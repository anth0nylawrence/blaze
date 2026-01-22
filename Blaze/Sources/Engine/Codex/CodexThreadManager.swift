//
//  CodexThreadManager.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import os.log

private let threadLog = OSLog(subsystem: "com.cogit0.Blaze", category: "CodexThreadManager")

// MARK: - CodexThread Model

/// Represents a Codex conversation thread.
///
/// Threads are server-side persisted within a workspace. Each thread tracks
/// its creation time and last activity for sorting by recency.
public struct CodexThread: Identifiable, Sendable, Codable, Equatable {
    /// Unique thread identifier (server-assigned).
    public let threadId: String

    /// Parent workspace identifier.
    public let workspaceId: String

    /// When the thread was created (ISO 8601).
    public let createdAt: Date

    /// When the thread was last active (ISO 8601).
    public var lastActivity: Date

    /// Optional thread title/summary.
    public var title: String?

    /// Whether the thread is archived.
    public var isArchived: Bool

    // MARK: - Identifiable

    public var id: String { threadId }

    // MARK: - Initialization

    public init(
        threadId: String,
        workspaceId: String,
        createdAt: Date,
        lastActivity: Date,
        title: String? = nil,
        isArchived: Bool = false
    ) {
        self.threadId = threadId
        self.workspaceId = workspaceId
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.title = title
        self.isArchived = isArchived
    }
}

// MARK: - Pagination Cursor

/// Cursor for paginated thread listing.
public struct CodexThreadCursor: Sendable, Codable {
    /// Opaque cursor string from the server.
    public let value: String

    /// Whether more results are available.
    public let hasMore: Bool

    public init(value: String, hasMore: Bool) {
        self.value = value
        self.hasMore = hasMore
    }
}

// MARK: - Thread List Result

/// Result of listing threads with pagination info.
public struct CodexThreadListResult: Sendable {
    /// Threads returned in this page.
    public let threads: [CodexThread]

    /// Cursor for fetching the next page (nil if no more).
    public let nextCursor: CodexThreadCursor?

    /// Total count (if provided by server).
    public let totalCount: Int?

    public init(threads: [CodexThread], nextCursor: CodexThreadCursor?, totalCount: Int?) {
        self.threads = threads
        self.nextCursor = nextCursor
        self.totalCount = totalCount
    }
}

// MARK: - Thread Manager Errors

/// Errors from thread management operations.
public enum CodexThreadError: Error, LocalizedError {
    case threadNotFound(threadId: String)
    case workspaceNotFound(workspaceId: String)
    case invalidResponse(reason: String)
    case alreadyArchived(threadId: String)
    case rpcError(code: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .threadNotFound(let id):
            return "Thread not found: \(id)"
        case .workspaceNotFound(let id):
            return "Workspace not found: \(id)"
        case .invalidResponse(let reason):
            return "Invalid response from Codex: \(reason)"
        case .alreadyArchived(let id):
            return "Thread already archived: \(id)"
        case .rpcError(let code, let message):
            return "Codex RPC error \(code): \(message)"
        }
    }
}

// MARK: - CodexThreadManager

