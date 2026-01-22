import Foundation

// MARK: - Gemini CLI Adapter

/// EngineAdapter implementation for Gemini CLI.
/// Uses stream-json output format similar to Claude CLI.
///
/// **Note:** This is a Phase 3 adapter. The actual CLI output format
/// may differ and will need adjustment when integrating with a real Gemini CLI.
@MainActor
final class GeminiCliAdapter: EngineAdapter {
    let engineType: EngineType = .gemini

    private let processRunner: ProcessRunner
    private let parser: GeminiNDJSONParser
    private let mapper: GeminiEventMapper
    private var currentTask: Task<Void, Never>?

    /// Cached CLI path from validation
    private var validatedCLIPath: String?

    // Minimum supported version
    private static let minimumVersion = "1.0.0"

    init() {
        self.processRunner = ProcessRunner()
        self.parser = GeminiNDJSONParser()
        self.mapper = GeminiEventMapper()
    }

    // MARK: - Installation Validation

    func validateInstallation() async throws -> CLIInfo {
        // Check if gemini CLI exists
        let whichProcess = Process()
        let pipe = Pipe()

        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["gemini"]
        whichProcess.standardOutput = pipe
        whichProcess.standardError = pipe

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
        } catch {
            throw EngineError.cliNotFound(.gemini)
        }

        guard whichProcess.terminationStatus == 0 else {
            throw EngineError.cliNotFound(.gemini)
        }

        let pathData = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: pathData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "/usr/local/bin/gemini"

        // Get version
        let version = try await getVersion(path: path)

        // Determine capabilities - Gemini has native session persistence
        let capabilities: Set<EngineFeature> = [
            .streaming,
            .toolUse,
            .sessionPersistence,
            .multiModal
        ]

        self.validatedCLIPath = path

