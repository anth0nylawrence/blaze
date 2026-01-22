import SwiftUI

// MARK: - Sessions Sidebar View

/// Tab 12: Quick session switcher sidebar with project grouping.
///
/// **Phase 2 Spec:**
/// - Quick session switcher (alternative to left sidebar)
/// - List recent sessions with project grouping
/// - Search/filter sessions by name or project
/// - Show session status (active/paused/archived)
/// - Actions: Switch to session, Archive, Delete
struct SessionsSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var groupedSessions: [String: [Session]] = [:]
    @State private var expandedProjects: Set<String> = []
    @State private var isLoading: Bool = false
    @State private var filterStatus: SessionFilterStatus = .all

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            headerView

            Divider()

            // Session list
            if isLoading {
                loadingView
            } else if filteredSessions.isEmpty {
                emptyView
            } else {
                sessionListView
            }
        }
        .task {
            await loadSessions()
        }
    }

    // MARK: - Computed Properties

    private var filteredSessions: [String: [Session]] {
        var result: [String: [Session]] = [:]

        // Group sessions directly from appState (reactive to changes)
        var grouped: [String: [Session]] = [:]
        for session in appState.sessions {
            let projectKey = session.originalProjectPath ?? session.projectPath ?? ""
            if grouped[projectKey] == nil {
                grouped[projectKey] = []
            }
            grouped[projectKey]?.append(session)
        }

        for (project, sessions) in grouped {
            let filtered = sessions.filter { session in
                // Apply search filter
                let matchesSearch = searchText.isEmpty ||
                    session.name.localizedCaseInsensitiveContains(searchText) ||
                    (session.projectPath?.localizedCaseInsensitiveContains(searchText) ?? false)

                // Apply status filter
                let matchesStatus: Bool
                switch filterStatus {
                case .all:
                    matchesStatus = true
                case .running:
                    matchesStatus = session.status == .running
                case .stopped:
                    matchesStatus = session.status == .stopped
                case .archived:
                    matchesStatus = session.status == .archived
                }

                return matchesSearch && matchesStatus
            }

            if !filtered.isEmpty {
                result[project] = filtered
            }
        }

        return result
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: DSSpacing.xs) {
            // Title and filter
            HStack {
                Label("Sessions", systemImage: "rectangle.stack.fill")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Status filter picker
                Picker("", selection: $filterStatus) {
                    ForEach(SessionFilterStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 80)

                // Refresh button
                Button {
                    Task {
                        await loadSessions()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Search field
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ds.tertiary)

                TextField("Search sessions...", text: $searchText)
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

            Text("Loading sessions...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Sessions")
                .dsTextStyle(.subtitle)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .dsTextStyle(.caption, color: .ds.secondary)
            } else {
                Text("Sessions will appear here when you start chatting")
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session List View

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Sort projects by most recent session
                let sortedProjects = filteredSessions.keys.sorted { p1, p2 in
                    let date1 = filteredSessions[p1]?.first?.updatedAt ?? Date.distantPast
                    let date2 = filteredSessions[p2]?.first?.updatedAt ?? Date.distantPast
                    return date1 > date2
                }

                ForEach(sortedProjects, id: \.self) { project in
                    if let sessions = filteredSessions[project] {
                        projectSection(project: project, sessions: sessions)
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    private func projectSection(project: String, sessions: [Session]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header
            Button {
                toggleProject(project)
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: expandedProjects.contains(project) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 12)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.accent)

                    Text(projectDisplayName(project))
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("(\(sessions.count))")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(Color.ds.surface.opacity(0.2))
            }
            .buttonStyle(.plain)

            // Sessions in this project
            if expandedProjects.contains(project) {
                ForEach(sessions) { session in
                    SessionRow(
                        session: session,
                        isCurrentSession: session.id == sessionId,
                        onSwitch: {
                            switchToSession(session)
                        },
                        onArchive: {
                            archiveSession(session)
                        },
                        onDelete: {
                            deleteSession(session)
                        }
                    )
                    .id("\(session.id)-\(session.unreadCount)")

                    if session.id != sessions.last?.id {
                        Divider()
                            .padding(.leading, DSSpacing.lg + DSSpacing.sm)
                    }
                }
            }
        }
    }

    private func projectDisplayName(_ path: String) -> String {
        if path.isEmpty {
            return "Uncategorized"
        }
        return (path as NSString).lastPathComponent
    }

    // MARK: - Actions

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        // Group sessions by project
        var grouped: [String: [Session]] = [:]
        for session in appState.sessions {
            let projectKey = session.originalProjectPath ?? session.projectPath ?? ""
            if grouped[projectKey] == nil {
                grouped[projectKey] = []
            }
            grouped[projectKey]?.append(session)
        }

        // Sort sessions within each project by updated date
        for (key, sessions) in grouped {
            grouped[key] = sessions.sorted { $0.updatedAt > $1.updatedAt }
        }

        groupedSessions = grouped

        // Expand projects with the current session
        if let currentProject = appState.sessions.first(where: { $0.id == sessionId })?.originalProjectPath {
            expandedProjects.insert(currentProject)
        }
    }

    private func toggleProject(_ project: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedProjects.contains(project) {
                expandedProjects.remove(project)
            } else {
                expandedProjects.insert(project)
            }
        }
    }

    private func switchToSession(_ session: Session) {
        // Notify the app to switch to this session
        NotificationCenter.default.post(
            name: .switchToSession,
            object: nil,
            userInfo: ["sessionId": session.id]
        )
    }

    private func archiveSession(_ session: Session) {
        // TODO: Implement session archiving via AppState when available
        print("[Sessions] Archive session: \(session.id)")
    }

    private func deleteSession(_ session: Session) {
        appState.deleteSession(session.id)
    }
}

