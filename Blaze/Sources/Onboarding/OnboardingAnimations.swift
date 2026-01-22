import SwiftUI

// MARK: - Onboarding Animation Tokens

/// Animation parameters specific to onboarding flows.
/// Aligned with DSGlassAnimation for consistency.
public enum OnboardingAnimation {
    /// Page transition duration (slide + fade)
    public static let pageDuration: Double = 0.3

    /// Content fade-in duration
    public static let fadeInDuration: Double = 0.2

    /// Staggered delay increment between items
    public static let staggerDelay: Double = 0.05

    /// Progress indicator transition duration
    public static let progressDuration: Double = 0.25

    /// Spring response for page transitions
    public static let springResponse: Double = 0.35

    /// Spring damping for page transitions
    public static let springDamping: Double = 0.85

    /// Scale factor for current progress dot
    public static let activeScale: CGFloat = 1.3

    /// Progress dot size
    public static let dotSize: CGFloat = 8
}

// MARK: - View Extensions for Onboarding Transitions

public extension View {
    /// Apply a slide + fade transition for onboarding page navigation.
    /// - Parameter direction: The edge from which content slides in.
    /// - Returns: A view with the onboarding transition applied.
    func onboardingTransition(direction: Edge = .trailing) -> some View {
        self.transition(
            .asymmetric(
                insertion: .move(edge: direction).combined(with: .opacity),
                removal: .move(edge: direction.opposite).combined(with: .opacity)
            )
        )
        .animation(
            .spring(
                response: OnboardingAnimation.springResponse,
                dampingFraction: OnboardingAnimation.springDamping
            ),
            value: UUID() // Trigger on any change
        )
    }

    /// Apply a fade-in effect with optional delay for staggered content.
    /// - Parameter delay: Delay before fade-in starts (in seconds).
    /// - Returns: A view with the fade-in modifier applied.
    func onboardingFadeIn(delay: Double = 0) -> some View {
        modifier(OnboardingFadeInModifier(delay: delay))
    }

    /// Apply a scale-in effect for emphasized content.
    /// - Returns: A view with the scale modifier applied.
    func onboardingScale() -> some View {
        modifier(OnboardingScaleModifier())
    }
}

// MARK: - Edge Extension

private extension Edge {
    /// Returns the opposite edge for asymmetric transitions.
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

// MARK: - Fade-In Modifier

/// A modifier that fades content in with an optional delay.
public struct OnboardingFadeInModifier: ViewModifier {
    let delay: Double

    @State private var isVisible = false

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .onAppear {
                withAnimation(
                    .easeOut(duration: OnboardingAnimation.fadeInDuration)
                        .delay(delay)
                ) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Scale Modifier

/// A modifier that scales content in from a smaller size.
public struct OnboardingScaleModifier: ViewModifier {
    @State private var isVisible = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(
                    .spring(
                        response: OnboardingAnimation.springResponse,
                        dampingFraction: OnboardingAnimation.springDamping
                    )
                ) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Staggered Content

/// A container that displays items with staggered fade-in animations.
public struct StaggeredContent<Content: View>: View {
    /// Number of items to display.
    let items: Int

    /// Delay increment between each item.
    let delay: Double

    /// Content builder that receives the item index.
    @ViewBuilder let content: (Int) -> Content

    public init(
        items: Int,
        delay: Double = OnboardingAnimation.staggerDelay,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.items = items
        self.delay = delay
        self.content = content
    }

    public var body: some View {
        ForEach(0..<items, id: \.self) { index in
            content(index)
                .onboardingFadeIn(delay: Double(index) * delay)
        }
    }
}

// MARK: - Progress Indicator

/// A horizontal progress indicator showing onboarding step progress.
public struct StepProgressIndicator: View {
    /// The current step (0-indexed).
    let currentStep: Int

    /// Total number of steps.
    let totalSteps: Int

    /// Spacing between dots.
    var spacing: CGFloat = DSSpacing.xs

    /// Inactive dot color.
    var inactiveColor: Color = Color.ds.tertiary.opacity(0.4)

    /// Active dot color.
    var activeColor: Color = Color.ds.accent

    public init(currentStep: Int, totalSteps: Int) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? activeColor : inactiveColor)
                    .frame(
                        width: OnboardingAnimation.dotSize,
                        height: OnboardingAnimation.dotSize
                    )
                    .scaleEffect(index == currentStep ? OnboardingAnimation.activeScale : 1.0)
                    .animation(
                        .spring(
                            response: OnboardingAnimation.progressDuration,
                            dampingFraction: OnboardingAnimation.springDamping
                        ),
                        value: currentStep
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
        .accessibilityValue("\(Int((Double(currentStep + 1) / Double(totalSteps)) * 100))% complete")
    }
}

// MARK: - Convenience Modifiers

public extension StepProgressIndicator {
    /// Set custom spacing between dots.
    func spacing(_ value: CGFloat) -> StepProgressIndicator {
        var copy = self
        copy.spacing = value
        return copy
    }

    /// Set custom inactive dot color.
    func inactiveColor(_ color: Color) -> StepProgressIndicator {
        var copy = self
        copy.inactiveColor = color
        return copy
    }

    /// Set custom active dot color.
    func activeColor(_ color: Color) -> StepProgressIndicator {
        var copy = self
        copy.activeColor = color
        return copy
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingAnimations_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DSSpacing.xl) {
            Text("Onboarding Progress")
                .font(.headline)

            StepProgressIndicator(currentStep: 1, totalSteps: 4)

            Divider()

            Text("Staggered Content")
                .font(.headline)

            StaggeredContent(items: 5, delay: 0.1) { index in
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    Text("Item \(index + 1)")
                }
                .padding(.vertical, DSSpacing.xxs)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 300)
    }
}
#endif
