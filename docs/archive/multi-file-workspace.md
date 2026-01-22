# Multi-File Workspace with Live Preview Spec

> Cogit0 Blaze - Your Code, Beautifully Orchestrated

## Overview

When Claude Code works on complex tasks, it often touches many files simultaneously. The Multi-File Workspace provides a **tabbed editor view** with **real-time file monitoring**, **live preview**, and **intelligent file grouping**—giving users visibility into everything Claude is doing without switching to external tools.

---

## 1. Core Features

### 1.1 Feature Matrix

| Feature | Description | Priority |
|---------|-------------|----------|
| **Tabbed Files** | Open multiple files in tabs | P0 |
| **Live Preview** | Real-time HTML/React/SwiftUI preview | P0 |
| **File Watcher** | Auto-reload on external changes | P0 |
| **Split View** | View 2+ files side-by-side | P1 |
| **Smart Groups** | Auto-group related files | P1 |
| **Quick Open** | Fuzzy file search (⌘P) | P0 |
| **Breadcrumb Nav** | Navigate file/symbol hierarchy | P2 |
| **Minimap** | Code overview sidebar | P2 |

### 1.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    WORKSPACE ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         Tab Bar                                   │   │
│  │  [index.tsx ×] [styles.css ×] [api.ts ×] [preview.html ●]       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────┐ ┌─────────────────────────────────┐   │
│  │                             │ │                                 │   │
│  │         Editor              │ │         Preview                 │   │
│  │                             │ │                                 │   │
│  │  Syntax highlighted         │ │  Live rendered output           │   │
│  │  Line numbers               │ │  Auto-refresh                   │   │
│  │  Diff markers               │ │  Device frames                  │   │
│  │  Breakpoint indicators      │ │  Console output                 │   │
│  │                             │ │                                 │   │
│  └─────────────────────────────┘ └─────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                       Status Bar                                  │   │
│  │  Ln 42, Col 15 │ UTF-8 │ TypeScript React │ 2 problems │ Sync ✓ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Model

### 2.1 Core Types

```swift
// WorkspaceModel.swift

/// A file opened in the workspace
struct WorkspaceFile: Identifiable, Hashable {
    let id: UUID
    let path: URL
    var content: String
    var isDirty: Bool
    var lastModified: Date
    var language: Language
    var highlights: [TextHighlight]    // Diff markers, search results

    enum Language: String, CaseIterable {
        case swift, typescript, javascript, python, rust, go
        case html, css, json, yaml, markdown, plaintext

        var icon: String { /* ... */ }
        var highlighter: SyntaxHighlighter { /* ... */ }
    }
}

/// Workspace state
@Observable
final class Workspace {
    var files: [WorkspaceFile] = []
    var activeFileId: UUID?
    var splitMode: SplitMode = .single
    var previewMode: PreviewMode = .hidden

    enum SplitMode {
        case single
        case vertical(ratio: CGFloat)
        case horizontal(ratio: CGFloat)
        case grid(rows: Int, cols: Int)
    }

    enum PreviewMode {
        case hidden
        case inline          // Below editor
        case sideBySide      // Right of editor
        case floating        // Separate window
    }

    var activeFile: WorkspaceFile? {
        files.first { $0.id == activeFileId }
    }

    func openFile(at path: URL) async throws {
        // Check if already open
        if let existing = files.first(where: { $0.path == path }) {
            activeFileId = existing.id
            return
        }

        // Load file
        let content = try String(contentsOf: path, encoding: .utf8)
        let file = WorkspaceFile(
            id: UUID(),
            path: path,
            content: content,
            isDirty: false,
            lastModified: try path.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date(),
            language: detectLanguage(path),
            highlights: []
        )

        files.append(file)
        activeFileId = file.id

        // Start watching
        FileWatcher.shared.watch(path)
    }

    func closeFile(_ id: UUID) {
        files.removeAll { $0.id == id }
        if activeFileId == id {
            activeFileId = files.first?.id
        }
    }
}
```

### 2.2 File Watcher

