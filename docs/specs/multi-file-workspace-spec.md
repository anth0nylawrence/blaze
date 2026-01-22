# Multi-File Workspace with Live Preview Spec

> "With great workspace comes great productivity." — Uncle Ben, if he were a developer

## Overview

The Multi-File Workspace transforms Blaze from a chat-and-review tool into a full **visual development cockpit**. Users can open multiple files side-by-side, see live previews of their changes, and watch Claude's edits appear in real-time—all without leaving the app or switching to an IDE.

## Core Concepts

### The Problem with Current Workflows

Developers using AI coding assistants constantly context-switch:

1. **Chat Window → IDE**: To see the full file Claude is editing
2. **IDE → Terminal**: To run tests or preview changes
3. **Terminal → Browser**: To see the result
4. **Browser → Chat**: To ask for adjustments

Each switch costs 2-5 seconds and breaks flow state.

### The Workspace Solution

```
┌────────────────────────────────────────────────────────────────────────────┐
│  Blaze Workspace                                                     ⌘W   │
├────────────┬───────────────────────────────────────────┬───────────────────┤
│            │                                           │                   │
│  Sessions  │   ┌─────────────┐ ┌─────────────┐        │   Live Preview    │
│            │   │ App.swift   │ │ Theme.swift │        │                   │
│  ─ Today   │   └─────────────┴─┴─────────────┘        │   ┌───────────┐   │
│    • Fix   │                                          │   │           │   │
│    • Add   │   1  import SwiftUI                      │   │  [App     │   │
│    • Ref   │   2                                      │   │   Preview]│   │
│            │   3  struct ContentView: View {          │   │           │   │
│  ─ Yester  │   4      @State private var theme =     │   └───────────┘   │
│    • Bug   │   5          Theme.dark                  │                   │
│            │   6                                      │   Terminal        │
│            │   7      var body: some View {           │   ────────────    │
│            │   8          VStack {                    │   $ swift run     │
│            │   9  ┃           Text("Hello")           │   Building...     │
│            │  10  ┃               .foregroundColor(   │   ✓ Success       │
│            │  11  ┃                   theme.primary)  │                   │
├────────────┤  12          }                           │   Console         │
│            │  13      }                               │   ────────────    │
│  Chat      │  14  }                                   │   [2024-12-25]    │
│            │                                          │   App started     │
│  Claude is │                                          │   Theme loaded    │
│  editing   │  ──────────────────────────────────────  │                   │
│  Theme.sw  │                                          │                   │
│            │   1  struct Theme {                      │                   │
│  ░░░░░░░░░ │   2      let primary: Color              │                   │
│            │   3      let background: Color           │                   │
└────────────┴───────────────────────────────────────────┴───────────────────┘
```

## Data Model

### Workspace State

```swift
/// Represents the user's workspace layout and state
struct Workspace: Codable, Identifiable {
    let id: UUID
    var name: String
    var layout: WorkspaceLayout
    var openFiles: [OpenFile]
    var focusedFileId: UUID?
    var previewConfig: PreviewConfig
    var terminalSessions: [TerminalSession]
    var customPanels: [CustomPanel]
    var createdAt: Date
    var lastModifiedAt: Date
}

struct WorkspaceLayout: Codable {
    var mainSplit: SplitConfig       // Chat | Editor | Preview
    var editorSplit: EditorSplitConfig
    var sidebarState: SidebarState
}

struct SplitConfig: Codable {
    var orientation: SplitOrientation
    var ratios: [CGFloat]            // e.g., [0.2, 0.5, 0.3]
    var collapsed: [Bool]            // Which panes are collapsed
}

enum SplitOrientation: String, Codable {
    case horizontal
    case vertical
}

struct EditorSplitConfig: Codable {
    var mode: EditorMode
    var groups: [EditorGroup]        // For multi-column layouts
}

enum EditorMode: String, Codable {
    case single                      // One file at a time
    case tabs                        // Tabbed interface
    case split2Horizontal            // Two files side by side
    case split2Vertical              // Two files stacked
    case split3                      // Three files
    case split4Grid                  // 2x2 grid
    case custom                      // User-defined layout
}

struct EditorGroup: Codable, Identifiable {
    let id: UUID
    var openFiles: [UUID]           // File IDs in this group
    var focusedFileId: UUID?
    var scrollPosition: CGFloat?
}
```