// MARK: - Session Filter Status

enum SessionFilterStatus: String, CaseIterable {
    case all = "All"
    case running = "Running"
    case stopped = "Stopped"
    case archived = "Archived"
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session
    let isCurrentSession: Bool
    let onSwitch: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingName: String = ""
    @FocusState private var isEditingFocused: Bool
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: onSwitch) {
            HStack(spacing: DSSpacing.sm) {
                // Current session indicator
                Circle()
                    .fill(isCurrentSession ? Color.ds.accent : Color.clear)
                    .frame(width: 6, height: 6)

                // Provider logo
                ProviderLogoView(provider: session.provider, size: 16)

                // Session info
                VStack(alignment: .leading, spacing: 2) {
                    // Session name with inline editing support
                    if isEditing {
                        TextField("Session name", text: $editingName, onCommit: {
                            commitRename()
                        })
                        .textFieldStyle(.plain)
                        .dsTextStyle(.caption)
                        .fontWeight(isCurrentSession ? .medium : .regular)
                        .focused($isEditingFocused)
                        .onExitCommand {
                            cancelEditing()
                        }
                    } else {
                        Text(session.name)
                            .dsTextStyle(.caption)
                            .fontWeight(isCurrentSession ? .medium : .regular)
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                startEditing()
                            }
                    }

                    HStack(spacing: DSSpacing.xs) {
                        // Timestamp
                        Text(formatRelativeTime(session.updatedAt))
                            .dsTextStyle(.micro, color: .ds.tertiary)

                        // Message count
                        let messageCount = session.messages.count
                        if messageCount > 0 {
                            Text("\(messageCount) msgs")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }
                    }
                }

                Spacer()

                // Unread count badge (hidden when selected/active)
                if !isCurrentSession && session.unreadCount > 0 {
                    CountBadge(session.unreadCount)
                }

                // Action buttons (visible on hover)
                if isHovered {
                    HStack(spacing: DSSpacing.xxs) {
                        // Archive button
                        Button(action: onArchive) {
                            Image(systemName: session.status == .archived ? "arrow.uturn.backward" : "archivebox")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.ds.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help(session.status == .archived ? "Unarchive" : "Archive")

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
        .background(
            Group {
                if isCurrentSession {
                    Color.ds.accent.opacity(0.1)
                } else if isHovered {
                    Color.ds.surface.opacity(0.3)
                } else {
                    Color.clear
                }
            }
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                startEditing()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button {
                onArchive()
            } label: {
                Label(
                    session.status == .archived ? "Unarchive" : "Archive",
                    systemImage: session.status == .archived ? "arrow.uturn.backward" : "archivebox"
                )
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Session",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the session and all its messages.")
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Rename Actions

    private func startEditing() {
        editingName = session.name
        isEditing = true
        // Focus the text field on the next run loop
        DispatchQueue.main.async {
            isEditingFocused = true
        }
    }

    private func commitRename() {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't save if empty - just cancel
        guard !trimmedName.isEmpty else {
            cancelEditing()
            return
        }

        // Only update if the name actually changed
        if trimmedName != session.name {
            appState.renameSession(session.id, to: trimmedName)
        }

        isEditing = false
        isEditingFocused = false
    }

    private func cancelEditing() {
        isEditing = false
        isEditingFocused = false
        editingName = ""
    }
}

// MARK: - Provider Logo View

/// Displays a provider logo with fallback to SF Symbol.
struct ProviderLogoView: View {
    let provider: AIProvider
    var size: CGFloat = 16

    var body: some View {
        ProviderLogos.image(for: provider, size: size)
    }
}

// MARK: - Session Status Sidebar Extension

extension SessionStatus {
    /// Color for session status display in sidebar
    var sidebarColor: Color {
        switch self {
        case .creating:
            return .ds.info
        case .ready:
            return .ds.info
        case .running:
            return .ds.positive
        case .stopped:
            return .ds.warning
        case .errored:
            return .ds.negative
        case .archived:
            return .ds.tertiary
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let switchToSession = Notification.Name("switchToSession")
}

// MARK: - Previews

#Preview("Sessions Sidebar") {
    SessionsSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Sessions Sidebar - Empty") {
    SessionsSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
