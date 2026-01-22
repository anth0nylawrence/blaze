import SwiftUI

// MARK: - Advanced Hook Builder View

/// Main UI for building and configuring CLI hooks.
/// Provides a form-based interface for creating hooks with metadata,
/// event type selection, matcher configuration, and script editing.
///
/// **E005-F009-S002-T001-A001**
public struct AdvancedHookBuilderView: View {
    // MARK: - State

    /// The hook definition being edited
    @Binding var hook: HookDefinition

    /// Callback when save is requested
    var onSave: ((HookDefinition) -> Void)?

    /// Callback when cancel is requested
    var onCancel: (() -> Void)?

    // MARK: - Local State

    @State private var name: String = ""
    @State private var hookDescription: String = ""
    @State private var isEnabled: Bool = true
    @State private var hookType: HookType = .command
    @State private var eventType: CLIHookEventType = .preToolUse
    @State private var matcherPatterns: String = ""
    @State private var content: String = ""
    @State private var timeout: String = ""
    @State private var showingTemplates: Bool = false
    @State private var validationErrors: [HookValidationError] = []
    @State private var selectedTemplate: HookTemplate?

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    public init(
        hook: Binding<HookDefinition>,
        onSave: ((HookDefinition) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._hook = hook
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        HSplitView {
            // Main form area
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    headerSection
                    metadataSection
                    hookTypeSection
                    eventTypeSection
                    matcherSection
                    contentEditorSection
                    actionButtons
                }
                .padding(DSSpacing.lg)
            }
            .frame(minWidth: 500)

            // Template variable reference sidebar
            templateVariableSidebar
                .frame(width: 280)
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.ds.bg0)
        .onAppear {
            loadFromBinding()
        }
        .sheet(isPresented: $showingTemplates) {
            TemplatePickerSheet(
                selectedTemplate: $selectedTemplate,
                eventType: eventType
            )
        }
        .onChange(of: selectedTemplate) { _, template in
            if let template = template {
                applyTemplate(template)
            }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(hook.id == UUID() ? "New Hook" : "Edit Hook")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ds.foreground)

