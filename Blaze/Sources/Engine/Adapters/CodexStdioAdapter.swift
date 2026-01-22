import Foundation
import os.log

private let adapterLog = OSLog(subsystem: "com.cogit0.Blaze", category: "CodexStdioAdapter")

// MARK: - Atomic Integer

/// Thread-safe counter for generating unique JSON-RPC request IDs.
final class AtomicInteger: @unchecked Sendable {
    private var value: Int
    private let lock = NSLock()

    init(initialValue: Int = 0) {
        self.value = initialValue
    }

    /// Increment and return the new value (atomic).
    func incrementAndGet() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    /// Get current value without incrementing.
    var current: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

// MARK: - JSON-RPC Types

/// JSON-RPC 2.0 request message.
struct CodexJSONRPCRequest: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: AnyCodable?

    init(id: Int, method: String, params: AnyCodable? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response message.
struct CodexJSONRPCResponse: Decodable, Sendable {
    let jsonrpc: String
    let id: Int?
    let result: AnyCodable?
    let error: CodexJSONRPCError?
}

/// JSON-RPC error object.
struct CodexJSONRPCError: Decodable, Error, LocalizedError, Sendable {
    let code: Int
    let message: String
    let data: AnyCodable?

    var errorDescription: String? {
        "JSON-RPC Error \(code): \(message)"
    }
}

/// JSON-RPC 2.0 notification (no id field).
struct CodexJSONRPCNotification: Decodable, Sendable {
    let jsonrpc: String
    let method: String
    let params: AnyCodable?
}

// Note: Uses AnyCodable from NDJSONParser.swift for type-erased JSON values.

// MARK: - Codex Stdio Adapter

/// Engine adapter for OpenAI Codex CLI using stdio JSON-RPC.
///
/// Unlike the pipe-based `CodexCliAdapter`, this adapter maintains a persistent
/// process with bidirectional JSON-RPC communication over stdin/stdout pipes.
///
/// ## JSON-RPC Protocol
/// - Requests: `{"jsonrpc":"2.0","id":1,"method":"...", "params":{...}}`
/// - Responses: `{"jsonrpc":"2.0","id":1,"result":{...}}` or `{"error":{...}}`
/// - Notifications: `{"jsonrpc":"2.0","method":"...", "params":{...}}` (no id)
///
/// ## Architecture
/// ```
/// ┌─────────────┐       stdin (JSON-RPC requests)
/// │ CodexStdio  │  ────────────────────────────▶  ┌─────────┐
/// │   Adapter   │                                 │  codex  │
/// │   (actor)   │  ◀────────────────────────────  │ process │
/// └─────────────┘       stdout (JSON-RPC msgs)    └─────────┘
/// ```
actor CodexStdioAdapter {
    // MARK: - Types

    /// Internal message parsed from stdout - either response or notification.
    private enum ParsedMessage {
        case response(CodexJSONRPCResponse)
        case notification(CodexJSONRPCNotification)
        case parseError(String, Error)
    }

    // MARK: - State

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    /// Atomic counter for request IDs.
    private let requestIdCounter = AtomicInteger()

    /// Pending requests awaiting responses, keyed by request ID.
    private var pendingRequests: [Int: CheckedContinuation<CodexJSONRPCResponse, Error>] = [:]

    /// Continuation for the notification stream.
    private var notificationContinuation: AsyncStream<CodexJSONRPCNotification>.Continuation?

    /// Buffer for incomplete stdout lines.
    private var stdoutBuffer = Data()

    /// Read loop task.
    private var readLoopTask: Task<Void, Never>?

    /// Process monitor task.
    private var processMonitorTask: Task<Void, Never>?

    /// Whether the adapter is running.
    private(set) var isRunning: Bool = false

    /// Cached CLI path.
    private var cliPath: String?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [] // Compact JSON

        decoder = JSONDecoder()
    }

    // MARK: - Lifecycle

    /// Start the Codex process and begin listening for messages.
    ///
    /// - Parameters:
    ///   - executable: Path to the codex CLI executable.
    ///   - workingDirectory: Optional working directory for the process.
    ///   - environment: Optional additional environment variables.
    /// - Throws: `CodexStdioError` if the process fails to start.
    func start(
        executable: String,
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async throws {
        guard !isRunning else {
            os_log(.default, log: adapterLog, "Adapter already running")
            return
        }

        cliPath = executable

        // Create pipes
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        stdinPipe = stdin
        stdoutPipe = stdout
        stderrPipe = stderr

        // Configure process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)

        // Codex stdio mode uses no arguments by default (server mode).
        // Specific modes can be configured via JSON-RPC method calls.
        proc.arguments = ["--stdio"]

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        if let wd = workingDirectory {
            proc.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        if let env = environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                processEnv[key] = value
            }
            proc.environment = processEnv
        }

        process = proc

        // Start process
        do {
            try proc.run()
            os_log(.info, log: adapterLog, "Codex process started (pid: %d)", proc.processIdentifier)
        } catch {
            cleanup()
            throw CodexStdioError.spawnFailed(underlying: error)
        }

        isRunning = true

        // Start read loop
        readLoopTask = Task { [weak self] in
            await self?.runReadLoop()
        }

        // Start process monitor
        processMonitorTask = Task { [weak self] in
            await self?.monitorProcess()
        }
    }

    /// Stop the Codex process gracefully.
    ///
    /// Sends SIGTERM, waits up to 2 seconds, then SIGKILL if needed.
    func stop() async {
        guard isRunning else { return }

        os_log(.info, log: adapterLog, "Stopping Codex process")

        // Cancel read loop first
        readLoopTask?.cancel()
        processMonitorTask?.cancel()

        // Close stdin to signal EOF
        stdinPipe?.fileHandleForWriting.closeFile()

        // Try SIGTERM first
        if let proc = process, proc.isRunning {
            proc.interrupt() // SIGTERM

            // Wait up to 2 seconds for graceful exit
            let deadline = Date().addingTimeInterval(2.0)
            while proc.isRunning && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(100))
            }

            // Force kill if still running
            if proc.isRunning {
                os_log(.default, log: adapterLog, "Process did not exit gracefully, sending SIGKILL")
                proc.terminate() // SIGKILL
            }

            proc.waitUntilExit()
        }

