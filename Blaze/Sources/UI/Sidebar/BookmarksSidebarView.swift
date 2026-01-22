import SwiftUI

// MARK: - Bookmarks Sidebar View

/// Tab 7: Bookmarks sidebar for saved locations and quick access.
///
/// **Phase 2 Spec:**
/// - List of bookmarked items (files, messages, tool calls)
/// - Bookmark name (auto-generated or user-edited)
/// - Type indicator icon
/// - Organize into folders
/// - Drag to reorder
struct BookmarksSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @EnvironmentObject var appState: AppState
    @State private var bookmarks: [SessionBookmark] = []
    @State private var folders: [String] = []
    @State private var expandedFolders: Set<String> = ["Default"]
    @State private var selectedFilter: BookmarkFilter = .all
    @State private var isEditing: Bool = false
    @State private var editingBookmarkId: UUID?

    private var session: Session? {
        guard let id = sessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    // MARK: - Computed Properties

    private var filteredBookmarks: [SessionBookmark] {
        bookmarks.filter { bookmark in
            switch selectedFilter {
            case .all: return true
            case .files: return bookmark.type == .file
            case .messages: return bookmark.type == .message
            case .tools: return bookmark.type == .tool
            }
        }
    }

    private var groupedBookmarks: [String: [SessionBookmark]] {
        Dictionary(grouping: filteredBookmarks) { $0.folder ?? "Default" }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            filterBar

            Divider()

            // Bookmarks list
            if bookmarks.isEmpty {
                emptyState
            } else if filteredBookmarks.isEmpty {
                noFilterResultsView
            } else {
                bookmarksList
            }
        }
        .onAppear {
            loadBookmarks()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(BookmarkFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 10))

                        Text(filter.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(selectedFilter == filter ? Color.ds.foreground : Color.ds.tertiary)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, 4)
                    .background(
                        selectedFilter == filter
                            ? Color.ds.accent.opacity(0.2)
                            : Color.ds.surface.opacity(0.3)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Add bookmark button
            Button {
                // Show add bookmark sheet (future)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
            .help("Add bookmark")
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Bookmarks")
                .dsTextStyle(.subtitle)

            Text("Save important moments for quick access")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Label("Right-click on messages", systemImage: "bubble.left")
                Label("Right-click on tool calls", systemImage: "wrench")
                Label("Right-click on files", systemImage: "doc.text")
            }
            .dsTextStyle(.micro, color: .ds.tertiary)
            .padding(.top, DSSpacing.sm)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Filter Results

    private var noFilterResultsView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No \(selectedFilter.rawValue) Bookmarks")
                .dsTextStyle(.subtitle)

            Button {
                selectedFilter = .all
            } label: {
                Text("Show all bookmarks")
                    .dsTextStyle(.caption, color: .ds.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bookmarks List

    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedBookmarks.keys.sorted(), id: \.self) { folder in
                    bookmarkFolder(folder, bookmarks: groupedBookmarks[folder] ?? [])
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    // MARK: - Bookmark Folder

    private func bookmarkFolder(_ folder: String, bookmarks: [SessionBookmark]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedFolders.contains(folder) {
                        expandedFolders.remove(folder)
                    } else {
                        expandedFolders.insert(folder)
                    }
                }
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: expandedFolders.contains(folder) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 12)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.secondary)

                    Text(folder)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .fontWeight(.medium)

                    Text("(\(bookmarks.count))")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)

            // Bookmarks in folder
            if expandedFolders.contains(folder) {
                ForEach(bookmarks) { bookmark in
                    BookmarkRow(
                        bookmark: bookmark,
                        isEditing: editingBookmarkId == bookmark.id
                    ) {
                        navigateToBookmark(bookmark)
                    } onEdit: {
                        editingBookmarkId = bookmark.id
                    } onDelete: {
                        deleteBookmark(bookmark)
                    } onRename: { newName in
                        renameBookmark(bookmark, to: newName)
                        editingBookmarkId = nil
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadBookmarks() {
        // Load bookmarks from events or persistence
        // For now, generate from events that might be bookmarkable
        var loadedBookmarks: [SessionBookmark] = []

        // Extract potential bookmarks from events
        for envelope in events {
            switch envelope.event {
            case .fileDiffProduced(let diff):
                // Auto-bookmark significant file changes
                let additions = diff.hunks.flatMap(\.lines).filter { $0.type == .addition }.count
                let deletions = diff.hunks.flatMap(\.lines).filter { $0.type == .deletion }.count
                if additions + deletions > 50 {
                    loadedBookmarks.append(SessionBookmark(
                        type: .file,
                        name: "Major change: \((diff.filePath as NSString).lastPathComponent)",
                        targetId: envelope.id.uuidString,
                        preview: "+\(additions) -\(deletions) lines",
                        filePath: diff.filePath,
                        createdAt: envelope.timestamp
                    ))
                }

            case .toolCallComplete(let tool):
                // Bookmark failed tool calls
                if tool.error != nil {
                    loadedBookmarks.append(SessionBookmark(
                        type: .tool,
                        name: "Failed: \(tool.toolName)",
                        targetId: tool.toolCallId,
                        preview: tool.error ?? "",
                        createdAt: envelope.timestamp,
                        eventId: envelope.id
                    ))
                }

            default:
                break
            }
        }

        // Sort by creation date (newest first)
        bookmarks = loadedBookmarks.sorted { $0.createdAt > $1.createdAt }
    }

    private func navigateToBookmark(_ bookmark: SessionBookmark) {
        switch bookmark.type {
        case .file:
            if let path = bookmark.filePath {
                appState.openFile(path, asPreview: true)
            }

        case .message, .tool:
            if let eventId = bookmark.eventId {
                appState.scrollToEvent(eventId)
            }
        }
    }

    private func deleteBookmark(_ bookmark: SessionBookmark) {
        withAnimation {
            bookmarks.removeAll { $0.id == bookmark.id }
        }
    }

    private func renameBookmark(_ bookmark: SessionBookmark, to newName: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].name = newName
        }
    }
}

// MARK: - Supporting Types

enum BookmarkFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case files = "Files"
    case messages = "Messages"
    case tools = "Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "bookmark"
        case .files: return "doc.text"
        case .messages: return "bubble.left"
        case .tools: return "wrench"
        }
    }
}

