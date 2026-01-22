import XCTest
import GRDB
@testable import Blaze

final class FileTreePerformanceTests: XCTestCase {

    /// Test that file tree model can handle large numbers of files
    func testLargeFileTreeCreation() throws {
        // Measure time to create a large file tree model
        measure {
            var files: [FileTreeNode] = []

            // Create 10,000 file nodes
            for i in 0..<10_000 {
                let node = FileTreeNode(
                    name: "file_\(i).swift",
                    path: "/project/src/file_\(i).swift",
                    type: .file
                )
                files.append(node)
            }

            // Verify count
            XCTAssertEqual(files.count, 10_000)
        }
    }

    /// Test that file tree sorting is efficient
    func testFileTreeSorting() throws {
        var files: [FileTreeNode] = []

        // Create files with random names
        for i in 0..<10_000 {
            let name = "file_\(arc4random_uniform(100000)).swift"
            let node = FileTreeNode(
                name: name,
                path: "/project/src/\(name)",
                type: .file
            )
            files.append(node)
        }

        // Measure sorting time
        measure {
            let sorted = files.sorted { $0.name < $1.name }
            XCTAssertEqual(sorted.count, 10_000)
        }
    }

    /// Test nested directory structure creation
    func testDeepNestedDirectoryTree() throws {
        measure {
            // Create a deeply nested directory structure (100 levels)
            func createNestedNode(depth: Int, maxDepth: Int) -> FileTreeNode {
                if depth >= maxDepth {
                    return FileTreeNode(
                        name: "file.txt",
                        path: String(repeating: "/dir", count: depth) + "/file.txt",
                        type: .file
                    )
                } else {
                    var node = FileTreeNode(
                        name: "dir\(depth)",
                        path: String(repeating: "/dir", count: depth),
                        type: .directory
                    )
                    node.children = [createNestedNode(depth: depth + 1, maxDepth: maxDepth)]
                    return node
                }
            }

            let root = createNestedNode(depth: 0, maxDepth: 100)
            XCTAssertEqual(root.type, .directory)
        }
    }
}

/// Performance tests for event persistence.

final class EventPersistencePerformanceTests: XCTestCase {

    /// Test rapid event creation
    func testRapidEventCreation() throws {
        let sessionId = UUID()
        let now = Date()

        measure {
            var events: [EventEnvelope] = []

            // Create 1000 events rapidly
            for i in 0..<1000 {
                let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "Token \(i)", timestamp: now))
                let envelope = EventEnvelope(sessionId: sessionId, sequence: i + 1, event: event)
                events.append(envelope)
            }

            XCTAssertEqual(events.count, 1000)
        }
    }

    /// Test event serialization performance
    func testEventSerialization() throws {
        let sessionId = UUID()
        let now = Date()
        let events: [EventEnvelope] = (0..<1000).map { i in
            let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "Token \(i)", timestamp: now))
            return EventEnvelope(sessionId: sessionId, sequence: i + 1, event: event)
        }

        measure {
            let encoder = JSONEncoder()
            for event in events {
                _ = try? encoder.encode(event)
            }
        }
    }
}

/// Performance tests for terminal output handling.

final class TerminalOutputPerformanceTests: XCTestCase {

    /// Test burst handling of terminal output
    func testTerminalOutputBurst() throws {
        measure {
            var lines: [String] = []

            // Simulate a burst of 10,000 lines of terminal output
            for i in 0..<10_000 {
                let line = "Line \(i): " + String(repeating: "x", count: 80)
                lines.append(line)
            }

            XCTAssertEqual(lines.count, 10_000)
        }
    }

    /// Test ANSI parsing performance
    func testAnsiParsingPerformance() throws {
        // Create strings with ANSI codes
        let ansiStrings: [String] = (0..<1000).map { i in
            "\u{001B}[31mRed text \(i)\u{001B}[0m \u{001B}[32mGreen text\u{001B}[0m"
        }

        measure {
            for string in ansiStrings {
                // Simple ANSI stripping (regex-like pattern matching)
                let stripped = string.replacingOccurrences(
                    of: "\u{001B}\\[[0-9;]*m",
                    with: "",
                    options: .regularExpression
                )
                XCTAssertFalse(stripped.contains("\u{001B}"))
            }
        }
    }

    /// Test large output buffer management
    func testLargeOutputBuffer() throws {
        measure {
            var buffer = ""

            // Accumulate 100KB of text
            for i in 0..<1000 {
                buffer += "Line \(i): " + String(repeating: "a", count: 100) + "\n"
            }

            // Verify buffer size
            XCTAssertGreaterThan(buffer.count, 100_000)

            // Test truncation performance
            if buffer.count > 50_000 {
                buffer = String(buffer.suffix(50_000))
            }
            XCTAssertEqual(buffer.count, 50_000)
        }
    }
}

/// Performance tests for binary file detection.

final class BinaryFileDetectionPerformanceTests: XCTestCase {

    /// Test binary detection by extension
    func testExtensionCheckPerformance() throws {
        let extensions = ["png", "jpg", "swift", "md", "json", "zip", "exe", "txt", "pdf", "docx"]

        measure {
            for _ in 0..<10_000 {
                for ext in extensions {
                    _ = BinaryFileDetector.isBinaryExtension(ext)
                }
            }
        }
    }

    /// Test binary content detection
    func testContentCheckPerformance() throws {
        // Create a mix of binary and text data
        let textData = Data(String(repeating: "Hello World\n", count: 1000).utf8)
        var binaryData = Data(count: 8192)
        binaryData[100] = 0 // Add null byte

        measure {
            for _ in 0..<1000 {
                _ = BinaryFileDetector.isBinaryContent(textData)
                _ = BinaryFileDetector.isBinaryContent(binaryData)
            }
        }
    }
}

// MARK: - File Tree Node (for tests)

/// Represents a node in the file tree (for testing purposes)
struct FileTreeNode {
    let name: String
    let path: String
    let type: FileTreeNodeType
    var children: [FileTreeNode] = []
}

enum FileTreeNodeType {
    case file
    case directory
}

