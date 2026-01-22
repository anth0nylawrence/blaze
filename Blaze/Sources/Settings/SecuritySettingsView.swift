//
//  SecuritySettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - Shell Command Permission

/// Permission level for a shell command
enum CommandPermission: String, CaseIterable, Identifiable {
    case read = "Read"
    case readWrite = "Read+Write"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .read: return "eye"
        case .readWrite: return "pencil"
        }
    }

    /// Convert to model permission level
    var modelPermission: CommandPermissionLevel {
        switch self {
        case .read: return .read
        case .readWrite: return .readWrite
        }
    }

    /// Create from model permission level
    init(from modelPermission: CommandPermissionLevel) {
        switch modelPermission {
        case .read: self = .read
        case .readWrite: self = .readWrite
        }
    }
}

/// Shell command with permission setting
struct ShellCommand: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let defaultPermission: CommandPermission
    var isEnabled: Bool = false
    var permission: CommandPermission

    init(
        id: String,
        name: String,
        description: String,
        defaultPermission: CommandPermission,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultPermission = defaultPermission
        self.isEnabled = isEnabled
        self.permission = defaultPermission
    }

    /// Standard shell commands with sensible defaults
    static let standardCommands: [ShellCommand] = [
        // Read-only commands
        ShellCommand(id: "ls", name: "ls", description: "List directory contents", defaultPermission: .read),
        ShellCommand(id: "cat", name: "cat", description: "Display file contents", defaultPermission: .read),
        ShellCommand(id: "head", name: "head", description: "Show first lines of file", defaultPermission: .read),
        ShellCommand(id: "tail", name: "tail", description: "Show last lines of file", defaultPermission: .read),
        ShellCommand(id: "grep", name: "grep", description: "Search text patterns", defaultPermission: .read),
        ShellCommand(id: "find", name: "find", description: "Find files and directories", defaultPermission: .read),
        ShellCommand(id: "pwd", name: "pwd", description: "Print working directory", defaultPermission: .read),
        ShellCommand(id: "which", name: "which", description: "Locate a command", defaultPermission: .read),
        ShellCommand(id: "wc", name: "wc", description: "Word, line, character count", defaultPermission: .read),
        ShellCommand(id: "file", name: "file", description: "Determine file type", defaultPermission: .read),
        ShellCommand(id: "diff", name: "diff", description: "Compare files", defaultPermission: .read),
        ShellCommand(id: "tree", name: "tree", description: "Display directory tree", defaultPermission: .read),

        // Write/modify commands
        ShellCommand(id: "mkdir", name: "mkdir", description: "Create directories", defaultPermission: .readWrite),
        ShellCommand(id: "rm", name: "rm", description: "Remove files/directories", defaultPermission: .readWrite),
        ShellCommand(id: "cp", name: "cp", description: "Copy files", defaultPermission: .readWrite),
        ShellCommand(id: "mv", name: "mv", description: "Move/rename files", defaultPermission: .readWrite),
        ShellCommand(id: "touch", name: "touch", description: "Create empty file", defaultPermission: .readWrite),
        ShellCommand(id: "chmod", name: "chmod", description: "Change permissions", defaultPermission: .readWrite),
        ShellCommand(id: "echo", name: "echo", description: "Output text (can redirect)", defaultPermission: .readWrite),
        ShellCommand(id: "sed", name: "sed", description: "Stream editor", defaultPermission: .readWrite),
        ShellCommand(id: "awk", name: "awk", description: "Pattern processing", defaultPermission: .readWrite),
    ]
}

// MARK: - Security Settings View

/// Security settings for trust modes, command allowlists, and governance policies.
///
/// These settings control how Blaze interacts with Claude Code CLI and other engines.
/// The trust mode directly maps to CLI flags when spawning the engine process.
struct SecuritySettingsView: View {
    // MARK: - State

    /// Trust mode stored in UserDefaults (legacy compatibility)
    @AppStorage("trustMode") private var trustModeRaw: String = "review"

    /// The SecuritySettings model for persistence
    @State private var settings: SecuritySettings = .load()

    @State private var showYoloConfirmation = false
    @State private var pendingTrustMode: SecurityTrustMode = .review

    @State private var commands: [ShellCommand] = ShellCommand.standardCommands
    @State private var customCommandName: String = ""
    @State private var customCommandPermission: CommandPermission = .read
    @State private var showGitRedirectAlert = false
    @State private var newTrustedTool: String = ""

    // MARK: - Computed

