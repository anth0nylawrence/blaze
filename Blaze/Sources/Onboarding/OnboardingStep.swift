import Foundation

// MARK: - OnboardingStep

/// Represents each step in the onboarding flow.
///
/// The onboarding guides users through:
/// 1. Welcome - Introduction and skip option
/// 2. User Profile - Name, preferences setup
/// 3. CLI Detection - Scan for installed CLIs (Claude, Gemini, Codex)
/// 4. Skills Recommendations - Suggest relevant skills based on detected CLIs
/// 5. Plugins Recommendations - Suggest MCP plugins
/// 6. Agents Recommendations - Suggest agent configurations
/// 7. Completion - Summary and finish
public enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome = 0
    case userProfile = 1
    case cliDetection = 2
    case skillsRecommendations = 3
    case pluginsRecommendations = 4
    case agentsRecommendations = 5
    case completion = 6

    public var id: Int { rawValue }

    // MARK: - Display Properties

    /// Human-readable title for the step
    public var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .userProfile:
            return "Your Profile"
        case .cliDetection:
            return "CLI Detection"
        case .skillsRecommendations:
            return "Skills"
        case .pluginsRecommendations:
            return "Plugins"
        case .agentsRecommendations:
            return "Agents"
        case .completion:
            return "Ready"
        }
    }

    /// Short description for progress indicator
    public var shortDescription: String {
        switch self {
        case .welcome:
            return "Get started"
        case .userProfile:
            return "Set up your profile"
        case .cliDetection:
            return "Detect installed CLIs"
        case .skillsRecommendations:
            return "Choose your skills"
        case .pluginsRecommendations:
            return "Enable plugins"
        case .agentsRecommendations:
            return "Configure agents"
        case .completion:
            return "You're all set"
        }
    }

    // MARK: - Navigation

    /// The next step in the sequence, or nil if this is the last step
    public var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// The previous step in the sequence, or nil if this is the first step
    public var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    /// Whether this is the first step (no back button needed)
    public var isFirst: Bool {
        self == .welcome
    }

    /// Whether this is the last step (show complete instead of next)
    public var isLast: Bool {
        self == .completion
    }

    /// Progress percentage (0.0 to 1.0) through the onboarding
    public var progressFraction: Double {
        let total = Double(Self.allCases.count - 1)
        return total > 0 ? Double(rawValue) / total : 0
    }

    /// Step number for display (1-indexed)
    public var stepNumber: Int {
        rawValue + 1
    }

    /// Total number of steps
    public static var totalSteps: Int {
        allCases.count
    }
}
