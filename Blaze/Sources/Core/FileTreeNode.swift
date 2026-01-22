import Foundation

// MARK: - FileTreeNode Model (E001-F005-S001-T001-A001)

/// Represents a node in the file tree hierarchy.
/// Supports directories, files, and symlinks with lazy loading of children.
///
/// **Phase 2 System Contract:**
/// - Shows worktree files only (not repo root or external paths)
/// - Symlinks displayed as symlinks with badge
/// - Symlinks outside repo root blocked by default
/// - Hidden items visible but dimmed (0.6 opacity)
public struct FileTreeNode: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let kind: FileKind
    public let isHidden: Bool
    public let size: Int64?
    public let modificationDate: Date?
    public var isExpanded: Bool
    public var children: [FileTreeNode]?

    /// For symlinks: the resolved target path
    public let symlinkTarget: String?

    /// Whether the symlink points outside the repo root
    public let isExternalSymlink: Bool

    /// Whether this represents a broken symlink
    public let isBrokenSymlink: Bool

    /// Error message if there was an issue reading this node
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        kind: FileKind,
        isHidden: Bool = false,
        size: Int64? = nil,
        modificationDate: Date? = nil,
        isExpanded: Bool = false,
        children: [FileTreeNode]? = nil,
        symlinkTarget: String? = nil,
        isExternalSymlink: Bool = false,
        isBrokenSymlink: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.kind = kind
        self.isHidden = isHidden
        self.size = size
        self.modificationDate = modificationDate
        self.isExpanded = isExpanded
        self.children = children
        self.symlinkTarget = symlinkTarget
        self.isExternalSymlink = isExternalSymlink
        self.isBrokenSymlink = isBrokenSymlink
        self.errorMessage = errorMessage
    }

    // MARK: - Computed Properties

    public var isDirectory: Bool {
        kind == .directory
    }

    public var isSymlink: Bool {
        kind == .symlink
    }

    public var isFile: Bool {
        kind == .file
    }

    /// Whether hidden folders should be collapsed by default
    public var shouldAutoExpand: Bool {
        isDirectory && !isHidden
    }

    /// Opacity for rendering (hidden items dimmed)
    public var opacity: Double {
        isHidden ? 0.6 : 1.0
    }

    /// SF Symbol name for this node type
    public var iconName: String {
        if isBrokenSymlink {
            return "link.badge.exclamationmark"
        }

        if isSymlink {
            if isDirectory {
                return "folder.badge.arrow"
            }
            return "link"
        }

        switch kind {
        case .directory:
            if isExpanded {
                return "folder.fill"
            }
            return "folder"
        case .file:
            return fileTypeIcon
        case .symlink:
            return "link"
        }
    }

    /// Icon based on file extension
    private var fileTypeIcon: String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        // Swift/iOS
        case "swift":
            return "swift"
        case "xcodeproj", "xcworkspace":
            return "hammer"
        case "storyboard", "xib":
            return "rectangle.on.rectangle"

        // Web
        case "js", "jsx", "ts", "tsx":
            return "chevron.left.forwardslash.chevron.right"
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "sass":
            return "paintbrush"
        case "json":
            return "curlybraces"

        // Images
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico":
            return "photo"
        case "pdf":
            return "doc.richtext"

        // Documents
        case "md", "markdown":
            return "doc.text"
        case "txt":
            return "doc.plaintext"
        case "rtf":
            return "doc.richtext"

        // Data
        case "sqlite", "db":
            return "cylinder"
        case "plist":
            return "list.bullet.rectangle"
        case "yaml", "yml":
            return "text.alignleft"
        case "xml":
            return "chevron.left.forwardslash.chevron.right"

        // Archives
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"

        // Executables
        case "sh", "bash", "zsh":
            return "terminal"
        case "py":
            return "chevron.left.forwardslash.chevron.right"
        case "rb":
            return "chevron.left.forwardslash.chevron.right"
        case "rs":
            return "gearshape.2"
        case "go":
            return "chevron.left.forwardslash.chevron.right"
        case "c", "cpp", "h", "hpp":
            return "chevron.left.forwardslash.chevron.right"
        case "java", "kt":
            return "cup.and.saucer"

        // Git
        case "gitignore", "gitattributes":
            return "arrow.triangle.branch"

        // Config
        case "env", "envrc":
            return "key"
        case "lock":
            return "lock"

        default:
            return "doc"
        }
    }

    /// Relative path from a given root URL
    public func relativePath(from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let nodePath = url.standardizedFileURL.path

        if nodePath.hasPrefix(rootPath) {
            var relative = String(nodePath.dropFirst(rootPath.count))
            if relative.hasPrefix("/") {
                relative = String(relative.dropFirst())
            }
            return relative.isEmpty ? name : relative
        }

        return nodePath
    }

    // MARK: - Equatable & Hashable

    public static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.name == rhs.name &&
        lhs.kind == rhs.kind &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.children?.count == rhs.children?.count
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }
}

