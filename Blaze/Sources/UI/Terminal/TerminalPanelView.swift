import SwiftUI
import SwiftTerm

// MARK: - TerminalPanelView (E001-F006-S001-T007-A001)

/// Terminal panel UI with tabs for user and Claude terminals.
///
/// **Phase 2 System Contract:**
/// - Bottom-right terminal panel
/// - Tabs row: User terminals + Claude terminal
/// - "+" creates new user terminal tab
/// - Auto-show when Claude runs foreground command
public struct TerminalPanelView: View {
    @ObservedObject var viewModel: TerminalPanelViewModel
    let maxHeight: CGFloat

    @State private var isExpanded: Bool = true

    public init(viewModel: TerminalPanelViewModel, maxHeight: CGFloat = 250) {
        self.viewModel = viewModel
        self.maxHeight = maxHeight
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Resize handle / header
            resizeHandle

            // Tab bar and content (only when expanded)
            if isExpanded {
                tabBar

                Divider()

                // Ghostty unavailable banner (E003-F001-S004-T001-A001)
                if viewModel.shouldShowGhosttyBanner {
                    VStack(spacing: 0) {
                        GhosttyUnavailableBanner {
                            viewModel.switchToSwiftTerm()
                        }
                        .padding(DSSpacing.sm)

                        Divider()
                    }
                }

                // Terminal content
                terminalContent
            }
        }
        .frame(height: isExpanded ? maxHeight : nil)  // Only fixed height when expanded
        .fixedSize(horizontal: false, vertical: !isExpanded)  // Collapse to content size when not expanded
        .background(Color.clear)  // Unified with panel background
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        HStack {
            // Expand/collapse button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("Terminal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            // Tab count badge
            if !viewModel.tabs.isEmpty {
                Text("\(viewModel.tabs.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.clear)  // Unified with panel background
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(viewModel.tabs) { tab in
                    TerminalTabButton(
                        tab: tab,
                        isSelected: viewModel.selectedTabId == tab.id,
                        onSelect: {
                            viewModel.selectTab(tab.id)
                        },
                        onClose: {
                            Task {
                                await viewModel.closeTab(tab.id)
                            }
                        }
                    )
                }

                // Add tab button
                Button {
                    Task {
                        await viewModel.createNewTerminal()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("New Terminal")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Terminal Content

    @ViewBuilder
    private var terminalContent: some View {
        if let selectedTab = viewModel.selectedTab {
            if selectedTab.kind == .claude {
                ClaudeTerminalView(viewModel: viewModel, tab: selectedTab)
            } else {
                UserTerminalView(viewModel: viewModel, tab: selectedTab)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("No terminals open")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("New Terminal") {
                Task {
                    await viewModel.createNewTerminal()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TerminalTabButton

/// Single tab button in the terminal tab bar
struct TerminalTabButton: View {
    let tab: TerminalTab
    let isSelected: Bool
    var onSelect: () -> Void
    var onClose: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            // Icon
            Image(systemName: tab.kind.icon)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? .primary : .secondary)

            // Title
            Text(tab.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)

            // Close button (on hover)
            if isHovered || isSelected {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(.selectedContentBackgroundColor).opacity(0.1) : .clear))
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - UserTerminalView

/// Interactive user terminal view using SwiftTerm
struct UserTerminalView: View {
    @ObservedObject var viewModel: TerminalPanelViewModel
    let tab: TerminalTab

    var body: some View {
        GeometryReader { geometry in
            SwiftTermViewWrapper(
                tabId: tab.id,
                viewModel: viewModel,
                size: CGSize(width: geometry.size.width - DSSpacing.sm, height: geometry.size.height)
            )
            .padding(.leading, DSSpacing.sm)  // Left padding for visual alignment
        }
    }
}

// MARK: - SwiftTermViewWrapper

/// NSViewRepresentable wrapper for SwiftTerm with integrated PTY
struct SwiftTermViewWrapper: NSViewRepresentable {
    let tabId: UUID
    @ObservedObject var viewModel: TerminalPanelViewModel
    let size: CGSize

    func makeNSView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: NSRect(origin: .zero, size: size))
        terminalView.configureNativeColors()

        // Make terminal background transparent for glass effect
        terminalView.nativeBackgroundColor = NSColor.clear

        // Enable layer-backed rendering and set transparent background
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalView.layer?.isOpaque = false

        // Configure appearance with font that supports powerline/nerd font glyphs
        let fontSize: CGFloat = 12  // Fixed 12pt to match file tree
        // Try to use Menlo which has good unicode coverage, with SF Mono as fallback
        let preferredFonts = ["MesloLGS NF", "Menlo", "SF Mono"]
        var terminalFont: NSFont?
        for fontName in preferredFonts {
            if let font = NSFont(name: fontName, size: fontSize) {
                terminalFont = font
                break
            }
        }
        terminalView.font = terminalFont ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Set up terminal delegate
        terminalView.terminalDelegate = context.coordinator
        context.coordinator.terminalView = terminalView

        // Create LocalProcess with delegate that feeds the TerminalView
        let processDelegate = TerminalProcessDelegate(terminalView: terminalView)
        context.coordinator.processDelegate = processDelegate
        let localProcess = LocalProcess(delegate: processDelegate)
        context.coordinator.localProcess = localProcess

        // Start shell process
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let workingDir = viewModel.workingDirectory.path

        // Build environment with proper TERM setting and working directory
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["PWD"] = workingDir
        env["LC_ALL"] = "en_US.UTF-8"  // Ensure proper UTF-8 encoding
        env["LANG"] = "en_US.UTF-8"
        env["PROMPT_EOL_MARK"] = ""  // Suppress zsh partial-line indicator
        let envArray = env.map { "\($0.key)=\($0.value)" }

        // Note: LocalProcess startProcess doesn't take cwd, so we cd in shell args
        localProcess.startProcess(
            executable: shell,
            args: ["-l", "-c", "cd '\(workingDir)' && exec \(shell) -l"],
            environment: envArray,
            execName: shell
        )

        return terminalView
    }

    func updateNSView(_ terminalView: TerminalView, context: Context) {
        // Size changes are handled by TerminalView internally
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tabId: tabId, viewModel: viewModel)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        let tabId: UUID
        let viewModel: TerminalPanelViewModel
        weak var terminalView: TerminalView?
        var localProcess: LocalProcess?
        var processDelegate: TerminalProcessDelegate?

        init(tabId: UUID, viewModel: TerminalPanelViewModel) {
            self.tabId = tabId
            self.viewModel = viewModel
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            // Size changes propagate through the delegate's getWindowSize()
        }

        func setTerminalTitle(source: TerminalView, title: String) {
            Task { @MainActor in
                await viewModel.updateTabTitle(tabId, title: title)
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            // Send user input to the shell process
            localProcess?.send(data: data)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String:String]) {
            if let url = URL(string: link) {
                NSWorkspace.shared.open(url)
            }
        }

        func bell(source: TerminalView) {
            NSSound.beep()
        }

        func selectionChanged(source: TerminalView) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            if let string = String(data: content, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    }
}

// MARK: - Terminal Process Delegate

/// Delegate that connects LocalProcess output to TerminalView
class TerminalProcessDelegate: LocalProcessDelegate {
    private weak var terminalView: TerminalView?
    private var isFirstOutput = true

    init(terminalView: TerminalView) {
        self.terminalView = terminalView
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        // Process ended
        DispatchQueue.main.async { [weak self] in
            let message = "\r\n[Process exited with code \(exitCode ?? -1)]\r\n"
            if let data = message.data(using: .utf8) {
                let bytes = [UInt8](data)
                self?.terminalView?.getTerminal().feed(byteArray: bytes)
            }
        }
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        var filteredSlice = slice

        // Filter zsh's partial-line indicator ("%" followed by spaces) from initial output
        // This appears when PROMPT_SP is set and previous output didn't end with newline
        if isFirstOutput {
            isFirstOutput = false
            if let firstByte = slice.first, firstByte == UInt8(ascii: "%") {
                filteredSlice = slice.dropFirst()
            }
        }

        // Feed process output to terminal view
        DispatchQueue.main.async { [weak self] in
            self?.terminalView?.feed(byteArray: filteredSlice)
        }
    }

    func getWindowSize() -> winsize {
        guard let terminalView = terminalView else {
            return winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
        }
        let terminal = terminalView.getTerminal()
        return winsize(
            ws_row: UInt16(terminal.rows),
            ws_col: UInt16(terminal.cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
    }
}

// MARK: - ClaudeTerminalView

/// Read-only terminal view for Claude output
struct ClaudeTerminalView: View {
    @ObservedObject var viewModel: TerminalPanelViewModel
    let tab: TerminalTab

    @State private var scrolledToBottom: Bool = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.getScrollbackLines(for: tab.id)) { line in
                        Text(line.content)
                            .font(.system(size: viewModel.cachedFontSize, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(8)
            }
            .background(Color.clear)  // Unified with panel background
            .onChange(of: viewModel.scrollbackUpdateCounter) { _, _ in
                if scrolledToBottom {
                    if let lastLine = viewModel.getScrollbackLines(for: tab.id).last {
                        withAnimation {
                            proxy.scrollTo(lastLine.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                // Copy all button
                Button {
                    Task {
                        if let content = await viewModel.exportTerminalOutput(tab.id) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(content, forType: .string)
                        }
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Copy all output")

                // Clear button
                Button {
                    Task {
                        await viewModel.clearScrollback(tab.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Clear output")
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(8)
        }
    }
}

// MARK: - TerminalPanelViewModel

/// ViewModel for the terminal panel
@MainActor
public class TerminalPanelViewModel: ObservableObject {
    @Published public private(set) var tabs: [TerminalTab] = []
    @Published public var selectedTabId: UUID?
    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var scrollbackUpdateCounter: Int = 0
    @Published public private(set) var cachedFontSize: CGFloat = 12  // Match file tree font size
    @Published public private(set) var currentBackendType: TerminalBackendType = .swiftTerm

    public var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }

    /// Whether to show Ghostty unavailable banner
    public var shouldShowGhosttyBanner: Bool {
        currentBackendType == .ghostty && !currentBackendType.isAvailable
    }

    private let terminalManager: TerminalManager
    public let sessionId: UUID
    public let workingDirectory: URL

    private var scrollbackCache: [UUID: [ScrollbackLine]] = [:]

    public init(
        terminalManager: TerminalManager,
        sessionId: UUID,
        workingDirectory: URL
    ) {
        self.terminalManager = terminalManager
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory

        // Start listening for events
        Task {
            await startListening()
        }

        // Load cached preferences
        Task {
            let prefs = await terminalManager.getPreferences()
            self.cachedFontSize = prefs.fontSize
            self.currentBackendType = prefs.backendType
        }
    }

    // MARK: - Tab Management

    public func createNewTerminal() async {
        do {
            let tab = try await terminalManager.createUserTerminal(
                sessionId: sessionId,
                workingDirectory: workingDirectory
            )
            tabs.append(tab)
            selectedTabId = tab.id
            isVisible = true
        } catch {
            // Handle error
            print("Failed to create terminal: \(error)")
        }
    }

    public func selectTab(_ id: UUID) {
        selectedTabId = id
        Task {
            await terminalManager.setActiveTab(id)
        }
    }

    public func closeTab(_ id: UUID) async {
        await terminalManager.closeTab(id)
        tabs.removeAll { $0.id == id }

        if selectedTabId == id {
            selectedTabId = tabs.first?.id
        }
    }

    public func updateTabTitle(_ id: UUID, title: String) async {
        await terminalManager.updateTabTitle(id, title: title)
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].title = title
        }
    }

    // MARK: - Terminal I/O

    public func writeToTerminal(_ id: UUID, data: Data) async {
        await terminalManager.write(id, data: data)
    }

    public func resizeTerminal(_ id: UUID, size: TerminalSize) async {
        await terminalManager.resize(id, size: size)
    }

    public func clearScrollback(_ id: UUID) async {
        await terminalManager.clearScrollback(id)
        scrollbackCache[id] = []
        scrollbackUpdateCounter += 1
    }

    public func exportTerminalOutput(_ id: UUID) async -> String? {
        await terminalManager.exportOutput(id)
    }

    // MARK: - Scrollback

    public func getScrollbackLines(for tabId: UUID) -> [ScrollbackLine] {
        scrollbackCache[tabId] ?? []
    }

    // MARK: - Visibility

    public func show() {
        isVisible = true
    }

    public func hide() {
        isVisible = false
    }

    public func toggle() {
        isVisible.toggle()
    }

    // MARK: - Backend Management

    /// Switch to SwiftTerm backend (for Ghostty fallback)
    public func switchToSwiftTerm() {
        Task {
            var prefs = await terminalManager.getPreferences()
            prefs.backendType = .swiftTerm
            await terminalManager.updatePreferences(prefs)
            currentBackendType = .swiftTerm
        }
    }

    // MARK: - Private

    private func startListening() async {
        // Listen for tab events
        Task {
            for await event in await terminalManager.tabEvents {
                await handleTabEvent(event)
            }
        }

        // Listen for output events
        Task {
            for await output in await terminalManager.outputEvents {
                await handleOutputEvent(output)
            }
        }

        // Set up auto-show handler
        await terminalManager.setAutoShowHandler { [weak self] sessionId in
            Task { @MainActor [weak self] in
                guard let self = self, self.sessionId == sessionId else { return }
                self.show()
            }
        }
    }

    private func handleTabEvent(_ event: TerminalTabEvent) async {
        switch event {
        case .created(let tab):
            if !tabs.contains(where: { $0.id == tab.id }) {
                tabs.append(tab)
            }
        case .updated(let tab):
            if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs[index] = tab
            }
        case .closed(let tab):
            tabs.removeAll { $0.id == tab.id }
        case .processTerminated(let tab, _):
            if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                var updatedTab = tabs[index]
                updatedTab.title = "\(updatedTab.title) (exited)"
                tabs[index] = updatedTab
            }
        }
    }

    private func handleOutputEvent(_ output: TerminalOutputEvent) async {
        // Update scrollback cache
        if scrollbackCache[output.tabId] == nil {
            scrollbackCache[output.tabId] = []
        }

        let lines = output.content.asString.components(separatedBy: .newlines)
        for line in lines where !line.isEmpty {
            scrollbackCache[output.tabId]?.append(ScrollbackLine(
                sequence: output.sequence,
                content: line,
                timestamp: output.timestamp
            ))
        }

        scrollbackUpdateCounter += 1
    }
}

// MARK: - Previews

#Preview("Terminal Panel") {
    let manager = TerminalManager()
    let viewModel = TerminalPanelViewModel(
        terminalManager: manager,
        sessionId: UUID(),
        workingDirectory: URL(fileURLWithPath: NSHomeDirectory())
    )

    TerminalPanelView(viewModel: viewModel)
        .frame(width: 600, height: 400)
}

#Preview("Terminal Tab Button") {
    HStack {
        TerminalTabButton(
            tab: TerminalTab(sessionId: UUID(), kind: .user, title: "zsh"),
            isSelected: true,
            onSelect: {},
            onClose: {}
        )

        TerminalTabButton(
            tab: TerminalTab(sessionId: UUID(), kind: .claude, title: "Claude Output"),
            isSelected: false,
            onSelect: {},
            onClose: {}
        )
    }
    .padding()
}
