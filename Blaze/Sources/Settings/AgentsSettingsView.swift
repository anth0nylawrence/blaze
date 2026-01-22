//
//  AgentsSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

/// Represents an agent markdown file from ~/.claude/agents/
private struct AgentFile: Identifiable {
    let id: String  // filename
    let name: String  // display name (without .md)
    let url: URL
}

/// Settings view for configuring agent orchestration and concurrency.
struct AgentsSettingsView: View {
    @AppStorage("agentConcurrency") private var concurrency: Int = 10
    @AppStorage("agentAutoThrottle") private var autoThrottle: Bool = true
    @AppStorage("agentMemoryThreshold") private var memoryThreshold: Int = 80
    @AppStorage("agentTimeout") private var timeout: Int = 300

    // System agents state
    @State private var systemAgents: [AgentFile] = []
    @State private var selectedAgent: AgentFile? = nil
    @State private var agentContent: String = ""
    @State private var isEditing: Bool = false
    @State private var showAgentSheet: Bool = false
    @State private var showNewAgentSheet: Bool = false
    @State private var newAgentName: String = ""
    @State private var newAgentContent: String = "# Agent Name\n\nDescribe the agent's purpose and behavior here.\n"
    @State private var agentError: String? = nil

    private var showWarning: Bool {
        concurrency > 20
    }

