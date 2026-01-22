import Foundation
import Combine
import os

// MARK: - FileTreeViewModel (E001-F005-S001-T002-A001 through A004)

/// ViewModel for the file tree with lazy loading, FSEvents watching, and cycle detection.
///
/// **Phase 2 System Contract:**
/// - Lazy-load directory contents on expand
/// - FSEvents: 250ms debounce, coalesced events, 2s burst cap
/// - Virtualization: Fixed 24px rows, 50-item overscan buffer
/// - Symlinks: Detect cycles, show warning icon, don't follow into loops
@MainActor
public final class FileTreeViewModel: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var rootNode: FileTreeNode?
    @Published public private(set) var flattenedNodes: [FlattenedNode] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: FileTreeError?
    @Published public var sortOrder: FileTreeSortOrder = .default {
        didSet {
            if sortOrder != oldValue {
                Task { await reloadTree() }
            }
        }
    }

    // MARK: - Configuration

    public let sessionId: UUID
    public let rootURL: URL

    // MARK: - Private State

    private var visitedPaths: Set<String> = []
    private var fsEventsWatcher: FSEventsWatcher?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.blaze.filetree", category: "FileTreeViewModel")

    // FSEvents configuration per spec
    private let debounceInterval: TimeInterval = 0.250  // 250ms
    private let burstMaxDelay: TimeInterval = 2.0       // 2s burst cap

    // MARK: - Initialization

    public init(sessionId: UUID, rootURL: URL) {
        self.sessionId = sessionId
        self.rootURL = rootURL
    }

    /// Empty view model for use when no session is selected (EnvironmentObject fallback)
    public static var empty: FileTreeViewModel {
        FileTreeViewModel(sessionId: UUID(), rootURL: URL(fileURLWithPath: NSTemporaryDirectory()))
    }

    deinit {
        // Stop FSEvents watcher directly since it's not actor-isolated
        fsEventsWatcher?.stop()
    }

    // MARK: - Public API

    /// Load the initial file tree
    public func loadTree() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        logger.info("Loading file tree for session: \(self.sessionId.uuidString)")

        do {
            visitedPaths.removeAll()
            let node = try FileTreeNodeBuilder.build(
                from: rootURL,
                repoRoot: rootURL,
                visited: &visitedPaths
            )

            // Load first level of children
            var mutableNode = node
            if node.isDirectory {
                let children = try FileTreeNodeBuilder.loadChildren(
                    for: node,
                    repoRoot: rootURL,
                    visited: &visitedPaths,
                    sortOrder: sortOrder
                )
                mutableNode = updateNode(node, children: children, isExpanded: true)
            }

            rootNode = mutableNode
            updateFlattenedNodes()
            startWatching()

            logger.info("File tree loaded with \(self.flattenedNodes.count) visible nodes")
        } catch let err as FileTreeError {
            error = err
            logger.error("Failed to load file tree: \(err.localizedDescription ?? "unknown")")
        } catch {
            self.error = .loadFailed(rootURL, underlying: error.localizedDescription)
            logger.error("Failed to load file tree: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Reload the entire tree (preserving expansion state where possible)
    public func reloadTree() async {
        let expandedPaths = collectExpandedPaths()
        await loadTree()
        restoreExpandedPaths(expandedPaths)
    }

    /// Toggle expansion of a directory node
    public func toggleExpansion(_ node: FileTreeNode) async {
        guard node.isDirectory || (node.isSymlink && !node.isExternalSymlink && !node.isBrokenSymlink) else {
            return
        }

        if node.isExpanded {
            collapseNode(node)
        } else {
            await expandNode(node)
        }
    }

    /// Expand a directory node and load its children
    public func expandNode(_ node: FileTreeNode) async {
        guard let root = rootNode else { return }
        guard !node.isExpanded else { return }

        logger.debug("Expanding node: \(node.name)")

        do {
            var localVisited = visitedPaths
            let children = try FileTreeNodeBuilder.loadChildren(
                for: node,
                repoRoot: rootURL,
                visited: &localVisited,
                sortOrder: sortOrder
            )
            visitedPaths = localVisited

            let updatedRoot = updateNodeInTree(root, targetId: node.id) { target in
                updateNode(target, children: children, isExpanded: true)
            }

            rootNode = updatedRoot
            updateFlattenedNodes()
        } catch {
            logger.error("Failed to expand node \(node.name): \(error.localizedDescription)")
        }
    }

    /// Collapse a directory node
    public func collapseNode(_ node: FileTreeNode) {
        guard let root = rootNode else { return }
        guard node.isExpanded else { return }

        logger.debug("Collapsing node: \(node.name)")

        let updatedRoot = updateNodeInTree(root, targetId: node.id) { target in
            updateNode(target, isExpanded: false)
        }

        rootNode = updatedRoot
        updateFlattenedNodes()
    }

    /// Find a node by URL
    public func findNode(url: URL) -> FileTreeNode? {
        guard let root = rootNode else { return nil }
        return findNodeInTree(root, url: url)
    }

    /// Find a file by name (searches entire tree, not just visible nodes)
    public func findFile(named filename: String) -> FileTreeNode? {
        guard let root = rootNode else { return nil }
        return findFileByName(in: root, name: filename.lowercased())
    }

    private func findFileByName(in node: FileTreeNode, name: String) -> FileTreeNode? {
        if node.name.lowercased() == name {
            return node
        }
        guard let children = node.children else { return nil }
        for child in children {
            if let found = findFileByName(in: child, name: name) {
                return found
            }
        }
        return nil
    }

    /// Expand all ancestors of a URL and scroll to it
    public func revealNode(url: URL) async -> FileTreeNode? {
        guard let root = rootNode else { return nil }

        // Get path components relative to root
        let rootPath = rootURL.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path

        guard targetPath.hasPrefix(rootPath) else { return nil }

        let relativePath = String(targetPath.dropFirst(rootPath.count))
        let components = relativePath.split(separator: "/").map(String.init)

        // Expand each parent
        var currentURL = rootURL
        for component in components.dropLast() {
            currentURL = currentURL.appendingPathComponent(component)
            if let node = findNode(url: currentURL), !node.isExpanded {
                await expandNode(node)
            }
        }

        return findNode(url: url)
    }

    /// Create a file reference for chat insertion
    public func createFileReference(for node: FileTreeNode) -> FileReference {
        let relativePath = node.relativePath(from: rootURL)
        return FileReference(url: node.url, relativePath: relativePath, isDirectory: node.isDirectory)
    }

    // MARK: - FSEvents Watching

    private func startWatching() {
        stopWatching()

        logger.info("Starting FSEvents watcher for: \(self.rootURL.path)")

        fsEventsWatcher = FSEventsWatcher(
            paths: [rootURL.path],
            debounceInterval: debounceInterval,
            burstMaxDelay: burstMaxDelay
        ) { [weak self] events in
            Task { @MainActor [weak self] in
                await self?.handleFileSystemEvents(events)
            }
        }

        fsEventsWatcher?.start()
    }

    private func stopWatching() {
        fsEventsWatcher?.stop()
        fsEventsWatcher = nil
    }

    private func handleFileSystemEvents(_ events: [FSEvent]) async {
        logger.debug("Received \(events.count) FSEvents")

        // Collect affected directories
        var affectedDirectories: Set<URL> = []
        for event in events {
            let url = URL(fileURLWithPath: event.path)
            let parentURL = url.deletingLastPathComponent()
            affectedDirectories.insert(parentURL)

            // If a directory was modified, also refresh it
            if event.flags.contains(.itemIsDir) {
                affectedDirectories.insert(url)
            }
        }

        // Refresh affected directories
        for directoryURL in affectedDirectories {
            await refreshDirectory(at: directoryURL)
        }
    }

    private func refreshDirectory(at url: URL) async {
        guard let root = rootNode else { return }
        guard let node = findNodeInTree(root, url: url) else { return }
        guard node.isExpanded else { return }

        logger.debug("Refreshing directory: \(url.lastPathComponent)")

        do {
            var localVisited = visitedPaths
            let children = try FileTreeNodeBuilder.loadChildren(
                for: node,
                repoRoot: rootURL,
                visited: &localVisited,
                sortOrder: sortOrder
            )
            visitedPaths = localVisited

            let updatedRoot = updateNodeInTree(root, targetId: node.id) { target in
                updateNode(target, children: children)
            }

            rootNode = updatedRoot
            updateFlattenedNodes()
        } catch {
            logger.error("Failed to refresh directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Flattened Node List (for virtualization)

    private func updateFlattenedNodes() {
        guard let root = rootNode else {
            flattenedNodes = []
            return
        }

        var nodes: [FlattenedNode] = []
        flattenNode(root, depth: 0, into: &nodes)
        flattenedNodes = nodes
    }

    private func flattenNode(_ node: FileTreeNode, depth: Int, into nodes: inout [FlattenedNode]) {
        // Skip root node from display (it's the worktree folder itself)
        if depth > 0 {
            nodes.append(FlattenedNode(node: node, depth: depth - 1))
        }

        if node.isExpanded, let children = node.children {
            for child in children {
                flattenNode(child, depth: depth + 1, into: &nodes)
            }
        }
    }

    // MARK: - Tree Manipulation Helpers

    private func updateNode(
        _ node: FileTreeNode,
        children: [FileTreeNode]? = nil,
        isExpanded: Bool? = nil
    ) -> FileTreeNode {
        FileTreeNode(
            id: node.id,
            url: node.url,
            name: node.name,
            kind: node.kind,
            isHidden: node.isHidden,
            size: node.size,
            modificationDate: node.modificationDate,
            isExpanded: isExpanded ?? node.isExpanded,
            children: children ?? node.children,
            symlinkTarget: node.symlinkTarget,
            isExternalSymlink: node.isExternalSymlink,
            isBrokenSymlink: node.isBrokenSymlink,
            errorMessage: node.errorMessage
        )
    }

    private func updateNodeInTree(
        _ node: FileTreeNode,
        targetId: UUID,
        transform: (FileTreeNode) -> FileTreeNode
    ) -> FileTreeNode {
        if node.id == targetId {
            return transform(node)
        }

        guard let children = node.children else {
            return node
        }

        let updatedChildren = children.map { child in
            updateNodeInTree(child, targetId: targetId, transform: transform)
        }

        return updateNode(node, children: updatedChildren)
    }

    private func findNodeInTree(_ node: FileTreeNode, url: URL) -> FileTreeNode? {
        let normalizedURL = url.standardizedFileURL
        let nodeURL = node.url.standardizedFileURL

        if nodeURL == normalizedURL {
            return node
        }

        guard let children = node.children else {
            return nil
        }

        for child in children {
            if let found = findNodeInTree(child, url: url) {
                return found
            }
        }

        return nil
    }

    private func collectExpandedPaths() -> Set<String> {
        guard let root = rootNode else { return [] }
        var paths: Set<String> = []
        collectExpandedPaths(from: root, into: &paths)
        return paths
    }

    private func collectExpandedPaths(from node: FileTreeNode, into paths: inout Set<String>) {
        if node.isExpanded {
            paths.insert(node.url.path)
        }
        if let children = node.children {
            for child in children {
                collectExpandedPaths(from: child, into: &paths)
            }
        }
    }

    private func restoreExpandedPaths(_ paths: Set<String>) {
        guard var root = rootNode else { return }

        func restoreExpansion(in node: inout FileTreeNode) {
            if paths.contains(node.url.path) && node.isDirectory {
                node = updateNode(node, isExpanded: true)
            }
            if var children = node.children {
                for i in children.indices {
                    restoreExpansion(in: &children[i])
                }
                node = updateNode(node, children: children)
            }
        }

        restoreExpansion(in: &root)
        rootNode = root
        updateFlattenedNodes()
    }
}

// MARK: - FlattenedNode

/// A node in the flattened list for virtualized rendering
public struct FlattenedNode: Identifiable {
    public let node: FileTreeNode
    public let depth: Int

    public var id: UUID { node.id }

    /// Indentation for this node
    public var indent: CGFloat {
        CGFloat(depth) * FileTreeVirtualization.indentPerLevel
    }
}

// MARK: - FSEventsWatcher

/// Wrapper around FSEvents for file system monitoring
public final class FSEventsWatcher {
    private let paths: [String]
    private let debounceInterval: TimeInterval
    private let burstMaxDelay: TimeInterval
    private let callback: ([FSEvent]) -> Void

    private var eventStream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
    private var pendingEvents: [FSEvent] = []
    private var burstStartTime: Date?
    private let queue = DispatchQueue(label: "com.blaze.fsevents", qos: .utility)
    private let logger = Logger(subsystem: "com.blaze.filetree", category: "FSEventsWatcher")

    public init(
        paths: [String],
        debounceInterval: TimeInterval,
        burstMaxDelay: TimeInterval,
        callback: @escaping ([FSEvent]) -> Void
    ) {
        self.paths = paths
        self.debounceInterval = debounceInterval
        self.burstMaxDelay = burstMaxDelay
        self.callback = callback
    }

    deinit {
        stop()
    }

    public func start() {
        guard eventStream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = paths as CFArray

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        eventStream = FSEventStreamCreate(
            nil,
            { (stream, clientCallbackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                guard let info = clientCallbackInfo else { return }
                let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()

                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
                let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))

                var events: [FSEvent] = []
                for i in 0..<numEvents {
                    events.append(FSEvent(
                        path: paths[i],
                        flags: FSEventFlags(rawValue: flags[i]),
                        eventId: eventIds[i]
                    ))
                }

                watcher.handleEvents(events)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,  // Latency in seconds (100ms)
            flags
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            logger.info("FSEvents watcher started for \(self.paths.count) paths")
        }
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
            logger.info("FSEvents watcher stopped")
        }
    }

    private func handleEvents(_ events: [FSEvent]) {
        queue.async { [weak self] in
            self?.processEvents(events)
        }
    }

    private func processEvents(_ newEvents: [FSEvent]) {
        // Cancel pending debounce
        debounceWorkItem?.cancel()

        // Add to pending events
        pendingEvents.append(contentsOf: newEvents)

        // Initialize burst start time
        if burstStartTime == nil {
            burstStartTime = Date()
        }

        // Check if we've exceeded burst max delay
        let now = Date()
        if let burstStart = burstStartTime,
           now.timeIntervalSince(burstStart) >= burstMaxDelay {
            flushEvents()
            return
        }

        // Schedule debounced flush
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushEvents()
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func flushEvents() {
        guard !pendingEvents.isEmpty else { return }

        // Coalesce events per directory
        var coalescedEvents: [String: FSEvent] = [:]
        for event in pendingEvents {
            let dir = (event.path as NSString).deletingLastPathComponent
            if let existing = coalescedEvents[dir] {
                coalescedEvents[dir] = FSEvent(
                    path: existing.path,
                    flags: FSEventFlags(rawValue: existing.flags.rawValue | event.flags.rawValue),
                    eventId: max(existing.eventId, event.eventId)
                )
            } else {
                coalescedEvents[dir] = event
            }
        }

        let events = Array(coalescedEvents.values)
        logger.debug("Flushing \(events.count) coalesced events from \(self.pendingEvents.count) raw events")

        pendingEvents.removeAll()
        burstStartTime = nil

        callback(events)
    }
}

// MARK: - FSEvent

/// Represents a single file system event
public struct FSEvent {
    public let path: String
    public let flags: FSEventFlags
    public let eventId: FSEventStreamEventId

    public init(path: String, flags: FSEventFlags, eventId: FSEventStreamEventId) {
        self.path = path
        self.flags = flags
        self.eventId = eventId
    }
}

// MARK: - FSEventFlags

/// Wrapper for FSEvent flags
public struct FSEventFlags: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let itemCreated = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemCreated))
    public static let itemRemoved = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRemoved))
    public static let itemRenamed = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRenamed))
    public static let itemModified = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemModified))
    public static let itemIsDir = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsDir))
    public static let itemIsFile = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsFile))
    public static let itemIsSymlink = FSEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsSymlink))
}
