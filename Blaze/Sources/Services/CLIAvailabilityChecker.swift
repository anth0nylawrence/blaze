import Foundation
import os.log

// MARK: - Version Constants

/// Minimum Codex version required for app-server mode support.
/// App-server mode provides structured JSON streaming that Blaze requires.
let CODEX_MIN_APP_SERVER_VERSION = "0.1.0"

// MARK: - Semver

/// Semantic version representation for CLI version comparison.
struct Semver: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    /// Parse a version string like "1.2.3" or "v1.2.3" into components.
    /// Returns nil if parsing fails.
    init?(_ string: String) {
        // Strip leading 'v' if present
        let cleaned = string.hasPrefix("v") ? String(string.dropFirst()) : string

        // Split by dots and parse
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }

        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: Semver, rhs: Semver) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    var description: String { "\(major).\(minor).\(patch)" }
}

// MARK: - CLI Status

/// Status of a CLI installation.
///
/// **Cases:**
/// - `available`: CLI found and version successfully retrieved
/// - `notInstalled`: CLI binary not found on PATH
/// - `notExecutable`: CLI exists but cannot be executed
/// - `versionCheckFailed`: CLI exists but version command failed
enum CLIStatus: Equatable, Sendable {
    case available(version: String, path: String)
    case notInstalled
    case notExecutable
    case versionCheckFailed

    /// Whether the CLI is usable for session creation
    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// Human-readable description for UI display
    var displayDescription: String {
        switch self {
        case .available(let version, _):
            return "Version \(version)"
        case .notInstalled:
            return "Not installed"
        case .notExecutable:
            return "Not executable"
        case .versionCheckFailed:
            return "Unable to verify"
        }
    }

    /// Version string if available
    var version: String? {
        if case .available(let version, _) = self { return version }
        return nil
    }

    /// Path to CLI binary if found
    var path: String? {
        if case .available(_, let path) = self { return path }
        return nil
    }

    /// Parsed semantic version if available
    var semver: Semver? {
        guard let version = version else { return nil }
        return Semver(version)
    }

    /// Check if version meets or exceeds minimum requirement.
    ///
    /// - Parameter minimum: Minimum version string (e.g., "0.1.0")
    /// - Returns: true if current version >= minimum, false otherwise
    func meetsMinimumVersion(_ minimum: String) -> Bool {
        guard let current = semver,
              let required = Semver(minimum) else {
            return false
        }
        return current >= required
    }

    /// Whether Codex CLI supports app-server mode (structured JSON streaming).
    ///
    /// Returns true if:
    /// - CLI is available AND
    /// - Version >= CODEX_MIN_APP_SERVER_VERSION
    ///
    /// For non-Codex CLIs, this always returns true (they don't need app-server mode).
    /// Use `supportsAppServer(for:)` method on CLIAvailabilityChecker for engine-aware checks.
    var supportsAppServerMode: Bool {
        guard isAvailable else { return false }
        return meetsMinimumVersion(CODEX_MIN_APP_SERVER_VERSION)
    }
}

// MARK: - CLI Availability

/// Result of checking CLI availability
struct CLIAvailability: Sendable {
    let provider: EngineType
    let status: CLIStatus
    let checkedAt: Date

    init(provider: EngineType, status: CLIStatus, checkedAt: Date = Date()) {
        self.provider = provider
        self.status = status
        self.checkedAt = checkedAt
    }

    /// Whether this cached result has expired
    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(checkedAt) > ttl
    }
}

// MARK: - CLI Availability Checker

