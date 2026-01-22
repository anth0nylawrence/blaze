import SwiftUI

// MARK: - Spacing Tokens

/// Consistent spacing scale for the Blaze Design System.
/// Based on a 4pt grid system.
public enum DSSpacing {
    /// 4pt - Extra extra small (hairline gaps)
    public static let xxs: CGFloat = 4

    /// 8pt - Extra small (tight spacing)
    public static let xs: CGFloat = 8

    /// 12pt - Small (compact layouts)
    public static let sm: CGFloat = 12

    /// 16pt - Medium (standard spacing)
    public static let md: CGFloat = 16

    /// 24pt - Large (comfortable spacing)
    public static let lg: CGFloat = 24

    /// 32pt - Extra large (section gaps)
    public static let xl: CGFloat = 32

    /// 48pt - Extra extra large (major sections)
    public static let xxl: CGFloat = 48

    /// 64pt - Huge (page-level spacing)
    public static let huge: CGFloat = 64
}

// MARK: - Corner Radius Tokens

/// Consistent corner radius scale for the Blaze Design System.
public enum DSRadius {
    /// 4pt - Small radius (buttons, badges)
    public static let sm: CGFloat = 4

    /// 8pt - Medium radius (cards, panels)
    public static let md: CGFloat = 8

    /// 12pt - Large radius (prominent elements)
    public static let lg: CGFloat = 12

    /// 16pt - Extra large radius (modals, sheets)
    public static let xl: CGFloat = 16

    /// 20pt - Extra extra large radius
    public static let xxl: CGFloat = 20

    /// 9999pt - Full/pill shape
    public static let full: CGFloat = 9999
}

// MARK: - Size Tokens

/// Common size tokens for icons, avatars, and other fixed-size elements.
public enum DSSize {
    /// 16pt - Extra small (inline icons)
    public static let xs: CGFloat = 16

    /// 20pt - Small (compact icons)
    public static let sm: CGFloat = 20

    /// 24pt - Medium (standard icons)
    public static let md: CGFloat = 24

    /// 32pt - Large (prominent icons)
    public static let lg: CGFloat = 32

    /// 40pt - Extra large (avatars)
    public static let xl: CGFloat = 40

    /// 48pt - Extra extra large (feature icons)
    public static let xxl: CGFloat = 48

    /// 64pt - Huge (hero elements)
    public static let huge: CGFloat = 64
}

// MARK: - Convenience Extensions

public extension EdgeInsets {
    /// Uniform padding using DS spacing
    static func ds(_ spacing: CGFloat) -> EdgeInsets {
        EdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
    }

    /// Horizontal/vertical padding using DS spacing
    static func ds(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
