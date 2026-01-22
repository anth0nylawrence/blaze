import SwiftUI

// MARK: - Environment Reference Panel View

/// A panel displaying available hook environment variables grouped by category.
///
/// Provides a searchable, collapsible reference for all environment variables
/// that hooks can access during execution. Features:
/// - Variables grouped by category (Claude, System, Blaze, Custom)
/// - Current value display with set/unset indicators
/// - Copy to clipboard and insert into editor actions
/// - Search/filter by name or description
///
/// **E005-F009-S002-T004-A001**
public struct EnvironmentReferencePanelView: View {
    // MARK: - Properties

    /// Callback when user wants to insert a variable into the script editor
    var onInsertVariable: ((HookEnvironmentVariable) -> Void)?

    // MARK: - State

    @State private var searchText: String = ""
    @State private var expandedCategories: Set<HookEnvironmentCategory> = Set(HookEnvironmentCategory.allCases)

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            searchSection
            Divider()
            variablesScrollView
        }
        .background(Color.ds.bg1)
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.ds.accent)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Environment Variables")
                    .font(.headline)
                    .foregroundStyle(Color.ds.foreground)

                Text("Available to hooks during execution")
                    .font(.caption)
                    .foregroundStyle(Color.ds.secondary)
            }

            Spacer()

            // Expand/Collapse all button
            Button {
                if expandedCategories.count == HookEnvironmentCategory.allCases.count {
                    expandedCategories.removeAll()
                } else {
                    expandedCategories = Set(HookEnvironmentCategory.allCases)
                }
            } label: {
                Image(systemName: expandedCategories.count == HookEnvironmentCategory.allCases.count
                    ? "rectangle.compress.vertical"
                    : "rectangle.expand.vertical")
            }
            .buttonStyle(.borderless)
            .help(expandedCategories.count == HookEnvironmentCategory.allCases.count
                ? "Collapse all sections"
                : "Expand all sections")
        }
        .padding(DSSpacing.md)
    }

    // MARK: - Search Section

    @ViewBuilder
    private var searchSection: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.ds.secondary)

            TextField("Filter variables...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(DSSpacing.sm)
        .background(Color.ds.surface)
    }

    // MARK: - Variables Scroll View

    @ViewBuilder
    private var variablesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: DSSpacing.sm, pinnedViews: [.sectionHeaders]) {
                ForEach(HookEnvironmentCategory.allCases) { category in
                    let variables = filteredVariables(for: category)
                    if !variables.isEmpty {
                        categorySection(category: category, variables: variables)
                    }
                }

                // Show empty state if no results
                if filteredVariables.isEmpty {
                    emptySearchState
                }
            }
            .padding(DSSpacing.sm)
        }
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(
        category: HookEnvironmentCategory,
        variables: [HookEnvironmentVariable]
    ) -> some View {
        Section {
            if expandedCategories.contains(category) {
                ForEach(variables) { variable in
                    EnvironmentVariableRow(
                        variable: variable,
                        onCopy: { copyToClipboard(variable) },
                        onInsert: onInsertVariable != nil
                            ? { onInsertVariable?(variable) }
                            : nil
                    )
                }
            }
        } header: {
            CategoryHeaderView(
                category: category,
                variableCount: variables.count,
                isExpanded: expandedCategories.contains(category),
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                }
            )
        }
    }

    // MARK: - Empty Search State

    @ViewBuilder
    private var emptySearchState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Color.ds.tertiary)

            Text("No variables found")
                .font(.headline)
                .foregroundStyle(Color.ds.secondary)

            Text("Try a different search term")
                .font(.caption)
                .foregroundStyle(Color.ds.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xl)
    }

    // MARK: - Filtering

    private var filteredVariables: [HookEnvironmentVariable] {
        let allVars = HookEnvironment.allVariables
        if searchText.isEmpty {
            return allVars
        }
        let query = searchText.lowercased()
        return allVars.filter { variable in
            variable.name.lowercased().contains(query) ||
            variable.description.lowercased().contains(query)
        }
    }

    private func filteredVariables(for category: HookEnvironmentCategory) -> [HookEnvironmentVariable] {
        let categoryVars = HookEnvironment.variables(for: category)
        if searchText.isEmpty {
            return categoryVars
        }
        let query = searchText.lowercased()
        return categoryVars.filter { variable in
            variable.name.lowercased().contains(query) ||
            variable.description.lowercased().contains(query)
        }
    }

    // MARK: - Actions

    private func copyToClipboard(_ variable: HookEnvironmentVariable) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(variable.shellReference, forType: .string)
    }
}

