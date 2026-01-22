import SwiftUI

// MARK: - Screen Preview View

/// Preview container for full screens with state handling.
struct ScreenPreviewView: View {
    let screenId: String?
    let state: PreviewState

    var body: some View {
        if let screenId = screenId {
            VStack(spacing: DSSpacing.lg) {
                // Screen name header
                HStack {
                    Text(screenName(for: screenId))
                        .dsTextStyle(.title)
                    Spacer()
                    Badge(state.rawValue, variant: badgeVariant(for: state), size: .small)
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)

                // Preview container with border
                screenContent(for: screenId)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.lg)
                            .stroke(Color.ds.border, lineWidth: 1)
                    )
                    .padding(DSSpacing.lg)

                Spacer()
            }
        } else {
            EmptyState(
                icon: "rectangle.on.rectangle",
                title: "Select a Screen",
                description: "Choose a screen from the list to preview it."
            )
        }
    }

    private func screenName(for id: String) -> String {
        switch id {
        case "ChatTimeline": return "Chat Timeline"
        case "DiffViewer": return "Diff Viewer"
        case "Settings": return "Settings"
        case "SessionList": return "Session List"
        default: return id
        }
    }

    @ViewBuilder
    private func screenContent(for id: String) -> some View {
        switch id {
        case "ChatTimeline":
            ChatTimelineScreenPreview(state: state)
        case "DiffViewer":
            DiffViewerScreenPreview(state: state)
        case "Settings":
            SettingsScreenPreview(state: state)
        case "SessionList":
            SessionListScreenPreview(state: state)
        default:
            Text("Preview not implemented for \(id)")
                .dsTextStyle(.body, color: .ds.secondary)
                .frame(width: 600, height: 400)
        }
    }

    private func badgeVariant(for state: PreviewState) -> BadgeVariant {
        switch state {
        case .loading: return .info
        case .empty: return .default
        case .error: return .error
        case .success: return .success
        case .edge: return .warning
        }
    }
}

// MARK: - Chat Timeline Preview

struct ChatTimelineScreenPreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    switch state {
                    case .loading:
                        MessageSkeleton(isUser: false, lines: 2)
                        MessageSkeleton(isUser: true, lines: 1)
                        MessageSkeleton(isUser: false, lines: 3)

                    case .empty:
                        EmptyState(
                            icon: "bubble.left.and.bubble.right",
                            title: "No Messages",
                            description: "Start a conversation by typing a message below."
                        )

                    case .error:
                        ErrorState(
                            title: "Failed to Load",
                            message: "Could not load messages. Please try again.",
                            retryAction: {}
                        )

                    case .success:
                        mockMessage(isUser: true, text: "Can you help me refactor this function?")
                        mockMessage(isUser: false, text: "I'd be happy to help you refactor. Could you share the function you'd like to improve?")
                        mockMessage(isUser: true, text: "Here's the code...")

                    case .edge:
                        // Long messages
                        mockMessage(isUser: false, text: String(repeating: "This is a very long message that tests how the UI handles extensive content. ", count: 10))
                    }
                }
                .padding(DSSpacing.md)
            }

            Divider()

            // Input area
            HStack(spacing: DSSpacing.sm) {
                GlassTextField("Type a message...", text: .constant(""))
                GlassButton("Send", icon: "paperplane.fill", size: .small) {}
            }
            .padding(DSSpacing.md)
            .background(Color.ds.bg1)
        }
        .frame(width: 600, height: 500)
        .background(Color.ds.bg0)
    }

    private func mockMessage(isUser: Bool, text: String) -> some View {
        HStack {
            if isUser { Spacer() }

            Text(text)
                .dsTextStyle(.body)
                .padding(DSSpacing.md)
                .background(isUser ? Color.accentColor : Color.ds.panel)
                .foregroundStyle(isUser ? .white : Color.ds.foreground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))

            if !isUser { Spacer() }
        }
    }
}

// MARK: - Diff Viewer Preview

