import SwiftUI

// MARK: - Focus Ring Modifier

/// A ViewModifier that adds an accessible focus ring indicator.
/// Provides a tasteful alternative to the default system focus ring.
public struct FocusRingModifier: ViewModifier {
    let isFocused: Bool
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let offset: CGFloat

    public init(
        isFocused: Bool,
        color: Color = .accentColor,
        cornerRadius: CGFloat = DSRadius.lg,
        lineWidth: CGFloat = 2,
        offset: CGFloat = 3
    ) {
        self.isFocused = isFocused
        self.color = color
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.offset = offset
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + offset, style: .continuous)
                    .stroke(color.opacity(isFocused ? 0.8 : 0), lineWidth: lineWidth)
                    .padding(-offset)
                    .animation(.easeOut(duration: DSGlassAnimation.focusDuration), value: isFocused)
            )
            .dsGlow(color: color, radius: 4, isActive: isFocused, intensity: 0.3)
    }
}

// MARK: - View Extension

public extension View {
    /// Add a focus ring that appears when focused.
    func dsFocusRing(
        isFocused: Bool,
        color: Color = .accentColor,
        cornerRadius: CGFloat = DSRadius.lg
    ) -> some View {
        modifier(FocusRingModifier(
            isFocused: isFocused,
            color: color,
            cornerRadius: cornerRadius
        ))
    }
}

// MARK: - Focusable Wrapper

/// A wrapper that automatically tracks focus state and applies focus ring.
public struct DSFocusable<Content: View>: View {
    @FocusState private var isFocused: Bool
    let cornerRadius: CGFloat
    let content: () -> Content

    public init(
        cornerRadius: CGFloat = DSRadius.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        content()
            .focused($isFocused)
            .dsFocusRing(isFocused: isFocused, cornerRadius: cornerRadius)
    }
}

// MARK: - Selection Ring Modifier

/// A ViewModifier for indicating selected state (different from focus).
public struct SelectionRingModifier: ViewModifier {
    let isSelected: Bool
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    public init(
        isSelected: Bool,
        color: Color = .accentColor,
        cornerRadius: CGFloat = DSRadius.lg,
        lineWidth: CGFloat = 2
    ) {
        self.isSelected = isSelected
        self.color = color
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(isSelected ? 1.0 : 0), lineWidth: lineWidth)
                    .animation(.easeOut(duration: 0.15), value: isSelected)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(isSelected ? 0.1 : 0))
            )
    }
}

public extension View {
    /// Add a selection indicator ring.
    func dsSelectionRing(
        isSelected: Bool,
        color: Color = .accentColor,
        cornerRadius: CGFloat = DSRadius.lg
    ) -> some View {
        modifier(SelectionRingModifier(
            isSelected: isSelected,
            color: color,
            cornerRadius: cornerRadius
        ))
    }
}

// MARK: - Hover Highlight Modifier

/// A ViewModifier that highlights on hover.
public struct HoverHighlightModifier: ViewModifier {
    let cornerRadius: CGFloat
    let highlightColor: Color

    @State private var isHovered = false

    public init(
        cornerRadius: CGFloat = DSRadius.md,
        highlightColor: Color = Color.ds.foreground.opacity(0.05)
    ) {
        self.cornerRadius = cornerRadius
        self.highlightColor = highlightColor
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovered ? highlightColor : .clear)
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

public extension View {
    /// Add hover highlight effect.
    func dsHoverHighlight(
        cornerRadius: CGFloat = DSRadius.md,
        color: Color = Color.ds.foreground.opacity(0.05)
    ) -> some View {
        modifier(HoverHighlightModifier(cornerRadius: cornerRadius, highlightColor: color))
    }
}