### Open Files

```swift
struct OpenFile: Codable, Identifiable {
    let id: UUID
    let filePath: String
    var content: String
    var originalContent: String?     // For diff display
    var language: String
    var isDirty: Bool               // Has unsaved changes
    var isReadOnly: Bool
    var cursorPosition: CursorPosition
    var selections: [TextSelection]
    var scrollOffset: CGFloat
    var foldedRanges: [Range<Int>]  // Collapsed code sections
    var highlights: [Highlight]      // Search results, errors, etc.
    var diagnostics: [Diagnostic]    // Linter errors, warnings
    var liveEditing: LiveEditState?  // Claude is currently editing
}

struct CursorPosition: Codable {
    var line: Int
    var column: Int
}

struct TextSelection: Codable {
    var start: CursorPosition
    var end: CursorPosition
}

struct Highlight: Codable {
    let id: UUID
    let range: Range<Int>           // Character range
    let type: HighlightType
    let message: String?
}

enum HighlightType: String, Codable {
    case searchResult
    case aiEditing                  // Claude is editing here
    case aiAdded                    // Claude added this
    case aiDeleted                  // Claude removed this
    case error
    case warning
    case info
    case bookmark
}

struct LiveEditState: Codable {
    let startedAt: Date
    var currentLine: Int
    var insertedLines: Range<Int>?
    var deletedLines: Range<Int>?
    var phase: EditPhase
}

enum EditPhase: String, Codable {
    case reading                    // Claude is reading
    case thinking                   // Claude is planning
    case writing                    // Claude is typing
    case complete                   // Edit finished
}
```

### Preview Configuration

```swift
struct PreviewConfig: Codable {
    var mode: PreviewMode
    var refreshStrategy: RefreshStrategy
    var targetPath: String?         // File to preview
    var command: String?            // Custom preview command
    var port: Int?                   // Dev server port
    var autoRefresh: Bool
    var refreshDelay: TimeInterval  // Debounce delay
}

enum PreviewMode: String, Codable {
    case disabled
    case webView                    // HTML/CSS/JS preview
    case markdown                   // Rendered markdown
    case swiftUI                    // SwiftUI preview (via Xcode)
    case terminal                   // Command output
    case image                      // Image file preview
    case custom                     // User-defined preview
}

enum RefreshStrategy: String, Codable {
    case onSave                     // Refresh when file saved
    case onType                     // Refresh as you type (debounced)
    case manual                     // Only on explicit refresh
    case onClaudeComplete           // When Claude finishes editing
}
```

## Live Preview System

### Preview Manager