    /// Current trust mode from settings
    private var trustMode: SecurityTrustMode {
        get { settings.trustMode }
        set {
            settings.trustMode = newValue
            settings.save()
            // Keep legacy @AppStorage in sync
            trustModeRaw = newValue.rawValue
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                // Trust Mode Section
                trustModeSection

                // Trusted Tools Section (only shown in Trusted mode)
                if settings.trustMode == .trusted {
                    trustedToolsSection
                }

                // CLI Behavior Explanation
                cliBehaviorSection

                // Command Allowlist Section
                commandAllowlistSection

                // Auto-Approve Patterns Section
                autoApprovePatternsSection

                // Reset Section
                resetSection
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadFromSettings()
        }
        .alert("Enable YOLO Mode?", isPresented: $showYoloConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingTrustMode = settings.trustMode
            }
            Button("Enable YOLO", role: .destructive) {
                settings.trustMode = .yolo
                settings.save()
                trustModeRaw = "yolo"
            }
        } message: {
            Text("YOLO mode uses --dangerously-skip-permissions to bypass ALL Claude Code safety prompts.\n\nThe agent can execute any command, write any file, and make network requests without asking.\n\nThis is extremely dangerous. Only use if you fully understand and accept the risks.")
        }
        .alert("Git Commands", isPresented: $showGitRedirectAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Git commands are configured in Git Settings. Navigate there to manage git command permissions.")
        }
    }

    // MARK: - Trust Mode Section

    private var trustModeSection: some View {
        FormSection(
            title: "Trust Mode",
            description: "Choose your security level for agent operations"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Picker("Mode", selection: $pendingTrustMode) {
                    ForEach(SecurityTrustMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.displayName)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: pendingTrustMode) { _, newValue in
                    if newValue == .yolo {
                        showYoloConfirmation = true
                    } else {
                        settings.trustMode = newValue
                        settings.save()
                        trustModeRaw = newValue.rawValue
                    }
                }

                // Description for selected mode
                TrustModeDescription(mode: settings.trustMode)

                // Warning banner when YOLO mode is active
                if settings.trustMode == .yolo {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ds.warning)
                        Text("YOLO mode is active. CLI runs with --dangerously-skip-permissions")
                            .dsTextStyle(.caption, color: .ds.warning)
                    }
                    .padding(DSSpacing.sm)
                    .background(Color.ds.warning.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }

                // Info banner for Trusted mode
                if settings.trustMode == .trusted {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Color.ds.accent)
                        Text("Trusted mode: Tools are added to the trusted list when you approve them")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                    .padding(DSSpacing.sm)
                    .background(Color.ds.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }

                if settings.trustMode == .review {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.ds.positive)
                        Text("Recommended for most users")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Trusted Tools Section

    private var trustedToolsSection: some View {
        FormSection(
            title: "Trusted Tools",
            description: "Tools that auto-approve after being granted once"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                if settings.trustedTools.isEmpty {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.ds.secondary)
                        Text("No tools trusted yet. Tools are added when you approve them during a session.")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                    .padding(.vertical, DSSpacing.sm)
                } else {
                    // List of trusted tools
                    ForEach(settings.trustedTools.sorted(), id: \.self) { tool in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.ds.positive)
                            Text(tool)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                settings.revokeToolTrust(tool)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.ds.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .help("Revoke trust for \(tool)")
                        }
                        .padding(.vertical, 2)
                    }

                    Divider()
                        .padding(.vertical, DSSpacing.xs)
                }

                // Add tool manually
                HStack(spacing: DSSpacing.sm) {
                    GlassTextField(
                        "Tool name (e.g., Bash, Write)",
                        text: $newTrustedTool,
                        icon: "hammer"
                    )
                    .font(.system(.body, design: .monospaced))

                    Button {
                        addTrustedTool()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.ds.accent)
                    }
                    .buttonStyle(.borderless)
                    .disabled(newTrustedTool.isEmpty)
                }

                // Common tools quick-add
                HStack(spacing: DSSpacing.xs) {
                    Text("Quick add:")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    ForEach(["Bash", "Read", "Write", "Edit", "Glob", "Grep"], id: \.self) { tool in
                        if !settings.trustedTools.contains(tool) {
                            Button(tool) {
                                settings.grantToolTrust(tool)
                            }
                            .buttonStyle(.borderless)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.ds.accent)
                        }
                    }
                }
                .padding(.top, DSSpacing.xs)

                // Clear all button
                if !settings.trustedTools.isEmpty {
                    Button("Clear All Trusted Tools") {
                        settings.clearTrustedTools()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.ds.warning)
                    .padding(.top, DSSpacing.sm)
                }
            }
        }
    }

    // MARK: - CLI Behavior Section

    private var cliBehaviorSection: some View {
        FormSection(
            title: "CLI Flag Mapping",
            description: "How trust mode translates to Claude Code CLI flags"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Current mode indicator
                HStack(spacing: DSSpacing.sm) {
                    Text("Current:")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    Text(settings.trustMode.displayName)
                        .dsTextStyle(.body)
                        .fontWeight(.medium)
                }

                Divider()

                // CLI flag display
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("CLI Arguments:")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    let flags = settings.cliFlags()
                    if flags.isEmpty {
                        Text("(none - default behavior)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.ds.tertiary)
                    } else {
                        Text(flags.joined(separator: " "))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.ds.accent)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                // Mode reference table
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Reference:")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    ForEach(SecurityTrustMode.allCases, id: \.self) { mode in
                        HStack(alignment: .top, spacing: DSSpacing.sm) {
                            Image(systemName: mode == settings.trustMode ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(mode == settings.trustMode ? Color.ds.accent : Color.ds.tertiary)
                                .frame(width: 16)

                            Text(mode.displayName)
                                .dsTextStyle(.caption)
                                .frame(width: 80, alignment: .leading)

                            Text(mode.cliFlagDescription)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.ds.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Command Allowlist Section

    private var commandAllowlistSection: some View {
        FormSection(
            title: "Command Allowlist",
            description: "Commands that can run without confirmation when enabled"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Sandbox mode notice
                if settings.trustMode == .sandbox {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.ds.accent)
                        Text("In Sandbox mode, no commands can execute. Allowlist is disabled.")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                    .padding(DSSpacing.sm)
                    .background(Color.ds.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }

                // Command list header
                HStack {
                    Text("Command")
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text("Description")
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Permission")
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .frame(width: 120, alignment: .trailing)
                }
                .padding(.horizontal, DSSpacing.xs)

                Divider()

                // Command rows
                ForEach($commands) { $command in
                    ShellCommandRow(command: $command, isDisabled: settings.trustMode == .sandbox)
                        .onChange(of: command.isEnabled) { _, _ in
                            syncCommandsToSettings()
                        }
                        .onChange(of: command.permission) { _, _ in
                            syncCommandsToSettings()
                        }
                }

                Divider()
                    .padding(.vertical, DSSpacing.xs)

                // Add custom command
                HStack(spacing: DSSpacing.sm) {
                    Toggle("", isOn: .constant(true))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .hidden()
                        .frame(width: 20)

                    GlassTextField(
                        "Custom command",
                        text: $customCommandName,
                        icon: "terminal"
                    )
                    .font(.system(.body, design: .monospaced))
                    .disabled(settings.trustMode == .sandbox)
                    .onChange(of: customCommandName) { _, newValue in
                        // Check for git command and show redirect alert
                        if newValue.lowercased().trimmingCharacters(in: .whitespaces).hasPrefix("git") {
                            showGitRedirectAlert = true
                            customCommandName = ""
                        }
                    }

                    Picker("", selection: $customCommandPermission) {
                        ForEach(CommandPermission.allCases) { perm in
                            Text(perm.rawValue).tag(perm)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                    .disabled(settings.trustMode == .sandbox)

                    Button {
                        addCustomCommand()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.ds.accent)
                    }
                    .buttonStyle(.borderless)
                    .disabled(customCommandName.isEmpty || settings.trustMode == .sandbox)
                }

                // Git redirect note
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(Color.ds.secondary)
                    Text("For git commands, see ")
                        .dsTextStyle(.caption, color: .ds.secondary)
                    Text("Git Settings")
                        .dsTextStyle(.caption, color: .ds.accent)
                }
                .padding(.top, DSSpacing.xs)

                // Summary of enabled commands
                if !enabledCommandsSummary.isEmpty && settings.trustMode != .sandbox {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.ds.positive)
                        Text("Allowed: \(enabledCommandsSummary)")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                    .padding(.top, DSSpacing.sm)
                }
            }
        }
    }

    // MARK: - Auto-Approve Patterns Section

    private var autoApprovePatternsSection: some View {
        FormSection(
            title: "Auto-Approve Patterns",
            description: "File patterns that skip confirmation for read/write"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                if settings.trustMode == .sandbox {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.ds.accent)
                        Text("In Sandbox mode, no writes are allowed. Patterns are disabled.")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                    .padding(DSSpacing.sm)
                    .background(Color.ds.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                } else if settings.trustMode == .yolo {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.ds.warning)
                        Text("In YOLO mode, all files are auto-approved. Patterns are ignored.")
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                    .padding(DSSpacing.sm)
                    .background(Color.ds.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }

                // Pattern examples
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Pattern syntax:")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    Group {
                        Text("*.swift    - All Swift files")
                        Text("src/*      - Files in src/ directory")
                        Text("**/*.ts    - TypeScript files anywhere")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.ds.tertiary)
                }

                // Current patterns (placeholder for future implementation)
                if settings.autoApprovePatterns.isEmpty {
                    Text("No patterns configured")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                        .padding(.vertical, DSSpacing.sm)
                } else {
                    ForEach(settings.autoApprovePatterns, id: \.self) { pattern in
                        HStack {
                            Text(pattern)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                removePattern(pattern)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.ds.tertiary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                // Note about future implementation
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(Color.ds.secondary)
                    Text("Pattern editor coming in a future release")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
                .padding(.top, DSSpacing.xs)
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        FormSection {
            GlassButton(
                "Reset to Defaults",
                icon: "arrow.counterclockwise",
                style: .secondary,
                size: .medium,
                action: resetToDefaults
            )
        }
    }

    // MARK: - Computed Properties

    private var enabledCommandsSummary: String {
        commands
            .filter { $0.isEnabled }
            .map { "\($0.name) (\($0.permission.rawValue))" }
            .joined(separator: ", ")
    }

    // MARK: - Actions

    private func loadFromSettings() {
        settings = .load()
        pendingTrustMode = settings.trustMode

        // Sync commands from settings allowlist
        for (index, command) in commands.enumerated() {
            if let permission = settings.commandAllowlist[command.name] {
                commands[index].isEnabled = true
                commands[index].permission = CommandPermission(from: permission)
            }
        }
    }

    private func syncCommandsToSettings() {
        var allowlist: [String: CommandPermissionLevel] = [:]
        for command in commands where command.isEnabled {
            allowlist[command.name] = command.permission.modelPermission
        }
        settings.commandAllowlist = allowlist
        settings.save()
    }

    private func addCustomCommand() {
        let trimmed = customCommandName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Don't add duplicates
        guard !commands.contains(where: { $0.name == trimmed }) else {
            customCommandName = ""
            return
        }

        let newCommand = ShellCommand(
            id: trimmed,
            name: trimmed,
            description: "Custom command",
            defaultPermission: customCommandPermission,
            isEnabled: true
        )
        commands.append(newCommand)
        customCommandName = ""

        // Sync to settings
        syncCommandsToSettings()
    }

    private func removePattern(_ pattern: String) {
        settings.autoApprovePatterns.removeAll { $0 == pattern }
        settings.save()
    }

    private func addTrustedTool() {
        let trimmed = newTrustedTool.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.grantToolTrust(trimmed)
        newTrustedTool = ""
    }

    private func resetToDefaults() {
        settings = .default
        settings.save()
        trustModeRaw = "review"
        pendingTrustMode = .review
        commands = ShellCommand.standardCommands
        customCommandName = ""
        newTrustedTool = ""
    }
}

// MARK: - Shell Command Row

private struct ShellCommandRow: View {
    @Binding var command: ShellCommand
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Enable toggle
            Toggle("", isOn: $command.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 20)
                .disabled(isDisabled)

            // Command name
            Text(command.name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(command.isEnabled && !isDisabled ? Color.ds.foreground : Color.ds.tertiary)
                .frame(width: 80, alignment: .leading)

            // Description
            Text(command.description)
                .dsTextStyle(.caption, color: command.isEnabled && !isDisabled ? .ds.secondary : .ds.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // Permission picker
            Picker("", selection: $command.permission) {
                ForEach(CommandPermission.allCases) { perm in
                    Label(perm.rawValue, systemImage: perm.icon)
                        .tag(perm)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .disabled(!command.isEnabled || isDisabled)
            .opacity(command.isEnabled && !isDisabled ? 1.0 : 0.5)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Trust Mode Description

private struct TrustModeDescription: View {
    let mode: SecurityTrustMode

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text(mode.displayName)
                .dsTextStyle(.body)
                .fontWeight(.medium)
            Text(mode.description)
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .padding(DSSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
    }
}

#Preview {
    SecuritySettingsView()
        .frame(width: 500, height: 700)
}
