import Foundation
import os.log

// MARK: - TerminalBackend Protocol (E001-F006-S001-T002-A001)

/// Protocol defining the interface for terminal backend implementations.
///
/// **Phase 2 System Contract:**
/// - Spawn PTY processes with configurable shell and environment
/// - Bidirectional I/O: write input, receive output stream
/// - Resize support for window size changes
/// - Graceful termination with fallback to force-kill
///
/// **Implementations:**
/// - `SwiftTermBackend`: Primary implementation using SwiftTerm library
/// - Future: `GhosttyBackend` using libghostty
public protocol TerminalBackend: AnyObject, Sendable {
    /// Unique identifier for this backend instance
    var id: UUID { get }

    /// Current state of the backend
    var state: TerminalBackendState { get async }

    /// Spawn a shell process
    /// - Parameters:
    ///   - shell: Path to shell executable (e.g., /bin/zsh)
    ///   - cwd: Working directory for the process
    ///   - env: Environment variables
    ///   - size: Initial terminal size
    /// - Throws: `TerminalError` if spawn fails
    func spawn(
        shell: String,
        cwd: URL,
        env: [String: String],
        size: TerminalSize
    ) async throws

    /// Write data to the terminal input
    /// - Parameter data: Data to write (typically UTF-8 encoded text or escape sequences)
    func write(_ data: Data) async

    /// Write a string to the terminal input
    /// - Parameter string: String to write
    func write(_ string: String) async

    /// Resize the terminal
    /// - Parameter size: New terminal size
    func resize(_ size: TerminalSize) async

    /// AsyncStream of output data from the terminal
    var output: AsyncStream<Data> { get async }

    /// AsyncStream of state changes
    var stateChanges: AsyncStream<TerminalBackendState> { get async }

    /// Terminate the terminal process gracefully
    /// - Parameter timeout: Timeout before force-killing (default 5 seconds)
    func terminate(timeout: TimeInterval) async

    /// Force-terminate the terminal process immediately
    func forceTerminate() async

    /// Get the exit code if the process has terminated
    var exitCode: Int32? { get async }
}

// MARK: - Default Implementations

public extension TerminalBackend {
    func write(_ string: String) async {
        if let data = string.data(using: .utf8) {
            await write(data)
        }
    }

    func terminate(timeout: TimeInterval = 5.0) async {
        await terminate(timeout: timeout)
    }
}

// MARK: - TerminalBackendState

/// State of a terminal backend
public enum TerminalBackendState: Sendable, Equatable {
    case idle
    case spawning
    case running(pid: Int32)
    case terminated(exitCode: Int32)
    case error(message: String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var pid: Int32? {
        if case .running(let pid) = self { return pid }
        return nil
    }
}

// MARK: - TerminalSize

/// Terminal dimensions in columns and rows
public struct TerminalSize: Sendable, Equatable, Codable {
    public let cols: Int
    public let rows: Int

    public init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
    }

    /// Default terminal size (80x24)
    public static let `default` = TerminalSize(cols: 80, rows: 24)

    /// Common macOS terminal size
    public static let standard = TerminalSize(cols: 120, rows: 30)
}

// MARK: - TerminalError

/// Errors that can occur in terminal operations
public enum TerminalError: Error, LocalizedError, Sendable {
    case spawnFailed(underlying: String)
    case shellNotFound(path: String)
    case workingDirectoryNotFound(path: String)
    case alreadyRunning
    case notRunning
    case writeError(underlying: String)
    case resizeError(underlying: String)
    case terminationTimeout

    public var errorDescription: String? {
        switch self {
        case .spawnFailed(let underlying):
            return "Failed to spawn terminal: \(underlying)"
        case .shellNotFound(let path):
            return "Shell not found at path: \(path)"
        case .workingDirectoryNotFound(let path):
            return "Working directory not found: \(path)"
        case .alreadyRunning:
            return "Terminal is already running"
        case .notRunning:
            return "Terminal is not running"
        case .writeError(let underlying):
            return "Failed to write to terminal: \(underlying)"
        case .resizeError(let underlying):
            return "Failed to resize terminal: \(underlying)"
        case .terminationTimeout:
            return "Terminal process did not terminate within timeout"
        }
    }
}

// MARK: - TerminalBackendType

