import Foundation

// MARK: - Event Type Discriminator

/// Event type discriminator for normalized events per System Contract.
/// Used for storage, filtering, and telemetry.
public enum NormalizedEventType: String, Codable, Sendable, CaseIterable {
    // Content events
    case assistantDelta = "assistant_delta"
    case assistantComplete = "assistant_complete"
    case thinkingDelta = "thinking_delta"

    // Tool events
    case toolCallStarted = "tool_call_started"
    case toolCallComplete = "tool_call_complete"
    case toolRequest = "tool_request"
    case toolDecision = "tool_decision"
    case toolResult = "tool_result"
    case subagentSpawned = "subagent_spawned"
    case subagentProgress = "subagent_progress"
    case subagentCompleted = "subagent_completed"
    case subagentFailed = "subagent_failed"

    // File events
    case fileDiffProduced = "file_diff_produced"
    case fileWritten = "file_written"
    case fileRead = "file_read"

    // System events
    case sessionStarted = "session_started"
    case sessionEnded = "session_ended"
    case error = "error"
    case tokenUsage = "token_usage"

    // Raw/unknown
    case raw = "raw"

    // Codex-specific events
    case turnPlanUpdated = "turn_plan_updated"
    case rateLimitsUpdated = "rate_limits_updated"
    case reasoningDelta = "reasoning_delta"
    case toolOutputDelta = "tool_output_delta"
    case fileDiffDelta = "file_diff_delta"

    // Review mode events (Codex)
    case reviewModeEntered = "review_mode_entered"
    case reviewModeExited = "review_mode_exited"
}

// MARK: - Normalized Event

/// Engine-agnostic event type that all CLI adapters map to.
/// This is the core abstraction that enables multi-engine support.
///
/// **System Contract (Phase 2):**
/// - All events must have: type, timestamp, session_id, payload
/// - Missing session_id is injected at ingestion boundary
/// - Events are strictly ordered by emission time
public enum NormalizedEvent: Codable, Sendable {
    // Content events
    case assistantDelta(AssistantDelta)
    case assistantComplete(AssistantComplete)
    case thinkingDelta(ThinkingDelta)

    // Tool events
    case toolCallStarted(ToolCallStarted)
    case toolCallComplete(ToolCallComplete)

    // File events
    case fileDiffProduced(FileDiffProduced)
    case fileWritten(FileWritten)
    case fileRead(FileRead)

    // System events
    case sessionStarted(SessionStartedEvent)
    case sessionEnded(SessionEndedEvent)
    case error(ErrorEvent)
    case tokenUsage(TokenUsage)

    // Tool approval events (Phase 2)
    case toolRequest(ToolRequestEvent)
    case toolDecision(ToolDecisionEvent)
    case toolResult(ToolResultEvent)

    // Subagent events
    case subagentSpawned(SubagentSpawnedEvent)
    case subagentProgress(SubagentProgressEvent)
    case subagentCompleted(SubagentCompletedEvent)
    case subagentFailed(SubagentFailedEvent)

    // Raw/unknown events (for forward compatibility)
    case raw(RawEvent)

    // Codex-specific events
    case turnPlanUpdated(TurnPlanUpdatedEvent)
    case rateLimitsUpdated(RateLimitsUpdatedEvent)
    case reasoningDelta(ReasoningDeltaEvent)
    case toolOutputDelta(ToolOutputDeltaEvent)
    case fileDiffDelta(FileDiffDeltaEvent)

    // Review mode events (Codex)
    case reviewModeEntered(ReviewModeEnteredEvent)
    case reviewModeExited(ReviewModeExitedEvent)

    /// Get the event type discriminator per System Contract
    public var eventType: NormalizedEventType {
        switch self {
        case .assistantDelta: return .assistantDelta
        case .assistantComplete: return .assistantComplete
        case .thinkingDelta: return .thinkingDelta
        case .toolCallStarted: return .toolCallStarted
        case .toolCallComplete: return .toolCallComplete
        case .toolRequest: return .toolRequest
        case .toolDecision: return .toolDecision
        case .toolResult: return .toolResult
        case .subagentSpawned: return .subagentSpawned
        case .subagentProgress: return .subagentProgress
        case .subagentCompleted: return .subagentCompleted
        case .subagentFailed: return .subagentFailed
        case .fileDiffProduced: return .fileDiffProduced
        case .fileWritten: return .fileWritten
        case .fileRead: return .fileRead
        case .sessionStarted: return .sessionStarted
        case .sessionEnded: return .sessionEnded
        case .error: return .error
        case .tokenUsage: return .tokenUsage
        case .raw: return .raw
        case .turnPlanUpdated: return .turnPlanUpdated
        case .rateLimitsUpdated: return .rateLimitsUpdated
        case .reasoningDelta: return .reasoningDelta
        case .toolOutputDelta: return .toolOutputDelta
        case .fileDiffDelta: return .fileDiffDelta
        case .reviewModeEntered: return .reviewModeEntered
        case .reviewModeExited: return .reviewModeExited
        }
    }

