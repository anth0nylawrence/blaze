import SwiftUI

// MARK: - Files Sidebar View

/// Tab 4: Files sidebar showing modified files, open tabs, and recent files.
///
/// **Phase 2 Spec:**
/// - Sections: Open Tabs (current), Recent, Modified (this session)
/// - Click file → open in File View (persistent)
/// - Drag file to chat → insert @file: reference
/// - Right-click: Copy path, Reveal in Finder
struct FilesSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @EnvironmentObject var appState: AppState
    @State private var selectedSection: FilesSection = .modified
    @State private var groupByDirectory: Bool = false

    // MARK: - Computed Properties

    private var modifiedFiles: [ModifiedFile] {
        // Extract file modifications from events
        var files: [String: ModifiedFile] = [:]

        for envelope in events {
            switch envelope.event {
            case .fileDiffProduced(let diff):
                let path = diff.filePath
                let fileName = (path as NSString).lastPathComponent
                let additions = diff.hunks.flatMap(\.lines).filter { $0.type == .addition }.count
                let deletions = diff.hunks.flatMap(\.lines).filter { $0.type == .deletion }.count

                if var existing = files[path] {
                    existing.additions += additions
                    existing.deletions += deletions
                    existing.lastModified = envelope.timestamp
                    files[path] = existing
                } else {
                    files[path] = ModifiedFile(
                        path: path,
                        fileName: fileName,
                        changeType: .modified,
                        additions: additions,
                        deletions: deletions,
                        lastModified: envelope.timestamp
                    )
                }

            case .fileWritten(let write):
                let path = write.filePath
                let fileName = (path as NSString).lastPathComponent

                if files[path] == nil {
                    files[path] = ModifiedFile(
                        path: path,
                        fileName: fileName,
                        changeType: .created,
                        additions: 0,
                        deletions: 0,
                        lastModified: envelope.timestamp
                    )
                } else {
                    files[path]?.lastModified = envelope.timestamp
                }

            default:
                break
            }
        }

        return files.values.sorted { $0.lastModified > $1.lastModified }
    }

    private var openTabs: [FileTab] {
        appState.openFileTabs
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            sectionPicker

            Divider()

            // Content based on selected section
            switch selectedSection {
            case .openTabs:
                openTabsList
            case .modified:
                modifiedFilesList
            case .recent:
                recentFilesList
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(FilesSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: DSSpacing.xxs) {
                        Image(systemName: section.icon)
                            .font(.system(size: 14))

                        Text(section.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(selectedSection == section ? Color.ds.foreground : Color.ds.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.xs)
                    .background(
                        selectedSection == section
                            ? Color.ds.accent.opacity(0.15)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, DSSpacing.xxs)
    }

    // MARK: - Open Tabs List

    private var openTabsList: some View {
        Group {
            if openTabs.isEmpty {
                emptyState(
                    icon: "doc.text",
                    title: "No Open Files",
                    description: "Files you open will appear here"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(openTabs) { tab in
                            FileRow(
                                fileName: tab.fileName,
                                path: tab.filePath,
                                badge: tab.isPreview ? "Preview" : nil,
                                badgeColor: .ds.tertiary,
                                isActive: tab.id == appState.activeFileTabId
                            ) {
                                appState.activeFileTabId = tab.id
                                appState.centerPaneMode = .files
                            } onClose: {
                                appState.closeFileTab(tab.id)
                            }
                        }
                    }
                    .padding(.vertical, DSSpacing.xs)
                }
            }
        }
    }

    // MARK: - Modified Files List

    private var modifiedFilesList: some View {
        Group {
            if modifiedFiles.isEmpty {
                emptyState(
                    icon: "doc.badge.ellipsis",
                    title: "No Modified Files",
                    description: "Files changed during this session will appear here"
                )
            } else {
                VStack(spacing: 0) {
                    // Stats header
                    HStack {
                        Text("\(modifiedFiles.count) files modified")
                            .dsTextStyle(.caption, color: .ds.secondary)

                        Spacer()

                        Button {
                            groupByDirectory.toggle()
                        } label: {
                            Image(systemName: groupByDirectory ? "folder.fill" : "list.bullet")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.ds.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help(groupByDirectory ? "Show flat list" : "Group by directory")
                    }
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)

                    Divider()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if groupByDirectory {
                                groupedModifiedFiles
                            } else {
                                flatModifiedFiles
                            }
                        }
                        .padding(.vertical, DSSpacing.xs)
                    }
                }
            }
        }
    }

    private var flatModifiedFiles: some View {
        ForEach(modifiedFiles) { file in
            ModifiedFileRow(file: file) {
                appState.openFile(file.path, asPreview: false)
            }
        }
    }

    private var groupedModifiedFiles: some View {
        let grouped = Dictionary(grouping: modifiedFiles) { file in
            (file.path as NSString).deletingLastPathComponent
        }

        return ForEach(grouped.keys.sorted(), id: \.self) { directory in
            VStack(alignment: .leading, spacing: 0) {
                // Directory header
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.tertiary)

                    Text((directory as NSString).lastPathComponent)
                        .dsTextStyle(.caption, color: .ds.secondary)

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xxs)

                // Files in directory
                ForEach(grouped[directory] ?? []) { file in
                    ModifiedFileRow(file: file, indented: true) {
                        appState.openFile(file.path, asPreview: false)
                    }
                }
            }
        }
    }

    // MARK: - Recent Files List

    private var recentFilesList: some View {
        // For now, show files that were read during the session
        let recentFiles = extractRecentFiles()

        return Group {
            if recentFiles.isEmpty {
                emptyState(
                    icon: "clock",
                    title: "No Recent Files",
                    description: "Recently accessed files will appear here"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(recentFiles) { file in
                            FileRow(
                                fileName: file.fileName,
                                path: file.path,
                                timestamp: file.accessedAt
                            ) {
                                appState.openFile(file.path, asPreview: true)
                            }
                        }
                    }
                    .padding(.vertical, DSSpacing.xs)
                }
            }
        }
    }

    private func extractRecentFiles() -> [RecentFile] {
        var files: [String: RecentFile] = [:]

        for envelope in events.reversed() {
            if case .fileRead(let read) = envelope.event {
                let path = read.filePath
                if files[path] == nil {
                    files[path] = RecentFile(
                        path: path,
                        fileName: (path as NSString).lastPathComponent,
                        accessedAt: envelope.timestamp
                    )
                }
            }
        }

        return files.values.sorted { $0.accessedAt > $1.accessedAt }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, description: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text(title)
                .dsTextStyle(.caption, color: .ds.secondary)

            Text(description)
                .dsTextStyle(.micro, color: .ds.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Types

enum FilesSection: String, CaseIterable, Identifiable {
    case openTabs = "Open"
    case modified = "Modified"
    case recent = "Recent"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .openTabs: return "doc.on.doc"
        case .modified: return "doc.badge.ellipsis"
        case .recent: return "clock"
        }
    }
}

