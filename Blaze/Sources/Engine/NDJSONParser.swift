import Foundation

// MARK: - NDJSON Parse Error

/// Detailed error information for malformed NDJSON lines
/// Used for telemetry and logging per System Contract
public struct NDJSONParseError: Sendable {
    public let rawBytes: Data
    public let rawString: String?
    public let errorDescription: String
    public let timestamp: Date
    public let lineNumber: Int

    /// Hex dump of first N bytes for debugging binary corruption
    public var hexDump: String {
        rawBytes.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

// MARK: - NDJSON Parser Delegate

/// Delegate protocol for receiving parse errors and telemetry
public protocol NDJSONParserDelegate: AnyObject, Sendable {
    /// Called when a malformed line is encountered and skipped
    func parserDidSkipMalformedLine(_ error: NDJSONParseError) async
}

// MARK: - NDJSON Parser

/// Parses newline-delimited JSON from Claude CLI stream-json output.
///
/// **System Contract Guarantees:**
/// - Events are strictly ordered by emission time
/// - Partial lines are buffered until newline is received
/// - Malformed lines are logged (with raw bytes) and skipped without crashing
/// - Parse errors emit telemetry via delegate
actor NDJSONParser {
    private var buffer = Data()
    private let decoder: JSONDecoder

    /// Tracks total lines parsed for error reporting
    private var lineCount: Int = 0

    /// Delegate for error telemetry (weak to avoid retain cycles)
    public weak var delegate: (any NDJSONParserDelegate)?

    /// Parse errors encountered during this session (for logging/debugging)
    private(set) var parseErrors: [NDJSONParseError] = []

    /// Maximum errors to retain in memory
    private let maxErrorsRetained = 100

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Initialize with delegate for telemetry
    init(delegate: (any NDJSONParserDelegate)?) {
        self.delegate = delegate
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Parse a chunk of data, returning any complete events found.
    /// Buffers partial lines until a newline is received.
    ///
    /// **Contract:** Events are emitted in emission order. Malformed lines
    /// are logged and skipped without throwing.
    ///
    /// **Note:** Handles concatenated JSON objects (e.g., `{...}{...}`) which
    /// can occur when PTY merges rapid CLI writes into a single "line".
    func parse(chunk: Data) -> [ClaudeStreamEvent] {
        buffer.append(chunk)
        var events: [ClaudeStreamEvent] = []

        // Process complete lines (terminated by newline)
        // Invariant: strict emission order preserved
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[..<newlineIndex]
            buffer = Data(buffer[(newlineIndex + 1)...])
            lineCount += 1

            // Skip empty lines (no error, just continue)
            guard !lineData.isEmpty else { continue }

            // Split concatenated JSON objects and parse each
            let jsonChunks = splitConcatenatedJSON(Data(lineData))
            for jsonData in jsonChunks {
                if let event = parseEvent(from: jsonData, lineNumber: lineCount) {
                    events.append(event)
                }
            }
        }

        return events
    }

    /// Split concatenated JSON objects (e.g., `{...}{...}`) into individual objects.
    ///
    /// Claude CLI sometimes writes multiple JSON events without newlines between them.
    /// This happens when PTY merges rapid writes into a single buffer read.
    ///
    /// Uses brace counting to find object boundaries while respecting string literals.
    private func splitConcatenatedJSON(_ data: Data) -> [Data] {
        guard let string = String(data: data, encoding: .utf8) else {
            return [data]
        }

        var results: [Data] = []
        var depth = 0
        var inString = false
        var escape = false
        var objectStart = string.startIndex

        for i in string.indices {
            let char = string[i]

            if escape {
                escape = false
                continue
            }

            if char == "\\" && inString {
                escape = true
                continue
            }

            if char == "\"" {
                inString = !inString
                continue
            }

            if inString {
                continue
            }

            if char == "{" {
                if depth == 0 {
                    objectStart = i
                }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    // Complete object found
                    let endIndex = string.index(after: i)
                    let objectString = String(string[objectStart..<endIndex])
                    if let objectData = objectString.data(using: .utf8) {
                        results.append(objectData)
                    }
                }
            }
        }

        // If no objects were extracted, return original data
        // (handles incomplete or malformed JSON)
        return results.isEmpty ? [data] : results
    }

    /// Flush any remaining buffered data as a final event.
    /// Call this when the stream ends.
    func flush() -> ClaudeStreamEvent? {
        guard !buffer.isEmpty else { return nil }

        let remaining = buffer
        buffer = Data()
        lineCount += 1

        return parseEvent(from: remaining, lineNumber: lineCount)
    }

    /// Reset the parser state.
    /// Call when starting a new session or after errors.
    func reset() {
        buffer = Data()
        lineCount = 0
        parseErrors.removeAll()
    }

    /// Get the current buffer size (for monitoring/debugging)
    var bufferSize: Int {
        buffer.count
    }

    /// Check if there's pending buffered data
    var hasPendingData: Bool {
        !buffer.isEmpty
    }

    private func parseEvent(from data: Data, lineNumber: Int) -> ClaudeStreamEvent? {
        do {
            return try decoder.decode(ClaudeStreamEvent.self, from: data)
        } catch {
            // Log parse error with raw bytes per System Contract
            let rawString = String(data: data, encoding: .utf8)
            let parseError = NDJSONParseError(
                rawBytes: data,
                rawString: rawString,
                errorDescription: error.localizedDescription,
                timestamp: Date(),
                lineNumber: lineNumber
            )

            // Store error for debugging (bounded to prevent memory growth)
            if parseErrors.count < maxErrorsRetained {
                parseErrors.append(parseError)
            }

            // Log to stderr with full context
            print("[NDJSONParser] Parse error at line \(lineNumber): \(error.localizedDescription)", to: &standardError)
            print("[NDJSONParser] Raw bytes (\(data.count)): \(parseError.hexDump)", to: &standardError)
            if let str = rawString {
                print("[NDJSONParser] Raw string: \(str.prefix(500))...", to: &standardError)
            }

            // Emit telemetry via delegate (fire-and-forget)
            Task { [weak self] in
                await self?.delegate?.parserDidSkipMalformedLine(parseError)
            }

            // Return as unknown event for forward compatibility
            // This preserves emission order even for malformed lines
            return .unknown(RawStreamEvent(
                type: "parse_error",
                timestamp: Date(),
                payload: data
            ))
        }
    }
}

// MARK: - Standard Error Output Helper

/// Helper for writing to stderr
private var standardError = FileHandle.standardError

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}

