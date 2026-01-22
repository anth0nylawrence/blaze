import Foundation

// MARK: - Codex CLI Adapter

/// EngineAdapter implementation for OpenAI Codex CLI.
/// Uses `codex exec --json` for structured output.
///
/// **Note:** This is a Phase 3 adapter. The actual CLI output format
/// may differ and will need adjustment when integrating with a real Codex CLI.
@MainActor
final class CodexCliAdapter: EngineAdapter {
    let engineType: EngineType = .codex

    private let processRunner: ProcessRunner
    private var currentTask: Task<Void, Never>?

    /// Cached CLI path from validation
    private var validatedCLIPath: String?

    // Minimum supported version
    private static let minimumVersion = "1.0.0"

    init() {
        self.processRunner = ProcessRunner()
    }

    // MARK: - Installation Validation

    func validateInstallation() async throws -> CLIInfo {
        // Check if codex CLI exists
        let whichProcess = Process()
        let pipe = Pipe()

        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["codex"]
        whichProcess.standardOutput = pipe
        whichProcess.standardError = pipe

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
        } catch {
            throw EngineError.cliNotFound(.codex)
        }

        guard whichProcess.terminationStatus == 0 else {
            throw EngineError.cliNotFound(.codex)
        }

        let pathData = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: pathData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "/usr/local/bin/codex"

        // Get version
        let version = try await getVersion(path: path)

        // Codex supports sandbox policies and approval modes
        let capabilities: Set<EngineFeature> = [
            .streaming,
            .toolUse,
            .sessionPersistence,
            .sandboxMode
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

        // Parse version from output
        let components = output.split(separator: " ")
        if components.count >= 2 {
            return String(components[1])
        }
        return output
    }

    // MARK: - Turn Execution

    func startTurn(prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        guard let cliPath = validatedCLIPath else {
            _ = try await validateInstallation()
            guard let path = validatedCLIPath else {
                throw EngineError.cliNotFound(.codex)
            }
            return try await startTurnWithPath(path, prompt: prompt, context: context)
        }

        return try await startTurnWithPath(cliPath, prompt: prompt, context: context)
    }

