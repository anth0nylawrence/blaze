import Foundation

// MARK: - HookType

/// Represents the execution type of a hook handler.
///
/// Hooks can execute in different modes:
/// - **prompt**: Injects a system message into the conversation
/// - **command**: Executes a shell command (script, binary, etc.)
/// - **agent**: Delegates to an AI agent for complex decisions
///
/// Each type has specific template variables available and different
/// timeout defaults based on expected execution time.
///
/// **E005-F009-S001-T001-A001**
public enum HookType: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case prompt
    case command
    case agent

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable hook type name for UI.
    public var displayName: String {
        switch self {
        case .prompt: return "Prompt"
        case .command: return "Command"
        case .agent: return "Agent"
        }
    }

    /// SF Symbol for hook type badge.
    public var icon: String {
        switch self {
        case .prompt: return "text.bubble"
        case .command: return "terminal"
        case .agent: return "person.crop.circle.badge.clock"
        }
    }

    /// Brief description of hook type behavior.
    public var description: String {
        switch self {
        case .prompt:
            return "Injects a system message into the conversation context"
        case .command:
            return "Executes a shell command and optionally returns output"
        case .agent:
            return "Delegates to an AI agent for complex decision-making"
        }
    }

    // MARK: - Execution Properties

    /// Default timeout in seconds for this hook type.
    ///
    /// - Prompt: 5s (fast, just string interpolation)
    /// - Command: 30s (reasonable for most scripts)
    /// - Agent: 120s (AI inference can be slow)
    public var defaultTimeout: TimeInterval {
        switch self {
        case .prompt: return 5.0
        case .command: return 30.0
        case .agent: return 120.0
        }
    }

    // MARK: - Template Variables

    /// Template variables available for this hook type.
    ///
    /// Different hook types have access to different variables:
    /// - Prompt hooks: conversation context variables
    /// - Command hooks: environment and project variables
    /// - Agent hooks: all variables (superset)
    public var templateVariables: [TemplateVariable] {
        switch self {
        case .prompt:
            return [
                TemplateVariable(
                    name: "$TOOL_INPUT",
                    description: "JSON-encoded input passed to the tool",
                    example: "{\"path\": \"/src/main.swift\"}"
                ),
                TemplateVariable(
                    name: "$TOOL_RESULT",
                    description: "JSON-encoded result from tool execution",
                    example: "{\"content\": \"file contents...\"}"
                ),
                TemplateVariable(
                    name: "$USER_PROMPT",
                    description: "The user's original prompt text",
                    example: "Fix the bug in main.swift"
                ),
                TemplateVariable(
                    name: "$TRANSCRIPT_PATH",
                    description: "Path to the conversation transcript file",
                    example: "/tmp/blaze/transcript-abc123.json"
                ),
            ]
        case .command:
            return [
                TemplateVariable(
                    name: "$CLAUDE_PROJECT_DIR",
                    description: "Absolute path to the current project directory",
                    example: "/Users/dev/my-project"
                ),
                TemplateVariable(
                    name: "$CLAUDE_PLUGIN_ROOT",
                    description: "Root directory for CLI plugins and extensions",
                    example: "/Users/dev/.claude/plugins"
                ),
                TemplateVariable(
                    name: "$CLAUDE_ENV_FILE",
                    description: "Path to the environment variables file",
                    example: "/Users/dev/.claude/.env"
                ),
                TemplateVariable(
                    name: "$CLAUDE_CODE_REMOTE",
                    description: "Remote server address if running in remote mode",
                    example: "ssh://user@server:22"
                ),
            ]
        case .agent:
            // Agent hooks have access to all variables
            var variables = HookType.prompt.templateVariables
            variables.append(contentsOf: HookType.command.templateVariables)
            return variables
        }
    }
}

// MARK: - TemplateVariable

/// Describes a template variable available in hook configurations.
///
/// Template variables are placeholders in hook commands or prompts
/// that get replaced with actual values at runtime. This struct
/// provides documentation for UI display and validation.
///
/// **E005-F009-S001-T001-A001**
public struct TemplateVariable: Sendable, Hashable, Identifiable {
    /// Variable name including the $ prefix (e.g., "$TOOL_INPUT").
    public let name: String

    /// Human-readable description of what the variable contains.
    public let description: String

    /// Example value to help users understand the format.
    public let example: String

    // MARK: - Identifiable

    public var id: String { name }

    // MARK: - Initialization

    public init(name: String, description: String, example: String) {
        self.name = name
        self.description = description
        self.example = example
    }
}

// MARK: - HookDefinition

/// Defines a single hook instance with type-specific configuration.
///
/// A hook definition contains all the information needed to execute
/// a hook: the type, matcher pattern, the actual command/prompt/agent
/// configuration, and optional metadata like timeout overrides.
///
/// **E005-F009-S001-T001-A001**
public struct HookDefinition: Codable, Sendable, Hashable, Identifiable {
    /// Unique identifier for this hook definition.
    public let id: UUID

    /// Display name for the hook (used in UI).
    public let name: String

    /// The type of hook (prompt, command, agent).
    public let type: HookType

    /// Optional matcher pattern (tool name, glob, regex).
    /// If nil, hook matches all events of its event type.
    public let matcher: String?