// MARK: - Claude Stream Events

/// Events emitted by Claude CLI in stream-json mode.
/// Discriminated union based on the `type` field (and `subtype` for system events).
enum ClaudeStreamEvent: Decodable, Sendable {
    case `init`(InitStreamEvent)           // Legacy: type="init"
    case systemInit(SystemInitStreamEvent) // Real CLI: type="system", subtype="init"
    case hookResponse(HookResponseEvent)   // type="system", subtype="hook_response"
    case user(UserStreamEvent)
    case assistant(AssistantStreamEvent)
    case result(ResultStreamEvent)
    case summary(SummaryStreamEvent)
    case system(SystemStreamEvent)         // type="system" with message (errors/warnings)
    case unknown(RawStreamEvent)

    private enum CodingKeys: String, CodingKey {
        case type
        case subtype
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let subtype = try container.decodeIfPresent(String.self, forKey: .subtype)

        switch type {
        case "init":
            self = .`init`(try InitStreamEvent(from: decoder))

        case "system":
            // System events are discriminated by subtype
            switch subtype {
            case "init":
                self = .systemInit(try SystemInitStreamEvent(from: decoder))
            case "hook_response":
                self = .hookResponse(try HookResponseEvent(from: decoder))
            default:
                // Regular system message (error/warning) or unknown subtype
                do {
                    self = .system(try SystemStreamEvent(from: decoder))
                } catch {
                    // If it doesn't match SystemStreamEvent schema, store as raw
                    self = .unknown(RawStreamEvent(
                        type: "system:\(subtype ?? "unknown")",
                        timestamp: Date(),
                        payload: nil
                    ))
                }
            }

        case "user":
            self = .user(try UserStreamEvent(from: decoder))
        case "assistant":
            self = .assistant(try AssistantStreamEvent(from: decoder))
        case "result":
            self = .result(try ResultStreamEvent(from: decoder))
        case "summary":
            self = .summary(try SummaryStreamEvent(from: decoder))
        default:
            // Unknown event type - store raw for forward compatibility
            self = .unknown(RawStreamEvent(
                type: type,
                timestamp: Date(),
                payload: nil
            ))
        }
    }
}

// MARK: - Event Envelope Base