        // Cancel all pending requests
        for (id, continuation) in pendingRequests {
            continuation.resume(throwing: CodexStdioError.adapterShutdown)
            os_log(.debug, log: adapterLog, "Cancelled pending request %d", id)
        }
        pendingRequests.removeAll()

        // Finish notification stream
        notificationContinuation?.finish()
        notificationContinuation = nil

        cleanup()
        os_log(.info, log: adapterLog, "Codex process stopped")
    }

    // MARK: - JSON-RPC Communication

    /// Send a JSON-RPC request and await the response.
    ///
    /// - Parameters:
    ///   - method: The RPC method name.
    ///   - params: Optional parameters dictionary.
    /// - Returns: The JSON-RPC response.
    /// - Throws: `CodexStdioError` or `JSONRPCError` on failure.
    func sendRequest(method: String, params: [String: Any]? = nil) async throws -> CodexJSONRPCResponse {
        guard isRunning else {
            throw CodexStdioError.notRunning
        }

        guard let stdinHandle = stdinPipe?.fileHandleForWriting else {
            throw CodexStdioError.pipeNotAvailable
        }

        let requestId = requestIdCounter.incrementAndGet()

        // Convert params to AnyCodable (wrapping dictionary)
        let codableParams: AnyCodable? = params.map { AnyCodable($0) }

        let request = CodexJSONRPCRequest(id: requestId, method: method, params: codableParams)

        // Encode and write
        var data = try encoder.encode(request)
        data.append(UInt8(ascii: "\n")) // Newline-delimited

        os_log(.debug, log: adapterLog, "Sending request %d: %{public}@", requestId, method)

        // Register continuation before writing (prevents race)
        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation first
            Task { [weak self] in
                await self?.registerPendingRequest(id: requestId, continuation: continuation)

                // Then write to stdin
                do {
                    try stdinHandle.write(contentsOf: data)
                } catch {
                    // Remove pending request and resume with error
                    await self?.removePendingRequest(id: requestId)
                    continuation.resume(throwing: CodexStdioError.writeFailed(underlying: error))
                }
            }
        }
    }

    /// Send a JSON-RPC notification (no response expected).
    ///
    /// - Parameters:
    ///   - method: The notification method name.
    ///   - params: Optional parameters dictionary.
    func sendNotification(method: String, params: [String: Any]? = nil) throws {
        guard isRunning else {
            throw CodexStdioError.notRunning
        }

        guard let stdinHandle = stdinPipe?.fileHandleForWriting else {
            throw CodexStdioError.pipeNotAvailable
        }

        // Notifications have no id
        struct Notification: Encodable {
            let jsonrpc: String = "2.0"
            let method: String
            let params: AnyCodable?
        }

        let codableParams: AnyCodable? = params.map { AnyCodable($0) }
        let notification = Notification(method: method, params: codableParams)

        var data = try encoder.encode(notification)
        data.append(UInt8(ascii: "\n"))

        os_log(.debug, log: adapterLog, "Sending notification: %{public}@", method)
        try stdinHandle.write(contentsOf: data)
    }

    /// Get an async stream of incoming notifications from the Codex process.
    ///
    /// - Returns: AsyncStream of JSON-RPC notifications.
    func notifications() -> AsyncStream<CodexJSONRPCNotification> {
        AsyncStream { continuation in
            Task { [weak self] in
                await self?.setNotificationContinuation(continuation)
            }
        }
    }

    // MARK: - Internal Helpers

    private func registerPendingRequest(id: Int, continuation: CheckedContinuation<CodexJSONRPCResponse, Error>) {
        pendingRequests[id] = continuation
    }

    private func removePendingRequest(id: Int) {
        pendingRequests.removeValue(forKey: id)
    }

    private func setNotificationContinuation(_ continuation: AsyncStream<CodexJSONRPCNotification>.Continuation) {
        // Finish any existing continuation
        notificationContinuation?.finish()
        notificationContinuation = continuation
    }

    // MARK: - Read Loop

    /// Main read loop that processes stdout line by line.
    private func runReadLoop() async {
        guard let stdoutHandle = stdoutPipe?.fileHandleForReading else {
            os_log(.error, log: adapterLog, "No stdout pipe available")
            return
        }

        os_log(.info, log: adapterLog, "Read loop started")

        // Read in chunks
        while !Task.isCancelled {
            do {
                // Non-blocking read with small timeout
                let data = try await readAvailableData(from: stdoutHandle)

                if data.isEmpty {
                    // No data available - small sleep to avoid busy loop
                    try await Task.sleep(for: .milliseconds(10))
                    continue
                }

                // Append to buffer and extract complete lines
                stdoutBuffer.append(data)
                let lines = extractLines()

                for line in lines {
                    await handleLine(line)
                }
            } catch {
                if !Task.isCancelled {
                    os_log(.error, log: adapterLog, "Read loop error: %{public}@", error.localizedDescription)
                }
                break
            }
        }

        os_log(.info, log: adapterLog, "Read loop ended")
    }

    /// Read available data from file handle (async-safe wrapper).
    private func readAvailableData(from handle: FileHandle) async throws -> Data {
        // Use availableData which returns immediately with whatever is available
        return handle.availableData
    }

    /// Extract complete newline-delimited lines from the buffer.
    private func extractLines() -> [String] {
        var lines: [String] = []

        while let newlineIndex = stdoutBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = stdoutBuffer[..<newlineIndex]
            stdoutBuffer = Data(stdoutBuffer[(newlineIndex + 1)...])

            if let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !line.isEmpty {
                lines.append(line)
            }
        }

        return lines
    }

    /// Parse and route a single line from stdout.
    private func handleLine(_ line: String) async {
        os_log(.debug, log: adapterLog, "Received line: %{public}@", line.prefix(200).description)

        guard let data = line.data(using: .utf8) else {
            os_log(.default, log: adapterLog, "Failed to convert line to data")
            return
        }

        // Try to parse as JSON-RPC message
        let parsed = parseMessage(data)

        switch parsed {
        case .response(let response):
            await routeResponse(response)

        case .notification(let notification):
            routeNotification(notification)

        case .parseError(let rawLine, let error):
            os_log(.default, log: adapterLog, "Failed to parse JSON-RPC: %{public}@ - line: %{public}@",
                   error.localizedDescription, rawLine.prefix(100).description)
        }
    }

    /// Parse a line as either a response or notification.
    private func parseMessage(_ data: Data) -> ParsedMessage {
        // First try as response (has id field)
        if let response = try? decoder.decode(CodexJSONRPCResponse.self, from: data),
           response.id != nil {
            return .response(response)
        }

        // Then try as notification (no id field)
        if let notification = try? decoder.decode(CodexJSONRPCNotification.self, from: data) {
            return .notification(notification)
        }

        // Parse error
        let rawLine = String(data: data, encoding: .utf8) ?? "<binary>"
        return .parseError(rawLine, CodexStdioError.invalidJSON)
    }

    /// Route a response to its waiting continuation.
    private func routeResponse(_ response: CodexJSONRPCResponse) async {
        guard let id = response.id else {
            os_log(.default, log: adapterLog, "Response missing id field")
            return
        }

        guard let continuation = pendingRequests.removeValue(forKey: id) else {
            os_log(.default, log: adapterLog, "No pending request for id %d", id)
            return
        }

        if let error = response.error {
            os_log(.debug, log: adapterLog, "Request %d failed: %{public}@", id, error.message)
            continuation.resume(throwing: error)
        } else {
            os_log(.debug, log: adapterLog, "Request %d succeeded", id)
            continuation.resume(returning: response)
        }
    }

    /// Route a notification to subscribers.
    private func routeNotification(_ notification: CodexJSONRPCNotification) {
        os_log(.debug, log: adapterLog, "Notification: %{public}@", notification.method)
        notificationContinuation?.yield(notification)
    }

    // MARK: - Process Monitor

    /// Monitor the process and handle unexpected exits.
    private func monitorProcess() async {
        guard let proc = process else { return }

        // Wait for process to exit (blocking)
        proc.waitUntilExit()

        let exitCode = proc.terminationStatus
        os_log(.info, log: adapterLog, "Codex process exited with code %d", exitCode)

        // Mark as not running
        isRunning = false

        // Cancel all pending requests with error
        for (id, continuation) in pendingRequests {
            continuation.resume(throwing: CodexStdioError.processExited(exitCode: exitCode))
            os_log(.debug, log: adapterLog, "Cancelled pending request %d due to process exit", id)
        }
        pendingRequests.removeAll()

        // Finish notification stream
        notificationContinuation?.finish()
    }

    // MARK: - Cleanup

    private func cleanup() {
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
        stdoutBuffer = Data()
        isRunning = false
    }
}

