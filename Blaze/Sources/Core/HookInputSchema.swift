import Foundation

// MARK: - Hook Input Schema
//
// Codable structs for CLI hook input JSON.
// These match the Claude Code hook input structure and can be extended
// for Gemini CLI and Codex CLI as their hook APIs mature.
//
// **E005-F009-S001-T003-A001**

// MARK: - Base Hook Input

/// Common fields present in all hook inputs.
///
/// Every hook input from Claude Code contains these base fields.
/// Event-specific inputs embed this and add their own fields.
public struct HookInputBase: Codable, Sendable, Equatable {
    /// Session identifier for the current Claude session.
    public let sessionId: String

    /// Conversation identifier (may differ from sessionId for multi-turn).
    public let conversationId: String?

    /// Project root directory path.
    public let projectPath: String?

    /// Current working directory (may differ from projectPath).
    public let cwd: String?

    public init(
        sessionId: String,
        conversationId: String? = nil,
        projectPath: String? = nil,
        cwd: String? = nil
    ) {
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.projectPath = projectPath
        self.cwd = cwd
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case projectPath = "project_path"
        case cwd
    }
}

// MARK: - Tool Input Value

/// Flexible container for tool input parameters.
///
/// Tool inputs can be strings, objects, or other JSON values.
/// This wrapper handles the polymorphic nature of tool_input.
public enum ToolInputValue: Codable, Sendable, Equatable {
    case string(String)
    case dictionary([String: AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictValue)
            return
        }

        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    /// Extract string value if present.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Extract dictionary value if present.
    public var dictionaryValue: [String: AnyCodableValue]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }
}

// MARK: - Any Codable Value

/// Type-erased Codable value for arbitrary JSON.
///
/// Used to represent tool inputs/outputs that can be any JSON type.
public enum AnyCodableValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // Try types in order of specificity
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
            return
        }

        if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictValue)
            return
        }

        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    /// Extract as String if possible.
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    /// Extract as Int if possible.
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    /// Extract as Bool if possible.
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
}

// MARK: - PreToolUse Input

/// Input for PreToolUse hook events.
///
/// Fires before a tool is executed. Hook can block or modify the tool call.
///
/// Example JSON:
/// ```json
/// {
///   "tool_name": "Bash",
///   "tool_input": {"command": "rm -rf /"},
///   "session_id": "abc123",
///   "conversation_id": "conv456",
///   "project_path": "/Users/dev/project"
/// }
/// ```
public struct PreToolUseInput: Codable, Sendable, Equatable {
    /// Name of the tool being invoked (e.g., "Bash", "Read", "Write").
    public let toolName: String

    /// Input parameters for the tool.
    public let toolInput: ToolInputValue

    /// Session identifier.
    public let sessionId: String

    /// Conversation identifier.
    public let conversationId: String?

    /// Project root path.
    public let projectPath: String?

    public init(
        toolName: String,
        toolInput: ToolInputValue,
        sessionId: String,
        conversationId: String? = nil,
        projectPath: String? = nil
    ) {
        self.toolName = toolName
        self.toolInput = toolInput
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.projectPath = projectPath
    }

    private enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case projectPath = "project_path"
    }
}

// MARK: - PostToolUse Input

/// Input for PostToolUse hook events.
///
/// Fires after a tool completes execution. Cannot block, only observe.
///
/// Example JSON:
/// ```json
/// {
///   "tool_name": "Read",
///   "tool_input": {"file_path": "/src/main.swift"},
///   "tool_output": "file contents...",
///   "tool_error": null,
///   "duration_ms": 42,
///   "session_id": "abc123"
/// }
/// ```
public struct PostToolUseInput: Codable, Sendable, Equatable {
    /// Name of the tool that was executed.
    public let toolName: String

    /// Input parameters that were passed to the tool.
    public let toolInput: ToolInputValue

    /// Output from the tool execution (may be truncated).
    public let toolOutput: String?

    /// Error message if the tool failed.
    public let toolError: String?

    /// Execution duration in milliseconds.
    public let durationMs: Int?

