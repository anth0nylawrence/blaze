import Foundation
import os.log

private let adapterLog = OSLog(subsystem: "com.cogit0.Blaze", category: "Adapter")

// MARK: - Claude Code Adapter

/// EngineAdapter implementation for Claude Code CLI.
/// Uses headless mode with stream-json output format.
/// Supports PTY mode for bidirectional communication (tool prompts).
@MainActor
final class ClaudeCodeAdapter: EngineAdapter {
    let engineType: EngineType = .claude

    // MARK: - Process Runners

    /// Pipe-based runner for non-interactive turns
    private let processRunner: ProcessRunner

    /// PTY-based runner for interactive turns (stdin required)
    private var ptyRunner: PtyProcessRunner?

    /// Stdin writer for sending tool results
    private var stdinWriter: StdinWriter?

    // MARK: - Parsers & Mappers

    private let parser: NDJSONParser
    private let mapper: ClaudeEventMapper
    private var currentTask: Task<Void, Never>?

    /// Cached CLI path from validation (nil until validateInstallation succeeds)
    private var validatedCLIPath: String?

    /// Session ID from system.init event (required for tool_result envelope)
    private(set) var sessionId: String?

    /// Whether the current turn is in interactive (PTY) mode
    private var isInteractiveMode: Bool = false

    // Minimum supported version
    private static let minimumVersion = "1.0.0"

    init() {
        self.processRunner = ProcessRunner()
        self.parser = NDJSONParser()
        self.mapper = ClaudeEventMapper()
    }

    // MARK: - Installation Validation