    /// Get the timestamp from any event (named differently to avoid Codable conflict)
    public var eventTimestamp: Date {
        switch self {
        case .assistantDelta(let e): return e.timestamp
        case .assistantComplete(let e): return e.timestamp
        case .thinkingDelta(let e): return e.timestamp
        case .toolCallStarted(let e): return e.timestamp
        case .toolCallComplete(let e): return e.timestamp
        case .toolRequest(let e): return e.timestamp
        case .toolDecision(let e): return e.timestamp
        case .toolResult(let e): return e.timestamp
        case .subagentSpawned(let e): return e.timestamp
        case .subagentProgress(let e): return e.timestamp
        case .subagentCompleted(let e): return e.timestamp
        case .subagentFailed(let e): return e.timestamp
        case .fileDiffProduced(let e): return e.timestamp
        case .fileWritten(let e): return e.timestamp
        case .fileRead(let e): return e.timestamp
        case .sessionStarted(let e): return e.timestamp
        case .sessionEnded(let e): return e.timestamp
        case .error(let e): return e.timestamp
        case .tokenUsage(let e): return e.timestamp
        case .raw(let e): return e.timestamp
        case .turnPlanUpdated(let e): return e.timestamp
        case .rateLimitsUpdated(let e): return e.timestamp
        case .reasoningDelta(let e): return e.timestamp
        case .toolOutputDelta(let e): return e.timestamp
        case .fileDiffDelta(let e): return e.timestamp
        case .reviewModeEntered(let e): return e.timestamp
        case .reviewModeExited(let e): return e.timestamp
        }
    }
}

// MARK: - Content Events

public struct AssistantDelta: Codable, Sendable {
    public let text: String
    public let timestamp: Date

    public init(text: String, timestamp: Date) {
        self.text = text
        self.timestamp = timestamp
    }
}

public struct AssistantComplete: Codable, Sendable {
    public let fullText: String
    public let timestamp: Date
    public let stopReason: StopReason?

    public init(fullText: String, timestamp: Date, stopReason: StopReason?) {
        self.fullText = fullText
        self.timestamp = timestamp
        self.stopReason = stopReason
    }
}

public struct ThinkingDelta: Codable, Sendable {
    public let text: String
    public let timestamp: Date

    public init(text: String, timestamp: Date) {
        self.text = text
        self.timestamp = timestamp
    }
}

public enum StopReason: String, Codable, Sendable {
    case endTurn = "end_turn"
    case toolUse = "tool_use"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
}

// MARK: - Tool Events

public struct ToolCallStarted: Codable, Sendable {
    public let toolCallId: String
    public let toolName: String
    public let input: String
    public let timestamp: Date

    public init(toolCallId: String, toolName: String, input: String, timestamp: Date) {
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.input = input
        self.timestamp = timestamp
    }
}

public struct ToolCallComplete: Codable, Sendable {
    public let toolCallId: String
    public let toolName: String
    public let output: String?
    public let error: String?
    public let duration: TimeInterval
    public let timestamp: Date

    public var succeeded: Bool { error == nil }

    public init(toolCallId: String, toolName: String, output: String?, error: String?, duration: TimeInterval, timestamp: Date) {
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.output = output
        self.error = error
        self.duration = duration
        self.timestamp = timestamp
    }
}

public struct SubagentSpawnedEvent: Codable, Sendable {
    public let toolUseId: String
    public let subagentType: String
    public let description: String
    public let prompt: String
    public let timestamp: Date

    public init(toolUseId: String, subagentType: String, description: String, prompt: String, timestamp: Date) {
        self.toolUseId = toolUseId
        self.subagentType = subagentType
        self.description = description
        self.prompt = prompt
        self.timestamp = timestamp
    }
}

public struct SubagentProgressEvent: Codable, Sendable {
    public let toolUseId: String
    public let message: String
    public let timestamp: Date

    public init(toolUseId: String, message: String, timestamp: Date) {
        self.toolUseId = toolUseId
        self.message = message
        self.timestamp = timestamp
    }
}

