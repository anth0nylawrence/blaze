import SwiftUI

// MARK: - Glass Level Tokens

/// Glass material intensity levels for the premium glass aesthetic.
/// Each level defines blur, opacity, and border characteristics.
public enum DSGlassLevel: String, CaseIterable, Codable {
    /// Ultra-subtle frosted effect (barely visible)
    case subtle

    /// Light frosted glass
    case light

    /// Standard glass panel (default)
    case regular

    /// Prominent glass effect
    case prominent

    /// Nearly opaque glass
    case solid

    // MARK: - Material Properties

    /// SwiftUI Material for background
    public var material: Material {
        switch self {
        case .subtle:
            return .ultraThinMaterial
        case .light:
            return .thinMaterial
        case .regular:
            return .regularMaterial
        case .prominent:
            return .thickMaterial
        case .solid:
            return .ultraThickMaterial
        }
    }

    /// Blur radius for custom blur implementations
    public var blurRadius: CGFloat {
        switch self {
        case .subtle:
            return 8
        case .light:
            return 12
        case .regular:
            return 20
        case .prominent:
            return 30
        case .solid:
            return 40
        }
    }

    /// Background opacity (for tinted glass)
    public var backgroundOpacity: Double {
        switch self {
        case .subtle:
            return 0.3
        case .light:
            return 0.5
        case .regular:
            return 0.7
        case .prominent:
            return 0.85
        case .solid:
            return 0.95
        }
    }

    /// Border opacity for glass edge
    public var borderOpacity: Double {
        switch self {
        case .subtle:
            return 0.08
        case .light:
            return 0.12
        case .regular:
            return 0.15
        case .prominent:
            return 0.2
        case .solid:
            return 0.25
        }
    }

    /// Highlight opacity for top/left edge shimmer
    public var highlightOpacity: Double {
        switch self {
        case .subtle:
            return 0.05
        case .light:
            return 0.08
        case .regular:
            return 0.12
        case .prominent:
            return 0.15
        case .solid:
            return 0.18
        }
    }

    /// Inner shadow opacity for depth
    public var innerShadowOpacity: Double {
        switch self {
        case .subtle:
            return 0.02
        case .light:
            return 0.04
        case .regular:
            return 0.06
        case .prominent:
            return 0.08
        case .solid:
            return 0.1
        }
    }
}

// MARK: - Glass Border Style

/// Border styling options for glass panels
public enum DSGlassBorder {
    /// No border
    case none

    /// Single subtle border
    case subtle

    /// Standard border with highlight
    case standard

    /// Prominent layered border (outer + inner + gradient)
    case layered

    /// Gradient stroke border
    case gradient

    /// Border line width
    public var lineWidth: CGFloat {
        switch self {
        case .none:
            return 0
        case .subtle:
            return 0.5
        case .standard, .layered, .gradient:
            return 1
        }
    }
}

// MARK: - Glass Animation Tokens

/// Animation parameters for glass interactions
public enum DSGlassAnimation {
    /// Hover state animation duration
    public static let hoverDuration: Double = 0.2

    /// Press state animation duration
    public static let pressDuration: Double = 0.1

    /// Focus state animation duration
    public static let focusDuration: Double = 0.25

    /// Hover scale factor (1.0 = no scale)
    public static let hoverScale: CGFloat = 1.015

    /// Press scale factor
    public static let pressScale: CGFloat = 0.98

    /// Hover brightness increase
    public static let hoverBrightness: Double = 0.03

    /// Press brightness decrease
    public static let pressBrightness: Double = -0.02

    /// Standard spring response
    public static let springResponse: Double = 0.35

    /// Standard spring damping
    public static let springDamping: Double = 0.7
}

// MARK: - Glass Gradient Presets

/// Pre-defined gradients for glass effects
public enum DSGlassGradient {
    /// Highlight gradient (top-left to bottom-right)
    public static var highlight: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.15),
                .white.opacity(0.05),
                .clear,
                .black.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Subtle shine gradient
    public static var shine: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.1),
                .clear,
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Border gradient for layered effect
    public static var border: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.2),
                .white.opacity(0.1),
                .clear,
                .black.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Glow gradient for focused elements
    public static func glow(color: Color = .accentColor) -> RadialGradient {
        RadialGradient(
            colors: [
                color.opacity(0.3),
                color.opacity(0.1),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
}

// MARK: - Noise Overlay

/// Noise/grain overlay for tactile glass feel
public struct DSGlassNoise {
    /// Whether noise overlay is enabled
    public static var isEnabled: Bool = false

    /// Noise opacity (very subtle)
    public static let opacity: Double = 0.02

    /// Noise blend mode
    public static let blendMode: BlendMode = .overlay
}