        return CLIInfo(
            version: version,
            path: path,
            capabilities: capabilities
        )
    }

    private func getVersion(path: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "unknown"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        // Parse version from output (e.g., "gemini 1.0.0")
        let components = output.split(separator: " ")
        if components.count >= 2 {
            return String(components[1])
        }
        return output
    }

    // MARK: - Turn Execution

    func startTurn(prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        guard let cliPath = validatedCLIPath else {
            // Try to find it
            _ = try await validateInstallation()
            guard let path = validatedCLIPath else {
                throw EngineError.cliNotFound(.gemini)
            }
            return try await startTurnWithPath(path, prompt: prompt, context: context)
        }

        return try await startTurnWithPath(cliPath, prompt: prompt, context: context)
    }

    private func startTurnWithPath(_ cliPath: String, prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        // Reset state
        await parser.reset()
        await mapper.reset()

        // Build arguments
        // Gemini CLI uses positional prompt argument (not -p flag)
        // and --output-format stream-json for streaming NDJSON output
        var args = [prompt, "--output-format", "stream-json"]

        // Add --resume for session continuity if we have previous context
        if !context.previousMessages.isEmpty {
            args.append("--resume")
        }

        // Configure process
        let config = ProcessRunner.Configuration(
            executable: cliPath,
            arguments: args,
            workingDirectory: context.projectPath,
            timeout: 600
        )

        return AsyncStream { continuation in
            currentTask = Task {
                do {
                    let processStream = await processRunner.run(config)

                    for try await output in processStream {
                        switch output {
                        case .stdout(let data):
                            let events = await parser.parse(chunk: data)
                            for geminiEvent in events {
                                let normalized = await mapper.map(geminiEvent)
                                for event in normalized {
                                    continuation.yield(event)
                                }
                            }

                        case .stderr(let data):
                            if let text = String(data: data, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                               !text.isEmpty {
                                print("[GeminiCliAdapter] stderr: \(text)")

                                // Check for rate limit errors (429)
                                if text.contains("429") || text.lowercased().contains("rate limit") {
                                    continuation.yield(.error(ErrorEvent(
                                        code: "rate_limit",
                                        message: "Gemini rate limit exceeded. Please wait and try again.",
                                        isRecoverable: true,
                                        timestamp: Date()
                                    )))
                                } else if text.lowercased().contains("auth") ||
                                          text.lowercased().contains("api key") ||
                                          text.lowercased().contains("unauthorized") ||
                                          text.lowercased().contains("401") {
                                    // Check for authentication errors
                                    continuation.yield(.error(ErrorEvent(
                                        code: "auth_error",
                                        message: "Gemini authentication failed. Check your API key.",
                                        isRecoverable: false,
                                        timestamp: Date()
                                    )))
                                } else if text.lowercased().contains("not found") ||
                                          text.lowercased().contains("command not found") {
                                    // Check for CLI not found
                                    continuation.yield(.error(ErrorEvent(
                                        code: "cli_not_found",
                                        message: "Gemini CLI not found. Please install gemini CLI.",
                                        isRecoverable: false,
                                        timestamp: Date()
                                    )))
                                }
                            }

                        case .exit(let code):
                            if let final = await parser.flush() {
                                let normalized = await mapper.map(final)
                                for event in normalized {
                                    continuation.yield(event)
                                }
                            }

                            if code != 0 {
                                print("[GeminiCliAdapter] Exit code: \(code)")
                            }
                        }
                    }
                } catch {
                    continuation.yield(.error(ErrorEvent(
                        code: "process_error",
                        message: error.localizedDescription,
                        isRecoverable: false,
                        timestamp: Date()
                    )))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Cancellation

    func cancelTurn() async {
        currentTask?.cancel()
        await processRunner.cancel()
    }

    // MARK: - Feature Support

    func supports(feature: EngineFeature) -> Bool {
        switch feature {
        case .streaming, .toolUse, .sessionPersistence, .multiModal:
            return true
        case .mcpSupport, .sandboxMode, .contextCompaction:
            return false
        }
    }
}

// MARK: - Gemini Event Mapper

/// Maps Gemini CLI stream events to normalized events.
/// Uses Gemini-specific event types (GeminiStreamEvent).
actor GeminiEventMapper {
    private var seenMessageIds: Set<String> = []
    private var accumulatedText: String = ""
    private var activeToolCalls: [String: ToolCallState] = [:]

    private struct ToolCallState {
        let name: String
        let input: String
        let startTime: Date
    }

    func reset() {
        seenMessageIds.removeAll()
        accumulatedText = ""
        activeToolCalls.removeAll()
    }

    /// Map a Gemini event to normalized events.
    func map(_ event: GeminiStreamEvent) -> [NormalizedEvent] {
        switch event {
        case .`init`(let initEvent):
            return [.sessionStarted(SessionStartedEvent(
                sessionId: initEvent.sessionId,
                engineType: "gemini",
                timestamp: Date()
            ))]

        case .message(let msgEvent):
            var events: [NormalizedEvent] = []

            // Only process assistant messages (not user echoes)
            if msgEvent.role == "assistant" {
                let newText = msgEvent.content

                // For streaming (delta: true), emit incremental text
                if msgEvent.delta == true {
                    // Emit delta if new text is longer than accumulated
                    if newText.count > accumulatedText.count {
                        let delta = String(newText.dropFirst(accumulatedText.count))
                        if !delta.isEmpty {
                            events.append(.assistantDelta(AssistantDelta(
                                text: delta,
                                timestamp: Date()
                            )))
                        }
                    } else if accumulatedText.isEmpty && !newText.isEmpty {
                        // First chunk
                        events.append(.assistantDelta(AssistantDelta(
                            text: newText,
                            timestamp: Date()
                        )))
                    }
                    accumulatedText = newText
                } else {
                    // Non-streaming complete message
                    events.append(.assistantDelta(AssistantDelta(
                        text: newText,
                        timestamp: Date()
                    )))
                    accumulatedText = newText
                }
            }

            return events

        case .toolCall(let toolEvent):
            // Serialize tool input to JSON string
            let inputJson: String
            if let input = toolEvent.tool.input,
               let data = try? JSONSerialization.data(withJSONObject: input, options: []),
               let str = String(data: data, encoding: .utf8) {
                inputJson = str
            } else {
                inputJson = "{}"
            }

            // Track active tool call
            activeToolCalls[toolEvent.id] = ToolCallState(
                name: toolEvent.tool.name,
                input: inputJson,
                startTime: Date()
            )

            return [.toolCallStarted(ToolCallStarted(
                toolCallId: toolEvent.id,
                toolName: toolEvent.tool.name,
                input: inputJson,
                timestamp: Date()
            ))]

        case .toolResult(let resultEvent):
            var events: [NormalizedEvent] = []

            if let toolState = activeToolCalls.removeValue(forKey: resultEvent.toolCallId) {
                let duration = Date().timeIntervalSince(toolState.startTime)
                events.append(.toolCallComplete(ToolCallComplete(
                    toolCallId: resultEvent.toolCallId,
                    toolName: toolState.name,
                    output: resultEvent.content,
                    error: resultEvent.isError == true ? resultEvent.content : nil,
                    duration: duration,
                    timestamp: Date()
                )))
            }

            return events

        case .result(let resultEvent):
            var events: [NormalizedEvent] = []

            // Emit assistant complete with accumulated text
            if !accumulatedText.isEmpty {
                events.append(.assistantComplete(AssistantComplete(
                    fullText: accumulatedText,
                    timestamp: Date(),
                    stopReason: .endTurn
                )))
            }

            // Emit token usage if available
            if let stats = resultEvent.stats {
                events.append(.tokenUsage(TokenUsage(
                    inputTokens: stats.inputTokens ?? stats.input ?? 0,
                    outputTokens: stats.outputTokens ?? 0,
                    cacheReadTokens: stats.cached,
                    cacheWriteTokens: nil,
                    totalTokens: stats.totalTokens ?? 0,
                    timestamp: Date()
                )))
            }

            events.append(.sessionEnded(SessionEndedEvent(
                sessionId: "",
                reason: resultEvent.status == "success" ? "completed" : "error",
                timestamp: Date()
            )))

            return events

        case .error(let errorEvent):
            return [.error(ErrorEvent(
                code: errorEvent.code ?? "unknown",
                message: errorEvent.message ?? "Unknown error",
                isRecoverable: false,
                timestamp: Date()
            ))]

        case .unknown:
            return []
        }
    }
}