/// Subagent execution completed successfully
public struct SubagentCompletedEvent: Codable, Sendable {
    public let toolUseId: String
    public let result: String
    public let tokenUsage: SubagentTokenUsage
    public let durationMs: Int
    public let timestamp: Date

    public init(
        toolUseId: String,
        result: String,
        tokenUsage: SubagentTokenUsage,
        durationMs: Int,
        timestamp: Date = Date()
    ) {
        self.toolUseId = toolUseId
        self.result = result
        self.tokenUsage = tokenUsage
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

/// Subagent execution failed
public struct SubagentFailedEvent: Codable, Sendable {
    public let toolUseId: String
    public let error: String
    public let errorCode: String?
    public let timestamp: Date

    public init(
        toolUseId: String,
        error: String,
        errorCode: String? = nil,
        timestamp: Date = Date()
    ) {
        self.toolUseId = toolUseId
        self.error = error
        self.errorCode = errorCode
        self.timestamp = timestamp
    }
}

// MARK: - File Events

public struct FileDiffProduced: Codable, Sendable {
    public let filePath: String
    public let diff: String
    public let hunks: [DiffHunk]
    public let timestamp: Date

    public init(filePath: String, diff: String, hunks: [DiffHunk], timestamp: Date) {
        self.filePath = filePath
        self.diff = diff
        self.hunks = hunks
        self.timestamp = timestamp
    }
}

public struct FileWritten: Codable, Sendable {
    public let filePath: String
    public let bytesWritten: Int64
    public let timestamp: Date

    public init(filePath: String, bytesWritten: Int64, timestamp: Date) {
        self.filePath = filePath
        self.bytesWritten = bytesWritten
        self.timestamp = timestamp
    }
}

public struct FileRead: Codable, Sendable {
    public let filePath: String
    public let bytesRead: Int64
    public let timestamp: Date

    public init(filePath: String, bytesRead: Int64, timestamp: Date) {
        self.filePath = filePath
        self.bytesRead = bytesRead
        self.timestamp = timestamp
    }
}

// MARK: - System Events

public struct SessionStartedEvent: Codable, Sendable {
    public let sessionId: String
    public let engineType: String
    public let timestamp: Date

    public init(sessionId: String, engineType: String, timestamp: Date) {
        self.sessionId = sessionId
        self.engineType = engineType
        self.timestamp = timestamp
    }
}

public struct SessionEndedEvent: Codable, Sendable {
    public let sessionId: String
    public let reason: String
    public let timestamp: Date

    public init(sessionId: String, reason: String, timestamp: Date) {
        self.sessionId = sessionId
        self.reason = reason
        self.timestamp = timestamp
    }
}

public struct ErrorEvent: Codable, Sendable {
    public let code: String
    public let message: String
    public let isRecoverable: Bool
    public let timestamp: Date

    public init(code: String, message: String, isRecoverable: Bool, timestamp: Date) {
        self.code = code
        self.message = message
        self.isRecoverable = isRecoverable
        self.timestamp = timestamp
    }
}

public struct TokenUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int?
    public let cacheWriteTokens: Int?
    public let totalTokens: Int
    public let timestamp: Date

    public init(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int?, cacheWriteTokens: Int?, totalTokens: Int, timestamp: Date) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.totalTokens = totalTokens
        self.timestamp = timestamp
    }
}

// MARK: - Tool Approval Events (Phase 2 System Contract)

/// Risk level for tool execution per System Contract
public enum ToolRiskLevel: String, Codable, Sendable {
    case low = "low"          // Read-only, safe tools
    case medium = "medium"    // Writes within worktree
    case high = "high"        // Shell commands, writes outside worktree
}

/// Tool request event - emitted when a tool call is requested
/// Part of the ToolRequest -> ToolDecision -> ToolResult ordering contract
public struct ToolRequestEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let toolCallId: String
    public let toolName: String
    public let input: String
    public let riskLevel: ToolRiskLevel
    public let scope: ToolScope?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        toolCallId: String,
        toolName: String,
        input: String,
        riskLevel: ToolRiskLevel,
        scope: ToolScope? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.input = input
        self.riskLevel = riskLevel
        self.scope = scope
        self.timestamp = timestamp
    }
}

/// Tool scope defines what the tool will access
public struct ToolScope: Codable, Sendable {
    public let paths: [String]?
    public let commands: [String]?
    public let urls: [String]?

    public init(paths: [String]? = nil, commands: [String]? = nil, urls: [String]? = nil) {
        self.paths = paths
        self.commands = commands
        self.urls = urls
    }
}

/// Decision on a tool request
public enum ToolDecisionType: String, Codable, Sendable {
    case approved = "approved"
    case rejected = "rejected"
    case alwaysAllow = "always_allow"
}