                Text("Configure automation to run on CLI events")
                    .font(.subheadline)
                    .foregroundStyle(Color.ds.secondary)
            }

            Spacer()

            Button {
                showingTemplates = true
            } label: {
                Label("Use Template", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            .help("Start from a predefined template")
        }
    }

    // MARK: - Metadata Section

    @ViewBuilder
    private var metadataSection: some View {
        FormSection(
            title: "Hook Metadata",
            description: "Basic information about this hook"
        ) {
            // Name
            FormRow(
                label: "Name",
                isRequired: true,
                errorMessage: validationError(for: .emptyName)
            ) {
                GlassTextField("Enter hook name", text: $name, icon: "tag")
            }

            // Description
            FormRow(
                label: "Description",
                helpText: "Optional description of what this hook does"
            ) {
                GlassTextField("Describe what this hook does", text: $hookDescription, icon: "text.alignleft")
            }

            // Enabled toggle
            GlassToggle(
                "Enabled",
                isOn: $isEnabled,
                description: "Hook will only run when enabled"
            )
        }
    }

    // MARK: - Hook Type Section

    @ViewBuilder
    private var hookTypeSection: some View {
        FormSection(
            title: "Hook Type",
            description: "How this hook will execute"
        ) {
            // Type picker with visual cards
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DSSpacing.sm) {
                ForEach(HookType.allCases) { type in
                    HookTypeCard(
                        type: type,
                        isSelected: hookType == type,
                        action: { hookType = type }
                    )
                }
            }

            // Type description
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.ds.info)
                Text(hookType.description)
                    .font(.caption)
                    .foregroundStyle(Color.ds.secondary)
            }
            .padding(.top, DSSpacing.xs)
        }
    }

    // MARK: - Event Type Section

    @ViewBuilder
    private var eventTypeSection: some View {
        FormSection(
            title: "Event Type",
            description: "When this hook should trigger"
        ) {
            FormRow(
                label: "Trigger Event",
                isRequired: true
            ) {
                Picker("Event", selection: $eventType) {
                    ForEach(CLIHookEventType.allCases, id: \.self) { event in
                        Label(event.displayName, systemImage: event.icon)
                            .tag(event)
                    }
                }
                .pickerStyle(.menu)
            }

            // Event details
            let eventDef = CLIHookEventDefinition.forEvent(eventType)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(eventDef.description)
                    .font(.caption)
                    .foregroundStyle(Color.ds.secondary)

                if eventType.canBlock {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(Color.ds.warning)
                        Text("This event can block execution")
                            .font(.caption)
                            .foregroundStyle(Color.ds.warning)
                    }
                }
            }
        }
    }

    // MARK: - Matcher Section

    @ViewBuilder
    private var matcherSection: some View {
        FormSection(
            title: "Matcher Configuration",
            description: "Filter which events trigger this hook"
        ) {
            FormRow(
                label: "Tool Patterns",
                helpText: "Comma-separated glob patterns (e.g., Bash, Read*, mcp__*)"
            ) {
                GlassTextField(
                    "e.g., Bash, Write, Edit",
                    text: $matcherPatterns,
                    icon: "line.3.horizontal.decrease.circle"
                )
            }

            // Matcher preview
            if !matcherPatterns.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Will match:")
                        .font(.caption.bold())
                        .foregroundStyle(Color.ds.secondary)

                    ForEach(parsedPatterns, id: \.self) { pattern in
                        HStack(spacing: DSSpacing.xxs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.ds.positive)
                            Text(pattern)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.ds.foreground)
                        }
                    }
                }
                .padding(DSSpacing.sm)
                .background(Color.ds.surface)
                .cornerRadius(DSRadius.md)
            }
        }
    }

    // MARK: - Content Editor Section

    @ViewBuilder
    private var contentEditorSection: some View {
        FormSection(
            title: contentSectionTitle,
            description: contentSectionDescription
        ) {
            // Content editor
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack {
                    Text(contentLabel)
                        .dsTextStyle(.body)

                    Text("*")
                        .foregroundStyle(Color.ds.negative)

                    Spacer()

                    // Script type indicator for command hooks
                    if hookType == .command {
                        Menu {
                            ForEach(HookScriptType.allCases, id: \.self) { scriptType in
                                Button(scriptType.displayName) {
                                    // Update content with shebang if empty
                                    if content.isEmpty {
                                        content = shebangFor(scriptType)
                                    }
                                }
                            }
                        } label: {
                            Label("Script Type", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.caption)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }

                // Text editor
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(DSSpacing.sm)
                    .background(Color.ds.surface)
                    .cornerRadius(DSRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(contentError != nil ? Color.ds.negative : Color.ds.tertiary.opacity(0.3), lineWidth: 1)
                    )

                // Content error message
                if let error = contentError {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.ds.negative)
                }
            }

            // Timeout configuration
            if hookType != .prompt {
                FormRow(
                    label: "Timeout (seconds)",
                    helpText: "Maximum execution time (default: \(Int(hookType.defaultTimeout))s)"
                ) {
                    HStack {
                        GlassTextField(
                            "\(Int(hookType.defaultTimeout))",
                            text: $timeout,
                            icon: "clock"
                        )
                        .frame(width: 120)

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                onCancel?()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Validate") {
                validate()
            }
            .buttonStyle(.bordered)

            Button("Save") {
                if validate() {
                    saveHook()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!validationErrors.isEmpty && validationErrors.count > 0)
        }
        .padding(.top, DSSpacing.md)
    }

    // MARK: - Template Variable Sidebar

    @ViewBuilder
    private var templateVariableSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundStyle(Color.ds.accent)
                Text("Template Variables")
                    .font(.headline)
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds.bg1)

            Divider()

            // Variables list
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    ForEach(hookType.templateVariables) { variable in
                        TemplateVariableRow(variable: variable) {
                            insertVariable(variable)
                        }
                    }

                    // Common variables section
                    if !commonVariables.isEmpty {
                        Divider()
                            .padding(.vertical, DSSpacing.sm)

                        Text("Common Variables")
                            .font(.caption.bold())
                            .foregroundStyle(Color.ds.secondary)

                        ForEach(commonVariables) { variable in
                            TemplateVariableRow(variable: variable) {
                                insertVariable(variable)
                            }
                        }
                    }
                }
                .padding(DSSpacing.md)
            }
        }
        .background(Color.ds.bg1)
    }

    // MARK: - Computed Properties

    private var parsedPatterns: [String] {
        matcherPatterns
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var contentSectionTitle: String {
        switch hookType {
        case .prompt: return "Prompt Message"
        case .command: return "Script Content"
        case .agent: return "Agent Configuration"
        }
    }

    private var contentSectionDescription: String {
        switch hookType {
        case .prompt: return "Message to inject into the conversation"
        case .command: return "Shell script or command to execute"
        case .agent: return "Agent identifier or prompt for delegation"
        }
    }

    private var contentLabel: String {
        switch hookType {
        case .prompt: return "Message"
        case .command: return "Script"
        case .agent: return "Agent"
        }
    }

    private var contentError: String? {
        validationErrors.first { error in
            switch error {
            case .emptyContent, .invalidPromptContent, .invalidAgentConfig, .dangerousCommand:
                return true
            default:
                return false
            }
        }?.message
    }

    private var commonVariables: [TemplateVariable] {
        [
            TemplateVariable(
                name: "$SESSION_ID",
                description: "Current session identifier",
                example: "abc123-def456"
            ),
            TemplateVariable(
                name: "$PROJECT_PATH",
                description: "Root path of the current project",
                example: "/Users/dev/project"
            ),
            TemplateVariable(
                name: "$TIMESTAMP",
                description: "ISO 8601 timestamp of the event",
                example: "2025-01-15T10:30:00Z"
            )
        ]
    }

    // MARK: - Helper Methods

    private func loadFromBinding() {
        name = hook.name
        hookDescription = hook.hookDescription ?? ""
        isEnabled = hook.isEnabled
        hookType = hook.type
        matcherPatterns = hook.matcher ?? ""
        content = hook.content
        timeout = hook.timeout.map { String(Int($0)) } ?? ""
    }

    private func validationError(for errorType: HookValidationError) -> String? {
        validationErrors.first { $0.id == errorType.id }?.message
    }

    @discardableResult
    private func validate() -> Bool {
        let definition = buildDefinition()
        validationErrors = definition.validate()
        return validationErrors.isEmpty
    }

    private func buildDefinition() -> HookDefinition {
        HookDefinition(
            id: hook.id,
            name: name,
            type: hookType,
            matcher: matcherPatterns.isEmpty ? nil : matcherPatterns,
            content: content,
            timeout: Double(timeout),
            isEnabled: isEnabled,
            hookDescription: hookDescription.isEmpty ? nil : hookDescription
        )
    }

    private func saveHook() {
        let definition = buildDefinition()
        hook = definition
        onSave?(definition)
        dismiss()
    }

    private func insertVariable(_ variable: TemplateVariable) {
        content += variable.name
    }

    private func applyTemplate(_ template: HookTemplate) {
        name = template.name
        hookDescription = template.description
        eventType = template.defaultEventType
        content = template.codeTemplate
        timeout = String(template.defaultTimeoutMs / 1000)

        // Reset selection
        selectedTemplate = nil
    }

    private func shebangFor(_ scriptType: HookScriptType) -> String {
        switch scriptType {
        case .shell: return "#!/bin/bash\n\n"
        case .python: return "#!/usr/bin/env python3\n\n"
        case .node: return "#!/usr/bin/env node\n\n"
        case .applescript: return ""
        }
    }
}