/// Service that detects installed CLIs via `which` commands and caches results.
///
/// **Usage:**
/// ```swift
/// let checker = CLIAvailabilityChecker.shared
/// let status = await checker.checkAvailability(for: .claude)
/// let allStatuses = await checker.checkAllProviders()
/// ```
///
/// **Thread Safety:** Uses actor isolation for safe concurrent access.
/// **Caching:** Results cached with configurable TTL (default 30s).
actor CLIAvailabilityChecker {

    // MARK: - Singleton

    /// Shared instance for app-wide usage
    static let shared = CLIAvailabilityChecker()

    // MARK: - Configuration

    /// Cache time-to-live in seconds (default: 30 seconds)
    var cacheTTL: TimeInterval = 30.0

    /// Timeout for shell commands in seconds (default: 2 seconds)
    var commandTimeout: TimeInterval = 2.0

    // MARK: - Private State

    private var cache: [EngineType: CLIAvailability] = [:]
    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "CLIAvailabilityChecker")

    // MARK: - API

    /// Check availability for a single provider.
    ///
    /// Returns cached result if valid, otherwise performs fresh check.
    ///
    /// - Parameter provider: The engine type to check
    /// - Returns: CLI status for the provider
    func checkAvailability(for provider: EngineType) async -> CLIStatus {
        // Check cache first
        if let cached = cache[provider], !cached.isExpired(ttl: cacheTTL) {
            logger.debug("Cache hit for \(provider.rawValue)")
            return cached.status
        }

        logger.debug("Checking availability for \(provider.rawValue)")
        let status = await performCheck(for: provider)

        // Update cache
        cache[provider] = CLIAvailability(provider: provider, status: status)

        return status
    }

    /// Check availability for all providers concurrently.
    ///
    /// - Returns: Dictionary mapping each engine type to its status
    func checkAllProviders() async -> [EngineType: CLIStatus] {
        await withTaskGroup(of: (EngineType, CLIStatus).self) { group in
            for provider in EngineType.allCases {
                group.addTask {
                    let status = await self.checkAvailability(for: provider)
                    return (provider, status)
                }
            }

            var results: [EngineType: CLIStatus] = [:]
            for await (provider, status) in group {
                results[provider] = status
            }
            return results
        }
    }

    /// Invalidate all cached results, forcing fresh checks on next call.
    func invalidateCache() {
        cache.removeAll()
        logger.info("Cache invalidated")
    }

    /// Invalidate cached result for a specific provider.
    func invalidateCache(for provider: EngineType) {
        cache.removeValue(forKey: provider)
        logger.info("Cache invalidated for \(provider.rawValue)")
    }

    /// Check if Codex supports app-server mode (version-gated feature).
    ///
    /// For Codex: requires version >= CODEX_MIN_APP_SERVER_VERSION
    /// For other CLIs: returns true if available (they don't need app-server mode)
    ///
    /// - Parameter provider: The engine type to check
    /// - Returns: true if the CLI supports structured JSON streaming for Blaze
    func supportsAppServer(for provider: EngineType) async -> Bool {
        let status = await checkAvailability(for: provider)

        switch provider {
        case .codex:
            let supported = status.supportsAppServerMode
            if !supported && status.isAvailable {
                let versionStr = status.version ?? "unknown"
                logger.warning(
                    "Codex CLI version \(versionStr) does not support app-server mode. Minimum required: \(CODEX_MIN_APP_SERVER_VERSION)"
                )
            }
            return supported
        case .claude, .gemini:
            // These CLIs always support structured output when available
            return status.isAvailable
        }
    }

    /// Get a user-friendly message explaining why Codex app-server mode is unavailable.
    ///
    /// Returns nil if app-server mode IS supported or if CLI isn't installed.
    func codexAppServerUnavailableReason() async -> String? {
        let status = await checkAvailability(for: .codex)

        guard status.isAvailable else {
            // CLI not installed - different problem
            return nil
        }

        guard !status.supportsAppServerMode else {
            // App-server mode is supported
            return nil
        }

        let currentVersion = status.version ?? "unknown"
        return "Codex CLI version \(currentVersion) does not support app-server mode. " +
               "Please upgrade to version \(CODEX_MIN_APP_SERVER_VERSION) or later for full Blaze integration."
    }

    // MARK: - Private Implementation

    /// Perform the actual CLI availability check.
    private func performCheck(for provider: EngineType) async -> CLIStatus {
        let binaryName = provider.cliCommand

        // Step 1: Find CLI path using `which`
        let pathResult = await runWhichCommand(for: binaryName)

        guard case .success(let path) = pathResult else {
            logger.info("\(provider.rawValue) CLI not found on PATH")
            return .notInstalled
        }

        // Step 2: Verify the binary is executable
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: path) else {
            logger.warning("\(provider.rawValue) CLI at \(path) is not executable")
            return .notExecutable
        }

        // Step 3: Get version string
        let versionResult = await runVersionCommand(at: path, for: provider)

        switch versionResult {
        case .success(let version):
            logger.info("\(provider.rawValue) CLI available: \(version) at \(path)")
            return .available(version: version, path: path)
        case .failure(let error):
            logger.warning("\(provider.rawValue) version check failed: \(error.localizedDescription)")
            return .versionCheckFailed
        }
    }

    /// Run `which <binary>` to find CLI path.
    private func runWhichCommand(for binaryName: String) async -> Result<String, Error> {
        await runShellCommand(
            executable: "/usr/bin/which",
            arguments: [binaryName]
        )
    }

    /// Run `<cli> --version` to get version string.
    private func runVersionCommand(at path: String, for provider: EngineType) async -> Result<String, Error> {
        // Different CLIs use different version flags
        let versionFlag = versionFlag(for: provider)

        let result = await runShellCommand(
            executable: path,
            arguments: [versionFlag]
        )

        return result.flatMap { output in
            if let version = parseVersionString(output, for: provider) {
                return .success(version)
            } else {
                return .failure(CLICheckerError.versionParsingFailed)
            }
        }
    }

    /// Run a shell command with timeout.
    private func runShellCommand(
        executable: String,
        arguments: [String]
    ) async -> Result<String, Error> {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            // Set up timeout
            let timeoutTask = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + commandTimeout,
                execute: timeoutTask
            )

            do {
                try process.run()
                process.waitUntilExit()
                timeoutTask.cancel()

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: .failure(
                        CLICheckerError.commandFailed(exitCode: process.terminationStatus)
                    ))
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                continuation.resume(returning: .success(output))
            } catch {
                timeoutTask.cancel()
                continuation.resume(returning: .failure(error))
            }
        }
    }

    /// Get the version flag for a specific provider.
    private func versionFlag(for provider: EngineType) -> String {
        switch provider {
        case .claude:
            return "--version"
        case .gemini:
            return "--version"
        case .codex:
            return "--version"
        }
    }

    /// Parse version string from CLI output.
    ///
    /// Different CLIs have different output formats:
    /// - Claude: "Claude Code v1.0.25 (claude-code)"
    /// - Gemini: "gemini-cli 0.1.0"
    /// - Codex: "codex version 0.1.0"
    private func parseVersionString(_ output: String, for provider: EngineType) -> String? {
        // Get first line of output
        let firstLine = output.components(separatedBy: .newlines).first ?? output

        // Try to extract version using common patterns
        switch provider {
        case .claude:
            // Match "v1.0.25" or similar
            if let range = firstLine.range(of: #"v?(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                return String(firstLine[range])
            }
        case .gemini:
            // Match version number
            if let range = firstLine.range(of: #"(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                return String(firstLine[range])
            }
        case .codex:
            // Match version number
            if let range = firstLine.range(of: #"(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                return String(firstLine[range])
            }
        }

        // Fallback: return first line if it looks like a version
        if !firstLine.isEmpty && firstLine.count < 100 {
            return firstLine
        }

        return nil
    }
}

// MARK: - Errors

/// Errors specific to CLI availability checking.
enum CLICheckerError: Error, LocalizedError {
    case commandFailed(exitCode: Int32)
    case versionParsingFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .commandFailed(let exitCode):
            return "Command failed with exit code \(exitCode)"
        case .versionParsingFailed:
            return "Failed to parse version string"
        case .timeout:
            return "Command timed out"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension CLIAvailabilityChecker {
    /// Create a checker with preset statuses for previews/testing.
    static func mock(statuses: [EngineType: CLIStatus]) -> CLIAvailabilityChecker {
        let checker = CLIAvailabilityChecker()
        Task {
            for (provider, status) in statuses {
                await checker.setMockStatus(provider: provider, status: status)
            }
        }
        return checker
    }

    /// Set a mock status for a provider (testing only).
    func setMockStatus(provider: EngineType, status: CLIStatus) {
        cache[provider] = CLIAvailability(provider: provider, status: status)
    }
}
#endif
