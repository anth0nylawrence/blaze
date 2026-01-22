import Foundation

// MARK: - Git Worktree Manager

/// Manages git worktrees for session isolation per Phase 2 System Contract.
///
/// **Contract Guarantees:**
/// - Worktrees are created at `{repo}/.blaze-worktrees/<sessionId>/`
/// - Branch names follow pattern `blaze-session-<short-uuid>`
/// - Operations serialize per-repo via RepoLockManager
/// - Orphan detection and cleanup on startup
public actor GitWorktreeManager {

    // MARK: - Dependencies

    private let repoLockManager: RepoLockManager
    private let fileManager = FileManager.default

    // MARK: - Constants

    /// Directory name for worktrees within repo
    public static let worktreesDirectoryName = ".blaze-worktrees"

    /// Branch prefix for session branches
    public static let branchPrefix = "blaze-session-"

    // MARK: - Initialization

    public init(repoLockManager: RepoLockManager = RepoLockManager()) {
        self.repoLockManager = repoLockManager
    }

    // MARK: - Public API

    /// Create a worktree for a session.
    ///
    /// - Parameters:
    ///   - repoPath: Canonical path to the repository root
    ///   - sessionId: UUID of the session
    ///   - baseBranch: Base branch to create from (default: current HEAD)
    /// - Returns: WorktreeInfo with path and branch name
    /// - Throws: GitWorktreeError if creation fails
    public func createWorktree(
        repoPath: String,
        sessionId: UUID,
        baseBranch: String? = nil
    ) async throws -> WorktreeInfo {
        // Canonicalize repo path
        guard let canonicalRepo = PathUtilities.canonicalize(repoPath) else {
            throw GitWorktreeError.invalidRepoPath(repoPath)
        }

        // Verify it's a git repo
        guard try await isGitRepository(canonicalRepo) else {
            throw GitWorktreeError.notAGitRepository(canonicalRepo)
        }

        // Serialize per-repo to avoid lock contention
        return try await repoLockManager.withLock(for: canonicalRepo, operation: "createWorktree") {
            try await self.createWorktreeUnsafe(
                repoPath: canonicalRepo,
                sessionId: sessionId,
                baseBranch: baseBranch
            )
        }
    }

    /// Remove a worktree.
    ///
    /// - Parameter worktreePath: Path to the worktree directory
    /// - Throws: GitWorktreeError if removal fails
    public func removeWorktree(worktreePath: String) async throws {
        guard let canonicalPath = PathUtilities.canonicalize(worktreePath) else {
            throw GitWorktreeError.invalidWorktreePath(worktreePath)
        }

        // Extract repo path from worktree path
        guard let repoPath = extractRepoPath(from: canonicalPath) else {
            throw GitWorktreeError.invalidWorktreePath(worktreePath)
        }

        return try await repoLockManager.withLock(for: repoPath, operation: "removeWorktree") {
            try await self.removeWorktreeUnsafe(repoPath: repoPath, worktreePath: canonicalPath)
        }
    }

    /// List all worktrees for a repository.
    ///
    /// - Parameter repoPath: Path to the repository
    /// - Returns: Array of WorktreeInfo
    public func listWorktrees(repoPath: String) async throws -> [WorktreeInfo] {
        guard let canonicalRepo = PathUtilities.canonicalize(repoPath) else {
            throw GitWorktreeError.invalidRepoPath(repoPath)
        }

        let result = try await runGitCommand(
            ["worktree", "list", "--porcelain"],
            in: canonicalRepo
        )

        return parseWorktreeList(result.stdout, repoPath: canonicalRepo)
    }

    /// Prune stale worktree entries (entries pointing to missing directories).
    ///
    /// - Parameter repoPath: Path to the repository
    public func pruneStaleWorktrees(repoPath: String) async throws {
        guard let canonicalRepo = PathUtilities.canonicalize(repoPath) else {
            throw GitWorktreeError.invalidRepoPath(repoPath)
        }

        return try await repoLockManager.withLock(for: canonicalRepo, operation: "pruneWorktrees") {
            _ = try await self.runGitCommand(["worktree", "prune"], in: canonicalRepo)
        }
    }

    /// Scan for orphan worktrees (worktrees without matching sessions).
    ///
    /// - Parameter knownSessionIds: Set of known session UUIDs
    /// - Parameter projectPaths: Paths to check for worktrees
    /// - Returns: Array of OrphanWorktree entries
    public func scanForOrphans(
        knownSessionIds: Set<UUID>,
        projectPaths: [String]
    ) async throws -> [OrphanWorktree] {
        var orphans: [OrphanWorktree] = []

        for projectPath in projectPaths {
            guard let canonicalPath = PathUtilities.canonicalize(projectPath) else { continue }

            let worktreesDir = URL(fileURLWithPath: canonicalPath)
                .appendingPathComponent(Self.worktreesDirectoryName)

            guard fileManager.fileExists(atPath: worktreesDir.path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(at: worktreesDir, includingPropertiesForKeys: [.contentModificationDateKey])

                for item in contents {
                    // Try to extract session ID from directory name
                    if let sessionId = UUID(uuidString: item.lastPathComponent.uppercased()),
                       !knownSessionIds.contains(sessionId) {
                        let modDate = try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                        orphans.append(OrphanWorktree(
                            path: item.path,
                            projectPath: canonicalPath,
                            sessionId: sessionId,
                            lastModified: modDate ?? Date()
                        ))
                    }
                }
            } catch {
                print("[GitWorktreeManager] Error scanning \(worktreesDir.path): \(error)")
            }
        }

        return orphans
    }

    /// Check if a path is a git repository.
    public func isGitRepository(_ path: String) async throws -> Bool {
        let gitDir = URL(fileURLWithPath: path).appendingPathComponent(".git")
        return fileManager.fileExists(atPath: gitDir.path)
    }

    /// Initialize a git repository with user consent.
    ///
    /// - Parameters:
    ///   - path: Path to initialize
    ///   - createInitialCommit: Whether to create an initial commit
    /// - Throws: GitWorktreeError if initialization fails
    public func initRepository(
        at path: String,
        createInitialCommit: Bool = false
    ) async throws {
        guard let canonicalPath = PathUtilities.canonicalize(path) else {
            throw GitWorktreeError.invalidRepoPath(path)
        }

        // Run git init
        _ = try await runGitCommand(["init"], in: canonicalPath)

        if createInitialCommit {
            // Add all files
            _ = try await runGitCommand(["add", "-A"], in: canonicalPath)

            // Check if there's anything to commit
            let status = try await runGitCommand(["status", "--porcelain"], in: canonicalPath)
            if !status.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Create initial commit
                _ = try await runGitCommand(
                    ["commit", "-m", "Initial commit"],
                    in: canonicalPath
                )
            }
        }
    }

    /// Check if git is installed and available.
    public func isGitInstalled() async -> Bool {
        do {
            let result = try await runCommand(["git", "--version"], in: nil)
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    /// Get the current branch name for a repository.
    public func getCurrentBranch(repoPath: String) async throws -> String? {
        guard let canonicalPath = PathUtilities.canonicalize(repoPath) else { return nil }

        let result = try await runGitCommand(
            ["rev-parse", "--abbrev-ref", "HEAD"],
            in: canonicalPath
        )

        let branch = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty ? nil : branch
    }

    /// Get available branches for a repository.
    public func getBranches(repoPath: String) async throws -> [String] {
        guard let canonicalPath = PathUtilities.canonicalize(repoPath) else { return [] }

        let result = try await runGitCommand(
            ["branch", "--format=%(refname:short)"],
            in: canonicalPath
        )

        return result.stdout
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Private Implementation

    private func createWorktreeUnsafe(
        repoPath: String,
        sessionId: UUID,
        baseBranch: String?
    ) async throws -> WorktreeInfo {
        // Generate branch name
        let shortId = String(sessionId.uuidString.prefix(8).lowercased())
        var branchName = "\(Self.branchPrefix)\(shortId)"

        // Check for branch collision and regenerate if needed
        var attempts = 0
        while try await branchExists(branchName, in: repoPath) && attempts < 10 {
            branchName = "\(Self.branchPrefix)\(shortId)-\(attempts)"
            attempts += 1
        }

        // Build worktree path
        let worktreePath = URL(fileURLWithPath: repoPath)
            .appendingPathComponent(Self.worktreesDirectoryName)
            .appendingPathComponent(sessionId.uuidString.lowercased())
            .path

        // Ensure worktrees directory exists
        let worktreesDir = URL(fileURLWithPath: repoPath)
            .appendingPathComponent(Self.worktreesDirectoryName)
        try fileManager.createDirectory(at: worktreesDir, withIntermediateDirectories: true)

        // Build git command
        var args = ["worktree", "add"]

        if let base = baseBranch {
            // Create from specific branch
            args.append(contentsOf: ["-b", branchName, worktreePath, base])
        } else {
            // Create from HEAD
            args.append(contentsOf: ["-b", branchName, worktreePath])
        }

        // Run git worktree add
        let result = try await runGitCommand(args, in: repoPath)

        if result.exitCode != 0 {
            throw GitWorktreeError.worktreeCreationFailed(
                path: worktreePath,
                message: result.stderr
            )
        }

        return WorktreeInfo(
            path: worktreePath,
            branchName: branchName,
            sessionId: sessionId,
            repoPath: repoPath
        )
    }

    private func removeWorktreeUnsafe(repoPath: String, worktreePath: String) async throws {
        // First, try to get branch name before removing
        let worktrees = try await listWorktrees(repoPath: repoPath)
        let worktree = worktrees.first { $0.path == worktreePath }

        // Remove the worktree
        let result = try await runGitCommand(
            ["worktree", "remove", "--force", worktreePath],
            in: repoPath
        )

        if result.exitCode != 0 {
            throw GitWorktreeError.worktreeRemovalFailed(
                path: worktreePath,
                message: result.stderr
            )
        }

        // Delete the branch if it was a blaze session branch
        if let branchName = worktree?.branchName,
           branchName.hasPrefix(Self.branchPrefix) {
            _ = try? await runGitCommand(
                ["branch", "-D", branchName],
                in: repoPath
            )
        }
    }

    private func branchExists(_ branchName: String, in repoPath: String) async throws -> Bool {
        let result = try await runGitCommand(
            ["show-ref", "--verify", "--quiet", "refs/heads/\(branchName)"],
            in: repoPath
        )
        return result.exitCode == 0
    }

    private func extractRepoPath(from worktreePath: String) -> String? {
        // Worktree path format: {repo}/.blaze-worktrees/{sessionId}
        let components = worktreePath.split(separator: "/")
        if let worktreesIndex = components.lastIndex(of: Substring(Self.worktreesDirectoryName)) {
            let repoComponents = components.prefix(upTo: worktreesIndex)
            return "/" + repoComponents.joined(separator: "/")
        }
        return nil
    }

    private func parseWorktreeList(_ output: String, repoPath: String) -> [WorktreeInfo] {
        var worktrees: [WorktreeInfo] = []
        var currentPath: String?
        var currentBranch: String?

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)

            if lineStr.isEmpty {
                // End of worktree entry
                if let path = currentPath {
                    // Try to extract session ID from path
                    let sessionId: UUID? = {
                        let components = path.split(separator: "/")
                        if let last = components.last,
                           let uuid = UUID(uuidString: String(last).uppercased()) {
                            return uuid
                        }
                        return nil
                    }()

                    worktrees.append(WorktreeInfo(
                        path: path,
                        branchName: currentBranch,
                        sessionId: sessionId,
                        repoPath: repoPath
                    ))
                }
                currentPath = nil
                currentBranch = nil
            } else if lineStr.hasPrefix("worktree ") {
                currentPath = String(lineStr.dropFirst("worktree ".count))
            } else if lineStr.hasPrefix("branch refs/heads/") {
                currentBranch = String(lineStr.dropFirst("branch refs/heads/".count))
            }
        }

        // Handle last entry if output doesn't end with newline
        if let path = currentPath {
            let sessionId: UUID? = {
                let components = path.split(separator: "/")
                if let last = components.last,
                   let uuid = UUID(uuidString: String(last).uppercased()) {
                    return uuid
                }
                return nil
            }()

            worktrees.append(WorktreeInfo(
                path: path,
                branchName: currentBranch,
                sessionId: sessionId,
                repoPath: repoPath
            ))
        }

        return worktrees
    }

    // MARK: - Command Execution

    private func runGitCommand(_ args: [String], in directory: String) async throws -> CommandResult {
        try await runCommand(["git", "-C", directory] + args, in: directory)
    }

    private func runCommand(_ args: [String], in directory: String?) async throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if let dir = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}