    /// The hook content - interpretation depends on type:
    /// - prompt: The message text to inject
    /// - command: The shell command to execute
    /// - agent: The agent identifier or prompt
    public let content: String

    /// Timeout override in seconds. Uses type default if nil.
    public let timeout: TimeInterval?

    /// Whether this hook is currently enabled.
    public let isEnabled: Bool

    /// Optional description for documentation purposes.
    public let hookDescription: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        type: HookType,
        matcher: String? = nil,
        content: String,
        timeout: TimeInterval? = nil,
        isEnabled: Bool = true,
        hookDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.matcher = matcher
        self.content = content
        self.timeout = timeout
        self.isEnabled = isEnabled
        self.hookDescription = hookDescription
    }

    // MARK: - Computed Properties

    /// Effective timeout (uses type default if not overridden).
    public var effectiveTimeout: TimeInterval {
        timeout ?? type.defaultTimeout
    }

    // MARK: - Validation

    /// Validates this hook definition and returns any errors.
    public func validate() -> [HookValidationError] {
        var errors: [HookValidationError] = []

        // Name validation
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }

        // Content validation
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyContent(hookType: type))
        }

        // Timeout validation
        if let timeout = timeout, timeout <= 0 {
            errors.append(.invalidTimeout(value: timeout))
        }

        // Matcher validation (if present)
        if let matcher = matcher {
            if matcher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyMatcher)
            }
        }

        // Type-specific validation
        switch type {
        case .command:
            // Check for potentially dangerous patterns
            if containsDangerousPattern(content) {
                errors.append(.dangerousCommand(pattern: "destructive shell pattern"))
            }
        case .agent:
            // Agent content should be a valid identifier or prompt
            if content.count < 2 {
                errors.append(.invalidAgentConfig(reason: "Agent identifier too short"))
            }
        case .prompt:
            // Prompt should have meaningful content
            if content.count < 5 {
                errors.append(.invalidPromptContent(reason: "Prompt too short to be useful"))
            }
        }

        return errors
    }

    /// Checks if the hook definition is valid (no errors).
    public var isValid: Bool {
        validate().isEmpty
    }

    // MARK: - Private Helpers

    /// Checks for dangerous shell patterns that could cause harm.
    private func containsDangerousPattern(_ command: String) -> Bool {
        let dangerousPatterns = [
            "rm -rf /",
            "rm -rf ~",
            "> /dev/sd",
            "mkfs.",
            "dd if=",
            ":(){:|:&};:",  // Fork bomb
        ]
        let lowercased = command.lowercased()
        return dangerousPatterns.contains { lowercased.contains($0) }
    }
}

// MARK: - HookValidationError

/// Errors that can occur during hook definition validation.
///
/// These errors provide specific feedback about what's wrong
/// with a hook configuration, enabling targeted UI feedback.
///
/// **E005-F009-S001-T001-A001**
public enum HookValidationError: Error, Sendable, Hashable, Identifiable {
    /// Hook name is empty or whitespace-only.
    case emptyName

    /// Hook content is empty for the given type.
    case emptyContent(hookType: HookType)

    /// Matcher pattern is empty (if provided, must have content).
    case emptyMatcher

    /// Timeout value is invalid (zero or negative).
    case invalidTimeout(value: TimeInterval)

    /// Command contains potentially dangerous patterns.
    case dangerousCommand(pattern: String)

    /// Agent configuration is invalid.
    case invalidAgentConfig(reason: String)

    /// Prompt content is invalid.
    case invalidPromptContent(reason: String)

    /// Template variable reference is invalid or unknown.
    case invalidTemplateVariable(name: String)

    // MARK: - Identifiable

    public var id: String {
        switch self {
        case .emptyName:
            return "emptyName"
        case .emptyContent(let hookType):
            return "emptyContent-\(hookType.rawValue)"
        case .emptyMatcher:
            return "emptyMatcher"
        case .invalidTimeout(let value):
            return "invalidTimeout-\(value)"
        case .dangerousCommand(let pattern):
            return "dangerousCommand-\(pattern)"
        case .invalidAgentConfig(let reason):
            return "invalidAgentConfig-\(reason)"
        case .invalidPromptContent(let reason):
            return "invalidPromptContent-\(reason)"
        case .invalidTemplateVariable(let name):
            return "invalidTemplateVariable-\(name)"
        }
    }

    // MARK: - User-Facing Messages

    /// Human-readable error message for UI display.
    public var message: String {
        switch self {
        case .emptyName:
            return "Hook name cannot be empty"
        case .emptyContent(let hookType):
            return "\(hookType.displayName) content cannot be empty"
        case .emptyMatcher:
            return "Matcher pattern cannot be empty if provided"
        case .invalidTimeout(let value):
            return "Timeout must be positive (got \(value)s)"
        case .dangerousCommand(let pattern):
            return "Command contains dangerous pattern: \(pattern)"
        case .invalidAgentConfig(let reason):
            return "Invalid agent configuration: \(reason)"
        case .invalidPromptContent(let reason):
            return "Invalid prompt: \(reason)"
        case .invalidTemplateVariable(let name):
            return "Unknown template variable: \(name)"
        }
    }

    /// SF Symbol for error severity indication.
    public var icon: String {
        switch self {
        case .dangerousCommand:
            return "exclamationmark.triangle.fill"
        default:
            return "exclamationmark.circle.fill"
        }
    }
}
