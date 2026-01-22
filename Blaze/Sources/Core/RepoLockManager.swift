import Foundation

// MARK: - Repo Lock Manager (Atom A005)

/// Manages per-repository locks to prevent concurrent git operations.
///
/// **System Contract Guarantees:**
/// - Only one git operation per repository at a time
/// - Locks are keyed by canonical repo path
/// - Automatic cleanup when actor is deallocated
/// - Fair ordering (FIFO) for waiting operations
public actor RepoLockManager {

    /// Lock state for a repository
    private struct RepoLock {
        var isLocked: Bool = false
        var waiters: [CheckedContinuation<Void, Never>] = []
        var lockHolder: String?
        var lockedAt: Date?
    }

    /// Locks keyed by canonical repository path
    private var locks: [String: RepoLock] = [:]

    /// Timeout for stale lock detection (5 minutes)
    private let staleLockTimeout: TimeInterval = 300

    public init() {}

    // MARK: - Public API

    /// Acquire a lock for the given repository path.
    /// Blocks until the lock is available.
    ///
    /// - Parameters:
    ///   - repoPath: Canonical path to the repository
    ///   - operation: Description of the operation (for debugging)
    public func acquireLock(for repoPath: String, operation: String = "unknown") async {
        let canonicalPath = PathUtilities.canonicalize(repoPath) ?? repoPath

        // Check if lock exists
        if locks[canonicalPath] == nil {
            locks[canonicalPath] = RepoLock()
        }

        // Check if lock is available
        if !locks[canonicalPath]!.isLocked {
            locks[canonicalPath]!.isLocked = true
            locks[canonicalPath]!.lockHolder = operation
            locks[canonicalPath]!.lockedAt = Date()
            return
        }

        // Check for stale lock
        if let lockedAt = locks[canonicalPath]!.lockedAt,
           Date().timeIntervalSince(lockedAt) > staleLockTimeout {
            // Force release stale lock
            print("[RepoLockManager] Force releasing stale lock for \(canonicalPath) (held by: \(locks[canonicalPath]!.lockHolder ?? "unknown"))", to: &standardError)
            locks[canonicalPath]!.isLocked = true
            locks[canonicalPath]!.lockHolder = operation
            locks[canonicalPath]!.lockedAt = Date()
            return
        }

        // Wait for lock to be released
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            locks[canonicalPath]!.waiters.append(continuation)
        }

        // Now we have the lock
        locks[canonicalPath]!.lockHolder = operation
        locks[canonicalPath]!.lockedAt = Date()
    }

    /// Release the lock for the given repository path.
    ///
    /// - Parameter repoPath: Canonical path to the repository
    public func releaseLock(for repoPath: String) {
        let canonicalPath = PathUtilities.canonicalize(repoPath) ?? repoPath

        guard var lock = locks[canonicalPath] else { return }

        if !lock.waiters.isEmpty {
            // Resume next waiter
            let waiter = lock.waiters.removeFirst()
            lock.lockHolder = nil
            lock.lockedAt = nil
            locks[canonicalPath] = lock
            waiter.resume()
        } else {
            // No waiters, release lock
            lock.isLocked = false
            lock.lockHolder = nil
            lock.lockedAt = nil
            locks[canonicalPath] = lock
        }
    }

    /// Execute an operation while holding the repository lock.
    ///
    /// - Parameters:
    ///   - repoPath: Canonical path to the repository
    ///   - operation: Description of the operation
    ///   - action: The async action to perform while holding the lock
    public func withLock<T>(
        for repoPath: String,
        operation: String = "unknown",
        action: () async throws -> T
    ) async rethrows -> T {
        await acquireLock(for: repoPath, operation: operation)
        defer { releaseLock(for: repoPath) }
        return try await action()
    }

    /// Check if a repository is currently locked.
    public func isLocked(_ repoPath: String) -> Bool {
        let canonicalPath = PathUtilities.canonicalize(repoPath) ?? repoPath
        return locks[canonicalPath]?.isLocked ?? false
    }

    /// Get the current lock holder for a repository.
    public func lockHolder(for repoPath: String) -> String? {
        let canonicalPath = PathUtilities.canonicalize(repoPath) ?? repoPath
        return locks[canonicalPath]?.lockHolder
    }

    /// Get the number of waiters for a repository lock.
    public func waiterCount(for repoPath: String) -> Int {
        let canonicalPath = PathUtilities.canonicalize(repoPath) ?? repoPath
        return locks[canonicalPath]?.waiters.count ?? 0
    }

    /// Force release all locks (for cleanup/testing).
    public func releaseAllLocks() {
        for (path, var lock) in locks {
            for waiter in lock.waiters {
                waiter.resume()
            }
            lock.waiters.removeAll()
            lock.isLocked = false
            lock.lockHolder = nil
            lock.lockedAt = nil
            locks[path] = lock
        }
    }
}

// MARK: - Standard Error Helper

private var standardError = FileHandle.standardError