// MARK: - Supporting Types

/// Information about a git worktree.
public struct WorktreeInfo: Sendable {
    public let path: String
    public let branchName: String?
    public let sessionId: UUID?
    public let repoPath: String

    public init(path: String, branchName: String?, sessionId: UUID?, repoPath: String) {
        self.path = path
        self.branchName = branchName
        self.sessionId = sessionId
        self.repoPath = repoPath
    }
}

/// Information about an orphaned worktree.
public struct OrphanWorktree: Sendable, Identifiable {
    public let path: String
    public let projectPath: String
    public let sessionId: UUID
    public let lastModified: Date

    public var id: UUID { sessionId }

    public init(path: String, projectPath: String, sessionId: UUID, lastModified: Date) {
        self.path = path
        self.projectPath = projectPath
        self.sessionId = sessionId
        self.lastModified = lastModified
    }
}

/// Result of a command execution.
private struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

// MARK: - Errors

/// Errors that can occur during git worktree operations.
public enum GitWorktreeError: Error, LocalizedError {
    case invalidRepoPath(String)
    case invalidWorktreePath(String)
    case notAGitRepository(String)
    case gitNotInstalled
    case worktreeCreationFailed(path: String, message: String)
    case worktreeRemovalFailed(path: String, message: String)
    case branchCollision(String)
    case lockTimeout(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRepoPath(let path):
            return "Invalid repository path: \(path)"
        case .invalidWorktreePath(let path):
            return "Invalid worktree path: \(path)"
        case .notAGitRepository(let path):
            return "Not a git repository: \(path)"
        case .gitNotInstalled:
            return "Git is not installed or not in PATH"
        case .worktreeCreationFailed(let path, let message):
            return "Failed to create worktree at \(path): \(message)"
        case .worktreeRemovalFailed(let path, let message):
            return "Failed to remove worktree at \(path): \(message)"
        case .branchCollision(let name):
            return "Branch name collision: \(name)"
        case .lockTimeout(let repo):
            return "Timed out waiting for lock on \(repo)"
        }
    }
}
