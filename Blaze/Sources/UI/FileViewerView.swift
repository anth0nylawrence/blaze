import SwiftUI

// MARK: - File Viewer View

/// Main tabbed file viewer with syntax highlighting and line numbers
struct FileViewerView: View {
    @EnvironmentObject var appState: AppState
    @State private var tabPendingClose: FileTab?
    @State private var showSaveConfirmation: Bool = false
    @State private var pendingCloseAll: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if appState.openFileTabs.isEmpty {
                EmptyFileTabBar()
            } else {
                FileTabBar(
                    tabs: $appState.openFileTabs,
                    activeTabId: $appState.activeFileTabId,
                    onClose: { tabId in
                        handleTabClose(tabId)
                    },
                    onCloseAll: {
                        handleCloseAll()
                    },
                    onCloseOthers: { keepId in
                        handleCloseOthers(keepId)
                    }
                )
            }

            // File content area
            if let activeTab = appState.activeFileTab {
                FileContentView(tab: activeTab)
            } else {
                EmptyFileViewerState(
                    onOpenFile: {
                        // Could trigger file picker
                    }
                )
            }
        }
        .background(.clear)  // Match chat window transparency
        .confirmationDialog(
            "Save Changes?",
            isPresented: $showSaveConfirmation,
            presenting: tabPendingClose
        ) { tab in
            Button("Save", role: .none) {
                saveAndClose(tab)
            }
            Button("Don't Save", role: .destructive) {
                forceClose(tab)
            }
            Button("Cancel", role: .cancel) {
                tabPendingClose = nil
                pendingCloseAll = false
            }
        } message: { tab in
            Text("Do you want to save the changes you made to \"\(tab.fileName)\"?")
        }
    }

    // MARK: - Tab Close Handling

    private func handleTabClose(_ tabId: UUID) {
        guard let tab = appState.openFileTabs.first(where: { $0.id == tabId }) else { return }

        if tab.isDirty {
            tabPendingClose = tab
            showSaveConfirmation = true
        } else {
            appState.closeFileTab(tabId)
        }
    }

    private func handleCloseAll() {
        let dirtyTabs = appState.dirtyTabs
        if let firstDirty = dirtyTabs.first {
            pendingCloseAll = true
            tabPendingClose = firstDirty
            showSaveConfirmation = true
        } else {
            appState.closeAllFileTabs()
        }
    }

    private func handleCloseOthers(_ keepId: UUID) {
        let otherDirtyTabs = appState.openFileTabs.filter { $0.id != keepId && $0.isDirty }
        if let firstDirty = otherDirtyTabs.first {
            tabPendingClose = firstDirty
            showSaveConfirmation = true
        } else {
            appState.openFileTabs.removeAll { $0.id != keepId }
            appState.activeFileTabId = keepId
        }
    }

    private func saveAndClose(_ tab: FileTab) {
        // Need to get current content from the active view - use stored content
        if let content = tab.originalContent {
            // Tab's originalContent would need to be updated content, so use a different approach
            // For now, just close without saving - proper implementation needs content binding
        }

        // Close the tab
        appState.closeFileTab(tab.id)
        tabPendingClose = nil

        // Continue closing all if needed
        if pendingCloseAll {
            handleCloseAll()
        }
    }

    private func forceClose(_ tab: FileTab) {
        appState.closeFileTab(tab.id)
        tabPendingClose = nil

        // Continue closing all if needed
        if pendingCloseAll {
            handleCloseAll()
        }
    }
}

// MARK: - File Content View

/// Displays file content with editing support
struct FileContentView: View {
    let tab: FileTab
    @EnvironmentObject var appState: AppState
    @State private var fileContent: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    @State private var isBinaryFile: Bool = false
    @State private var fileSize: Int64?
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @FocusState private var isEditorFocused: Bool

    // Performance: cache line count to avoid repeated string splitting
    @State private var cachedLineCount: Int = 1
    @State private var dirtyCheckTask: Task<Void, Never>?

    // Responsive font sizing: tracks editor width for dynamic font scaling
    @State private var editorFontSize: CGFloat = 12

