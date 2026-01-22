import SwiftUI
import os.log

// MARK: - ThemeColors

/// Semantic color definitions with optional overrides.
/// Colors persist as hex strings and resolve against DSColors at runtime.
public struct ThemeColors: Codable, Equatable, Sendable {
    public var background: Color?
    public var surface: Color?
    public var surfaceHover: Color?
    public var accent: Color?
    public var accentHover: Color?
    public var textPrimary: Color?
    public var textSecondary: Color?
    public var textMuted: Color?
    public var border: Color?
    public var success: Color?
    public var warning: Color?
    public var error: Color?

    public init(
        background: Color? = nil, surface: Color? = nil, surfaceHover: Color? = nil,
        accent: Color? = nil, accentHover: Color? = nil,
        textPrimary: Color? = nil, textSecondary: Color? = nil, textMuted: Color? = nil,
        border: Color? = nil, success: Color? = nil, warning: Color? = nil, error: Color? = nil
    ) {
        self.background = background; self.surface = surface; self.surfaceHover = surfaceHover
        self.accent = accent; self.accentHover = accentHover
        self.textPrimary = textPrimary; self.textSecondary = textSecondary; self.textMuted = textMuted
        self.border = border; self.success = success; self.warning = warning; self.error = error
    }

    // MARK: - Presets

    /// Nebula theme: deep blue dark aesthetic (Ghostty blue)
    public static var nebula: ThemeColors {
        ThemeColors(
            background: Color(hex: "#0A1020"), surface: Color(hex: "#1A1725"),
            surfaceHover: Color(hex: "#251F35"), accent: Color(hex: "#9966FF"),
            accentHover: Color(hex: "#B38AFF"), textPrimary: Color(hex: "#E8E4F0"),
            textSecondary: Color(hex: "#A89FC4"), textMuted: Color(hex: "#6B6280"),
            border: Color(hex: "#3D3555"), success: Color(hex: "#4ADE80"),
            warning: Color(hex: "#FBBF24"), error: Color(hex: "#F87171")
        )
    }

    /// Hyperion theme: deep purple dark aesthetic (original Nebula colors)
    public static var hyperion: ThemeColors {
        ThemeColors(
            background: Color(hex: "#0D0B14"), surface: Color(hex: "#1A1725"),
            surfaceHover: Color(hex: "#251F35"), accent: Color(hex: "#9966FF"),
            accentHover: Color(hex: "#B38AFF"), textPrimary: Color(hex: "#E8E4F0"),
            textSecondary: Color(hex: "#A89FC4"), textMuted: Color(hex: "#6B6280"),
            border: Color(hex: "#3D3555"), success: Color(hex: "#4ADE80"),
            warning: Color(hex: "#FBBF24"), error: Color(hex: "#F87171")
        )
    }

    /// Resolves theme colors against system defaults, returning non-optional colors.
    public func resolved(with system: DSColors.Type) -> ResolvedThemeColors {
        ResolvedThemeColors(
            background: background ?? system.bg0, surface: surface ?? system.surface,
            surfaceHover: surfaceHover ?? system.panel, accent: accent ?? system.accent,
            accentHover: accentHover ?? system.accent.opacity(0.8),
            textPrimary: textPrimary ?? system.foreground, textSecondary: textSecondary ?? system.secondary,
            textMuted: textMuted ?? system.tertiary, border: border ?? system.border,
            success: success ?? system.positive, warning: warning ?? system.warning,
            error: error ?? system.negative
        )
    }

    // MARK: - Codable (Hex Strings)

    private enum CodingKeys: String, CodingKey {
        case background, surface, surfaceHover, accent, accentHover
        case textPrimary, textSecondary, textMuted, border, success, warning, error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func decode(_ key: CodingKeys) -> Color? {
            guard let hex = try? c.decodeIfPresent(String.self, forKey: key),
                  let color = Color(hex: hex) else {
                if let hex = try? c.decodeIfPresent(String.self, forKey: key) {
                    Logger.theme.warning("Invalid hex '\(hex)' for '\(key.rawValue)'")
                }
                return nil
            }
            return color
        }
        background = decode(.background); surface = decode(.surface); surfaceHover = decode(.surfaceHover)
        accent = decode(.accent); accentHover = decode(.accentHover)
        textPrimary = decode(.textPrimary); textSecondary = decode(.textSecondary); textMuted = decode(.textMuted)
        border = decode(.border); success = decode(.success); warning = decode(.warning); error = decode(.error)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func encode(_ color: Color?, _ key: CodingKeys) throws {
            if let color, let hex = color.hexString { try c.encode(hex, forKey: key) }
        }
        try encode(background, .background); try encode(surface, .surface); try encode(surfaceHover, .surfaceHover)
        try encode(accent, .accent); try encode(accentHover, .accentHover)
        try encode(textPrimary, .textPrimary); try encode(textSecondary, .textSecondary); try encode(textMuted, .textMuted)
        try encode(border, .border); try encode(success, .success); try encode(warning, .warning); try encode(error, .error)
    }
}

// MARK: - ResolvedThemeColors

/// Fully resolved theme colors with no optionals. Use after merging with system defaults.
public struct ResolvedThemeColors: Equatable, Sendable {
    public let background, surface, surfaceHover: Color
    public let accent, accentHover: Color
    public let textPrimary, textSecondary, textMuted: Color
    public let border, success, warning, error: Color
}

// MARK: - Color Hex Extension

public extension Color {
    /// Creates a Color from hex string (#RRGGBB or #RRGGBBAA). Returns nil for invalid formats.
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6 || h.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        if h.count == 6 {
            self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                      green: Double((rgb >> 8) & 0xFF) / 255,
                      blue: Double(rgb & 0xFF) / 255)
        } else {
            self.init(red: Double((rgb >> 24) & 0xFF) / 255,
                      green: Double((rgb >> 16) & 0xFF) / 255,
                      blue: Double((rgb >> 8) & 0xFF) / 255,
                      opacity: Double(rgb & 0xFF) / 255)
        }
    }

    /// Returns hex string (#RRGGBB or #RRGGBBAA). Nil if not convertible to RGB.
    var hexString: String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(c.redComponent * 255), g = Int(c.greenComponent * 255), b = Int(c.blueComponent * 255)
        return c.alphaComponent < 1.0
            ? String(format: "#%02X%02X%02X%02X", r, g, b, Int(c.alphaComponent * 255))
            : String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Logger

private extension Logger {
    static let theme = Logger(subsystem: "com.cogit0.Blaze", category: "Theme")
}