/// Tool decision event - emitted when a decision is made on a tool request
public struct ToolDecisionEvent: Codable, Sendable {
    public let toolRequestId: UUID
    public let decision: ToolDecisionType
    public let decidedBy: String  // "user" or "system" or allowlist rule id
    public let rationale: String?
    public let allowlistRuleId: UUID?
    public let timestamp: Date

    public init(
        toolRequestId: UUID,
        decision: ToolDecisionType,
        decidedBy: String,
        rationale: String? = nil,
        allowlistRuleId: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.toolRequestId = toolRequestId
        self.decision = decision
        self.decidedBy = decidedBy
        self.rationale = rationale
        self.allowlistRuleId = allowlistRuleId
        self.timestamp = timestamp
    }
}

/// Tool result event - emitted after tool execution (only if approved)
public struct ToolResultEvent: Codable, Sendable {
    public let toolRequestId: UUID
    public let toolCallId: String
    public let toolName: String
    public let output: String?
    public let error: String?
    public let durationMs: Int
    public let timestamp: Date

    public var succeeded: Bool { error == nil }

    public init(
        toolRequestId: UUID,
        toolCallId: String,
        toolName: String,
        output: String? = nil,
        error: String? = nil,
        durationMs: Int,
        timestamp: Date = Date()
    ) {
        self.toolRequestId = toolRequestId
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.output = output
        self.error = error
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

// MARK: - Codex-Specific Events

/// Status of a plan step in a turn plan
public enum PlanStepStatus: String, Codable, Sendable {
    case pending = "pending"
    case inProgress = "in_progress"
    case done = "done"
}

/// A single step in the turn plan
public struct PlanStep: Codable, Sendable, Identifiable {
    public let id: String
    public let description: String
    public let status: PlanStepStatus

    public init(id: String, description: String, status: PlanStepStatus) {
        self.id = id
        self.description = description
        self.status = status
    }
}

/// Turn plan updated event - emitted when Codex updates its execution plan
public struct TurnPlanUpdatedEvent: Codable, Sendable {
    public let turnId: String
    public let explanation: String
    public let steps: [PlanStep]
    public let timestamp: Date

    public init(turnId: String, explanation: String, steps: [PlanStep], timestamp: Date = Date()) {
        self.turnId = turnId
        self.explanation = explanation
        self.steps = steps
        self.timestamp = timestamp
    }
}

/// Rate limit information for a model
public struct RateLimit: Codable, Sendable {
    public let model: String
    public let remaining: Int
    public let resetAt: Date

    public init(model: String, remaining: Int, resetAt: Date) {
        self.model = model
        self.remaining = remaining
        self.resetAt = resetAt
    }
}

/// Rate limits updated event - emitted when Codex reports rate limit status
public struct RateLimitsUpdatedEvent: Codable, Sendable {
    public let primary: RateLimit?
    public let secondary: RateLimit?
    public let timestamp: Date

    public init(primary: RateLimit? = nil, secondary: RateLimit? = nil, timestamp: Date = Date()) {
        self.primary = primary
        self.secondary = secondary
        self.timestamp = timestamp
    }
}

/// Reasoning delta event - streaming reasoning content from Codex
public struct ReasoningDeltaEvent: Codable, Sendable {
    public let itemId: String
    public let summaryDelta: String?
    public let contentDelta: String?
    public let timestamp: Date

    public init(itemId: String, summaryDelta: String? = nil, contentDelta: String? = nil, timestamp: Date = Date()) {
        self.itemId = itemId
        self.summaryDelta = summaryDelta
        self.contentDelta = contentDelta
        self.timestamp = timestamp
    }
}

/// Tool output delta event - streaming tool output from Codex
public struct ToolOutputDeltaEvent: Codable, Sendable {
    public let itemId: String
    public let delta: String
    public let timestamp: Date

    public init(itemId: String, delta: String, timestamp: Date = Date()) {
        self.itemId = itemId
        self.delta = delta
        self.timestamp = timestamp
    }
}

/// File diff delta event - streaming file diff from Codex
public struct FileDiffDeltaEvent: Codable, Sendable {
    public let itemId: String
    public let delta: String
    public let timestamp: Date

    public init(itemId: String, delta: String, timestamp: Date = Date()) {
        self.itemId = itemId
        self.delta = delta
        self.timestamp = timestamp
    }
}

// MARK: - Review Mode Events (Codex)

/// Review mode entered event - Codex paused for human review of changes
public struct ReviewModeEnteredEvent: Codable, Sendable {
    /// Unique identifier for this review session
    public let reviewId: String
    /// Reason for entering review mode
    public let reason: String
    /// Pending file changes to review
    public let pendingChanges: [ReviewModeFileDiff]
    public let timestamp: Date

    public init(
        reviewId: String,
        reason: String,
        pendingChanges: [ReviewModeFileDiff],
        timestamp: Date = Date()
    ) {
        self.reviewId = reviewId
        self.reason = reason
        self.pendingChanges = pendingChanges
        self.timestamp = timestamp
    }
}

/// Review mode exited event - human review completed
public struct ReviewModeExitedEvent: Codable, Sendable {
    /// The review ID that was completed
    public let reviewId: String
    /// Outcome of the review
    public let result: ReviewModeResult
    public let timestamp: Date

    public init(reviewId: String, result: ReviewModeResult, timestamp: Date = Date()) {
        self.reviewId = reviewId
        self.result = result
        self.timestamp = timestamp
    }
}

/// Result of a review mode session
public enum ReviewModeResult: String, Codable, Sendable {
    case approved
    case cancelled
    case timeout
}

/// File diff for review mode (simplified version of FileDiffProduced)
public struct ReviewModeFileDiff: Codable, Sendable {
    /// Path to the modified file
    public let filePath: String
    /// Type of change: create, modify, delete
    public let changeType: String
    /// Unified diff content (optional, may be nil for new files)
    public let diff: String?

    public init(filePath: String, changeType: String, diff: String? = nil) {
        self.filePath = filePath
        self.changeType = changeType
        self.diff = diff
    }
}

// MARK: - Raw Event

public struct RawEvent: Codable, Sendable {
    public let type: String
    public let payload: Data
    public let timestamp: Date

    public init(type: String, payload: Data, timestamp: Date = Date()) {
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
    }
}

// MARK: - Event Envelope

/// Wraps a normalized event with metadata for storage and sequencing.
///
/// **System Contract (Phase 2):**
/// - Required fields: type, timestamp, session_id, payload (event)
/// - session_id is injected at ingestion boundary if missing from source
public struct EventEnvelope: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let sequence: Int
    public let timestamp: Date
    public let event: NormalizedEvent

    /// Event type for filtering and persistence
    public var eventType: NormalizedEventType {
        event.eventType
    }

    public init(sessionId: UUID, sequence: Int, event: NormalizedEvent) {
        self.id = UUID()
        self.sessionId = sessionId
        self.sequence = sequence
        self.timestamp = Date()
        self.event = event
    }

    /// Create envelope with explicit ID (for deserialization)
    public init(id: UUID, sessionId: UUID, sequence: Int, timestamp: Date, event: NormalizedEvent) {
        self.id = id
        self.sessionId = sessionId
        self.sequence = sequence
        self.timestamp = timestamp
        self.event = event
    }
}

// MARK: - Event Normalizer

/// Normalizes incoming events to ensure System Contract compliance.
///
/// **System Contract Guarantees:**
/// - All events have type, timestamp, session_id, payload
/// - Missing session_id is injected from the ingestion context
/// - Events are validated before acceptance
public actor EventNormalizer {
    /// The session ID to inject when source events don't have one
    private let defaultSessionId: String

    /// Sequence counter for ordering
    private var nextSequence: Int = 0

    public init(defaultSessionId: String) {
        self.defaultSessionId = defaultSessionId
    }

    /// Normalize an event, injecting session_id if needed
    public func normalize(_ event: NormalizedEvent, sessionId: UUID? = nil) -> EventEnvelope {
        let seq = nextSequence
        nextSequence += 1

        // Use provided sessionId or parse from defaultSessionId
        let resolvedSessionId: UUID
        if let sessionId {
            resolvedSessionId = sessionId
        } else if let parsed = UUID(uuidString: defaultSessionId) {
            resolvedSessionId = parsed
        } else {
            // Generate new UUID if default is not a valid UUID
            resolvedSessionId = UUID()
        }

        return EventEnvelope(
            sessionId: resolvedSessionId,
            sequence: seq,
            event: event
        )
    }

    /// Reset sequence counter (for new session)
    public func reset() {
        nextSequence = 0
    }

    /// Get current sequence number
    public var currentSequence: Int {
        nextSequence
    }

    /// Validate that an event has all required fields per System Contract
    public func validate(_ envelope: EventEnvelope) -> Bool {
        // All envelopes have required fields by construction
        // Additional validation can be added here if needed
        return envelope.sessionId != UUID(uuidString: "00000000-0000-0000-0000-000000000000")
    }
}
