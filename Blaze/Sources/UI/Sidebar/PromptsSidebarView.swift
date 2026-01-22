import SwiftUI

// MARK: - Prompts Sidebar View

/// Tab 13: Saved prompts and templates sidebar.
///
/// **Phase 2 Spec:**
/// - List saved prompts from PromptStore
/// - Categories: System prompts, Templates, Snippets
/// - Actions: Insert into chat, Edit, Delete
/// - Create new prompt button
/// - Search prompts
struct PromptsSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var prompts: [SavedPrompt] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: PromptSidebarCategory = .all
    @State private var isLoading: Bool = false
    @State private var showCreateSheet: Bool = false
    @State private var editingPrompt: SavedPrompt?
    @State private var expandedCategories: Set<String> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and create button
            headerView
                .clipped()

            Divider()

            // Prompt list
            if isLoading {
                loadingView
            } else if filteredPrompts.isEmpty {
                emptyView
            } else {
                promptListView
            }
        }
        .clipped()  // Prevent UI bleeding outside container
        .task {
            await loadPrompts()
        }
        .sheet(isPresented: $showCreateSheet) {
            PromptEditSheet(
                prompt: nil,
                onSave: { newPrompt in
                    Task {
                        await savePrompt(newPrompt)
                    }
                },
                onCancel: {
                    showCreateSheet = false
                }
            )
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditSheet(
                prompt: prompt,
                onSave: { updatedPrompt in
                    Task {
                        await savePrompt(updatedPrompt)
                    }
                },
                onCancel: {
                    editingPrompt = nil
                }
            )
        }
    }

    // MARK: - Computed Properties

    private var filteredPrompts: [SavedPrompt] {
        prompts.filter { prompt in
            // Apply search filter
            let matchesSearch = searchText.isEmpty ||
                prompt.name.localizedCaseInsensitiveContains(searchText) ||
                prompt.content.localizedCaseInsensitiveContains(searchText) ||
                (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false)

            // Apply category filter
            let matchesCategory: Bool
            switch selectedCategory {
            case .all:
                matchesCategory = true
            case .system:
                matchesCategory = prompt.category == PromptCategory.general.rawValue
            case .templates:
                matchesCategory = prompt.isTemplate
            case .snippets:
                matchesCategory = !prompt.isTemplate && prompt.category != PromptCategory.general.rawValue
            case .recent:
                matchesCategory = prompt.lastUsedAt != nil
            }

            return matchesSearch && matchesCategory
        }
    }

    private var groupedPrompts: [String: [SavedPrompt]] {
        Dictionary(grouping: filteredPrompts) { prompt in
            prompt.category ?? "Uncategorized"
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: DSSpacing.xs) {
            // Title and create button
            HStack {
                Label("Prompts", systemImage: "text.quote")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Create new prompt button
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ds.accent)
                }
                .buttonStyle(.plain)
                .help("Create new prompt")
            }

            // Category picker (scrollable for narrow sidebars)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(PromptSidebarCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 11, weight: selectedCategory == category ? .semibold : .regular))
                                .foregroundStyle(selectedCategory == category ? Color.ds.foreground : Color.ds.secondary)
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xxs)
                                .background(
                                    selectedCategory == category
                                        ? Color.ds.accent.opacity(0.2)
                                        : Color.ds.surface.opacity(0.3)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Search field
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ds.tertiary)

                TextField("Search prompts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.ds.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxs)
            .background(Color.ds.surface.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading prompts...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "text.quote")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Prompts")
                .dsTextStyle(.subtitle)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .dsTextStyle(.caption, color: .ds.secondary)
            } else {
                Text("Save frequently used prompts for quick access")
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create Prompt", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Prompt List View

    private var promptListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // If grouped by category
                if selectedCategory == .all {
                    let sortedCategories = groupedPrompts.keys.sorted()
                    ForEach(sortedCategories, id: \.self) { category in
                        if let categoryPrompts = groupedPrompts[category] {
                            promptSection(category: category, prompts: categoryPrompts)
                        }
                    }
                } else {
                    // Flat list for filtered view
                    ForEach(filteredPrompts) { prompt in
                        PromptRow(
                            prompt: prompt,
                            onInsert: {
                                insertPrompt(prompt)
                            },
                            onEdit: {
                                editingPrompt = prompt
                            },
                            onDelete: {
                                deletePrompt(prompt)
                            }
                        )

                        if prompt.id != filteredPrompts.last?.id {
                            Divider()
                                .padding(.leading, DSSpacing.lg)
                        }
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    private func promptSection(category: String, prompts: [SavedPrompt]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            Button {
                toggleCategory(category)
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 12)

                    Image(systemName: categoryIcon(for: category))
                        .font(.system(size: 11))
                        .foregroundStyle(categoryColor(for: category))

                    Text(category)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .fontWeight(.medium)

                    Text("(\(prompts.count))")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(Color.ds.surface.opacity(0.2))
            }
            .buttonStyle(.plain)

            // Prompts in this category
            if expandedCategories.contains(category) {
                ForEach(prompts) { prompt in
                    PromptRow(
                        prompt: prompt,
                        onInsert: {
                            insertPrompt(prompt)
                        },
                        onEdit: {
                            editingPrompt = prompt
                        },
                        onDelete: {
                            deletePrompt(prompt)
                        }
                    )

                    if prompt.id != prompts.last?.id {
                        Divider()
                            .padding(.leading, DSSpacing.lg + DSSpacing.sm)
                    }
                }
            }
        }
    }

    private func categoryIcon(for category: String) -> String {
        guard let cat = PromptCategory(rawValue: category) else {
            return "tag"
        }
        switch cat {
        case .general: return "star"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .debugging: return "ant"
        case .documentation: return "doc.text"
        case .testing: return "checkmark.shield"
        case .review: return "eye"
        case .explanation: return "lightbulb"
        case .custom: return "tag"
        }
    }

    private func categoryColor(for category: String) -> Color {
        guard let cat = PromptCategory(rawValue: category) else {
            return .ds.tertiary
        }
        switch cat {
        case .general: return .ds.accent
        case .refactoring: return .ds.info
        case .debugging: return .ds.negative
        case .documentation: return .ds.positive
        case .testing: return .ds.warning
        case .review: return .purple
        case .explanation: return .orange
        case .custom: return .ds.tertiary
        }
    }

    // MARK: - Actions

    private func loadPrompts() async {
        isLoading = true
        defer { isLoading = false }

        // Generate demo prompts for now
        prompts = generateDemoPrompts()

        // Expand first category by default
        if let firstCategory = groupedPrompts.keys.sorted().first {
            expandedCategories.insert(firstCategory)
        }
    }

    private func toggleCategory(_ category: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }

    private func insertPrompt(_ prompt: SavedPrompt) {
        // Notify to insert prompt content into chat
        NotificationCenter.default.post(
            name: .insertPrompt,
            object: nil,
            userInfo: ["content": prompt.content, "promptId": prompt.id]
        )
    }

    private func savePrompt(_ prompt: SavedPrompt) async {
        if prompts.contains(where: { $0.id == prompt.id }) {
            // Update existing
            if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts[index] = prompt
            }
        } else {
            // Add new
            prompts.append(prompt)
        }
        showCreateSheet = false
        editingPrompt = nil
    }

    private func deletePrompt(_ prompt: SavedPrompt) {
        prompts.removeAll { $0.id == prompt.id }
    }

    private func generateDemoPrompts() -> [SavedPrompt] {
        [
            SavedPrompt(
                name: "Explain This Code",
                content: "Please explain what this code does step by step, including any important patterns or potential issues.",
                description: "Get a detailed explanation of selected code",
                category: PromptCategory.explanation.rawValue,
                isTemplate: false
            ),
            SavedPrompt(
                name: "Write Tests",
                content: "Write comprehensive unit tests for this code. Include edge cases and use descriptive test names.",
                description: "Generate unit tests for code",
                category: PromptCategory.testing.rawValue,
                isTemplate: false
            ),
            SavedPrompt(
                name: "Refactor for Readability",
                content: "Refactor this code to improve readability. Focus on: clear naming, smaller functions, reduced complexity.",
                description: "Improve code readability",
                category: PromptCategory.refactoring.rawValue,
                isTemplate: false
            ),
            SavedPrompt(
                name: "Debug Error",
                content: "I'm getting this error: {{error_message}}\n\nPlease help me understand what's causing it and how to fix it.",
                description: "Debug an error with context",
                category: PromptCategory.debugging.rawValue,
                isTemplate: true,
                variables: ["error_message"]
            ),
            SavedPrompt(
                name: "Code Review",
                content: "Review this code for:\n- Bugs and edge cases\n- Performance issues\n- Security concerns\n- Best practices",
                description: "Comprehensive code review",
                category: PromptCategory.review.rawValue,
                isTemplate: false
            ),
            SavedPrompt(
                name: "Add Documentation",
                content: "Add comprehensive documentation to this code including:\n- Function/method docstrings\n- Parameter descriptions\n- Return value descriptions\n- Usage examples",
                description: "Generate code documentation",
                category: PromptCategory.documentation.rawValue,
                isTemplate: false
            )
        ]
    }
}

