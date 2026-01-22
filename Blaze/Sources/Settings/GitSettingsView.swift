import SwiftUI

/// Git command with auto-run permission setting
struct GitCommand: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let isDestructive: Bool
    var autoRunAllowed: Bool = false

    static let standardCommands: [GitCommand] = [
        GitCommand(id: "status", name: "status", description: "Show working tree status", isDestructive: false, autoRunAllowed: true),
        GitCommand(id: "diff", name: "diff", description: "Show changes", isDestructive: false, autoRunAllowed: true),
        GitCommand(id: "log", name: "log", description: "Show commit history", isDestructive: false, autoRunAllowed: true),
        GitCommand(id: "add", name: "add", description: "Stage changes", isDestructive: false, autoRunAllowed: true),
        GitCommand(id: "commit", name: "commit", description: "Create a commit", isDestructive: false, autoRunAllowed: false),
        GitCommand(id: "push", name: "push", description: "Push to remote", isDestructive: true, autoRunAllowed: false),
        GitCommand(id: "pull", name: "pull", description: "Pull from remote", isDestructive: false, autoRunAllowed: false),
        GitCommand(id: "fetch", name: "fetch", description: "Fetch from remote", isDestructive: false, autoRunAllowed: true),
        GitCommand(id: "branch", name: "branch", description: "List/create branches", isDestructive: false, autoRunAllowed: true),
        GitCommand(id: "checkout", name: "checkout", description: "Switch branches/restore files", isDestructive: false, autoRunAllowed: false),
        GitCommand(id: "merge", name: "merge", description: "Merge branches", isDestructive: true, autoRunAllowed: false),
        GitCommand(id: "rebase", name: "rebase", description: "Reapply commits", isDestructive: true, autoRunAllowed: false),
        GitCommand(id: "stash", name: "stash", description: "Stash changes", isDestructive: false, autoRunAllowed: true)
    ]
}

struct GitSettingsView: View {
    @AppStorage("gitAutoRun") private var autoRun: Bool = false
    @AppStorage("commitStyle") private var commitStyle: String = "conventional"
    @AppStorage("includeCoAuthor") private var coAuthor: Bool = true
    @AppStorage("autoStash") private var autoStash: Bool = true
    @AppStorage("worktreePerTask") private var worktree: Bool = false

    @State private var commands: [GitCommand] = GitCommand.standardCommands
    @State private var customCommand: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Warning banner when auto-run is enabled
                if autoRun {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Auto-run may execute git commands without confirmation")
                        Spacer()
                    }
                    .foregroundStyle(Color.ds.warning)
                    .padding(DSSpacing.sm)
                    .background(Color.ds.warning.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Automation Section
                FormSection(
                    title: "Automation",
                    description: "Control automatic execution of git commands"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        GlassToggle(
                            "Auto-run Git Commands",
                            isOn: $autoRun,
                            description: "Allow certain git commands to run without confirmation"
                        )

                        // Command permission list (shown when auto-run is enabled)
                        if autoRun {
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                Text("Command Permissions")
                                    .dsTextStyle(.caption, color: .ds.secondary)
                                    .padding(.top, DSSpacing.sm)

                                ForEach($commands) { $command in
                                    GitCommandRow(command: $command)
                                }

                                Divider()
                                    .padding(.vertical, DSSpacing.xs)

                                // Add custom command
                                HStack(spacing: DSSpacing.sm) {
                                    GlassTextField(
                                        "Custom command",
                                        text: $customCommand
                                    )

                                    Button {
                                        addCustomCommand()
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(customCommand.isEmpty)
                                }
                            }
                            .padding(.leading, DSSpacing.md)
                        }
                    }
                }

                // Commit Style Section
                FormSection(
                    title: "Commit Style",
                    description: "Configure how commits are formatted"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            Text("Message Format")
                                .dsTextStyle(.body)
                            Spacer()
                            Picker("Style", selection: $commitStyle) {
                                Text("Conventional").tag("conventional")
                                Text("Free-form").tag("freeform")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 200)
                        }

                        Text(commitStyle == "conventional"
                            ? "Uses prefixes like feat:, fix:, docs:, etc."
                            : "No enforced format for commit messages"
                        )
                        .dsTextStyle(.caption, color: .ds.tertiary)

                        GlassToggle(
                            "Include Co-Author",
                            isOn: $coAuthor,
                            description: "Add Claude attribution to commits"
                        )
                    }
                }

                // Advanced Section
                FormSection(
                    title: "Advanced",
                    description: "Additional git workflow options"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        GlassToggle(
                            "Auto-Stash on Branch Switch",
                            isOn: $autoStash,
                            description: "Automatically stash uncommitted changes when switching branches"
                        )

                        GlassToggle(
                            "Worktree per Task",
                            isOn: $worktree,
                            description: "Experimental: Isolate tasks in separate worktrees"
                        )

                        if worktree {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color.ds.secondary)
                                Text("Each task will be worked on in its own git worktree")
                                    .dsTextStyle(.caption, color: .ds.secondary)
                            }
                            .padding(.leading, DSSpacing.md)
                        }
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Actions

    private func addCustomCommand() {
        guard !customCommand.isEmpty else { return }
        let newCommand = GitCommand(
            id: customCommand,
            name: customCommand,
            description: "Custom command",
            isDestructive: false,
            autoRunAllowed: false
        )
        commands.append(newCommand)
        customCommand = ""
    }
}

// MARK: - Git Command Row

private struct GitCommandRow: View {
    @Binding var command: GitCommand

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            // Auto-run toggle
            Toggle("", isOn: $command.autoRunAllowed)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // Command name
            Text("git \(command.name)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(command.autoRunAllowed ? Color.ds.foreground : Color.ds.secondary)

            // Destructive warning badge
            if command.isDestructive {
                Text("DESTRUCTIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ds.negative)
                    .clipShape(Capsule())
            }

            Spacer()

            // Description
            Text(command.description)
                .dsTextStyle(.caption, color: .ds.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GitSettingsView()
        .frame(width: 600, height: 800)
        .background(Color.ds.bg0)
}