    private var agentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("agents")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                // System Agents Section
                FormSection(
                    title: "System Agents",
                    description: "Installed agents from ~/.claude/agents/"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        if systemAgents.isEmpty {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(Color.ds.secondary)
                                Text("No agents found")
                                    .dsTextStyle(.body, color: .ds.secondary)
                            }
                            .padding(.vertical, DSSpacing.sm)
                        } else {
                            ForEach(systemAgents) { agent in
                                HStack {
                                    Image(systemName: "person.text.rectangle")
                                        .foregroundStyle(Color.ds.accent)
                                        .frame(width: 20)

                                    Text(agent.name)
                                        .dsTextStyle(.body)

                                    Spacer()

                                    Button("View") {
                                        viewAgent(agent)
                                    }
                                    .buttonStyle(.borderless)

                                    Button("Edit") {
                                        editAgent(agent)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, DSSpacing.xxs)

                                if agent.id != systemAgents.last?.id {
                                    Divider()
                                        .background(Color.ds.border.opacity(0.5))
                                }
                            }
                        }

                        // Error display
                        if let error = agentError {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.ds.negative)
                                Text(error)
                                    .dsTextStyle(.caption, color: .ds.negative)
                            }
                            .padding(.top, DSSpacing.xs)
                        }

                        Divider()
                            .padding(.vertical, DSSpacing.xs)

                        // Add new agent button
                        Button(action: { showNewAgentSheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add New Agent")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // Concurrency Settings
                FormSection(
                    title: "Concurrency",
                    description: "Configure how many agents can run simultaneously"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Concurrency slider
                        FormRow(
                            label: "Maximum concurrent agents",
                            helpText: "Recommended: 10-20 agents for most workflows"
                        ) {
                            HStack(spacing: DSSpacing.sm) {
                                Slider(value: Binding(
                                    get: { Double(concurrency) },
                                    set: { concurrency = Int($0) }
                                ), in: 1...100, step: 1)
                                .tint(Color.accentColor)

                                Text("\(concurrency)")
                                    .font(.body.monospacedDigit())
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .frame(width: 40)
                                    .padding(.horizontal, DSSpacing.xs)
                                    .padding(.vertical, DSSpacing.xxs)
                                    .background(Color.ds.surface.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                            }
                        }

                        // Warning for high concurrency
                        if showWarning {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.ds.warning)

                                Text("High concurrency may impact system performance")
                                    .dsTextStyle(.caption, color: .ds.warning)
                            }
                            .padding(DSSpacing.sm)
                            .background(Color.ds.warning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                        }
                    }
                }

                // Resource Management
                FormSection(
                    title: "Resource Management",
                    description: "Control how agents respond to system resource constraints"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Auto-throttle toggle
                        GlassToggle(
                            "Auto-throttle",
                            isOn: $autoThrottle,
                            description: "Automatically reduce concurrency when system resources are low"
                        )

                        Divider()
                            .background(Color.ds.border)

                        // Memory threshold slider
                        FormRow(
                            label: "Memory threshold",
                            helpText: "Trigger throttling when memory usage exceeds this percentage"
                        ) {
                            HStack(spacing: DSSpacing.sm) {
                                Slider(value: Binding(
                                    get: { Double(memoryThreshold) },
                                    set: { memoryThreshold = Int($0) }
                                ), in: 50...90, step: 5)
                                .tint(Color.accentColor)

                                Text("\(memoryThreshold)%")
                                    .font(.body.monospacedDigit())
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .frame(width: 50)
                                    .padding(.horizontal, DSSpacing.xs)
                                    .padding(.vertical, DSSpacing.xxs)
                                    .background(Color.ds.surface.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                            }
                        }
                    }
                }

                // Execution Limits
                FormSection(
                    title: "Execution Limits",
                    description: "Configure timeout and execution constraints"
                ) {
                    FormRow(
                        label: "Agent timeout",
                        helpText: "Maximum execution time per agent (seconds)"
                    ) {
                        GlassTextField(
                            "Timeout",
                            text: Binding(
                                get: { String(timeout) },
                                set: {
                                    if let value = Int($0) {
                                        timeout = value
                                    }
                                }
                            )
                        )
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                        .frame(width: 100)
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadSystemAgents()
        }
        .sheet(isPresented: $showAgentSheet) {
            AgentViewSheet(
                agent: selectedAgent,
                content: $agentContent,
                isEditing: isEditing,
                onSave: saveAgent,
                onDismiss: { showAgentSheet = false }
            )
        }
        .sheet(isPresented: $showNewAgentSheet) {
            NewAgentSheet(
                name: $newAgentName,
                content: $newAgentContent,
                onCreate: createNewAgent,
                onDismiss: {
                    showNewAgentSheet = false
                    newAgentName = ""
                    newAgentContent = "# Agent Name\n\nDescribe the agent's purpose and behavior here.\n"
                }
            )
        }
    }

    // MARK: - Agent Management

    private func loadSystemAgents() {
        agentError = nil
        let fm = FileManager.default

        guard fm.fileExists(atPath: agentsDirectory.path) else {
            systemAgents = []
            return
        }

        do {
            let files = try fm.contentsOfDirectory(at: agentsDirectory, includingPropertiesForKeys: nil)
            systemAgents = files
                .filter { $0.pathExtension == "md" }
                .map { url in
                    AgentFile(
                        id: url.lastPathComponent,
                        name: url.deletingPathExtension().lastPathComponent,
                        url: url
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            agentError = "Failed to load agents: \(error.localizedDescription)"
        }
    }

    private func viewAgent(_ agent: AgentFile) {
        agentError = nil
        do {
            agentContent = try String(contentsOf: agent.url, encoding: .utf8)
            selectedAgent = agent
            isEditing = false
            showAgentSheet = true
        } catch {
            agentError = "Failed to read \(agent.name): \(error.localizedDescription)"
        }
    }

    private func editAgent(_ agent: AgentFile) {
        agentError = nil
        do {
            agentContent = try String(contentsOf: agent.url, encoding: .utf8)
            selectedAgent = agent
            isEditing = true
            showAgentSheet = true
        } catch {
            agentError = "Failed to read \(agent.name): \(error.localizedDescription)"
        }
    }

    private func saveAgent() {
        guard let agent = selectedAgent else { return }
        agentError = nil
        do {
            try agentContent.write(to: agent.url, atomically: true, encoding: .utf8)
            showAgentSheet = false
        } catch {
            agentError = "Failed to save \(agent.name): \(error.localizedDescription)"
        }
    }

    private func createNewAgent() {
        agentError = nil
        let safeName = newAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else {
            agentError = "Agent name cannot be empty"
            return
        }

        let filename = safeName.hasSuffix(".md") ? safeName : "\(safeName).md"
        let fileURL = agentsDirectory.appendingPathComponent(filename)

        let fm = FileManager.default

        // Create agents directory if needed
        if !fm.fileExists(atPath: agentsDirectory.path) {
            do {
                try fm.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
            } catch {
                agentError = "Failed to create agents directory: \(error.localizedDescription)"
                return
            }
        }

        // Check if file already exists
        if fm.fileExists(atPath: fileURL.path) {
            agentError = "Agent '\(safeName)' already exists"
            return
        }

        do {
            try newAgentContent.write(to: fileURL, atomically: true, encoding: .utf8)
            showNewAgentSheet = false
            newAgentName = ""
            newAgentContent = "# Agent Name\n\nDescribe the agent's purpose and behavior here.\n"
            loadSystemAgents()
        } catch {
            agentError = "Failed to create agent: \(error.localizedDescription)"
        }
    }
}

// MARK: - Agent View/Edit Sheet

private struct AgentViewSheet: View {
    let agent: AgentFile?
    @Binding var content: String
    let isEditing: Bool
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent?.name ?? "Agent")
                        .font(.headline)
                    Text(isEditing ? "Editing" : "Read-only")
                        .font(.caption)
                        .foregroundStyle(Color.ds.secondary)
                }

                Spacer()

                if isEditing {
                    Button("Save") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.ds.surface.opacity(0.5))

            Divider()

            // Content
            if isEditing {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color.ds.bg0)
    }
}

// MARK: - New Agent Sheet

private struct NewAgentSheet: View {
    @Binding var name: String
    @Binding var content: String
    let onCreate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Agent")
                    .font(.headline)

                Spacer()

                Button("Create") {
                    onCreate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.ds.surface.opacity(0.5))

            Divider()

            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Name field
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Agent Name")
                        .font(.caption)
                        .foregroundStyle(Color.ds.secondary)
                    TextField("my-agent", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Content editor
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Agent Definition")
                        .font(.caption)
                        .foregroundStyle(Color.ds.secondary)
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.ds.surface.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color.ds.bg0)
    }
}

#Preview {
    AgentsSettingsView()
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}
