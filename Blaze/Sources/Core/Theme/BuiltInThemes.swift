import SwiftUI

// MARK: - Built-In Themes

/// Provides 5 pre-defined themes with stable UUIDs.
/// These themes cannot be deleted or have their IDs changed.
public enum BuiltInThemes {

    // MARK: - Stable UUIDs

    private static let nebulaID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let obsidianID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let auroraID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let sunriseID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    private static let monochromeID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    private static let hyperionID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!

    // MARK: - Theme Definitions

    /// Deep blue dark aesthetic (default theme)
    public static let nebula = ThemeProfile(
        id: nebulaID,
        name: "Nebula",
        isBuiltIn: true,
        colors: .nebula,
        glassLevel: .regular,
        accentOption: .purple
    )

    /// Pure dark with minimal contrast, blue accent
    public static let obsidian = ThemeProfile(
        id: obsidianID,
        name: "Obsidian",
        isBuiltIn: true,
        colors: ThemeColors(
            background: Color(hex: "#0D0D0F"),
            surface: Color(hex: "#151517"),
            surfaceHover: Color(hex: "#1C1C1F"),
            accent: Color(hex: "#3B82F6"),
            accentHover: Color(hex: "#60A5FA"),
            textPrimary: Color(hex: "#E4E4E7"),
            textSecondary: Color(hex: "#A1A1AA"),
            textMuted: Color(hex: "#71717A"),
            border: Color(hex: "#27272A"),
            success: Color(hex: "#4ADE80"),
            warning: Color(hex: "#FBBF24"),
            error: Color(hex: "#F87171")
        ),
        glassLevel: .prominent,
        accentOption: .blue
    )

    /// Dark with cyan/teal accents, nature-inspired
    public static let aurora = ThemeProfile(
        id: auroraID,
        name: "Aurora",
        isBuiltIn: true,
        colors: ThemeColors(
            background: Color(hex: "#0A1A1A"),
            surface: Color(hex: "#0F2424"),
            surfaceHover: Color(hex: "#153030"),
            accent: Color(hex: "#00D4AA"),
            accentHover: Color(hex: "#33E0BB"),
            textPrimary: Color(hex: "#E0F2F1"),
            textSecondary: Color(hex: "#80CBC4"),
            textMuted: Color(hex: "#4DB6AC"),
            border: Color(hex: "#1A3333"),
            success: Color(hex: "#4ADE80"),
            warning: Color(hex: "#FBBF24"),
            error: Color(hex: "#F87171")
        ),
        glassLevel: .regular,
        accentOption: .green
    )

    /// Warm dark theme with orange accents
    public static let sunrise = ThemeProfile(
        id: sunriseID,
        name: "Sunrise",
        isBuiltIn: true,
        colors: ThemeColors(
            background: Color(hex: "#1A1410"),
            surface: Color(hex: "#241C16"),
            surfaceHover: Color(hex: "#2E241C"),
            accent: Color(hex: "#FF8C42"),
            accentHover: Color(hex: "#FFA366"),
            textPrimary: Color(hex: "#F5EDE6"),
            textSecondary: Color(hex: "#C4B5A8"),
            textMuted: Color(hex: "#8A7B6E"),
            border: Color(hex: "#3D3328"),
            success: Color(hex: "#4ADE80"),
            warning: Color(hex: "#FBBF24"),
            error: Color(hex: "#F87171")
        ),
        glassLevel: .light,
        accentOption: .orange
    )

    /// Grayscale only, no color accents
    public static let monochrome = ThemeProfile(
        id: monochromeID,
        name: "Monochrome",
        isBuiltIn: true,
        colors: ThemeColors(
            background: Color(hex: "#121212"),
            surface: Color(hex: "#1A1A1A"),
            surfaceHover: Color(hex: "#222222"),
            accent: Color(hex: "#888888"),
            accentHover: Color(hex: "#999999"),
            textPrimary: Color(hex: "#E8E8E8"),
            textSecondary: Color(hex: "#A0A0A0"),
            textMuted: Color(hex: "#666666"),
            border: Color(hex: "#333333"),
            success: Color(hex: "#A0A0A0"),
            warning: Color(hex: "#888888"),
            error: Color(hex: "#B0B0B0")
        ),
        glassLevel: .regular,
        accentOption: .blue  // Accent option irrelevant since accent color is gray
    )

    /// Deep purple dark aesthetic (original Nebula colors)
    public static let hyperion = ThemeProfile(
        id: hyperionID,
        name: "Hyperion",
        isBuiltIn: true,
        colors: .hyperion,
        glassLevel: .regular,
        accentOption: .purple
    )

    // MARK: - Collection Access

    /// All built-in themes, with Nebula first (default)
    public static var all: [ThemeProfile] {
        [nebula, obsidian, aurora, sunrise, monochrome, hyperion]
    }

    /// Returns built-in theme for given ID, or nil if not a built-in ID
    public static func theme(forId id: UUID) -> ThemeProfile? {
        all.first { $0.id == id }
    }

    /// Set of all built-in theme IDs for quick membership checks
    public static var builtInIDs: Set<UUID> {
        Set(all.map(\.id))
    }
}
