//
//  CLIPowerSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

/// Known Claude CLI flags with descriptions
struct CLIFlag: Identifiable {
    let id: String
    let flag: String
    let description: String
    var isEnabled: Bool = false
    var value: String? = nil  // For flags that take values
    let hasValue: Bool  // Whether this flag accepts a value

    init(id: String, flag: String, description: String, isEnabled: Bool = false, value: String? = nil, hasValue: Bool = false) {
        self.id = id
        self.flag = flag
        self.description = description
        self.isEnabled = isEnabled
        self.value = value
        self.hasValue = hasValue
    }

    static let knownFlags: [CLIFlag] = [
        CLIFlag(id: "verbose", flag: "--verbose", description: "Enable verbose output"),
        CLIFlag(id: "print-cost", flag: "--print-cost", description: "Print cost after completion"),
        CLIFlag(id: "max-turns", flag: "--max-turns", description: "Maximum conversation turns", hasValue: true),
        CLIFlag(id: "model", flag: "--model", description: "Model to use (e.g., claude-sonnet-4-20250514)", hasValue: true),
        CLIFlag(id: "output-format", flag: "--output-format", description: "Output format (stream-json, json, text)", hasValue: true),
        CLIFlag(id: "skip-permissions", flag: "--dangerously-skip-permissions", description: "Skip permission prompts (dangerous)"),
        CLIFlag(id: "no-browser", flag: "--no-browser", description: "Disable browser auto-open during auth"),
        CLIFlag(id: "mcp-debug", flag: "--mcp-debug", description: "Enable MCP server debug logging")
    ]
}

/// Known Claude Code tools with their capabilities
struct CLITool: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let canRead: Bool
    let canWrite: Bool
    var isEnabled: Bool = false
    var readAllowed: Bool = true
    var writeAllowed: Bool = true

    static let builtInTools: [CLITool] = [
        CLITool(id: "Bash", name: "Bash", description: "Execute shell commands", canRead: true, canWrite: true),
        CLITool(id: "Read", name: "Read", description: "Read file contents", canRead: true, canWrite: false),
        CLITool(id: "Write", name: "Write", description: "Write/create files", canRead: false, canWrite: true),
        CLITool(id: "Edit", name: "Edit", description: "Edit existing files", canRead: true, canWrite: true),
        CLITool(id: "Grep", name: "Grep", description: "Search file contents", canRead: true, canWrite: false),
        CLITool(id: "Glob", name: "Glob", description: "Find files by pattern", canRead: true, canWrite: false),
        CLITool(id: "WebFetch", name: "WebFetch", description: "Fetch web pages", canRead: true, canWrite: false),
        CLITool(id: "WebSearch", name: "WebSearch", description: "Search the web", canRead: true, canWrite: false),
        CLITool(id: "TodoWrite", name: "TodoWrite", description: "Manage task lists", canRead: false, canWrite: true),
        CLITool(id: "NotebookEdit", name: "NotebookEdit", description: "Edit Jupyter notebooks", canRead: true, canWrite: true),
        CLITool(id: "MCPSearch", name: "MCPSearch", description: "Search MCP tools", canRead: true, canWrite: false),
        CLITool(id: "Skill", name: "Skill", description: "Execute skills", canRead: true, canWrite: true)
    ]
}

/// Settings view for CLI power user configuration.
/// Includes preset selection, tool permissions, path restrictions, and raw CLI flags.
struct CLIPowerSettingsView: View {
    @AppStorage("cliPreset") private var preset: String = "standard"

