//
//  PluginsSelectionView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - Plugin Category

/// Categories for filtering registry plugins.
public enum PluginCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case integrations = "Integrations"
    case productivity = "Productivity"
    case devtools = "Dev Tools"
    case data = "Data"
    case ai = "AI"
    case other = "Other"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .integrations: return "link"
        case .productivity: return "bolt.fill"
        case .devtools: return "hammer.fill"
        case .data: return "cylinder.fill"
        case .ai: return "brain.head.profile"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Plugins Selection View

/// Registry plugins selection view for onboarding.
/// Displays plugins grouped by CLI in a searchable, filterable grid.
public struct PluginsSelectionView: View {
    // MARK: - State

    @State private var searchText: String = ""
    @State private var selectedCategory: PluginCategory = .all
    @Binding var selectedPlugins: Set<String>

    /// Available plugins from registry (passed in or fetched)
    let plugins: [PluginItem]

    /// Set of installed plugin IDs
    let installedPluginIds: Set<String>

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

    // MARK: - CLI Display Order

    private let cliDisplayOrder = ["claude", "gemini", "codex"]

    // MARK: - Init

    public init(
        plugins: [PluginItem],
        selectedPlugins: Binding<Set<String>>,
        installedPluginIds: Set<String> = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.plugins = plugins
        self._selectedPlugins = selectedPlugins
        self.installedPluginIds = installedPluginIds
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
            Text("Community Plugins")
                .dsTextStyle(.hero)

            Text("Extend your CLI with community plugins. Select the ones you'd like to install.")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: DSSpacing.md) {
            // Search field
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.ds.secondary)
                    .font(.system(size: DSSize.sm))

                TextField("Search plugins...", text: $searchText)
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

            // Category filter chips
            categoryChips

            Spacer()

            // Selection count
            if !selectedPlugins.isEmpty {
                Text("\(selectedPlugins.count) selected")
                    .dsTextStyle(.caption, color: .ds.accent)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(Color.ds.accent.opacity(0.1))
                    .cornerRadius(DSRadius.sm)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.xs) {
                ForEach(PluginCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: 400)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(message: error)
        } else if filteredPlugins.isEmpty {
            emptyStateView
        } else {
            pluginsGridView
        }
    }

    private var loadingView: some View {
        VStack(spacing: DSSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading community plugins...")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.warning)

            Text("Failed to load plugins")
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.secondary)

            Text("No plugins found")
                .dsTextStyle(.subtitle)

            if !searchText.isEmpty || selectedCategory != .all {
                Text("Try adjusting your search or filters")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Button("Clear filters") {
                    searchText = ""
                    selectedCategory = .all
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.accent)
                .padding(.top, DSSpacing.xs)
            } else {
                Text("No community plugins available yet.")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
    }

    private var pluginsGridView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.xl) {
                ForEach(sortedCLIs, id: \.self) { cli in
                    if let pluginsForCLI = pluginsGroupedByCLI[cli], !pluginsForCLI.isEmpty {
                        cliSection(cli: cli, plugins: pluginsForCLI)
                    }
                }
            }
            .padding(.vertical, DSSpacing.md)
        }
    }

    // MARK: - CLI Section

    private func cliSection(cli: String, plugins: [PluginItem]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Section header
            HStack(spacing: DSSpacing.sm) {
                CLISectionIcon(cli: cli)

                Text(cliDisplayName(cli))
                    .dsTextStyle(.subtitle, weight: .semibold)

                Text("(\(plugins.count))")
                    .dsTextStyle(.caption, color: .ds.tertiary)

                Spacer()
            }

            // Plugin cards grid
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(plugins) { plugin in
                    PluginCard(
                        plugin: plugin,
                        isSelected: selectedPlugins.contains(plugin.id),
                        isInstalled: installedPluginIds.contains(plugin.id),
                        onToggle: { togglePlugin(plugin.id) }
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredPlugins: [PluginItem] {
        plugins.filter { plugin in
            // Category filter
            let categoryMatch = selectedCategory == .all ||
                plugin.category.lowercased() == selectedCategory.rawValue.lowercased()

            // Search filter
            let searchMatch = searchText.isEmpty ||
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.description.localizedCaseInsensitiveContains(searchText) ||
                plugin.author.localizedCaseInsensitiveContains(searchText)

            return categoryMatch && searchMatch
        }
    }

    private var pluginsGroupedByCLI: [String: [PluginItem]] {
        Dictionary(grouping: filteredPlugins, by: { $0.forCLI.lowercased() })
    }

    private var sortedCLIs: [String] {
        let allCLIs = Set(filteredPlugins.map { $0.forCLI.lowercased() })
        var sorted = cliDisplayOrder.filter { allCLIs.contains($0) }
        let remaining = allCLIs.subtracting(Set(sorted)).sorted()
        sorted.append(contentsOf: remaining)
        return sorted
    }

    // MARK: - Helper Methods

    private func cliDisplayName(_ cli: String) -> String {
        switch cli.lowercased() {
        case "claude": return "Claude Code"
        case "gemini": return "Gemini CLI"
        case "codex": return "Codex CLI"
        default: return cli.capitalized
        }
    }

    // MARK: - Actions

    private func togglePlugin(_ pluginId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedPlugins.contains(pluginId) {
                selectedPlugins.remove(pluginId)
            } else {
                selectedPlugins.insert(pluginId)
            }
        }
    }
}

// MARK: - Category Chip

/// A selectable chip for category filtering.
private struct CategoryChip: View {
    let category: PluginCategory
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: category.icon)
                    .font(.system(size: 10))
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.secondary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                isSelected
                    ? Color.ds.accent.opacity(0.15)
                    : (isHovered ? Color.ds.surface : Color.clear)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.ds.accent.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - CLI Section Icon

/// Icon for CLI section headers.
private struct CLISectionIcon: View {
    let cli: String

    var body: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.12))
                .frame(width: 28, height: 28)

            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        switch cli.lowercased() {
        case "claude": return "c.circle.fill"
        case "gemini": return "g.circle.fill"
        case "codex": return "o.circle.fill"
        default: return "terminal.fill"
        }
    }

    private var iconColor: Color {
        switch cli.lowercased() {
        case "claude": return Color.ds.accent
        case "gemini": return Color.blue
        case "codex": return Color.green
        default: return Color.ds.secondary
        }
    }
}

