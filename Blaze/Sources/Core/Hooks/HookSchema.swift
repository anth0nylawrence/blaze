import Foundation

// MARK: - CLI Hook Event Type

/// All hook event types supported by CLI providers (Claude Code, Gemini CLI, etc.).
/// These map to the provider's hooks.json/settings.json schema.
/// Distinct from `HookEventType` (in HookStore) which is for Blaze's internal hooks.
///
/// **E005-F004-S001-T002-A001**
public enum CLIHookEventType: String, Codable, Sendable, CaseIterable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case sessionStart = "SessionStart"
    case preCompact = "PreCompact"
    case notification = "Notification"
    case permissionRequest = "PermissionRequest"
    case userPromptSubmit = "UserPromptSubmit"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .preToolUse: return "Pre Tool Use"
        case .postToolUse: return "Post Tool Use"
        case .stop: return "Stop"
        case .sessionStart: return "Session Start"
        case .preCompact: return "Pre Compact"
        case .notification: return "Notification"
        case .permissionRequest: return "Permission Request"
        case .userPromptSubmit: return "User Prompt Submit"
        }
    }

    /// SF Symbol icon for the event type.
    public var icon: String {
        switch self {
        case .preToolUse: return "hammer.fill"
        case .postToolUse: return "checkmark.circle.fill"
        case .stop: return "stop.circle.fill"
        case .sessionStart: return "play.circle.fill"
        case .preCompact: return "arrow.triangle.2.circlepath"
        case .notification: return "bell.fill"
        case .permissionRequest: return "lock.shield.fill"
        case .userPromptSubmit: return "text.bubble.fill"
        }
    }

    /// Whether this event can block/modify execution flow.
    public var canBlock: Bool {
        switch self {
        case .preToolUse, .permissionRequest, .userPromptSubmit:
            return true
        case .postToolUse, .stop, .sessionStart, .preCompact, .notification:
            return false
        }
    }
}

// MARK: - Hook Matcher

/// Pattern matching configuration for hook events.
/// Determines which events trigger a hook based on tool names or other criteria.
public struct HookMatcher: Codable, Sendable, Equatable {
    /// Glob patterns to match tool names (e.g., "Bash", "Read*", "mcp__*").
    public var toolPatterns: [String]

    /// File path patterns for file-related events (e.g., "*.swift", "src/**").
    public var filePatterns: [String]

    /// Custom predicate expression (provider-specific).
    public var predicate: String?

    public init(
        toolPatterns: [String] = [],
        filePatterns: [String] = [],
        predicate: String? = nil
    ) {
        self.toolPatterns = toolPatterns
        self.filePatterns = filePatterns
        self.predicate = predicate
    }

    /// Check if the matcher matches a given tool name.
    public func matches(toolName: String) -> Bool {
        if toolPatterns.isEmpty {
            return true // No patterns = match all
        }
        return toolPatterns.contains { pattern in
            matchesGlob(pattern: pattern, value: toolName)
        }
    }

    /// Check if the matcher matches a given file path.
    public func matches(filePath: String) -> Bool {
        if filePatterns.isEmpty {
            return true
        }
        return filePatterns.contains { pattern in
            matchesGlob(pattern: pattern, value: filePath)
        }
    }

    /// Simple glob matching (supports * and **).
    private func matchesGlob(pattern: String, value: String) -> Bool {
        // Convert glob to regex
        var regex = "^"
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let char = pattern[i]
            if char == "*" {
                let next = pattern.index(after: i)
                if next < pattern.endIndex && pattern[next] == "*" {
                    regex += ".*"
                    i = pattern.index(after: next)
                    continue
                } else {
                    regex += "[^/]*"
                }
            } else if char == "?" {
                regex += "."
            } else if "[](){}+^$.|\\".contains(char) {
                regex += "\\\(char)"
            } else {
                regex += String(char)
            }
            i = pattern.index(after: i)
        }
        regex += "$"

        return (try? NSRegularExpression(pattern: regex, options: []))?
            .firstMatch(in: value, options: [], range: NSRange(value.startIndex..., in: value)) != nil
    }
}

// MARK: - Hook Capability

/// Describes what hook events a provider supports and their characteristics.
public struct HookCapability: Codable, Sendable, Equatable {
    /// The provider this capability describes.
    public var provider: HookProvider

    /// Set of event types this provider supports.
    public var supportedEvents: Set<CLIHookEventType>

    /// Whether the provider supports matcher patterns.
    public var supportsMatcher: Bool

    /// Whether the provider supports blocking hooks (can deny tool execution).
    public var supportsBlocking: Bool

