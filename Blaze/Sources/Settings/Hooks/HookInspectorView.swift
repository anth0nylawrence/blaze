import SwiftUI

// MARK: - Hook Inspector View

/// Configuration inspector panel for hook nodes in the visual builder.
/// Displays node-specific configuration fields and validation messages.
public struct HookInspectorView: View {
    @Binding var node: HookNode?
    let onDelete: (UUID) -> Void

    @State private var eventType: String = ""
    @State private var commandText: String = ""
    @State private var messageText: String = ""
    @State private var patternText: String = ""
    @State private var descriptionText: String = ""
    @State private var configEdits: [String: String] = [:]
    @State private var showDeleteConfirmation = false

    private let eventTypes = [
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "PermissionRequest",
        "UserPromptSubmit",
        "Notification",
        "Stop",
        "SubagentStart",
        "SubagentStop",
        "PreCompact",
        "SessionStart",
        "SessionEnd"
    ]

    public init(
        node: Binding<HookNode?>,
        onDelete: @escaping (UUID) -> Void
    ) {
        self._node = node
        self.onDelete = onDelete
    }

    public var body: some View {
        ScrollView {
            if let node = node {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    // Header
                    headerView(for: node)

                    // Description field (for all node types)
                    FormRow(
                        label: "Description",
                        helpText: "Optional note describing what this node does"
                    ) {
                        GlassTextField(
                            "e.g., Logs all tool calls for debugging",
                            text: $descriptionText
                        )
                        .onChange(of: descriptionText) { _, newValue in
                            updateNodeConfig(key: "description", value: newValue)
                        }
                    }

                    Divider()

                    // Configuration based on node type
                    configurationView(for: node)

                    Spacer()

                    // Delete button
                    deleteButton(for: node)
                }
                .padding(DSSpacing.md)
            } else {
                emptyStateView
            }
        }
        .frame(width: 300)
        .background(Color.ds.bg1)
        .onChange(of: node) { _, newNode in
            loadNodeState(newNode)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerView(for node: HookNode) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: node.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(categoryColor(for: node.type.category))

            Text(node.type.displayName)
                .dsTextStyle(.title)

            Spacer()
        }
    }

    // MARK: - Configuration Views

    @ViewBuilder
    private func configurationView(for node: HookNode) -> some View {
        switch node.type.category {
        case .event:
            eventConfigurationView(for: node)
        case .filter:
            filterConfigurationView(for: node)
        case .action:
            actionConfigurationView(for: node)
        case .control, .transform, .utility:
            genericConfigurationView(for: node)
        }
    }

    // Event node configuration
    @ViewBuilder
    private func eventConfigurationView(for node: HookNode) -> some View {
        FormSection(
            title: "Event Configuration",
            description: "Select the event type to trigger this hook"
        ) {
            FormRow(
                label: "Event Type",
                isRequired: true,
                errorMessage: validationMessage(for: node, field: "eventType")
            ) {
                GlassPicker("Select Event", selection: $eventType) {
                    ForEach(eventTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .onChange(of: eventType) { _, newValue in
                    updateNodeEventType(newValue)
                }
            }
        }
    }

    // Filter node configuration
    @ViewBuilder
    private func filterConfigurationView(for node: HookNode) -> some View {
        FormSection(
            title: "Filter Configuration",
            description: "Configure filter patterns"
        ) {
            if node.type == .matcher {
                FormRow(
                    label: "Patterns",
                    helpText: "Enter patterns separated by commas",
                    errorMessage: validationMessage(for: node, field: "matcher")
                ) {
                    GlassTextField(
                        "e.g., *.ts, src/**",
                        text: $patternText
                    )
                    .onChange(of: patternText) { _, newValue in
                        updateNodePattern(newValue)
                    }
                }
            } else {
                genericConfigurationView(for: node)
            }
        }
    }

    // Action node configuration
    @ViewBuilder
    private func actionConfigurationView(for node: HookNode) -> some View {
        FormSection(
            title: "Action Configuration",
            description: "Configure the action to execute"
        ) {
            switch node.type {
            case .command:
                FormRow(
                    label: "Command",
                    helpText: "Shell command to execute",
                    isRequired: true,
                    errorMessage: validationMessage(for: node, field: "command")
                ) {
                    GlassTextField(
                        "e.g., /path/to/script.sh",
                        text: $commandText,
                        icon: "terminal"
                    )
                    .onChange(of: commandText) { _, newValue in
                        updateNodeConfig(key: "command", value: newValue)
                    }
                }

            case .prompt:
                FormRow(
                    label: "Message",
                    helpText: "Prompt message to display",
                    isRequired: true,
                    errorMessage: validationMessage(for: node, field: "message")
                ) {
                    TextEditor(text: $messageText)
                        .frame(minHeight: 80)
                        .padding(DSSpacing.xs)
                        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
                        .onChange(of: messageText) { _, newValue in
                            updateNodeConfig(key: "message", value: newValue)
                        }
                }

            case .agent:
                FormRow(
                    label: "Skill/Agent",
                    helpText: "Name of skill or agent to invoke",
                    isRequired: true,
                    errorMessage: validationMessage(for: node, field: "skill")
                ) {
                    GlassTextField(
                        "e.g., commit",
                        text: Binding(
                            get: { configEdits["skill"] ?? "" },
                            set: { configEdits["skill"] = $0 }
                        ),
                        icon: "bolt.fill"
                    )
                    .onChange(of: configEdits["skill"]) { _, newValue in
                        if let value = newValue {
                            updateNodeConfig(key: "skill", value: value)
                        }
                    }
                }

            default:
                genericConfigurationView(for: node)
            }
        }
    }

    // Generic key-value configuration editor
    @ViewBuilder
    private func genericConfigurationView(for node: HookNode) -> some View {
        FormSection(
            title: "Configuration",
            description: "Node configuration settings"
        ) {
            if node.config.isEmpty {
                Text("No configuration fields available")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(DSSpacing.sm)
            } else {
                ForEach(Array(node.config.keys.sorted()), id: \.self) { key in
                    FormRow(label: key.capitalized) {
                        GlassTextField(
                            "Value",
                            text: Binding(
                                get: {
                                    if let value = node.config[key]?.value {
                                        return String(describing: value)
                                    }
                                    return ""
                                },
                                set: { newValue in
                                    updateNodeConfig(key: key, value: newValue)
                                }
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "square.dashed")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.tertiary)

            Text("Select a node to configure")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete Button

    @ViewBuilder
    private func deleteButton(for node: HookNode) -> some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Node")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .confirmationDialog(
            "Delete Node",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete(node.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this node? This action cannot be undone.")
        }
    }

    // MARK: - Validation

    private func validationMessage(for node: HookNode, field: String) -> String? {
        switch field {
        case "eventType":
            if node.type.category == .event && (node.eventType == nil || node.eventType?.isEmpty == true) {
                return "Event type is required"
            }

        case "command":
            if node.type == .command && node.config["command"] == nil {
                return "Command is required"
            }

        case "message":
            if node.type == .prompt && node.config["message"] == nil && node.config["prompt"] == nil {
                return "Message is required"
            }

        case "skill":
            if node.type == .agent && node.config["skill"] == nil && node.config["agent"] == nil {
                return "Skill or agent name is required"
            }

        case "matcher":
            if node.type == .matcher && node.config["matcher"] == nil {
                return "At least one pattern is required"
            }

        default:
            break
        }

        return nil
    }

    // MARK: - State Management

    private func loadNodeState(_ node: HookNode?) {
        guard let node = node else {
            eventType = ""
            commandText = ""
            messageText = ""
            patternText = ""
            descriptionText = ""
            configEdits = [:]
            return
        }

        // Load event type
        eventType = node.eventType ?? ""

        // Load description
        if let description = node.config["description"]?.value as? String {
            descriptionText = description
        } else {
            descriptionText = ""
        }

        // Load action-specific fields
        if let command = node.config["command"]?.value as? String {
            commandText = command
        }
        if let message = node.config["message"]?.value as? String {
            messageText = message
        }
        if let patterns = node.config["matcher"]?.value as? [String] {
            patternText = patterns.joined(separator: ", ")
        }

        // Load generic config
        configEdits = node.config.reduce(into: [:]) { result, item in
            result[item.key] = String(describing: item.value.value)
        }
    }

    private func updateNodeEventType(_ newValue: String) {
        node?.eventType = newValue
    }

    private func updateNodeConfig(key: String, value: String) {
        node?.config[key] = AnyCodable(value)
    }

    private func updateNodePattern(_ newValue: String) {
        let patterns = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        node?.config["matcher"] = AnyCodable(patterns)
    }

    // MARK: - Helpers

    private func categoryColor(for category: HookNodeCategory) -> Color {
        switch category {
        case .event: return Color.ds.info
        case .filter: return Color.ds.warning
        case .action: return Color.ds.positive
        case .control: return Color.ds.accent
        case .transform: return Color.purple
        case .utility: return Color.ds.secondary
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Inspector - Event Node") {
    HookInspectorView(
        node: .constant(HookNode(
            type: .preToolUse,
            eventType: "PreToolUse",
            position: .zero
        )),
        onDelete: { _ in }
    )
}

#Preview("Inspector - Action Node") {
    HookInspectorView(
        node: .constant(HookNode(
            type: .command,
            config: ["command": AnyCodable("/path/to/script.sh")],
            position: .zero
        )),
        onDelete: { _ in }
    )
}

#Preview("Inspector - Empty") {
    HookInspectorView(
        node: .constant(nil),
        onDelete: { _ in }
    )
}
#endif