```swift
// FileWatcher.swift

actor FileWatcher {
    static let shared = FileWatcher()

    private var sources: [URL: DispatchSourceFileSystemObject] = [:]

    func watch(_ path: URL) {
        guard sources[path] == nil else { return }

        let descriptor = open(path.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            Task {
                await self?.handleChange(at: path)
            }
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
        sources[path] = source
    }

    private func handleChange(at path: URL) async {
        // Check what happened
        let exists = FileManager.default.fileExists(atPath: path.path)

        if exists {
            // File was modified - reload
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .fileDidChange,
                    object: nil,
                    userInfo: ["path": path]
                )
            }
        } else {
            // File was deleted
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .fileWasDeleted,
                    object: nil,
                    userInfo: ["path": path]
                )
            }
        }
    }

    func unwatch(_ path: URL) {
        sources[path]?.cancel()
        sources.removeValue(forKey: path)
    }
}
```

---

## 3. UI Components

### 3.1 Workspace View

```swift
// WorkspaceView.swift

struct WorkspaceView: View {
    @Bindable var workspace: Workspace
    @State private var showQuickOpen = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBar(
                files: workspace.files,
                activeId: $workspace.activeFileId,
                onClose: { workspace.closeFile($0) }
            )

            Divider()

            // Editor + Preview
            HSplitView {
                // Editor
                if let file = workspace.activeFile {
                    CodeEditor(file: file)
                } else {
                    EmptyWorkspaceView()
                }

                // Preview (if enabled)
                if workspace.previewMode != .hidden,
                   let file = workspace.activeFile,
                   file.language.supportsPreview {
                    LivePreview(file: file)
                }
            }

            // Status bar
            StatusBar(file: workspace.activeFile)
        }
        .onKeyPress("p", modifiers: .command) {
            showQuickOpen = true
            return .handled
        }
        .sheet(isPresented: $showQuickOpen) {
            QuickOpenSheet(onSelect: { path in
                Task { try await workspace.openFile(at: path) }
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileDidChange)) { notification in
            guard let path = notification.userInfo?["path"] as? URL else { return }
            handleExternalChange(at: path)
        }
    }
}
```

### 3.2 Tab Bar

```swift
// TabBar.swift

struct TabBar: View {
    let files: [WorkspaceFile]
    @Binding var activeId: UUID?
    let onClose: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(files) { file in
                    TabItem(
                        file: file,
                        isActive: file.id == activeId,
                        onSelect: { activeId = file.id },
                        onClose: { onClose(file.id) }
                    )
                }
            }
        }
        .frame(height: 36)
        .background(DarkBackground.surface)
    }
}

struct TabItem: View {
    let file: WorkspaceFile
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // File icon
            Image(systemName: file.language.icon)
                .font(.system(size: IconSize.sm))
                .foregroundStyle(DarkText.tertiary)

            // File name
            Text(file.path.lastPathComponent)
                .font(Typography.bodySmall)
                .foregroundStyle(isActive ? DarkText.primary : DarkText.secondary)

            // Dirty indicator
            if file.isDirty {
                Circle()
                    .fill(DarkAccent.warning)
                    .frame(width: 6, height: 6)
            }

            // Close button (on hover or active)
            if isHovering || isActive {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DarkText.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isActive ? DarkBackground.raised : .clear)
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(DarkAccent.primary)
                    .frame(height: 2)
            }
        }
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }
}
```

### 3.3 Code Editor