    /// Whether the provider supports injecting system messages via hooks.
    public var supportsSystemMessage: Bool

    /// Whether the provider supports modifying tool input via hooks.
    public var supportsInputModification: Bool

    /// Maximum number of hooks per event type (0 = unlimited).
    public var maxHooksPerEvent: Int

    public init(
        provider: HookProvider,
        supportedEvents: Set<CLIHookEventType>,
        supportsMatcher: Bool = true,
        supportsBlocking: Bool = true,
        supportsSystemMessage: Bool = true,
        supportsInputModification: Bool = false,
        maxHooksPerEvent: Int = 0
    ) {
        self.provider = provider
        self.supportedEvents = supportedEvents
        self.supportsMatcher = supportsMatcher
        self.supportsBlocking = supportsBlocking
        self.supportsSystemMessage = supportsSystemMessage
        self.supportsInputModification = supportsInputModification
        self.maxHooksPerEvent = maxHooksPerEvent
    }

    /// Check if the provider supports a specific event type.
    public func supports(event: CLIHookEventType) -> Bool {
        supportedEvents.contains(event)
    }

    // MARK: - Built-in Capabilities

    /// Claude Code hook capabilities.
    public static let claude = HookCapability(
        provider: .claude,
        supportedEvents: [
            CLIHookEventType.preToolUse,
            CLIHookEventType.postToolUse,
            CLIHookEventType.stop,
            CLIHookEventType.sessionStart,
            CLIHookEventType.preCompact,
            CLIHookEventType.userPromptSubmit
        ],
        supportsMatcher: true,
        supportsBlocking: true,
        supportsSystemMessage: true,
        supportsInputModification: true,
        maxHooksPerEvent: 0
    )

    /// Gemini CLI hook capabilities.
    public static let gemini = HookCapability(
        provider: .gemini,
        supportedEvents: [
            CLIHookEventType.preToolUse,
            CLIHookEventType.postToolUse,
            CLIHookEventType.sessionStart,
            CLIHookEventType.stop
        ],
        supportsMatcher: true,
        supportsBlocking: true,
        supportsSystemMessage: false,
        supportsInputModification: false,
        maxHooksPerEvent: 10
    )

    /// Codex CLI hook capabilities (none - hooks not yet supported).
    public static let codex = HookCapability(
        provider: .codex,
        supportedEvents: [],
        supportsMatcher: false,
        supportsBlocking: false,
        supportsSystemMessage: false,
        supportsInputModification: false,
        maxHooksPerEvent: 0
    )

    /// Get capabilities for a provider.
    public static func forProvider(_ provider: HookProvider) -> HookCapability {
        switch provider {
        case .claude: return .claude
        case .gemini: return .gemini
        case .codex: return .codex
        }
    }
}

// MARK: - Hook Event Definition

