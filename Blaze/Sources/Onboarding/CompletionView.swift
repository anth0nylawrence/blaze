import SwiftUI

// MARK: - Completion View

/// The final screen in the onboarding flow.
/// Displays a celebratory summary of what was configured during onboarding.
public struct CompletionView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    @State private var showConfetti = false
    @State private var isAppeared = false

    public init() {}

    // MARK: - Computed Properties

    /// CLIs that were detected during onboarding
    private var detectedCLINames: [String] {
        viewModel.detectedCLIs
            .filter { $0.isDetected }
            .map { $0.name }
    }

    /// Summary items to display
    private var summaryItems: [SummaryItem] {
        var items: [SummaryItem] = []

        // CLIs
        if !detectedCLINames.isEmpty {
            items.append(SummaryItem(
                icon: "terminal",
                title: "CLIs Detected",
                detail: detectedCLINames.joined(separator: ", "),
                count: detectedCLINames.count,
                color: .ds.positive
            ))
        } else {
            items.append(SummaryItem(
                icon: "terminal",
                title: "CLIs",
                detail: "None detected - install later",
                count: 0,
                color: .ds.tertiary
            ))
        }

        // Skills
        let skillCount = viewModel.selectedSkills.count
        items.append(SummaryItem(
            icon: "star.fill",
            title: "Skills Selected",
            detail: skillCount > 0 ? "\(skillCount) skill\(skillCount == 1 ? "" : "s") ready" : "None selected",
            count: skillCount,
            color: skillCount > 0 ? .ds.accent : .ds.tertiary
        ))

        // Plugins
        let pluginCount = viewModel.selectedPlugins.count
        items.append(SummaryItem(
            icon: "puzzlepiece.extension",
            title: "Plugins Enabled",
            detail: pluginCount > 0 ? "\(pluginCount) plugin\(pluginCount == 1 ? "" : "s") active" : "None selected",
            count: pluginCount,
            color: pluginCount > 0 ? .ds.info : .ds.tertiary
        ))

        // Agents
        let agentCount = viewModel.selectedAgents.count
        items.append(SummaryItem(
            icon: "cpu",
            title: "Agents Enabled",
            detail: agentCount > 0 ? "\(agentCount) agent\(agentCount == 1 ? "" : "s") configured" : "None selected",
            count: agentCount,
            color: agentCount > 0 ? .ds.warning : .ds.tertiary
        ))

        return items
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: DSSpacing.xl) {
                Spacer()

                // Celebratory header
                celebratoryHeader
                    .onboardingScale()

                // Summary section
                summarySection
                    .onboardingFadeIn(delay: 0.2)

                Spacer()

                // Action buttons
                actionButtons
                    .onboardingFadeIn(delay: 0.4)
            }
            .padding(DSSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Trigger confetti with a slight delay for dramatic effect
            withAnimation(.easeOut(duration: 0.3)) {
                isAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showConfetti = true
                }
            }
        }
    }

    // MARK: - Celebratory Header

    private var celebratoryHeader: some View {
        VStack(spacing: DSSpacing.md) {
            // Checkmark icon with glow
            ZStack {
                // Glow backdrop
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.ds.positive.opacity(0.4),
                                Color.ds.positive.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.ds.positive,
                                    Color.ds.positive.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DSSize.huge + DSSize.lg, height: DSSize.huge + DSSize.lg)

                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .dsElevation(.high)
            }
            .padding(.bottom, DSSpacing.sm)

            // Headline
            Text("You're all set!")
                .dsTextStyle(.hero)
                .multilineTextAlignment(.center)

            // Tagline
            Text("Blaze is ready to supercharge your coding")
                .dsTextStyle(.subtitle, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(spacing: DSSpacing.sm) {
            ForEach(Array(summaryItems.enumerated()), id: \.element.id) { index, item in
                summaryRow(item)
                    .onboardingFadeIn(delay: 0.25 + Double(index) * OnboardingAnimation.staggerDelay)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(maxWidth: 440)
    }

    private func summaryRow(_ item: SummaryItem) -> some View {
        HStack(spacing: DSSpacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                    .fill(item.color.opacity(0.15))
                    .frame(width: DSSize.xl, height: DSSize.xl)

                Image(systemName: item.icon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(item.color)
            }

            // Text content
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(item.title)
                    .dsTextStyle(.body, weight: .medium)

                Text(item.detail)
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()

            // Count badge (if any)
            if item.count > 0 {
                Text("\(item.count)")
                    .dsTextStyle(.caption, weight: .semibold)
                    .foregroundStyle(item.color)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(
                        Capsule()
                            .fill(item.color.opacity(0.15))
                    )
            }
        }
        .padding(DSSpacing.sm)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .low, border: .subtle)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DSSpacing.md) {
            // Primary CTA
            GlassButton(
                "Start Using Blaze",
                icon: "arrow.right",
                style: .primary,
                size: .large
            ) {
                viewModel.completeOnboarding()
            }
            .frame(minWidth: 220)

            // Secondary option for future tutorial
            Button {
                // TODO: Implement quick tour
                // For now, just complete onboarding
                viewModel.completeOnboarding()
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "play.circle")
                        .font(.system(size: DSSize.xs))
                    Text("Take a Quick Tour")
                }
                .dsTextStyle(.caption, color: .ds.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.8)
            .onHover { hovering in
                // Hover handled by button style
            }
        }
    }
}

// MARK: - Summary Item Model

private struct SummaryItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let count: Int
    let color: Color
}

// MARK: - Confetti View

/// A simple confetti animation overlay for celebration.
private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [
        .ds.accent,
        .ds.positive,
        .ds.warning,
        .ds.info,
        Color.purple,
        Color.pink
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
    }

    private func createParticles(in size: CGSize) {
        let particleCount = 60

        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -CGFloat.random(in: 20...100),
                color: colors.randomElement() ?? .ds.accent,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                delay: Double.random(in: 0...0.5)
            )
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let delay: Double
}

private struct ConfettiPiece: View {
    let particle: ConfettiParticle

    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.6)
            .rotationEffect(.degrees(particle.rotation + rotationAngle))
            .position(x: particle.x + xOffset, y: particle.y + yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.5)
                        .delay(particle.delay)
                ) {
                    yOffset = 800
                    xOffset = CGFloat.random(in: -100...100)
                    rotationAngle = Double.random(in: 360...720)
                }

                withAnimation(
                    .easeIn(duration: 0.8)
                        .delay(particle.delay + 1.5)
                ) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Completion View - Empty") {
    CompletionView()
        .environment(OnboardingViewModel())
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}

#Preview("Completion View - With Selections") {
    CompletionView()
        .environment({
            let vm = OnboardingViewModel()
            vm.selectedSkills = ["commit", "review"]
            vm.selectedPlugins = ["github"]
            vm.selectedAgents = ["scout"]
            return vm
        }())
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}

#Preview("Completion View - Dark") {
    CompletionView()
        .environment({
            let vm = OnboardingViewModel()
            vm.selectedSkills = ["commit", "test", "review"]
            vm.selectedPlugins = ["github", "slack"]
            vm.selectedAgents = ["scout", "oracle"]
            return vm
        }())
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
        .preferredColorScheme(.dark)
}
#endif