// MARK: - Prompt Sidebar Category

enum PromptSidebarCategory: String, CaseIterable {
    case all = "All"
    case system = "System"
    case templates = "Templates"
    case snippets = "Snippets"
    case recent = "Recent"
}

// MARK: - Prompt Row

struct PromptRow: View {
    let prompt: SavedPrompt
    let onInsert: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        Button(action: onInsert) {
            HStack(spacing: DSSpacing.sm) {
                // Template indicator
                Image(systemName: prompt.isTemplate ? "doc.text.fill" : "text.quote")
                    .font(.system(size: 11))
                    .foregroundStyle(prompt.isTemplate ? Color.ds.info : Color.ds.tertiary)
                    .frame(width: 14)

                // Prompt info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(prompt.name)
                            .dsTextStyle(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        // Shortcut badge
                        if let shortcut = prompt.shortcut {
                            Text(shortcut)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.ds.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.ds.surface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }

                    if let description = prompt.description {
                        Text(description)
                            .dsTextStyle(.micro, color: .ds.tertiary)
                            .lineLimit(1)
                    }

                    // Variables indicator for templates
                    if prompt.isTemplate && !prompt.variables.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "textformat.alt")
                                .font(.system(size: 8))
                            Text(prompt.variables.joined(separator: ", "))
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(Color.ds.info)
                    }
                }