    /// Session identifier.
    public let sessionId: String

    /// Conversation identifier.
    public let conversationId: String?

    /// Project root path.
    public let projectPath: String?

    public init(
        toolName: String,
        toolInput: ToolInputValue,
        toolOutput: String? = nil,
        toolError: String? = nil,
        durationMs: Int? = nil,
        sessionId: String,
        conversationId: String? = nil,
        projectPath: String? = nil
    ) {
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolOutput = toolOutput
        self.toolError = toolError
        self.durationMs = durationMs
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.projectPath = projectPath
    }

    private enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolOutput = "tool_output"
        case toolError = "tool_error"
        case durationMs = "duration_ms"
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case projectPath = "project_path"
    }
}

// MARK: - UserPromptSubmit Input

/// Input for UserPromptSubmit hook events.
///
/// Fires when the user submits a prompt. Can modify or block the prompt.
///
/// Example JSON:
/// ```json
/// {
///   "prompt": "Delete all files",
///   "session_id": "abc123",
///   "conversation_id": "conv456",
///   "project_path": "/Users/dev/project"
/// }
/// ```
public struct UserPromptSubmitInput: Codable, Sendable, Equatable {
    /// The user's prompt text.
    public let prompt: String

    /// Session identifier.
    public let sessionId: String

    /// Conversation identifier.
    public let conversationId: String?

    /// Project root path.
    public let projectPath: String?

    public init(
        prompt: String,
        sessionId: String,
        conversationId: String? = nil,
        projectPath: String? = nil
    ) {
        self.prompt = prompt
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.projectPath = projectPath
    }

    private enum CodingKeys: String, CodingKey {
        case prompt
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case projectPath = "project_path"
    }
}

// MARK: - SessionStart Input

/// Input for SessionStart hook events.
///
/// Fires when a session starts or resumes.
///
/// Example JSON:
/// ```json
/// {
///   "session_id": "abc123",
///   "project_path": "/Users/dev/project",
///   "type": "start",
///   "cwd": "/Users/dev/project"
/// }
/// ```
public struct SessionStartInput: Codable, Sendable, Equatable {
    /// Session identifier.
    public let sessionId: String

    /// Project root path.
    public let projectPath: String?

    /// Session start type: "start", "resume", or "compact".
    public let type: SessionStartType

    /// Current working directory.
    public let cwd: String?

    public init(
        sessionId: String,
        projectPath: String? = nil,
        type: SessionStartType = .start,
        cwd: String? = nil
    ) {
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.type = type
        self.cwd = cwd
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case projectPath = "project_path"
        case type
        case cwd
    }
}

/// Type of session start event.
public enum SessionStartType: String, Codable, Sendable, Equatable {
    case start = "start"
    case resume = "resume"
    case compact = "compact"
}

// MARK: - Stop Input

/// Input for Stop hook events.
///
/// Fires when the agent stops or completes a turn.
///
/// Example JSON:
/// ```json
/// {
///   "stop_reason": "end_of_turn",
///   "session_id": "abc123",
///   "conversation_id": "conv456",
///   "project_path": "/Users/dev/project",
///   "turn_count": 5
/// }
/// ```
public struct StopInput: Codable, Sendable, Equatable {
    /// Reason for stopping (e.g., "end_of_turn", "user_interrupt", "error").
    public let stopReason: String

    /// Session identifier.
    public let sessionId: String

    /// Conversation identifier.
    public let conversationId: String?

    /// Project root path.
    public let projectPath: String?

    /// Number of turns completed in the session.
    public let turnCount: Int?

    public init(
        stopReason: String,
        sessionId: String,
        conversationId: String? = nil,
        projectPath: String? = nil,
        turnCount: Int? = nil
    ) {
        self.stopReason = stopReason
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.projectPath = projectPath
        self.turnCount = turnCount
    }

    private enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case projectPath = "project_path"
        case turnCount = "turn_count"
    }
}

// MARK: - PreCompact Input