/// Common fields present in all Claude stream events
protocol StreamEventEnvelope {
    var type: String { get }
    var timestamp: Date { get }
    var uuid: String { get }
    var sessionId: String { get }
    var parentUuid: String? { get }
    var isSidechain: Bool? { get }
}

// MARK: - Init Event (Legacy format - type: "init")

struct InitStreamEvent: Decodable, Sendable {
    let type: String
    let version: String
    let message: InitMessage

    // Optional envelope fields
    let uuid: String?
    let sessionId: String?
    let parentUuid: String?
    let isSidechain: Bool?

    var timestamp: Date { Date() }

    struct InitMessage: Decodable, Sendable {
        let sessionId: String
        let version: String
        let model: String
        let cwd: String
        let capabilities: [String]?
        let allowedTools: [String]?
    }
}

// MARK: - System Init Event (Real CLI format - type: "system", subtype: "init")

struct SystemInitStreamEvent: Decodable, Sendable {
    let type: String
    let subtype: String
    let sessionId: String
    let uuid: String
    let cwd: String
    let tools: [String]?
    let mcpServers: [MCPServerInfo]?
    let model: String
    let permissionMode: String?
    let claudeCodeVersion: String?
    let slashCommands: [String]?
    let agents: [String]?
    let skills: [String]?
    let apiKeySource: String?

    var timestamp: Date { Date() } // Not always present in real output

    struct MCPServerInfo: Decodable, Sendable {
        let name: String
        let status: String
    }
}

// MARK: - Hook Response Event (type: "system", subtype: "hook_response")

struct HookResponseEvent: Decodable, Sendable {
    let type: String
    let subtype: String
    let sessionId: String
    let uuid: String
    let hookName: String
    let hookEvent: String
    let stdout: String
    let stderr: String
    let exitCode: Int
}

// MARK: - User Event

struct UserStreamEvent: Decodable, Sendable {
    let type: String
    let message: UserMessage
    let isMeta: Bool?
    let toolUseResult: ToolUseResultMeta?

    // Optional envelope fields
    let uuid: String?
    let sessionId: String?
    let parentUuid: String?
    let isSidechain: Bool?

    var timestamp: Date { Date() }

    struct UserMessage: Decodable, Sendable {
        let role: String
        let content: UserContent
    }

    struct ToolUseResultMeta: Decodable, Sendable {
        let content: [ContentBlock]?
        let totalDurationMs: Int?
        let totalTokens: Int?
        let totalToolUseCount: Int?
        let wasInterrupted: Bool?
    }
}

/// User content can be either a simple string or an array of content blocks
enum UserContent: Decodable, Sendable {
    case text(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            let blocks = try container.decode([ContentBlock].self)
            self = .blocks(blocks)
        }
    }
}

// MARK: - Assistant Event

struct AssistantStreamEvent: Decodable, Sendable {
    let type: String
    let message: AssistantMessage

    // Optional envelope fields (not always present in real CLI output)
    let uuid: String?
    let sessionId: String?
    let parentUuid: String?
    let isSidechain: Bool?
    let requestId: String?

    // Computed property for timestamp (use message timestamp or current time)
    var timestamp: Date { Date() }

    struct AssistantMessage: Decodable, Sendable {
        let id: String
        let type: String
        let role: String
        let model: String
        let content: [AssistantContentBlock]
        let stopReason: String?
        let stopSequence: String?
        let usage: UsageStats?
    }
}

/// Content blocks in assistant messages
enum AssistantContentBlock: Decodable, Sendable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case thinking(ThinkingBlock)
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        default:
            self = .unknown(type: type)
        }
    }
}

struct TextBlock: Decodable, Sendable {
    let type: String
    let text: String
}

struct ToolUseBlock: Decodable, Sendable {
    let type: String
    let id: String
    let name: String
    let input: ToolInput
}

struct ThinkingBlock: Decodable, Sendable {
    let type: String
    let thinking: String
}

/// Tool input is a dynamic JSON object - store as dictionary
struct ToolInput: Decodable, Sendable {
    let rawValue: [String: AnyCodable]

    init(rawValue: [String: AnyCodable]) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode([String: AnyCodable].self)
    }

    /// Get a string value from the input
    func getString(_ key: String) -> String? {
        rawValue[key]?.value as? String
    }

    /// Get the input as JSON string for display
    func asJSON() -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: rawValue.mapValues { $0.value },
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Result Event (Real CLI format)

