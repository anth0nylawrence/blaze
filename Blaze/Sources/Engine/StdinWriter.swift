import Foundation

// MARK: - Stdin Writer

/// Atomic JSON line writer for CLI stdin.
///
/// Writes single JSON objects as newline-terminated lines, with fail-fast EPIPE handling.
/// Designed for sending `tool_result` envelopes to Claude CLI via PTY.
///
/// ## Key Behaviors
/// - One call = one NDJSON line (atomic write)
/// - Fails fast on EPIPE (no retry - process closed stdin)
/// - Uses explicit `CodingKeys` for protocol safety (no `convertToSnakeCase` magic)
///
/// ## Usage
/// ```swift
/// let writer = StdinWriter(runner: ptyRunner)
/// try await writer.sendJSONLine(envelope)
/// ```
public actor StdinWriter {
    private let runner: PtyProcessRunner
    private let encoder: JSONEncoder
    private weak var traceRecorder: RawTraceRecorder?

    public init(runner: PtyProcessRunner, traceRecorder: RawTraceRecorder? = nil) {
        self.runner = runner
        self.traceRecorder = traceRecorder

        self.encoder = JSONEncoder()
        encoder.outputFormatting = []  // Compact JSON, no pretty printing
        // NOTE: Do NOT use convertToSnakeCase - explicit CodingKeys for protocol safety
    }

    /// Send a JSON object as a newline-terminated line
    ///
    /// - Parameter value: Encodable value to send
    /// - Throws: `StdinWriterError.epipe` if process closed stdin
    public func sendJSONLine<T: Encodable>(_ value: T) async throws {
        let data = try encoder.encode(value)

        // Ensure single write with newline
        var line = data
        line.append(UInt8(ascii: "\n"))

        print("[StdinWriter] Attempting write: \(line.count) bytes, runner.isRunning=\(runner.isRunning)")

        do {
            try runner.write(line)
            print("[StdinWriter] Write SUCCESS")

            // Non-blocking trace (fire-and-forget)
            Task { [weak traceRecorder] in
                await traceRecorder?.recordStdin(line)
            }
        } catch PtyProcessError.epipe {
            print("[StdinWriter] Write FAILED: EPIPE - process closed stdin")
            throw StdinWriterError.epipe
        } catch PtyProcessError.notRunning {
            print("[StdinWriter] Write FAILED: process not running")
            throw StdinWriterError.pipeNotOpen
        } catch {
            print("[StdinWriter] Write FAILED: \(error)")
            throw StdinWriterError.writeFailed(underlying: error)
        }
    }
}

// MARK: - Errors

/// Errors from stdin writing operations
public enum StdinWriterError: Error, LocalizedError {
    case pipeNotOpen
    case writeFailed(underlying: Error)
    case epipe  // Process stdin closed - FAIL IMMEDIATELY, no retry

    public var errorDescription: String? {
        switch self {
        case .pipeNotOpen:
            return "Stdin pipe is not open"
        case .writeFailed(let underlying):
            return "Write failed: \(underlying.localizedDescription)"
        case .epipe:
            return "Process closed stdin (EPIPE) - fail fast"
        }
    }
}

// MARK: - Tool Result Envelope

/// Envelope for sending tool_result back to Claude CLI.
///
/// Uses the `C_session_id` variant (confirmed working):
/// - `type: "user"`
/// - `session_id: "<session_id>"`
/// - `parent_tool_use_id: null` (explicitly null, not omitted)
/// - `message.content[].type: "tool_result"`
///
/// ## Example JSON Output
/// ```json
/// {
///   "type": "user",
///   "session_id": "...",
///   "parent_tool_use_id": null,
///   "message": {
///     "role": "user",
///     "content": [{
///       "type": "tool_result",
///       "tool_use_id": "...",
///       "content": "...",
///       "is_error": false
///     }]
///   }
/// }
/// ```
public struct ToolResultEnvelope: Encodable, Sendable {
    public let sessionId: String?
    public let parentToolUseId: String?  // Always encoded (as null if nil)
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public init(
        sessionId: String?,
        parentToolUseId: String? = nil,  // Default to null (not omitted)
        toolUseId: String,
        content: String,
        isError: Bool = false
    ) {
        self.sessionId = sessionId
        self.parentToolUseId = parentToolUseId
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }

    // MARK: - Explicit CodingKeys (no convertToSnakeCase magic)

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case parentToolUseId = "parent_tool_use_id"
        case message
    }

    enum MessageCodingKeys: String, CodingKey {
        case role
        case content
    }

    enum ToolResultCodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode("user", forKey: .type)

        if let sessionId = sessionId {
            try container.encode(sessionId, forKey: .sessionId)
        }

        // Always encode parent_tool_use_id (as null if nil) - C_session_id variant
        try container.encode(parentToolUseId, forKey: .parentToolUseId)

        // Encode message
        var messageContainer = container.nestedContainer(keyedBy: MessageCodingKeys.self, forKey: .message)
        try messageContainer.encode("user", forKey: .role)

        var contentArray = messageContainer.nestedUnkeyedContainer(forKey: .content)
        var toolResult = contentArray.nestedContainer(keyedBy: ToolResultCodingKeys.self)
        try toolResult.encode("tool_result", forKey: .type)
        try toolResult.encode(toolUseId, forKey: .toolUseId)
        try toolResult.encode(content, forKey: .content)
        try toolResult.encode(isError, forKey: .isError)
    }
}

// Note: RawTraceRecorder is defined in Sources/Debug/RawTraceRecorder.swift
