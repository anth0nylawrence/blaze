import XCTest
import GRDB
@testable import Blaze

final class RepoLockManagerTests: XCTestCase {

    // MARK: - Basic Lock Operations

    func testAcquireAndReleaseLock() async {
        let manager = RepoLockManager()

        // Initially not locked
        let initiallyLocked = await manager.isLocked("/test/repo")
        XCTAssertFalse(initiallyLocked)

        // Acquire lock
        await manager.acquireLock(for: "/test/repo", operation: "test-op")
        let afterAcquire = await manager.isLocked("/test/repo")
        XCTAssertTrue(afterAcquire)

        // Release lock
        await manager.releaseLock(for: "/test/repo")
        let afterRelease = await manager.isLocked("/test/repo")
        XCTAssertFalse(afterRelease)
    }

    func testLockHolder() async {
        let manager = RepoLockManager()

        await manager.acquireLock(for: "/test/repo", operation: "git-pull")
        let holder = await manager.lockHolder(for: "/test/repo")
        XCTAssertEqual(holder, "git-pull")

        await manager.releaseLock(for: "/test/repo")
        let holderAfterRelease = await manager.lockHolder(for: "/test/repo")
        XCTAssertNil(holderAfterRelease)
    }

    func testWithLockExecutesAction() async throws {
        let manager = RepoLockManager()
        var executed = false

        let result = await manager.withLock(for: "/test/repo", operation: "test") {
            executed = true
            return "success"
        }

        XCTAssertTrue(executed)
        XCTAssertEqual(result, "success")

        // Lock should be released after withLock completes
        let isLocked = await manager.isLocked("/test/repo")
        XCTAssertFalse(isLocked)
    }

    func testWithLockReleasesOnThrow() async {
        let manager = RepoLockManager()

        struct TestError: Error {}

        do {
            let _: Void = try await manager.withLock(for: "/test/repo", operation: "test") {
                throw TestError()
            }
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }

        // Lock should be released even after error
        let isLocked = await manager.isLocked("/test/repo")
        XCTAssertFalse(isLocked)
    }

    func testWaiterCount() async {
        let manager = RepoLockManager()

        // Initially no waiters
        let initialWaiters = await manager.waiterCount(for: "/test/repo")
        XCTAssertEqual(initialWaiters, 0)
    }

    func testReleaseAllLocks() async {
        let manager = RepoLockManager()

        // Acquire multiple locks
        await manager.acquireLock(for: "/repo1", operation: "op1")
        await manager.acquireLock(for: "/repo2", operation: "op2")

        let locked1 = await manager.isLocked("/repo1")
        let locked2 = await manager.isLocked("/repo2")
        XCTAssertTrue(locked1)
        XCTAssertTrue(locked2)

        // Release all
        await manager.releaseAllLocks()

        let afterRelease1 = await manager.isLocked("/repo1")
        let afterRelease2 = await manager.isLocked("/repo2")
        XCTAssertFalse(afterRelease1)
        XCTAssertFalse(afterRelease2)
    }

    func testMultipleReposIndependent() async {
        let manager = RepoLockManager()

        // Lock repo1
        await manager.acquireLock(for: "/repo1", operation: "op1")

        // Repo2 should still be unlocked
        let repo2Locked = await manager.isLocked("/repo2")
        XCTAssertFalse(repo2Locked)

        // Can lock repo2 while repo1 is locked
        await manager.acquireLock(for: "/repo2", operation: "op2")
        let repo2LockedAfter = await manager.isLocked("/repo2")
        XCTAssertTrue(repo2LockedAfter)

        await manager.releaseAllLocks()
    }
}

// MARK: - Path Utilities Tests (Atom A006)


final class PathUtilitiesTests: XCTestCase {

    // MARK: - Standardize Tests

    func testStandardizePath() {
        // Basic path standardization
        let standardized = PathUtilities.standardize("/foo/bar/../baz")
        XCTAssertEqual(standardized, "/foo/baz")
    }

    func testStandardizeWithDotDot() {
        let standardized = PathUtilities.standardize("/a/b/c/../../d")
        XCTAssertEqual(standardized, "/a/d")
    }

