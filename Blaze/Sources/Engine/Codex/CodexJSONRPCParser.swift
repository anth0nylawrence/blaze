//
//  CodexJSONRPCParser.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

// MARK: - JSON-RPC Message Type

/// Discriminates JSON-RPC 2.0 message types by field presence.
///
/// ## Classification Rules
/// - **response**: Has `id` + (`result` or `error`)
/// - **request**: Has `id` + `method`
/// - **notification**: Has `method` but no `id`
public enum JSONRPCMessageType: String, Sendable {
    case response
    case request
    case notification
}

// MARK: - JSON-RPC Parse Error

/// Error details when JSON-RPC parsing fails
public struct JSONRPCParseError: Error, Sendable {
    public let rawLine: String
    public let reason: ParseFailureReason
    public let underlyingError: Error?
    public let timestamp: Date

    public enum ParseFailureReason: String, Sendable {
        case invalidJSON = "invalid_json"
        case missingRequiredFields = "missing_required_fields"
        case malformedStructure = "malformed_structure"
    }

    public var localizedDescription: String {
        switch reason {
        case .invalidJSON:
            return "Invalid JSON: \(underlyingError?.localizedDescription ?? "unknown")"
        case .missingRequiredFields:
            return "Missing required JSON-RPC fields (jsonrpc, method/result/error)"
        case .malformedStructure:
            return "Malformed JSON-RPC structure"
        }
    }
}

// MARK: - JSON-RPC Error Object

/// Standard JSON-RPC 2.0 error object
public struct JSONRPCError: Decodable, Sendable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?

    /// Standard JSON-RPC error codes
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
}

// MARK: - JSON-RPC Message

/// Unified representation of any JSON-RPC 2.0 message.
///
/// Codex uses JSON-RPC 2.0 over stdio. This struct captures all message variants:
/// - Responses (to our requests)
/// - Requests (from Codex asking for input/approval)
/// - Notifications (one-way events like progress updates)
public struct JSONRPCMessage: Sendable {
    /// Discriminated message type
    public let type: JSONRPCMessageType

    /// Message ID (nil for notifications)
    public let id: JSONRPCId?

    /// Method name (nil for responses)
    public let method: String?

    /// Method parameters (for requests/notifications)
    public let params: AnyCodable?

    /// Result value (for successful responses)
    public let result: AnyCodable?

    /// Error object (for failed responses)
    public let error: JSONRPCError?

    /// Original raw line for debugging
    public let rawLine: String

    /// Parse timestamp
    public let timestamp: Date
}

// MARK: - JSON-RPC ID

/// JSON-RPC id can be string, number, or null
public enum JSONRPCId: Sendable, Equatable, Hashable {
    case string(String)
    case number(Int)

    public var stringValue: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        }
    }
}

extension JSONRPCId: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intId = try? container.decode(Int.self) {
            self = .number(intId)
        } else if let stringId = try? container.decode(String.self) {
            self = .string(stringId)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "JSON-RPC id must be string or integer"
            )
        }
    }
}

extension JSONRPCId: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let n): try container.encode(n)
        case .string(let s): try container.encode(s)
        }
    }
}

// MARK: - Known Codex Methods

/// Known Codex JSON-RPC method names for type-safe handling
public enum CodexMethod: String, Sendable {
    // Agent message events
    case itemAgentMessageDelta = "item/agentMessage/delta"
    case itemAgentMessageCompleted = "item/agentMessage/completed"

    // Turn lifecycle
    case turnStarted = "turn/started"
    case turnCompleted = "turn/completed"

    // Tool events
    case itemToolCallStarted = "item/toolCall/started"
    case itemToolCallCompleted = "item/toolCall/completed"

    // Exec events
    case execStarted = "exec/started"
    case execCompleted = "exec/completed"

    // Approval requests (from Codex to harness)
    case approvalRequest = "approval/request"