                Spacer()

                // Action buttons (visible on hover)
                if isHovered {
                    HStack(spacing: DSSpacing.xxs) {
                        // Insert button
                        Button(action: onInsert) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.ds.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Insert into chat")

                        // Edit button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.ds.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Edit")

                        // Delete button
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.ds.negative)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
            .padding(.vertical, DSSpacing.xs)
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
        .confirmationDialog(
            "Delete Prompt",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the prompt '\(prompt.name)'.")
        }
    }
}

// MARK: - Prompt Edit Sheet

struct PromptEditSheet: View {
    let prompt: SavedPrompt?
    let onSave: (SavedPrompt) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var content: String = ""
    @State private var description: String = ""
    @State private var category: String = PromptCategory.general.rawValue
    @State private var isTemplate: Bool = false
    @State private var shortcut: String = ""

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Header
            HStack {
                Text(prompt == nil ? "Create Prompt" : "Edit Prompt")
                    .dsTextStyle(.subtitle)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Form
            Form {
                TextField("Name", text: $name)

                TextField("Description (optional)", text: $description)

                Picker("Category", selection: $category) {
                    ForEach(PromptCategory.allCases, id: \.rawValue) { cat in
                        Text(cat.rawValue).tag(cat.rawValue)
                    }
                }

                Toggle("Is Template (supports variables)", isOn: $isTemplate)

                TextField("Keyboard Shortcut (optional)", text: $shortcut)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)

            // Content editor
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Prompt Content")
                    .dsTextStyle(.caption, color: .ds.secondary)

                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 150)
                    .border(Color.ds.surface, width: 1)

                if isTemplate {
                    Text("Use {{variable_name}} syntax for template variables")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button(prompt == nil ? "Create" : "Save") {
                    let newPrompt = SavedPrompt(
                        id: prompt?.id ?? UUID(),
                        name: name,
                        content: content,
                        description: description.isEmpty ? nil : description,
                        category: category,
                        isTemplate: isTemplate,
                        variables: extractVariables(from: content),
                        shortcut: shortcut.isEmpty ? nil : shortcut
                    )
                    onSave(newPrompt)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || content.isEmpty)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 500, height: 550)
        .onAppear {
            if let prompt = prompt {
                name = prompt.name
                content = prompt.content
                description = prompt.description ?? ""
                category = prompt.category ?? PromptCategory.general.rawValue
                isTemplate = prompt.isTemplate
                shortcut = prompt.shortcut ?? ""
            }
        }
    }

    private func extractVariables(from content: String) -> [String] {
        let pattern = #"\{\{(\w+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else {
                return nil
            }
            return String(content[range])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let insertPrompt = Notification.Name("insertPrompt")
}

// MARK: - Previews

#Preview("Prompts Sidebar") {
    PromptsSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Prompts Sidebar - Empty") {
    PromptsSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
