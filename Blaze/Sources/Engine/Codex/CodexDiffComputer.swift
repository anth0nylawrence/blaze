//
//  CodexDiffComputer.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

/// Computes unified diffs from before/after file content for Codex file changes.
///
/// Codex `item/fileChange` events provide full before/after content instead of
/// unified diff format. This utility converts that to `FileDiffProduced` events
/// with proper hunks and line numbers.
///
/// **Algorithm:**
/// Uses a simple LCS (Longest Common Subsequence) approach to identify matching
/// lines, then generates hunks from the diff. Not optimal for very large files
/// but sufficient for typical code changes.
///
/// **Usage:**
/// ```swift
/// let diff = await CodexDiffComputer.computeDiff(
///     before: "line1\nline2",
///     after: "line1\nmodified",
///     filePath: "src/file.swift"
/// )
/// // Returns FileDiffProduced with hunks showing line2 -> modified
/// ```
public enum CodexDiffComputer {
    // MARK: - Public API

    /// Compute a unified diff from before/after file content.
    ///
    /// - Parameters:
    ///   - before: Original file content (empty string for new files)
    ///   - after: New file content (empty string for deleted files)
    ///   - filePath: Path to the file being changed
    /// - Returns: A `FileDiffProduced` event with hunks representing the changes
    public static func computeDiff(
        before: String,
        after: String,
        filePath: String
    ) async -> FileDiffProduced {
        let oldLines = before.isEmpty ? [] : before.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = after.isEmpty ? [] : after.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        let hunks = computeHunks(oldLines: oldLines, newLines: newLines)
        let diffText = generateUnifiedDiffText(
            filePath: filePath,
            hunks: hunks,
            oldLines: oldLines,
            newLines: newLines
        )

        return FileDiffProduced(
            filePath: filePath,
            diff: diffText,
            hunks: hunks,
            timestamp: Date()
        )
    }

    // MARK: - Diff Computation

    /// Edit operation for Myers diff algorithm
    private enum EditOp: Equatable {
        case equal
        case insert
        case delete
    }

    /// Compute diff hunks from old and new line arrays.
    private static func computeHunks(oldLines: [String], newLines: [String]) -> [DiffHunk] {
        // Handle edge cases
        if oldLines.isEmpty && newLines.isEmpty {
            return []
        }

        if oldLines.isEmpty {
            // New file - all additions
            return [createAdditionHunk(newLines: newLines)]
        }

        if newLines.isEmpty {
            // Deleted file - all deletions
            return [createDeletionHunk(oldLines: oldLines)]
        }

        // Compute edit script using LCS
        let editOps = computeEditScript(oldLines: oldLines, newLines: newLines)

        // Convert edit operations to hunks
        return createHunksFromEditOps(
            editOps: editOps,
            oldLines: oldLines,
            newLines: newLines
        )
    }

