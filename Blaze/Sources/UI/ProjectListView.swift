import SwiftUI
import UniformTypeIdentifiers

// MARK: - Session Drag Type

/// Custom UTType for session drag and drop
extension UTType {
    static let blazeSession = UTType(exportedAs: "com.cogit0.blaze.session")
}

/// Wrapper for session ID to support drag and drop
struct SessionTransferItem: Codable, Transferable {
    let sessionId: UUID
    let sourceProjectPath: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .blazeSession)
    }
}

// MARK: - Project List View

/// Sidebar view showing sessions grouped by project.
///
/// **Phase 2 UI:**
/// - Projects displayed as expandable groups
/// - Uncategorized sessions in separate section
/// - Support for drag-and-drop reordering
/// - File tree for selected session's worktree
struct ProjectListView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedSessionId: UUID?
    @Binding var fileTreeViewModel: FileTreeViewModel?

    // MARK: - State

    @State private var expandedProjects: Set<String> = []
    @State private var draggedSession: Session?
    @State private var fileTreeHeight: CGFloat = 200  // Resizable file tree height

    // MARK: - Computed Properties

    private var selectedSession: Session? {
        guard let id = selectedSessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar clearance
            Spacer().frame(height: 30)

            // Use ScrollView+LazyVStack pattern (like SidebarContainer) to avoid List's implicit backgrounds
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Project groups
                    ForEach(sortedProjectPaths, id: \.self) { projectPath in
                        if !projectPath.isEmpty {
                            ProjectGroupSectionNoList(
                                projectPath: projectPath,
                                sessions: sessionsForProject(projectPath),
                                isExpanded: expandedProjects.contains(projectPath),
                                toggleExpanded: { toggleProject(projectPath) },
                                selectedSessionId: $selectedSessionId
                            )
                        }
                    }

                    // Uncategorized section
                    if let uncategorized = appState.sessionsGroupedByProject[""], !uncategorized.isEmpty {
                        UncategorizedSectionNoList(
                            sessions: uncategorized,
                            selectedSessionId: $selectedSessionId
                        )
                    }
                }
                .padding(.vertical, DSSpacing.xs)
            }
            .background(.clear)  // Background applied at ContentView level
            // Give ScrollView lower priority so FileTreeView gets its minimum space
            .layoutPriority(0)

            // File tree for selected session's worktree
            if let viewModel = fileTreeViewModel {
                // Resize handle
                Rectangle()
                    .fill(Color(.separatorColor))
                    .frame(height: 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.tertiaryLabelColor))
                            .frame(width: 40, height: 4)
                    }
                    .contentShape(Rectangle().size(width: .infinity, height: 10))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newHeight = fileTreeHeight - value.translation.height
                                fileTreeHeight = min(max(newHeight, 100), 800)  // Allow much taller file tree
                            }
                    )
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.resizeUpDown.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                FileTreeView(
                    viewModel: viewModel,
                    onPreviewFile: { node in
                        appState.openFile(node.url.path, asPreview: false)  // Single-click opens persistent tabs
                    },
                    onOpenFile: { node in
                        appState.openFile(node.url.path, asPreview: false)
                    },
                    onCreateFileReference: { _ in
                        // TODO: Insert @file:path token into chat input
                        // For now, file drag-to-chat is not yet wired
                    }
                )
                .frame(height: fileTreeHeight)
                .layoutPriority(1)
            }
        }
        .sheet(isPresented: $appState.showNewSessionModal) {
            NewSessionModal()
        }
        .onAppear {
            // Expand all projects by default
            expandedProjects = Set(appState.sessionsGroupedByProject.keys)
        }
    }

    // MARK: - Computed Properties

    private var sortedProjectPaths: [String] {
        appState.sessionsGroupedByProject.keys
            .filter { !$0.isEmpty }
            .sorted { path1, path2 in
                // Sort by most recent session update
                let sessions1 = sessionsForProject(path1)
                let sessions2 = sessionsForProject(path2)
                let latest1 = sessions1.max(by: { $0.updatedAt < $1.updatedAt })?.updatedAt ?? Date.distantPast
                let latest2 = sessions2.max(by: { $0.updatedAt < $1.updatedAt })?.updatedAt ?? Date.distantPast
                return latest1 > latest2
            }
    }

    private func sessionsForProject(_ projectPath: String) -> [Session] {
        (appState.sessionsGroupedByProject[projectPath] ?? [])
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func toggleProject(_ projectPath: String) {
        if expandedProjects.contains(projectPath) {
            expandedProjects.remove(projectPath)
        } else {
            expandedProjects.insert(projectPath)
        }
    }
}