    private func startTurnWithPath(_ cliPath: String, prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        // Build arguments - Codex uses `exec --json "<prompt>"`
        var args = ["exec", "--json", prompt]

        // Add approval policy based on trust mode
        switch context.trustMode {
        case .unrestricted:
            args.append("--full-auto")
        case .allowlisted:
            args.append("--auto-approve")
        case .prompt, .lockedDown:
            // Default interactive approval
            break
        }

        // Add resume for multi-turn
        if !context.previousMessages.isEmpty {
            args.append("resume")
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
                var lineBuffer = Data()
                let decoder = JSONDecoder()
                var accumulatedText = ""
                var threadId: String?

                do {
                    let processStream = await processRunner.run(config)

                    for try await output in processStream {
                        switch output {
                        case .stdout(let data):
                            // Parse NDJSON lines
                            lineBuffer.append(data)
                            print("[CodexCliAdapter] stdout chunk: \(data.count) bytes")

                            // Split on newlines
                            while let newlineIndex = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                                let lineData = lineBuffer.prefix(upTo: newlineIndex)
                                lineBuffer = lineBuffer.suffix(from: lineBuffer.index(after: newlineIndex))

                                // Skip empty lines
                                guard !lineData.isEmpty else { continue }

                                // Debug: show raw line
                                if let lineStr = String(data: Data(lineData), encoding: .utf8) {
                                    print("[CodexCliAdapter] parsing line: \(lineStr.prefix(100))")
                                }

                                // Parse the JSON line
                                do {
                                    let events = try parseCodexExecEvent(Data(lineData), decoder: decoder,
                                                                          accumulatedText: &accumulatedText,
                                                                          threadId: &threadId)
                                    for event in events {
                                        print("[CodexCliAdapter] yielding event: \(event)")
                                        continuation.yield(event)
                                    }
                                } catch {
                                    print("[CodexCliAdapter] Failed to parse line: \(error)")
                                }
                            }

                        case .stderr(let data):
                            if let text = String(data: data, encoding: .utf8) {
                                print("[CodexCliAdapter] stderr: \(text)")
                            }

                        case .exit(let code):
                            if code != 0 {
                                print("[CodexCliAdapter] Exit code: \(code)")
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

    // MARK: - File Read Detection

    /// Commands that read file contents
    private static let fileReadCommands = ["cat", "head", "tail", "less", "more", "bat", "view"]

    /// Extract file paths from common file-reading shell commands.
    ///
    /// Detects patterns like:
    /// - `cat foo.txt`
    /// - `head -n 10 bar.swift`
    /// - `tail -f log.txt`
    /// - `less README.md`
    ///
    /// - Parameter command: The shell command string
    /// - Returns: Array of file paths found in the command
    private func extractFilePathsFromCommand(_ command: String) -> [String] {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle piped commands - take the first command
        let firstCommand = trimmed.split(separator: "|").first.map(String.init) ?? trimmed

        // Split into tokens
        let tokens = firstCommand.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let executable = tokens.first else { return [] }

        // Check if this is a file-reading command
        let baseName = (executable as NSString).lastPathComponent
        guard Self.fileReadCommands.contains(baseName) else { return [] }

        // Extract file paths (skip flags that start with -)
        var paths: [String] = []
        var skipNext = false

        for (index, token) in tokens.enumerated() {
            // Skip the command itself
            if index == 0 { continue }

            // Skip if previous token was a flag expecting a value (like -n for head)
            if skipNext {
                skipNext = false
                continue
            }

            // Check if this is a flag
            if token.hasPrefix("-") {
                // Flags that take a value: -n, -c, etc.
                let flagsWithValue = ["-n", "-c", "-q", "--lines", "--bytes"]
                if flagsWithValue.contains(token) {
                    skipNext = true
                }
                continue
            }

            // This looks like a file path
            // Skip common non-file arguments
            if !token.isEmpty && token != "+" {
                paths.append(token)
            }
        }

        return paths
    }

    // MARK: - Codex Exec JSON Parser

    /// Parse a single line from `codex exec --json` output.
    /// Returns an array of events since a command execution may produce
    /// both a toolCallComplete and fileRead events.
    private func parseCodexExecEvent(
        _ data: Data,
        decoder: JSONDecoder,
        accumulatedText: inout String,
        threadId: inout String?
    ) throws -> [NormalizedEvent] {
        struct CodexExecEvent: Codable {
            let type: String
            let thread_id: String?
            let item: CodexItem?
            let usage: CodexUsage?
        }

        struct CodexItem: Codable {
            let id: String
            let type: String
            let text: String?
            // command_execution fields
            let command: String?
            let output: String?
            let exit_code: Int?
        }

        struct CodexUsage: Codable {
            let input_tokens: Int
            let output_tokens: Int
        }

        let event = try decoder.decode(CodexExecEvent.self, from: data)
        let now = Date()

        switch event.type {
        case "thread.started":
            // Store thread ID for session tracking
            if let tid = event.thread_id {
                threadId = tid
            }
            return [.sessionStarted(SessionStartedEvent(
                sessionId: event.thread_id ?? UUID().uuidString,
                engineType: "codex",
                timestamp: now
            ))]

        case "turn.started":
            // Can ignore - thread.started covers session init
            return []

        case "item.started":
            // Tool call started - emit toolCallStarted for command_execution
            guard let item = event.item else { return [] }

            if item.type == "command_execution" {
                return [.toolCallStarted(ToolCallStarted(
                    toolCallId: item.id,
                    toolName: "bash",
                    input: item.command ?? "",
                    timestamp: now
                ))]
            }
            // Other item types (agent_message, etc.) don't need started events
            return []

        case "item.completed":
            guard let item = event.item else { return [] }

            switch item.type {
            case "agent_message":
                // Emit delta for the text (if not already emitted)
                let text = item.text ?? ""
                if text != accumulatedText {
                    accumulatedText = text
                    return [.assistantDelta(AssistantDelta(
                        text: text,
                        timestamp: now
                    ))]
                }
                return []

            case "reasoning":
                // Reasoning item completed - could emit as reasoningDelta
                if let text = item.text {
                    return [.reasoningDelta(ReasoningDeltaEvent(
                        itemId: item.id,
                        summaryDelta: nil,
                        contentDelta: text,
                        timestamp: now
                    ))]
                }
                return []

            case "command_execution":
                // Command execution completed - emit toolCallComplete
                var events: [NormalizedEvent] = []
                let isError = (item.exit_code ?? 0) != 0
                let command = item.command ?? ""

                // Emit the tool call complete event
                events.append(.toolCallComplete(ToolCallComplete(
                    toolCallId: item.id,
                    toolName: "bash",
                    output: item.output,
                    error: isError ? "Exit code: \(item.exit_code ?? -1)" : nil,
                    duration: 0,  // Duration not available in Codex output
                    timestamp: now
                )))

                // Detect file reads from command and emit fileRead events
                let filePaths = extractFilePathsFromCommand(command)
                for filePath in filePaths {
                    events.append(.fileRead(FileRead(
                        filePath: filePath,
                        bytesRead: Int64(item.output?.count ?? 0),
                        timestamp: now
                    )))
                }

                return events

            default:
                return []
            }

        case "turn.completed":
            // Emit final assistant complete + token usage
            var events: [NormalizedEvent] = []

            // Assistant complete
            if !accumulatedText.isEmpty {
                events.append(.assistantComplete(AssistantComplete(
                    fullText: accumulatedText,
                    timestamp: now,
                    stopReason: .endTurn
                )))
            }

            // Token usage
            if let usage = event.usage {
                events.append(.tokenUsage(TokenUsage(
                    inputTokens: usage.input_tokens,
                    outputTokens: usage.output_tokens,
                    cacheReadTokens: nil,
                    cacheWriteTokens: nil,
                    totalTokens: usage.input_tokens + usage.output_tokens,
                    timestamp: now
                )))
            }

            // Session ended
            events.append(.sessionEnded(SessionEndedEvent(
                sessionId: threadId ?? UUID().uuidString,
                reason: "completed",
                timestamp: now
            )))

            return events

        default:
            return []
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
        case .streaming, .toolUse, .sessionPersistence, .sandboxMode:
            return true
        case .mcpSupport, .multiModal, .contextCompaction:
            return false
        }
    }
}
