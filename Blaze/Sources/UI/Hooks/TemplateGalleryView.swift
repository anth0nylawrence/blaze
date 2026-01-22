import SwiftUI

// MARK: - Template Gallery View

/// A gallery view for browsing and selecting hook templates.
/// Displays templates in a responsive grid with category filtering and search.
///
/// **Atom:** E005-F009-S002-T002-A001
public struct TemplateGalleryView: View {
    /// Callback when a template is selected for use.
    let onSelectTemplate: (HookTemplate) -> Void

    /// Optional callback to dismiss the gallery.
    let onDismiss: (() -> Void)?

    @State private var searchText: String = ""
    @State private var selectedCategory: HookTemplateCategory?
    @State private var hoveredTemplateId: String?

    // Grid layout configuration
    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 340), spacing: DSSpacing.md)
    ]

    public init(
        onSelectTemplate: @escaping (HookTemplate) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.onSelectTemplate = onSelectTemplate
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerView

            Divider()
                .padding(.horizontal, DSSpacing.md)

            // Template grid
            if filteredTemplates.isEmpty {
                emptyStateView
            } else {
                templateGridView
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.ds.bg0)
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Hook Templates")
                        .dsTextStyle(.title)

                    Text("Choose a template to get started quickly")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }

                Spacer()

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.ds.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Search and filters row
            HStack(spacing: DSSpacing.md) {
                // Search field
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ds.tertiary)

                    TextField("Search templates...", text: $searchText)
                        .textFieldStyle(.plain)
                        .dsTextStyle(.body)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(Color.ds.surface.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                .frame(maxWidth: 280)

                Spacer()

                // Category filter pills
                categoryFilterView
            }
        }
        .padding(DSSpacing.lg)
    }

    // MARK: - Category Filter

    private var categoryFilterView: some View {
        HStack(spacing: DSSpacing.xs) {
            // "All" option
            CategoryPill(
                label: "All",
                icon: "square.grid.2x2",
                isSelected: selectedCategory == nil,
                color: .accentColor
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCategory = nil
                }
            }

            // Category pills
            ForEach(HookTemplateCategory.allCases, id: \.self) { category in
                CategoryPill(
                    label: category.displayName,
                    icon: category.icon,
                    isSelected: selectedCategory == category,
                    color: categoryColor(for: category)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
    }

    // MARK: - Template Grid

    private var templateGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(filteredTemplates, id: \.id) { template in
                    TemplateCard(
                        template: template,
                        isHovered: hoveredTemplateId == template.id,
                        onHover: { isHovered in
                            hoveredTemplateId = isHovered ? template.id : nil
                        },
                        onSelect: {
                            onSelectTemplate(template)
                        }
                    )
                }
            }
            .padding(DSSpacing.lg)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Templates Found")
                .dsTextStyle(.subtitle)

            Text("Try adjusting your search or filters")
                .dsTextStyle(.caption, color: .ds.secondary)

            if !searchText.isEmpty || selectedCategory != nil {
                Button("Clear Filters") {
                    withAnimation {
                        searchText = ""
                        selectedCategory = nil
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtering

    private var filteredTemplates: [HookTemplate] {
        var templates = HookTemplates.all

        // Filter by category
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            templates = HookTemplates.search(query: searchText)
            // Re-apply category filter if active
            if let category = selectedCategory {
                templates = templates.filter { $0.category == category }
            }
        }

        return templates
    }

    // MARK: - Helpers

    private func categoryColor(for category: HookTemplateCategory) -> Color {
        switch category {
        case .logging:
            return .ds.info
        case .security:
            return .ds.negative
        case .notification:
            return .ds.warning
        case .custom:
            return .purple
        case .integration:
            return .ds.positive
        }
    }
}

// MARK: - Category Pill

/// A selectable filter pill for categories.
private struct CategoryPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11))

                Text(label)
                    .dsTextStyle(.micro)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? color : Color.ds.secondary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(
                isSelected
                    ? color.opacity(0.15)
                    : (isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Template Card

/// A card displaying a single hook template with hover effects.
private struct TemplateCard: View {
    let template: HookTemplate
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Header with icon and category
                HStack(spacing: DSSpacing.sm) {
                    // Template icon
                    Image(systemName: template.displayIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(categoryColor)
                        .frame(width: DSSize.lg, height: DSSize.lg)
                        .background(categoryColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .dsTextStyle(.subtitle)
                            .lineLimit(1)

                        // Category badge
                        Badge(
                            template.category.displayName,
                            icon: template.category.icon,
                            variant: categoryBadgeVariant,
                            size: .small
                        )
                    }

                    Spacer()

                    // Blocking indicator
                    if template.canBlock {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.ds.warning)
                            .help("This hook can block tool execution")
                    }
                }

                // Description
                Text(template.description)
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: DSSpacing.xs)

                // Event types and tags
                HStack(spacing: DSSpacing.sm) {
                    // Supported event types
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.ds.tertiary)

                        Text(eventTypesLabel)
                            .dsTextStyle(.micro, color: .ds.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Script type indicator
                    scriptTypeBadge
                }

                // Tags row (show first 3)
                if !template.tags.isEmpty {
                    HStack(spacing: DSSpacing.xxs) {
                        ForEach(template.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                                .padding(.horizontal, DSSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.ds.surface.opacity(0.3))
                                .clipShape(Capsule())
                        }

                        if template.tags.count > 3 {
                            Text("+\(template.tags.count - 3)")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }
                    }
                }
            }
            .padding(DSSpacing.md)
            .frame(minHeight: 160)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg)
                    .stroke(
                        isHovered ? categoryColor.opacity(0.4) : Color.ds.border.opacity(0.3),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .shadow(
                color: isHovered ? categoryColor.opacity(0.15) : Color.clear,
                radius: 8,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover(perform: onHover)
    }

    // MARK: - Card Helpers

    private var cardBackground: some View {
        ZStack {
            Color.ds.surface.opacity(0.2)

            if isHovered {
                LinearGradient(
                    colors: [
                        categoryColor.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var categoryColor: Color {
        switch template.category {
        case .logging:
            return .ds.info
        case .security:
            return .ds.negative
        case .notification:
            return .ds.warning
        case .custom:
            return .purple
        case .integration:
            return .ds.positive
        }
    }

    private var categoryBadgeVariant: BadgeVariant {
        switch template.category {
        case .logging:
            return .info
        case .security:
            return .error
        case .notification:
            return .warning
        case .custom:
            return .default
        case .integration:
            return .success
        }
    }

    private var eventTypesLabel: String {
        let types = template.supportedEventTypes
        if types.count == 1 {
            return types[0].rawValue
        } else if types.count <= 3 {
            return types.map { $0.shortName }.joined(separator: ", ")
        } else {
            return "\(types.count) event types"
        }
    }

    @ViewBuilder
    private var scriptTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: scriptTypeIcon)
                .font(.system(size: 10))

            Text(scriptTypeLabel)
                .dsTextStyle(.micro)
        }
        .foregroundStyle(Color.ds.secondary)
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 2)
        .background(Color.ds.surface.opacity(0.4))
        .clipShape(Capsule())
    }

    private var scriptTypeIcon: String {
        switch template.scriptType {
        case .shell:
            return "terminal"
        case .python:
            return "chevron.left.forwardslash.chevron.right"
        case .node:
            return "curlybraces"
        case .applescript:
            return "applescript"
        }
    }

    private var scriptTypeLabel: String {
        switch template.scriptType {
        case .shell:
            return "Shell"
        case .python:
            return "Python"
        case .node:
            return "Node.js"
        case .applescript:
            return "AppleScript"
        }
    }
}

// MARK: - CLIHookEventType Extension

extension CLIHookEventType {
    /// Short display name for compact UI.
    var shortName: String {
        switch self {
        case .preToolUse:
            return "Pre"
        case .postToolUse:
            return "Post"
        case .sessionStart:
            return "Start"
        case .stop:
            return "Stop"
        case .preCompact:
            return "Compact"
        case .notification:
            return "Notify"
        case .permissionRequest:
            return "Perm"
        case .userPromptSubmit:
            return "Prompt"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Template Gallery") {
    TemplateGalleryView { template in
        print("Selected: \(template.name)")
    } onDismiss: {
        print("Dismissed")
    }
    .frame(width: 800, height: 700)
}

#Preview("Template Gallery - Compact") {
    TemplateGalleryView { template in
        print("Selected: \(template.name)")
    }
    .frame(width: 600, height: 500)
}
#endif
