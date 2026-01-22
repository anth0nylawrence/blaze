import Foundation

// MARK: - Hook Environment Variable Category

/// Categories for grouping environment variables by their source and purpose.
///
/// Environment variables available to hooks come from different sources:
/// - **claude**: Claude Code specific variables set by the CLI
/// - **system**: Standard Unix environment variables (HOME, PATH, USER)
/// - **blaze**: Variables set by the Blaze harness application
/// - **custom**: User-defined variables from .env files
///
/// **E005-F009-S001-T007-A001**
public enum HookEnvironmentCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case claude
    case system
    case blaze
    case custom

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable category name for UI.
    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .system: return "System"
        case .blaze: return "Blaze"
        case .custom: return "Custom"
        }
    }

    /// Brief description of what this category contains.
    public var description: String {
        switch self {
        case .claude:
            return "Variables set by Claude Code CLI during hook execution"
        case .system:
            return "Standard Unix environment variables"
        case .blaze:
            return "Variables set by the Blaze harness application"
        case .custom:
            return "User-defined variables from .env files"
        }
    }

    /// SF Symbol icon for the category.
    public var icon: String {
        switch self {
        case .claude: return "cpu"
        case .system: return "terminal"
        case .blaze: return "flame"
        case .custom: return "gear"
        }
    }
}

// MARK: - Hook Environment Variable

/// Describes an environment variable available to hooks during execution.
///
/// Environment variables are passed to hook scripts and can be referenced
/// in command templates. This struct provides documentation for UI display,
/// validation, and runtime value retrieval.
///
/// **E005-F009-S001-T007-A001**
public struct HookEnvironmentVariable: Sendable, Hashable, Identifiable, Codable {
    /// Variable name without the $ prefix (e.g., "CLAUDE_PROJECT_DIR").
    public let name: String

    /// Human-readable description of what the variable contains.
    public let description: String

    /// Example value to help users understand the format.
    public let example: String

    /// The source/category of this variable.
    public let category: HookEnvironmentCategory

    /// Whether this variable is required (must be set for hooks to work).
    public let isRequired: Bool

    /// Default value if the variable is not set (nil if no default).
    public let defaultValue: String?

    // MARK: - Identifiable

    public var id: String { name }

    // MARK: - Initialization

    public init(
        name: String,
        description: String,
        example: String,
        category: HookEnvironmentCategory,
        isRequired: Bool = false,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.description = description
        self.example = example
        self.category = category
        self.isRequired = isRequired
        self.defaultValue = defaultValue
    }

    // MARK: - Runtime Value Access

    /// Gets the current value of this environment variable.
    ///
    /// Reads from `ProcessInfo.processInfo.environment`. Returns nil if
    /// the variable is not set in the current process environment.
    public func getCurrentValue() -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    /// Gets the effective value (current value or default).
    ///
    /// Returns the current environment value if set, otherwise falls
    /// back to the default value if one is defined.
    public var effectiveValue: String? {
        getCurrentValue() ?? defaultValue
    }

    /// Variable name with $ prefix for use in shell commands.
    public var shellReference: String {
        "$\(name)"
    }

    /// Variable reference for use in templates (e.g., "${CLAUDE_PROJECT_DIR}").
    public var templateReference: String {
        "${\(name)}"
    }
}

// MARK: - Hook Environment

/// Central registry of environment variables available to hooks.
///
/// Provides a complete reference of all known environment variables
/// that hooks can access, organized by category. Use this for:
/// - Documenting available variables in the UI
/// - Validating variable references in hook templates
/// - Retrieving current values at runtime
///
/// **E005-F009-S001-T007-A001**
public enum HookEnvironment {

    // MARK: - Claude Code Variables

    /// Project root directory set by Claude Code CLI.
    public static let claudeProjectDir = HookEnvironmentVariable(
        name: "CLAUDE_PROJECT_DIR",
        description: "Absolute path to the current project's root directory",
        example: "/Users/dev/my-project",
        category: .claude,
        isRequired: true
    )

    /// Plugin/extension root directory.
    public static let claudePluginRoot = HookEnvironmentVariable(
        name: "CLAUDE_PLUGIN_ROOT",
        description: "Root directory for CLI plugins and extensions",
        example: "/Users/dev/.claude/plugins",
        category: .claude
    )

    /// Path to the environment variables file.
    public static let claudeEnvFile = HookEnvironmentVariable(
        name: "CLAUDE_ENV_FILE",
        description: "Path to the .env file for environment variable overrides",
        example: "/Users/dev/.claude/.env",
        category: .claude
    )

    /// Remote session indicator.
    public static let claudeCodeRemote = HookEnvironmentVariable(
        name: "CLAUDE_CODE_REMOTE",
        description: "Remote server address if running in remote/SSH mode (empty for local)",
        example: "ssh://user@server:22",
        category: .claude
    )