    func testStandardizeAbsolutePath() {
        let standardized = PathUtilities.standardize("/Users/test/project")
        XCTAssertEqual(standardized, "/Users/test/project")
    }

    // MARK: - Worktree Containment Tests

    func testPathWithinWorktree() {
        let worktree = "/Users/test/project"

        // Direct child
        XCTAssertTrue(PathUtilities.isWithinWorktree(
            "/Users/test/project/src/file.swift",
            worktree: worktree
        ))

        // Exact match
        XCTAssertTrue(PathUtilities.isWithinWorktree(
            "/Users/test/project",
            worktree: worktree
        ))

        // Deep nesting
        XCTAssertTrue(PathUtilities.isWithinWorktree(
            "/Users/test/project/a/b/c/d/e.txt",
            worktree: worktree
        ))
    }

    func testPathOutsideWorktree() {
        let worktree = "/Users/test/project"

        // Parent directory
        XCTAssertFalse(PathUtilities.isWithinWorktree(
            "/Users/test",
            worktree: worktree
        ))

        // Sibling directory
        XCTAssertFalse(PathUtilities.isWithinWorktree(
            "/Users/test/other-project",
            worktree: worktree
        ))

        // Completely different path
        XCTAssertFalse(PathUtilities.isWithinWorktree(
            "/var/log/system.log",
            worktree: worktree
        ))
    }

    func testPathWithTraversalInWorktree() {
        let worktree = "/Users/test/project"

        // Traversal that stays within worktree
        XCTAssertTrue(PathUtilities.isWithinWorktree(
            "/Users/test/project/src/../lib/file.swift",
            worktree: worktree
        ))
    }

    // MARK: - Traversal Detection Tests

    func testTraversalAttemptDetection() {
        let worktree = "/Users/test/project"

        // Traversal escaping worktree
        XCTAssertTrue(PathUtilities.hasTraversalAttempt(
            "/Users/test/project/../other/file.txt",
            worktree: worktree
        ))

        // Deep traversal escape
        XCTAssertTrue(PathUtilities.hasTraversalAttempt(
            "/Users/test/project/src/../../secret.txt",
            worktree: worktree
        ))
    }

    func testSafeTraversal() {
        let worktree = "/Users/test/project"

        // Traversal staying within worktree
        XCTAssertFalse(PathUtilities.hasTraversalAttempt(
            "/Users/test/project/a/b/../c/file.txt",
            worktree: worktree
        ))
    }

    // MARK: - Path Comparison Tests

    func testPathsAreEqual() {
        XCTAssertTrue(PathUtilities.pathsAreEqual(
            "/foo/bar",
            "/foo/bar"
        ))

        XCTAssertTrue(PathUtilities.pathsAreEqual(
            "/foo/bar/../bar",
            "/foo/bar"
        ))

        XCTAssertFalse(PathUtilities.pathsAreEqual(
            "/foo/bar",
            "/foo/baz"
        ))
    }

    // MARK: - Relative Path Tests

    func testRelativePath() {
        let relative = PathUtilities.relativePath(
            from: "/Users/test/project",
            to: "/Users/test/project/src/file.swift"
        )
        XCTAssertEqual(relative, "src/file.swift")
    }

    func testRelativePathUpward() {
        let relative = PathUtilities.relativePath(
            from: "/Users/test/project/src",
            to: "/Users/test/project/lib/util.swift"
        )
        XCTAssertEqual(relative, "../lib/util.swift")
    }

    // MARK: - Directory Detection Tests

    func testIsDirectory() {
        // /tmp should exist and be a directory
        XCTAssertTrue(PathUtilities.isDirectory("/tmp"))

        // Non-existent path
        XCTAssertFalse(PathUtilities.isDirectory("/nonexistent/path/xyz123"))
    }

    func testExists() {
        // /tmp should exist
        XCTAssertTrue(PathUtilities.exists("/tmp"))

        // Non-existent path
        XCTAssertFalse(PathUtilities.exists("/nonexistent/path/xyz123"))
    }
}

// MARK: - Path Validation Tests (Atom A007)