/// Defines the schema and metadata for a CLI hook event type.
/// Used to validate hook configurations and generate UI.
public struct CLIHookEventDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: CLIHookEventType { eventType }

    /// The event type this definition describes.
    public var eventType: CLIHookEventType

    /// Human-readable description of when this event fires.
    public var description: String

    /// Field names available in the hook input JSON.
    public var inputSchema: [String]

    /// Field names that can be returned in the hook output.
    public var outputSchema: [String]

    /// Example input JSON for documentation.
    public var exampleInput: String?

    public init(
        eventType: CLIHookEventType,
        description: String,
        inputSchema: [String],
        outputSchema: [String] = ["result", "message"],
        exampleInput: String? = nil
    ) {
        self.eventType = eventType
        self.description = description
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.exampleInput = exampleInput
    }

    // MARK: - Built-in Definitions

    /// All hook event definitions.
    public static let all: [CLIHookEventDefinition] = [
        preToolUse,
        postToolUse,
        stop,
        sessionStart,
        preCompact,
        notification,
        permissionRequest,
        userPromptSubmit
    ]

    /// Definition for PreToolUse event.
    public static let preToolUse = CLIHookEventDefinition(
        eventType: .preToolUse,
        description: "Fires before a tool is executed. Can block or modify the tool call.",
        inputSchema: [
            "tool_name",
            "tool_input",
            "session_id",
            "conversation_id",
            "project_path"
        ],
        outputSchema: [
            "result",      // "continue", "block"
            "message",     // System message to inject
            "reason",      // Block reason (if blocking)
            "updatedInput" // Modified tool input (optional)
        ],
        exampleInput: """
        {
          "tool_name": "Bash",
          "tool_input": {"command": "rm -rf /"},
          "session_id": "abc123",
          "project_path": "/Users/dev/project"
        }
        """
    )

    /// Definition for PostToolUse event.
    public static let postToolUse = CLIHookEventDefinition(
        eventType: .postToolUse,
        description: "Fires after a tool completes execution. Cannot block, only observe.",
        inputSchema: [
            "tool_name",
            "tool_input",
            "tool_output",
            "tool_error",
            "duration_ms",
            "session_id",
            "conversation_id",
            "project_path"
        ],
        outputSchema: [
            "result",  // "continue" only
            "message"  // System message to inject
        ],
        exampleInput: """
        {
          "tool_name": "Read",
          "tool_input": {"file_path": "/src/main.swift"},
          "tool_output": "file contents...",
          "duration_ms": 42,
          "session_id": "abc123"
        }
        """
    )

    /// Definition for Stop event.
    public static let stop = CLIHookEventDefinition(
        eventType: .stop,
        description: "Fires when the agent stops or completes a turn.",
        inputSchema: [
            "stop_reason",
            "session_id",
            "conversation_id",
            "project_path",
            "turn_count"
        ],
        outputSchema: ["result", "message"],
        exampleInput: """
        {
          "stop_reason": "end_of_turn",
          "session_id": "abc123",
          "turn_count": 5
        }
        """
    )

    /// Definition for SessionStart event.
    public static let sessionStart = CLIHookEventDefinition(
        eventType: .sessionStart,
        description: "Fires when a session starts or resumes.",
        inputSchema: [
            "session_id",
            "project_path",
            "type",  // "start", "resume", "compact"
            "cwd"
        ],
        outputSchema: ["result", "message"],
        exampleInput: """
        {
          "session_id": "abc123",
          "project_path": "/Users/dev/project",
          "type": "start",
          "cwd": "/Users/dev/project"
        }
        """
    )

    /// Definition for PreCompact event.
    public static let preCompact = CLIHookEventDefinition(
        eventType: .preCompact,
        description: "Fires before context is compacted due to token limits.",
        inputSchema: [
            "session_id",
            "conversation_id",
            "project_path",
            "token_count",
            "token_limit"
        ],
        outputSchema: ["result", "message"],
        exampleInput: """
        {
          "session_id": "abc123",
          "token_count": 180000,
          "token_limit": 200000
        }
        """
    )

    /// Definition for Notification event.
    public static let notification = CLIHookEventDefinition(
        eventType: .notification,
        description: "Fires when the agent sends a notification to the user.",
        inputSchema: [
            "notification_type",
            "notification_message",
            "session_id",
            "project_path"
        ],
        outputSchema: ["result", "message"],
        exampleInput: """
        {
          "notification_type": "task_complete",
          "notification_message": "Build succeeded",
          "session_id": "abc123"
        }
        """
    )

    /// Definition for PermissionRequest event.
    public static let permissionRequest = CLIHookEventDefinition(
        eventType: .permissionRequest,
        description: "Fires when the agent requests permission for an action.",
        inputSchema: [
            "permission_type",
            "tool_name",
            "tool_input",
            "session_id",
            "project_path"
        ],
        outputSchema: [
            "result",           // "continue", "block"
            "message",
            "permissionDecision" // "allow", "deny", "ask"
        ],
        exampleInput: """
        {
          "permission_type": "file_write",
          "tool_name": "Write",
          "tool_input": {"file_path": "/etc/passwd"},
          "session_id": "abc123"
        }
        """
    )

    /// Definition for UserPromptSubmit event.
    public static let userPromptSubmit = CLIHookEventDefinition(
        eventType: .userPromptSubmit,
        description: "Fires when the user submits a prompt. Can modify or block.",
        inputSchema: [
            "prompt",
            "session_id",
            "conversation_id",
            "project_path"
        ],
        outputSchema: [
            "result",       // "continue", "block"
            "message",
            "updatedPrompt" // Modified prompt (optional)
        ],
        exampleInput: """
        {
          "prompt": "Delete all files",
          "session_id": "abc123",
          "project_path": "/Users/dev/project"
        }
        """
    )

    /// Get definition for an event type.
    public static func forEvent(_ eventType: CLIHookEventType) -> CLIHookEventDefinition {
        switch eventType {
        case .preToolUse: return preToolUse
        case .postToolUse: return postToolUse
        case .stop: return stop
        case .sessionStart: return sessionStart
        case .preCompact: return preCompact
        case .notification: return notification
        case .permissionRequest: return permissionRequest
        case .userPromptSubmit: return userPromptSubmit
        }
    }
}
