//
//  AgentsSelectionView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - Agent Use Case Filter

/// Filter categories for agents in selection view.
/// A subset of AgentUseCase plus "All" for unfiltered browsing.
public enum AgentUseCaseFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case planning = "Planning"
    case debugging = "Debugging"
    case security = "Security"
    case research = "Research"
    case workflow = "Workflow"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .planning: return "map.fill"
        case .debugging: return "ant.fill"
        case .security: return "lock.shield.fill"
        case .research: return "magnifyingglass"
        case .workflow: return "flowchart.fill"
        }
    }

    /// Maps to the underlying AgentUseCase enum value.
    var matchingUseCases: [AgentUseCase] {
        switch self {
        case .all: return AgentUseCase.allCases
        case .planning: return [.planning]
        case .debugging: return [.debugging]
        case .security: return [.security]
        case .research: return [.research]
        case .workflow: return [.refactoring, .testing, .documentation, .other]
        }
    }
}

// MARK: - Agents Selection View

/// Registry agents selection view for onboarding.
/// Displays agents in a searchable, filterable grid with use case badges.
public struct AgentsSelectionView: View {
    // MARK: - State

    @State private var searchText: String = ""
    @State private var selectedUseCase: AgentUseCaseFilter = .all
    @Binding var selectedAgents: Set<String>

    /// Available agents from registry
    let agents: [AgentItem]

    /// Loading state
    let isLoading: Bool

    /// Error message if fetch failed
    let errorMessage: String?

    /// Retry action for error state
    let onRetry: (() -> Void)?

    // MARK: - Layout

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 350), spacing: DSSpacing.md)
    ]

    // MARK: - Init

    public init(
        agents: [AgentItem],
        selectedAgents: Binding<Set<String>>,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.agents = agents
        self._selectedAgents = selectedAgents
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Header
            headerView
                .onboardingFadeIn(delay: 0)

            // Search and filter bar
            filterBar
                .onboardingFadeIn(delay: OnboardingAnimation.staggerDelay)

            // Content area
            contentView
                .onboardingFadeIn(delay: OnboardingAnimation.staggerDelay * 2)

            Spacer()
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: DSSpacing.sm) {
            Text("Community Agents")
                .dsTextStyle(.hero)

            Text("Extend your workflow with specialized AI agents. Select the ones you'd like to install.")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: DSSpacing.md) {
            // Use case chip bar
            useCaseChipBar

            HStack(spacing: DSSpacing.md) {
                // Search field
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.ds.secondary)
                        .font(.system(size: DSSize.sm))

                    TextField("Search agents...", text: $searchText)
                        .textFieldStyle(.plain)
                        .dsTextStyle(.body)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.ds.tertiary)
                                .font(.system(size: DSSize.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(Color.ds.surface)
                .cornerRadius(DSRadius.md)
                .frame(maxWidth: 300)

                Spacer()

                // Selection count
                if !selectedAgents.isEmpty {
                    Text("\(selectedAgents.count) selected")
                        .dsTextStyle(.caption, color: .ds.accent)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(Color.ds.accent.opacity(0.1))
                        .cornerRadius(DSRadius.sm)
                }
            }
        }
        .padding(.horizontal, DSSpacing.sm)
    }

    // MARK: - Use Case Chip Bar

    private var useCaseChipBar: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(AgentUseCaseFilter.allCases) { useCase in
                UseCaseChip(
                    useCase: useCase,
                    isSelected: selectedUseCase == useCase,
                    onTap: { selectedUseCase = useCase }
                )
            }
            Spacer()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(message: error)
        } else if filteredAgents.isEmpty {
            emptyStateView
        } else {
            agentsGridView
        }
    }

    private var loadingView: some View {
        VStack(spacing: DSSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading community agents...")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.warning)

            Text("Failed to load agents")
                .dsTextStyle(.subtitle)

            Text(message)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if let retry = onRetry {
                GlassButton("Retry", icon: "arrow.clockwise", style: .secondary, size: .medium) {
                    retry()
                }
                .padding(.top, DSSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
    }

    private var emptyStateView: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.secondary)

            Text("No agents found")
                .dsTextStyle(.subtitle)

            if !searchText.isEmpty || selectedUseCase != .all {
                Text("Try adjusting your search or filters")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Button("Clear filters") {
                    searchText = ""
                    selectedUseCase = .all
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.accent)
                .padding(.top, DSSpacing.xs)
            } else {
                Text("No community agents available yet.")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
    }

    private var agentsGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(filteredAgents) { agent in
                    AgentCard(
                        agent: agent,
                        isSelected: selectedAgents.contains(agent.id),
                        onToggle: { toggleAgent(agent.id) }
                    )
                }
            }
            .padding(.vertical, DSSpacing.md)
        }
    }

    // MARK: - Computed Properties

    private var filteredAgents: [AgentItem] {
        agents.filter { agent in
            // Use case filter
            let useCaseMatch = selectedUseCase.matchingUseCases.contains(agent.useCase)

            // Search filter
            let searchMatch = searchText.isEmpty ||
                agent.name.localizedCaseInsensitiveContains(searchText) ||
                agent.description.localizedCaseInsensitiveContains(searchText) ||
                agent.author.localizedCaseInsensitiveContains(searchText)

            return useCaseMatch && searchMatch
        }
    }

    // MARK: - Actions

    private func toggleAgent(_ agentId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedAgents.contains(agentId) {
                selectedAgents.remove(agentId)
            } else {
                selectedAgents.insert(agentId)
            }
        }
    }
}