// MARK: - FileKind

/// The type of file system node
public enum FileKind: String, Codable, Sendable {
    case file
    case directory
    case symlink
}

// MARK: - FileTreeSnapshot

/// A point-in-time snapshot of the file tree for a session
public struct FileTreeSnapshot: Sendable {
    public let sessionId: UUID
    public let rootURL: URL
    public let rootNode: FileTreeNode
    public let timestamp: Date

    /// Flattened count of visible nodes (for virtualization)
    public var visibleNodeCount: Int {
        countVisibleNodes(rootNode)
    }

    private func countVisibleNodes(_ node: FileTreeNode) -> Int {
        var count = 1
        if node.isExpanded, let children = node.children {
            for child in children {
                count += countVisibleNodes(child)
            }
        }
        return count
    }

    public init(sessionId: UUID, rootURL: URL, rootNode: FileTreeNode, timestamp: Date = Date()) {
        self.sessionId = sessionId
        self.rootURL = rootURL
        self.rootNode = rootNode
        self.timestamp = timestamp
    }
}

// MARK: - OpenFileTab

/// Represents an open file tab in the file view
public struct OpenFileTab: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let isTemporary: Bool
    public var lastViewedAt: Date

    public var name: String {
        url.lastPathComponent
    }

    public init(
        id: UUID = UUID(),
        url: URL,
        isTemporary: Bool = true,
        lastViewedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.isTemporary = isTemporary
        self.lastViewedAt = lastViewedAt
    }

    /// Make this tab permanent (from a temporary preview)
    public func makePermanent() -> OpenFileTab {
        OpenFileTab(
            id: id,
            url: url,
            isTemporary: false,
            lastViewedAt: Date()
        )
    }
}

// MARK: - FileReference

/// A reference to a file or folder that can be inserted into chat
public struct FileReference: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let relativePath: String
    public let isDirectory: Bool

    public var token: String {
        isDirectory ? "@folder:\(relativePath)" : "@file:\(relativePath)"
    }

    public init(id: UUID = UUID(), url: URL, relativePath: String, isDirectory: Bool = false) {
        self.id = id
        self.url = url
        self.relativePath = relativePath
        self.isDirectory = isDirectory
    }
}

// MARK: - FileTreeError

/// Errors that can occur when working with the file tree
public enum FileTreeError: Error, LocalizedError, Sendable {
    case rootNotFound(URL)
    case accessDenied(URL)
    case symlinkCycleDetected(URL)
    case externalSymlink(URL, target: String)
    case loadFailed(URL, underlying: String)
    case fileDeleted(URL)
    case repositoryMoved

    public var errorDescription: String? {
        switch self {
        case .rootNotFound(let url):
            return "Root directory not found: \(url.path)"
        case .accessDenied(let url):
            return "Permission denied: \(url.path)"
        case .symlinkCycleDetected(let url):
            return "Symlink cycle detected at: \(url.path)"
        case .externalSymlink(let url, let target):
            return "Symlink at \(url.path) points outside repository: \(target)"
        case .loadFailed(let url, let underlying):
            return "Failed to load \(url.path): \(underlying)"
        case .fileDeleted(let url):
            return "File no longer exists: \(url.path)"
        case .repositoryMoved:
            return "Repository folder has been moved or deleted"
        }
    }
}

// MARK: - Virtualization Constants

/// Constants for file tree virtualization per Phase 2 spec
public enum FileTreeVirtualization {
    /// Fixed height for each row (enables O(1) scroll position calculation)
    public static let rowHeight: CGFloat = 24

    /// Pre-render items above/below viewport to prevent flicker
    public static let overscanBuffer: Int = 50

    /// Number of views to reuse in the recycle pool
    public static let recyclePoolSize: Int = 100

    /// Indent per nesting level
    public static let indentPerLevel: CGFloat = 16
}

// MARK: - File Tree Node Builder

/// Builder for creating FileTreeNode from filesystem
public enum FileTreeNodeBuilder {

    /// Create a FileTreeNode from a URL
    /// - Parameters:
    ///   - url: The file URL
    ///   - repoRoot: The repository root URL (for external symlink detection)
    ///   - visited: Set of canonical paths already visited (for cycle detection)
    /// - Returns: A FileTreeNode representing the file/directory
    public static func build(
        from url: URL,
        repoRoot: URL,
        visited: inout Set<String>
    ) throws -> FileTreeNode {
        let fileManager = FileManager.default
        let standardURL = url.standardizedFileURL
        let path = standardURL.path

        // Check if file exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw FileTreeError.rootNotFound(url)
        }