// MARK: - Project Group Section

struct ProjectGroupSection: View {
    let projectPath: String
    let sessions: [Session]
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    @Binding var selectedSessionId: UUID?
    @EnvironmentObject var appState: AppState

    @State private var isDragTargeted: Bool = false

    var body: some View {
        Section(isExpanded: Binding(
            get: { isExpanded },
            set: { _ in toggleExpanded() }
        )) {
            ForEach(sessions) { session in
                SessionRowView(session: session)
                    .tag(session.id)
                    .onTapGesture {
                        selectedSessionId = session.id
                    }
                    .draggable(SessionTransferItem(
                        sessionId: session.id,
                        sourceProjectPath: projectPath
                    )) {
                        // Custom drag preview
                        SessionDragPreview(session: session)
                    }
            }
            .onMove { source, destination in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    appState.reorderSessions(
                        projectPath: projectPath,
                        from: source,
                        to: destination
                    )
                }
            }
        } header: {
            projectHeader
        }
        .dropDestination(for: SessionTransferItem.self) { items, _ in
            // Handle sessions dropped from other projects (move to this project)
            guard let item = items.first else { return false }
            if item.sourceProjectPath != projectPath {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    appState.moveSessionToProject(
                        sessionId: item.sessionId,
                        toProjectPath: projectPath
                    )
                }
                return true
            }
            return false
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragTargeted = isTargeted
            }
        }
        .listRowBackground(
            isDragTargeted
                ? Color.ds.accent.opacity(0.15)
                : Color.clear
        )
    }

    private var projectHeader: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "folder.fill")
                .dsTextStyle(.caption)
                .foregroundStyle(Color.ds.accent)

            Text(projectDisplayName)
                .dsTextStyle(.body)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("\(sessions.count)")
                .dsTextStyle(.caption, color: .ds.tertiary)
                .padding(.horizontal, DSSpacing.xs)
                .background(Color.ds.border.opacity(0.3))
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpanded()
        }
    }

    private var projectDisplayName: String {
        (projectPath as NSString).lastPathComponent
    }
}

// MARK: - Uncategorized Section

struct UncategorizedSection: View {
    let sessions: [Session]
    @Binding var selectedSessionId: UUID?

    var body: some View {
        Section("Uncategorized") {
            ForEach(sessions.sorted { $0.updatedAt > $1.updatedAt }) { session in
                SessionRowView(session: session)
                    .tag(session.id)
            }
        }
    }
}

// MARK: - Project Group Section (No List)

/// Project group section without List - uses VStack for transparent background
struct ProjectGroupSectionNoList: View {
    let projectPath: String
    let sessions: [Session]
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    @Binding var selectedSessionId: UUID?
    @EnvironmentObject var appState: AppState

