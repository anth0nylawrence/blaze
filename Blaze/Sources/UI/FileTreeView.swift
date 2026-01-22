import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileTreeView (E001-F005-S001-T005-A001 through A008)

/// Virtualized file tree view with lazy loading, drag-to-chat, and preview/open interactions.
///
/// **Phase 2 System Contract:**
/// - Single click: Preview file (temporary tab, italic name)
/// - Double click: Open file (persistent tab)
/// - Drag to chat: Inserts @file:relative/path token
/// - Hidden items: Visible but dimmed (0.6 opacity)
/// - Symlinks: Show badge, don't traverse outside repo root
public struct FileTreeView: View {
    @ObservedObject var viewModel: FileTreeViewModel

    // Callbacks
    var onPreviewFile: ((FileTreeNode) -> Void)?
    var onOpenFile: ((FileTreeNode) -> Void)?
    var onCreateFileReference: ((FileReference) -> Void)?

    @State private var selectedNodeId: UUID?
    @State private var hoveredNodeId: UUID?
    @State private var contextMenuNode: FileTreeNode?

    public init(
        viewModel: FileTreeViewModel,
        onPreviewFile: ((FileTreeNode) -> Void)? = nil,
        onOpenFile: ((FileTreeNode) -> Void)? = nil,
        onCreateFileReference: ((FileReference) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onPreviewFile = onPreviewFile
        self.onOpenFile = onOpenFile
        self.onCreateFileReference = onCreateFileReference
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with sort controls
            fileTreeHeader

            Divider()

            // Tree content
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.flattenedNodes.isEmpty {
                emptyView
            } else {
                virtualizedTreeView
            }
        }
        .background(.clear)  // Background applied at ContentView level - no stacking
        .task {
            await viewModel.loadTree()
        }
    }

    // MARK: - Header

