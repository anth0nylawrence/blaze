import Foundation

// MARK: - GhosttyBackend Stub (E003-F001-S003-T001-A001, E003-F001-S003-T002-A002)

/// Stub implementation for Ghostty terminal backend.
///
/// **Status:** Awaiting libghostty public release
///
/// This stub implementation satisfies the TerminalBackend protocol contract
/// but always returns `.idle` state and no-ops all operations. Once libghostty
/// ships, this class will be replaced with a real implementation binding to
/// the native Ghostty library.
///
/// **Phase 2 Integration Plan:**
/// - Replace spawn() with libghostty FFI bindings
/// - Wire output stream to libghostty output callbacks
/// - Implement PTY resize via libghostty API
/// - Add proper state management for running processes
public final class GhosttyBackend: TerminalBackend {
    // MARK: - Properties

    public let id: UUID

    private var _state: TerminalBackendState = .idle
    private let stateContinuation: AsyncStream<TerminalBackendState>.Continuation
    private let stateStream: AsyncStream<TerminalBackendState>

    private let outputContinuation: AsyncStream<Data>.Continuation
    private let outputStream: AsyncStream<Data>

    private var _exitCode: Int32?

    // MARK: - Initialization

    public init() {
        self.id = UUID()

        // Create state stream
        var stateCont: AsyncStream<TerminalBackendState>.Continuation!
        self.stateStream = AsyncStream { continuation in
            stateCont = continuation
        }
        self.stateContinuation = stateCont

        // Create output stream
        var outputCont: AsyncStream<Data>.Continuation!
        self.outputStream = AsyncStream { continuation in
            outputCont = continuation
        }
        self.outputContinuation = outputCont
    }

    // MARK: - TerminalBackend Protocol

    public var state: TerminalBackendState {
        get async { _state }
    }

    public func spawn(
        shell: String,
        cwd: URL,
        env: [String: String],
        size: TerminalSize
    ) async throws {
        // Stub: No-op until libghostty is available
        // Real implementation will:
        // 1. Call libghostty spawn API
        // 2. Set up PTY with specified size
        // 3. Configure shell and environment
        // 4. Transition state to .running(pid: <actual_pid>)
        throw TerminalError.spawnFailed(underlying: "Ghostty backend not yet implemented - awaiting libghostty release")
    }

    public func write(_ data: Data) async {
        // Stub: No-op until libghostty is available
        // Real implementation will write to libghostty PTY input
    }

    public func resize(_ size: TerminalSize) async {
        // Stub: No-op until libghostty is available
        // Real implementation will call libghostty resize API
    }

    public var output: AsyncStream<Data> {
        get async { outputStream }
    }

    public var stateChanges: AsyncStream<TerminalBackendState> {
        get async { stateStream }
    }

    public func terminate(timeout: TimeInterval) async {
        // Stub: No-op until libghostty is available
        // Real implementation will:
        // 1. Send SIGTERM to child process
        // 2. Wait for timeout
        // 3. Fall back to SIGKILL if necessary
    }

    public func forceTerminate() async {
        // Stub: No-op until libghostty is available
        // Real implementation will send SIGKILL to child process
    }

    public var exitCode: Int32? {
        get async { _exitCode }
    }

    // MARK: - Cleanup

    deinit {
        stateContinuation.finish()
        outputContinuation.finish()
    }
}
