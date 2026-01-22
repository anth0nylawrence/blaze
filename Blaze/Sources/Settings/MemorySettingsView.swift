import SwiftUI

struct MemorySettingsView: View {
    // System/User CLAUDE.md from ~/.claude/CLAUDE.md
    @State private var systemClaudeMd: String = ""
    @State private var systemClaudeMdPath: String = ""
    @State private var systemClaudeMdExists: Bool = false
    @State private var systemClaudeMdModified: Bool = false

    // Project CLAUDE.md from current project
    @State private var projectClaudeMd: String = ""
    @State private var projectClaudeMdPath: String = ""
    @State private var projectClaudeMdExists: Bool = false
    @State private var projectClaudeMdModified: Bool = false

    @AppStorage("autoClearThreshold") private var threshold: Int = 90
    @State private var showClearConfirmation = false
    @State private var contextUsagePercent: Int = 45 // Placeholder until wired to real data
    @State private var saveError: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // System/User CLAUDE.md Section
                FormSection(
                    title: "System Settings",
                    description: "Global instructions from ~/.claude/CLAUDE.md"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        // File path indicator
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: systemClaudeMdExists ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(systemClaudeMdExists ? Color.ds.positive : Color.ds.secondary)

                            Text(systemClaudeMdPath.isEmpty ? "~/.claude/CLAUDE.md" : systemClaudeMdPath)
                                .dsTextStyle(.caption, color: .ds.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if systemClaudeMdModified {
                                Text("Modified")
                                    .dsTextStyle(.caption, color: .ds.warning)
                            }
                        }

                        // Editor
                        TextEditor(text: $systemClaudeMd)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.ds.surface.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: systemClaudeMd) { _, _ in
                                systemClaudeMdModified = true
                            }