```swift
// CodeEditor.swift

struct CodeEditor: View {
    let file: WorkspaceFile
    @State private var cursorPosition: TextPosition = .init(line: 1, column: 1)
    @State private var selection: Range<String.Index>?

    var body: some View {
        HStack(spacing: 0) {
            // Gutter (line numbers, fold markers, diff indicators)
            GutterView(
                lineCount: file.content.lineCount,
                highlights: file.highlights,
                currentLine: cursorPosition.line
            )

            // Main editor
            TextEditor(text: .constant(file.content))
                .font(Typography.code)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .trailing) {
                    // Minimap
                    MinimapView(content: file.content)
                        .frame(width: 80)
                }
        }
        .background(DarkBackground.canvas)
    }
}

struct GutterView: View {
    let lineCount: Int
    let highlights: [TextHighlight]
    let currentLine: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lineCount, id: \.self) { line in
                HStack(spacing: Spacing.xxs) {
                    // Diff indicator
                    if let highlight = highlights.first(where: { $0.line == line }) {
                        Rectangle()
                            .fill(highlight.color)
                            .frame(width: 3)
                    }

                    // Line number
                    Text("\(line)")
                        .font(Typography.codeSmall)
                        .foregroundStyle(line == currentLine ? DarkText.secondary : DarkText.disabled)
                }
                .frame(height: lineHeight)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .background(DarkBackground.surface)
    }
}
```

### 3.4 Live Preview

```swift
// LivePreview.swift

struct LivePreview: View {
    let file: WorkspaceFile
    @State private var deviceFrame: DeviceFrame = .none
    @State private var refreshKey = UUID()

    enum DeviceFrame: String, CaseIterable {
        case none = "None"
        case iphone = "iPhone 15 Pro"
        case ipad = "iPad Pro"
        case macbook = "MacBook Pro"

        var size: CGSize? {
            switch self {
            case .none: return nil
            case .iphone: return CGSize(width: 393, height: 852)
            case .ipad: return CGSize(width: 1024, height: 1366)
            case .macbook: return CGSize(width: 1440, height: 900)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Preview toolbar
            HStack {
                Text("Preview")
                    .font(Typography.label)
                    .foregroundStyle(DarkText.tertiary)

                Spacer()

                // Device frame picker
                Picker("Device", selection: $deviceFrame) {
                    ForEach(DeviceFrame.allCases, id: \.self) { frame in
                        Text(frame.rawValue).tag(frame)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                // Refresh button
                Button {
                    refreshKey = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(Spacing.sm)
            .background(DarkBackground.raised)

            Divider()

            // Preview content
            ScrollView([.horizontal, .vertical]) {
                previewContent
                    .frame(
                        width: deviceFrame.size?.width,
                        height: deviceFrame.size?.height
                    )
                    .overlay(
                        deviceFrame != .none
                            ? DeviceFrameOverlay(device: deviceFrame)
                            : nil
                    )
            }
            .id(refreshKey)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch file.language {
        case .html:
            WebView(html: file.content)
        case .markdown:
            MarkdownView(content: file.content)
        case .swift:
            SwiftUIPreview(source: file.content)
        default:
            Text("Preview not available for \(file.language.rawValue)")
                .foregroundStyle(DarkText.tertiary)
        }
    }
}

struct WebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
```

---

## 4. Quick Open

### 4.1 Fuzzy File Search

```swift
// QuickOpenSheet.swift

struct QuickOpenSheet: View {
    let onSelect: (URL) -> Void

    @State private var query = ""
    @State private var results: [FileResult] = []
    @State private var selectedIndex = 0
    @Environment(\.dismiss) var dismiss

    struct FileResult: Identifiable {
        let id = UUID()
        let path: URL
        let score: Double
        let matchRanges: [Range<String.Index>]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DarkText.tertiary)

                TextField("Search files...", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.body)
                    .onSubmit {
                        selectCurrent()
                    }
            }
            .padding(Spacing.md)
            .background(DarkBackground.elevated)

            Divider()

            // Results
            if results.isEmpty && !query.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(DarkText.tertiary)
                    Text("No files found")
                        .foregroundStyle(DarkText.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            FileResultRow(
                                result: result,
                                isSelected: index == selectedIndex
                            )
                            .onTapGesture {
                                select(result)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(DarkBackground.raised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(DarkShadow.xl)
        .onChange(of: query) { _, newValue in
            search(query: newValue)
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(results.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .task {
            await indexProjectFiles()
        }
    }

    private func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }

        // Fuzzy match against indexed files
        results = ProjectIndex.shared.fuzzySearch(query: query)
            .prefix(20)
            .map { FileResult(path: $0.path, score: $0.score, matchRanges: $0.ranges) }
    }

    private func select(_ result: FileResult) {
        onSelect(result.path)
        dismiss()
    }

    private func selectCurrent() {
        guard selectedIndex < results.count else { return }
        select(results[selectedIndex])
    }
}
```

