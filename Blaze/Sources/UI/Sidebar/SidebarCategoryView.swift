import SwiftUI

// MARK: - Sidebar Category View

/// Collapsible category header with its tabs
struct SidebarCategoryView: View {
    let category: SidebarCategory
    let isExpanded: Bool
    @Binding var selectedTab: SidebarTab
    let onToggle: () -> Void

    @State private var isHeaderHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            categoryHeader

            // Tabs (when expanded)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(category.tabs) { tab in
                        SidebarTabRow(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            onSelect: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedTab = tab
                                }
                            }
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        Button(action: onToggle) {
            HStack(spacing: DSSpacing.xs) {
                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.ds.tertiary)
                    .frame(width: 12)

                // Category icon
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ds.secondary)

                // Category name
                Text(category.rawValue)
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Tab count badge
                Text("\(category.tabs.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.ds.surface.opacity(0.3))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                isHeaderHovered
                    ? Color.ds.surface.opacity(0.3)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .onHover { isHeaderHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHeaderHovered)
    }
}

// MARK: - Sidebar Tab Row

/// Individual tab row within a category
struct SidebarTabRow: View {
    let tab: SidebarTab
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DSSpacing.sm) {
                // Selection indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.ds.accent : Color.clear)
                    .frame(width: 3, height: 16)

                // Tab icon
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.ds.accent : Color.ds.secondary)
                    .frame(width: 16)

                // Tab name
                Text(tab.rawValue)
                    .dsTextStyle(.body, color: isSelected ? .ds.foreground : .ds.secondary)

                Spacer()

                // Keyboard shortcut hint
                if let shortcut = tab.shortcutNumber {
                    Text("\(shortcut)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 14)
                        .opacity(isHovered ? 1 : 0)
                }
            }
            .padding(.leading, DSSpacing.lg) // Indent under category header
            .padding(.trailing, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                Group {
                    if isSelected {
                        Color.ds.accent.opacity(0.1)
                    } else if isHovered {
                        Color.ds.surface.opacity(0.3)
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Compact Category Header

/// Minimal category header for collapsed sidebar view
struct CompactCategoryHeader: View {
    let category: SidebarCategory
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.ds.tertiary)

                Text(category.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.ds.tertiary)
                    .tracking(0.5)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Sidebar Category - Expanded") {
    struct PreviewWrapper: View {
        @State private var selectedTab: SidebarTab = .timeline

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                SidebarCategoryView(
                    category: .activity,
                    isExpanded: true,
                    selectedTab: $selectedTab,
                    onToggle: {}
                )

                SidebarCategoryView(
                    category: .filesCode,
                    isExpanded: true,
                    selectedTab: $selectedTab,
                    onToggle: {}
                )
            }
            .frame(width: 280)
            .background(Color.ds.bg0)
        }
    }

    return PreviewWrapper()
}

#Preview("Sidebar Category - Collapsed") {
    struct PreviewWrapper: View {
        @State private var selectedTab: SidebarTab = .timeline

        var body: some View {
            SidebarCategoryView(
                category: .activity,
                isExpanded: false,
                selectedTab: $selectedTab,
                onToggle: {}
            )
            .frame(width: 280)
            .background(Color.ds.bg0)
        }
    }

    return PreviewWrapper()
}

#Preview("Tab Row States") {
    VStack(spacing: 0) {
        // Selected
        SidebarTabRow(
            tab: .timeline,
            isSelected: true,
            onSelect: {}
        )

        // Unselected
        SidebarTabRow(
            tab: .tools,
            isSelected: false,
            onSelect: {}
        )

        // Another unselected
        SidebarTabRow(
            tab: .tasks,
            isSelected: false,
            onSelect: {}
        )
    }
    .frame(width: 280)
    .background(Color.ds.bg0)
}
