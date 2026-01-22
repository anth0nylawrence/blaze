import Foundation
import GRDB

// MARK: - Bookmark Store

/// Persistent storage for file bookmarks (pinned files/folders).
///
/// **Phase 2 System Contract:**
/// - Bookmarks are per-repo for project-scoped pins
/// - Supports both file and directory bookmarks
/// - Maintains display order for sorting
public actor BookmarkStore {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) throws {
        self.dbPool = dbPool
        try ensureTable()
    }

    // MARK: - Table Setup

    private func ensureTable() throws {
        try dbPool.write { db in
            guard try !db.tableExists("bookmarks") else { return }

            try db.create(table: "bookmarks") { t in
                t.column("id", .text).primaryKey()
                t.column("repo_id", .text)
                    .references("repos", onDelete: .cascade)
                t.column("path", .text).notNull()
                t.column("is_directory", .boolean).notNull()
                t.column("display_name", .text)
                t.column("display_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull()
                t.column("icon", .text)  // Custom SF Symbol name
                t.column("color", .text) // Hex color code
            }
            try db.create(index: "bookmarks_repo_id", on: "bookmarks", columns: ["repo_id"])
            try db.create(index: "bookmarks_path", on: "bookmarks", columns: ["repo_id", "path"])
        }
    }

    // MARK: - CRUD Operations

    /// Create a new bookmark
    public func create(_ bookmark: Bookmark) async throws {
        try await dbPool.write { db in
            try BookmarkRecord(bookmark).insert(db)
        }
    }

    /// Get a bookmark by ID
    public func get(id: UUID) async throws -> Bookmark? {
        try await dbPool.read { db in
            try BookmarkRecord.fetchOne(db, key: id.uuidString)?.toBookmark()
        }
    }

    /// Get all bookmarks for a repo
    public func getBookmarks(repoId: UUID) async throws -> [Bookmark] {
        try await dbPool.read { db in
            try BookmarkRecord
                .filter(Column("repo_id") == repoId.uuidString)
                .order(Column("display_order"))
                .fetchAll(db)
                .map { $0.toBookmark() }
        }
    }

    /// Get all global bookmarks (no repo association)
    public func getGlobalBookmarks() async throws -> [Bookmark] {
        try await dbPool.read { db in
            try BookmarkRecord
                .filter(Column("repo_id") == nil)
                .order(Column("display_order"))
                .fetchAll(db)
                .map { $0.toBookmark() }
        }
    }

    /// Update a bookmark
    public func update(_ bookmark: Bookmark) async throws {
        try await dbPool.write { db in
            try BookmarkRecord(bookmark).update(db)
        }
    }

    /// Delete a bookmark
    public func delete(id: UUID) async throws {
        _ = try await dbPool.write { db in
            try BookmarkRecord.deleteOne(db, key: id.uuidString)
        }
    }

    /// Reorder bookmarks
    public func reorder(ids: [UUID]) async throws {
        try await dbPool.write { db in
            for (index, id) in ids.enumerated() {
                try db.execute(sql: """
                    UPDATE bookmarks SET display_order = ? WHERE id = ?
                """, arguments: [index, id.uuidString])
            }
        }
    }

    /// Check if a path is bookmarked
    public func isBookmarked(path: String, repoId: UUID?) async throws -> Bool {
        try await dbPool.read { db in
            if let repoId = repoId {
                return try BookmarkRecord
                    .filter(Column("repo_id") == repoId.uuidString && Column("path") == path)
                    .fetchCount(db) > 0
            } else {
                return try BookmarkRecord
                    .filter(Column("repo_id") == nil && Column("path") == path)
                    .fetchCount(db) > 0
            }
        }
    }
}

// MARK: - Bookmark Model

/// A bookmarked file or directory
public struct Bookmark: Identifiable, Codable, Sendable {
    public let id: UUID
    public let repoId: UUID?
    public let path: String
    public let isDirectory: Bool
    public var displayName: String?
    public var displayOrder: Int
    public let createdAt: Date
    public var icon: String?
    public var color: String?

    public var fileName: String {
        (path as NSString).lastPathComponent
    }

    public var effectiveDisplayName: String {
        displayName ?? fileName
    }

    public init(
        id: UUID = UUID(),
        repoId: UUID? = nil,
        path: String,
        isDirectory: Bool,
        displayName: String? = nil,
        displayOrder: Int = 0,
        icon: String? = nil,
        color: String? = nil
    ) {
        self.id = id
        self.repoId = repoId
        self.path = path
        self.isDirectory = isDirectory
        self.displayName = displayName
        self.displayOrder = displayOrder
        self.createdAt = Date()
        self.icon = icon
        self.color = color
    }
}

// MARK: - Database Record

private struct BookmarkRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "bookmarks"

    let id: String
    let repoId: String?
    let path: String
    let isDirectory: Bool
    var displayName: String?
    var displayOrder: Int
    let createdAt: Date
    var icon: String?
    var color: String?

    init(_ bookmark: Bookmark) {
        self.id = bookmark.id.uuidString
        self.repoId = bookmark.repoId?.uuidString
        self.path = bookmark.path
        self.isDirectory = bookmark.isDirectory
        self.displayName = bookmark.displayName
        self.displayOrder = bookmark.displayOrder
        self.createdAt = bookmark.createdAt
        self.icon = bookmark.icon
        self.color = bookmark.color
    }

    func toBookmark() -> Bookmark {
        Bookmark(
            id: UUID(uuidString: id)!,
            repoId: repoId.flatMap { UUID(uuidString: $0) },
            path: path,
            isDirectory: isDirectory,
            displayName: displayName,
            displayOrder: displayOrder,
            icon: icon,
            color: color
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case repoId = "repo_id"
        case path
        case isDirectory = "is_directory"
        case displayName = "display_name"
        case displayOrder = "display_order"
        case createdAt = "created_at"
        case icon
        case color
    }
}
