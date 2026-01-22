import Foundation
import SwiftUI

// MARK: - ModelTier

/// Represents the capability tier of an AI model.
///
/// Tiers help users choose between:
/// - **Flagship**: Maximum capability, highest cost
/// - **Balanced**: Good performance/cost ratio (default)
/// - **Fast**: Quick responses, lower cost
///
/// **E005-F001-S001-T001-A001**
public enum ModelTier: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    public var id: String { rawValue }
    case flagship
    case balanced
    case fast

    // MARK: - Display Properties

    /// Human-readable tier name.
    public var displayName: String {
        switch self {
        case .flagship: return "Flagship"
        case .balanced: return "Balanced"
        case .fast: return "Fast"
        }
    }

    /// SF Symbol for tier badge.
    public var icon: String {
        switch self {
        case .flagship: return "star.fill"
        case .balanced: return "scale.3d"
        case .fast: return "hare.fill"
        }
    }

    /// Color for tier badge in UI.
    public var badgeColor: Color {
        switch self {
        case .flagship: return Color(red: 1.0, green: 0.84, blue: 0.0)    // Gold #FFD700
        case .balanced: return Color(red: 0.75, green: 0.75, blue: 0.75)  // Silver #C0C0C0
        case .fast: return Color(red: 0.80, green: 0.50, blue: 0.20)      // Bronze #CD7F32
        }
    }

    /// Alias for badgeColor (backward compatibility with UI code).
    public var color: Color { badgeColor }

    // MARK: - Cost Properties

    /// Cost multiplier relative to balanced tier.
    /// Used for cost estimation in the UI.
    public var costMultiplier: Double {
        switch self {
        case .flagship: return 3.0
        case .balanced: return 1.0
        case .fast: return 0.5
        }
    }
}