/// Input for PreCompact hook events.
///
/// Fires before context is compacted due to token limits.
///
/// Example JSON:
/// ```json
/// {
///   "session_id": "abc123",
///   "conversation_id": "conv456",
///   "project_path": "/Users/dev/project",
///   "token_count": 180000,
///   "token_limit": 200000
/// }
/// ```
public struct PreCompactInput: Codable, Sendable, Equatable {
    /// Session identifier.
    public let sessionId: String

    /// Conversation identifier.
    public let conversationId: String?

    /// Project root path.
    public let projectPath: String?

    /// Current token count before compaction.
    public let tokenCount: Int

    /// Token limit that triggered compaction.
    public let tokenLimit: Int

    public init(
        sessionId: String,
        conversationId: String? = nil,
        projectPath: String? = nil,
        tokenCount: Int,
        tokenLimit: Int
    ) {
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.projectPath = projectPath
        self.tokenCount = tokenCount
        self.tokenLimit = tokenLimit
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case conversationId = "conversation_id"
        case projectPath = "project_path"
        case tokenCount = "token_count"
        case tokenLimit = "token_limit"
    }
}

// MARK: - Notification Input

/// Input for Notification hook events.
///
/// Fires when the agent sends a notification to the user.
///
/// Example JSON:
/// ```json
/// {
///   "notification_type": "task_complete",
///   "notification_message": "Build succeeded",
///   "session_id": "abc123",
///   "project_path": "/Users/dev/project"
/// }
/// ```
public struct NotificationInput: Codable, Sendable, Equatable {
    /// Type of notification (e.g., "task_complete", "error", "info").
    public let notificationType: String

    /// Notification message content.
    public let notificationMessage: String

    /// Session identifier.
    public let sessionId: String

    /// Project root path.
    public let projectPath: String?

    public init(
        notificationType: String,
        notificationMessage: String,
        sessionId: String,
        projectPath: String? = nil
    ) {
        self.notificationType = notificationType
        self.notificationMessage = notificationMessage
        self.sessionId = sessionId
        self.projectPath = projectPath
    }

    private enum CodingKeys: String, CodingKey {
        case notificationType = "notification_type"
        case notificationMessage = "notification_message"
        case sessionId = "session_id"
        case projectPath = "project_path"
    }
}

// MARK: - Permission Request Input

/// Input for PermissionRequest hook events.
///
/// Fires when the agent requests permission for an action.
///
/// Example JSON:
/// ```json
/// {
///   "permission_type": "file_write",
///   "tool_name": "Write",
///   "tool_input": {"file_path": "/etc/passwd"},
///   "session_id": "abc123",
///   "project_path": "/Users/dev/project"
/// }
/// ```
public struct PermissionRequestInput: Codable, Sendable, Equatable {
    /// Type of permission being requested.
    public let permissionType: String

    /// Tool requesting permission.
    public let toolName: String

    /// Tool input parameters.
    public let toolInput: ToolInputValue

    /// Session identifier.
    public let sessionId: String

    /// Project root path.
    public let projectPath: String?

    public init(
        permissionType: String,
        toolName: String,
        toolInput: ToolInputValue,
        sessionId: String,
        projectPath: String? = nil
    ) {
        self.permissionType = permissionType
        self.toolName = toolName
        self.toolInput = toolInput
        self.sessionId = sessionId
        self.projectPath = projectPath
    }

    private enum CodingKeys: String, CodingKey {
        case permissionType = "permission_type"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case sessionId = "session_id"
        case projectPath = "project_path"
    }
}

// MARK: - Unified Hook Input

/// Unified hook input that can represent any event type.
///
/// Use this when you need to decode hook input without knowing
/// the event type ahead of time.
public enum HookInput: Codable, Sendable, Equatable {
    case preToolUse(PreToolUseInput)
    case postToolUse(PostToolUseInput)
    case userPromptSubmit(UserPromptSubmitInput)
    case sessionStart(SessionStartInput)
    case stop(StopInput)
    case preCompact(PreCompactInput)
    case notification(NotificationInput)
    case permissionRequest(PermissionRequestInput)

