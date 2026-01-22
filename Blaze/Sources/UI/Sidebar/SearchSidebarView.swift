import SwiftUI
import Combine

// MARK: - Search Sidebar View

/// Tab 6: Search sidebar for searching across chat, files, and tool outputs.
///
/// **Phase 2 Spec:**
/// - Search input field
/// - Scope toggles: Chat, Files, Tools, All
/// - Results list with context snippets
/// - Highlight matches
/// - Recent searches
struct SearchSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var searchScope: SearchScope = .all
    @State private var results: [SearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var recentSearches: [String] = []
    @State private var showRecentSearches: Bool = false

    @FocusState private var isSearchFocused: Bool

    // Debounce publisher
    @State private var searchDebouncer = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    private var session: Session? {
        guard let id = sessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            searchInputView

            Divider()

            // Scope picker
            scopePicker

            Divider()

            // Results or empty state
            if isSearching {
                loadingView
            } else if searchText.isEmpty {
                if showRecentSearches && !recentSearches.isEmpty {
                    recentSearchesView
                } else {
                    emptyState
                }
            } else if results.isEmpty {
                noResultsView
            } else {
                resultsList
            }
        }
        .onAppear {
            setupDebouncer()
        }
    }

    // MARK: - Search Input

    private var searchInputView: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Color.ds.tertiary)

            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { _, newValue in
                    searchDebouncer.send(newValue)
                    showRecentSearches = newValue.isEmpty
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    results = []
                    showRecentSearches = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.sm)
    }

    // MARK: - Scope Picker

    private var scopePicker: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(SearchScope.allCases) { scope in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        searchScope = scope
                    }
                    if !searchText.isEmpty {
                        performSearch()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: scope.icon)
                            .font(.system(size: 10))

                        Text(scope.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(searchScope == scope ? Color.ds.foreground : Color.ds.tertiary)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, 4)
                    .background(
                        searchScope == scope
                            ? Color.ds.accent.opacity(0.2)
                            : Color.ds.surface.opacity(0.3)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Searching...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("Search Session")
                .dsTextStyle(.subtitle)

            Text("Search across chat messages, files, and tool outputs")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.md)

            // Keyboard shortcut hint
            HStack(spacing: 4) {
                Text("⌘F")
                    .dsTextStyle(.monoSmall, color: .ds.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ds.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Text("to focus")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Results")
                .dsTextStyle(.subtitle)

            Text("No matches found for \"\(searchText)\"")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            if searchScope != .all {
                Button {
                    searchScope = .all
                    performSearch()
                } label: {
                    Text("Search all scopes")
                        .dsTextStyle(.caption, color: .ds.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recent Searches View

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Searches")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                Button("Clear") {
                    recentSearches.removeAll()
                }
                .dsTextStyle(.micro, color: .ds.tertiary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(recentSearches, id: \.self) { query in
                        HStack(spacing: DSSpacing.sm) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.ds.tertiary)

                            Text(query)
                                .dsTextStyle(.body)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xs)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            searchText = query
                            performSearch()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Results count
            HStack {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { result in
                        SearchResultRow(result: result, searchText: searchText) {
                            navigateToResult(result)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Logic

    private func setupDebouncer() {
        searchDebouncer
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { query in
                if !query.isEmpty {
                    performSearch()
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            results = []
            return
        }

        isSearching = true
        let query = searchText.lowercased()

        // Add to recent searches
        if !recentSearches.contains(searchText) {
            recentSearches.insert(searchText, at: 0)
            if recentSearches.count > 10 {
                recentSearches = Array(recentSearches.prefix(10))
            }
        }

        // Search in events
        var searchResults: [SearchResultItem] = []

        for envelope in events {
            switch envelope.event {
            // Search in assistant messages
            case .assistantDelta(let delta):
                if shouldSearch(.chat) && delta.text.lowercased().contains(query) {
                    searchResults.append(SearchResultItem(
                        type: .message,
                        title: "Assistant Message",
                        snippet: extractSnippet(from: delta.text, matching: query),
                        timestamp: envelope.timestamp,
                        eventId: envelope.id
                    ))
                }

            case .assistantComplete(let complete):
                if shouldSearch(.chat) && complete.fullText.lowercased().contains(query) {
                    // Only add if not already found via delta
                    if !searchResults.contains(where: { $0.eventId == envelope.id }) {
                        searchResults.append(SearchResultItem(
                            type: .message,
                            title: "Assistant Message",
                            snippet: extractSnippet(from: complete.fullText, matching: query),
                            timestamp: envelope.timestamp,
                            eventId: envelope.id
                        ))
                    }
                }

            // Search in tool calls
            case .toolCallStarted(let tool):
                if shouldSearch(.tools) {
                    if tool.toolName.lowercased().contains(query) || tool.input.lowercased().contains(query) {
                        searchResults.append(SearchResultItem(
                            type: .tool,
                            title: "Tool: \(tool.toolName)",
                            snippet: extractSnippet(from: tool.input, matching: query),
                            timestamp: envelope.timestamp,
                            eventId: envelope.id
                        ))
                    }
                }

            case .toolCallComplete(let tool):
                if shouldSearch(.tools), let output = tool.output, output.lowercased().contains(query) {
                    searchResults.append(SearchResultItem(
                        type: .tool,
                        title: "Tool Output: \(tool.toolName)",
                        snippet: extractSnippet(from: output, matching: query),
                        timestamp: envelope.timestamp,
                        eventId: envelope.id
                    ))
                }

            // Search in file events
            case .fileDiffProduced(let diff):
                if shouldSearch(.files) && diff.filePath.lowercased().contains(query) {
                    searchResults.append(SearchResultItem(
                        type: .file,
                        title: (diff.filePath as NSString).lastPathComponent,
                        snippet: diff.filePath,
                        filePath: diff.filePath,
                        timestamp: envelope.timestamp,
                        eventId: envelope.id
                    ))
                }

            case .fileWritten(let file):
                if shouldSearch(.files) && file.filePath.lowercased().contains(query) {
                    searchResults.append(SearchResultItem(
                        type: .file,
                        title: (file.filePath as NSString).lastPathComponent,
                        snippet: file.filePath,
                        filePath: file.filePath,
                        timestamp: envelope.timestamp,
                        eventId: envelope.id
                    ))
                }

            case .fileRead(let file):
                if shouldSearch(.files) && file.filePath.lowercased().contains(query) {
                    searchResults.append(SearchResultItem(
                        type: .file,
                        title: (file.filePath as NSString).lastPathComponent,
                        snippet: file.filePath,
                        filePath: file.filePath,
                        timestamp: envelope.timestamp,
                        eventId: envelope.id
                    ))
                }

            default:
                break
            }
        }

        // Deduplicate and sort by timestamp
        let uniqueResults = Dictionary(grouping: searchResults) { $0.id }
            .values
            .compactMap { $0.first }
            .sorted { $0.timestamp > $1.timestamp }

        results = uniqueResults
        isSearching = false
    }

    private func shouldSearch(_ scope: SearchScope) -> Bool {
        searchScope == .all || searchScope == scope
    }

    private func extractSnippet(from text: String, matching query: String) -> String {
        let lowercased = text.lowercased()
        guard let range = lowercased.range(of: query) else {
            return String(text.prefix(100))
        }

        let matchStart = text.distance(from: text.startIndex, to: range.lowerBound)
        let snippetStart = max(0, matchStart - 30)
        let snippetEnd = min(text.count, matchStart + query.count + 70)

        let startIndex = text.index(text.startIndex, offsetBy: snippetStart)
        let endIndex = text.index(text.startIndex, offsetBy: snippetEnd)

        var snippet = String(text[startIndex..<endIndex])
        if snippetStart > 0 { snippet = "..." + snippet }
        if snippetEnd < text.count { snippet = snippet + "..." }

        return snippet
    }

    private func navigateToResult(_ result: SearchResultItem) {
        switch result.type {
        case .message, .tool:
            // Scroll to event in chat
            if let eventId = result.eventId {
                appState.scrollToEvent(eventId)
            }

        case .file:
            // Open file in file viewer
            if let filePath = result.filePath {
                appState.openFile(filePath, asPreview: true)
            }
        }
    }
}

// MARK: - Supporting Types

enum SearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case chat = "Chat"
    case files = "Files"
    case tools = "Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.3.stack.3d"
        case .chat: return "bubble.left"
        case .files: return "doc.text"
        case .tools: return "wrench"
        }
    }
}

struct SearchResultItem: Identifiable {
    let id = UUID()
    let type: SearchResultType
    let title: String
    let snippet: String
    var filePath: String? = nil
    let timestamp: Date
    var eventId: UUID? = nil
}

enum SearchResultType {
    case message
    case file
    case tool

    var icon: String {
        switch self {
        case .message: return "bubble.left"
        case .file: return "doc.text"
        case .tool: return "wrench"
        }
    }

    var color: Color {
        switch self {
        case .message: return .ds.accent
        case .file: return .ds.positive
        case .tool: return .ds.warning
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResultItem
    let searchText: String
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title with type icon
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: result.type.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(result.type.color)

                Text(result.title)
                    .dsTextStyle(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Text(formatRelativeTime(result.timestamp))
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }

            // Snippet with highlighted match
            Text(attributedSnippet)
                .dsTextStyle(.micro, color: .ds.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.sm)
        .background(isHovered ? Color.ds.surface.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var attributedSnippet: AttributedString {
        var attributedString = AttributedString(result.snippet)

        // Find and highlight matches
        let lowercasedSnippet = result.snippet.lowercased()
        let lowercasedQuery = searchText.lowercased()

        var searchStartIndex = lowercasedSnippet.startIndex
        while let range = lowercasedSnippet.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedSnippet.endIndex) {
            // Convert string range to AttributedString range
            let start = lowercasedSnippet.distance(from: lowercasedSnippet.startIndex, to: range.lowerBound)
            let end = lowercasedSnippet.distance(from: lowercasedSnippet.startIndex, to: range.upperBound)

            let attrStart = attributedString.index(attributedString.startIndex, offsetByCharacters: start)
            let attrEnd = attributedString.index(attributedString.startIndex, offsetByCharacters: end)
            attributedString[attrStart..<attrEnd].backgroundColor = Color.ds.accent.opacity(0.3)
            attributedString[attrStart..<attrEnd].foregroundColor = Color.ds.foreground

            searchStartIndex = range.upperBound
        }

        return attributedString
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview("Search Sidebar") {
    SearchSidebarView(
        sessionId: UUID(),
        events: []
    )
    .environmentObject(AppState())
    .frame(width: 280, height: 500)
    .background(Color.ds.bg0)
}