struct ModifiedFile: Identifiable {
    let id = UUID()
    let path: String
    let fileName: String
    var changeType: FileChangeType
    var additions: Int
    var deletions: Int
    var lastModified: Date
}

enum FileChangeType: String {
    case created = "Created"
    case modified = "Modified"
    case deleted = "Deleted"

    var icon: String {
        switch self {
        case .created: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .created: return .ds.positive
        case .modified: return .ds.warning
        case .deleted: return .ds.negative
        }
    }
}

struct RecentFile: Identifiable {
    let id = UUID()
    let path: String
    let fileName: String
    let accessedAt: Date
}

// MARK: - File Row

struct FileRow: View {
    let fileName: String
    let path: String
    var badge: String? = nil
    var badgeColor: Color = .ds.tertiary
    var timestamp: Date? = nil
    var isActive: Bool = false
    let onTap: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // File icon
            Image(systemName: fileIcon)
                .font(.system(size: 14))
                .foregroundStyle(fileIconColor)
                .frame(width: 20)

            // File name and path
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DSSpacing.xs) {
                    Text(fileName)
                        .dsTextStyle(.body)
                        .lineLimit(1)

                    if let badge {
                        Text(badge)
                            .dsTextStyle(.micro, color: badgeColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(badgeColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                if let timestamp {
                    Text(formatRelativeTime(timestamp))
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }

            Spacer()

            // Close button (if applicable)
            if let onClose, isHovered {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(
            isActive
                ? Color.ds.accent.opacity(0.15)
                : (isHovered ? Color.ds.surface.opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }

            Divider()

            Button("Open") {
                onTap()
            }
        }
    }

    private var fileIcon: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "doc.text"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.richtext"
        case "html", "css": return "globe"
        default: return "doc.text"
        }
    }

    private var fileIconColor: Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "py": return .blue
        case "js", "ts", "jsx", "tsx": return .yellow
        case "json": return .gray
        case "md", "markdown": return .purple
        default: return .ds.secondary
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Modified File Row

struct ModifiedFileRow: View {
    let file: ModifiedFile
    var indented: Bool = false
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // Change type indicator
            Image(systemName: file.changeType.icon)
                .font(.system(size: 12))
                .foregroundStyle(file.changeType.color)
                .frame(width: 16)

            // File name
            Text(file.fileName)
                .dsTextStyle(.body)
                .lineLimit(1)

            Spacer()

            // Diff stats
            if file.additions > 0 || file.deletions > 0 {
                HStack(spacing: DSSpacing.xxs) {
                    if file.additions > 0 {
                        Text("+\(file.additions)")
                            .dsTextStyle(.monoSmall, color: .ds.positive)
                    }
                    if file.deletions > 0 {
                        Text("-\(file.deletions)")
                            .dsTextStyle(.monoSmall, color: .ds.negative)
                    }
                }
            }
        }
        .padding(.leading, indented ? DSSpacing.lg : DSSpacing.sm)
        .padding(.trailing, DSSpacing.sm)
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
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            }

            Divider()

            Button("Open") {
                onTap()
            }
        }
    }
}

// MARK: - Previews

#Preview("Files Sidebar - Modified") {
    FilesSidebarView(
        sessionId: UUID(),
        events: []
    )
    .environmentObject(AppState())
    .frame(width: 280, height: 400)
    .background(Color.ds.bg0)
}
