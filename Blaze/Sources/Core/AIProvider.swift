import Foundation
import SwiftUI

// MARK: - AIProvider

/// Represents an AI provider (vendor) that the harness can connect to.
///
/// Each provider has:
/// - A CLI binary for headless operation
/// - An engine type for adapter routing
/// - Provider-specific metadata (branding, capabilities)
///
/// **E005-F001-S001-T001-A001**
public enum AIProvider: String, Codable, CaseIterable, Sendable, Hashable {
    case anthropic
    case openai
    case google
    case community

    // MARK: - Display Properties

    /// Human-readable provider name for UI.
    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .google: return "Google"
        case .community: return "Community"
        }
    }

    /// Brand color for provider-specific UI elements.
    public var brandColor: Color {
        switch self {
        case .anthropic: return Color(red: 0.85, green: 0.45, blue: 0.35) // Coral/terracotta
        case .openai: return Color(red: 0.0, green: 0.65, blue: 0.52)     // Teal
        case .google: return Color(red: 0.26, green: 0.52, blue: 0.96)    // Blue
        case .community: return Color(red: 0.55, green: 0.35, blue: 0.85) // Purple
        }
    }

    /// Asset catalog name for provider logo.
    public var logoAssetName: String {
        switch self {
        case .anthropic: return "logo-anthropic"
        case .openai: return "logo-openai"
        case .google: return "logo-google"
        case .community: return "logo-community"
        }
    }

    /// SF Symbol fallback when logo asset is unavailable.
    public var fallbackSymbol: String {
        switch self {
        case .anthropic: return "brain"
        case .openai: return "chevron.left.forwardslash.chevron.right"
        case .google: return "sparkles"
        case .community: return "person.3.fill"
        }
    }

    // MARK: - Engine Properties

    /// The engine type used for adapter routing.
    public var engineType: EngineType {
        switch self {
        case .anthropic: return .claude
        case .openai: return .codex
        case .google: return .gemini
        case .community: return .claude // Community tools often use Claude protocol
        }
    }

    /// CLI binary name for spawning processes.
    public var cliBinary: String {
        switch self {
        case .anthropic: return "claude"
        case .openai: return "codex"
        case .google: return "gemini"
        case .community: return "aider"
        }
    }

    /// Whether this provider supports hooks (PreToolUse, PostToolUse, etc.).
    public var supportsHooks: Bool {
        switch self {
        case .anthropic: return true
        case .openai: return false   // Codex CLI doesn't support hooks yet
        case .google: return true
        case .community: return false
        }
    }

    /// Number of hook event types supported.
    public var hookEventCount: Int {
        switch self {
        case .anthropic: return 6  // PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, PreCompact, Stop
        case .openai: return 0
        case .google: return 4     // PreToolUse, PostToolUse, SessionStart, Stop
        case .community: return 0
        }
    }

    // MARK: - Hook Provider Mapping

    /// Maps to HookProvider for hook execution context.
    /// Used by HookRunner to filter hooks by CLI engine.
    public var hookProvider: HookProvider {
        switch self {
        case .anthropic: return .claude
        case .openai: return .codex
        case .google: return .gemini
        case .community: return .claude  // Community tools use Claude protocol
        }
    }
}
