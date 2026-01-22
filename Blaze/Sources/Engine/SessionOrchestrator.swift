import Foundation
import os.log

private let orchestratorLog = OSLog(subsystem: "com.cogit0.Blaze", category: "Orchestrator")

// MARK: - Session Orchestrator

/// Orchestrates a complete session turn: CLI process → parse → map → store → UI.
/// This is the central coordinator that connects all the pieces.
///
/// **Phase 2 System Contract Integration:**
/// - Wires ToolApprovalPipeline for tool request/decision/result tracking
/// - Intercepts tool events and routes through approval pipeline
/// - Supports HookRunner for automation hooks
@MainActor
final class SessionOrchestrator: ObservableObject {
    // Dependencies
    private let engineManager: EngineManager
    private let eventStore: EventStore?

    // Phase 2: Tool approval pipeline
    private let approvalPipeline: ToolApprovalPipeline?

    // Phase 2: Hook runner for automation
    private let hookRunner: HookRunner?

    // Subagent routing
    private let subagentRouter: SubagentEventRouter?

    // State
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentError: Error?

    // Track sequence number per session
    private var sequenceCounters: [UUID: Int] = [:]

    // Track active tool calls for request/result correlation
    private var activeToolCalls: [String: UUID] = [:]

    init(
        engineManager: EngineManager,
        eventStore: EventStore? = nil,
        approvalPipeline: ToolApprovalPipeline? = nil,
        hookRunner: HookRunner? = nil,
        subagentRouter: SubagentEventRouter? = nil
    ) {
        self.engineManager = engineManager
        self.eventStore = eventStore
        self.approvalPipeline = approvalPipeline
        self.hookRunner = hookRunner
        self.subagentRouter = subagentRouter
    }

    /// Access to the approval pipeline for UI binding
    var toolApprovalPipeline: ToolApprovalPipeline? { approvalPipeline }

    // MARK: - Adapter Access

    /// Get the adapter for a session (for external access/testing)
    /// Uses session-specific adapters to prevent PTY bleeding
    func getAdapter(for session: Session) -> (any EngineAdapter)? {
        // Use session-specific adapter with dynamic engine type (Bug 1 fix + E005-F008-S002-T014-A001)
        return engineManager.adapter(for: session.provider.engineType, sessionId: session.id)
    }

    // MARK: - Turn Execution