    /// Current session identifier.
    public static let claudeSessionId = HookEnvironmentVariable(
        name: "CLAUDE_SESSION_ID",
        description: "Unique identifier for the current Claude Code session",
        example: "abc123-def456-ghi789",
        category: .claude,
        isRequired: true
    )

    /// Working directory for the current session.
    public static let claudeCwd = HookEnvironmentVariable(
        name: "CLAUDE_CWD",
        description: "Current working directory for the session",
        example: "/Users/dev/my-project/src",
        category: .claude
    )

    /// Model being used in the current session.
    public static let claudeModel = HookEnvironmentVariable(
        name: "CLAUDE_MODEL",
        description: "The AI model identifier being used (e.g., claude-sonnet-4-20250514)",
        example: "claude-sonnet-4-20250514",
        category: .claude
    )

    // MARK: - System Variables

    /// User's home directory.
    public static let home = HookEnvironmentVariable(
        name: "HOME",
        description: "User's home directory path",
        example: "/Users/dev",
        category: .system,
        isRequired: true
    )

    /// System PATH for executable lookup.
    public static let path = HookEnvironmentVariable(
        name: "PATH",
        description: "Colon-separated list of directories to search for executables",
        example: "/usr/local/bin:/usr/bin:/bin",
        category: .system,
        isRequired: true
    )

    /// Current username.
    public static let user = HookEnvironmentVariable(
        name: "USER",
        description: "Current user's login name",
        example: "dev",
        category: .system,
        isRequired: true
    )

    /// Default shell.
    public static let shell = HookEnvironmentVariable(
        name: "SHELL",
        description: "Path to the user's default shell",
        example: "/bin/zsh",
        category: .system,
        defaultValue: "/bin/sh"
    )

    /// Temporary directory.
    public static let tmpdir = HookEnvironmentVariable(
        name: "TMPDIR",
        description: "Directory for temporary files",
        example: "/var/folders/abc/T/",
        category: .system,
        defaultValue: "/tmp"
    )

    /// Language/locale setting.
    public static let lang = HookEnvironmentVariable(
        name: "LANG",
        description: "System locale and language setting",
        example: "en_US.UTF-8",
        category: .system,
        defaultValue: "en_US.UTF-8"
    )

    /// Terminal type.
    public static let term = HookEnvironmentVariable(
        name: "TERM",
        description: "Terminal type for output formatting",
        example: "xterm-256color",
        category: .system
    )

    // MARK: - Blaze Variables

    /// Blaze application version.
    public static let blazeVersion = HookEnvironmentVariable(
        name: "BLAZE_VERSION",
        description: "Current Blaze application version",
        example: "1.0.0",
        category: .blaze
    )

    /// Blaze session identifier.
    public static let blazeSessionId = HookEnvironmentVariable(
        name: "BLAZE_SESSION_ID",
        description: "Unique identifier for the current Blaze session",
        example: "blaze-abc123",
        category: .blaze
    )

    /// Current provider being used.
    public static let blazeProvider = HookEnvironmentVariable(
        name: "BLAZE_PROVIDER",
        description: "The CLI provider currently in use (claude, gemini, codex)",
        example: "claude",
        category: .blaze
    )

    /// Security mode in effect.
    public static let blazeSecurityMode = HookEnvironmentVariable(
        name: "BLAZE_SECURITY_MODE",
        description: "Current security mode (review, trusted, sandbox)",
        example: "review",
        category: .blaze,
        defaultValue: "review"
    )

    /// Whether running in headless mode.
    public static let blazeHeadless = HookEnvironmentVariable(
        name: "BLAZE_HEADLESS",
        description: "Set to '1' if running without UI interaction",
        example: "1",
        category: .blaze,
        defaultValue: "0"
    )

    // MARK: - Variable Collections

    /// All Claude Code specific environment variables.
    public static let claudeVariables: [HookEnvironmentVariable] = [
        claudeProjectDir,
        claudePluginRoot,
        claudeEnvFile,
        claudeCodeRemote,
        claudeSessionId,
        claudeCwd,
        claudeModel
    ]

    /// All system environment variables commonly used by hooks.
    public static let systemVariables: [HookEnvironmentVariable] = [
        home,
        path,
        user,
        shell,
        tmpdir,
        lang,
        term
    ]

    /// All Blaze-specific environment variables.
    public static let blazeVariables: [HookEnvironmentVariable] = [
        blazeVersion,
        blazeSessionId,
        blazeProvider,
        blazeSecurityMode,
        blazeHeadless
    ]

    /// All known environment variables across all categories.
    public static let allVariables: [HookEnvironmentVariable] = {
        claudeVariables + systemVariables + blazeVariables
    }()

    /// Required environment variables that must be set for hooks to work.
    public static let requiredVariables: [HookEnvironmentVariable] = {
        allVariables.filter { $0.isRequired }
    }()

