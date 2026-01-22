import SwiftUI

// MARK: - Badge Animation Modifiers

/// Pulse animation modifier for badge count increases.
/// Scales 1.0 -> 1.1 -> 1.0 over 0.3s.
public struct BadgePulseModifier: ViewModifier {
    let trigger: Int

    @State private var scale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { oldValue, newValue in
                guard !reduceMotion, newValue > oldValue else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    scale = 1.1
                }
                withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
                    scale = 1.0
                }
            }
    }
}

/// Fade-in animation modifier for badge appearance.
/// Opacity 0 -> 1 over 0.2s when count transitions from 0 to positive.
public struct BadgeFadeInModifier: ViewModifier {
    let isVisible: Bool

    @State private var opacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onChange(of: isVisible) { _, newValue in
                if reduceMotion {
                    opacity = newValue ? 1 : 0
                } else if newValue {
                    withAnimation(.easeIn(duration: 0.2)) {
                        opacity = 1
                    }
                } else {
                    opacity = 0
                }
            }
            .onAppear {
                opacity = isVisible ? 1 : 0
            }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply pulse animation when count increases.
    func pulseAnimation(trigger: Int) -> some View {
        modifier(BadgePulseModifier(trigger: trigger))
    }

    /// Apply fade-in animation when badge becomes visible.
    func fadeInAnimation(isVisible: Bool) -> some View {
        modifier(BadgeFadeInModifier(isVisible: isVisible))
    }
}

// MARK: - AnimatedBadge

/// A wrapper that applies animations to a CountBadge.
/// Pulses when count increases, fades in when count goes from 0 to positive.
public struct AnimatedBadge: View {
    let count: Int
    let variant: BadgeVariant
    let maxDisplay: Int

    @State private var previousCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ count: Int,
        variant: BadgeVariant = .primary,
        maxDisplay: Int = 99
    ) {
        self.count = count
        self.variant = variant
        self.maxDisplay = maxDisplay
    }

    public var body: some View {
        CountBadge(count, variant: variant, maxDisplay: maxDisplay)
            .pulseAnimation(trigger: count)
            .fadeInAnimation(isVisible: count > 0)
            .onChange(of: count) { _, newValue in
                previousCount = newValue
            }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Badge Animations") {
    BadgeAnimationDemo()
        .frame(width: 300, height: 200)
        .background(Color.ds.bg0)
}

private struct BadgeAnimationDemo: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("Tap to increment")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: DSSpacing.xl) {
                VStack {
                    Text("Static")
                        .font(.caption2)
                    CountBadge(count)
                }

                VStack {
                    Text("Animated")
                        .font(.caption2)
                    AnimatedBadge(count)
                }
            }

            HStack(spacing: DSSpacing.md) {
                Button("-") {
                    if count > 0 { count -= 1 }
                }

                Button("+") {
                    count += 1
                }

                Button("Reset") {
                    count = 0
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
#endif