/// Available terminal backend implementations
public enum TerminalBackendType: String, CaseIterable, Sendable, Codable {
    case swiftTerm = "SwiftTerm"
    case ghostty = "Ghostty"

    /// Check if this backend is available on the system
    public var isAvailable: Bool {
        switch self {
        case .swiftTerm:
            return true  // Always available (bundled)
        case .ghostty:
            return Self.checkGhosttyAvailability()
        }
    }

    /// Check if libghostty is installed (stub for now)
    private static func checkGhosttyAvailability() -> Bool {
        // TODO: Check for libghostty when it ships
        // For now, return false as Ghostty is not yet available
        return false
    }

    public var displayName: String {
        switch self {
        case .swiftTerm:
            return "SwiftTerm"
        case .ghostty:
            return "Ghostty (Coming Soon)"
        }
    }

    public var description: String {
        switch self {
        case .swiftTerm:
            return "Battle-tested terminal emulator with full xterm-256color support"
        case .ghostty:
            return "Fast, native macOS terminal powered by libghostty (availability check pending)"
        }
    }

    /// Get the effective backend, falling back to SwiftTerm if unavailable
    /// (E003-F001-S004-T002-A002, E003-F001-S004-T003-A003)
    public var effectiveBackend: TerminalBackendType {
        if self.isAvailable {
            return self
        }

        // Log the fallback event for debugging
        let logger = Logger(subsystem: "com.cogit0.blaze", category: "Terminal")
        logger.warning("Terminal backend '\(self.rawValue)' not available, falling back to SwiftTerm")

        // Always fallback to SwiftTerm (guaranteed to be available)
        return .swiftTerm
    }
}

// MARK: - TerminalBackendFactory

/// Factory for creating terminal backend instances
public enum TerminalBackendFactory {
    private static let logger = Logger(subsystem: "com.cogit0.blaze", category: "Terminal")

    /// Create a terminal backend of the specified type, with automatic fallback
    /// - Parameter type: The backend type to create
    /// - Returns: A new backend instance (may be a fallback if requested type unavailable)
    public static func create(type: TerminalBackendType) -> any TerminalBackend {
        // Use effectiveBackend to automatically fallback if needed
        // (E003-F001-S004-T002-A002, E003-F001-S004-T003-A003)
        let effective = type.effectiveBackend

        switch effective {
        case .swiftTerm:
            return SwiftTermBackend()
        case .ghostty:
            // This should never be reached due to effectiveBackend fallback,
            // but keep it safe in case isAvailable logic changes
            logger.error("Ghostty backend reached despite availability fallback - returning GhosttyBackend anyway")
            return GhosttyBackend()
        }
    }
}

// MARK: - Shell Configuration

/// Configuration for shell spawning
public struct ShellConfiguration: Sendable {
    /// Path to the shell executable
    public let shellPath: String

    /// Login shell flag (-l)
    public let isLoginShell: Bool

    /// Additional shell arguments
    public let arguments: [String]

    /// Environment variable overrides
    public let environmentOverrides: [String: String]

    public init(
        shellPath: String? = nil,
        isLoginShell: Bool = true,
        arguments: [String] = [],
        environmentOverrides: [String: String] = [:]
    ) {
        self.shellPath = shellPath ?? ShellConfiguration.detectDefaultShell()
        self.isLoginShell = isLoginShell
        self.arguments = arguments
        self.environmentOverrides = environmentOverrides
    }

    /// Detect the user's default shell
    public static func detectDefaultShell() -> String {
        // Try SHELL environment variable first
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }

        // Fall back to common shells
        let fallbacks = ["/bin/zsh", "/bin/bash", "/bin/sh"]
        for shell in fallbacks {
            if FileManager.default.fileExists(atPath: shell) {
                return shell
            }
        }

        return "/bin/sh"
    }

    /// Build the full command line arguments
    public var fullArguments: [String] {
        var args: [String] = []
        if isLoginShell {
            args.append("-l")
        }
        args.append(contentsOf: arguments)
        return args
    }

    /// Build the environment dictionary
    /// - Parameter baseEnv: Base environment to merge with overrides
    /// - Returns: Merged environment dictionary
    public func buildEnvironment(baseEnv: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var env = baseEnv

        // Set TERM for full color support
        env["TERM"] = "xterm-256color"

        // Apply overrides
        for (key, value) in environmentOverrides {
            env[key] = value
        }

        return env
    }
}