    @State private var isDragTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (clickable to expand/collapse)
            projectHeader
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleExpanded()
                    }
                }

            // Sessions (if expanded)
            if isExpanded {
                ForEach(sessions) { session in
                    SessionRowNoList(
                        session: session,
                        isSelected: selectedSessionId == session.id,
                        onSelect: { selectedSessionId = session.id }
                    )
                    .id("\(session.id)-\(session.unreadCount)")
                    .draggable(SessionTransferItem(
                        sessionId: session.id,
                        sourceProjectPath: projectPath
                    )) {
                        SessionDragPreview(session: session)
                    }
                }
            }
        }
        .background(
            isDragTargeted
                ? Color.ds.accent.opacity(0.15)
                : Color.clear
        )
        .dropDestination(for: SessionTransferItem.self) { items, _ in
            guard let item = items.first else { return false }
            if item.sourceProjectPath != projectPath {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    appState.moveSessionToProject(
                        sessionId: item.sessionId,
                        toProjectPath: projectPath
                    )
                }
                return true
            }
            return false
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragTargeted = isTargeted
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: DSSpacing.sm) {
            // Disclosure indicator
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .dsTextStyle(.caption)
                .foregroundStyle(Color.ds.tertiary)
                .frame(width: 12)

            Image(systemName: "folder.fill")
                .dsTextStyle(.caption)
                .foregroundStyle(Color.ds.accent)

            Text(projectDisplayName)
                .dsTextStyle(.body)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("\(sessions.count)")
                .dsTextStyle(.caption, color: .ds.tertiary)
                .padding(.horizontal, DSSpacing.xs)
                .background(Color.ds.border.opacity(0.3))
                .clipShape(Capsule())
        }
    }

    private var projectDisplayName: String {
        (projectPath as NSString).lastPathComponent
    }
}

// MARK: - Uncategorized Section (No List)

/// Uncategorized section without List
struct UncategorizedSectionNoList: View {
    let sessions: [Session]
    @Binding var selectedSessionId: UUID?

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .dsTextStyle(.caption)
                    .foregroundStyle(Color.ds.tertiary)
                    .frame(width: 12)

                Text("Uncategorized")
                    .dsTextStyle(.body, color: .ds.secondary)

                Spacer()

                Text("\(sessions.count)")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(.horizontal, DSSpacing.xs)
                    .background(Color.ds.border.opacity(0.3))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Sessions
            if isExpanded {
                ForEach(sessions.sorted { $0.updatedAt > $1.updatedAt }) { session in
                    SessionRowNoList(
                        session: session,
                        isSelected: selectedSessionId == session.id,
                        onSelect: { selectedSessionId = session.id }
                    )
                    .id("\(session.id)-\(session.unreadCount)")
                }
            }
        }
    }
}

// MARK: - Session Row (No List)

