import SwiftUI

// MARK: - Glass Panel Modifier

/// A ViewModifier that applies the premium glass aesthetic to any view.
/// Includes material background, layered borders, and subtle animations.
public struct GlassPanelModifier: ViewModifier {
    let level: DSGlassLevel
    let cornerRadius: CGFloat
    let elevation: DSElevation
    let border: DSGlassBorder
    let isInteractive: Bool

    @State private var isHovered = false
    @State private var isPressed = false

    public init(
        level: DSGlassLevel = .regular,
        cornerRadius: CGFloat = DSRadius.lg,
        elevation: DSElevation = .medium,
        border: DSGlassBorder = .standard,
        isInteractive: Bool = false
    ) {
        self.level = level
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.border = border
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(borderOverlay)
            .dsElevation(elevation)
            .scaleEffect(interactiveScale)
            .brightness(interactiveBrightness)
            .animation(.spring(response: DSGlassAnimation.springResponse, dampingFraction: DSGlassAnimation.springDamping), value: isHovered)
            .animation(.easeOut(duration: DSGlassAnimation.pressDuration), value: isPressed)
            .onHover { hovering in
                guard isInteractive else { return }
                isHovered = hovering
            }
    }

    // MARK: - Glass Background

    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            // Base material
            Rectangle()
                .fill(level.material)

            // Highlight gradient overlay
            Rectangle()
                .fill(DSGlassGradient.highlight)
                .opacity(level.highlightOpacity)
        }
    }

    // MARK: - Border Overlay

    @ViewBuilder
    private var borderOverlay: some View {
        switch border {
        case .none:
            EmptyView()

        case .subtle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.ds.border.opacity(level.borderOpacity), lineWidth: border.lineWidth)

        case .standard:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(level.highlightOpacity),
                            Color.white.opacity(level.highlightOpacity * 0.5),
                            Color.clear,
                            Color.black.opacity(level.borderOpacity * 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: border.lineWidth
                )

        case .layered:
            ZStack {
                // Outer stroke (shadow)
                RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
                    .stroke(Color.black.opacity(level.borderOpacity * 0.3), lineWidth: 1)
                    .offset(y: 1)

                // Main gradient stroke
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DSGlassGradient.border, lineWidth: border.lineWidth)

                // Inner highlight
                RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                    .stroke(Color.white.opacity(level.highlightOpacity * 0.5), lineWidth: 0.5)
                    .padding(1)
            }

        case .gradient:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DSGlassGradient.border, lineWidth: border.lineWidth)
        }
    }

    // MARK: - Interactive States

    private var interactiveScale: CGFloat {
        guard isInteractive else { return 1.0 }
        if isPressed {
            return DSGlassAnimation.pressScale
        } else if isHovered {
            return DSGlassAnimation.hoverScale
        }
        return 1.0
    }

    private var interactiveBrightness: Double {
        guard isInteractive else { return 0 }
        if isPressed {
            return DSGlassAnimation.pressBrightness
        } else if isHovered {
            return DSGlassAnimation.hoverBrightness
        }
        return 0
    }
}

// MARK: - View Extension

public extension View {
    /// Apply glass panel styling with customizable parameters.
    func dsGlassPanel(
        level: DSGlassLevel = .regular,
        cornerRadius: CGFloat = DSRadius.lg,
        elevation: DSElevation = .medium,
        border: DSGlassBorder = .standard,
        isInteractive: Bool = false
    ) -> some View {
        modifier(GlassPanelModifier(
            level: level,
            cornerRadius: cornerRadius,
            elevation: elevation,
            border: border,
            isInteractive: isInteractive
        ))
    }

    /// Apply simple glass panel with default settings.
    func dsGlassPanel() -> some View {
        modifier(GlassPanelModifier())
    }
}

// MARK: - Hairline Divider Modifier

/// A subtle 1px divider line using design system colors.
public struct HairlineDividerModifier: ViewModifier {
    let axis: Axis
    let color: Color
    let padding: CGFloat

    public init(
        axis: Axis = .horizontal,
        color: Color = Color.ds.border,
        padding: CGFloat = 0
    ) {
        self.axis = axis
        self.color = color
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: axis == .horizontal ? .bottom : .trailing) {
                if axis == .horizontal {
                    Rectangle()
                        .fill(color)
                        .frame(height: 1)
                        .padding(.horizontal, padding)
                } else {
                    Rectangle()
                        .fill(color)
                        .frame(width: 1)
                        .padding(.vertical, padding)
                }
            }
    }
}

public extension View {
    /// Add a hairline divider at the bottom (horizontal) or trailing (vertical) edge.
    func dsHairlineDivider(
        axis: Axis = .horizontal,
        color: Color = Color.ds.border,
        padding: CGFloat = 0
    ) -> some View {
        modifier(HairlineDividerModifier(axis: axis, color: color, padding: padding))
    }
}
