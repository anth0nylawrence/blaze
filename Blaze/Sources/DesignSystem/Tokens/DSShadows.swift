import SwiftUI

// MARK: - Elevation Tokens

/// Elevation levels for shadow depth in the Blaze Design System.
/// Higher elevation = more prominent shadow.
public enum DSElevation: Int, CaseIterable {
    /// No shadow (flat on surface)
    case none = 0

    /// Subtle shadow (slightly raised)
    case low = 1

    /// Standard shadow (clearly raised)
    case medium = 2

    /// Prominent shadow (floating)
    case high = 3

    /// Maximum shadow (overlay/modal)
    case overlay = 4

    // MARK: - Shadow Properties

    /// Shadow color with opacity based on elevation
    public var shadowColor: Color {
        switch self {
        case .none:
            return .clear
        case .low:
            return .black.opacity(0.06)
        case .medium:
            return .black.opacity(0.1)
        case .high:
            return .black.opacity(0.15)
        case .overlay:
            return .black.opacity(0.25)
        }
    }

    /// Shadow blur radius
    public var shadowRadius: CGFloat {
        switch self {
        case .none:
            return 0
        case .low:
            return 2
        case .medium:
            return 6
        case .high:
            return 12
        case .overlay:
            return 24
        }
    }

    /// Shadow Y offset (shadows fall downward)
    public var shadowY: CGFloat {
        switch self {
        case .none:
            return 0
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 4
        case .overlay:
            return 8
        }
    }

    /// Shadow X offset (typically 0 for centered light source)
    public var shadowX: CGFloat {
        0
    }
}

// MARK: - Shadow Modifier

public extension View {
    /// Apply elevation-based shadow to a view
    func dsElevation(_ level: DSElevation) -> some View {
        self.shadow(
            color: level.shadowColor,
            radius: level.shadowRadius,
            x: level.shadowX,
            y: level.shadowY
        )
    }
}

// MARK: - NSShadow Helper (for AppKit integration)

#if canImport(AppKit)
import AppKit

public extension DSElevation {
    /// Shadow alpha component for AppKit
    private var shadowAlpha: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 0.06
        case .medium: return 0.1
        case .high: return 0.15
        case .overlay: return 0.25
        }
    }

    /// Create NSShadow for AppKit compatibility
    var nsShadow: NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(shadowAlpha)
        shadow.shadowBlurRadius = shadowRadius
        shadow.shadowOffset = NSSize(width: shadowX, height: -shadowY)
        return shadow
    }
}
#endif