    /// Compute edit script using LCS-based algorithm.
    private static func computeEditScript(oldLines: [String], newLines: [String]) -> [EditOp] {
        let m = oldLines.count
        let n = newLines.count

        // Build LCS matrix
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if oldLines[i - 1] == newLines[j - 1] {
                    lcs[i][j] = lcs[i - 1][j - 1] + 1
                } else {
                    lcs[i][j] = max(lcs[i - 1][j], lcs[i][j - 1])
                }
            }
        }

        // Backtrack to find edit operations
        var editOps: [EditOp] = []
        var i = m
        var j = n

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
                editOps.append(.equal)
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
                editOps.append(.insert)
                j -= 1
            } else {
                editOps.append(.delete)
                i -= 1
            }
        }

        return editOps.reversed()
    }

    /// Create hunks from edit operations with context lines.
    private static func createHunksFromEditOps(
        editOps: [EditOp],
        oldLines: [String],
        newLines: [String]
    ) -> [DiffHunk] {
        let contextLines = 3

        var hunks: [DiffHunk] = []
        var currentHunkLines: [DiffLine] = []
        var hunkOldStart = 1
        var hunkNewStart = 1
        var oldIndex = 0
        var newIndex = 0
        var lastChangeIndex = -1
        var pendingContextBefore: [DiffLine] = []

        for (opIndex, op) in editOps.enumerated() {
            switch op {
            case .equal:
                let line = oldLines[oldIndex]
                let contextLine = DiffLine(
                    type: .context,
                    content: line,
                    oldLineNumber: oldIndex + 1,
                    newLineNumber: newIndex + 1
                )

                if !currentHunkLines.isEmpty {
                    // We're in a hunk, add context
                    currentHunkLines.append(contextLine)

                    // Check if we should end the hunk (too many context lines after last change)
                    if opIndex - lastChangeIndex > contextLines {
                        // Trim trailing context beyond contextLines
                        let trailingContext = opIndex - lastChangeIndex - 1
                        let trimCount = max(0, trailingContext - contextLines)
                        if trimCount > 0 {
                            currentHunkLines.removeLast(trimCount)
                        }

                        // Check if more changes are coming within context range
                        let remainingOps = editOps.dropFirst(opIndex + 1)
                        let nextChangeOffset = remainingOps.firstIndex(where: { $0 != .equal })
                        let shouldEndHunk = nextChangeOffset == nil || nextChangeOffset! > contextLines

                        if shouldEndHunk {
                            hunks.append(createHunk(
                                lines: currentHunkLines,
                                oldStart: hunkOldStart,
                                newStart: hunkNewStart
                            ))
                            currentHunkLines = []
                        }
                    }
                } else {
                    // Not in a hunk, track potential context before
                    pendingContextBefore.append(contextLine)
                    if pendingContextBefore.count > contextLines {
                        pendingContextBefore.removeFirst()
                    }
                }

                oldIndex += 1
                newIndex += 1

            case .delete:
                if currentHunkLines.isEmpty {
                    // Starting new hunk
                    hunkOldStart = max(1, oldIndex + 1 - pendingContextBefore.count)
                    hunkNewStart = max(1, newIndex + 1 - pendingContextBefore.count)
                    currentHunkLines = pendingContextBefore
                    pendingContextBefore = []
                }

                currentHunkLines.append(DiffLine(
                    type: .deletion,
                    content: oldLines[oldIndex],
                    oldLineNumber: oldIndex + 1,
                    newLineNumber: nil
                ))
                lastChangeIndex = opIndex
                oldIndex += 1

            case .insert:
                if currentHunkLines.isEmpty {
                    // Starting new hunk
                    hunkOldStart = max(1, oldIndex + 1 - pendingContextBefore.count)
                    hunkNewStart = max(1, newIndex + 1 - pendingContextBefore.count)
                    currentHunkLines = pendingContextBefore
                    pendingContextBefore = []
                }

                currentHunkLines.append(DiffLine(
                    type: .addition,
                    content: newLines[newIndex],
                    oldLineNumber: nil,
                    newLineNumber: newIndex + 1
                ))
                lastChangeIndex = opIndex
                newIndex += 1
            }
        }

        // Finalize any remaining hunk
        if !currentHunkLines.isEmpty {
            hunks.append(createHunk(
                lines: currentHunkLines,
                oldStart: hunkOldStart,
                newStart: hunkNewStart
            ))
        }

        return hunks
    }

    /// Create a hunk for a new file (all additions).
    private static func createAdditionHunk(newLines: [String]) -> DiffHunk {
        let lines = newLines.enumerated().map { index, content in
            DiffLine(
                type: .addition,
                content: content,
                oldLineNumber: nil,
                newLineNumber: index + 1
            )
        }

        return DiffHunk(
            oldStart: 0,
            oldCount: 0,
            newStart: 1,
            newCount: newLines.count,
            lines: lines
        )
    }

    /// Create a hunk for a deleted file (all deletions).
    private static func createDeletionHunk(oldLines: [String]) -> DiffHunk {
        let lines = oldLines.enumerated().map { index, content in
            DiffLine(
                type: .deletion,
                content: content,
                oldLineNumber: index + 1,
                newLineNumber: nil
            )
        }

        return DiffHunk(
            oldStart: 1,
            oldCount: oldLines.count,
            newStart: 0,
            newCount: 0,
            lines: lines
        )
    }

    /// Create a hunk from accumulated lines.
    private static func createHunk(
        lines: [DiffLine],
        oldStart: Int,
        newStart: Int
    ) -> DiffHunk {
        let oldCount = lines.filter { $0.type == .context || $0.type == .deletion }.count
        let newCount = lines.filter { $0.type == .context || $0.type == .addition }.count

        return DiffHunk(
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            lines: lines
        )
    }

    // MARK: - Unified Diff Text Generation

    /// Generate unified diff text format.
    private static func generateUnifiedDiffText(
        filePath: String,
        hunks: [DiffHunk],
        oldLines: [String],
        newLines: [String]
    ) -> String {
        guard !hunks.isEmpty else {
            return ""
        }

        var lines: [String] = []

        // Header
        lines.append("--- a/\(filePath)")
        lines.append("+++ b/\(filePath)")

        for hunk in hunks {
            // Hunk header
            lines.append("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")

            // Hunk content
            for line in hunk.lines {
                let prefix: String
                switch line.type {
                case .context:
                    prefix = " "
                case .addition:
                    prefix = "+"
                case .deletion:
                    prefix = "-"
                }
                lines.append("\(prefix)\(line.content)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