final class PathValidationTests: XCTestCase {

    // MARK: - Basic Validation

    func testValidPathWithinWorktree() {
        let result = PathUtilities.validatePath(
            "/Users/test/project/src/file.swift",
            worktree: "/Users/test/project"
        )

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.riskLevel, .low)
    }

    func testPathOutsideWorktreeRisk() {
        let result = PathUtilities.validatePath(
            "/etc/passwd",
            worktree: "/Users/test/project"
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains(.outsideWorktree))
        XCTAssertTrue(result.issues.contains(.sensitivePath))
        XCTAssertEqual(result.riskLevel, .high)
    }

    func testTraversalAttemptDetected() {
        let result = PathUtilities.validatePath(
            "/Users/test/project/../secrets/api.key",
            worktree: "/Users/test/project"
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains(.traversalAttempt))
    }

    // MARK: - Sensitive Path Detection

    func testSensitivePathEtc() {
        let result = PathUtilities.validatePath("/etc/shadow", worktree: nil)
        XCTAssertTrue(result.issues.contains(.sensitivePath))
    }

    func testSensitivePathSsh() {
        let result = PathUtilities.validatePath("~/.ssh/id_rsa", worktree: nil)
        XCTAssertTrue(result.issues.contains(.sensitivePath))
    }

    func testSensitivePathAws() {
        let result = PathUtilities.validatePath("~/.aws/credentials", worktree: nil)
        XCTAssertTrue(result.issues.contains(.sensitivePath))
    }

    func testSensitivePathKube() {
        let result = PathUtilities.validatePath("~/.kube/config", worktree: nil)
        XCTAssertTrue(result.issues.contains(.sensitivePath))
    }

    func testSensitivePathDocker() {
        let result = PathUtilities.validatePath("~/.docker/config.json", worktree: nil)
        XCTAssertTrue(result.issues.contains(.sensitivePath))
    }

    func testSensitivePathGnupg() {
        let result = PathUtilities.validatePath("~/.gnupg/private-keys.d", worktree: nil)
        XCTAssertTrue(result.issues.contains(.sensitivePath))
    }

    func testSensitivePathSystem() {
        // System locations
        XCTAssertTrue(PathUtilities.validatePath("/System/Library/file", worktree: nil).issues.contains(.sensitivePath))
        XCTAssertTrue(PathUtilities.validatePath("/Library/Preferences/plist", worktree: nil).issues.contains(.sensitivePath))
        XCTAssertTrue(PathUtilities.validatePath("/usr/bin/ls", worktree: nil).issues.contains(.sensitivePath))
    }

    // MARK: - Risk Level Tests

    func testRiskLevelLow() {
        let result = PathUtilities.validatePath(
            "/Users/test/project/README.md",
            worktree: "/Users/test/project"
        )
        XCTAssertEqual(result.riskLevel, .low)
    }

    func testRiskLevelHighForEscape() {
        let result = PathUtilities.validatePath(
            "/Users/other/secrets",
            worktree: "/Users/test/project"
        )
        XCTAssertEqual(result.riskLevel, .high)
    }

    // MARK: - No Worktree Tests

    func testValidationWithoutWorktree() {
        // Without worktree, only sensitive path check applies
        let result = PathUtilities.validatePath("/normal/path/file.txt", worktree: nil)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.riskLevel, .low)
    }

    // MARK: - Path Issue Description Tests

    func testPathIssueDescriptions() {
        XCTAssertFalse(PathIssue.traversalAttempt.description.isEmpty)
        XCTAssertFalse(PathIssue.outsideWorktree.description.isEmpty)
        XCTAssertFalse(PathIssue.symlinkEscape.description.isEmpty)
        XCTAssertFalse(PathIssue.absolutePathOutsideWorktree.description.isEmpty)
        XCTAssertFalse(PathIssue.sensitivePath.description.isEmpty)
    }

    func testPathIssueCaseIterable() {
        // Ensure all cases are covered
        XCTAssertEqual(PathIssue.allCases.count, 5)
    }
}

// MARK: - Tool Risk Classifier Tests (Atom A007)


