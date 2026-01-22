import SwiftUI

// MARK: - Gallery Mock Data

/// Mock data provider for UI Gallery previews.
/// All data is static and works offline.
public enum GalleryMockData {

    // MARK: - Sessions

    public static let sessions: [(id: String, name: String, date: String, messageCount: Int, isActive: Bool)] = [
        ("session1", "Blaze Development", "Today, 3:45 PM", 42, true),
        ("session2", "API Integration", "Yesterday", 15, false),
        ("session3", "Bug Fix #123", "2 days ago", 8, false),
        ("session4", "Documentation", "Last week", 23, false),
        ("session5", "Refactoring", "2 weeks ago", 67, false),
    ]

    // MARK: - Messages

    public static let messages: [(id: String, isUser: Bool, text: String)] = [
        ("msg1", true, "Can you help me refactor this function to use async/await?"),
        ("msg2", false, "I'd be happy to help you refactor. Could you share the function you'd like to improve? I'll analyze the current implementation and suggest an async/await approach."),
        ("msg3", true, "Here's the code:\n\nfunc fetchData(completion: @escaping (Result<Data, Error>) -> Void) {\n    URLSession.shared.dataTask(with: url) { data, _, error in\n        // ...\n    }.resume()\n}"),
        ("msg4", false, "I'll refactor this to use async/await. Here's the updated version:\n\n```swift\nfunc fetchData() async throws -> Data {\n    let (data, _) = try await URLSession.shared.data(from: url)\n    return data\n}\n```\n\nThis is cleaner and easier to use with Swift's structured concurrency."),
    ]

    // MARK: - Tool Calls

    public static let toolCalls: [(id: String, name: String, status: String, duration: TimeInterval)] = [
        ("tool1", "Read", "Completed", 0.5),
        ("tool2", "Edit", "Completed", 1.2),
        ("tool3", "Bash", "Running", 0),
        ("tool4", "Write", "Pending", 0),
    ]

    // MARK: - Diff Lines

    public struct DiffLine {
        let lineNumber: Int
        let type: DiffLineType
        let text: String

        public enum DiffLineType {
            case context, addition, removal
        }
    }

    public static let diffLines: [DiffLine] = [
        DiffLine(lineNumber: 1, type: .context, text: "import Foundation"),
        DiffLine(lineNumber: 2, type: .context, text: ""),
        DiffLine(lineNumber: 3, type: .removal, text: "func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {"),
        DiffLine(lineNumber: 3, type: .addition, text: "func fetchData() async throws -> Data {"),
        DiffLine(lineNumber: 4, type: .removal, text: "    URLSession.shared.dataTask(with: url) { data, _, error in"),
        DiffLine(lineNumber: 4, type: .addition, text: "    let (data, _) = try await URLSession.shared.data(from: url)"),
        DiffLine(lineNumber: 5, type: .removal, text: "        if let error = error {"),
        DiffLine(lineNumber: 5, type: .addition, text: "    return data"),
        DiffLine(lineNumber: 6, type: .removal, text: "            completion(.failure(error))"),
        DiffLine(lineNumber: 6, type: .context, text: "}"),
    ]

    // MARK: - Projects

    public static let projects: [(id: String, name: String, path: String, fileCount: Int)] = [
        ("proj1", "Blaze", "/Users/dev/blaze", 45),
        ("proj2", "MyApp", "/Users/dev/myapp", 128),
        ("proj3", "Library", "/Users/dev/library", 32),
    ]

    // MARK: - Settings

    public struct SettingsData {
        var projectPath: String = "/Users/dev/project"
        var trustMode: Int = 0  // 0: Review, 1: Trusted, 2: Sandbox
        var darkMode: Bool = false
        var showToolCards: Bool = true
        var autoScroll: Bool = true
    }

    public static var settings = SettingsData()

    // MARK: - Long Text (for edge cases)

    public static let longText = String(repeating: "This is a long piece of text that tests how the UI handles extensive content without breaking the layout. ", count: 20)

    public static let codeBlock = """
    import SwiftUI

    struct ContentView: View {
        @State private var count = 0

        var body: some View {
            VStack {
                Text("Count: \\(count)")
                    .font(.largeTitle)

                Button("Increment") {
                    count += 1
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    """

    // MARK: - Error Messages

    public static let errorMessages: [(severity: String, message: String)] = [
        ("info", "Your session will expire in 5 minutes"),
        ("warning", "API rate limit approaching (80%)"),
        ("error", "Failed to connect to server"),
        ("critical", "Authentication token expired"),
    ]
}

// MARK: - Preview State Extensions

extension PreviewState {
    /// Get appropriate mock data for this state
    func mockMessages() -> [(id: String, isUser: Bool, text: String)] {
        switch self {
        case .loading:
            return []
        case .empty:
            return []
        case .error:
            return []
        case .success:
            return Array(GalleryMockData.messages.prefix(4))
        case .edge:
            return GalleryMockData.messages + [
                ("edge1", false, GalleryMockData.longText)
            ]
        }
    }

    func mockSessions() -> [(id: String, name: String, date: String, messageCount: Int, isActive: Bool)] {
        switch self {
        case .loading, .empty:
            return []
        case .error:
            return []
        case .success:
            return Array(GalleryMockData.sessions.prefix(3))
        case .edge:
            return GalleryMockData.sessions + [
                ("edge", String(repeating: "Very Long Session Name ", count: 5), "Just now", 999, true)
            ]
        }
    }
}
