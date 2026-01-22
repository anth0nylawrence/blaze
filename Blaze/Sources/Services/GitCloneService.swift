import Foundation

// MARK: - Git Clone Service

/// Service for cloning Git repositories with progress tracking.
///
/// Supports HTTPS and SSH URLs with:
/// - Progress reporting via callback closure
/// - Shallow clone option for faster setup
/// - Cancellation support
/// - Error handling with typed errors
///
/// **Usage:**
/// ```swift
/// let service = GitCloneService()
/// let destination = try await service.cloneRepository(
///     url: "https://github.com/owner/repo",
///     destination: "/path/to/destination",
///     shallow: true
/// ) { progress in
///     print("Phase: \(progress.phase), \(progress.percent)%")
/// }
/// ```
public actor GitCloneService {

    // MARK: - Types

    /// Progress phases during git clone operation.
    public enum ClonePhase: String, Sendable, CaseIterable {
        case counting = "counting"
        case compressing = "compressing"
        case receiving = "receiving"
        case resolving = "resolving"
        case done = "done"

        public var displayName: String {
            switch self {
            case .counting: return "Counting objects"
            case .compressing: return "Compressing objects"
            case .receiving: return "Receiving objects"
            case .resolving: return "Resolving deltas"
            case .done: return "Clone complete"
            }
        }
    }

    /// Progress information during clone operation.
    public struct CloneProgress: Sendable {
        public let phase: ClonePhase
        public let percent: Int
        public let message: String

        public init(phase: ClonePhase, percent: Int, message: String) {
            self.phase = phase
            self.percent = percent
            self.message = message
        }
    }

    /// Errors that can occur during git clone operations.
    public enum GitCloneError: Error, LocalizedError, Sendable {
        case invalidURL(String)
        case authenticationFailed(String)
        case repositoryNotFound(String)
        case networkError(String)
        case cloneFailed(exitCode: Int, stderr: String)
        case cloneCancelled
        case gitNotInstalled
        case destinationNotAbsolute(String)
        case destinationParentNotFound(String)
        case fileProtocolNotAllowed

        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Invalid Git URL: \(url)"
            case .authenticationFailed(let url):
                return "Authentication failed for repository: \(url). Please check your credentials or SSH key configuration."
            case .repositoryNotFound(let url):
                return "Repository not found: \(url). The repository may be private or the URL may be incorrect."
            case .networkError(let message):
                return "Network error: \(message). Please check your internet connection."
            case .cloneFailed(let exitCode, let stderr):
                return "Clone failed with exit code \(exitCode): \(stderr)"
            case .cloneCancelled:
                return "Clone operation was cancelled"
            case .gitNotInstalled:
                return "Git is not installed. Please install Git to clone repositories."
            case .destinationNotAbsolute(let path):
                return "Destination path must be absolute: \(path)"
            case .destinationParentNotFound(let path):
                return "Parent directory does not exist: \(path)"
            case .fileProtocolNotAllowed:
                return "file:// protocol URLs are not allowed for security reasons"
            }
        }
    }

    // MARK: - Configuration

    /// Configuration for clone operations.
    public struct Configuration: Sendable {
        /// Default timeout for clone operations (5 minutes).
        public static let defaultTimeout: TimeInterval = 300

        /// Timeout in seconds.
        public let timeout: TimeInterval

        public init(timeout: TimeInterval = defaultTimeout) {
            self.timeout = timeout
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let configuration: Configuration
    private var currentProcess: Process?
    private var isCancelled: Bool = false

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Clone a Git repository.
    ///
    /// - Parameters:
    ///   - url: Git repository URL (HTTPS or SSH format)
    ///   - destination: Absolute path where repository will be cloned
    ///   - shallow: If true, clone with `--depth=1` for faster setup
    ///   - progress: Callback for progress updates (called on MainActor)
    /// - Returns: Path to the cloned repository
    /// - Throws: `GitCloneError` on failure
    @discardableResult
    public func cloneRepository(
        url: String,
        destination: String,
        shallow: Bool = false,
        progress: @escaping @Sendable (CloneProgress) -> Void = { _ in }
    ) async throws -> String {
        // Reset state
        isCancelled = false
        currentProcess = nil

        // Validate URL
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        try validateCloneURL(trimmedURL)

        // Validate destination
        try validateDestination(destination)

        // Find git binary
        let gitPath = try await findGitPath()

        // Build arguments
        var args = ["clone", "--progress"]
        if shallow {
            args.append("--depth=1")
        }
        args.append(trimmedURL)
        args.append(destination)

        // Create process
        let process = Process()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        // Set environment for SSH batch mode (fail fast on passphrase prompts)
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
        process.environment = environment

        currentProcess = process

        // Track stderr for error handling using a thread-safe buffer
        let stderrCollector = StderrCollector()

        // Setup stderr handler for progress parsing
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                stderrCollector.append(text)

                // Parse progress from each line
                for line in text.split(separator: "\r", omittingEmptySubsequences: false) {
                    let lineStr = String(line).trimmingCharacters(in: .newlines)
                    if let progressUpdate = self?.parseCloneProgress(lineStr) {
                        Task { @MainActor in
                            progress(progressUpdate)
                        }
                    }
                }
            }
        }

        // Setup timeout task
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(configuration.timeout))
            if !Task.isCancelled {
                await self.cancel()
            }
        }

        // Run the process
        do {
            try process.run()
        } catch {
            timeoutTask.cancel()
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw GitCloneError.cloneFailed(exitCode: -1, stderr: "Failed to spawn git process: \(error)")
        }

        // Wait for completion with cancellation checks
        while process.isRunning {
            try Task.checkCancellation()
            if isCancelled {
                process.terminate()
                try? await cleanup(destination: destination)
                throw GitCloneError.cloneCancelled
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        timeoutTask.cancel()
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        // Read remaining stderr
        let remainingData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if let remaining = String(data: remainingData, encoding: .utf8) {
            stderrCollector.append(remaining)
        }

        // Get final stderr content
        let stderrBuffer = stderrCollector.content

        // Check if cancelled during final cleanup
        if isCancelled {
            try? await cleanup(destination: destination)
            throw GitCloneError.cloneCancelled
        }

        // Check exit status
        let exitCode = Int(process.terminationStatus)
        if exitCode != 0 {
            try? await cleanup(destination: destination)
            throw translateGitError(exitCode: exitCode, stderr: stderrBuffer, url: trimmedURL)
        }

        // Verify .git directory exists
        let gitDir = URL(fileURLWithPath: destination).appendingPathComponent(".git")
        guard fileManager.fileExists(atPath: gitDir.path) else {
            try? await cleanup(destination: destination)
            throw GitCloneError.cloneFailed(
                exitCode: exitCode,
                stderr: "Clone appeared to succeed but .git directory not found"
            )
        }

        // Report completion
        Task { @MainActor in
            progress(CloneProgress(phase: .done, percent: 100, message: "Clone complete"))
        }

        currentProcess = nil
        return destination
    }

    /// Cancel an in-progress clone operation.
    public func cancel() {
        isCancelled = true
        currentProcess?.terminate()
    }

    /// Check if a clone operation is in progress.
    public var isCloning: Bool {
        currentProcess?.isRunning ?? false
    }

    // MARK: - Validation

    /// Validate that a URL is a valid Git clone URL.
    ///
    /// Accepts:
    /// - HTTPS: `https://github.com/owner/repo` or `https://github.com/owner/repo.git`
    /// - SSH: `git@github.com:owner/repo.git`
    ///
    /// - Parameter url: URL to validate
    /// - Throws: `GitCloneError.invalidURL` if URL is invalid
    private nonisolated func validateCloneURL(_ url: String) throws {
        // Check for empty URL
        guard !url.isEmpty else {
            throw GitCloneError.invalidURL("URL cannot be empty")
        }

        // Check for spaces
        guard !url.contains(" ") else {
            throw GitCloneError.invalidURL("URL cannot contain spaces: \(url)")
        }

        // Reject file:// protocol for security
        if url.lowercased().hasPrefix("file://") {
            throw GitCloneError.fileProtocolNotAllowed
        }

        // Check HTTPS pattern: https://host/path
        let httpsPattern = #"^https?://[^\s/]+/.+"#
        if url.range(of: httpsPattern, options: .regularExpression) != nil {
            return
        }

        // Check SSH pattern: git@host:path or ssh://git@host/path
        let sshPattern = #"^(git@[^\s:]+:.+)|(ssh://[^\s]+/.+)$"#
        if url.range(of: sshPattern, options: .regularExpression) != nil {
            return
        }

        throw GitCloneError.invalidURL(url)
    }

    /// Validate destination path.
    private func validateDestination(_ destination: String) throws {
        // Must be absolute
        guard destination.hasPrefix("/") else {
            throw GitCloneError.destinationNotAbsolute(destination)
        }

        // Parent directory must exist
        let parentPath = URL(fileURLWithPath: destination).deletingLastPathComponent().path
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: parentPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GitCloneError.destinationParentNotFound(parentPath)
        }
    }

    // MARK: - Progress Parsing

    /// Parse git clone stderr output for progress information.
    ///
    /// Git outputs progress in format:
    /// - `Counting objects: 100% (123/123), done.`
    /// - `Compressing objects: 100% (45/45), done.`
    /// - `Receiving objects:  45% (123/456), 1.2 MiB | 500.00 KiB/s`
    /// - `Resolving deltas: 100% (789/789), done.`
    ///
    /// - Parameter line: Stderr line to parse
    /// - Returns: CloneProgress if line contains progress info, nil otherwise
    private nonisolated func parseCloneProgress(_ line: String) -> CloneProgress? {
        // Receiving objects pattern
        if line.contains("Receiving objects:") || line.contains("Receiving objects") {
            if let percent = extractPercentage(from: line) {
                return CloneProgress(phase: .receiving, percent: percent, message: "Receiving objects")
            }
        }

        // Resolving deltas pattern
        if line.contains("Resolving deltas:") || line.contains("Resolving deltas") {
            if let percent = extractPercentage(from: line) {
                return CloneProgress(phase: .resolving, percent: percent, message: "Resolving deltas")
            }
        }

        // Counting objects pattern
        if line.contains("Counting objects:") || line.contains("Counting objects") {
            if let percent = extractPercentage(from: line) {
                return CloneProgress(phase: .counting, percent: percent, message: "Counting objects")
            }
            // Git sometimes doesn't report percentage for counting
            return CloneProgress(phase: .counting, percent: 0, message: "Counting objects")
        }

        // Compressing objects pattern
        if line.contains("Compressing objects:") || line.contains("Compressing objects") {
            if let percent = extractPercentage(from: line) {
                return CloneProgress(phase: .compressing, percent: percent, message: "Compressing objects")
            }
        }

        return nil
    }

    /// Extract percentage value from a progress line.
    ///
    /// Handles formats like:
    /// - `Receiving objects:  45% (123/456)`
    /// - `Resolving deltas: 100% (789/789), done.`
    private nonisolated func extractPercentage(from line: String) -> Int? {
        // Pattern: N% where N is 1-3 digits
        let pattern = #"(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
              ),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }

        return Int(line[range])
    }

    // MARK: - Error Translation

    /// Translate git exit code and stderr to typed error.
    private nonisolated func translateGitError(exitCode: Int, stderr: String, url: String) -> GitCloneError {
        let stderrLower = stderr.lowercased()

        // Authentication failure
        if stderrLower.contains("authentication failed") ||
           stderrLower.contains("could not read from remote repository") ||
           stderrLower.contains("permission denied") ||
           stderrLower.contains("publickey") {
            return .authenticationFailed(url)
        }

        // Repository not found
        if stderrLower.contains("not found") ||
           stderrLower.contains("repository not found") ||
           stderrLower.contains("does not exist") {
            return .repositoryNotFound(url)
        }

        // Network error
        if stderrLower.contains("could not resolve host") ||
           stderrLower.contains("unable to connect") ||
           stderrLower.contains("network") ||
           stderrLower.contains("timed out") ||
           stderrLower.contains("connection refused") {
            return .networkError(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Generic failure
        return .cloneFailed(exitCode: exitCode, stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Utilities

    /// Find git binary path.
    private func findGitPath() async throws -> String {
        // Try common paths
        let commonPaths = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git"
        ]

        for path in commonPaths {
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try xcrun
        let xcrunPath = try? await findGitViaXcrun()
        if let path = xcrunPath {
            return path
        }

        // Try which
        let whichPath = try? await findGitViaWhich()
        if let path = whichPath {
            return path
        }

        throw GitCloneError.gitNotInstalled
    }

    /// Find git via xcrun.
    private func findGitViaXcrun() async throws -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "git"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return path?.isEmpty == false ? path : nil
    }

    /// Find git via which.
    private func findGitViaWhich() async throws -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["git"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return path?.isEmpty == false ? path : nil
    }

    /// Clean up partial clone directory.
    private func cleanup(destination: String) async throws {
        if fileManager.fileExists(atPath: destination) {
            try fileManager.removeItem(atPath: destination)
        }
    }
}

// MARK: - Thread-safe Stderr Collector

/// Thread-safe collector for stderr output.
private final class StderrCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""

    func append(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer += text
    }

    var content: String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}

// MARK: - Convenience Extensions

extension GitCloneService {

    /// Clone using AsyncStream for progress updates.
    ///
    /// Alternative API that returns progress as an AsyncStream.
    ///
    /// ```swift
    /// let (destination, progressStream) = try await service.cloneWithStream(
    ///     url: "https://github.com/owner/repo",
    ///     destination: "/path/to/dest"
    /// )
    /// for await progress in progressStream {
    ///     print("\(progress.phase): \(progress.percent)%")
    /// }
    /// ```
    public func cloneWithStream(
        url: String,
        destination: String,
        shallow: Bool = false
    ) async throws -> (String, AsyncStream<CloneProgress>) {
        let stream = AsyncStream<CloneProgress> { continuation in
            Task {
                do {
                    _ = try await cloneRepository(
                        url: url,
                        destination: destination,
                        shallow: shallow
                    ) { progress in
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }

        return (destination, stream)
    }

    /// Validate a URL without cloning.
    ///
    /// Useful for pre-validation in UI before starting clone.
    ///
    /// - Parameter url: URL to validate
    /// - Returns: true if URL is valid
    public nonisolated func isValidURL(_ url: String) -> Bool {
        do {
            try validateCloneURL(url.trimmingCharacters(in: .whitespaces))
            return true
        } catch {
            return false
        }
    }
}
