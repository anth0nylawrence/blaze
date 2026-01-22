import XCTest
import GRDB
@testable import Blaze

final class DiffServiceTests: XCTestCase {
    private var tempDirectory: URL!
    private var diffService: DiffService!

    override func setUp() async throws {
        diffService = DiffService()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlazeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Accept Diff Tests

    func testAcceptDiffCreatesNewFile() async throws {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 0,
            newStart: 1,
            newCount: 3,
            lines: [
                DiffLine(type: .addition, content: "line 1", oldLineNumber: nil, newLineNumber: 1),
                DiffLine(type: .addition, content: "line 2", oldLineNumber: nil, newLineNumber: 2),
                DiffLine(type: .addition, content: "line 3", oldLineNumber: nil, newLineNumber: 3),
            ]
        )

        let diff = FileDiff(filePath: "newfile.swift", hunks: [hunk])
        let result = try await diffService.acceptDiff(diff, projectPath: tempDirectory.path)

        XCTAssertEqual(result.decision, .accepted)

        // Verify file was created
        let filePath = tempDirectory.appendingPathComponent("newfile.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))

        // Verify content
        let content = try String(contentsOf: filePath, encoding: .utf8)
        XCTAssertEqual(content, "line 1\nline 2\nline 3")
    }

    func testAcceptDiffOverwritesExistingFile() async throws {
        // Create existing file
        let filePath = tempDirectory.appendingPathComponent("existing.swift")
        try "old content".write(to: filePath, atomically: true, encoding: .utf8)

        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 1,
            newStart: 1,
            newCount: 2,
            lines: [
                DiffLine(type: .deletion, content: "old content", oldLineNumber: 1, newLineNumber: nil),
                DiffLine(type: .addition, content: "new content", oldLineNumber: nil, newLineNumber: 1),
                DiffLine(type: .addition, content: "extra line", oldLineNumber: nil, newLineNumber: 2),
            ]
        )

        let diff = FileDiff(filePath: "existing.swift", hunks: [hunk])
        let result = try await diffService.acceptDiff(diff, projectPath: tempDirectory.path)

        XCTAssertEqual(result.decision, .accepted)

        // Verify new content
        let content = try String(contentsOf: filePath, encoding: .utf8)
        XCTAssertEqual(content, "new content\nextra line")
    }

    func testAcceptDiffWithAbsolutePath() async throws {
        let filePath = tempDirectory.appendingPathComponent("absolute.swift")

        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 0,
            newStart: 1,
            newCount: 1,
            lines: [
                DiffLine(type: .addition, content: "absolute content", oldLineNumber: nil, newLineNumber: 1),
            ]
        )

        let diff = FileDiff(filePath: filePath.path, hunks: [hunk])
        let result = try await diffService.acceptDiff(diff, projectPath: "/ignored")

        XCTAssertEqual(result.decision, .accepted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
    }

    func testAcceptDiffCreatesDirectories() async throws {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 0,
            newStart: 1,
            newCount: 1,
            lines: [
                DiffLine(type: .addition, content: "nested content", oldLineNumber: nil, newLineNumber: 1),
            ]
        )

        let diff = FileDiff(filePath: "nested/path/to/file.swift", hunks: [hunk])
        let result = try await diffService.acceptDiff(diff, projectPath: tempDirectory.path)

        XCTAssertEqual(result.decision, .accepted)

        let filePath = tempDirectory.appendingPathComponent("nested/path/to/file.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
    }

    // MARK: - Reject Diff Tests

    func testRejectDiffForNonExistentFile() async throws {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 0,
            newStart: 1,
            newCount: 1,
            lines: [
                DiffLine(type: .addition, content: "content", oldLineNumber: nil, newLineNumber: 1),
            ]
        )

        let diff = FileDiff(filePath: "nonexistent.swift", hunks: [hunk])
        let result = try await diffService.rejectDiff(diff, projectPath: tempDirectory.path)

        XCTAssertEqual(result.decision, .rejected)
    }

    // MARK: - FileDiff Extension Tests

    func testWithDecision() {
        let hunk = DiffHunk(
            oldStart: 1, oldCount: 1, newStart: 1, newCount: 1,
            lines: [DiffLine(type: .context, content: "line", oldLineNumber: 1, newLineNumber: 1)]
        )
        let diff = FileDiff(filePath: "test.swift", hunks: [hunk])

        XCTAssertEqual(diff.decision, .pending)

        let accepted = diff.withDecision(.accepted)
        XCTAssertEqual(accepted.decision, .accepted)
        XCTAssertEqual(diff.decision, .pending) // Original unchanged
    }

    // MARK: - Batch Operations Tests

    func testAcceptMultipleDiffs() async throws {
        let hunks = [
            DiffHunk(
                oldStart: 1, oldCount: 0, newStart: 1, newCount: 1,
                lines: [DiffLine(type: .addition, content: "file1", oldLineNumber: nil, newLineNumber: 1)]
            )
        ]

        let diffs = [
            FileDiff(filePath: "file1.swift", hunks: hunks),
            FileDiff(filePath: "file2.swift", hunks: hunks),
            FileDiff(filePath: "file3.swift", hunks: hunks),
        ]

        let results = try await diffService.acceptDiffs(diffs, projectPath: tempDirectory.path)

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.decision == .accepted })

        for i in 1...3 {
            let path = tempDirectory.appendingPathComponent("file\(i).swift")
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        }
    }
}

// MARK: - Event Persistence Tests


