import Foundation

// MARK: - Gemini Stream Events

/// Events emitted by Gemini CLI in stream-json output mode.
/// Discriminated union based on the `type` field.
///
/// **Actual Gemini CLI output format (verified 2026-01-21):**
/// - init: {"type":"init","timestamp":"...","session_id":"...","model":"..."}
/// - message (user): {"type":"message","timestamp":"...","role":"user","content":"..."}
/// - message (assistant): {"type":"message","timestamp":"...","role":"assistant","content":"...","delta":true}
/// - result: {"type":"result","timestamp":"...","status":"success","stats":{...}}
enum GeminiStreamEvent: Decodable, Sendable {
    case `init`(GeminiInitEvent)
    case message(GeminiMessageEvent)
    case toolCall(GeminiToolCallEvent)
    case toolResult(GeminiToolResultEvent)
    case result(GeminiResultEvent)
    case error(GeminiErrorEvent)
    case unknown(GeminiRawEvent)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "init":
            self = .`init`(try GeminiInitEvent(from: decoder))
        case "message":
            self = .message(try GeminiMessageEvent(from: decoder))
        case "tool_call":
            self = .toolCall(try GeminiToolCallEvent(from: decoder))
        case "tool_result":
            self = .toolResult(try GeminiToolResultEvent(from: decoder))
        case "result":
            self = .result(try GeminiResultEvent(from: decoder))
        case "error":
            self = .error(try GeminiErrorEvent(from: decoder))
        default:
            self = .unknown(GeminiRawEvent(type: type, timestamp: Date()))
        }
    }
}

// MARK: - Init Event

/// Gemini CLI session initialization event.
/// Emitted at the start of a session.
struct GeminiInitEvent: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let sessionId: String
    let model: String

    private enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case sessionId = "session_id"
        case model
    }
}

// MARK: - Message Event

/// Gemini CLI message event for user prompts and assistant responses.
/// For streaming, `delta` is true and content accumulates.
struct GeminiMessageEvent: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let role: String  // "user" or "assistant"
    let content: String
    let delta: Bool?  // true for streaming chunks

    private enum CodingKeys: String, CodingKey {
        case type, timestamp, role, content, delta
    }
}

// MARK: - Tool Call Event

/// Gemini CLI tool call event.
/// Emitted when the model wants to invoke a tool.
struct GeminiToolCallEvent: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let tool: GeminiToolInfo
    let id: String

    struct GeminiToolInfo: Decodable, Sendable {
        let name: String
        let input: [String: String]?  // Simplified to String values for now
    }
}

// MARK: - Tool Result Event

/// Gemini CLI tool result event.
/// Emitted when a tool execution completes.
struct GeminiToolResultEvent: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let toolCallId: String
    let content: String
    let isError: Bool?

    private enum CodingKeys: String, CodingKey {
        case type, timestamp
        case toolCallId = "tool_call_id"
        case content
        case isError = "is_error"
    }
}

// MARK: - Result Event

/// Gemini CLI result event (turn/session completion).
/// Emitted when a turn ends successfully or with error.
struct GeminiResultEvent: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let status: String  // "success" or "error"
    let stats: GeminiStats?

    private enum CodingKeys: String, CodingKey {
        case type, timestamp, status, stats
    }

    struct GeminiStats: Decodable, Sendable {
        let totalTokens: Int?
        let inputTokens: Int?
        let outputTokens: Int?
        let cached: Int?
        let input: Int?
        let durationMs: Int?
        let toolCalls: Int?

        private enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cached, input
            case durationMs = "duration_ms"
            case toolCalls = "tool_calls"
        }
    }
}

// MARK: - Error Event

/// Gemini CLI error event.
/// Emitted when an error occurs during processing.
struct GeminiErrorEvent: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let code: String?
    let message: String?
}

// MARK: - Raw Event

/// Fallback for unknown Gemini event types.
/// Preserves the type string for logging/debugging.
struct GeminiRawEvent: Decodable, Sendable {
    let type: String
    let timestamp: Date

    init(type: String, timestamp: Date) {
        self.type = type
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        timestamp = Date()
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }
}