                        // Actions
                        HStack {
                            if !systemClaudeMdExists {
                                Button("Create File") {
                                    createSystemClaudeMd()
                                }
                                .buttonStyle(.bordered)
                            }

                            Spacer()

                            Button("Reload") {
                                loadSystemClaudeMd()
                            }
                            .buttonStyle(.borderless)

                            Button("Save") {
                                saveSystemClaudeMd()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!systemClaudeMdModified)
                        }
                    }
                }

                // Project CLAUDE.md Section
                FormSection(
                    title: "Project Settings",
                    description: "Project-specific instructions from CLAUDE.md in project root"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        // File path indicator
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: projectClaudeMdExists ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(projectClaudeMdExists ? Color.ds.positive : Color.ds.secondary)

                            Text(projectClaudeMdPath.isEmpty ? "No project open" : projectClaudeMdPath)
                                .dsTextStyle(.caption, color: .ds.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if projectClaudeMdModified {
                                Text("Modified")
                                    .dsTextStyle(.caption, color: .ds.warning)
                            }
                        }

                        // Editor
                        TextEditor(text: $projectClaudeMd)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.ds.surface.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: projectClaudeMd) { _, _ in
                                projectClaudeMdModified = true
                            }

                        // Actions
                        HStack {
                            if !projectClaudeMdExists && !projectClaudeMdPath.isEmpty {
                                Button("Create File") {
                                    createProjectClaudeMd()
                                }
                                .buttonStyle(.bordered)
                            }

                            Spacer()

                            Button("Reload") {
                                loadProjectClaudeMd()
                            }
                            .buttonStyle(.borderless)
                            .disabled(projectClaudeMdPath.isEmpty)

                            Button("Save") {
                                saveProjectClaudeMd()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!projectClaudeMdModified || projectClaudeMdPath.isEmpty)
                        }
                    }
                }

                // Error display
                if let error = saveError {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ds.negative)
                        Text(error)
                            .dsTextStyle(.caption, color: .ds.negative)
                    }
                }

                // Context Usage Section
                FormSection(
                    title: "Context Usage",
                    description: "Current conversation context window usage"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack {
                            Text("\(contextUsagePercent)%")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(contextUsagePercent)k / 100k tokens")
                                .font(.caption)
                                .foregroundColor(.ds.secondary)
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.ds.surface.opacity(0.3))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(contextUsageColor)
                                    .frame(
                                        width: geometry.size.width * CGFloat(contextUsagePercent) / 100,
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)
                    }
                }

                // Auto-Clear Settings Section
                FormSection(
                    title: "Context Management",
                    description: "Automatically manage context when usage gets high"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            Text("Auto-clear threshold")
                                .dsTextStyle(.body)
                            Spacer()
                            Text("\(threshold)%")
                                .dsTextStyle(.body, color: .ds.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(threshold) },
                                set: { threshold = Int($0) }
                            ),
                            in: 50...100,
                            step: 5
                        )

                        Text("Context will be cleared when usage exceeds \(threshold)%")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }

                    Divider()
                        .padding(.vertical, DSSpacing.sm)

                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Context Now")
                        }
                        .foregroundColor(.ds.negative)
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadSystemClaudeMd()
            loadProjectClaudeMd()
        }
        .alert("Clear Context?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearContext()
            }
        } message: {
            Text("This will clear the current conversation context. This action cannot be undone.")
        }
    }

    // MARK: - Computed Properties

    private var contextUsageColor: Color {
        switch contextUsagePercent {
        case 0..<70:
            return .ds.positive
        case 70..<threshold:
            return .ds.warning
        default:
            return .ds.negative
        }
    }

    // MARK: - System CLAUDE.md Actions

    private func loadSystemClaudeMd() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = homeDir.appendingPathComponent(".claude")
        let filePath = claudeDir.appendingPathComponent("CLAUDE.md")
        systemClaudeMdPath = filePath.path

        if FileManager.default.fileExists(atPath: filePath.path) {
            systemClaudeMdExists = true
            do {
                systemClaudeMd = try String(contentsOf: filePath, encoding: .utf8)
                systemClaudeMdModified = false
                saveError = nil
            } catch {
                saveError = "Failed to load system CLAUDE.md: \(error.localizedDescription)"
            }
        } else {
            systemClaudeMdExists = false
            systemClaudeMd = "# System Instructions\n\nAdd global instructions for Claude Code here.\n"
        }
    }

    private func saveSystemClaudeMd() {
        let url = URL(fileURLWithPath: systemClaudeMdPath)
        do {
            try systemClaudeMd.write(to: url, atomically: true, encoding: .utf8)
            systemClaudeMdModified = false
            systemClaudeMdExists = true
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func createSystemClaudeMd() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = homeDir.appendingPathComponent(".claude")

        do {
            // Create .claude directory if needed
            if !FileManager.default.fileExists(atPath: claudeDir.path) {
                try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            }
            saveSystemClaudeMd()
        } catch {
            saveError = "Failed to create directory: \(error.localizedDescription)"
        }
    }

    // MARK: - Project CLAUDE.md Actions

    private func loadProjectClaudeMd() {
        // TODO: Get actual project path from SessionStore or workspace manager
        // For now, use a placeholder path
        let projectDir = FileManager.default.currentDirectoryPath
        let filePath = URL(fileURLWithPath: projectDir).appendingPathComponent("CLAUDE.md")
        projectClaudeMdPath = filePath.path

        if FileManager.default.fileExists(atPath: filePath.path) {
            projectClaudeMdExists = true
            do {
                projectClaudeMd = try String(contentsOf: filePath, encoding: .utf8)
                projectClaudeMdModified = false
                saveError = nil
            } catch {
                saveError = "Failed to load project CLAUDE.md: \(error.localizedDescription)"
            }
        } else {
            projectClaudeMdExists = false
            projectClaudeMd = "# Project Context\n\nAdd project-specific instructions here.\n"
        }
    }

    private func saveProjectClaudeMd() {
        guard !projectClaudeMdPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectClaudeMdPath)
        do {
            try projectClaudeMd.write(to: url, atomically: true, encoding: .utf8)
            projectClaudeMdModified = false
            projectClaudeMdExists = true
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func createProjectClaudeMd() {
        saveProjectClaudeMd()
    }

    // MARK: - Context Actions

    private func clearContext() {
        // TODO: Wire to SessionStore context clearing
        print("Clear context triggered")
        contextUsagePercent = 0
    }
}

// MARK: - Preview

#Preview("Memory Settings") {
    MemorySettingsView()
        .frame(width: 600, height: 900)
        .background(Color.ds.bg0)
}