    /// Parse from raw method string
    public static func from(_ raw: String) -> CodexMethod? {
        CodexMethod(rawValue: raw)
    }
}

// MARK: - JSON-RPC Parser

/// Stateless parser for Codex JSON-RPC 2.0 messages.
///
/// Codex emits newline-delimited JSON-RPC over stdio. Each line is one message.
///
/// ## Usage
/// ```swift
/// let parser = CodexJSONRPCParser()
/// for line in stdoutLines {
///     switch parser.parse(line: line) {
///     case .success(let msg):
///         handleMessage(msg)
///     case .failure(let err):
///         logError(err)
///     }
/// }
/// ```
public struct CodexJSONRPCParser: Sendable {
    private let decoder: JSONDecoder

    public init() {
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Parse a single line of JSON-RPC output.
    ///
    /// - Parameter line: Raw JSON string (one complete message)
    /// - Returns: Parsed message or parse error
    public func parse(line: String) -> Result<JSONRPCMessage, JSONRPCParseError> {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty lines
        guard !trimmed.isEmpty else {
            return .failure(JSONRPCParseError(
                rawLine: line,
                reason: .invalidJSON,
                underlyingError: nil,
                timestamp: Date()
            ))
        }

        // Parse JSON
        guard let data = trimmed.data(using: .utf8) else {
            return .failure(JSONRPCParseError(
                rawLine: line,
                reason: .invalidJSON,
                underlyingError: nil,
                timestamp: Date()
            ))
        }

        do {
            let rawMessage = try decoder.decode(RawJSONRPCMessage.self, from: data)
            return classify(raw: rawMessage, line: trimmed)
        } catch {
            return .failure(JSONRPCParseError(
                rawLine: line,
                reason: .invalidJSON,
                underlyingError: error,
                timestamp: Date()
            ))
        }
    }

    /// Classify message type based on field presence
    private func classify(raw: RawJSONRPCMessage, line: String) -> Result<JSONRPCMessage, JSONRPCParseError> {
        let now = Date()

        // Response: has id + (result OR error)
        if let id = raw.id, (raw.result != nil || raw.error != nil) {
            return .success(JSONRPCMessage(
                type: .response,
                id: id,
                method: nil,
                params: nil,
                result: raw.result,
                error: raw.error,
                rawLine: line,
                timestamp: now
            ))
        }

        // Request: has id + method
        if let id = raw.id, let method = raw.method {
            return .success(JSONRPCMessage(
                type: .request,
                id: id,
                method: method,
                params: raw.params,
                result: nil,
                error: nil,
                rawLine: line,
                timestamp: now
            ))
        }

        // Notification: has method but no id
        if let method = raw.method, raw.id == nil {
            return .success(JSONRPCMessage(
                type: .notification,
                id: nil,
                method: method,
                params: raw.params,
                result: nil,
                error: nil,
                rawLine: line,
                timestamp: now
            ))
        }

        // Doesn't match any valid JSON-RPC pattern
        return .failure(JSONRPCParseError(
            rawLine: line,
            reason: .missingRequiredFields,
            underlyingError: nil,
            timestamp: now
        ))
    }
}

// MARK: - Raw Message for Decoding

/// Internal struct for initial JSON decoding before classification
private struct RawJSONRPCMessage: Decodable {
    let jsonrpc: String?
    let id: JSONRPCId?
    let method: String?
    let params: AnyCodable?
    let result: AnyCodable?
    let error: JSONRPCError?
}

// MARK: - Convenience Extensions

extension JSONRPCMessage {
    /// Check if this is a known Codex method
    public var codexMethod: CodexMethod? {
        guard let method else { return nil }
        return CodexMethod.from(method)
    }

    /// Extract params as dictionary (common case)
    public var paramsDict: [String: Any]? {
        params?.value as? [String: Any]
    }

    /// Extract result as dictionary
    public var resultDict: [String: Any]? {
        result?.value as? [String: Any]
    }
}