struct ResultStreamEvent: Decodable, Sendable {
    let type: String
    let subtype: String?           // "success" or "error_*"
    let uuid: String
    let sessionId: String
    let result: String?            // The actual response text
    let isError: Bool?
    let durationMs: Int?
    let durationApiMs: Int?
    let numTurns: Int?
    let totalCostUsd: Double?
    let usage: UsageStats?
    let modelUsage: [String: ModelUsageInfo]?
    let permissionDenials: [String]?

    // Computed properties for backward compatibility
    var success: Bool { !(isError ?? false) }
    var timestamp: Date { Date() } // Not always present

    struct ModelUsageInfo: Decodable, Sendable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationInputTokens: Int?
        let webSearchRequests: Int?
        let costUsd: Double?
        let contextWindow: Int?
    }

    // Legacy nested result support (for backward compatibility with tests)
    struct LegacyResultInfo: Decodable, Sendable {
        let success: Bool
        let exitCode: Int
        let durationMs: Int
        let numTurns: Int
        let sessionId: String
    }
}

// MARK: - Summary Event

struct SummaryStreamEvent: Decodable, Sendable {
    let type: String
    let summary: String
    let leafUuid: String?

    // Optional envelope fields
    let uuid: String?
    let sessionId: String?
    let parentUuid: String?
    let isSidechain: Bool?

    var timestamp: Date { Date() }
}

// MARK: - System Event (error/warning messages)

struct SystemStreamEvent: Decodable, Sendable {
    let type: String
    let message: SystemMessage

    // Optional envelope fields
    let uuid: String?
    let sessionId: String?
    let parentUuid: String?
    let isSidechain: Bool?

    var timestamp: Date { Date() }

    struct SystemMessage: Decodable, Sendable {
        let level: String
        let text: String
        let code: String?
        let details: AnyCodable?
    }
}

// MARK: - Raw/Unknown Event

struct RawStreamEvent: Decodable, Sendable {
    let type: String
    let timestamp: Date
    let payload: Data?

    init(type: String, timestamp: Date, payload: Data?) {
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        payload = nil
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case timestamp
    }
}

// MARK: - Content Block

/// Content blocks used in user tool_result messages
enum ContentBlock: Decodable, Sendable {
    case text(TextContentBlock)
    case toolResult(ToolResultBlock)
    case image(ImageBlock)
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextContentBlock(from: decoder))
        case "tool_result":
            self = .toolResult(try ToolResultBlock(from: decoder))
        case "image":
            self = .image(try ImageBlock(from: decoder))
        default:
            self = .unknown(type: type)
        }
    }
}

struct TextContentBlock: Decodable, Sendable {
    let type: String
    let text: String

    // Custom init for programmatic creation
    init(type: String, text: String) {
        self.type = type
        self.text = text
    }

    // Decodable init (required because we have a custom init)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decode(String.self, forKey: .text)
    }

    private enum CodingKeys: String, CodingKey {
        case type, text
    }
}

struct ToolResultBlock: Decodable, Sendable {
    let type: String
    let toolUseId: String
    let content: [TextContentBlock]?
    let isError: Bool?

    // Note: JSONDecoder uses .convertFromSnakeCase, so tool_use_id -> toolUseId automatically
    // We only need custom CodingKeys for the flexible content decoding
    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content, isError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        toolUseId = try container.decode(String.self, forKey: .toolUseId)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError)

        // Content can be either a string or an array of TextContentBlock
        // Real CLI sends string for simple results, array for complex ones
        if let stringContent = try? container.decode(String.self, forKey: .content) {
            // Convert string to single TextContentBlock
            content = [TextContentBlock(type: "text", text: stringContent)]
        } else if let arrayContent = try? container.decode([TextContentBlock].self, forKey: .content) {
            content = arrayContent
        } else {
            content = nil
        }
    }
}

struct ImageBlock: Decodable, Sendable {
    let type: String
    let source: ImageSource

    struct ImageSource: Decodable, Sendable {
        let type: String
        let mediaType: String?
        let data: String?
    }
}

// MARK: - Usage Stats

struct UsageStats: Decodable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let totalTokens: Int?
    let serviceTier: String?

    var total: Int {
        totalTokens ?? (inputTokens + outputTokens)
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values
public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Cannot encode AnyCodable"))
        }
    }
}
