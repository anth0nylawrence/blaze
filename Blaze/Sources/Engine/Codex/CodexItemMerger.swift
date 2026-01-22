//
//  CodexItemMerger.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import os.log

// MARK: - Codex Item

/// Represents an item from Codex CLI response.
/// Items are the atomic units of content in Codex streaming output.
public struct CodexItem: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier for the item (from Codex `item_id`)
    public let id: String

    /// Type discriminator (e.g., "message", "function_call", "function_call_output")
    public let type: CodexItemType

    /// Primary content of the item
    public let content: String

    /// Optional metadata (tool name, file path, etc.)
    public let metadata: CodexItemMetadata?

    /// Timestamp when the item was received/created
    public let timestamp: Date

    public init(
        id: String,
        type: CodexItemType,
        content: String,
        metadata: CodexItemMetadata? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// MARK: - Item Type

/// Type discriminator for Codex items
public enum CodexItemType: String, Codable, Sendable {
    case message
    case functionCall = "function_call"
    case functionCallOutput = "function_call_output"
    case reasoning
    case fileDiff = "file_diff"
    case system
    case unknown
}

// MARK: - Item Metadata

/// Optional metadata attached to Codex items
public struct CodexItemMetadata: Codable, Sendable, Equatable {
    public let toolName: String?
    public let filePath: String?
    public let status: String?
    public let extra: [String: String]?

    public init(
        toolName: String? = nil,
        filePath: String? = nil,
        status: String? = nil,
        extra: [String: String]? = nil
    ) {
        self.toolName = toolName
        self.filePath = filePath
        self.status = status
        self.extra = extra
    }

    /// Returns true if this metadata has any non-nil fields
    public var hasContent: Bool {
        toolName != nil || filePath != nil || status != nil || (extra?.isEmpty == false)
    }
}

// MARK: - Merge Decision

/// Represents a merge decision for logging/debugging
public enum MergeDecision: String, Sendable {
    case keepRemote = "keep_remote"
    case keepLocal = "keep_local"
    case addUnique = "add_unique"
    case skipDuplicate = "skip_duplicate"
}

// MARK: - Codex Item Merger

/// Merges local streaming items with server-side history on resume.
///
/// ## Merge Strategy
/// When resuming a session, the server returns canonical history but local streaming
/// may have accumulated items not yet reflected in remote state. This merger:
/// 1. Deduplicates by itemId
/// 2. For duplicates, keeps the "richer" version (more content/metadata)
/// 3. Preserves ordering: remote items first (chronological), then unique local items
///
/// ## Usage
/// ```swift
/// let merger = CodexItemMerger()
/// let merged = merger.merge(remote: serverItems, local: localItems)
/// ```
public struct CodexItemMerger: Sendable {
    private let logger = Logger(subsystem: "com.cogit0.blaze", category: "CodexItemMerger")

    public init() {}

    // MARK: - Full Merge

    /// Merges remote and local item arrays, deduplicating and preserving richness.
    ///
    /// - Parameters:
    ///   - remote: Items from server-side history (canonical source)
    ///   - local: Items accumulated locally during streaming
    /// - Returns: Merged array with remote items first, then unique local items
    public func merge(remote: [CodexItem], local: [CodexItem]) -> [CodexItem] {
        // Edge case: remote only
        guard !local.isEmpty else {
            logger.debug("Merge: remote only (\(remote.count) items)")
            return remote
        }

        // Edge case: local only
        guard !remote.isEmpty else {
            logger.debug("Merge: local only (\(local.count) items)")
            return local
        }

        // Edge case: both empty
        if remote.isEmpty && local.isEmpty {
            logger.debug("Merge: both empty")
            return []
        }

        // Build index of local items by ID for O(1) lookup
        var localById: [String: CodexItem] = [:]
        for item in local {
            localById[item.id] = item
        }

        // Track which local items were matched (for adding uniques later)
        var matchedLocalIds: Set<String> = []

        // Process remote items, potentially enriching from local versions
        var result: [CodexItem] = []
        result.reserveCapacity(remote.count + local.count)

        for remoteItem in remote {
            if let localItem = localById[remoteItem.id] {
                // Duplicate found - pick richer version
                matchedLocalIds.insert(remoteItem.id)
                let decision = pickRicher(remote: remoteItem, local: localItem)
                let picked = decision == .keepRemote ? remoteItem : localItem
                result.append(picked)

                logger.debug("Merge decision for '\(remoteItem.id)': \(decision.rawValue)")
            } else {
                // Remote-only item
                result.append(remoteItem)
            }
        }

        // Append unique local items (not in remote)
        var uniqueLocalCount = 0
        for item in local where !matchedLocalIds.contains(item.id) {
            result.append(item)
            uniqueLocalCount += 1
            logger.debug("Added unique local item: '\(item.id)'")
        }

        logger.info("Merge complete: \(remote.count) remote + \(uniqueLocalCount) unique local = \(result.count) total")

        return result
    }

    // MARK: - Incremental Merge

    /// Merges a single new item into an existing array.
    /// Used for post-resume updates when new items stream in.
    ///
    /// - Parameters:
    ///   - existing: Current array of items
    ///   - newItem: New item to merge
    /// - Returns: Updated array with new item merged
    public func mergeIncremental(existing: [CodexItem], newItem: CodexItem) -> [CodexItem] {
        // Check if item already exists
        if let existingIndex = existing.firstIndex(where: { $0.id == newItem.id }) {
            // Duplicate - decide which to keep
            let existingItem = existing[existingIndex]
            let decision = pickRicher(remote: existingItem, local: newItem)

            if decision == .keepLocal {
                // Replace with richer version
                var updated = existing
                updated[existingIndex] = newItem
                logger.debug("Incremental merge: replaced '\(newItem.id)' with richer version")
                return updated
            } else {
                // Keep existing
                logger.debug("Incremental merge: kept existing '\(newItem.id)'")
                return existing
            }
        }

        // New item - append
        logger.debug("Incremental merge: appended new item '\(newItem.id)'")
        return existing + [newItem]
    }

    // MARK: - Richness Comparison

    /// Compares two items and returns which version is "richer".
    ///
    /// Richness heuristic (in order of priority):
    /// 1. Non-empty content beats empty content
    /// 2. Longer content (by byte length) is richer
    /// 3. Presence of metadata is richer
    /// 4. More metadata fields is richer
    ///
    /// - Parameters:
    ///   - remote: The server-side version
    ///   - local: The locally-streamed version
    /// - Returns: Decision on which to keep
    private func pickRicher(remote: CodexItem, local: CodexItem) -> MergeDecision {
        let remoteRichness = computeRichness(remote)
        let localRichness = computeRichness(local)

        if remoteRichness > localRichness {
            return .keepRemote
        } else if localRichness > remoteRichness {
            return .keepLocal
        } else {
            // Tie-breaker: prefer remote (canonical source)
            return .keepRemote
        }
    }

    /// Computes a richness score for an item.
    /// Higher score = richer content.
    private func computeRichness(_ item: CodexItem) -> Int {
        var score = 0

        // Non-empty content: +100 base
        if !item.content.isEmpty {
            score += 100
        }

        // Content length: +1 per 100 bytes (capped at 50 points)
        let lengthPoints = min(item.content.utf8.count / 100, 50)
        score += lengthPoints

        // Metadata presence: +20
        if let metadata = item.metadata, metadata.hasContent {
            score += 20

            // Additional metadata fields: +5 each
            if metadata.toolName != nil { score += 5 }
            if metadata.filePath != nil { score += 5 }
            if metadata.status != nil { score += 5 }
            if let extra = metadata.extra {
                score += min(extra.count * 2, 10)
            }
        }

        return score
    }
}
