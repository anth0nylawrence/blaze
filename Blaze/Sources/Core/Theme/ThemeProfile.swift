import SwiftUI

// MARK: - Theme Profile

/// Core data model for user-customizable themes.
/// Combines colors, glass effects, accent options, and optional font overrides.
public struct ThemeProfile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var isBuiltIn: Bool
    public var colors: ThemeColors
    public var glassLevel: DSGlassLevel
    public var accentOption: AccentColorOption
    public var fontOverrides: FontOverrides?

    public init(
        id: UUID = UUID(),
        name: String,
        isBuiltIn: Bool = false,
        colors: ThemeColors,
        glassLevel: DSGlassLevel = .regular,
        accentOption: AccentColorOption = .purple,
        fontOverrides: FontOverrides? = nil
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.colors = colors
        self.glassLevel = glassLevel
        self.accentOption = accentOption
        self.fontOverrides = fontOverrides
    }

    /// Default theme with Nebula-inspired dark purple aesthetic
    public static var `default`: ThemeProfile {
        ThemeProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Nebula",
            isBuiltIn: true,
            colors: .nebula,
            glassLevel: .regular,
            accentOption: .purple,
            fontOverrides: nil
        )
    }
}

// MARK: - Accent Color Option

/// Predefined accent color choices plus custom option
public enum AccentColorOption: String, Codable, CaseIterable, Equatable {
    case purple
    case blue
    case pink
    case orange
    case green
    case red
    case custom

    /// SwiftUI Color for the accent (custom returns nil - use stored value)
    public var color: Color? {
        switch self {
        case .purple: return Color(red: 0.6, green: 0.4, blue: 1.0)
        case .blue: return .blue
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        case .custom: return nil
        }
    }
}

// MARK: - Font Overrides

/// Optional font customization for UI and monospace text
public struct FontOverrides: Codable, Equatable {
    /// Custom UI font family name (nil = system default)
    public var uiFont: String?
    /// Custom monospace font family name (nil = system mono)
    public var monoFont: String?

    public init(uiFont: String? = nil, monoFont: String? = nil) {
        self.uiFont = uiFont
        self.monoFont = monoFont
    }
}