```swift
@MainActor
class PreviewManager: ObservableObject {
    @Published var previewContent: PreviewContent?
    @Published var isRefreshing = false
    @Published var previewError: PreviewError?

    private var devServer: DevServerProcess?
    private var refreshTask: Task<Void, Never>?
    private let debouncer = Debouncer(delay: 0.3)

    /// Start live preview for a file
    func startPreview(for file: OpenFile, config: PreviewConfig) async {
        switch config.mode {
        case .webView:
            await startWebPreview(file, config: config)
        case .markdown:
            await startMarkdownPreview(file)
        case .swiftUI:
            await startSwiftUIPreview(file)
        case .terminal:
            await startTerminalPreview(config)
        case .image:
            await startImagePreview(file)
        case .custom:
            await startCustomPreview(config)
        case .disabled:
            previewContent = nil
        }
    }

    /// Web preview with hot reload
    private func startWebPreview(_ file: OpenFile, config: PreviewConfig) async {
        // Check for existing dev server
        if let existing = devServer, existing.isRunning {
            await refreshWebPreview()
            return
        }

        // Detect framework and start appropriate dev server
        let framework = await detectWebFramework(file.filePath)

        switch framework {
        case .nextjs:
            devServer = try? await startDevServer(
                command: "npm run dev",
                port: config.port ?? 3000
            )
        case .vite:
            devServer = try? await startDevServer(
                command: "npm run dev",
                port: config.port ?? 5173
            )
        case .static:
            devServer = try? await startDevServer(
                command: "python -m http.server \(config.port ?? 8000)",
                port: config.port ?? 8000
            )
        case .unknown:
            // Just render the HTML directly
            previewContent = .html(file.content)
        }

        if let port = devServer?.port {
            previewContent = .webView(URL(string: "http://localhost:\(port)")!)
        }
    }

    /// Markdown preview with syntax highlighting
    private func startMarkdownPreview(_ file: OpenFile) async {
        let html = MarkdownRenderer.render(
            file.content,
            options: .init(
                syntaxHighlighting: true,
                mermaidDiagrams: true,
                mathSupport: true,
                theme: .github
            )
        )
        previewContent = .html(html)
    }

    /// SwiftUI preview via Xcode integration
    private func startSwiftUIPreview(_ file: OpenFile) async {
        // Check if Xcode is running
        guard await XcodeIntegration.isAvailable else {
            previewError = .xcodeNotRunning
            return
        }

        // Request preview update
        do {
            let previewURL = try await XcodeIntegration.requestPreview(
                filePath: file.filePath
            )
            previewContent = .image(previewURL)
        } catch {
            previewError = .xcodePreviewFailed(error)
        }
    }

    /// Handle file content changes
    func onFileChanged(_ file: OpenFile, config: PreviewConfig) {
        guard config.autoRefresh else { return }

        switch config.refreshStrategy {
        case .onType:
            debouncer.call { [weak self] in
                await self?.refreshPreview(for: file, config: config)
            }
        case .onSave:
            if !file.isDirty {
                Task { await refreshPreview(for: file, config: config) }
            }
        case .manual:
            break // User will trigger manually
        case .onClaudeComplete:
            break // Handled by edit events
        }
    }
}

enum PreviewContent {
    case html(String)
    case webView(URL)
    case markdown(AttributedString)
    case image(URL)
    case terminal(String)
    case error(String)
}
```

### Real-Time Edit Visualization

```swift
@MainActor
class LiveEditVisualizer: ObservableObject {
    @Published var activeEdits: [UUID: LiveEditState] = [:]
    @Published var editAnimations: [UUID: EditAnimation] = [:]

    /// Process incoming edit events from Claude
    func processEditEvent(_ event: NormalizedEvent) {
        switch event {
        case .fileEditStarted(let path):
            startEditVisualization(path: path)

        case .fileEditProgress(let path, let line, let type):
            updateEditProgress(path: path, line: line, type: type)

        case .fileEditCompleted(let path, let content):
            completeEditVisualization(path: path, newContent: content)

        default:
            break
        }
    }

    /// Show Claude's cursor moving through the file
    private func updateEditProgress(path: String, line: Int, type: EditType) {
        guard let fileId = getFileId(for: path) else { return }

        var state = activeEdits[fileId] ?? LiveEditState(
            startedAt: Date(),
            currentLine: line,
            phase: .writing
        )

        state.currentLine = line

        switch type {
        case .insert(let range):
            state.insertedLines = range
        case .delete(let range):
            state.deletedLines = range
        case .replace(_, let newRange):
            state.insertedLines = newRange
        }

        activeEdits[fileId] = state

        // Trigger animation
        withAnimation(.easeInOut(duration: 0.15)) {
            editAnimations[fileId] = EditAnimation(
                line: line,
                type: type,
                timestamp: Date()
            )
        }
    }

    /// Animate the cursor typing effect
    func cursorAnimation(for fileId: UUID) -> some View {
        guard let state = activeEdits[fileId] else {
            return EmptyView().eraseToAnyView()
        }

        return CursorView(line: state.currentLine)
            .transition(.opacity)
            .animation(
                .easeInOut(duration: 0.1).repeatForever(autoreverses: true),
                value: state.currentLine
            )
            .eraseToAnyView()
    }
}

struct EditAnimation: Identifiable {
    let id = UUID()
    let line: Int
    let type: EditType
    let timestamp: Date
}

enum EditType {
    case insert(Range<Int>)
    case delete(Range<Int>)
    case replace(old: Range<Int>, new: Range<Int>)
}
```

