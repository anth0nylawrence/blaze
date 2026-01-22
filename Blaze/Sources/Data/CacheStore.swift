import Foundation
import GRDB

// MARK: - Cache Store

/// Derived cache storage for file tree snapshots and search indexes.
///
/// **System Contract (Phase 2):**
/// - Optional in-memory + on-disk caches for file tree snapshots, search indexes
/// - Caches speed up file tree load and refresh
/// - Caches are derived data - can be regenerated from source
///
/// **Storage:**
/// - file_cache table: file tree snapshots per repo
/// - search_index table: search index metadata per repo
actor CacheStore {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - File Tree Cache

    /// Get cached file tree for a repo.
    func getFileTree(repoId: UUID) async throws -> [FileCacheEntry] {
        try await dbPool.read { db in
            try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .order(Column("path"))
                .fetchAll(db)
        }
    }

    /// Get cached file tree for a repo under a specific path.
    func getFileTree(repoId: UUID, parentPath: String?) async throws -> [FileCacheEntry] {
        try await dbPool.read { db in
            var query = FileCacheEntry.filter(Column("repo_id") == repoId.uuidString)

            if let parentPath {
                query = query.filter(Column("parent_path") == parentPath)
            } else {
                query = query.filter(Column("parent_path") == nil)
            }

            return try query.order(Column("is_directory").desc, Column("path")).fetchAll(db)
        }
    }

    /// Cache a file tree snapshot for a repo.
    func cacheFileTree(repoId: UUID, entries: [FileCacheEntry]) async throws {
        try await dbPool.write { db in
            // Clear existing cache for this repo
            try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .deleteAll(db)

            // Insert new entries
            for entry in entries {
                try entry.insert(db)
            }
        }
    }

    /// Update a single file in the cache (for incremental updates).
    func updateFileCache(_ entry: FileCacheEntry) async throws {
        try await dbPool.write { db in
            // Upsert: delete existing if any, then insert
            try FileCacheEntry
                .filter(Column("repo_id") == entry.repoId)
                .filter(Column("path") == entry.path)
                .deleteAll(db)

            try entry.insert(db)
        }
    }

    /// Remove a file from the cache.
    func removeFromFileCache(repoId: UUID, path: String) async throws {
        try await dbPool.write { db in
            try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .filter(Column("path") == path)
                .deleteAll(db)
        }
    }

    /// Clear file cache for a repo.
    func clearFileCache(repoId: UUID) async throws {
        try await dbPool.write { db in
            try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .deleteAll(db)
        }
    }

    /// Check if file cache exists and is recent.
    func hasRecentFileCache(repoId: UUID, maxAge: TimeInterval = 300) async throws -> Bool {
        let cutoff = Date().addingTimeInterval(-maxAge)
        return try await dbPool.read { db in
            let count = try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .filter(Column("cached_at") > cutoff)
                .fetchCount(db)
            return count > 0
        }
    }

    // MARK: - Search Index Cache

    /// Get search index entries for a repo.
    func getSearchIndex(repoId: UUID) async throws -> [SearchIndexEntry] {
        try await dbPool.read { db in
            try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .order(Column("path"))
                .fetchAll(db)
        }
    }

    /// Get search index entry for a specific file.
    func getSearchIndexEntry(repoId: UUID, path: String) async throws -> SearchIndexEntry? {
        try await dbPool.read { db in
            try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .filter(Column("path") == path)
                .fetchOne(db)
        }
    }

    /// Check if a file needs reindexing based on content hash.
    func needsReindexing(repoId: UUID, path: String, contentHash: String) async throws -> Bool {
        let existing = try await getSearchIndexEntry(repoId: repoId, path: path)
        return existing?.contentHash != contentHash
    }

    /// Update search index for a file.
    func updateSearchIndex(_ entry: SearchIndexEntry) async throws {
        try await dbPool.write { db in
            // Upsert
            try SearchIndexEntry
                .filter(Column("repo_id") == entry.repoId)
                .filter(Column("path") == entry.path)
                .deleteAll(db)

            try entry.insert(db)
        }
    }

    /// Bulk update search index.
    func updateSearchIndex(entries: [SearchIndexEntry]) async throws {
        try await dbPool.write { db in
            for entry in entries {
                try SearchIndexEntry
                    .filter(Column("repo_id") == entry.repoId)
                    .filter(Column("path") == entry.path)
                    .deleteAll(db)

                try entry.insert(db)
            }
        }
    }

    /// Remove file from search index.
    func removeFromSearchIndex(repoId: UUID, path: String) async throws {
        try await dbPool.write { db in
            try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .filter(Column("path") == path)
                .deleteAll(db)
        }
    }

    /// Clear search index for a repo.
    func clearSearchIndex(repoId: UUID) async throws {
        try await dbPool.write { db in
            try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .deleteAll(db)
        }
    }

    /// Get files that need indexing (not in index or stale).
    func getFilesNeedingIndexing(repoId: UUID) async throws -> [FileCacheEntry] {
        try await dbPool.read { db in
            // Get all files from file cache
            let files = try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .filter(Column("is_directory") == false)
                .fetchAll(db)

            // Get indexed paths
            let indexedPaths = try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .select(Column("path"))
                .fetchAll(db)
                .map { $0.path }

            let indexedSet = Set(indexedPaths)
            return files.filter { !indexedSet.contains($0.path) }
        }
    }

    // MARK: - Cache Statistics

    /// Get cache statistics for a repo.
    func getCacheStats(repoId: UUID) async throws -> CacheStats {
        try await dbPool.read { db in
            let fileCount = try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .fetchCount(db)

            let dirCount = try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .filter(Column("is_directory") == true)
                .fetchCount(db)

            let indexedCount = try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .fetchCount(db)

            let lastCached = try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .select(max(Column("cached_at")))
                .fetchOne(db) as Date?

            let lastIndexed = try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .select(max(Column("indexed_at")))
                .fetchOne(db) as Date?

            return CacheStats(
                repoId: repoId,
                fileCount: fileCount,
                directoryCount: dirCount,
                indexedCount: indexedCount,
                lastCached: lastCached,
                lastIndexed: lastIndexed
            )
        }
    }

    // MARK: - Cleanup

    /// Clear all caches for a repo.
    func clearAllCaches(repoId: UUID) async throws {
        try await dbPool.write { db in
            try FileCacheEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .deleteAll(db)
            try SearchIndexEntry
                .filter(Column("repo_id") == repoId.uuidString)
                .deleteAll(db)
        }
    }

    /// Clear stale caches older than given age.
    func clearStaleCaches(maxAge: TimeInterval) async throws {
        let cutoff = Date().addingTimeInterval(-maxAge)
        try await dbPool.write { db in
            try FileCacheEntry
                .filter(Column("cached_at") < cutoff)
                .deleteAll(db)
            try SearchIndexEntry
                .filter(Column("indexed_at") < cutoff)
                .deleteAll(db)
        }
    }
}