/// Manages Codex thread lifecycle via JSON-RPC.
///
/// ## Responsibilities
/// - List threads with cursor-based pagination
/// - Start new threads
/// - Resume existing threads
/// - Archive threads
///
/// ## Usage
/// ```swift
/// let manager = CodexThreadManager(adapter: adapter)
///
/// // List threads for a workspace
/// let result = try await manager.listThreads(workspaceId: "ws-123", cwd: "/path/to/project")
///
/// // Start a new thread
/// let thread = try await manager.startThread(workspaceId: "ws-123")
///
/// // Resume an existing thread
/// let restored = try await manager.resumeThread(threadId: "th-456")
///
/// // Archive a thread
/// try await manager.archiveThread(threadId: "th-456")
/// ```
public actor CodexThreadManager {
    // MARK: - Dependencies

    private let adapter: CodexStdioAdapter

    // MARK: - State

    /// Cache of known threads, keyed by threadId.
    private var threadCache: [String: CodexThread] = [:]

    /// ISO 8601 date formatter for parsing server responses.
    private let dateFormatter: ISO8601DateFormatter

    // MARK: - Initialization

    /// Create a thread manager using the given stdio adapter.
    ///
    /// - Parameter adapter: Running CodexStdioAdapter instance.
    init(adapter: CodexStdioAdapter) {
        self.adapter = adapter

        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    // MARK: - Thread Operations

    /// List threads in a workspace with pagination.
    ///
    /// - Parameters:
    ///   - workspaceId: Workspace to list threads from.
    ///   - cwd: Optional working directory filter.
    ///   - cursor: Pagination cursor from previous call (nil for first page).
    ///   - limit: Maximum threads to return (default 50).
    /// - Returns: Thread list result with pagination info.
    public func listThreads(
        workspaceId: String,
        cwd: String? = nil,
        cursor: CodexThreadCursor? = nil,
        limit: Int = 50
    ) async throws -> CodexThreadListResult {
        var params: [String: Any] = [
            "workspaceId": workspaceId,
            "limit": limit
        ]

        if let cwd = cwd {
            params["cwd"] = cwd
        }

        if let cursor = cursor {
            params["cursor"] = cursor.value
        }

        os_log(.debug, log: threadLog, "Listing threads for workspace %{public}@ (limit: %d)",
               workspaceId, limit)

        let response = try await adapter.sendRequest(method: "thread/list", params: params)

        // Check for error response
        if let error = response.error {
            throw CodexThreadError.rpcError(code: error.code, message: error.message)
        }

        guard let resultDict = response.result?.value as? [String: Any] else {
            throw CodexThreadError.invalidResponse(reason: "Missing result object")
        }

        // Parse threads array
        guard let threadsArray = resultDict["threads"] as? [[String: Any]] else {
            throw CodexThreadError.invalidResponse(reason: "Missing threads array")
        }

        var threads = try threadsArray.map { try parseThread(from: $0) }

        // Sort by most recent activity (descending)
        threads.sort { $0.lastActivity > $1.lastActivity }

        // Deduplicate by threadId (keep most recent)
        threads = deduplicateThreads(threads)

        // Update cache
        for thread in threads {
            threadCache[thread.threadId] = thread
        }

        // Parse pagination cursor
        var nextCursor: CodexThreadCursor?
        if let cursorValue = resultDict["nextCursor"] as? String {
            let hasMore = resultDict["hasMore"] as? Bool ?? true
            nextCursor = CodexThreadCursor(value: cursorValue, hasMore: hasMore)
        }

        let totalCount = resultDict["totalCount"] as? Int

        os_log(.debug, log: threadLog, "Listed %d threads (hasMore: %{public}@)",
               threads.count, String(describing: nextCursor?.hasMore))

        return CodexThreadListResult(
            threads: threads,
            nextCursor: nextCursor,
            totalCount: totalCount
        )
    }

    /// Start a new thread in a workspace.
    ///
    /// - Parameters:
    ///   - workspaceId: Workspace to create thread in.
    ///   - title: Optional initial title for the thread.
    ///   - cwd: Optional working directory for the thread.
    /// - Returns: The newly created thread.
    public func startThread(
        workspaceId: String,
        title: String? = nil,
        cwd: String? = nil
    ) async throws -> CodexThread {
        var params: [String: Any] = [
            "workspaceId": workspaceId
        ]

        if let title = title {
            params["title"] = title
        }

        if let cwd = cwd {
            params["cwd"] = cwd
        }

        os_log(.info, log: threadLog, "Starting new thread in workspace %{public}@", workspaceId)

        let response = try await adapter.sendRequest(method: "thread/start", params: params)

        if let error = response.error {
            throw CodexThreadError.rpcError(code: error.code, message: error.message)
        }

        guard let resultDict = response.result?.value as? [String: Any] else {
            throw CodexThreadError.invalidResponse(reason: "Missing result object")
        }

        let thread = try parseThread(from: resultDict)

        // Cache the new thread
        threadCache[thread.threadId] = thread

        os_log(.info, log: threadLog, "Created thread %{public}@", thread.threadId)

        return thread
    }

    /// Resume an existing thread, restoring conversation context.
    ///
    /// - Parameter threadId: Thread identifier to resume.
    /// - Returns: The restored thread with updated activity timestamp.
    public func resumeThread(threadId: String) async throws -> CodexThread {
        let params: [String: Any] = [
            "threadId": threadId
        ]

        os_log(.info, log: threadLog, "Resuming thread %{public}@", threadId)

        let response = try await adapter.sendRequest(method: "thread/resume", params: params)

        if let error = response.error {
            // Check for specific error codes
            if error.code == -32001 { // Thread not found
                throw CodexThreadError.threadNotFound(threadId: threadId)
            }
            throw CodexThreadError.rpcError(code: error.code, message: error.message)
        }

        guard let resultDict = response.result?.value as? [String: Any] else {
            throw CodexThreadError.invalidResponse(reason: "Missing result object")
        }

        let thread = try parseThread(from: resultDict)

        // Update cache
        threadCache[thread.threadId] = thread

        os_log(.info, log: threadLog, "Resumed thread %{public}@ (last activity: %{public}@)",
               thread.threadId, dateFormatter.string(from: thread.lastActivity))

        return thread
    }

    /// Archive a thread (soft delete).
    ///
    /// - Parameter threadId: Thread identifier to archive.
    public func archiveThread(threadId: String) async throws {
        // Check cache first
        if let cached = threadCache[threadId], cached.isArchived {
            throw CodexThreadError.alreadyArchived(threadId: threadId)
        }

        let params: [String: Any] = [
            "threadId": threadId
        ]

        os_log(.info, log: threadLog, "Archiving thread %{public}@", threadId)

        let response = try await adapter.sendRequest(method: "thread/archive", params: params)

        if let error = response.error {
            if error.code == -32001 {
                throw CodexThreadError.threadNotFound(threadId: threadId)
            }
            throw CodexThreadError.rpcError(code: error.code, message: error.message)
        }

        // Update cache
        if var thread = threadCache[threadId] {
            thread.isArchived = true
            threadCache[threadId] = thread
        }

        os_log(.info, log: threadLog, "Archived thread %{public}@", threadId)
    }

    // MARK: - Cache Management

    /// Get a cached thread by ID.
    ///
    /// - Parameter threadId: Thread identifier.
    /// - Returns: Cached thread or nil if not in cache.
    public func getCachedThread(threadId: String) -> CodexThread? {
        threadCache[threadId]
    }

    /// Clear the thread cache.
    public func clearCache() {
        threadCache.removeAll()
        os_log(.debug, log: threadLog, "Thread cache cleared")
    }

    // MARK: - Private Helpers

    /// Parse a thread from a dictionary response.
    private func parseThread(from dict: [String: Any]) throws -> CodexThread {
        guard let threadId = dict["threadId"] as? String else {
            throw CodexThreadError.invalidResponse(reason: "Missing threadId")
        }

        guard let workspaceId = dict["workspaceId"] as? String else {
            throw CodexThreadError.invalidResponse(reason: "Missing workspaceId")
        }

        let createdAt: Date
        if let createdAtString = dict["createdAt"] as? String {
            createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }

        let lastActivity: Date
        if let lastActivityString = dict["lastActivity"] as? String {
            lastActivity = dateFormatter.date(from: lastActivityString) ?? createdAt
        } else {
            lastActivity = createdAt
        }

        let title = dict["title"] as? String
        let isArchived = dict["isArchived"] as? Bool ?? false

        return CodexThread(
            threadId: threadId,
            workspaceId: workspaceId,
            createdAt: createdAt,
            lastActivity: lastActivity,
            title: title,
            isArchived: isArchived
        )
    }

    /// Deduplicate threads by threadId, keeping the one with most recent activity.
    private func deduplicateThreads(_ threads: [CodexThread]) -> [CodexThread] {
        var seen: [String: CodexThread] = [:]

        for thread in threads {
            if let existing = seen[thread.threadId] {
                // Keep the one with more recent lastActivity
                if thread.lastActivity > existing.lastActivity {
                    seen[thread.threadId] = thread
                }
            } else {
                seen[thread.threadId] = thread
            }
        }

        // Return sorted by lastActivity descending
        return seen.values.sorted { $0.lastActivity > $1.lastActivity }
    }
}