## Editor Component

### Code Editor View

```swift
struct CodeEditorView: View {
    @ObservedObject var file: OpenFileViewModel
    @ObservedObject var liveEdits: LiveEditVisualizer
    @State private var hoveredLine: Int?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (if in tabbed mode)
            EditorTabBar(file: file)

            // Main editor
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(file.lines.enumerated()), id: \.offset) { index, line in
                            EditorLineView(
                                lineNumber: index + 1,
                                content: line,
                                isHovered: hoveredLine == index,
                                isEditing: liveEdits.activeEdits[file.id]?.currentLine == index,
                                highlights: file.highlightsForLine(index),
                                diagnostics: file.diagnosticsForLine(index)
                            )
                            .id(index)
                            .onHover { isHovered in
                                hoveredLine = isHovered ? index : nil
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: liveEdits.activeEdits[file.id]?.currentLine) { _, newLine in
                    // Auto-scroll to follow Claude's edits
                    if let line = newLine {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(line, anchor: .center)
                        }
                    }
                }
            }

            // Status bar
            EditorStatusBar(file: file, liveEdits: liveEdits)
        }
        .focused($isFocused)
        .onKeyPress(phases: .down) { keyPress in
            handleKeyPress(keyPress)
        }
    }
}

struct EditorLineView: View {
    let lineNumber: Int
    let content: String
    let isHovered: Bool
    let isEditing: Bool
    let highlights: [Highlight]
    let diagnostics: [Diagnostic]

    var body: some View {
        HStack(spacing: 0) {
            // Gutter
            HStack(spacing: 4) {
                // Breakpoint/bookmark indicator
                if let bookmark = highlights.first(where: { $0.type == .bookmark }) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.blue)
                        .font(.caption2)
                }

                // Line number
                Text("\(lineNumber)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)

                // Diagnostic indicator
                if let diag = diagnostics.first {
                    Image(systemName: diag.severity.icon)
                        .foregroundColor(diag.severity.color)
                        .font(.caption2)
                }
            }
            .frame(width: 60)
            .padding(.horizontal, 4)
            .background(gutterBackground)

            // Code content with syntax highlighting
            SyntaxHighlightedText(content: content, language: file.language)
                .font(.system(.body, design: .monospaced))
                .background(lineBackground)
                .overlay(editingIndicator)
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private var lineBackground: some View {
        if isEditing {
            LinearGradient(
                colors: [.blue.opacity(0.2), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if isHovered {
            Color.primary.opacity(0.05)
        } else if hasErrorDiagnostic {
            Color.red.opacity(0.1)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var editingIndicator: some View {
        if isEditing {
            HStack {
                Spacer()
                BlinkingCursor()
            }
        }
    }
}

struct BlinkingCursor: View {
    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isVisible.toggle()
                }
            }
    }
}
```

### Split Editor Layout