/// Session row without List - handles selection highlighting manually
struct SessionRowNoList: View {
    let session: Session
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var isHovered: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var validationError: String?
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            // Status indicator
            statusIndicator
                .frame(width: 20)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                // Session name (editable on double-click)
                if isEditing {
                    editableNameField
                } else {
                    Text(session.name)
                        .dsTextStyle(.body)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            startEditing()
                        }
                }

                HStack(spacing: DSSpacing.xs) {
                    // Timestamp
                    Text(session.updatedAt, style: .relative)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .lineLimit(1)

                    // Branch badge if has worktree
                    if let branch = session.branchName {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .dsTextStyle(.micro)
                            Text(abbreviatedBranchName(branch))
                                .dsTextStyle(.monoSmall, color: .ds.tertiary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, DSSpacing.xxs)
                        .background(Color.ds.border.opacity(0.2))
                        .clipShape(Capsule())
                        .fixedSize()
                    }
                }
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: DSSpacing.xs)

            // Unread count badge (hidden when selected or hovering)
            if !isSelected && !isHovered && session.unreadCount > 0 {
                CountBadge(session.unreadCount)
            }

            // Hover actions
            if isHovered && !isEditing {
                HStack(spacing: DSSpacing.xs) {
                    Button {
                        startEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .dsTextStyle(.caption)
                            .foregroundStyle(Color.ds.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Rename session")

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .dsTextStyle(.caption)
                            .foregroundStyle(Color.ds.negative.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete session")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.vertical, DSSpacing.xxs)
        .padding(.horizontal, DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .fill(isSelected ? Color.ds.accent.opacity(0.2) : (isHovered ? Color.ds.surface.opacity(0.3) : Color.clear))
        )
        .padding(.horizontal, DSSpacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .sessionDeletionAlert(
            isPresented: $showDeleteConfirmation,
            session: session,
            onDelete: { deleteWorktree in
                appState.deleteSession(session.id, deleteWorktree: deleteWorktree)
            }
        )
    }

    // MARK: - Editable Name Field

    private var editableNameField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Session name", text: $editedName)
                .textFieldStyle(.plain)
                .dsTextStyle(.body)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.ds.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .focused($isNameFieldFocused)
                .onSubmit {
                    commitEdit()
                }
                .onExitCommand {
                    cancelEdit()
                }
                .onChange(of: editedName) { _, newValue in
                    validateName(newValue)
                }

            if let error = validationError {
                Text(error)
                    .dsTextStyle(.micro)
                    .foregroundStyle(Color.ds.negative)
            }
        }
    }

    // MARK: - Editing Actions

    private func startEditing() {
        editedName = session.name
        validationError = nil
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }

    private func commitEdit() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            validationError = "Name cannot be empty"
            return
        }

        if isDuplicateName(trimmedName) {
            validationError = "Name already exists in project"
            return
        }

        appState.renameSession(session.id, to: trimmedName)
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
        editedName = ""
        validationError = nil
    }

    private func validateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            validationError = "Name cannot be empty"
        } else if isDuplicateName(trimmed) && trimmed != session.name {
            validationError = "Name already exists"
        } else {
            validationError = nil
        }
    }

    private func isDuplicateName(_ name: String) -> Bool {
        let projectPath = session.originalProjectPath ?? session.projectPath ?? ""
        let projectSessions = appState.sessionsGroupedByProject[projectPath] ?? []
        return projectSessions.contains { $0.id != session.id && $0.name == name }
    }

    private var statusIndicator: some View {
        Group {
            switch session.status {
            case .creating:
                ProgressView()
                    .scaleEffect(0.5)
            case .running:
                Circle()
                    .fill(Color.ds.positive)
                    .frame(width: 8, height: 8)
            case .errored:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.ds.warning)
                    .dsTextStyle(.caption)
            case .archived:
                Image(systemName: "archivebox")
                    .foregroundStyle(Color.ds.tertiary)
                    .dsTextStyle(.caption)
            default:
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(Color.ds.secondary)
                    .dsTextStyle(.body)
            }
        }
    }

    private func abbreviatedBranchName(_ branch: String) -> String {
        if branch.hasPrefix("blaze-session-") {
            return String(branch.dropFirst("blaze-session-".count).prefix(8))
        }
        return branch
    }
}

// MARK: - Updated Session Row View