// MARK: - Plugin Card

/// A card displaying a registry plugin with selection and installation status.
private struct PluginCard: View {
    let plugin: PluginItem
    let isSelected: Bool
    let isInstalled: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Header row: name + status badges
                HStack {
                    Text(plugin.name)
                        .dsTextStyle(.subtitle, weight: .semibold)
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }

                // Description (truncated)
                Text(plugin.description)
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .top)

                // Author
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text(plugin.author)
                        .lineLimit(1)
                }
                .dsTextStyle(.caption, color: .ds.tertiary)

                // Selection checkbox row
                HStack {
                    // Category badge
                    Text(plugin.category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.ds.secondary)
                        .padding(.horizontal, DSSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.ds.surface)
                        .clipShape(Capsule())

                    Spacer()

                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: DSSize.md))
                        .foregroundStyle(isSelected ? Color.ds.positive : Color.ds.tertiary)
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
        .accessibilityLabel("\(plugin.name) by \(plugin.author)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isInstalled {
            HStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                Text("Installed")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Color.ds.positive)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, 2)
            .background(Color.ds.positive.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Plugins Selection - With Data") {
    @Previewable @State var selected: Set<String> = ["web-search", "github"]

    PluginsSelectionView(
        plugins: [
            PluginItem(
                id: "web-search",
                name: "Web Search",
                description: "Search the web directly from your CLI for documentation, examples, and solutions.",
                author: "anthropic",
                version: "1.0.0",
                category: "Integrations",
                forCLI: "claude",
                permissions: .none
            ),
            PluginItem(
                id: "github",
                name: "GitHub Integration",
                description: "Create PRs, manage issues, and navigate repositories without leaving your editor.",
                author: "community",
                version: "2.1.0",
                category: "Integrations",
                forCLI: "claude",
                permissions: RegistryPermissions(tools: [], fileAccess: true, networkAccess: true)
            ),
            PluginItem(
                id: "memory",
                name: "Persistent Memory",
                description: "Remember context across sessions for a more personalized experience.",
                author: "anthropic",
                version: "0.9.0",
                category: "AI",
                forCLI: "claude",
                permissions: .none
            ),
            PluginItem(
                id: "gemini-search",
                name: "Gemini Search",
                description: "Enhanced search capabilities powered by Gemini.",
                author: "google",
                version: "1.0.0",
                category: "Integrations",
                forCLI: "gemini",
                permissions: .none
            ),
            PluginItem(
                id: "codex-lint",
                name: "Code Linter",
                description: "Real-time code linting and formatting suggestions.",
                author: "openai",
                version: "1.5.0",
                category: "Dev Tools",
                forCLI: "codex",
                permissions: .none
            )
        ],
        selectedPlugins: $selected,
        installedPluginIds: ["memory"]
    )
    .frame(width: 900, height: 800)
    .background(Color.ds.bg0)
}

#Preview("Plugins Selection - Loading") {
    @Previewable @State var selected: Set<String> = []

    PluginsSelectionView(
        plugins: [],
        selectedPlugins: $selected,
        isLoading: true
    )
    .frame(width: 900, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Plugins Selection - Error") {
    @Previewable @State var selected: Set<String> = []

    PluginsSelectionView(
        plugins: [],
        selectedPlugins: $selected,
        errorMessage: "Unable to connect to the registry. Please check your network connection.",
        onRetry: { print("Retry tapped") }
    )
    .frame(width: 900, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Plugins Selection - Empty") {
    @Previewable @State var selected: Set<String> = []

    PluginsSelectionView(
        plugins: [],
        selectedPlugins: $selected
    )
    .frame(width: 900, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Plugins Selection - Dark") {
    @Previewable @State var selected: Set<String> = ["web-search"]

    PluginsSelectionView(
        plugins: [
            PluginItem(
                id: "web-search",
                name: "Web Search",
                description: "Search the web directly from your CLI.",
                author: "anthropic",
                version: "1.0.0",
                category: "Integrations",
                forCLI: "claude",
                permissions: .none
            )
        ],
        selectedPlugins: $selected
    )
    .frame(width: 900, height: 700)
    .background(Color.ds.bg0)
    .environment(\.colorScheme, .dark)
}
#endif