```swift
struct SplitEditorView: View {
    @ObservedObject var workspace: WorkspaceViewModel
    @State private var splitRatios: [CGFloat] = [0.5, 0.5]

    var body: some View {
        GeometryReader { geometry in
            switch workspace.layout.editorSplit.mode {
            case .single:
                singleEditor

            case .tabs:
                tabbedEditor

            case .split2Horizontal:
                HSplitView {
                    editorPane(for: workspace.editorGroups[0])
                    editorPane(for: workspace.editorGroups[1])
                }

            case .split2Vertical:
                VSplitView {
                    editorPane(for: workspace.editorGroups[0])
                    editorPane(for: workspace.editorGroups[1])
                }

            case .split3:
                HSplitView {
                    editorPane(for: workspace.editorGroups[0])
                    VSplitView {
                        editorPane(for: workspace.editorGroups[1])
                        editorPane(for: workspace.editorGroups[2])
                    }
                }

            case .split4Grid:
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        editorPane(for: workspace.editorGroups[0])
                        editorPane(for: workspace.editorGroups[1])
                    }
                    HStack(spacing: 1) {
                        editorPane(for: workspace.editorGroups[2])
                        editorPane(for: workspace.editorGroups[3])
                    }
                }

            case .custom:
                CustomLayoutView(layout: workspace.customLayout)
            }
        }
    }

    @ViewBuilder
    private func editorPane(for group: EditorGroup) -> some View {
        VStack(spacing: 0) {
            // Tab bar for this group
            EditorGroupTabBar(group: group)

            // Current editor
            if let file = group.focusedFile {
                CodeEditorView(
                    file: file,
                    liveEdits: workspace.liveEdits
                )
            } else {
                EmptyEditorPane(
                    onOpenFile: { workspace.openFilePicker(for: group.id) }
                )
            }
        }
        .background(Color(.textBackgroundColor))
    }
}
```

## File Tree & Navigation

### File Explorer

```swift
struct FileExplorerView: View {
    @ObservedObject var workspace: WorkspaceViewModel
    @State private var searchQuery = ""
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))

            // File tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredFiles, id: \.path) { item in
                        FileTreeItem(
                            item: item,
                            isExpanded: expandedFolders.contains(item.path),
                            isSelected: workspace.focusedFile?.filePath == item.path,
                            depth: item.depth,
                            onToggle: { toggleFolder(item.path) },
                            onSelect: { selectFile(item) }
                        )
                    }
                }
            }

            // Quick actions
            HStack {
                Button(action: { workspace.createNewFile() }) {
                    Image(systemName: "doc.badge.plus")
                }
                Button(action: { workspace.createNewFolder() }) {
                    Image(systemName: "folder.badge.plus")
                }
                Spacer()
                Button(action: { workspace.refreshFileTree() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(8)
        }
    }
}

struct FileTreeItem: View {
    let item: FileTreeNode
    let isExpanded: Bool
    let isSelected: Bool
    let depth: Int
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Indentation
            ForEach(0..<depth, id: \.self) { _ in
                Color.clear.frame(width: 16)
            }

            // Folder toggle or file icon
            if item.isDirectory {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                    .onTapGesture(perform: onToggle)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundColor(.yellow)
            } else {
                Color.clear.frame(width: 12)
                FileIcon(language: item.language)
            }

            // Name
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Status indicators
            if item.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            if item.isBeingEdited {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

struct FileIcon: View {
    let language: String?

    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
    }

    var iconName: String {
        switch language {
        case "swift": return "swift"
        case "javascript", "typescript": return "js.square"
        case "python": return "chevron.left.forwardslash.chevron.right"
        case "markdown": return "doc.richtext"
        case "json": return "curlybraces"
        case "html": return "chevron.left.slash.chevron.right"
        case "css": return "paintpalette"
        default: return "doc"
        }
    }

    var iconColor: Color {
        switch language {
        case "swift": return .orange
        case "javascript": return .yellow
        case "typescript": return .blue
        case "python": return .green
        default: return .secondary
        }
    }
}
```

### Quick Open (Command Palette)