    /// Execute a turn and stream normalized events.
    /// Updates AppState as events arrive for reactive UI.
    func executeTurn(
        prompt: String,
        session: Session,
        appState: AppState
    ) -> AsyncThrowingStream<NormalizedEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.runTurn(
                        prompt: prompt,
                        session: session,
                        appState: appState,
                        continuation: continuation
                    )
                } catch {
                    self.currentError = error
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func runTurn(
        prompt: String,
        session: Session,
        appState: AppState,
        continuation: AsyncThrowingStream<NormalizedEvent, Error>.Continuation
    ) async throws {
        isRunning = true
        currentError = nil
        defer { isRunning = false }

        // Get session-specific adapter (Bug 1 fix: prevents PTY bleeding between sessions)
        // E005-F008-S002-T014-A001: Use session.provider.engineType for dynamic engine selection
        let engineType = session.provider.engineType
        guard let adapter = engineManager.adapter(for: engineType, sessionId: session.id) else {
            throw EngineError.cliNotFound(engineType)
        }

        // Build turn context with PTY enabled for interactive tool prompts
        // Phase 2 System Contract: CLI runs in worktree directory for isolation
        let workingDirectory = session.effectiveWorkingDirectory
            ?? FileManager.default.homeDirectoryForCurrentUser.path

        let context = TurnContext(
            sessionId: session.id,
            projectPath: workingDirectory,
            allowedTools: nil,  // TODO: Get from session/policy
            trustMode: .review,
            enableStdin: true   // Enable PTY mode for AskUserQuestion support
        )

        // Start turn via adapter (uses PTY runner for bidirectional communication)
        let eventStream = try await adapter.startTurn(prompt: prompt, context: context)

        // Process events from adapter stream
        os_log(.info, log: orchestratorLog, "runTurn: Starting event stream iteration for session %{public}@", session.id.uuidString)
        var eventCount = 0
        for await event in eventStream {
            eventCount += 1
            os_log(.debug, log: orchestratorLog, "runTurn: Received event #%d type=%{public}@", eventCount, String(describing: type(of: event)))
            do {
                try await handleEvent(
                    event,
                    sessionId: session.id,
                    appState: appState,
                    continuation: continuation
                )
            } catch {
                // Log but continue processing events
                os_log(.error, log: orchestratorLog, "runTurn: Error handling event: %{public}@", error.localizedDescription)
            }
        }
        os_log(.info, log: orchestratorLog, "runTurn: Stream ended. Processed %d events", eventCount)

        continuation.finish()
    }

    private func handleEvent(
        _ event: NormalizedEvent,
        sessionId: UUID,
        appState: AppState,
        continuation: AsyncThrowingStream<NormalizedEvent, Error>.Continuation
    ) async throws {
        os_log(.debug, log: orchestratorLog, "handleEvent: Processing event type=%{public}@ for session %{public}@",
               String(describing: type(of: event)), sessionId.uuidString)

        // Increment sequence
        let sequence = (sequenceCounters[sessionId] ?? 0) + 1
        sequenceCounters[sessionId] = sequence

        // Route subagent events first (before approval pipeline)
        let wasSubagentEvent = await handleSubagentEvents(event, sessionId: sessionId)

        // Phase 2: Route tool events through approval pipeline
        // (Skip if already handled as subagent event to avoid double-processing)
        if !wasSubagentEvent {
            await handleToolApprovalEvents(event, sessionId: sessionId)
        }

        // Phase 2: Execute hooks for relevant events (with provider context for capability filtering)
        await handleHooks(event, sessionId: sessionId, provider: appState.sessions.first { $0.id == sessionId }?.provider)

        // Update AppState for UI reactivity FIRST (before storage which may throw)
        os_log(.debug, log: orchestratorLog, "handleEvent: About to call appendEvent for session %{public}@", sessionId.uuidString)
        appState.appendEvent(event, to: sessionId)

        // Persist to EventStore if available (non-blocking - errors don't stop UI)
        if let store = eventStore {
            do {
                try await store.append(event, sessionId: sessionId, sequence: sequence)
            } catch {
                print("[SessionOrchestrator] EventStore error: \(error)")
            }
        }

        // Yield to caller
        continuation.yield(event)
    }

    // MARK: - Subagent Event Routing

    /// Route subagent events through the SubagentEventRouter
    ///
    /// - Returns: True if event was a subagent event (routed), false otherwise
    private func handleSubagentEvents(_ event: NormalizedEvent, sessionId: UUID) async -> Bool {
        guard let router = subagentRouter else { return false }
        return await router.route(event, parentSessionId: sessionId)
    }

    // MARK: - Tool Approval Pipeline Integration

    /// Route tool events through the approval pipeline
    private func handleToolApprovalEvents(_ event: NormalizedEvent, sessionId: UUID) async {
        guard let pipeline = approvalPipeline else { return }

        switch event {
        case .toolCallStarted(let started):
            // Create a tool request and submit to pipeline
            let request = ToolRequestEvent(
                toolCallId: started.toolCallId,
                toolName: started.toolName,
                input: started.input,
                riskLevel: ToolRiskClassifier.classify(toolName: started.toolName, scope: nil),
                scope: nil
            )

            // Track the mapping for result correlation
            activeToolCalls[started.toolCallId] = request.id

            // Submit to pipeline (this may auto-approve based on trust mode)
            // Note: We don't await the decision here because CLI runs tools anyway
            // This is for tracking/audit purposes
            Task {
                let _ = await pipeline.submitRequest(request)
            }

        case .toolCallComplete(let complete):
            // Find the corresponding request
            if let requestId = activeToolCalls[complete.toolCallId] {
                // Create and record the result
                let result = ToolResultEvent(
                    toolRequestId: requestId,
                    toolCallId: complete.toolCallId,
                    toolName: complete.toolName,
                    output: complete.output,
                    error: complete.error,
                    durationMs: Int(complete.duration * 1000),
                    timestamp: complete.timestamp
                )

                await pipeline.recordResult(result)
                activeToolCalls.removeValue(forKey: complete.toolCallId)
            }

        default:
            break
        }
    }

    // MARK: - Hook Integration

    /// Execute hooks for relevant events with provider context.
    ///
    /// **E005-F004-S001-T009-A001:** Session-aware hook context.
    /// The provider parameter enables HookRunner to filter hooks by CLI engine
    /// capabilities (e.g., skip unsupported events for Gemini/Codex).
    private func handleHooks(_ event: NormalizedEvent, sessionId: UUID, provider: AIProvider?) async {
        guard let runner = hookRunner else { return }

        let hookEventType: HookEventType?
        var triggerContext: String?
        var triggerData: [String: String] = [:]

        switch event {
        case .toolCallStarted(let started):
            hookEventType = .preToolCall
            triggerContext = started.toolName
            triggerData["tool_name"] = started.toolName
            triggerData["tool_call_id"] = started.toolCallId

        case .toolCallComplete(let complete):
            hookEventType = .postToolCall
            triggerContext = complete.toolName
            triggerData["tool_name"] = complete.toolName
            triggerData["tool_call_id"] = complete.toolCallId
            if !complete.succeeded {
                triggerData["is_error"] = "true"
            }

        case .fileDiffProduced(let diff):
            hookEventType = .postFileWrite
            triggerContext = diff.filePath
            triggerData["file_path"] = diff.filePath

        case .sessionStarted:
            hookEventType = .sessionStart

        case .sessionEnded:
            hookEventType = .sessionEnd

        default:
            hookEventType = nil
        }

        if let eventType = hookEventType {
            // Convert AIProvider to HookProvider for capability filtering
            let hookProvider = provider?.hookProvider

            let _ = await runner.executeHooks(
                for: eventType,
                triggerContext: triggerContext,
                triggerData: triggerData,
                sessionId: sessionId,
                provider: hookProvider
            )
        }
    }

    // MARK: - Cancellation

    /// Cancel the current turn for a specific session
    /// E005-F008-S002-T014-A001: Support multi-provider cancellation
    func cancel(session: Session? = nil) async {
        if let session = session {
            // Cancel specific session's adapter
            let engineType = session.provider.engineType
            if let adapter = engineManager.adapter(for: engineType, sessionId: session.id) {
                await adapter.cancelTurn()
            }
        } else {
            // Fallback: Cancel all template adapters (legacy behavior)
            for engineType in EngineType.allCases {
                if let adapter = engineManager.adapter(for: engineType) {
                    await adapter.cancelTurn()
                }
            }
        }
    }

    // MARK: - Utilities

    /// Reset sequence counter for a session (e.g., when clearing context)
    func resetSequence(for sessionId: UUID) {
        sequenceCounters[sessionId] = 0
    }
}