    /// The event type for this input.
    public var eventType: CLIHookEventType {
        switch self {
        case .preToolUse: return .preToolUse
        case .postToolUse: return .postToolUse
        case .userPromptSubmit: return .userPromptSubmit
        case .sessionStart: return .sessionStart
        case .stop: return .stop
        case .preCompact: return .preCompact
        case .notification: return .notification
        case .permissionRequest: return .permissionRequest
        }
    }

    /// Extract session ID from any input type.
    public var sessionId: String {
        switch self {
        case .preToolUse(let input): return input.sessionId
        case .postToolUse(let input): return input.sessionId
        case .userPromptSubmit(let input): return input.sessionId
        case .sessionStart(let input): return input.sessionId
        case .stop(let input): return input.sessionId
        case .preCompact(let input): return input.sessionId
        case .notification(let input): return input.sessionId
        case .permissionRequest(let input): return input.sessionId
        }
    }

    /// Extract project path from any input type.
    public var projectPath: String? {
        switch self {
        case .preToolUse(let input): return input.projectPath
        case .postToolUse(let input): return input.projectPath
        case .userPromptSubmit(let input): return input.projectPath
        case .sessionStart(let input): return input.projectPath
        case .stop(let input): return input.projectPath
        case .preCompact(let input): return input.projectPath
        case .notification(let input): return input.projectPath
        case .permissionRequest(let input): return input.projectPath
        }
    }

    // MARK: - Decoding

    /// Decode hook input based on event type.
    ///
    /// - Parameters:
    ///   - data: JSON data to decode
    ///   - eventType: The known event type
    /// - Returns: Decoded HookInput
    public static func decode(from data: Data, eventType: CLIHookEventType) throws -> HookInput {
        let decoder = JSONDecoder()
        switch eventType {
        case .preToolUse:
            return .preToolUse(try decoder.decode(PreToolUseInput.self, from: data))
        case .postToolUse:
            return .postToolUse(try decoder.decode(PostToolUseInput.self, from: data))
        case .userPromptSubmit:
            return .userPromptSubmit(try decoder.decode(UserPromptSubmitInput.self, from: data))
        case .sessionStart:
            return .sessionStart(try decoder.decode(SessionStartInput.self, from: data))
        case .stop:
            return .stop(try decoder.decode(StopInput.self, from: data))
        case .preCompact:
            return .preCompact(try decoder.decode(PreCompactInput.self, from: data))
        case .notification:
            return .notification(try decoder.decode(NotificationInput.self, from: data))
        case .permissionRequest:
            return .permissionRequest(try decoder.decode(PermissionRequestInput.self, from: data))
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        // Try each type in order, starting with most common
        if let input = try? PreToolUseInput(from: decoder) {
            self = .preToolUse(input)
            return
        }
        if let input = try? PostToolUseInput(from: decoder) {
            self = .postToolUse(input)
            return
        }
        if let input = try? SessionStartInput(from: decoder) {
            self = .sessionStart(input)
            return
        }
        if let input = try? StopInput(from: decoder) {
            self = .stop(input)
            return
        }
        if let input = try? UserPromptSubmitInput(from: decoder) {
            self = .userPromptSubmit(input)
            return
        }
        if let input = try? PreCompactInput(from: decoder) {
            self = .preCompact(input)
            return
        }
        if let input = try? NotificationInput(from: decoder) {
            self = .notification(input)
            return
        }
        if let input = try? PermissionRequestInput(from: decoder) {
            self = .permissionRequest(input)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Could not decode HookInput: no matching event type"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .preToolUse(let input): try input.encode(to: encoder)
        case .postToolUse(let input): try input.encode(to: encoder)
        case .userPromptSubmit(let input): try input.encode(to: encoder)
        case .sessionStart(let input): try input.encode(to: encoder)
        case .stop(let input): try input.encode(to: encoder)
        case .preCompact(let input): try input.encode(to: encoder)
        case .notification(let input): try input.encode(to: encoder)
        case .permissionRequest(let input): try input.encode(to: encoder)
        }
    }
}
