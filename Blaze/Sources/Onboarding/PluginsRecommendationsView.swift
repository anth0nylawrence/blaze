//
//  PluginsRecommendationsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - Plugin Model

/// Represents a recommended plugin with metadata.
private struct RecommendedPlugin: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let supportedCLIs: Set<String> // CLI IDs this plugin works with

    /// Whether this plugin works with all CLIs.
    var isUniversal: Bool {
        supportedCLIs.isEmpty || supportedCLIs.count >= 3
    }
}

// MARK: - Plugins Recommendations View

/// Onboarding step for recommending MCP plugins based on detected CLIs.
/// Displays a grid of plugin cards with selection checkboxes.
public struct PluginsRecommendationsView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    /// Hardcoded list of recommended plugins.
    private let plugins: [RecommendedPlugin] = [
        RecommendedPlugin(
            id: "web-search",
            name: "Web Search",
            description: "Search the web from Claude",
            icon: "globe",
            supportedCLIs: [] // All CLIs
        ),
        RecommendedPlugin(
            id: "github",
            name: "GitHub",
            description: "GitHub integration",
            icon: "chevron.left.forwardslash.chevron.right",
            supportedCLIs: [] // All CLIs
        ),
        RecommendedPlugin(
            id: "filesystem",
            name: "Filesystem",
            description: "Enhanced file operations",
            icon: "folder.fill",
            supportedCLIs: [] // All CLIs
        ),
        RecommendedPlugin(
            id: "memory",
            name: "Memory",
            description: "Persistent memory across sessions",
            icon: "brain.head.profile",
            supportedCLIs: ["claude"] // Claude only
        )
    ]

    public init() {}

    public var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: DSSpacing.xl) {
            // Header
            VStack(spacing: DSSpacing.sm) {
                Text("Recommended Plugins")
                    .dsTextStyle(.hero)

                Text("Plugins add tools and integrations to your workflow")
                    .dsTextStyle(.body, color: .ds.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, DSSpacing.lg)

            // Plugin grid
            VStack(spacing: DSSpacing.md) {
                LazyVGrid(columns: gridColumns, spacing: DSSpacing.md) {
                    ForEach(filteredPlugins) { plugin in
                        PluginCard(
                            plugin: plugin,
                            isSelected: vm.selectedPlugins.contains(plugin.id),
                            detectedCLIs: detectedCLINames(for: plugin)
                        ) {
                            togglePlugin(plugin.id)
                        }
                    }
                }
            }
            .frame(maxWidth: 600)

            Spacer()

            // Navigation buttons
            HStack(spacing: DSSpacing.md) {
                GlassButton("Back", icon: "chevron.left", style: .ghost, size: .medium) {
                    viewModel.goBack()
                }

                Spacer()

                GlassButton("Continue", icon: "arrow.right", style: .primary, size: .large) {
                    viewModel.goForward()
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.lg)
        }
        .padding(.horizontal, DSSpacing.xl)
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.ds.bg0)
    }

    // MARK: - Computed Properties

    /// Grid layout for plugin cards (3 columns).
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DSSpacing.md),
            GridItem(.flexible(), spacing: DSSpacing.md),
            GridItem(.flexible(), spacing: DSSpacing.md)
        ]
    }

    /// Detected CLI IDs.
    private var detectedCLIIds: Set<String> {
        Set(viewModel.detectedCLIs.filter { $0.isDetected }.map { $0.id })
    }

    /// Plugins filtered by detected CLIs.
    /// Shows plugins that work with at least one detected CLI.
    private var filteredPlugins: [RecommendedPlugin] {
        plugins.filter { plugin in
            // Universal plugins (empty supportedCLIs) always show
            if plugin.supportedCLIs.isEmpty {
                return true
            }
            // Show if any detected CLI is supported
            return !plugin.supportedCLIs.isDisjoint(with: detectedCLIIds)
        }
    }

    // MARK: - Helper Methods

    /// Returns display names of CLIs this plugin works with.
    private func detectedCLINames(for plugin: RecommendedPlugin) -> [String] {
        if plugin.supportedCLIs.isEmpty {
            return ["All CLIs"]
        }
        return viewModel.detectedCLIs
            .filter { plugin.supportedCLIs.contains($0.id) && $0.isDetected }
            .map { $0.name }
    }

    /// Toggles a plugin's selection state.
    private func togglePlugin(_ id: String) {
        if viewModel.selectedPlugins.contains(id) {
            viewModel.selectedPlugins.remove(id)
        } else {
            viewModel.selectedPlugins.insert(id)
        }
    }
}

// MARK: - Plugin Card

/// A card displaying a single plugin with selection checkbox.
private struct PluginCard: View {
    let plugin: RecommendedPlugin
    let isSelected: Bool
    let detectedCLIs: [String]
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.sm) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.ds.surface)
                        .frame(width: DSSize.xxl, height: DSSize.xxl)

                    Image(systemName: plugin.icon)
                        .font(.system(size: DSSize.md))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.ds.secondary)
                }

                // Name
                Text(plugin.name)
                    .dsTextStyle(.subtitle, color: isSelected ? .ds.foreground : .ds.secondary)
                    .lineLimit(1)

                // Description
                Text(plugin.description)
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 30) // Consistent height for 2 lines

                // CLI compatibility badge
                if !detectedCLIs.isEmpty {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text(detectedCLIs.first ?? "")
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.positive)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.ds.positive.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .padding(.horizontal, DSSpacing.sm)
            .dsGlassPanel(
                level: isSelected ? .regular : .subtle,
                cornerRadius: DSRadius.lg,
                elevation: isSelected ? .medium : (isHovered ? .low : .none),
                border: isSelected ? .layered : .subtle,
                isInteractive: true
            )
            .overlay(alignment: .topTrailing) {
                // Selection checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.ds.tertiary)
                    .padding(DSSpacing.xs)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Plugins Recommendations View") {
    PluginsRecommendationsView()
        .environment(OnboardingViewModel())
        .frame(width: 700, height: 600)
}
#endif