    func validateInstallation() async throws -> CLIInfo {
        // Check if claude CLI exists
        let whichProcess = Process()
        let pipe = Pipe()

        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]
        whichProcess.standardOutput = pipe
        whichProcess.standardError = pipe

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
        } catch {
            throw EngineError.cliNotFound(.claude)
        }

        guard whichProcess.terminationStatus == 0 else {
            throw EngineError.cliNotFound(.claude)
        }

        let pathData = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: pathData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "/usr/local/bin/claude"

        // Get version
        let version = try await getVersion(path: path)

        // Determine capabilities
        let capabilities: Set<EngineFeature> = [
            .streaming,
            .toolUse,
            .multiModal,
            .mcpSupport,
            .contextCompaction
        ]

        // Cache the validated path for use in startTurn
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

        // Parse version from output (e.g., "claude 1.0.0")
        let components = output.split(separator: " ")
        if components.count >= 2 {
            return String(components[1])
        }
        return output
    }

    // MARK: - Turn Execution

    func startTurn(prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        // Ensure we have a valid CLI path
        guard let cliPath = validatedCLIPath else {
            // Try to find it now
            let whichProcess = Process()
            let pipe = Pipe()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = ["claude"]
            whichProcess.standardOutput = pipe
            whichProcess.standardError = pipe

            do {
                try whichProcess.run()
                whichProcess.waitUntilExit()
            } catch {
                throw EngineError.cliNotFound(.claude)
            }

            guard whichProcess.terminationStatus == 0 else {
                throw EngineError.cliNotFound(.claude)
            }

            let pathData = pipe.fileHandleForReading.readDataToEndOfFile()
            let foundPath = String(data: pathData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let foundPath, !foundPath.isEmpty else {
                throw EngineError.cliNotFound(.claude)
            }

            validatedCLIPath = foundPath
            return try await startTurnWithPath(foundPath, prompt: prompt, context: context)
        }

        return try await startTurnWithPath(cliPath, prompt: prompt, context: context)
    }

    private func startTurnWithPath(_ cliPath: String, prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        // Reset state
        await parser.reset()
        await mapper.reset()
        sessionId = nil

        // Use PTY mode if stdin is enabled
        if context.enableStdin {
            return try await startPtyTurn(cliPath: cliPath, prompt: prompt, context: context)
        }

        // Build arguments for pipe-based (non-interactive) mode
        // Note: --verbose is required for stream-json with -p (print mode)
        var args = ["-p", prompt, "--output-format", "stream-json", "--verbose"]

        // Add allowed tools if specified
        if let tools = context.allowedTools, !tools.isEmpty {
            args += ["--allowedTools", tools.joined(separator: ",")]
        }

        // Configure process
        let config = ProcessRunner.Configuration(
            executable: cliPath,
            arguments: args,
            workingDirectory: context.projectPath,
            timeout: 600 // 10 minute timeout
        )

        isInteractiveMode = false

        return AsyncStream { continuation in
            currentTask = Task {
                do {
                    let processStream = await processRunner.run(config)

                    for try await output in processStream {
                        switch output {
                        case .stdout(let data):
                            let events = await parser.parse(chunk: data)
                            for claudeEvent in events {
                                let normalized = await mapper.map(claudeEvent)
                                for event in normalized {
                                    continuation.yield(event)
                                }
                            }

                        case .stderr(let data):
                            // Log but continue
                            if let text = String(data: data, encoding: .utf8) {
                                print("[ClaudeCodeAdapter] stderr: \(text)")
                            }

                        case .exit(let code):
                            // Flush remaining
                            if let final = await parser.flush() {
                                let normalized = await mapper.map(final)
                                for event in normalized {
                                    continuation.yield(event)
                                }
                            }

                            if code != 0 {
                                print("[ClaudeCodeAdapter] Exit code: \(code)")
                            }
                        }
                    }
                } catch {
                    // Emit error event
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

    // MARK: - PTY-Based Turn (Interactive Mode)

    /// Start a turn using PTY runner for bidirectional communication
    private func startPtyTurn(cliPath: String, prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent> {
        // Build arguments with stdin support
        var args = ["-p", prompt, "--output-format", "stream-json", "--input-format", "stream-json", "--verbose"]

        // Add allowed tools if specified
        if let tools = context.allowedTools, !tools.isEmpty {
            args += ["--allowedTools", tools.joined(separator: ",")]
        }

        // Create PTY runner
        let runner = PtyProcessRunner()
        self.ptyRunner = runner

        // Spawn process with PTY
        try runner.spawn(
            executable: cliPath,
            arguments: args,
            workingDirectory: context.projectPath
        )

        // Create stdin writer
        self.stdinWriter = StdinWriter(runner: runner)
        isInteractiveMode = true

        return AsyncStream { [weak self] continuation in
            self?.currentTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                os_log(.info, log: adapterLog, "PTY polling loop started")
                var pollCount = 0
                var totalEventsYielded = 0

                // Poll for output until process exits
                while runner.isRunning {
                    pollCount += 1
                    let lines = runner.readLines()

                    if !lines.isEmpty {
                        os_log(.debug, log: adapterLog, "Poll #%d: got %d line(s)", pollCount, lines.count)
                    }

                    for line in lines {
                        // Parse and map each NDJSON line
                        // Add newline back - readLines() strips it, but parser needs it
                        if let data = (line + "\n").data(using: .utf8) {
                            let events = await self.parser.parse(chunk: data)
                            for claudeEvent in events {
                                // Extract session_id from system.init
                                await self.extractSessionId(from: claudeEvent)

                                let normalized = await self.mapper.map(claudeEvent)
                                for event in normalized {
                                    totalEventsYielded += 1
                                    os_log(.debug, log: adapterLog, "Yielding event #%d type=%{public}@", totalEventsYielded, String(describing: type(of: event)))
                                    continuation.yield(event)
                                }
                            }
                        }
                    }

                    // Small delay between polls
                    try? await Task.sleep(for: .milliseconds(50))
                }

                os_log(.info, log: adapterLog, "PTY polling loop EXITED after %d polls, yielded %d events - isRunning became false", pollCount, totalEventsYielded)

                // Drain remaining output
                let remainingLines = runner.readLines()
                for line in remainingLines {
                    // Add newline back for parser
                    if let data = (line + "\n").data(using: .utf8) {
                        let events = await self.parser.parse(chunk: data)
                        for claudeEvent in events {
                            await self.extractSessionId(from: claudeEvent)
                            let normalized = await self.mapper.map(claudeEvent)
                            for event in normalized {
                                totalEventsYielded += 1
                                os_log(.debug, log: adapterLog, "Yielding drain event #%d type=%{public}@", totalEventsYielded, String(describing: type(of: event)))
                                continuation.yield(event)
                            }
                        }
                    }
                }

                // Flush parser
                if let final = await self.parser.flush() {
                    let normalized = await self.mapper.map(final)
                    for event in normalized {
                        totalEventsYielded += 1
                        os_log(.debug, log: adapterLog, "Yielding flush event #%d type=%{public}@", totalEventsYielded, String(describing: type(of: event)))
                        continuation.yield(event)
                    }
                }

                os_log(.info, log: adapterLog, "Adapter finished. Total events yielded: %d", totalEventsYielded)
                continuation.finish()
            }
        }
    }

    /// Extract session_id from system.init event
    private func extractSessionId(from event: ClaudeStreamEvent) async {
        if case .systemInit(let initEvent) = event {
            self.sessionId = initEvent.sessionId
        }
    }

    // MARK: - Tool Result Submission

    /// Send a tool result back to Claude via stdin
    /// - Parameters:
    ///   - toolUseId: The tool_use ID from the tool call
    ///   - content: The response content (option ID or free text)
    ///   - isError: Whether this is an error response
    func sendToolResult(toolUseId: String, content: String, isError: Bool = false) async throws {
        print("[Adapter] sendToolResult called - toolUseId=\(toolUseId.prefix(12))...")
        print("[Adapter] sendToolResult - isInteractiveMode=\(isInteractiveMode), ptyRunner exists=\(ptyRunner != nil)")

        if let runner = ptyRunner {
            print("[Adapter] sendToolResult - runner.isRunning=\(runner.isRunning)")
        }

        guard isInteractiveMode else {
            print("[Adapter] sendToolResult FAILED: not in interactive mode")
            throw EngineError.unknown("Cannot send tool result: not in interactive mode")
        }

        guard let writer = stdinWriter else {
            print("[Adapter] sendToolResult FAILED: stdin writer not available")
            throw EngineError.unknown("Cannot send tool result: stdin writer not available")
        }

        // Build envelope using confirmed C_session_id variant
        let envelope = ToolResultEnvelope(
            sessionId: sessionId,
            parentToolUseId: nil,  // Confirmed: always null
            toolUseId: toolUseId,
            content: content,
            isError: isError
        )

        print("[Adapter] sendToolResult - about to write envelope")
        try await writer.sendJSONLine(envelope)
        print("[Adapter] sendToolResult - SUCCESS")
    }

    // MARK: - Cancellation

    func cancelTurn() async {
        currentTask?.cancel()

        if isInteractiveMode {
            // Terminate PTY runner
            ptyRunner?.terminate()
            ptyRunner = nil
            stdinWriter = nil
        } else {
            await processRunner.cancel()
        }

        isInteractiveMode = false
    }

    // MARK: - Feature Support

    /// Claude CLI headless mode auto-denies AskUserQuestion, so tool_result is not honored.
    var supportsAskUserQuestionToolResults: Bool { false }

    func supports(feature: EngineFeature) -> Bool {
        switch feature {
        case .streaming, .toolUse, .multiModal, .mcpSupport, .contextCompaction:
            return true
        case .sessionPersistence, .sandboxMode:
            return false
        }
    }
}