struct DiffViewerScreenPreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("src/main.swift", systemImage: "doc.fill")
                    .dsTextStyle(.subtitle)
                Spacer()
                Badge("+15", variant: .success, size: .small)
                Badge("-3", variant: .error, size: .small)
            }
            .padding(DSSpacing.md)
            .background(Color.ds.bg1)

            Divider()

            // Diff content
            ScrollView {
                switch state {
                case .loading:
                    VStack(spacing: DSSpacing.xs) {
                        ForEach(0..<10, id: \.self) { _ in
                            LoadingSkeleton(height: 20)
                        }
                    }
                    .padding(DSSpacing.md)

                case .empty:
                    EmptyState(
                        icon: "doc.badge.plus",
                        title: "No Changes",
                        description: "This file has no modifications."
                    )

                case .error:
                    ErrorState(
                        title: "Cannot Load Diff",
                        message: "Failed to parse the diff content.",
                        retryAction: {}
                    )

                case .success, .edge:
                    VStack(alignment: .leading, spacing: 0) {
                        diffLine(number: 10, type: .context, text: "import Foundation")
                        diffLine(number: 11, type: .context, text: "")
                        diffLine(number: 12, type: .removal, text: "func oldFunction() {")
                        diffLine(number: 12, type: .addition, text: "func newFunction() async throws {")
                        diffLine(number: 13, type: .context, text: "    // Implementation")
                        diffLine(number: 14, type: .addition, text: "    try await Task.sleep(nanoseconds: 1_000_000)")
                        diffLine(number: 15, type: .context, text: "}")
                    }
                    .padding(DSSpacing.sm)
                }
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                GlassButton("Reject", icon: "xmark", style: .ghost, size: .small) {}
                GlassButton("Accept", icon: "checkmark", style: .primary, size: .small) {}
            }
            .padding(DSSpacing.md)
            .background(Color.ds.bg1)
        }
        .frame(width: 600, height: 400)
        .background(Color.ds.bg0)
    }

    enum DiffLineType {
        case context, addition, removal
    }

    private func diffLine(number: Int, type: DiffLineType, text: String) -> some View {
        HStack(spacing: 0) {
            // Line number
            Text("\(number)")
                .dsTextStyle(.monoSmall, color: .ds.tertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, DSSpacing.xs)

            // Prefix
            Text(type == .addition ? "+" : (type == .removal ? "-" : " "))
                .dsTextStyle(.mono, color: prefixColor(for: type))
                .frame(width: 20)

            // Content
            Text(text)
                .dsTextStyle(.mono)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(backgroundColor(for: type))
    }

    private func prefixColor(for type: DiffLineType) -> Color {
        switch type {
        case .addition: return Color.ds.positive
        case .removal: return Color.ds.negative
        case .context: return Color.ds.tertiary
        }
    }

    private func backgroundColor(for type: DiffLineType) -> Color {
        switch type {
        case .addition: return Color.ds.diffAdd
        case .removal: return Color.ds.diffRemove
        case .context: return .clear
        }
    }
}

// MARK: - Settings Preview

struct SettingsScreenPreview: View {
    let state: PreviewState
    @State private var projectPath = "/Users/dev/project"
    @State private var trustMode = 0

    var body: some View {
        TabView {
            // General tab
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                switch state {
                case .loading:
                    CardSkeleton()
                    CardSkeleton(showAvatar: false)

                case .error:
                    DSErrorBanner(severity: .error, message: "Failed to load settings", dismissAction: {})

                default:
                    FormSection(title: "Project") {
                        FormRow(label: "Project Path") {
                            GlassTextField("Path", text: $projectPath, icon: "folder")
                        }
                    }

                    FormSection(title: "Security") {
                        Picker("Trust Mode", selection: $trustMode) {
                            Text("Review").tag(0)
                            Text("Trusted").tag(1)
                            Text("Sandbox").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding(DSSpacing.lg)
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // Engines tab
            Text("Engines settings")
                .tabItem {
                    Label("Engines", systemImage: "cpu")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Session List Preview

struct SessionListScreenPreview: View {
    let state: PreviewState
    @State private var selectedSession = "session1"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Sessions")
                    .dsTextStyle(.title)
                Spacer()
                GlassIconButton(icon: "plus", size: .small) {}
            }
            .padding(DSSpacing.md)

            Divider()

            // List
            switch state {
            case .loading:
                ListSkeleton(itemCount: 5)
                    .padding(DSSpacing.sm)

            case .empty:
                EmptyState(
                    icon: "tray",
                    title: "No Sessions",
                    description: "Create a new session to get started.",
                    actionTitle: "New Session"
                ) {}

            case .error:
                ErrorState(
                    title: "Load Failed",
                    message: "Could not load sessions.",
                    retryAction: {}
                )

            case .success, .edge:
                ScrollView {
                    VStack(spacing: 0) {
                        SidebarRow(
                            icon: "message.fill",
                            title: "Blaze Development",
                            subtitle: "Today, 3:45 PM",
                            badge: "Active",
                            badgeVariant: .success,
                            isSelected: selectedSession == "session1"
                        ) { selectedSession = "session1" }

                        SidebarRow(
                            icon: "message",
                            title: "API Integration",
                            subtitle: "Yesterday",
                            isSelected: selectedSession == "session2"
                        ) { selectedSession = "session2" }

                        SidebarRow(
                            icon: "message",
                            title: "Bug Fix #123",
                            subtitle: "2 days ago",
                            isSelected: selectedSession == "session3"
                        ) { selectedSession = "session3" }
                    }
                    .padding(DSSpacing.sm)
                }
            }
        }
        .frame(width: 280, height: 400)
        .background(Color.ds.bg1)
    }
}