/// Session row with status indicator, worktree info, and inline rename support
struct SessionRowView: View {
    let session: Session
    @EnvironmentObject var appState: AppState
    @State private var isHovered: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var validationError: String?
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            // Status indicator
            statusIndicator
                .frame(width: 20)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                // Session name (editable on double-click)
                if isEditing {
                    editableNameField
                } else {
                    Text(session.name)
                        .dsTextStyle(.body)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            startEditing()
                        }
                }

                HStack(spacing: DSSpacing.xs) {
                    // Timestamp
                    Text(session.updatedAt, style: .relative)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .lineLimit(1)

                    // Branch badge if has worktree
                    if let branch = session.branchName {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .dsTextStyle(.micro)
                            Text(abbreviatedBranchName(branch))
                                .dsTextStyle(.monoSmall, color: .ds.tertiary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, DSSpacing.xxs)
                        .background(Color.ds.border.opacity(0.2))
                        .clipShape(Capsule())
                        .fixedSize()
                    }
                }
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: DSSpacing.xs)

            // Hover actions
            if isHovered && !isEditing {
                HStack(spacing: DSSpacing.xs) {
                    Button {
                        startEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .dsTextStyle(.caption)
                            .foregroundStyle(Color.ds.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Rename session")

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .dsTextStyle(.caption)
                            .foregroundStyle(Color.ds.negative.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete session")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.vertical, DSSpacing.xxs)
        .padding(.trailing, DSSpacing.xs)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .sessionDeletionAlert(
            isPresented: $showDeleteConfirmation,
            session: session,
            onDelete: { deleteWorktree in
                appState.deleteSession(session.id, deleteWorktree: deleteWorktree)
            }
        )
    }

    // MARK: - Editable Name Field

    private var editableNameField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Session name", text: $editedName)
                .textFieldStyle(.plain)
                .dsTextStyle(.body)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.ds.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .focused($isNameFieldFocused)
                .onSubmit {
                    commitEdit()
                }
                .onExitCommand {
                    cancelEdit()
                }
                .onChange(of: editedName) { _, newValue in
                    validateName(newValue)
                }

            if let error = validationError {
                Text(error)
                    .dsTextStyle(.micro)
                    .foregroundStyle(Color.ds.negative)
            }
        }
    }

    // MARK: - Editing Actions

    private func startEditing() {
        editedName = session.name
        validationError = nil
        isEditing = true
        // Focus the field after a short delay to ensure it's visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }

    private func commitEdit() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate
        if trimmedName.isEmpty {
            validationError = "Name cannot be empty"
            return
        }

        // Check for duplicates in the same project
        if isDuplicateName(trimmedName) {
            validationError = "Name already exists in project"
            return
        }

        // Update the session
        appState.renameSession(session.id, to: trimmedName)
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
        editedName = ""
        validationError = nil
    }

    private func validateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            validationError = "Name cannot be empty"
        } else if isDuplicateName(trimmed) && trimmed != session.name {
            validationError = "Name already exists"
        } else {
            validationError = nil
        }
    }

    private func isDuplicateName(_ name: String) -> Bool {
        let projectPath = session.originalProjectPath ?? session.projectPath ?? ""
        let projectSessions = appState.sessionsGroupedByProject[projectPath] ?? []
        return projectSessions.contains { $0.id != session.id && $0.name == name }
    }

    private var statusIndicator: some View {
        Group {
            switch session.status {
            case .creating:
                ProgressView()
                    .scaleEffect(0.5)
            case .running:
                Circle()
                    .fill(Color.ds.positive)
                    .frame(width: 8, height: 8)
            case .errored:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.ds.warning)
                    .dsTextStyle(.caption)
            case .archived:
                Image(systemName: "archivebox")
                    .foregroundStyle(Color.ds.tertiary)
                    .dsTextStyle(.caption)
            default:
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(Color.ds.secondary)
                    .dsTextStyle(.body)
            }
        }
    }

    private func abbreviatedBranchName(_ branch: String) -> String {
        if branch.hasPrefix("blaze-session-") {
            return String(branch.dropFirst("blaze-session-".count).prefix(8))
        }
        return branch
    }
}

// MARK: - Session Drag Preview

/// Custom drag preview for session drag and drop
struct SessionDragPreview: View {
    let session: Session

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .dsTextStyle(.body)
                .foregroundStyle(Color.ds.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .dsTextStyle(.body)
                    .foregroundStyle(Color.ds.foreground)

                if let branch = session.branchName {
                    Text(branch)
                        .dsTextStyle(.monoSmall)
                        .foregroundStyle(Color.ds.tertiary)
                }
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(Color.ds.bg1)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.ds.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview {
    ProjectListView(selectedSessionId: .constant(nil), fileTreeViewModel: .constant(nil))
        .environmentObject(AppState())
        .frame(width: 280)
}

#Preview("Session Drag Preview") {
    SessionDragPreview(
        session: Session(
            name: "Feature Implementation",
            originalProjectPath: "/Users/dev/project",
            branchName: "blaze-session-abc123"
        )
    )
    .padding()
    .background(Color.black)
}
