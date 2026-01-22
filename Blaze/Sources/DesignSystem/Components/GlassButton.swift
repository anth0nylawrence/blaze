import SwiftUI

// MARK: - Glass Button Style

/// Button style variants for glass buttons.
public enum GlassButtonStyle {
    case primary    // Accent-colored, prominent
    case secondary  // Subtle, glass background
    case ghost      // Minimal, text-only until hover
    case destructive // Red/warning variant
}

/// Size variants for glass buttons.
public enum GlassButtonSize {
    case small
    case medium
    case large

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return DSSpacing.sm
        case .medium: return DSSpacing.md
        case .large: return DSSpacing.lg
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return DSSpacing.xs
        case .medium: return DSSpacing.sm
        case .large: return DSSpacing.md
        }
    }

    var textStyle: DSTextStyle {
        switch self {
        case .small: return .caption
        case .medium: return .body
        case .large: return .subtitle
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return DSSize.xs
        case .medium: return DSSize.sm
        case .large: return DSSize.md
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return DSRadius.sm
        case .medium: return DSRadius.md
        case .large: return DSRadius.lg
        }
    }
}

// MARK: - Glass Button

/// A button with premium glass styling and smooth interactions.
public struct GlassButton: View {
    let title: String
    let icon: String?
    let style: GlassButtonStyle
    let size: GlassButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    public init(
        _ title: String,
        icon: String? = nil,
        style: GlassButtonStyle = .primary,
        size: GlassButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: { if !isDisabled && !isLoading { action() } }) {
            HStack(spacing: DSSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize))
                }

                Text(title)
                    .font(size.textStyle.font)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minWidth: minWidth)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay(borderOverlay)
            .dsElevation(elevation)
            .scaleEffect(scale)
            .brightness(brightness)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            guard !isDisabled else { return }
            withAnimation(.easeOut(duration: DSGlassAnimation.hoverDuration)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDisabled else { return }
                    withAnimation(.easeOut(duration: DSGlassAnimation.pressDuration)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: DSGlassAnimation.pressDuration)) {
                        isPressed = false
                    }
                }
        )
        .disabled(isDisabled || isLoading)
    }

    // MARK: - Computed Properties

    private var minWidth: CGFloat {
        switch size {
        case .small: return 60
        case .medium: return 80
        case .large: return 100
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return Color.ds.foreground
        case .ghost:
            return isHovered ? Color.ds.foreground : Color.ds.secondary
        case .destructive:
            return .white
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            if isPressed {
                Color.accentColor.opacity(0.9)
            } else if isHovered {
                Color.accentColor.brightness(0.05)
            } else {
                Color.accentColor
            }

        case .secondary:
            ZStack {
                Rectangle()
                    .fill(DSGlassLevel.regular.material)
                if isHovered {
                    Color.ds.foreground.opacity(0.05)
                }
            }

        case .ghost:
            if isHovered {
                Color.ds.foreground.opacity(0.08)
            } else {
                Color.clear
            }

        case .destructive:
            if isPressed {
                Color.ds.negative.opacity(0.9)
            } else if isHovered {
                Color.ds.negative.brightness(0.05)
            } else {
                Color.ds.negative
            }
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .primary, .destructive:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

        case .secondary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .stroke(Color.ds.border.opacity(0.3), lineWidth: 1)

        case .ghost:
            EmptyView()
        }
    }

    private var elevation: DSElevation {
        switch style {
        case .primary, .destructive:
            return isPressed ? .low : (isHovered ? .high : .medium)
        case .secondary:
            return isPressed ? .none : (isHovered ? .low : .none)
        case .ghost:
            return .none
        }
    }

    private var scale: CGFloat {
        if isPressed {
            return DSGlassAnimation.pressScale
        } else if isHovered && style != .ghost {
            return DSGlassAnimation.hoverScale
        }
        return 1.0
    }

    private var brightness: Double {
        if isPressed {
            return DSGlassAnimation.pressBrightness
        } else if isHovered {
            return DSGlassAnimation.hoverBrightness
        }
        return 0
    }
}

// MARK: - Icon-Only Button

/// A glass button with only an icon (no text).
public struct GlassIconButton: View {
    let icon: String
    let style: GlassButtonStyle
    let size: GlassButtonSize
    let action: () -> Void

    public init(
        icon: String,
        style: GlassButtonStyle = .secondary,
        size: GlassButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }

    public var body: some View {
        GlassButton(
            "",
            icon: icon,
            style: style,
            size: size,
            action: action
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Glass Buttons") {
    VStack(spacing: DSSpacing.lg) {
        HStack(spacing: DSSpacing.md) {
            GlassButton("Primary", icon: "star.fill", action: {})
            GlassButton("Secondary", style: .secondary, action: {})
            GlassButton("Ghost", style: .ghost, action: {})
            GlassButton("Destructive", icon: "trash", style: .destructive, action: {})
        }

        HStack(spacing: DSSpacing.md) {
            GlassButton("Small", size: .small, action: {})
            GlassButton("Medium", size: .medium, action: {})
            GlassButton("Large", size: .large, action: {})
        }

        HStack(spacing: DSSpacing.md) {
            GlassButton("Loading", isLoading: true, action: {})
            GlassButton("Disabled", isDisabled: true, action: {})
        }
    }
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}
#endif
