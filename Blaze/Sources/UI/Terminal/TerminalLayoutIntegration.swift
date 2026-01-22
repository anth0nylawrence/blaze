import SwiftUI

// MARK: - TerminalLayoutIntegration (E001-F006-S001-T009-A001)

/// Integration helpers for embedding terminal panel in the main app layout.
///
/// **Phase 2 System Contract:**
/// - Bottom panel with resizable height
/// - Toggle visibility with keyboard shortcut
/// - Auto-show when Claude runs foreground commands
/// - Proper focus management between chat and terminal

// MARK: - Terminal Panel Container

/// Container view that manages the terminal panel position and visibility
public struct TerminalPanelContainer<Content: View>: View {
    let content: Content
    @ObservedObject var terminalViewModel: TerminalPanelViewModel

    @State private var panelHeight: CGFloat = 250
    @State private var isDragging: Bool = false

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 500
    private let defaultHeight: CGFloat = 250

    public init(
        terminalViewModel: TerminalPanelViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.terminalViewModel = terminalViewModel
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main content area - takes remaining space after terminal
            content
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipShape(Rectangle())  // Strong clipping to prevent overflow
                .layoutPriority(1)  // Content fills remaining space

            // Terminal panel (when visible) - sizes itself based on expanded state
            if terminalViewModel.isVisible {
                // Spacer between chat and terminal for visual separation
                Color.clear.frame(height: 8)

                TerminalPanelView(viewModel: terminalViewModel, maxHeight: panelHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: terminalViewModel.isVisible)
    }
}

// MARK: - Terminal Resize Handle

/// Draggable handle for resizing the terminal panel
struct TerminalResizeHandle: View {
    @Binding var isDragging: Bool

    var body: some View {
        Rectangle()
            .fill(Color(.separatorColor))
            .frame(height: 1)
            .overlay {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDragging ? Color.accentColor : Color(.tertiaryLabelColor))
                    .frame(width: 40, height: 4)
            }
            .contentShape(Rectangle().size(width: .infinity, height: 10))
            .cursor(.resizeUpDown)
    }
}

// MARK: - Cursor Modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Terminal Toggle Button

/// Button for toggling terminal visibility in toolbar
public struct TerminalToggleButton: View {
    @ObservedObject var viewModel: TerminalPanelViewModel

    public init(viewModel: TerminalPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Button {
            withAnimation {
                viewModel.toggle()
            }
        } label: {
            Label {
                Text("Terminal")
            } icon: {
                Image(systemName: viewModel.isVisible ? "terminal.fill" : "terminal")
            }
        }
        .help(viewModel.isVisible ? "Hide Terminal (Cmd+`)" : "Show Terminal (Cmd+`)")
    }
}

// MARK: - Keyboard Shortcut Extension

/// Keyboard shortcut handling for terminal
public struct TerminalKeyboardShortcuts: ViewModifier {
    @ObservedObject var viewModel: TerminalPanelViewModel

    public func body(content: Content) -> some View {
        content
            // Toggle terminal (Cmd + `)
            .keyboardShortcut("`", modifiers: .command)
            // Create new terminal (Cmd + Shift + T)
            .onReceive(NotificationCenter.default.publisher(for: .init("CreateNewTerminal"))) { _ in
                Task {
                    await viewModel.createNewTerminal()
                }
            }
    }
}

extension View {
    public func terminalKeyboardShortcuts(_ viewModel: TerminalPanelViewModel) -> some View {
        self.modifier(TerminalKeyboardShortcuts(viewModel: viewModel))
    }
}

// MARK: - Terminal Focus State

/// Focus state for managing keyboard input between chat and terminal
public enum TerminalFocusState: Hashable {
    case chat
    case terminal(UUID)  // Terminal tab ID
    case fileTree
    case sidebar
}

// MARK: - Terminal Sidebar Badge