// MARK: - File Cache Entry

/// Cached file tree entry.
public struct FileCacheEntry: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "file_cache"

    public let id: String
    public let repoId: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modifiedAt: Date?
    public let cachedAt: Date
    public let parentPath: String?

    public init(
        id: String = UUID().uuidString,
        repoId: UUID,
        path: String,
        isDirectory: Bool,
        size: Int64? = nil,
        modifiedAt: Date? = nil,
        cachedAt: Date = Date(),
        parentPath: String? = nil
    ) {
        self.id = id
        self.repoId = repoId.uuidString
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
        self.cachedAt = cachedAt
        self.parentPath = parentPath
    }

    /// Create from file URL.
    public static func from(url: URL, repoId: UUID, repoRoot: URL) throws -> FileCacheEntry {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let relativePath = url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
        let parentPath = url.deletingLastPathComponent().path.replacingOccurrences(of: repoRoot.path + "/", with: "")

        return FileCacheEntry(
            repoId: repoId,
            path: relativePath,
            isDirectory: attrs[.type] as? FileAttributeType == .typeDirectory,
            size: attrs[.size] as? Int64,
            modifiedAt: attrs[.modificationDate] as? Date,
            parentPath: parentPath.isEmpty || parentPath == repoRoot.path ? nil : parentPath
        )
    }

    /// Get display name (file/folder name).
    public var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    enum CodingKeys: String, CodingKey {
        case id
        case repoId = "repo_id"
        case path
        case isDirectory = "is_directory"
        case size
        case modifiedAt = "modified_at"
        case cachedAt = "cached_at"
        case parentPath = "parent_path"
    }
}