// MARK: - Category Header View

/// Header for a collapsible category section
private struct CategoryHeaderView: View {
    let category: HookEnvironmentCategory
    let variableCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DSSpacing.sm) {
                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.ds.secondary)
                    .frame(width: 12)

                // Category icon
                Image(systemName: category.icon)
                    .font(.subheadline)
                    .foregroundStyle(categoryColor)

                // Category name
                Text(category.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ds.foreground)

                // Variable count badge
                Text("\(variableCount)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.15))
                    .foregroundStyle(categoryColor)
                    .cornerRadius(DSRadius.full)

                Spacer()

                // Category description (collapsed)
                if !isExpanded {
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(Color.ds.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, DSSpacing.sm)
            .padding(.horizontal, DSSpacing.xs)
            .background(Color.ds.bg1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch category {
        case .claude: return Color.ds.accent
        case .system: return Color.ds.info
        case .blaze: return Color.orange
        case .custom: return Color.purple
        }
    }
}

// MARK: - Environment Variable Row

/// Row displaying a single environment variable with its details and actions
private struct EnvironmentVariableRow: View {
    let variable: HookEnvironmentVariable
    let onCopy: () -> Void
    let onInsert: (() -> Void)?

    @State private var isHovering = false
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Header row: name + status + actions
            HStack(alignment: .center, spacing: DSSpacing.sm) {
                // Variable name
                Text(variable.shellReference)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(Color.ds.accent)

                // Required badge
                if variable.isRequired {
                    Text("Required")
                        .font(.caption2)
                        .padding(.horizontal, DSSpacing.xxs)
                        .padding(.vertical, 2)
                        .background(Color.ds.warning.opacity(0.15))
                        .foregroundStyle(Color.ds.warning)
                        .cornerRadius(DSRadius.sm)
                }

                Spacer()

                // Action buttons (visible on hover or always if touch)
                HStack(spacing: DSSpacing.xxs) {
                    // Copy button
                    Button {
                        onCopy()
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedFeedback = false
                        }
                    } label: {
                        if showCopiedFeedback {
                            Label("Copied", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundStyle(Color.ds.positive)
                        } else {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .help("Copy to clipboard")

                    // Insert button (only shown if callback provided)
                    if let onInsert = onInsert {
                        Button {
                            onInsert()
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Insert into script")
                    }
                }
                .opacity(isHovering ? 1 : 0.6)
            }

            // Description
            Text(variable.description)
                .font(.caption)
                .foregroundStyle(Color.ds.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Current value row
            HStack(spacing: DSSpacing.xs) {
                // Value indicator
                if let currentValue = variable.getCurrentValue() {
                    // Value is set
                    HStack(spacing: DSSpacing.xxs) {
                        Circle()
                            .fill(Color.ds.positive)
                            .frame(width: 6, height: 6)
                        Text("Set:")
                            .font(.caption2)
                            .foregroundStyle(Color.ds.positive)
                    }

                    // Truncated value
                    Text(truncatedValue(currentValue))
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.ds.foreground.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let defaultValue = variable.defaultValue {
                    // Has default
                    HStack(spacing: DSSpacing.xxs) {
                        Circle()
                            .fill(Color.ds.warning)
                            .frame(width: 6, height: 6)
                        Text("Default:")
                            .font(.caption2)
                            .foregroundStyle(Color.ds.warning)
                    }

                    Text(defaultValue)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.ds.foreground.opacity(0.7))
                        .lineLimit(1)
                } else {
                    // Not set
                    HStack(spacing: DSSpacing.xxs) {
                        Circle()
                            .fill(Color.ds.tertiary)
                            .frame(width: 6, height: 6)
                        Text("Not set")
                            .font(.caption2)
                            .foregroundStyle(Color.ds.tertiary)
                    }
                }

                Spacer()
            }

            // Example row
            HStack(spacing: DSSpacing.xxs) {
                Text("Example:")
                    .font(.caption2)
                    .foregroundStyle(Color.ds.tertiary)

                Text(variable.example)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.ds.secondary)
                    .lineLimit(1)
            }
        }
        .padding(DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(Color.ds.surface.opacity(isHovering ? 0.8 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.ds.borderSubtle, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    /// Truncates long values for display (e.g., PATH)
    private func truncatedValue(_ value: String) -> String {
        if value.count > 60 {
            return String(value.prefix(57)) + "..."
        }
        return value
    }
}

// MARK: - Compact Environment Reference Panel

/// A more compact version suitable for sidebars and narrow panels.
///
/// Shows variables in a condensed format with quick-copy functionality.
public struct CompactEnvironmentReferencePanelView: View {
    /// Callback when user wants to insert a variable
    var onInsertVariable: ((HookEnvironmentVariable) -> Void)?

    @State private var searchText: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundStyle(Color.ds.accent)
                Text("Environment Variables")
                    .font(.caption.bold())
                Spacer()
            }
            .padding(DSSpacing.sm)
            .background(Color.ds.bg1)

            Divider()

            // Search
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(Color.ds.tertiary)
                TextField("Search...", text: $searchText)
                    .font(.caption)
                    .textFieldStyle(.plain)
            }
            .padding(DSSpacing.xs)
            .background(Color.ds.surface)

            Divider()

            // Variables list
            ScrollView {
                LazyVStack(spacing: DSSpacing.xxs) {
                    ForEach(filteredVariables) { variable in
                        CompactVariableRow(
                            variable: variable,
                            onInsert: onInsertVariable
                        )
                    }
                }
                .padding(DSSpacing.xs)
            }
        }
        .background(Color.ds.bg1)
    }

    private var filteredVariables: [HookEnvironmentVariable] {
        if searchText.isEmpty {
            return HookEnvironment.allVariables
        }
        let query = searchText.lowercased()
        return HookEnvironment.allVariables.filter { variable in
            variable.name.lowercased().contains(query) ||
            variable.description.lowercased().contains(query)
        }
    }
}

// MARK: - Compact Variable Row

private struct CompactVariableRow: View {
    let variable: HookEnvironmentVariable
    let onInsert: ((HookEnvironmentVariable) -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)

            // Variable name
            Text(variable.name)
                .font(.caption.monospaced())
                .foregroundStyle(Color.ds.foreground)
                .lineLimit(1)

            Spacer()

            // Actions on hover
            if isHovering {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(variable.shellReference, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                if let onInsert = onInsert {
                    Button {
                        onInsert(variable)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, DSSpacing.xxs)
        .padding(.horizontal, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .fill(isHovering ? Color.ds.surface : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .help(variable.description)
    }

    private var statusColor: Color {
        if variable.getCurrentValue() != nil {
            return Color.ds.positive
        } else if variable.defaultValue != nil {
            return Color.ds.warning
        }
        return Color.ds.tertiary
    }
}

// MARK: - Previews

#if DEBUG
struct EnvironmentReferencePanelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EnvironmentReferencePanelView { variable in
                print("Insert: \(variable.name)")
            }
            .frame(width: 400, height: 600)
            .previewDisplayName("Environment Reference Panel")

            EnvironmentReferencePanelView()
                .frame(width: 400, height: 600)
                .previewDisplayName("No Insert Callback")

            CompactEnvironmentReferencePanelView { variable in
                print("Insert: \(variable.name)")
            }
            .frame(width: 280, height: 400)
            .previewDisplayName("Compact Panel")
        }
    }
}
#endif
