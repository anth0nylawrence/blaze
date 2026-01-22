import SwiftUI

// MARK: - Session Deletion Alert

/// Enhanced session deletion confirmation with worktree cleanup options.
///
/// **Phase 2.10 - Polish:**
/// - Shows confirmation dialog before deletion
/// - If session has worktree, offers to delete it too
/// - Shows warning about unsaved changes if session is running
struct SessionDeletionAlert: ViewModifier {
    @Binding var isPresented: Bool
    let session: Session
    let onDelete: (Bool) -> Void  // Parameter: deleteWorktree

    @State private var deleteWorktree: Bool = true
    @State private var showForceDeleteOption: Bool = false
    @State private var worktreeDeletionFailed: Bool = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert(alertTitle, isPresented: $isPresented) {
                alertButtons
            } message: {
                alertMessage
            }
            .alert("Worktree Deletion Failed", isPresented: $worktreeDeletionFailed) {
                Button("Retry with Force") {
                    onDelete(true)
                }
                Button("Keep Worktree") {
                    onDelete(false)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Failed to delete the worktree. You can retry with force option or keep the worktree.")
            }
    }

    // MARK: - Alert Title

    private var alertTitle: String {
        if session.status == .running {
            return "Delete Running Session?"
        } else if session.hasWorktree {
            return "Delete Session and Worktree?"
        } else {
            return "Delete Session?"
        }
    }

    // MARK: - Alert Buttons

    @ViewBuilder
    private var alertButtons: some View {
        if session.hasWorktree {
            Button("Delete Session Only", role: .destructive) {
                onDelete(false)
            }

            Button("Delete Session & Worktree", role: .destructive) {
                onDelete(true)
            }

            Button("Cancel", role: .cancel) {}
        } else {
            Button("Delete", role: .destructive) {
                onDelete(false)
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Alert Message

    @ViewBuilder
    private var alertMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.status == .running {
                Text("Warning: This session is currently running. Deleting it will stop any active operations.")
            }

            Text("This will permanently delete \"\(session.name)\" and all its messages.")

            if session.hasWorktree {
                if let branchName = session.branchName {
                    Text("\nWorktree branch: \(branchName)")
                }
                Text("\nChoose whether to also delete the worktree directory and branch.")
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Shows a session deletion confirmation alert.
    func sessionDeletionAlert(
        isPresented: Binding<Bool>,
        session: Session,
        onDelete: @escaping (Bool) -> Void
    ) -> some View {
        self.modifier(SessionDeletionAlert(
            isPresented: isPresented,
            session: session,
            onDelete: onDelete
        ))
    }
}

// MARK: - Enhanced Delete Session Dialog View

/// A more detailed sheet-style deletion dialog for complex scenarios.
struct SessionDeletionSheet: View {
    let session: Session
    let onConfirm: (SessionDeletionOptions) -> Void
    let onCancel: () -> Void

    @State private var deleteWorktree: Bool = true
    @State private var forceDelete: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                // Warning if running
                if session.status == .running {
                    warningBanner
                }

                // Session info
                sessionInfo

                // Worktree options
                if session.hasWorktree {
                    worktreeOptions
                }
            }
            .padding(DSSpacing.lg)

            Divider()

            // Footer
            footer
        }
        .frame(width: 400)
        .background(Color.ds.bg1)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "trash")
                .foregroundStyle(Color.ds.negative)

            Text("Delete Session")
                .font(.headline)

            Spacer()
        }
        .padding(DSSpacing.md)
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ds.warning)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Session is running")
                    .dsTextStyle(.body, color: .ds.warning)
                    .fontWeight(.medium)

                Text("Active operations will be stopped.")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()
        }
        .padding(DSSpacing.sm)
        .background(Color.ds.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
    }

    // MARK: - Session Info

    private var sessionInfo: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Session Details", systemImage: "info.circle")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack {
                    Text("Name:")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                    Text(session.name)
                        .dsTextStyle(.body)
                }

                if let projectPath = session.originalProjectPath ?? session.projectPath {
                    HStack(alignment: .top) {
                        Text("Project:")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                        Text((projectPath as NSString).lastPathComponent)
                            .dsTextStyle(.monoSmall)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                HStack {
                    Text("Messages:")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                    Text("\(session.messages.count)")
                        .dsTextStyle(.body)
                }
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds.surface.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
    }

    // MARK: - Worktree Options

    private var worktreeOptions: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Worktree Cleanup", systemImage: "arrow.triangle.branch")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Toggle(isOn: $deleteWorktree) {
                    VStack(alignment: .leading) {
                        Text("Delete worktree and branch")
                            .dsTextStyle(.body)

                        if let branchName = session.branchName {
                            Text("Branch: \(branchName)")
                                .dsTextStyle(.monoSmall, color: .ds.tertiary)
                        }
                    }
                }
                .toggleStyle(.checkbox)

                if deleteWorktree {
                    Toggle(isOn: $forceDelete) {
                        VStack(alignment: .leading) {
                            Text("Force delete")
                                .dsTextStyle(.body)
                            Text("Use if worktree has uncommitted changes")
                                .dsTextStyle(.caption, color: .ds.tertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.leading, DSSpacing.lg)
                }
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds.surface.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button(role: .destructive) {
                let options = SessionDeletionOptions(
                    deleteWorktree: deleteWorktree,
                    forceDelete: forceDelete
                )
                onConfirm(options)
            } label: {
                Text("Delete")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ds.negative)
            .keyboardShortcut(.return)
        }
        .padding(DSSpacing.md)
    }
}

// MARK: - Session Deletion Options

/// Options for session deletion.
struct SessionDeletionOptions {
    let deleteWorktree: Bool
    let forceDelete: Bool
}

// MARK: - Previews

#Preview("Deletion Alert - With Worktree") {
    let session = Session(
        name: "Feature Branch",
        originalProjectPath: "/Users/dev/project",
        worktreePath: "/Users/dev/project/.blaze-worktrees/abc123",
        branchName: "blaze-session-abc123",
        status: .ready
    )

    return VStack {
        Text("Session with worktree")
    }
    .frame(width: 400, height: 300)
    .sessionDeletionAlert(
        isPresented: .constant(true),
        session: session,
        onDelete: { _ in }
    )
}

#Preview("Deletion Sheet") {
    let session = Session(
        name: "Feature Branch",
        originalProjectPath: "/Users/dev/project",
        worktreePath: "/Users/dev/project/.blaze-worktrees/abc123",
        branchName: "blaze-session-abc123",
        status: .running
    )

    return SessionDeletionSheet(
        session: session,
        onConfirm: { _ in },
        onCancel: {}
    )
}