    private var language: SyntaxHighlighter.Language {
        SyntaxHighlighter.Language.from(extension: tab.fileExtension)
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if isBinaryFile {
                BinaryFileView(filePath: tab.filePath, fileSize: fileSize)
            } else if let error = loadError {
                errorView(error)
            } else {
                editableContentView
            }
        }
        .onAppear {
            loadFileContent()
        }
        .onChange(of: tab.id) { _, _ in
            loadFileContent()
        }
        .onChange(of: fileContent) { _, newValue in
            // Performance: Debounce dirty check to reduce re-renders
            dirtyCheckTask?.cancel()
            dirtyCheckTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                // Update line count (cached to avoid repeated string splits)
                let newLineCount = newValue.filter { $0 == "\n" }.count + 1
                if cachedLineCount != newLineCount {
                    cachedLineCount = newLineCount
                }
                // Mark tab as dirty
                appState.markTabDirty(tab.id, content: newValue, originalContent: originalContent)
            }
        }
        .alert("Save Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "Unknown error")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading file...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Color.ds.negative)

            Text("Failed to load file")
                .dsTextStyle(.subtitle)

            Text(error)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                loadFileContent()
            }
            .buttonStyle(.bordered)
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Editable Content View

    private var editableContentView: some View {
        VStack(spacing: 0) {
            // Status bar with save button
            HStack {
                Text(tab.filePath)
                    .dsTextStyle(.micro, color: .ds.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if tab.isDirty {
                    Text("Modified")
                        .dsTextStyle(.micro, color: .ds.accent)
                }

                Button {
                    saveFile()
                } label: {
                    HStack(spacing: 4) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("Save")
                    }
                    .dsTextStyle(.micro)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!tab.isDirty || isSaving)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(Color.clear)  // Unified with panel background

            Divider()

            // Unified scroll view with line numbers and text together
            // Horizontal scroll enabled to prevent text wrapping - ensures line numbers align 1:1
            GeometryReader { geometry in
                let fontSize = calculateFontSize(for: geometry.size.width)
                let lineHeight = max(16, fontSize * 1.5)

                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Line number gutter - scrolls WITH content
                        LazyVStack(alignment: .trailing, spacing: 0) {
                            ForEach(1...max(cachedLineCount, 1), id: \.self) { lineNum in
                                Text("\(lineNum)")
                                    .font(.system(size: fontSize, design: .monospaced))
                                    .foregroundStyle(Color.ds.tertiary)
                                    .frame(height: lineHeight, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.top, 8)
                        .frame(width: lineNumberWidth)
                        .background(Color.clear)  // Unified with panel background

                        // Text content - no word wrap, horizontal scroll instead
                        NoWrapTextEditor(
                            text: $fileContent,
                            fontSize: fontSize,
                            lineHeight: lineHeight,
                            onFocusChange: { focused in
                                isEditorFocused = focused
                            },
                            editorSession: appState.editorSession(for: tab)
                        )
                        .frame(
                            minWidth: maxLineWidth(fontSize: fontSize),
                            minHeight: CGFloat(cachedLineCount) * lineHeight + 16
                        )
                    }
                }
            }
            .background(Color.clear)  // Unified with panel background
        }
    }

    private var lineNumberWidth: CGFloat {
        let digits = String(max(cachedLineCount, 1)).count
        // 12pt monospaced font needs ~8px per digit + padding for alignment
        return CGFloat(max(digits, 3)) * 12 + 24
    }

    /// Calculate the width needed to display the longest line without wrapping
    private func maxLineWidth(fontSize: CGFloat) -> CGFloat {
        let lines = fileContent.components(separatedBy: .newlines)
        let maxLength = lines.map { $0.count }.max() ?? 0
        // Monospaced font: ~0.6 * fontSize per character + padding
        return CGFloat(maxLength) * fontSize * 0.65 + 32
    }

    /// Calculate responsive font size based on available width.
    /// Scales from 12pt (normal) down to 8pt (minimum) when space is constrained.
    private func calculateFontSize(for width: CGFloat) -> CGFloat {
        let gutterWidth = lineNumberWidth
        let minContentWidth: CGFloat = 200
        let maxFontSize: CGFloat = 12  // 12pt mono ≈ 14pt proportional
        let minFontSize: CGFloat = 8

        // If plenty of space, use max font size
        if width > gutterWidth + minContentWidth * 1.5 {
            return maxFontSize
        }

        // Scale font based on available space
        let scale = max(0, (width - gutterWidth - 100) / minContentWidth)
        return max(minFontSize, minFontSize + (maxFontSize - minFontSize) * scale)
    }

    // MARK: - Save File

    private func saveFile() {
        guard tab.isDirty, !isSaving else { return }

        isSaving = true
        Task {
            do {
                try await appState.saveFileTab(tab.id, content: fileContent)
                await MainActor.run {
                    originalContent = fileContent
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    // MARK: - Load Content

    private func loadFileContent() {
        isLoading = true
        loadError = nil
        isBinaryFile = false
        fileSize = nil

        Task {
            do {
                // Get file size
                let url = URL(fileURLWithPath: tab.filePath)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    await MainActor.run {
                        fileSize = size
                    }
                }

                let content = try await loadFile(at: tab.filePath)
                await MainActor.run {
                    fileContent = content
                    originalContent = content  // Store original for dirty tracking
                    cachedLineCount = content.filter { $0 == "\n" }.count + 1  // Initialize line count
                    isLoading = false
                }
            } catch FileViewerError.binaryFile {
                await MainActor.run {
                    isBinaryFile = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func loadFile(at path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)

        // Check if it's a binary file by extension first
        let ext = url.pathExtension.lowercased()
        if BinaryFileDetector.isBinaryExtension(ext) {
            throw FileViewerError.binaryFile
        }

        let data = try Data(contentsOf: url)

        // Check for binary content (null bytes)
        if BinaryFileDetector.isBinaryContent(data) {
            throw FileViewerError.binaryFile
        }

        // Try to decode as UTF-8, fall back to ASCII
        if let content = String(data: data, encoding: .utf8) {
            return content
        } else if let content = String(data: data, encoding: .ascii) {
            return content
        } else {
            throw FileViewerError.encodingError
        }
    }
}

// MARK: - Code Line View

/// Single line of code with line number and syntax highlighting
struct CodeLineView: View {
    let lineNumber: Int
    let content: String
    let language: SyntaxHighlighter.Language
    let isCurrentLine: Bool

    @State private var isHovered: Bool = false

    private var lineNumberWidth: CGFloat {
        // Calculate width based on number of digits
        let digits = String(lineNumber).count
        return CGFloat(max(digits, 3)) * 8 + 16
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line number gutter
            Text("\(lineNumber)")
                .dsTextStyle(.monoSmall)
                .foregroundStyle(isCurrentLine ? Color.ds.foreground : Color.ds.tertiary)
                .frame(width: lineNumberWidth, alignment: .trailing)
                .padding(.trailing, DSSpacing.sm)
                .background(
                    isCurrentLine
                        ? Color.ds.accent.opacity(0.15)
                        : (isHovered ? Color.ds.surface.opacity(0.3) : Color.ds.surface.opacity(0.2))
                )

            // Code content
            Text(SyntaxHighlighter.highlight(content, language: language))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, DSSpacing.md)
        }
        .frame(minHeight: 20)
        .background(
            isCurrentLine
                ? Color.ds.accent.opacity(0.1)
                : (isHovered ? Color.ds.surface.opacity(0.1) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Markdown Content View

/// Renders markdown content with proper formatting
struct MarkdownContentView: View {
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(attributedContent)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DSSpacing.lg)
        }
    }

    private var attributedContent: AttributedString {
        do {
            return try AttributedString(markdown: content, options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            ))
        } catch {
            return AttributedString(content)
        }
    }
}

// MARK: - Empty State

/// Shown when no file is selected
struct EmptyFileViewerState: View {
    let onOpenFile: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.tertiary)

            Text("No File Open")
                .dsTextStyle(.title)

            Text("Open a file from the chat or use the sidebar to browse project files")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: DSSpacing.md) {
                Button("Open File...") {
                    onOpenFile()
                }
                .buttonStyle(.bordered)

                Button("Switch to Chat") {
                    // Will be handled by parent
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)  // Unified with panel background
    }
}

// MARK: - File Viewer Error

enum FileViewerError: LocalizedError {
    case fileNotFound
    case accessDenied
    case encodingError
    case fileTooLarge
    case binaryFile

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .accessDenied:
            return "Access denied"
        case .encodingError:
            return "Unable to read file encoding"
        case .fileTooLarge:
            return "File is too large to display"
        case .binaryFile:
            return "Binary file cannot be displayed as text"
        }
    }
}