/// Badge showing terminal status for sidebar
public struct TerminalSidebarBadge: View {
    @ObservedObject var viewModel: TerminalPanelViewModel

    private var hasRunningProcesses: Bool {
        !viewModel.tabs.filter { tab in
            tab.kind == .user && !tab.isClosed
        }.isEmpty
    }

    public var body: some View {
        if hasRunningProcesses {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("\(viewModel.tabs.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.controlBackgroundColor))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Auto-Show Handler

/// Handler for terminal auto-show events from Claude
public struct TerminalAutoShowHandler {
    let viewModel: TerminalPanelViewModel

    /// Handle a tool event and potentially show the terminal
    public func handleToolEvent(_ event: NormalizedEvent, sessionId: UUID) async {
        guard let autoShowEvent = ClaudeBackgroundDetector.parseToolEvent(event, sessionId: sessionId) else {
            return
        }

        let terminalManager = await getTerminalManager()
        let shouldShow = await terminalManager.shouldAutoShow(for: autoShowEvent)

        if shouldShow {
            await MainActor.run {
                viewModel.show()
            }
        }
    }

    private func getTerminalManager() async -> TerminalManager {
        // This would be injected via the view model in practice
        // For now, return a placeholder
        TerminalManager()
    }
}

// MARK: - Terminal Status Bar

/// Status bar showing terminal state
public struct TerminalStatusBar: View {
    @ObservedObject var viewModel: TerminalPanelViewModel

    public var body: some View {
        HStack(spacing: 12) {
            // Terminal count
            if !viewModel.tabs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))

                    Text("\(viewModel.tabs.count)")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }

            // Running processes indicator
            let runningCount = viewModel.tabs.filter { $0.kind == .user && !$0.isClosed }.count
            if runningCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)

                    Text("\(runningCount) running")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Full Integration Example

/// Example of full terminal integration in main content view
public struct TerminalIntegratedContentView: View {
    let sessionId: UUID
    let workingDirectory: URL
    @StateObject private var terminalViewModel: TerminalPanelViewModel

    public init(sessionId: UUID, workingDirectory: URL, terminalManager: TerminalManager) {
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory
        self._terminalViewModel = StateObject(wrappedValue: TerminalPanelViewModel(
            terminalManager: terminalManager,
            sessionId: sessionId,
            workingDirectory: workingDirectory
        ))
    }

    public var body: some View {
        TerminalPanelContainer(terminalViewModel: terminalViewModel) {
            // Main content goes here
            VStack {
                Text("Main Content Area")
                    .font(.title)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    TerminalToggleButton(viewModel: terminalViewModel)
                }
            }
        }
        .terminalKeyboardShortcuts(terminalViewModel)
    }
}

// MARK: - Previews

#Preview("Terminal Panel Container") {
    let manager = TerminalManager()
    let viewModel = TerminalPanelViewModel(
        terminalManager: manager,
        sessionId: UUID(),
        workingDirectory: URL(fileURLWithPath: NSHomeDirectory())
    )

    return TerminalPanelContainer(terminalViewModel: viewModel) {
        VStack {
            Text("Main Content")
                .font(.largeTitle)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    .frame(width: 800, height: 600)
    .onAppear {
        viewModel.show()
    }
}

#Preview("Terminal Toggle Button") {
    let manager = TerminalManager()
    let viewModel = TerminalPanelViewModel(
        terminalManager: manager,
        sessionId: UUID(),
        workingDirectory: URL(fileURLWithPath: NSHomeDirectory())
    )

    return TerminalToggleButton(viewModel: viewModel)
        .padding()
}

#Preview("Terminal Sidebar Badge") {
    let manager = TerminalManager()
    let viewModel = TerminalPanelViewModel(
        terminalManager: manager,
        sessionId: UUID(),
        workingDirectory: URL(fileURLWithPath: NSHomeDirectory())
    )

    return TerminalSidebarBadge(viewModel: viewModel)
        .padding()
}
