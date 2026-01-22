import SwiftUI

// MARK: - Glow Modifier

/// A ViewModifier that adds a subtle outer glow effect for emphasis.
/// Commonly used for focused or primary elements.
public struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool
    let intensity: Double

    public init(
        color: Color = .accentColor,
        radius: CGFloat = 8,
        isActive: Bool = true,
        intensity: Double = 0.5
    ) {
        self.color = color
        self.radius = radius
        self.isActive = isActive
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(intensity) : .clear,
                radius: isActive ? radius : 0
            )
            .animation(.easeInOut(duration: DSGlassAnimation.focusDuration), value: isActive)
    }
}

// MARK: - View Extension

public extension View {
    /// Add a subtle glow effect around the view.
    func dsGlow(
        color: Color = .accentColor,
        radius: CGFloat = 8,
        isActive: Bool = true,
        intensity: Double = 0.5
    ) -> some View {
        modifier(GlowModifier(
            color: color,
            radius: radius,
            isActive: isActive,
            intensity: intensity
        ))
    }

    /// Add accent-colored glow when condition is true.
    func dsGlow(when condition: Bool, radius: CGFloat = 8) -> some View {
        modifier(GlowModifier(
            color: .accentColor,
            radius: radius,
            isActive: condition
        ))
    }
}

// MARK: - Pulse Glow Modifier

/// A ViewModifier that adds a pulsing glow animation.
/// Useful for drawing attention to important elements.
public struct PulseGlowModifier: ViewModifier {
    let color: Color
    let minRadius: CGFloat
    let maxRadius: CGFloat
    let duration: Double
    let isActive: Bool

    @State private var isPulsing = false

    public init(
        color: Color = .accentColor,
        minRadius: CGFloat = 4,
        maxRadius: CGFloat = 12,
        duration: Double = 1.5,
        isActive: Bool = true
    ) {
        self.color = color
        self.minRadius = minRadius
        self.maxRadius = maxRadius
        self.duration = duration
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(isPulsing ? 0.6 : 0.3) : .clear,
                radius: isActive ? (isPulsing ? maxRadius : minRadius) : 0
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}

public extension View {
    /// Add a pulsing glow animation.
    func dsPulseGlow(
        color: Color = .accentColor,
        isActive: Bool = true
    ) -> some View {
        modifier(PulseGlowModifier(color: color, isActive: isActive))
    }
}

// MARK: - Inner Glow Modifier

/// A ViewModifier that adds an inner glow effect using overlay.
public struct InnerGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let cornerRadius: CGFloat

    public init(
        color: Color = .accentColor,
        radius: CGFloat = 4,
        cornerRadius: CGFloat = DSRadius.lg
    ) {
        self.color = color
        self.radius = radius
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(0.5), lineWidth: radius)
                    .blur(radius: radius)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public extension View {
    /// Add an inner glow effect.
    func dsInnerGlow(
        color: Color = .accentColor,
        radius: CGFloat = 4,
        cornerRadius: CGFloat = DSRadius.lg
    ) -> some View {
        modifier(InnerGlowModifier(
            color: color,
            radius: radius,
            cornerRadius: cornerRadius
        ))
    }
}
