import Foundation

// MARK: - Diff Service

/// Service for handling diff accept/reject file operations
actor DiffService {

    // MARK: - Errors

    enum DiffError: Error, LocalizedError {
        case fileNotFound(String)
        case writePermissionDenied(String)
        case gitNotAvailable
        case gitOperationFailed(String)
        case invalidDiff
        case uncommittedChanges(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .writePermissionDenied(let path):
                return "Write permission denied for: \(path)"
            case .gitNotAvailable:
                return "Git is not available in PATH"
            case .gitOperationFailed(let message):
                return "Git operation failed: \(message)"
            case .invalidDiff:
                return "Invalid diff structure"
            case .uncommittedChanges(let path):
                return "Cannot reject diff - file has uncommitted changes: \(path)"
            }
        }
    }

    // MARK: - Accept Diff (D8.4)

    /// Accept a diff by writing the new content to the file system
    /// - Parameters:
    ///   - diff: The file diff to accept
    ///   - projectPath: The project root path for resolving relative paths
    /// - Returns: The updated FileDiff with accepted decision
    func acceptDiff(_ diff: FileDiff, projectPath: String) async throws -> FileDiff {
        let resolvedPath = resolvePath(diff.filePath, projectPath: projectPath)

        // Build the new file content from the diff
        let newContent = try buildNewContent(from: diff)

        // Verify we can write to the path
        let fileManager = FileManager.default
        let directory = (resolvedPath as NSString).deletingLastPathComponent

        // Create directory if needed
        if !fileManager.fileExists(atPath: directory) {
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        // Check write permission
        if fileManager.fileExists(atPath: resolvedPath) {
            if !fileManager.isWritableFile(atPath: resolvedPath) {
                throw DiffError.writePermissionDenied(resolvedPath)
            }
        }

        // Write the new content
        try newContent.write(toFile: resolvedPath, atomically: true, encoding: .utf8)

        // Return updated diff with accepted decision
        var updatedDiff = diff
        updatedDiff.decision = .accepted
        return updatedDiff
    }

    // MARK: - Reject Diff (D8.5)

    /// Reject a diff by reverting the file to its original state
    /// Uses git checkout for tracked files, or deletes for new files
    /// - Parameters:
    ///   - diff: The file diff to reject
    ///   - projectPath: The project root path
    /// - Returns: The updated FileDiff with rejected decision
    func rejectDiff(_ diff: FileDiff, projectPath: String) async throws -> FileDiff {
        let resolvedPath = resolvePath(diff.filePath, projectPath: projectPath)
        let fileManager = FileManager.default

        // Check if file exists
        guard fileManager.fileExists(atPath: resolvedPath) else {
            // File doesn't exist, nothing to reject (might be a new file that wasn't written yet)
            var updatedDiff = diff
            updatedDiff.decision = .rejected
            return updatedDiff
        }

        // Check if we're in a git repository
        let isGitRepo = await isGitRepository(path: projectPath)

        if isGitRepo {
            // Check if file is tracked by git
            let isTracked = await isFileTracked(path: resolvedPath, projectPath: projectPath)

            if isTracked {
                // Use git checkout to revert
                try await gitCheckout(path: resolvedPath, projectPath: projectPath)
            } else {
                // Untracked file - check if it's a new file (all additions)
                let isNewFile = diff.hunks.allSatisfy { hunk in
                    hunk.lines.allSatisfy { $0.type == .addition }
                }

                if isNewFile {
                    // Delete the new file
                    try fileManager.removeItem(atPath: resolvedPath)
                } else {
                    // Modified untracked file - can't safely revert
                    throw DiffError.uncommittedChanges(resolvedPath)
                }
            }
        } else {
            // Not a git repo - try to restore from original content
            let originalContent = try buildOriginalContent(from: diff)
            try originalContent.write(toFile: resolvedPath, atomically: true, encoding: .utf8)
        }

        var updatedDiff = diff
        updatedDiff.decision = .rejected
        return updatedDiff
    }

    // MARK: - Content Building

    /// Build the new file content from a diff (after applying changes)
    private func buildNewContent(from diff: FileDiff) throws -> String {
        var lines: [String] = []

        for hunk in diff.hunks {
            for line in hunk.lines {
                switch line.type {
                case .context, .addition:
                    lines.append(line.content)
                case .deletion:
                    // Skip deleted lines in new content
                    continue
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Build the original file content from a diff (before changes)
    private func buildOriginalContent(from diff: FileDiff) throws -> String {
        var lines: [String] = []

        for hunk in diff.hunks {
            for line in hunk.lines {
                switch line.type {
                case .context, .deletion:
                    lines.append(line.content)
                case .addition:
                    // Skip added lines in original content
                    continue
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Path Resolution

    private func resolvePath(_ path: String, projectPath: String) -> String {
        if path.hasPrefix("/") {
            return path
        } else {
            return (projectPath as NSString).appendingPathComponent(path)
        }
    }

    // MARK: - Git Operations

    private func isGitRepository(path: String) async -> Bool {
        do {
            let result = try await runGitCommand(["rev-parse", "--is-inside-work-tree"], in: path)
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            return false
        }
    }

    private func isFileTracked(path: String, projectPath: String) async -> Bool {
        do {
            // Get relative path for git
            let relativePath = path.replacingOccurrences(of: projectPath + "/", with: "")
            let result = try await runGitCommand(["ls-files", relativePath], in: projectPath)
            return !result.isEmpty
        } catch {
            return false
        }
    }

    private func gitCheckout(path: String, projectPath: String) async throws {
        // Get relative path for git
        let relativePath = path.replacingOccurrences(of: projectPath + "/", with: "")

        do {
            _ = try await runGitCommand(["checkout", "--", relativePath], in: projectPath)
        } catch {
            throw DiffError.gitOperationFailed("Failed to checkout \(relativePath): \(error.localizedDescription)")
        }
    }

    private func runGitCommand(_ args: [String], in directory: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw DiffError.gitOperationFailed(errorString)
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }

    // MARK: - Batch Operations

    /// Accept multiple diffs
    func acceptDiffs(_ diffs: [FileDiff], projectPath: String) async throws -> [FileDiff] {
        var results: [FileDiff] = []
        for diff in diffs {
            let updated = try await acceptDiff(diff, projectPath: projectPath)
            results.append(updated)
        }
        return results
    }

    /// Reject multiple diffs
    func rejectDiffs(_ diffs: [FileDiff], projectPath: String) async throws -> [FileDiff] {
        var results: [FileDiff] = []
        for diff in diffs {
            let updated = try await rejectDiff(diff, projectPath: projectPath)
            results.append(updated)
        }
        return results
    }
}

// MARK: - FileDiff Extension

extension FileDiff {
    /// Create a mutable copy with updated decision
    func withDecision(_ decision: DiffDecision) -> FileDiff {
        var copy = self
        copy.decision = decision
        return copy
    }
}
