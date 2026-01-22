import SwiftUI

// MARK: - Global Font Scale Environment Key

private struct GlobalFontScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

public extension EnvironmentValues {
    var globalFontScale: Double {
        get { self[GlobalFontScaleKey.self] }
        set { self[GlobalFontScaleKey.self] = newValue }
    }
}

// MARK: - Text Style Modifier

/// A ViewModifier that applies design system typography tokens.
public struct TextStyleModifier: ViewModifier {
    @Environment(\.globalFontScale) private var fontScale

    let style: DSTextStyle
    let color: Color?
    let weight: Font.Weight?

    public init(
        style: DSTextStyle,
        color: Color? = nil,
        weight: Font.Weight? = nil
    ) {
        self.style = style
        self.color = color
        self.weight = weight
    }

    public func body(content: Content) -> some View {
        content
            .font(effectiveFont)
            .foregroundStyle(color ?? Color.ds.foreground)
            .tracking(style.tracking)
            .lineSpacing((style.lineHeight - 1.0) * scaledFontSize)
    }

    private var effectiveFont: Font {
        let baseFont = scaledFont
        if let weight = weight {
            return baseFont.weight(weight)
        }
        return baseFont
    }

    private var scaledFontSize: CGFloat {
        baseFontSize * fontScale
    }

    private var scaledFont: Font {
        let size = scaledFontSize
        switch style {
        case .hero:
            return .system(size: size, weight: .bold, design: .default)
        case .title:
            return .system(size: size, weight: .semibold, design: .default)
        case .subtitle:
            return .system(size: size, weight: .medium, design: .default)
        case .body:
            return .system(size: size, weight: .regular, design: .default)
        case .caption:
            return .system(size: size, weight: .regular, design: .default)
        case .micro:
            return .system(size: size, weight: .regular, design: .default)
        case .mono:
            return .system(size: size, weight: .regular, design: .monospaced)
        case .monoSmall:
            return .system(size: size, weight: .regular, design: .monospaced)
        case .monoLarge:
            return .system(size: size, weight: .regular, design: .monospaced)
        }
    }

    private var baseFontSize: CGFloat {
        switch style {
        case .hero: return 32
        case .title: return 20
        case .subtitle: return 16
        case .body: return 14
        case .caption: return 12
        case .micro: return 11
        case .mono: return 13
        case .monoSmall: return 11
        case .monoLarge: return 15
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Apply design system text style with optional color and weight overrides.
    func dsTextStyle(
        _ style: DSTextStyle,
        color: Color? = nil,
        weight: Font.Weight? = nil
    ) -> some View {
        modifier(TextStyleModifier(style: style, color: color, weight: weight))
    }
}

// MARK: - Text Extensions

public extension Text {
    /// Apply design system text style directly to Text.
    func dsStyle(_ style: DSTextStyle, color: Color? = nil) -> some View {
        self
            .font(style.font)
            .foregroundStyle(color ?? Color.ds.foreground)
            .tracking(style.tracking)
    }
}

// MARK: - Label Style

/// A label style that uses design system typography.
public struct DSLabelStyle: LabelStyle {
    let textStyle: DSTextStyle
    let iconSize: CGFloat
    let spacing: CGFloat

    public init(
        textStyle: DSTextStyle = .body,
        iconSize: CGFloat = DSSize.sm,
        spacing: CGFloat = DSSpacing.xs
    ) {
        self.textStyle = textStyle
        self.iconSize = iconSize
        self.spacing = spacing
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
                .font(.system(size: iconSize))
            configuration.title
                .font(textStyle.font)
        }
    }
}

public extension LabelStyle where Self == DSLabelStyle {
    /// Design system label style with customizable text style.
    static func ds(_ textStyle: DSTextStyle = .body) -> DSLabelStyle {
        DSLabelStyle(textStyle: textStyle)
    }
}
