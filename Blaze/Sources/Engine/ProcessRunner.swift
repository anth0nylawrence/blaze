import Foundation

// MARK: - Process Runner

/// Manages spawning and monitoring CLI child processes.
/// Handles stdout/stderr streaming, cancellation, and timeouts.
actor ProcessRunner {
    private var runningProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var isCancelled: Bool = false

    /// Output from a process
    enum ProcessOutput: Sendable {
        case stdout(Data)
        case stderr(Data)
        case exit(Int32)
    }

    /// Configuration for running a process
    struct Configuration: Sendable {
        let executable: String
        let arguments: [String]
        let workingDirectory: String?
        let environment: [String: String]?
        let timeout: TimeInterval?

        init(
            executable: String,
            arguments: [String] = [],
            workingDirectory: String? = nil,
            environment: [String: String]? = nil,
            timeout: TimeInterval? = nil
        ) {
            self.executable = executable
            self.arguments = arguments
            self.workingDirectory = workingDirectory
            self.environment = environment
            self.timeout = timeout
        }
    }

    /// Run a process and stream its output
    func run(_ config: Configuration) -> AsyncThrowingStream<ProcessOutput, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.executeProcess(config, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func executeProcess(
        _ config: Configuration,
        continuation: AsyncThrowingStream<ProcessOutput, Error>.Continuation
    ) async throws {
        isCancelled = false

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        // Store references for cancellation
        runningProcess = process
        outputPipe = stdout
        errorPipe = stderr

        // Configure process
        process.executableURL = URL(fileURLWithPath: config.executable)
        process.arguments = config.arguments
        process.standardOutput = stdout
        process.standardError = stderr

        if let workingDir = config.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        if let env = config.environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                processEnv[key] = value
            }
            process.environment = processEnv
        }

        // Setup output handlers
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                continuation.yield(.stdout(data))
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                continuation.yield(.stderr(data))
            }
        }

        // Start timeout task if configured
        let timeoutTask: Task<Void, Never>?
        if let timeout = config.timeout {
            timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeout))
                if !Task.isCancelled {
                    await self.cancel()
                }
            }
        } else {
            timeoutTask = nil
        }

        // Launch process
        do {
            try process.run()
        } catch {
            timeoutTask?.cancel()
            cleanup()
            throw EngineError.processSpawnFailed(underlying: error)
        }

        // Wait for completion
        process.waitUntilExit()
        timeoutTask?.cancel()

        // Cleanup handlers
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil

        // Read any remaining data
        let remainingStdout = stdout.fileHandleForReading.readDataToEndOfFile()
        let remainingStderr = stderr.fileHandleForReading.readDataToEndOfFile()

        if !remainingStdout.isEmpty {
            continuation.yield(.stdout(remainingStdout))
        }
        if !remainingStderr.isEmpty {
            continuation.yield(.stderr(remainingStderr))
        }

        // Yield exit status
        let exitCode = process.terminationStatus
        continuation.yield(.exit(exitCode))

        cleanup()

        if isCancelled {
            continuation.finish(throwing: EngineError.cancelled)
        } else {
            continuation.finish()
        }
    }

    /// Cancel the running process
    func cancel() {
        isCancelled = true

        guard let process = runningProcess, process.isRunning else { return }

        // First try SIGINT for graceful shutdown
        process.interrupt()

        // Give it 2 seconds to terminate gracefully
        Task {
            try? await Task.sleep(for: .seconds(2))
            if await self.runningProcess?.isRunning == true {
                // Force kill if still running
                await self.runningProcess?.terminate()
            }
        }
    }

    private func cleanup() {
        runningProcess = nil
        outputPipe = nil
        errorPipe = nil
    }

    /// Check if a process is currently running
    var isRunning: Bool {
        runningProcess?.isRunning ?? false
    }
}

// MARK: - Convenience Extensions

extension ProcessRunner.Configuration {
    /// Create a configuration for running the Claude CLI
    static func claude(
        prompt: String,
        projectPath: String? = nil,
        allowedTools: Set<String>? = nil,
        outputFormat: String = "stream-json"
    ) -> Self {
        // Note: --verbose is required for stream-json with -p (print mode)
        var args = ["-p", prompt, "--output-format", outputFormat, "--verbose"]

        if let tools = allowedTools, !tools.isEmpty {
            args += ["--allowedTools", tools.joined(separator: ",")]
        }

        // Find claude CLI dynamically using which
        let cliPath = Self.findClaudePath() ?? "/usr/local/bin/claude"

        return Self(
            executable: cliPath,
            arguments: args,
            workingDirectory: projectPath,
            timeout: 300 // 5 minute default timeout
        )
    }

    /// Find the Claude CLI path using `which`
    private static func findClaudePath() -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }

    /// Create a configuration for running the Gemini CLI
    static func gemini(
        prompt: String,
        projectPath: String? = nil,
        outputFormat: String = "stream-json"
    ) -> Self {
        Self(
            executable: "/usr/local/bin/gemini",
            arguments: ["-p", prompt, "--output-format", outputFormat],
            workingDirectory: projectPath,
            timeout: 300
        )
    }

    /// Create a configuration for running the Codex CLI
    static func codex(
        prompt: String,
        projectPath: String? = nil
    ) -> Self {
        Self(
            executable: "/usr/local/bin/codex",
            arguments: ["exec", "--json", prompt],
            workingDirectory: projectPath,
            timeout: 300
        )
    }
}