// MARK: - Errors

/// Errors from Codex stdio adapter operations.
enum CodexStdioError: Error, LocalizedError {
    case notRunning
    case spawnFailed(underlying: Error)
    case pipeNotAvailable
    case writeFailed(underlying: Error)
    case invalidJSON
    case processExited(exitCode: Int32)
    case adapterShutdown
    case timeout

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Codex adapter is not running"
        case .spawnFailed(let underlying):
            return "Failed to spawn Codex process: \(underlying.localizedDescription)"
        case .pipeNotAvailable:
            return "Stdin/stdout pipe not available"
        case .writeFailed(let underlying):
            return "Failed to write to stdin: \(underlying.localizedDescription)"
        case .invalidJSON:
            return "Invalid JSON-RPC message"
        case .processExited(let exitCode):
            return "Codex process exited unexpectedly (code \(exitCode))"
        case .adapterShutdown:
            return "Adapter was shut down"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - Restart Logic Extension

extension CodexStdioAdapter {
    /// Restart the Codex process (stop then start).
    ///
    /// Useful for recovering from crashes or resetting state.
    func restart(
        executable: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async throws {
        await stop()

        // Use cached path if not provided
        guard let path = executable ?? cliPath else {
            throw CodexStdioError.notRunning
        }

        try await start(
            executable: path,
            workingDirectory: workingDirectory,
            environment: environment
        )
    }
}