// MARK: - Hook Type Card

/// Visual card for selecting hook type
private struct HookTypeCard: View {
    let type: HookType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.ds.accent : Color.ds.secondary)

                Text(type.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(DSSpacing.md)
            .background(isSelected ? Color.ds.accent.opacity(0.1) : Color.ds.surface)
            .cornerRadius(DSRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(isSelected ? Color.ds.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Variable Row

/// Row displaying a template variable with insert action
private struct TemplateVariableRow: View {
    let variable: TemplateVariable
    let onInsert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            HStack {
                Text(variable.name)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color.ds.accent)

                Spacer()

                Button {
                    onInsert()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Insert variable")
            }

            Text(variable.description)
                .font(.caption)
                .foregroundStyle(Color.ds.secondary)
                .lineLimit(2)

            Text("e.g., \(variable.example)")
                .font(.caption2.monospaced())
                .foregroundStyle(Color.ds.tertiary)
        }
        .padding(DSSpacing.xs)
        .background(Color.ds.surface.opacity(0.5))
        .cornerRadius(DSRadius.sm)
    }
}

// MARK: - Template Picker Sheet

/// Sheet for browsing and selecting hook templates
private struct TemplatePickerSheet: View {
    @Binding var selectedTemplate: HookTemplate?
    let eventType: CLIHookEventType

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedCategory: HookTemplateCategory?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Hook Templates")
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color.ds.bg1)

            Divider()

            HStack(spacing: 0) {
                // Categories sidebar
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Categories")
                        .font(.caption.bold())
                        .foregroundStyle(Color.ds.secondary)
                        .padding(.horizontal, DSSpacing.sm)

                    Button {
                        selectedCategory = nil
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text("All")
                            Spacer()
                        }
                        .padding(DSSpacing.xs)
                        .background(selectedCategory == nil ? Color.ds.accent.opacity(0.2) : Color.clear)
                        .cornerRadius(DSRadius.sm)
                    }
                    .buttonStyle(.plain)

                    ForEach(HookTemplateCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                                Spacer()
                            }
                            .padding(DSSpacing.xs)
                            .background(selectedCategory == category ? Color.ds.accent.opacity(0.2) : Color.clear)
                            .cornerRadius(DSRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .frame(width: 150)
                .padding(DSSpacing.sm)
                .background(Color.ds.bg1)

                Divider()

                // Templates list
                VStack(spacing: 0) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.ds.secondary)
                        TextField("Search templates", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(DSSpacing.sm)
                    .background(Color.ds.surface)
                    .cornerRadius(DSRadius.md)
                    .padding(DSSpacing.sm)

                    // Templates grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: DSSpacing.sm) {
                            ForEach(filteredTemplates, id: \.id) { template in
                                TemplateCard(template: template) {
                                    selectedTemplate = template
                                    dismiss()
                                }
                            }
                        }
                        .padding(DSSpacing.sm)
                    }
                }
            }
        }
        .frame(width: 700, height: 500)
        .background(Color.ds.bg0)
    }

    private var filteredTemplates: [HookTemplate] {
        var templates = HookTemplates.all

        // Filter by category
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            templates = HookTemplates.search(query: searchText)
        }

        // Filter by compatible event type
        templates = templates.filter { $0.supportedEventTypes.contains(eventType) }

        return templates
    }
}