        // Get file attributes
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: path)
        } catch {
            throw FileTreeError.accessDenied(url)
        }

        let name = standardURL.lastPathComponent
        let isHidden = name.hasPrefix(".")
        let size = attributes[.size] as? Int64
        let modDate = attributes[.modificationDate] as? Date
        let fileType = attributes[.type] as? FileAttributeType

        // Determine kind
        let kind: FileKind
        var symlinkTarget: String? = nil
        var isExternalSymlink = false
        var isBrokenSymlink = false

        if fileType == .typeSymbolicLink {
            kind = .symlink

            // Resolve symlink
            do {
                let targetPath = try fileManager.destinationOfSymbolicLink(atPath: path)
                let targetURL: URL

                if targetPath.hasPrefix("/") {
                    targetURL = URL(fileURLWithPath: targetPath)
                } else {
                    targetURL = standardURL.deletingLastPathComponent().appendingPathComponent(targetPath)
                }

                let resolvedTarget = targetURL.standardizedFileURL
                symlinkTarget = resolvedTarget.path

                // Check if target exists
                if !fileManager.fileExists(atPath: resolvedTarget.path) {
                    isBrokenSymlink = true
                }

                // Check if target is outside repo root
                let repoRootPath = repoRoot.standardizedFileURL.path
                if !resolvedTarget.path.hasPrefix(repoRootPath) {
                    isExternalSymlink = true
                }
            } catch {
                isBrokenSymlink = true
                symlinkTarget = "unknown"
            }
        } else if isDirectory.boolValue {
            kind = .directory
        } else {
            kind = .file
        }

        return FileTreeNode(
            url: standardURL,
            name: name,
            kind: kind,
            isHidden: isHidden,
            size: size,
            modificationDate: modDate,
            isExpanded: false,
            children: nil,
            symlinkTarget: symlinkTarget,
            isExternalSymlink: isExternalSymlink,
            isBrokenSymlink: isBrokenSymlink
        )
    }

    /// Load children for a directory node
    /// - Parameters:
    ///   - node: The parent directory node
    ///   - repoRoot: The repository root URL
    ///   - visited: Set of canonical paths already visited (for cycle detection)
    ///   - sortOrder: How to sort children
    /// - Returns: Array of child nodes
    public static func loadChildren(
        for node: FileTreeNode,
        repoRoot: URL,
        visited: inout Set<String>,
        sortOrder: FileTreeSortOrder = .default
    ) throws -> [FileTreeNode] {
        guard node.isDirectory || node.isSymlink else {
            return []
        }

        // For symlinks, check if we should traverse
        if node.isSymlink {
            if node.isExternalSymlink || node.isBrokenSymlink {
                return []
            }
        }

        // Cycle detection
        let resolvedPath: String
        do {
            resolvedPath = try node.url.resolvingSymlinksInPath().path
        } catch {
            resolvedPath = node.url.standardizedFileURL.path
        }

        guard !visited.contains(resolvedPath) else {
            throw FileTreeError.symlinkCycleDetected(node.url)
        }
        visited.insert(resolvedPath)

        // List directory contents
        let fileManager = FileManager.default
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: node.url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                options: []  // Don't skip hidden files
            )
        } catch {
            throw FileTreeError.accessDenied(node.url)
        }

        // Build child nodes
        var children: [FileTreeNode] = []
        for url in contents {
            do {
                let child = try build(from: url, repoRoot: repoRoot, visited: &visited)
                children.append(child)
            } catch {
                // Create error node for files we can't read
                let errorNode = FileTreeNode(
                    url: url,
                    name: url.lastPathComponent,
                    kind: .file,
                    isHidden: url.lastPathComponent.hasPrefix("."),
                    errorMessage: error.localizedDescription
                )
                children.append(errorNode)
            }
        }

        // Sort children
        return sortChildren(children, order: sortOrder)
    }

    /// Sort child nodes according to the specified order
    private static func sortChildren(_ children: [FileTreeNode], order: FileTreeSortOrder) -> [FileTreeNode] {
        children.sorted { a, b in
            // Directories always come first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }

            switch order {
            case .name:
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .nameDescending:
                return a.name.localizedStandardCompare(b.name) == .orderedDescending
            case .dateModified:
                let aDate = a.modificationDate ?? .distantPast
                let bDate = b.modificationDate ?? .distantPast
                return aDate > bDate
            case .size:
                let aSize = a.size ?? 0
                let bSize = b.size ?? 0
                return aSize > bSize
            case .`default`:
                // Default: directories first, then alphabetical, hidden last
                if a.isHidden != b.isHidden {
                    return !a.isHidden
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
    }
}

// MARK: - Sort Order

/// How to sort files in the tree
public enum FileTreeSortOrder: String, CaseIterable, Sendable {
    case `default` = "Default"
    case name = "Name"
    case nameDescending = "Name (Z-A)"
    case dateModified = "Date Modified"
    case size = "Size"
}