---

## 5. Smart File Groups

### 5.1 Auto-Grouping Logic

```swift
// FileGrouper.swift

enum FileGroupStrategy {
    case byDirectory
    case byType
    case byRelationship    // Component + styles + tests
    case byRecency
    case byClaudeActivity  // Files Claude touched together

    func group(_ files: [WorkspaceFile]) -> [FileGroup] {
        switch self {
        case .byRelationship:
            return groupByRelationship(files)
        case .byClaudeActivity:
            return groupByClaudeActivity(files)
        default:
            return groupSimple(files)
        }
    }

    private func groupByRelationship(_ files: [WorkspaceFile]) -> [FileGroup] {
        var groups: [FileGroup] = []
        var ungrouped = files

        // Find component groups (e.g., Component.tsx + Component.css + Component.test.tsx)
        for file in files where file.path.pathExtension == "tsx" {
            let baseName = file.path.deletingPathExtension().lastPathComponent
            let related = files.filter { other in
                let otherBase = other.path.deletingPathExtension().lastPathComponent
                return otherBase.hasPrefix(baseName) || otherBase == baseName
            }

            if related.count > 1 {
                groups.append(FileGroup(
                    name: baseName,
                    icon: "square.stack.3d.up",
                    files: related
                ))
                ungrouped.removeAll { related.contains($0) }
            }
        }

        // Add ungrouped files
        if !ungrouped.isEmpty {
            groups.append(FileGroup(
                name: "Other",
                icon: "folder",
                files: ungrouped
            ))
        }

        return groups
    }
}

struct FileGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let files: [WorkspaceFile]
}
```

---

## 6. Integration with Chat

### 6.1 Opening Files from Messages

```swift
// FileLink.swift

struct FileLink: View {
    let path: String
    @Environment(Workspace.self) var workspace

    var body: some View {
        Button {
            Task {
                try await workspace.openFile(at: URL(fileURLWithPath: path))
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "doc.text")
                    .font(.system(size: IconSize.xs))
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(Typography.code)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxxs)
            .background(DarkBackground.raised)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
        }
        .buttonStyle(.plain)
    }
}
```

### 6.2 Syncing with Tool Events

```swift
// WorkspaceSync.swift

actor WorkspaceSync {
    func handleToolEvent(_ event: NormalizedEvent) async {
        switch event {
        case .toolCallStarted(let tool) where tool.name == "Read":
            let path = tool.input["file_path"] as! String
            await MainActor.run {
                // Highlight file in workspace if open
                Workspace.shared.highlightFile(at: URL(fileURLWithPath: path))
            }

        case .toolCallStarted(let tool) where tool.name == "Write" || tool.name == "Edit":
            let path = tool.input["file_path"] as! String
            await MainActor.run {
                // Open file if not already open
                Task {
                    try await Workspace.shared.openFile(at: URL(fileURLWithPath: path))
                }
            }

        default:
            break
        }
    }
}
```

---

## 7. Implementation Checklist

- [ ] WorkspaceFile data model
- [ ] Workspace observable
- [ ] Tab bar with drag-reorder
- [ ] Code editor with syntax highlighting
- [ ] Line numbers and gutter
- [ ] File watcher integration
- [ ] Quick Open (⌘P)
- [ ] Split view (horizontal/vertical)
- [ ] Live preview (HTML/Markdown)
- [ ] Status bar
- [ ] Smart file grouping
- [ ] Minimap
- [ ] Breadcrumb navigation
- [ ] External change detection
- [ ] Dirty file indicators
- [ ] Keyboard shortcuts
- [ ] Accessibility labels