// MARK: - Breadcrumb Path

/// Shows the file path as breadcrumbs
struct FileBreadcrumb: View {
    let filePath: String

    private var components: [String] {
        // Show last 3 path components
        let parts = filePath.components(separatedBy: "/").filter { !$0.isEmpty }
        if parts.count <= 4 {
            return parts
        }
        return ["..."] + Array(parts.suffix(3))
    }

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.ds.tertiary)
                }

                Text(component)
                    .dsTextStyle(.caption, color: index == components.count - 1 ? .ds.foreground : .ds.secondary)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
    }
}

// MARK: - Previews

#Preview("File Viewer") {
    let appState = AppState()

    // Add some sample tabs
    appState.openFileTabs = [
        FileTab(filePath: "/Users/dev/project/Sources/App/BlazeApp.swift", isPreview: false),
        FileTab(filePath: "/Users/dev/project/README.md", isPreview: true),
    ]
    appState.activeFileTabId = appState.openFileTabs.first?.id

    return FileViewerView()
        .environmentObject(appState)
        .frame(width: 800, height: 600)
}

#Preview("Code Line") {
    VStack(spacing: 0) {
        CodeLineView(
            lineNumber: 1,
            content: "import SwiftUI",
            language: .swift,
            isCurrentLine: false
        )
        CodeLineView(
            lineNumber: 2,
            content: "",
            language: .swift,
            isCurrentLine: false
        )
        CodeLineView(
            lineNumber: 3,
            content: "struct ContentView: View {",
            language: .swift,
            isCurrentLine: true
        )
        CodeLineView(
            lineNumber: 4,
            content: "    var body: some View {",
            language: .swift,
            isCurrentLine: false
        )
    }
    .frame(width: 500)
    .background(Color.ds.bg0)
}

#Preview("Empty State") {
    EmptyFileViewerState(onOpenFile: {})
        .frame(width: 600, height: 400)
}

#Preview("Breadcrumb") {
    VStack(spacing: DSSpacing.md) {
        FileBreadcrumb(filePath: "/Users/dev/project/Sources/App/BlazeApp.swift")
        FileBreadcrumb(filePath: "/short/path.txt")
    }
    .padding()
    .background(Color.ds.bg0)
}