    @State private var tools: [CLITool] = CLITool.builtInTools
    @State private var cliFlags: [CLIFlag] = CLIFlag.knownFlags
    @State private var customToolName: String = ""
    @State private var allowedPaths: [String] = []
    @State private var newPath: String = ""
    @State private var showingFolderPicker = false
    @State private var newFlagName: String = ""
    @State private var newFlagDescription: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Presets Section
                FormSection(
                    title: "Presets",
                    description: "Quick configuration profiles for common use cases"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Picker("Preset", selection: $preset) {
                            Text("Minimal (safe only)").tag("minimal")
                            Text("Standard").tag("standard")
                            Text("Full (all tools)").tag("full")
                            Text("Custom").tag("custom")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: preset) { _, newValue in
                            applyPreset(newValue)
                        }

                        Text(presetDescription)
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Tools Section
                FormSection(
                    title: "Allowed Tools",
                    description: "Select which tools the CLI can invoke and their permissions"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        // Tool list
                        ForEach($tools) { $tool in
                            ToolPermissionRow(tool: $tool)
                        }

                        Divider()
                            .padding(.vertical, DSSpacing.xs)

                        // Add custom tool
                        HStack(spacing: DSSpacing.sm) {
                            GlassTextField(
                                "Custom tool name",
                                text: $customToolName
                            )

                            Button {
                                addCustomTool()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .disabled(customToolName.isEmpty)
                        }

                        Text("Add custom MCP tools by name")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Path Restrictions Section
                FormSection(
                    title: "Path Restrictions",
                    description: "Limit file access to specific directories"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        // Path list
                        if allowedPaths.isEmpty {
                            Text("No restrictions (full filesystem access)")
                                .dsTextStyle(.body, color: .ds.secondary)
                                .italic()
                        } else {
                            ForEach(allowedPaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(Color.ds.secondary)

                                    Text(path)
                                        .dsTextStyle(.body)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Button {
                                        removePath(path)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.ds.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Divider()
                            .padding(.vertical, DSSpacing.xs)

                        // Add path
                        HStack(spacing: DSSpacing.sm) {
                            Button("Add Folder...") {
                                showingFolderPicker = true
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                }

                // CLI Flags Section
                FormSection(
                    title: "CLI Flags",
                    description: "Enable specific CLI flags for all invocations"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        ForEach($cliFlags) { $flag in
                            CLIFlagRow(
                                flag: $flag,
                                isCustom: !CLIFlag.knownFlags.contains(where: { $0.id == flag.id }),
                                onDelete: {
                                    cliFlags.removeAll { $0.id == flag.id }
                                }
                            )
                        }

                        Divider()
                            .padding(.vertical, DSSpacing.xs)

                        // Add custom flag
                        HStack(spacing: DSSpacing.sm) {
                            GlassTextField("--custom-flag", text: $newFlagName)

                            GlassTextField("Description (optional)", text: $newFlagDescription)

                            Button {
                                addCustomFlag()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .disabled(newFlagName.isEmpty)
                        }

                        Text("Add custom CLI flags not in the predefined list")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Export/Import Section
                FormSection(
                    title: "Configuration",
                    description: "Export or import your CLI power settings"
                ) {
                    HStack(spacing: DSSpacing.md) {
                        Button("Export Settings") {
                            exportSettings()
                        }
                        .buttonStyle(.bordered)

                        Button("Import Settings") {
                            importSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if url.startAccessingSecurityScopedResource() {
                    allowedPaths.append(url.path)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        .onAppear {
            applyPreset(preset)
        }
    }

    // MARK: - Computed Properties

    private var presetDescription: String {
        switch preset {
        case "minimal": return "Read-only tools: Read, Grep, Glob"
        case "standard": return "Common tools with write confirmation: Read, Write, Edit, Grep, Glob, Bash"
        case "full": return "All tools enabled with full permissions"
        case "custom": return "Custom configuration - modify tools individually"
        default: return ""
        }
    }

    // MARK: - Actions

    private func applyPreset(_ presetName: String) {
        switch presetName {
        case "minimal":
            tools = tools.map { tool in
                var t = tool
                t.isEnabled = ["Read", "Grep", "Glob"].contains(tool.id)
                t.writeAllowed = false
                return t
            }
        case "standard":
            tools = tools.map { tool in
                var t = tool
                t.isEnabled = ["Read", "Write", "Edit", "Grep", "Glob", "Bash"].contains(tool.id)
                t.readAllowed = true
                t.writeAllowed = true
                return t
            }
        case "full":
            tools = tools.map { tool in
                var t = tool
                t.isEnabled = true
                t.readAllowed = true
                t.writeAllowed = true
                return t
            }
        default:
            break // Custom - don't change
        }
    }

    private func addCustomTool() {
        guard !customToolName.isEmpty else { return }
        let newTool = CLITool(
            id: customToolName,
            name: customToolName,
            description: "Custom tool",
            canRead: true,
            canWrite: true,
            isEnabled: true
        )
        tools.append(newTool)
        customToolName = ""
        preset = "custom"
    }

    private func removePath(_ path: String) {
        allowedPaths.removeAll { $0 == path }
    }

    private func addCustomFlag() {
        guard !newFlagName.isEmpty else { return }
        let flag = CLIFlag(
            id: UUID().uuidString,
            flag: newFlagName.hasPrefix("--") ? newFlagName : "--\(newFlagName)",
            description: newFlagDescription.isEmpty ? "Custom flag" : newFlagDescription,
            isEnabled: true,
            hasValue: false
        )
        cliFlags.append(flag)
        newFlagName = ""
        newFlagDescription = ""
    }

    private func exportSettings() {
        print("Export settings action triggered")
        // TODO: Implement export to JSON file
    }

    private func importSettings() {
        print("Import settings action triggered")
        // TODO: Implement import from JSON file
    }
}

// MARK: - Tool Permission Row

private struct ToolPermissionRow: View {
    @Binding var tool: CLITool

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            // Enable checkbox
            Toggle("", isOn: $tool.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // Tool name and description
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .dsTextStyle(.body)
                    .foregroundStyle(tool.isEnabled ? Color.ds.foreground : Color.ds.secondary)

                Text(tool.description)
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }

            Spacer()

            // Permission toggles (only if tool is enabled)
            if tool.isEnabled {
                HStack(spacing: DSSpacing.sm) {
                    if tool.canRead {
                        PermissionBadge(
                            label: "R",
                            isEnabled: tool.readAllowed,
                            color: .blue
                        ) {
                            tool.readAllowed.toggle()
                        }
                    }

                    if tool.canWrite {
                        PermissionBadge(
                            label: "W",
                            isEnabled: tool.writeAllowed,
                            color: .orange
                        ) {
                            tool.writeAllowed.toggle()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Permission Badge

private struct PermissionBadge: View {
    let label: String
    let isEnabled: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(isEnabled ? .white : color)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(isEnabled ? color : color.opacity(0.2))
            )
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - CLI Flag Row

private struct CLIFlagRow: View {
    @Binding var flag: CLIFlag
    let isCustom: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Toggle("", isOn: $flag.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(flag.flag)
                    .dsTextStyle(.body)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(flag.isEnabled ? Color.ds.foreground : Color.ds.secondary)

                Text(flag.description)
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }

            Spacer()

            // Value field for flags that accept values
            if flag.hasValue && flag.isEnabled {
                GlassTextField(
                    "value",
                    text: Binding(
                        get: { flag.value ?? "" },
                        set: { flag.value = $0.isEmpty ? nil : $0 }
                    )
                )
                .frame(width: 120)
            }

            // Delete button for custom flags only
            if isCustom {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ds.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CLIPowerSettingsView()
        .frame(width: 600, height: 800)
        .background(Color.ds.bg0)
}