    /// Optional environment variables (have defaults or are not required).
    public static let optionalVariables: [HookEnvironmentVariable] = {
        allVariables.filter { !$0.isRequired }
    }()

    // MARK: - Lookup Methods

    /// Get environment variable by name.
    ///
    /// - Parameter name: Variable name (with or without $ prefix)
    /// - Returns: The variable definition if known, nil otherwise
    public static func variable(named name: String) -> HookEnvironmentVariable? {
        let cleanName = name.hasPrefix("$") ? String(name.dropFirst()) : name
        return allVariables.first { $0.name == cleanName }
    }

    /// Get all variables for a specific category.
    ///
    /// - Parameter category: The category to filter by
    /// - Returns: Array of variables in the specified category
    public static func variables(for category: HookEnvironmentCategory) -> [HookEnvironmentVariable] {
        switch category {
        case .claude: return claudeVariables
        case .system: return systemVariables
        case .blaze: return blazeVariables
        case .custom: return [] // Custom variables are user-defined
        }
    }

    /// Check if a variable name is known/documented.
    ///
    /// - Parameter name: Variable name (with or without $ prefix)
    /// - Returns: true if the variable is in our registry
    public static func isKnown(_ name: String) -> Bool {
        variable(named: name) != nil
    }

    // MARK: - Validation

    /// Validation result for environment variable checks.
    public struct ValidationResult: Sendable {
        /// Variables that are required but not set.
        public let missingRequired: [HookEnvironmentVariable]

        /// Variables that are set in the environment.
        public let present: [HookEnvironmentVariable]

        /// Whether all required variables are present.
        public var isValid: Bool { missingRequired.isEmpty }

        /// Human-readable summary of validation state.
        public var summary: String {
            if isValid {
                return "All required environment variables are set (\(present.count) total)"
            } else {
                let missing = missingRequired.map { $0.name }.joined(separator: ", ")
                return "Missing required variables: \(missing)"
            }
        }
    }

    /// Validates that all required environment variables are set.
    ///
    /// Checks the current process environment for all variables marked
    /// as required and reports which ones are missing.
    ///
    /// - Returns: Validation result with details about missing/present variables
    public static func validateEnvironment() -> ValidationResult {
        var missingRequired: [HookEnvironmentVariable] = []
        var present: [HookEnvironmentVariable] = []

        for variable in allVariables {
            if variable.getCurrentValue() != nil {
                present.append(variable)
            } else if variable.isRequired {
                missingRequired.append(variable)
            }
        }

        return ValidationResult(
            missingRequired: missingRequired,
            present: present
        )
    }

    /// Build an environment dictionary for hook execution.
    ///
    /// Creates a dictionary suitable for passing to `Process.environment`,
    /// populated with current values for all known variables plus any
    /// additional custom variables provided.
    ///
    /// - Parameter additionalVariables: Extra key-value pairs to include
    /// - Returns: Environment dictionary for subprocess execution
    public static func buildEnvironment(
        additionalVariables: [String: String] = [:]
    ) -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        // Ensure all variables with defaults have values
        for variable in allVariables {
            if env[variable.name] == nil, let defaultValue = variable.defaultValue {
                env[variable.name] = defaultValue
            }
        }

        // Merge additional variables (overwrite existing)
        for (key, value) in additionalVariables {
            env[key] = value
        }

        return env
    }

    // MARK: - Template Expansion

    /// Expands environment variable references in a template string.
    ///
    /// Supports both `$VAR` and `${VAR}` syntax. Unknown variables
    /// are left unexpanded.
    ///
    /// - Parameter template: String containing variable references
    /// - Returns: String with variables replaced by their values
    public static func expandTemplate(_ template: String) -> String {
        var result = template
        let env = ProcessInfo.processInfo.environment

        // First expand ${VAR} syntax
        let bracketPattern = #"\$\{([A-Z_][A-Z0-9_]*)\}"#
        if let regex = try? NSRegularExpression(pattern: bracketPattern, options: []) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange)

            // Process in reverse order to preserve indices
            for match in matches.reversed() {
                if let varRange = Range(match.range(at: 1), in: result) {
                    let varName = String(result[varRange])
                    if let value = env[varName] {
                        let fullRange = Range(match.range, in: result)!
                        result.replaceSubrange(fullRange, with: value)
                    }
                }
            }
        }

        // Then expand $VAR syntax (but not inside ${})
        let simplePattern = #"\$([A-Z_][A-Z0-9_]*)\b"#
        if let regex = try? NSRegularExpression(pattern: simplePattern, options: []) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange)

            for match in matches.reversed() {
                if let varRange = Range(match.range(at: 1), in: result) {
                    let varName = String(result[varRange])
                    if let value = env[varName] {
                        let fullRange = Range(match.range, in: result)!
                        result.replaceSubrange(fullRange, with: value)
                    }
                }
            }
        }

        return result
    }
}
