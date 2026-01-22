import SwiftUI

// MARK: - Detected Skill Card View

/// A card displaying an individual detected skill with toggle functionality.
struct DetectedSkillCard: View {
    let skill: DetectedSkill
    let onToggle: () -> Void

    @State private var isHovered = false

    /// Convert CLI ID to display color
    private var cliColor: Color {
        switch skill.sourceCLI.lowercased() {
        case "claude": return .cyan
        case "codex": return .green
        case "gemini": return .blue
        case "opencode": return .orange
        case "ampcode": return .purple
        default: return .gray
        }
    }

    /// Convert CLI ID to display name
    private var cliDisplayName: String {
        switch skill.sourceCLI.lowercased() {
        case "claude": return "Claude Code"
        case "codex": return "OpenAI Codex"
        case "gemini": return "Gemini CLI"
        case "opencode": return "OpenCode"
        case "ampcode": return "AmpCode"
        default: return skill.sourceCLI.capitalized
        }
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: DSSpacing.md) {
                // Avatar
                skillAvatar

                // Name and CLI source
                VStack(spacing: DSSpacing.xxs) {
                    Text(skill.name)
                        .dsTextStyle(.subtitle, weight: .semibold)

                    Text(cliDisplayName)
                        .dsTextStyle(.caption, color: cliColor)
                        .fontWeight(.medium)
                }

                // Description
                Text(skill.description)
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Toggle indicator
                toggleIndicator
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity)
            .dsGlassPanel(
                level: skill.isEnabled ? .prominent : .regular,
                cornerRadius: DSRadius.lg,
                elevation: isHovered ? .high : (skill.isEnabled ? .medium : .low),
                border: skill.isEnabled ? .layered : .standard
            )
            .overlay(selectionBorder)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: skill.isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }

    // MARK: - Subviews

    private var skillAvatar: some View {
        ZStack {
            // Background circle with CLI color
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            cliColor.opacity(0.8),
                            cliColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: DSSize.xxl, height: DSSize.xxl)

            // Glow effect when selected
            if skill.isEnabled {
                Circle()
                    .fill(cliColor.opacity(0.3))
                    .frame(width: DSSize.xxl + 8, height: DSSize.xxl + 8)
                    .blur(radius: 8)
            }

            // Icon
            Image(systemName: skill.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var toggleIndicator: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: skill.isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(skill.isEnabled ? Color.ds.positive : Color.ds.tertiary)

            Text(skill.isEnabled ? "Enabled" : "Disabled")
                .dsTextStyle(.caption, color: skill.isEnabled ? .ds.positive : .ds.tertiary)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(
            Capsule()
                .fill(skill.isEnabled ? Color.ds.positive.opacity(0.1) : Color.ds.foreground.opacity(0.05))
        )
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
            .stroke(
                skill.isEnabled ? cliColor.opacity(0.6) : Color.clear,
                lineWidth: 2
            )
    }
}

// MARK: - Skills Recommendations View

/// Onboarding step for configuring skills.
public struct SkillsRecommendationsView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()

            // Header
            header

            // Content based on scan state
            contentView

            Spacer()
        }
        .task {
            if viewModel.skillScanState == .idle {
                await viewModel.scanForSkills()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DSSpacing.sm) {
            Text("Your Skills")
                .dsTextStyle(.hero)

            Text("Skills extend capabilities with specialized workflows")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.skillScanState {
        case .idle, .scanning:
            scanningView

        case .completed:
            if viewModel.detectedSkills.isEmpty {
                noSkillsView
            } else {
                VStack(spacing: DSSpacing.lg) {
                    skillGrid
                    quickActions
                }
            }

        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.ds.accent)

            Text("Scanning for skills...")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .padding(.vertical, DSSpacing.xxl)
    }

    // MARK: - No Skills View

    private var noSkillsView: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "star.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.tertiary)

            VStack(spacing: DSSpacing.sm) {
                Text("No Skills Found")
                    .dsTextStyle(.subtitle, weight: .semibold)

                Text("Add skill definitions to ~/.claude/skills/ to see them here")
                    .dsTextStyle(.body, color: .ds.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Rescan") {
                Task {
                    await viewModel.scanForSkills()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, DSSpacing.xxl)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.negative)

            VStack(spacing: DSSpacing.sm) {
                Text("Scan Failed")
                    .dsTextStyle(.subtitle, weight: .semibold)

                Text(message)
                    .dsTextStyle(.body, color: .ds.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                Task {
                    await viewModel.scanForSkills()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, DSSpacing.xxl)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Skill Grid

    private var skillGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(viewModel.detectedSkills) { skill in
                    DetectedSkillCard(
                        skill: skill,
                        onToggle: { viewModel.toggleSkill(id: skill.id) }
                    )
                }
            }
            .padding(.horizontal, DSSpacing.lg)
        }
        .frame(maxHeight: 400)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: DSSpacing.md) {
            Button("Enable All") {
                viewModel.enableAllSkills()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.accent)

            Text("|")
                .foregroundStyle(Color.ds.tertiary)

            Button("Disable All") {
                viewModel.disableAllSkills()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.secondary)

            Text("|")
                .foregroundStyle(Color.ds.tertiary)

            Text("\(viewModel.enabledSkillCount) of \(viewModel.detectedSkills.count) enabled")
                .foregroundStyle(Color.ds.tertiary)
        }
        .dsTextStyle(.caption)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Skills Recommendations") {
    SkillsRecommendationsView()
        .environment(OnboardingViewModel())
        .frame(width: 700, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Detected Skill Card - Enabled") {
    DetectedSkillCard(
        skill: DetectedSkill(
            id: "commit",
            name: "Commit",
            description: "Create git commits with user approval and no Claude attribution",
            icon: "arrow.triangle.branch",
            sourceCLI: "claude",
            filePath: URL(fileURLWithPath: "/tmp"),
            isEnabled: true
        ),
        onToggle: {}
    )
    .frame(width: 200)
    .padding()
    .background(Color.ds.bg0)
}

#Preview("Detected Skill Card - Disabled") {
    DetectedSkillCard(
        skill: DetectedSkill(
            id: "test",
            name: "Test",
            description: "Comprehensive testing workflow - unit tests, integration tests, E2E tests",
            icon: "testtube.2",
            sourceCLI: "claude",
            filePath: URL(fileURLWithPath: "/tmp"),
            isEnabled: false
        ),
        onToggle: {}
    )
    .frame(width: 200)
    .padding()
    .background(Color.ds.bg0)
}
#endif
