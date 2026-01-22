import Foundation

// MARK: - InstallMethod

/// Method for installing a CLI tool.
///
/// **E005-F005-S001-T001-A001**
public enum InstallMethod: String, Codable, Sendable, CaseIterable {
    case homebrew
    case npm
    case pip
    case manual

    /// Human-readable description of the install method.
    public var displayName: String {
        switch self {
        case .homebrew: return "Homebrew"
        case .npm: return "npm"
        case .pip: return "pip"
        case .manual: return "Manual"
        }
    }
}

// MARK: - InstallCommand

/// Installation command for a CLI tool.
///
/// **E005-F005-S001-T001-A001**
public struct InstallCommand: Codable, Sendable, Hashable {
    /// The installation method (package manager or manual).
    public let method: InstallMethod

    /// The actual shell command to run.
    public let command: String

    /// Whether the command requires sudo/admin privileges.
    public let requiresSudo: Bool

    public init(method: InstallMethod, command: String, requiresSudo: Bool = false) {
        self.method = method
        self.command = command
        self.requiresSudo = requiresSudo
    }
}

// MARK: - DependencyType

/// External dependencies required by CLI tools.
///
/// **E005-F005-S001-T001-A001**
public enum DependencyType: String, Codable, Sendable, CaseIterable, Hashable {
    case nodejs
    case python
    case homebrew
    case npm

    /// Human-readable dependency name for UI.
    public var displayName: String {
        switch self {
        case .nodejs: return "Node.js"
        case .python: return "Python"
        case .homebrew: return "Homebrew"
        case .npm: return "npm"
        }
    }

    /// Shell command to verify the dependency is installed.
    public var checkCommand: String {
        switch self {
        case .nodejs: return "node --version"
        case .python: return "python3 --version"
        case .homebrew: return "brew --version"
        case .npm: return "npm --version"
        }
    }

    /// Minimum recommended version (informational).
    public var minimumVersion: String? {
        switch self {
        case .nodejs: return "18.0.0"
        case .python: return "3.9"
        case .homebrew: return nil
        case .npm: return "9.0.0"
        }
    }
}

// MARK: - CLIType

/// Supported CLI tools that Blaze can orchestrate.
///
/// Each CLI type represents an agentic coding tool that:
/// - Outputs structured JSON (NDJSON/stream-json)
/// - Supports headless operation
/// - Can be spawned as a child process
///
/// **E005-F005-S001-T001-A001**
public enum CLIType: String, Codable, Sendable, CaseIterable, Hashable {
    case claudeCode
    case geminiCLI
    case codexCLI

    // MARK: - Display Properties

    /// Human-readable name for UI.
    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .geminiCLI: return "Gemini CLI"
        case .codexCLI: return "Codex CLI"
        }
    }

    /// Brief description of the CLI tool.
    public var description: String {
        switch self {
        case .claudeCode:
            return "Anthropic's agentic coding assistant with comprehensive tool use and hooks support"
        case .geminiCLI:
            return "Google's Gemini-powered CLI for code generation and analysis"
        case .codexCLI:
            return "OpenAI's Codex CLI with sandbox policies and approval workflows"
        }
    }

    /// Whether this CLI is recommended as the primary choice.
    public var isRecommended: Bool {
        switch self {
        case .claudeCode: return true
        case .geminiCLI: return false
        case .codexCLI: return false
        }
    }

    // MARK: - Executable Properties

    /// The binary name to invoke.
    public var executable: String {
        switch self {
        case .claudeCode: return "claude"
        case .geminiCLI: return "gemini"
        case .codexCLI: return "codex"
        }
    }

    /// Flag to check CLI version.
    public var versionFlag: String {
        return "--version"
    }

    // MARK: - Dependencies

    /// External dependencies required by this CLI.
    public var dependencies: [DependencyType] {
        switch self {
        case .claudeCode: return [.nodejs, .npm]
        case .geminiCLI: return [.nodejs, .npm]
        case .codexCLI: return [.nodejs, .npm]
        }
    }

    /// Installation command for this CLI tool.
    public var installCommand: InstallCommand? {
        switch self {
        case .claudeCode:
            return InstallCommand(
                method: .npm,
                command: "npm install -g @anthropic-ai/claude-code",
                requiresSudo: false
            )
        case .geminiCLI:
            return InstallCommand(
                method: .npm,
                command: "npm install -g @anthropic-ai/gemini-cli",
                requiresSudo: false
            )
        case .codexCLI:
            return InstallCommand(
                method: .npm,
                command: "npm install -g @openai/codex",
                requiresSudo: false
            )
        }
    }

    // MARK: - Provider Mapping

    /// Maps to the corresponding AIProvider.
    public var provider: AIProvider {
        switch self {
        case .claudeCode: return .anthropic
        case .geminiCLI: return .google
        case .codexCLI: return .openai
        }
    }
}
