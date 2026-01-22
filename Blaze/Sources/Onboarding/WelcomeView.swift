import AppKit
import SwiftUI

// MARK: - Blaze Logo (SF Symbol)

private enum BlazeLogo {
    /// Returns a flame icon as the Blaze logo.
    /// Using SF Symbol avoids SPM resource bundling complexity.
    static func image(size: CGFloat = 48) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size * 0.7, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Welcome View

/// The first screen in the onboarding flow.
/// Introduces Blaze with a hero icon, headline, tagline, feature highlights,
/// and a primary "Get Started" CTA.
///
/// This view is designed to be embedded in `OnboardingRootView` which provides
/// the navigation bar and background. When used standalone, it provides its own
/// action buttons and background.
public struct WelcomeView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    /// When true, this view provides its own action buttons and background.
    /// When false, it assumes the parent container provides navigation.
    private let isStandalone: Bool

    @State private var isAppeared = false

    // MARK: - Initialization

    public init(standalone: Bool = false) {
        self.isStandalone = standalone
    }

    // MARK: - Feature Items

    private struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }

    private let features: [FeatureItem] = [
        FeatureItem(
            icon: "brain.head.profile",
            title: "Multiple AI Providers",
            description: "Claude, Gemini, and Codex in one unified interface"
        ),
        FeatureItem(
            icon: "doc.viewfinder",
            title: "Structured Event Rendering",
            description: "Rich diffs, tool cards, and real-time streaming"
        ),
        FeatureItem(
            icon: "shield.lefthalf.filled",
            title: "Governance & Permissions",
            description: "Review gates and approval workflows you control"
        ),
        FeatureItem(
            icon: "rectangle.split.3x1",
            title: "Session Workspaces",
            description: "Git worktrees, multi-file editing, and task tracking"
        )
    ]

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero content
            heroSection
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 20)

            Spacer()

            // Feature list
            featureList
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 30)

            Spacer()

            // Actions (only when standalone)
            if isStandalone {
                actionSection
                    .opacity(isAppeared ? 1 : 0)
                    .offset(y: isAppeared ? 0 : 20)

                Spacer()
                    .frame(height: DSSpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isStandalone {
                backgroundGradient
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                isAppeared = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: DSSpacing.md) {
            // App icon with glow effect
            ZStack {
                // Glow backdrop
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(0.3),
                                Color.accentColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                // Icon container - Blaze logo (PNG from bundle)
                BlazeLogo.image(size: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .dsElevation(.high)
            }
            .padding(.bottom, DSSpacing.sm)

            // Headline
            Text("Welcome to Blaze")
                .dsTextStyle(.hero)
                .multilineTextAlignment(.center)

            // Tagline
            Text("Your AI-powered coding companion")
                .dsTextStyle(.subtitle, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: DSSpacing.sm) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                featureRow(feature)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                    .animation(
                        .easeOut(duration: 0.4).delay(Double(index) * 0.08),
                        value: isAppeared
                    )
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .frame(maxWidth: 480)
    }

    private func featureRow(_ feature: FeatureItem) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            // Icon
            Image(systemName: feature.icon)
                .font(.system(size: DSSize.md))
                .foregroundStyle(Color.accentColor)
                .frame(width: DSSize.lg, height: DSSize.lg)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            // Text content
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(feature.title)
                    .dsTextStyle(.body, weight: .medium)

                Text(feature.description)
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()
        }
        .padding(DSSpacing.sm)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .low, border: .subtle)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: DSSpacing.md) {
            // Primary CTA
            GlassButton(
                "Get Started",
                icon: "arrow.right",
                style: .primary,
                size: .large
            ) {
                viewModel.nextStep()
            }
            .frame(minWidth: 200)

            // Skip link (subtle, bottom-right aligned)
            HStack {
                Spacer()

                Button {
                    viewModel.skipOnboarding()
                } label: {
                    Text("Skip")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(0.7)
                .onHover { hovering in
                    // Subtle hover feedback handled by button style
                }
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, DSSpacing.xl)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Base color
            Color.ds.bg0

            // Subtle radial gradient overlay
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.03),
                    Color.clear
                ],
                center: .top,
                startRadius: 100,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Welcome View") {
    WelcomeView()
        .frame(width: 600, height: 700)
        .environment(OnboardingViewModel())
}

#Preview("Welcome View - Dark") {
    WelcomeView()
        .frame(width: 600, height: 700)
        .environment(OnboardingViewModel())
        .preferredColorScheme(.dark)
}
#endif