// MARK: - Search Index Entry

/// Search index entry for a file.
public struct SearchIndexEntry: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "search_index"

    public let id: String
    public let repoId: String
    public let path: String
    public let contentHash: String
    public let indexedAt: Date
    public let fileType: String?
    public let lineCount: Int?

    public init(
        id: String = UUID().uuidString,
        repoId: UUID,
        path: String,
        contentHash: String,
        indexedAt: Date = Date(),
        fileType: String? = nil,
        lineCount: Int? = nil
    ) {
        self.id = id
        self.repoId = repoId.uuidString
        self.path = path
        self.contentHash = contentHash
        self.indexedAt = indexedAt
        self.fileType = fileType
        self.lineCount = lineCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case repoId = "repo_id"
        case path
        case contentHash = "content_hash"
        case indexedAt = "indexed_at"
        case fileType = "file_type"
        case lineCount = "line_count"
    }
}

// MARK: - Cache Statistics

/// Statistics about cached data for a repo.
public struct CacheStats: Codable, Sendable {
    public let repoId: UUID
    public let fileCount: Int
    public let directoryCount: Int
    public let indexedCount: Int
    public let lastCached: Date?
    public let lastIndexed: Date?

    /// Percentage of files indexed.
    public var indexedPercentage: Double {
        guard fileCount > 0 else { return 0 }
        return Double(indexedCount) / Double(fileCount) * 100
    }

    /// Whether the cache is considered fresh (< 5 minutes old).
    public var isFresh: Bool {
        guard let lastCached else { return false }
        return Date().timeIntervalSince(lastCached) < 300
    }
}

// MARK: - In-Memory File Tree Cache

/// In-memory cache for file tree with LRU eviction.
/// Use this for fast access to recently viewed directories.
public actor InMemoryFileTreeCache {
    private var cache: [String: CachedFileTree] = [:]  // key: repoId/path
    private var accessOrder: [String] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    /// Get cached file tree entries.
    public func get(repoId: UUID, path: String?) -> [FileCacheEntry]? {
        let key = makeKey(repoId: repoId, path: path)
        guard let entry = cache[key] else { return nil }

        // Check if stale (> 60 seconds)
        if Date().timeIntervalSince(entry.cachedAt) > 60 {
            cache.removeValue(forKey: key)
            return nil
        }

        // Update access order (LRU)
        if let idx = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: idx)
        }
        accessOrder.append(key)

        return entry.entries
    }

    /// Cache file tree entries.
    public func set(repoId: UUID, path: String?, entries: [FileCacheEntry]) {
        let key = makeKey(repoId: repoId, path: path)

        // Evict if at capacity
        while cache.count >= maxEntries, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        cache[key] = CachedFileTree(entries: entries, cachedAt: Date())

        if let idx = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: idx)
        }
        accessOrder.append(key)
    }

    /// Invalidate cache for a repo.
    public func invalidate(repoId: UUID) {
        let prefix = repoId.uuidString + "/"
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) || $0 == repoId.uuidString }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            if let idx = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: idx)
            }
        }
    }

    /// Clear all cached data.
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    private func makeKey(repoId: UUID, path: String?) -> String {
        if let path {
            return "\(repoId.uuidString)/\(path)"
        }
        return repoId.uuidString
    }
}

/// Cached file tree with timestamp.
private struct CachedFileTree {
    let entries: [FileCacheEntry]
    let cachedAt: Date
}