    private var fileTreeHeader: some View {
        HStack {
            Text("Files")
                .dsTextStyle(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Sort menu
            Menu {
                ForEach(FileTreeSortOrder.allCases, id: \.self) { order in
                    Button {
                        viewModel.sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .dsTextStyle(.micro)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)

            // Refresh button
            Button {
                Task {
                    await viewModel.reloadTree()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .dsTextStyle(.micro)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh file tree")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Virtualized Tree View

    private var virtualizedTreeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.flattenedNodes) { flatNode in
                    FileTreeRow(
                        node: flatNode.node,
                        depth: flatNode.depth,
                        isSelected: selectedNodeId == flatNode.id,
                        isHovered: hoveredNodeId == flatNode.id,
                        onTap: {
                            handleSingleClick(flatNode.node)
                        },
                        onDoubleTap: {
                            handleDoubleClick(flatNode.node)
                        },
                        onToggleExpansion: {
                            Task {
                                await viewModel.toggleExpansion(flatNode.node)
                            }
                        }
                    )
                    .frame(height: FileTreeVirtualization.rowHeight)
                    .onHover { isHovered in
                        hoveredNodeId = isHovered ? flatNode.id : nil
                    }
                    .contextMenu {
                        contextMenuContent(for: flatNode.node)
                    }
                    .onDrag {
                        let reference = viewModel.createFileReference(for: flatNode.node)
                        onCreateFileReference?(reference)
                        return NSItemProvider(object: reference.token as NSString)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Event Handlers

    private func handleSingleClick(_ node: FileTreeNode) {
        selectedNodeId = node.id

        if node.isDirectory || node.isSymlink {
            Task {
                await viewModel.toggleExpansion(node)
            }
        } else if node.isFile {
            onPreviewFile?(node)
        }
    }

    private func handleDoubleClick(_ node: FileTreeNode) {
        if node.isFile {
            onOpenFile?(node)
        } else if node.isDirectory || node.isSymlink {
            Task {
                await viewModel.toggleExpansion(node)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(for node: FileTreeNode) -> some View {
        if node.isFile {
            Button {
                onOpenFile?(node)
            } label: {
                Label("Open", systemImage: "doc")
            }

            Button {
                onOpenFile?(node)
            } label: {
                Label("Open in New Tab", systemImage: "plus.rectangle.on.rectangle")
            }

            Divider()
        }

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.url.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "doc.on.clipboard")
        }

        Button {
            let relativePath = node.relativePath(from: viewModel.rootURL)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(relativePath, forType: .string)
        } label: {
            Label("Copy Relative Path", systemImage: "doc.on.clipboard")
        }

        Divider()

        Button {
            let reference = viewModel.createFileReference(for: node)
            onCreateFileReference?(reference)
        } label: {
            Label("Insert Reference to Chat", systemImage: "text.insert")
        }

        if node.isSymlink {
            Divider()

            if node.isExternalSymlink {
                Button {
                    if let target = node.symlinkTarget {
                        let targetURL = URL(fileURLWithPath: target)
                        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                    }
                } label: {
                    Label("Reveal Target in Finder", systemImage: "arrow.right.circle")
                }

                Text("Symlink points outside repository")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if node.isBrokenSymlink {
                Text("Broken symlink")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading files...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: FileTreeError) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text(error.localizedDescription ?? "Unknown error")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                Task {
                    await viewModel.loadTree()
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("No files")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FileTreeRow

/// Single row in the file tree
public struct FileTreeRow: View {
    let node: FileTreeNode
    let depth: Int
    let isSelected: Bool
    let isHovered: Bool
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onToggleExpansion: (() -> Void)?

    @State private var clickCount = 0
    @State private var clickTask: Task<Void, Never>?

    public var body: some View {
        HStack(spacing: 4) {
            // Indentation
            Color.clear
                .frame(width: CGFloat(depth) * FileTreeVirtualization.indentPerLevel)

            // Disclosure indicator for directories
            if node.isDirectory || (node.isSymlink && !node.isBrokenSymlink && !node.isExternalSymlink) {
                Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .onTapGesture {
                        onToggleExpansion?()
                    }
            } else {
                Color.clear.frame(width: 12)
            }

            // File/folder icon
            ZStack {
                Image(systemName: node.iconName)
                    .dsTextStyle(.body)
                    .foregroundStyle(iconColor)

                // Symlink badge
                if node.isSymlink {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.blue)
                        .offset(x: 6, y: 6)
                }
            }
            .frame(width: 18)

            // File name
            Text(node.name)
                .dsTextStyle(.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(node.opacity)

            Spacer()

            // Status indicators
            if node.isBrokenSymlink {
                Image(systemName: "exclamationmark.triangle.fill")
                    .dsTextStyle(.micro)
                    .foregroundStyle(.orange)
                    .help("Broken symlink")
            }

            if node.isExternalSymlink {
                Image(systemName: "arrow.up.right.square")
                    .dsTextStyle(.micro)
                    .foregroundStyle(.blue)
                    .help("Points outside repository")
            }

            if node.errorMessage != nil {
                Image(systemName: "exclamationmark.circle")
                    .dsTextStyle(.micro)
                    .foregroundStyle(.red)
                    .help(node.errorMessage ?? "Error")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            handleClick()
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    clickTask?.cancel()
                    onDoubleTap?()
                }
        )
        .help(tooltipText)
    }

    private func handleClick() {
        clickTask?.cancel()
        clickTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay to detect double-click
            if !Task.isCancelled {
                onTap?()
            }
        }
    }

    private var iconColor: Color {
        if node.isBrokenSymlink {
            return .orange
        }

        switch node.kind {
        case .directory:
            return node.isHidden ? .gray : .blue
        case .symlink:
            return .purple
        case .file:
            return fileIconColor
        }
    }

    private var fileIconColor: Color {
        let ext = node.url.pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "jsx", "ts", "tsx": return .yellow
        case "py": return .blue
        case "rb": return .red
        case "go": return .cyan
        case "rs": return .orange
        case "md", "markdown": return .gray
        case "json", "yaml", "yml": return .green
        case "html", "css": return .pink
        default: return .gray
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color(.selectedContentBackgroundColor).opacity(0.1)
        }
        return .clear
    }

    private var tooltipText: String {
        var tooltip = node.url.path

        if let target = node.symlinkTarget {
            tooltip += "\n-> \(target)"
        }

        if let size = node.size {
            tooltip += "\nSize: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        }

        if let date = node.modificationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            tooltip += "\nModified: \(formatter.string(from: date))"
        }

        return tooltip
    }
}

// MARK: - File Drop Delegate

/// Delegate for handling file drops into chat
public struct FileReferenceDropDelegate: DropDelegate {
    let onDrop: (FileReference) -> Void

    public func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.plainText]).first else {
            return false
        }

        provider.loadObject(ofClass: String.self) { string, error in
            guard let token = string, token.hasPrefix("@file:") else { return }
            // Parse token and create reference
            let relativePath = String(token.dropFirst(6))
            let reference = FileReference(
                url: URL(fileURLWithPath: relativePath),
                relativePath: relativePath
            )
            DispatchQueue.main.async {
                onDrop(reference)
            }
        }

        return true
    }

    public func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }
}

// MARK: - Sidebar Integration

/// File tree integrated into sidebar panel
public struct SidebarFileTreeView: View {
    @ObservedObject var viewModel: FileTreeViewModel
    var onPreviewFile: ((FileTreeNode) -> Void)?
    var onOpenFile: ((FileTreeNode) -> Void)?
    var onCreateFileReference: ((FileReference) -> Void)?

    public var body: some View {
        VStack(spacing: 0) {
            FileTreeView(
                viewModel: viewModel,
                onPreviewFile: onPreviewFile,
                onOpenFile: onOpenFile,
                onCreateFileReference: onCreateFileReference
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("File Tree") {
    let viewModel = FileTreeViewModel(
        sessionId: UUID(),
        rootURL: URL(fileURLWithPath: NSHomeDirectory())
    )

    return FileTreeView(viewModel: viewModel)
        .frame(width: 280, height: 500)
}

#Preview("File Tree Row") {
    VStack(spacing: 0) {
        FileTreeRow(
            node: FileTreeNode(
                url: URL(fileURLWithPath: "/test/src"),
                name: "src",
                kind: .directory,
                isExpanded: true
            ),
            depth: 0,
            isSelected: false,
            isHovered: false
        )
        .frame(height: 24)

        FileTreeRow(
            node: FileTreeNode(
                url: URL(fileURLWithPath: "/test/src/main.swift"),
                name: "main.swift",
                kind: .file
            ),
            depth: 1,
            isSelected: true,
            isHovered: false
        )
        .frame(height: 24)

        FileTreeRow(
            node: FileTreeNode(
                url: URL(fileURLWithPath: "/test/.hidden"),
                name: ".hidden",
                kind: .directory,
                isHidden: true
            ),
            depth: 0,
            isSelected: false,
            isHovered: true
        )
        .frame(height: 24)

        FileTreeRow(
            node: FileTreeNode(
                url: URL(fileURLWithPath: "/test/link"),
                name: "link",
                kind: .symlink,
                symlinkTarget: "/external/path",
                isExternalSymlink: true
            ),
            depth: 0,
            isSelected: false,
            isHovered: false
        )
        .frame(height: 24)

        FileTreeRow(
            node: FileTreeNode(
                url: URL(fileURLWithPath: "/test/broken"),
                name: "broken",
                kind: .symlink,
                isBrokenSymlink: true
            ),
            depth: 0,
            isSelected: false,
            isHovered: false
        )
        .frame(height: 24)
    }
    .padding()
    .frame(width: 280)
}
