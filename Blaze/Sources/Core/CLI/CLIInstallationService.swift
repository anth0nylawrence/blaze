import Foundation

// MARK: - Installation Errors

/// Errors that can occur during CLI installation
public enum CLIInstallationError: Error, LocalizedError, Sendable {
    case cliNotSupported(String)
    case noInstallCommand(CLIType)
    case dependencyMissing(DependencyType)
    case processFailure(command: String, exitCode: Int32, output: String)
    case timeout(command: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .cliNotSupported(let name):
            return "CLI '\(name)' is not supported"
        case .noInstallCommand(let cli):
            return "No install command available for \(cli.displayName)"
        case .dependencyMissing(let dep):
            return "\(dep.displayName) is required but not installed"
        case .processFailure(let command, let exitCode, let output):
            return "Command '\(command)' failed with exit code \(exitCode): \(output)"
        case .timeout(let command):
            return "Command '\(command)' timed out"
        case .cancelled:
            return "Installation was cancelled"
        }
    }
}

// MARK: - CLIInstallationService

/// Thread-safe service for detecting and installing CLI tools.
///
/// Uses Swift actor isolation to ensure safe concurrent access when
/// checking CLI installations and running install commands.
///
/// **E005-F005-S001-T002-A001**
public actor CLIInstallationService {

    // MARK: - Properties

    /// Shared singleton instance
    public static let shared = CLIInstallationService()

    /// Environment variables for subprocess execution
    private var environment: [String: String]

    /// Timeout for detection commands (seconds)
    private let detectionTimeout: TimeInterval = 10

    /// Timeout for installation commands (seconds)
    private let installationTimeout: TimeInterval = 300

    // MARK: - Initialization

    public init() {
        // Inherit current environment and ensure PATH includes common locations
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "\(NSHomeDirectory())/.nvm/current/bin",
            "\(NSHomeDirectory())/.npm-global/bin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (additionalPaths + [existingPath]).joined(separator: ":")
        self.environment = env
    }

    // MARK: - Detection

    /// Detects whether a specific CLI is installed.
    ///
    /// Runs `which <executable>` to find the path, then `<executable> --version`
    /// to determine the installed version.
    ///
    /// - Parameter cli: The CLI type to detect
    /// - Returns: Detection result with installation status, version, and path
    public func detectCLI(_ cli: CLIType) async -> CLIDetectionResult {
        let executable = cli.executable

        // First, find the path using `which`
        let whichResult = await runCommand("which", arguments: [executable])

        guard whichResult.exitCode == 0, let path = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return CLIDetectionResult(
                cliName: executable,
                isInstalled: false,
                version: nil,
                path: nil
            )
        }

        // Found the CLI, now get the version
        let versionResult = await runCommand(path, arguments: [cli.versionFlag])

        let version: String?
        if versionResult.exitCode == 0 {
            version = parseVersion(from: versionResult.output)
        } else {
            version = nil
        }

        return CLIDetectionResult(
            cliName: executable,
            isInstalled: true,
            version: version,
            path: path
        )
    }

    /// Detects all supported CLI tools.
    ///
    /// Runs detection for each `CLIType` case concurrently.
    ///
    /// - Returns: Array of detection results for all CLI types
    public func detectAllCLIs() async -> [CLIDetectionResult] {
        await withTaskGroup(of: CLIDetectionResult.self) { group in
            for cli in CLIType.allCases {
                group.addTask {
                    await self.detectCLI(cli)
                }
            }

            var results: [CLIDetectionResult] = []
            for await result in group {
                results.append(result)
            }

            // Sort by CLI type order for consistent UI
            let order = CLIType.allCases.map(\.executable)
            return results.sorted { order.firstIndex(of: $0.cliName) ?? 0 < order.firstIndex(of: $1.cliName) ?? 0 }
        }
    }

    // MARK: - Dependency Checking

    /// Checks whether a dependency is installed.
    ///
    /// Runs the dependency's check command and verifies it succeeds.
    ///
    /// - Parameter dep: The dependency type to check
    /// - Returns: `true` if the dependency is installed and working
    public func checkDependency(_ dep: DependencyType) async -> Bool {
        let result = await runShellCommand(dep.checkCommand)
        return result.exitCode == 0
    }

    /// Checks all dependencies for a CLI.
    ///
    /// - Parameter cli: The CLI to check dependencies for
    /// - Returns: Array of tuples with dependency and its installation status
    public func checkDependencies(for cli: CLIType) async -> [(DependencyType, Bool)] {
        await withTaskGroup(of: (DependencyType, Bool).self) { group in
            for dep in cli.dependencies {
                group.addTask {
                    let isInstalled = await self.checkDependency(dep)
                    return (dep, isInstalled)
                }
            }

            var results: [(DependencyType, Bool)] = []
            for await result in group {
                results.append(result)
            }

            // Sort by dependency order for consistent output
            let order = cli.dependencies
            return results.sorted { order.firstIndex(of: $0.0) ?? 0 < order.firstIndex(of: $1.0) ?? 0 }
        }
    }

    // MARK: - Installation

    /// Installs a CLI tool.
    ///
    /// Verifies dependencies are met, then executes the install command
    /// while streaming progress updates to the handler.
    ///
    /// - Parameters:
    ///   - cli: The CLI type to install
    ///   - progressHandler: Callback for progress updates (called on arbitrary thread)
    /// - Throws: `CLIInstallationError` if installation fails
    public func install(
        _ cli: CLIType,
        progressHandler: @escaping @Sendable (InstallProgress) -> Void
    ) async throws {
        let startTime = Date()

        // Step 1: Verify install command exists
        guard let installCmd = cli.installCommand else {
            throw CLIInstallationError.noInstallCommand(cli)
        }

        let totalSteps = 3
        var outputLines: [String] = []

        func makeProgress(step: Int, description: String) -> InstallProgress {
            InstallProgress(
                currentStep: step,
                totalSteps: totalSteps,
                stepDescription: description,
                elapsedTime: Date().timeIntervalSince(startTime),
                output: outputLines
            )
        }

        // Step 1: Check dependencies
        progressHandler(makeProgress(step: 1, description: "Checking dependencies..."))

        let depResults = await checkDependencies(for: cli)
        for (dep, isInstalled) in depResults {
            if isInstalled {
                outputLines.append("[OK] \(dep.displayName) is installed")
            } else {
                outputLines.append("[MISSING] \(dep.displayName) is not installed")
                progressHandler(makeProgress(step: 1, description: "Missing dependency: \(dep.displayName)"))
                throw CLIInstallationError.dependencyMissing(dep)
            }
        }

        progressHandler(makeProgress(step: 1, description: "Dependencies verified"))

        // Step 2: Run installation
        progressHandler(makeProgress(step: 2, description: "Installing \(cli.displayName)..."))
        outputLines.append("Running: \(installCmd.command)")

        let installResult = await runShellCommand(
            installCmd.command,
            timeout: installationTimeout
        ) { line in
            outputLines.append(line)
            progressHandler(makeProgress(step: 2, description: "Installing \(cli.displayName)..."))
        }

        if installResult.exitCode != 0 {
            let errorOutput = installResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            outputLines.append("[ERROR] Installation failed with exit code \(installResult.exitCode)")
            progressHandler(makeProgress(step: 2, description: "Installation failed"))
            throw CLIInstallationError.processFailure(
                command: installCmd.command,
                exitCode: installResult.exitCode,
                output: errorOutput
            )
        }

        outputLines.append("[OK] Installation command completed")

        // Step 3: Verify installation
        progressHandler(makeProgress(step: 3, description: "Verifying installation..."))

        let detection = await detectCLI(cli)
        if detection.isInstalled {
            outputLines.append("[OK] \(cli.displayName) verified at \(detection.path ?? "unknown path")")
            if let version = detection.version {
                outputLines.append("[OK] Version: \(version)")
            }
            progressHandler(makeProgress(step: 3, description: "Installation complete"))
        } else {
            outputLines.append("[WARNING] CLI not found after installation - may need shell restart")
            progressHandler(makeProgress(step: 3, description: "Installation may need shell restart"))
        }
    }

    // MARK: - Private Helpers

    /// Result of a shell command execution
    private struct CommandResult {
        let exitCode: Int32
        let output: String
    }

    /// Runs a command with arguments directly (not through shell).
    private func runCommand(
        _ command: String,
        arguments: [String],
        timeout: TimeInterval? = nil
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe

            var outputData = Data()

            do {
                try process.run()

                // Read output
                outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(
                    exitCode: process.terminationStatus,
                    output: output
                ))
            } catch {
                continuation.resume(returning: CommandResult(
                    exitCode: -1,
                    output: error.localizedDescription
                ))
            }
        }
    }

    /// Runs a shell command string through /bin/bash.
    private func runShellCommand(
        _ command: String,
        timeout: TimeInterval? = nil,
        outputHandler: ((String) -> Void)? = nil
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe

            // Use thread-safe storage for streaming output
            let outputCollector = OutputCollector()

            // Handle streaming output if handler provided
            if let handler = outputHandler {
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }

                    if let str = String(data: data, encoding: .utf8) {
                        let lines = outputCollector.append(str)
                        for line in lines {
                            handler(line)
                        }
                    }
                }
            }

            do {
                try process.run()

                if outputHandler == nil {
                    // Read all at once if no streaming handler
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    process.waitUntilExit()
                    continuation.resume(returning: CommandResult(
                        exitCode: process.terminationStatus,
                        output: output
                    ))
                } else {
                    // Wait for process to complete with streaming
                    process.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil

                    let output = outputCollector.flush()
                    continuation.resume(returning: CommandResult(
                        exitCode: process.terminationStatus,
                        output: output
                    ))
                }
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: CommandResult(
                    exitCode: -1,
                    output: error.localizedDescription
                ))
            }
        }
    }

    /// Parses a version string from command output.
    ///
    /// Handles common formats:
    /// - "1.0.17" (plain)
    /// - "v1.0.17" (prefixed)
    /// - "claude version 1.0.17" (with label)
    private func parseVersion(from output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern: optional prefix, then semver-like digits
        let pattern = #"v?(\d+\.\d+(?:\.\d+)?(?:-[a-zA-Z0-9.]+)?)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let versionRange = Range(match.range(at: 1), in: trimmed) else {
            // Fallback: return first non-empty line
            return trimmed.components(separatedBy: .newlines).first?.nilIfEmpty
        }

        return String(trimmed[versionRange])
    }
}

// MARK: - OutputCollector

/// Thread-safe collector for streaming process output.
/// Uses a lock to safely accumulate output from readabilityHandler callbacks.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var lines: [String] = []

    /// Appends new output and returns any complete lines.
    func append(_ str: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        buffer += str
        var newLines: [String] = []

        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            lines.append(line)
            newLines.append(line)
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
        }

        return newLines
    }

    /// Flushes remaining buffer and returns all collected output.
    func flush() -> String {
        lock.lock()
        defer { lock.unlock() }

        if !buffer.isEmpty {
            lines.append(buffer)
            buffer = ""
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - String Extension

private extension String {
    /// Returns nil if the string is empty after trimming whitespace.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