// MARK: - Use Case Chip

/// A chip button for filtering agents by use case.
private struct UseCaseChip: View {
    let useCase: AgentUseCaseFilter
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: useCase.icon)
                    .font(.system(size: 11))
                Text(useCase.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.ds.bg0 : Color.ds.foreground)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                isSelected
                    ? Color.ds.accent
                    : (isHovered ? Color.ds.surface : Color.ds.surface.opacity(0.6))
            )
            .cornerRadius(DSRadius.full)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Agent Card

/// A card displaying a registry agent with use case badge.
private struct AgentCard: View {
    let agent: AgentItem
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Header row: name + checkbox
                HStack {
                    Text(agent.name)
                        .dsTextStyle(.subtitle, weight: .semibold)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: DSSize.md))
                        .foregroundStyle(isSelected ? Color.ds.positive : Color.ds.tertiary)
                }

                // Description (truncated)
                Text(agent.description)
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .top)

                // Author
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text(agent.author)
                        .lineLimit(1)
                }
                .dsTextStyle(.caption, color: .ds.tertiary)

                // Use case badge
                HStack(spacing: DSSpacing.xs) {
                    UseCaseBadge(useCase: agent.useCase)
                    Spacer()
                }
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlassPanel(
                level: isSelected ? .regular : .subtle,
                cornerRadius: DSRadius.lg,
                elevation: isSelected ? .medium : (isHovered ? .low : .none),
                border: isSelected ? .layered : .subtle,
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(agent.name) by \(agent.author)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
    }
}

// MARK: - Use Case Badge

/// A badge showing the agent's use case.
private struct UseCaseBadge: View {
    let useCase: AgentUseCase

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(displayName)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var displayName: String {
        switch useCase {
        case .planning: return "Planning"
        case .debugging: return "Debugging"
        case .security: return "Security"
        case .research: return "Research"
        case .refactoring: return "Refactoring"
        case .testing: return "Testing"
        case .documentation: return "Documentation"
        case .other: return "Workflow"
        }
    }

    private var icon: String {
        switch useCase {
        case .planning: return "map.fill"
        case .debugging: return "ant.fill"
        case .security: return "lock.shield.fill"
        case .research: return "magnifyingglass"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .testing: return "checkmark.seal.fill"
        case .documentation: return "doc.text.fill"
        case .other: return "flowchart.fill"
        }
    }

    private var badgeColor: Color {
        switch useCase {
        case .planning: return Color.purple
        case .debugging: return Color.orange
        case .security: return Color.red
        case .research: return Color.blue
        case .refactoring: return Color.teal
        case .testing: return Color.green
        case .documentation: return Color.indigo
        case .other: return Color.ds.secondary
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Agents Selection - With Data") {
    @Previewable @State var selected: Set<String> = ["architect", "debugger"]

    AgentsSelectionView(
        agents: [
            AgentItem(
                id: "architect",
                name: "System Architect",
                description: "Analyzes codebases and designs scalable system architectures with best practices.",
                author: "cogit0",
                version: "1.0.0",
                category: "Development",
                useCase: .planning,
                permissions: .none
            ),
            AgentItem(
                id: "debugger",
                name: "Bug Hunter",
                description: "Systematic debugging agent that traces issues through logs, stack traces, and code paths.",
                author: "devtools",
                version: "2.1.0",
                category: "Development",
                useCase: .debugging,
                permissions: .none
            ),
            AgentItem(
                id: "sec-audit",
                name: "Security Auditor",
                description: "Performs comprehensive security audits including OWASP checks and dependency scanning.",
                author: "secteam",
                version: "1.5.0",
                category: "Security",
                useCase: .security,
                permissions: .none
            ),
            AgentItem(
                id: "researcher",
                name: "Code Researcher",
                description: "Deep dives into unfamiliar codebases to understand patterns and document findings.",
                author: "community",
                version: "1.0.0",
                category: "Analysis",
                useCase: .research,
                permissions: .none
            )
        ],
        selectedAgents: $selected
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Agents Selection - Loading") {
    @Previewable @State var selected: Set<String> = []

    AgentsSelectionView(
        agents: [],
        selectedAgents: $selected,
        isLoading: true
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Agents Selection - Error") {
    @Previewable @State var selected: Set<String> = []

    AgentsSelectionView(
        agents: [],
        selectedAgents: $selected,
        errorMessage: "Unable to connect to the registry. Please check your network connection.",
        onRetry: { print("Retry tapped") }
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Agents Selection - Empty") {
    @Previewable @State var selected: Set<String> = []

    AgentsSelectionView(
        agents: [],
        selectedAgents: $selected
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Agents Selection - Dark") {
    @Previewable @State var selected: Set<String> = ["architect"]

    AgentsSelectionView(
        agents: [
            AgentItem(
                id: "architect",
                name: "System Architect",
                description: "Analyzes codebases and designs scalable system architectures.",
                author: "cogit0",
                version: "1.0.0",
                category: "Development",
                useCase: .planning,
                permissions: .none
            )
        ],
        selectedAgents: $selected
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
    .environment(\.colorScheme, .dark)
}
#endif
