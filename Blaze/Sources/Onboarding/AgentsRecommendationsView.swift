import SwiftUI

// MARK: - Detected Agent Card View

/// A card displaying an individual detected agent with toggle functionality.
struct DetectedAgentCard: View {
    let agent: DetectedAgent
    let onToggle: () -> Void

    @State private var isHovered = false

    /// Convert color name string to SwiftUI Color
    private var agentColor: Color {
        switch agent.colorName.lowercased() {
        case "purple": return .purple
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "cyan": return .cyan
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "pink": return .pink
        case "yellow": return .yellow
        case "brown": return .brown
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: DSSpacing.md) {
                // Avatar
                agentAvatar

                // Name and model
                VStack(spacing: DSSpacing.xxs) {
                    Text(agent.name)
                        .dsTextStyle(.subtitle, weight: .semibold)

                    Text(agent.model.capitalized)
                        .dsTextStyle(.caption, color: agentColor)
                        .fontWeight(.medium)
                }

                // Description
                Text(agent.description)
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
                level: agent.isEnabled ? .prominent : .regular,
                cornerRadius: DSRadius.lg,
                elevation: isHovered ? .high : (agent.isEnabled ? .medium : .low),
                border: agent.isEnabled ? .layered : .standard
            )
            .overlay(selectionBorder)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: agent.isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }

    // MARK: - Subviews

    private var agentAvatar: some View {
        ZStack {
            // Background circle with agent color
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            agentColor.opacity(0.8),
                            agentColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: DSSize.xxl, height: DSSize.xxl)

            // Glow effect when selected
            if agent.isEnabled {
                Circle()
                    .fill(agentColor.opacity(0.3))
                    .frame(width: DSSize.xxl + 8, height: DSSize.xxl + 8)
                    .blur(radius: 8)
            }

            // Icon
            Image(systemName: agent.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var toggleIndicator: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: agent.isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(agent.isEnabled ? Color.ds.positive : Color.ds.tertiary)

            Text(agent.isEnabled ? "Enabled" : "Disabled")
                .dsTextStyle(.caption, color: agent.isEnabled ? .ds.positive : .ds.tertiary)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(
            Capsule()
                .fill(agent.isEnabled ? Color.ds.positive.opacity(0.1) : Color.ds.foreground.opacity(0.05))
        )
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
            .stroke(
                agent.isEnabled ? agentColor.opacity(0.6) : Color.clear,
                lineWidth: 2
            )
    }
}

// MARK: - Agents Recommendations View

/// Onboarding step for configuring specialized agents.
public struct AgentsRecommendationsView: View {
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
            await viewModel.scanForAgents()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DSSpacing.sm) {
            Text("Meet the Agents")
                .dsTextStyle(.hero)

            Text("Specialized agents handle complex tasks autonomously")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.agentScanState {
        case .idle, .scanning:
            scanningView

        case .completed:
            if viewModel.detectedAgents.isEmpty {
                noAgentsView
            } else {
                VStack(spacing: DSSpacing.lg) {
                    agentGrid
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

            Text("Scanning for agents...")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .padding(.vertical, DSSpacing.xxl)
    }

    // MARK: - No Agents View

    private var noAgentsView: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.tertiary)

            VStack(spacing: DSSpacing.sm) {
                Text("No Agents Found")
                    .dsTextStyle(.subtitle, weight: .semibold)

                Text("Add agent definitions to ~/.claude/agents/ to see them here")
                    .dsTextStyle(.body, color: .ds.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Rescan") {
                Task {
                    await viewModel.scanForAgents()
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
                    await viewModel.scanForAgents()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, DSSpacing.xxl)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Agent Grid

    private var agentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(viewModel.detectedAgents) { agent in
                    DetectedAgentCard(
                        agent: agent,
                        onToggle: { viewModel.toggleAgent(id: agent.id) }
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
                viewModel.enableAllAgents()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.accent)

            Text("|")
                .foregroundStyle(Color.ds.tertiary)

            Button("Disable All") {
                viewModel.disableAllAgents()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.secondary)

            Text("|")
                .foregroundStyle(Color.ds.tertiary)

            Text("\(viewModel.enabledAgentCount) of \(viewModel.detectedAgents.count) enabled")
                .foregroundStyle(Color.ds.tertiary)
        }
        .dsTextStyle(.caption)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Agents Recommendations") {
    AgentsRecommendationsView()
        .environment(OnboardingViewModel())
        .frame(width: 700, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Detected Agent Card - Enabled") {
    DetectedAgentCard(
        agent: DetectedAgent(
            id: "kraken",
            name: "Kraken",
            description: "Implementation and refactoring agent using TDD workflow",
            icon: "hammer.fill",
            colorName: "purple",
            model: "opus",
            source: .global,
            isEnabled: true
        ),
        onToggle: {}
    )
    .frame(width: 200)
    .padding()
    .background(Color.ds.bg0)
}

#Preview("Detected Agent Card - Disabled") {
    DetectedAgentCard(
        agent: DetectedAgent(
            id: "scout",
            name: "Scout",
            description: "Codebase exploration and pattern finding",
            icon: "magnifyingglass",
            colorName: "blue",
            model: "sonnet",
            source: .global,
            isEnabled: false
        ),
        onToggle: {}
    )
    .frame(width: 200)
    .padding()
    .background(Color.ds.bg0)
}
#endif