// MARK: - Template Card

/// Card displaying a hook template
private struct TemplateCard: View {
    let template: HookTemplate
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack {
                    Image(systemName: template.displayIcon)
                        .foregroundStyle(Color.ds.accent)
                    Text(template.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.ds.foreground)
                    Spacer()
                }

                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(Color.ds.secondary)
                    .lineLimit(2)

                // Tags
                HStack(spacing: DSSpacing.xxs) {
                    ForEach(template.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, DSSpacing.xxs)
                            .padding(.vertical, 2)
                            .background(Color.ds.surface)
                            .cornerRadius(DSRadius.sm)
                    }
                }
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds.bg1)
            .cornerRadius(DSRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(Color.ds.tertiary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Advanced Hook Builder - New") {
    AdvancedHookBuilderView(
        hook: .constant(HookDefinition(
            name: "",
            type: .command,
            content: ""
        ))
    )
}

#Preview("Advanced Hook Builder - Edit") {
    AdvancedHookBuilderView(
        hook: .constant(HookDefinition(
            name: "My Custom Hook",
            type: .command,
            matcher: "Bash, Write",
            content: "#!/bin/bash\necho \"Hello from hook!\"",
            timeout: 30,
            isEnabled: true,
            hookDescription: "A custom hook for logging"
        ))
    )
}

#Preview("Advanced Hook Builder - Prompt Type") {
    AdvancedHookBuilderView(
        hook: .constant(HookDefinition(
            name: "Security Reminder",
            type: .prompt,
            content: "Remember to review file changes carefully before approving."
        ))
    )
}
#endif