```swift
struct QuickOpenView: View {
    @ObservedObject var workspace: WorkspaceViewModel
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Open file...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // Results
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Recent files
                    if query.isEmpty {
                        SectionHeader(title: "Recent Files")
                        ForEach(Array(workspace.recentFiles.prefix(5).enumerated()), id: \.element.id) { index, file in
                            QuickOpenItem(
                                file: file,
                                isSelected: selectedIndex == index,
                                onSelect: { openFile(file) }
                            )
                        }
                    }

                    // Search results
                    if !query.isEmpty {
                        ForEach(Array(filteredFiles.enumerated()), id: \.element.path) { index, file in
                            QuickOpenItem(
                                file: file,
                                isSelected: selectedIndex == index,
                                query: query,
                                onSelect: { openFile(file) }
                            )
                        }

                        if filteredFiles.isEmpty {
                            EmptyResultsView(query: query)
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .onAppear { isFocused = true }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.return) { selectCurrent(); return .handled }
        .onKeyPress(.escape) { workspace.closeQuickOpen(); return .handled }
    }

    var filteredFiles: [FileInfo] {
        workspace.fuzzySearch(query: query, limit: 20)
    }
}

struct QuickOpenItem: View {
    let file: FileInfo
    let isSelected: Bool
    var query: String = ""
    let onSelect: () -> Void

    var body: some View {
        HStack {
            FileIcon(language: file.language)

            VStack(alignment: .leading, spacing: 2) {
                HighlightedText(text: file.name, query: query)
                    .font(.body)

                Text(file.relativePath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Keyboard shortcut hint (for first 9 items)
            if let index = file.displayIndex, index < 9 {
                Text("⌘\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
```

## Terminal Integration

### Embedded Terminal

```swift
struct TerminalPanelView: View {
    @ObservedObject var workspace: WorkspaceViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Terminal tabs
            HStack(spacing: 0) {
                ForEach(Array(workspace.terminalSessions.enumerated()), id: \.element.id) { index, session in
                    TerminalTab(
                        session: session,
                        isSelected: selectedTab == index,
                        onSelect: { selectedTab = index },
                        onClose: { workspace.closeTerminal(session.id) }
                    )
                }

                Button(action: { workspace.createTerminal() }) {
                    Image(systemName: "plus")
                        .padding(8)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .background(Color(.controlBackgroundColor))

            Divider()

            // Terminal content
            if let session = workspace.terminalSessions[safe: selectedTab] {
                TerminalView(session: session)
            } else {
                EmptyTerminalView(onCreate: { workspace.createTerminal() })
            }
        }
    }
}

struct TerminalView: View {
    @ObservedObject var session: TerminalSession
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(session.output) { line in
                            TerminalLine(line: line)
                                .id(line.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.output.count) { _, _ in
                    if let lastLine = session.output.last {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
            .background(Color.black)

            // Input
            HStack {
                Text(session.prompt)
                    .foregroundColor(.green)
                    .font(.system(.body, design: .monospaced))

                TextField("", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isFocused)
                    .onSubmit {
                        session.execute(inputText)
                        inputText = ""
                    }
            }
            .padding(8)
            .background(Color.black)
        }
    }
}

struct TerminalLine: View {
    let line: TerminalOutput

    var body: some View {
        Text(line.content)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(line.type.color)
            .textSelection(.enabled)
    }
}

extension TerminalOutput.OutputType {
    var color: Color {
        switch self {
        case .stdout: return .white
        case .stderr: return .red
        case .command: return .green
        case .info: return .cyan
        case .success: return .green
        case .error: return .red
        }
    }
}
```

## Keyboard Shortcuts

