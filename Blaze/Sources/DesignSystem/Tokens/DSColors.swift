import SwiftUI

// MARK: - Color Tokens

/// Semantic color tokens for the Blaze Design System.
/// When a ThemeManager is configured, colors come from the active theme.
/// Otherwise, falls back to system colors for light/dark mode adaptation.
public enum DSColors {
    // MARK: - Theme Manager Integration

    /// The shared theme manager. Set this at app startup to enable theme-aware colors.
    public static weak var themeManager: ThemeManager?

    /// Returns the resolved theme colors if a manager is set, nil otherwise.
    private static var themeColors: ResolvedThemeColors? {
        themeManager?.resolvedColors
    }

    // MARK: - Backgrounds (Layered)

    /// Deepest background layer (window background)
    public static var bg0: Color {
        themeColors?.background ?? Color(nsColor: .windowBackgroundColor)
    }

    /// Primary background layer
    public static var bg1: Color {
        themeColors?.surface ?? Color(nsColor: .controlBackgroundColor)
    }

    /// Panel/card background with slight elevation
    public static var panel: Color {
        themeColors?.surfaceHover ?? Color(nsColor: .underPageBackgroundColor)
    }

    /// Interactive surface background
    public static var surface: Color {
        themeColors?.surface ?? Color(nsColor: .textBackgroundColor)
    }

    // MARK: - Content

    /// Primary text color
    public static var foreground: Color {
        themeColors?.textPrimary ?? Color(nsColor: .labelColor)
    }

    /// Secondary/subdued text
    public static var secondary: Color {
        themeColors?.textSecondary ?? Color(nsColor: .secondaryLabelColor)
    }

    /// Tertiary/disabled text
    public static var tertiary: Color {
        themeColors?.textMuted ?? Color(nsColor: .tertiaryLabelColor)
    }

    /// Placeholder text
    public static var placeholder: Color {
        themeColors?.textMuted ?? Color(nsColor: .placeholderTextColor)
    }

    // MARK: - Borders & Dividers

    /// Standard border color
    public static var border: Color {
        themeColors?.border ?? Color(nsColor: .separatorColor)
    }

    /// Subtle/faint border
    public static var borderSubtle: Color {
        (themeColors?.border ?? Color(nsColor: .separatorColor)).opacity(0.5)
    }

    /// Grid/table lines
    public static var gridLine: Color {
        themeColors?.border ?? Color(nsColor: .gridColor)
    }

    // MARK: - Semantic States

    /// Success/positive state
    public static var positive: Color {
        themeColors?.success ?? Color.green
    }

    /// Warning state
    public static var warning: Color {
        themeColors?.warning ?? Color.orange
    }

    /// Error/negative state
    public static var negative: Color {
        themeColors?.error ?? Color.red
    }

    /// Informational state
    public static var info: Color {
        Color.blue
    }

    /// Accent color (from theme or system)
    public static var accent: Color {
        themeColors?.accent ?? Color.accentColor
    }

    // MARK: - Glass Effect Colors

    /// Glass panel tint (subtle white for light, subtle black for dark)
    public static var glassTint: Color {
        Color.primary.opacity(0.03)
    }

    /// Glass border highlight (top/left edges)
    public static var glassHighlight: Color {
        Color.white.opacity(0.15)
    }

    /// Glass border shadow (bottom/right edges)
    public static var glassShadow: Color {
        Color.black.opacity(0.1)
    }

    // MARK: - Diff Colors

    /// Addition/inserted line background
    public static var diffAdd: Color {
        Color.green.opacity(0.15)
    }

    /// Deletion/removed line background
    public static var diffRemove: Color {
        Color.red.opacity(0.15)
    }

    /// Modified/changed indicator
    public static var diffModify: Color {
        Color.orange.opacity(0.15)
    }
}

// MARK: - Convenience Extension

public extension Color {
    /// Access to Design System colors via `Color.ds.foreground`, etc.
    static let ds = DSColors.self
}

// MARK: - Theme-Aware View Modifier

/// A view modifier that observes theme changes and forces re-rendering.
/// Apply this to root views that need to respond to theme changes.
public struct ThemeAwareModifier: ViewModifier {
    @Environment(\.themeManager) private var themeManager

    public func body(content: Content) -> some View {
        // By accessing themeManager?.activeTheme here, we create an observation
        // that will trigger view updates when the theme changes
        let _ = themeManager?.activeTheme.id
        content
    }
}

public extension View {
    /// Makes this view respond to theme changes by triggering re-renders.
    /// Apply to root views that use Color.ds.* tokens.
    func themeAware() -> some View {
        modifier(ThemeAwareModifier())
    }
}
