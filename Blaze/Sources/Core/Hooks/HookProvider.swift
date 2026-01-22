import Foundation

// MARK: - HookProvider

/// Represents a CLI tool provider for hook configuration purposes.
///
/// Each provider has a specific config directory structure where hooks
/// and settings are stored. This enum abstracts the provider-specific
/// paths and capabilities.
///
/// **E005-F004-S001-T001-A001**
public enum HookProvider: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case claude
    case gemini
    case codex

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable provider name for UI.
    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .gemini: return "Gemini CLI"
        case .codex: return "Codex CLI"
        }
    }

    // MARK: - Hook Support

    /// Whether this provider supports hooks (PreToolUse, PostToolUse, etc.).
    ///
    /// Currently only Claude Code has full hook support.
    /// Gemini and Codex support may be added in future versions.
    public var supportsHooks: Bool {
        switch self {
        case .claude: return true
        case .gemini: return false  // Not yet supported
        case .codex: return false   // Not yet supported
        }
    }

    // MARK: - Configuration Paths

    /// The config directory name for this provider (e.g., ".claude").
    ///
    /// This is the hidden directory where provider-specific settings are stored,
    /// typically in the user's home directory or project root.
    public var configDirectoryName: String {
        switch self {
        case .claude: return ".claude"
        case .gemini: return ".gemini"
        case .codex: return ".codex"
        }
    }

    /// The settings filename within the config directory.
    ///
    /// Claude and Gemini use "settings.json", Codex uses "config.json".
    public var settingsFilename: String {
        switch self {
        case .claude, .gemini:
            return "settings.json"
        case .codex:
            return "config.json"
        }
    }
}