| Action | Shortcut | Description |
|--------|----------|-------------|
| Quick Open | ⌘ + P | Open file quick switcher |
| Command Palette | ⌘ + Shift + P | Open command palette |
| Toggle Preview | ⌘ + Shift + V | Show/hide preview panel |
| Toggle Terminal | ⌘ + ` | Show/hide terminal |
| Split Right | ⌘ + \ | Split editor horizontally |
| Split Down | ⌘ + Shift + \ | Split editor vertically |
| Close Editor | ⌘ + W | Close current file |
| Close All | ⌘ + Shift + W | Close all open files |
| Next Tab | ⌃ + Tab | Switch to next tab |
| Previous Tab | ⌃ + Shift + Tab | Switch to previous tab |
| Go to Line | ⌘ + G | Jump to line number |
| Find in File | ⌘ + F | Search in current file |
| Find in Project | ⌘ + Shift + F | Search across all files |
| Go to Symbol | ⌘ + Shift + O | Navigate to symbol |
| Toggle Sidebar | ⌘ + B | Show/hide file explorer |
| Save | ⌘ + S | Save current file |
| Save All | ⌘ + Opt + S | Save all open files |
| Refresh Preview | ⌘ + R | Manually refresh preview |
| Focus Editor 1-4 | ⌘ + 1/2/3/4 | Focus specific editor pane |
| Maximize Editor | ⌘ + Shift + Enter | Maximize/restore current editor |

## Fun Messages

### Loading States
```swift
let loadingMessages = [
    // Star Wars
    "Accessing the archives... (They're not incomplete, we promise)",
    "Downloading the high ground...",
    "Feeling the Force flow through these files...",

    // Star Trek
    "Engaging warp drive to file system...",
    "Scanning for life signs in your codebase...",
    "Resistance to loading is futile...",

    // Marvel
    "Assembling your workspace... Avengers style",
    "Snapping files into existence (no infinity stones harmed)",
    "With great files comes great responsibility...",

    // DC
    "I'm not the editor your code deserves, but the one it needs...",
    "Faster than a speeding file system!",
    "Truth, justice, and well-formatted code!",
]
```

### Empty States
```swift
let emptyWorkspaceMessages = [
    "This workspace is emptier than the space between stars... Open a file to begin your journey.",
    "\"In my experience, there's no such thing as empty workspace.\" — Obi-Wan, optimistically",
    "Workspace Status: Maximum Potential, Zero Clutter",
    "The canvas is blank. The code is waiting. You are ready.",
]
```

### Preview Errors
```swift
let previewErrorMessages = [
    "Preview failed faster than the Kessel Run. Check your code and try again.",
    "\"I've made a terrible mistake.\" — Preview Engine, probably",
    "Houston, we have a preview problem.",
    "Preview went to the Upside Down. Saving changes might bring it back.",
]
```

## Performance Optimization

### Virtualized Rendering

```swift
class VirtualizedEditorRenderer {

    /// Calculate visible line range based on scroll position
    func visibleRange(
        scrollOffset: CGFloat,
        viewportHeight: CGFloat,
        lineHeight: CGFloat,
        totalLines: Int
    ) -> Range<Int> {
        let bufferLines = 50 // Render extra lines for smooth scrolling

        let startLine = max(0, Int(scrollOffset / lineHeight) - bufferLines)
        let visibleLines = Int(viewportHeight / lineHeight)
        let endLine = min(totalLines, startLine + visibleLines + (bufferLines * 2))

        return startLine..<endLine
    }

    /// Syntax highlight only visible range
    func highlightVisible(
        content: String,
        range: Range<Int>,
        language: String
    ) -> [HighlightedLine] {
        let lines = content.components(separatedBy: .newlines)
        let visibleLines = Array(lines[range])

        return visibleLines.enumerated().map { index, line in
            HighlightedLine(
                lineNumber: range.lowerBound + index,
                tokens: SyntaxHighlighter.tokenize(line, language: language)
            )
        }
    }
}
```

### Incremental Parsing

```swift
class IncrementalParser {

    /// Parse only changed regions
    func parseIncremental(
        oldContent: String,
        newContent: String,
        changedRange: Range<Int>
    ) -> ParseResult {
        // Expand change range to include full syntactic units
        let expandedRange = expandToSyntacticBoundary(changedRange, in: newContent)

        // Re-parse only the affected region
        let changedText = String(newContent[expandedRange])
        let tokens = SyntaxHighlighter.tokenize(changedText, language: currentLanguage)

        // Merge with cached tokens
        return mergeTokens(
            cached: cachedTokens,
            new: tokens,
            at: expandedRange
        )
    }
}
```

## Accessibility

- Full keyboard navigation for all workspace features
- VoiceOver announces file changes: "File App.swift modified, 3 additions, 1 deletion"
- Screen reader compatible code editor with line-by-line navigation
- High contrast mode for better visibility
- Configurable font sizes for all panels
- Reduce motion option disables live edit animations
- Terminal output readable by assistive technologies

---

*"Any sufficiently advanced workspace is indistinguishable from an IDE." — Arthur C. Clarke, developer edition*