struct SessionBookmark: Identifiable {
    let id = UUID()
    let type: BookmarkType
    var name: String
    let targetId: String
    let preview: String
    var folder: String? = nil
    var filePath: String? = nil
    let createdAt: Date
    var eventId: UUID? = nil
}

enum BookmarkType {
    case file
    case message
    case tool

    var icon: String {
        switch self {
        case .file: return "doc.text"
        case .message: return "bubble.left"
        case .tool: return "wrench"
        }
    }

    var color: Color {
        switch self {
        case .file: return .ds.positive
        case .message: return .ds.accent
        case .tool: return .ds.warning
        }
    }
}

// MARK: - Bookmark Row

struct BookmarkRow: View {
    let bookmark: SessionBookmark
    var isEditing: Bool = false
    let onTap: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRename: ((String) -> Void)? = nil

    @State private var isHovered: Bool = false
    @State private var editedName: String = ""

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Type icon
            Image(systemName: bookmark.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(bookmark.type.color)
                .frame(width: 16)

            // Name and preview
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit {
                            onRename?(editedName)
                        }
                        .onAppear {
                            editedName = bookmark.name
                        }
                } else {
                    Text(bookmark.name)
                        .dsTextStyle(.caption)
                        .lineLimit(1)
                }

                Text(bookmark.preview)
                    .dsTextStyle(.micro, color: .ds.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Timestamp
            Text(formatRelativeTime(bookmark.createdAt))
                .dsTextStyle(.micro, color: .ds.tertiary)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(isHovered ? Color.ds.surface.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") {
                onTap()
            }

            Divider()

            Button("Rename...") {
                onEdit?()
            }

            Button("Delete", role: .destructive) {
                onDelete?()
            }
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview("Bookmarks Sidebar") {
    BookmarksSidebarView(
        sessionId: UUID(),
        events: []
    )
    .environmentObject(AppState())
    .frame(width: 280, height: 500)
    .background(Color.ds.bg0)
}
