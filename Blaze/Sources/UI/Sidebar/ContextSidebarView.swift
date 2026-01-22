import SwiftUI

// MARK: - Context Sidebar View (Enhanced)

/// Tab 16: Context window and included files sidebar.
///
/// **Phase 2 Spec:**
/// - Show current context window usage
/// - List included files/context
/// - CLAUDE.md preview
/// - Actions: Add file to context, Remove from context
/// - Show context breakdown by source
struct EnhancedContextSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @EnvironmentObject var appState: AppState
    @State private var contextFiles: [ContextFile] = []
    @State private var isLoading: Bool = false
    @State private var expandedSections: Set<ContextSection> = [.claudeMd, .files]
    @State private var claudeMdContent: String?
    @State private var showAddFileSheet: Bool = false

    // MARK: - Computed Properties

    private var session: Session? {
        guard let id = sessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    private var latestTokenUsage: TokenUsage? {
        for envelope in events.reversed() {
            if case .tokenUsage(let usage) = envelope.event {
                return usage
            }
        }
        return nil
    }

    private var contextBreakdown: ContextBreakdown {
        var breakdown = ContextBreakdown()

        // CLAUDE.md tokens
        if let content = claudeMdContent {
            breakdown.claudeMd = estimateTokens(content)
        }

        // Files tokens
        for file in contextFiles {
            breakdown.files += file.estimatedTokens
        }

        // Conversation tokens (from messages)
        if let messages = session?.messages {
            for message in messages {
                breakdown.conversation += estimateTokens(message.content)
            }
        }

        // Tool outputs from events
        for envelope in events {
            switch envelope.event {
            case .toolCallComplete(let complete):
                if let output = complete.output {
                    breakdown.toolOutputs += estimateTokens(output)
                }
            case .toolResult(let result):
                if let output = result.output {
                    breakdown.toolOutputs += estimateTokens(output)
                }
            default:
                break
            }
        }

        return breakdown
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with usage summary
            headerView

            Divider()

            // Content sections
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Context usage overview
                    usageOverviewSection

                    Divider()
                        .padding(.vertical, DSSpacing.xs)

                    // CLAUDE.md section
                    claudeMdSection

                    // Context files section
                    contextFilesSection

                    // Breakdown section
                    breakdownSection
                }
                .padding(.vertical, DSSpacing.xs)
            }
        }
        .task {
            await loadContext()
        }
        .sheet(isPresented: $showAddFileSheet) {
            AddContextFileSheet(
                projectPath: session?.effectiveWorkingDirectory,
                onAdd: { filePath in
                    addFileToContext(filePath)
                },
                onCancel: {
                    showAddFileSheet = false
                }
            )
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("Context", systemImage: "doc.text.magnifyingglass")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Add file button
            Button {
                showAddFileSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ds.accent)
            }
            .buttonStyle(.plain)
            .help("Add file to context")

            // Refresh button
            Button {
                Task {
                    await loadContext()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Usage Overview Section

    private var usageOverviewSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Token usage from CLI
            if let usage = latestTokenUsage {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Usage")
                            .dsTextStyle(.micro, color: .ds.tertiary)

                        Text(formatTokens(usage.totalTokens))
                            .dsTextStyle(.subtitle, color: .ds.foreground)
                    }

                    Spacer()

                    // Context health indicator
                    contextHealthBadge(usage: usage)
                }
                .padding(DSSpacing.sm)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .low)
            } else {
                // Estimated usage
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimated Usage")
                            .dsTextStyle(.micro, color: .ds.tertiary)

                        Text(formatTokens(contextBreakdown.total))
                            .dsTextStyle(.subtitle, color: .ds.foreground)
                    }

                    Spacer()

                    Text("No CLI data")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
                .padding(DSSpacing.sm)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .low)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    private func contextHealthBadge(usage: TokenUsage) -> some View {
        let percentage = Double(usage.totalTokens) / 200000.0 // Assuming 200k context
        let status: (String, Color) = {
            if percentage > 0.9 {
                return ("Critical", .ds.negative)
            } else if percentage > 0.7 {
                return ("Warning", .ds.warning)
            } else {
                return ("Healthy", .ds.positive)
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(status.1)
                .frame(width: 6, height: 6)

            Text(status.0)
                .dsTextStyle(.micro, color: status.1)
        }
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 2)
        .background(status.1.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - CLAUDE.md Section

    private var claudeMdSection: some View {
        collapsibleSection(
            section: .claudeMd,
            title: "CLAUDE.md",
            icon: "doc.text.fill",
            count: claudeMdContent != nil ? 1 : 0
        ) {
            if let content = claudeMdContent {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    // Preview
                    Text(content.prefix(300) + (content.count > 300 ? "..." : ""))
                        .dsTextStyle(.monoSmall, color: .ds.secondary)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSSpacing.xs)
                        .background(Color.ds.surface.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))

                    // Stats
                    HStack(spacing: DSSpacing.md) {
                        Label("\(content.count) chars", systemImage: "textformat.size")
                        Label("~\(estimateTokens(content)) tokens", systemImage: "number")
                    }
                    .dsTextStyle(.micro, color: .ds.tertiary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.leading, DSSpacing.lg)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.ds.warning)

                    Text("No CLAUDE.md found in project")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.leading, DSSpacing.lg)
            }
        }
    }

    // MARK: - Context Files Section

    private var contextFilesSection: some View {
        collapsibleSection(
            section: .files,
            title: "Included Files",
            icon: "doc.on.doc",
            count: contextFiles.count
        ) {
            if contextFiles.isEmpty {
                Text("No files added to context")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.leading, DSSpacing.lg)
            } else {
                ForEach(contextFiles) { file in
                    ContextFileRow(
                        file: file,
                        onRemove: {
                            removeFileFromContext(file)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        collapsibleSection(
            section: .breakdown,
            title: "Token Breakdown",
            icon: "chart.pie",
            count: nil
        ) {
            VStack(spacing: DSSpacing.xs) {
                ContextBreakdownRow(
                    label: "CLAUDE.md",
                    tokens: contextBreakdown.claudeMd,
                    color: .ds.accent
                )
                ContextBreakdownRow(
                    label: "Context Files",
                    tokens: contextBreakdown.files,
                    color: .ds.info
                )
                ContextBreakdownRow(
                    label: "Conversation",
                    tokens: contextBreakdown.conversation,
                    color: .ds.positive
                )
                ContextBreakdownRow(
                    label: "Tool Outputs",
                    tokens: contextBreakdown.toolOutputs,
                    color: .ds.warning
                )

                Divider()

                ContextBreakdownRow(
                    label: "Total",
                    tokens: contextBreakdown.total,
                    color: .ds.foreground,
                    bold: true
                )
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
        }
    }

    // MARK: - Collapsible Section Helper

    private func collapsibleSection<Content: View>(
        section: ContextSection,
        title: String,
        icon: String,
        count: Int?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleSection(section)
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 12)

                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.secondary)

                    Text(title)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .fontWeight(.medium)

                    if let count = count {
                        Text("(\(count))")
                            .dsTextStyle(.micro, color: .ds.tertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(Color.ds.surface.opacity(0.2))
            }
            .buttonStyle(.plain)

            if expandedSections.contains(section) {
                content()
                    .padding(.vertical, DSSpacing.xs)
            }
        }
    }

    // MARK: - Actions

    private func loadContext() async {
        isLoading = true
        defer { isLoading = false }

        // Load CLAUDE.md
        if let projectPath = session?.effectiveWorkingDirectory {
            let claudeMdPath = URL(fileURLWithPath: projectPath).appendingPathComponent("CLAUDE.md")
            if FileManager.default.fileExists(atPath: claudeMdPath.path) {
                claudeMdContent = try? String(contentsOf: claudeMdPath, encoding: .utf8)
            }
        }

        // Generate demo context files
        contextFiles = [
            ContextFile(
                path: "/src/Models/User.swift",
                type: .swift,
                estimatedTokens: 450,
                addedAt: Date().addingTimeInterval(-300)
            ),
            ContextFile(
                path: "/src/Services/APIClient.swift",
                type: .swift,
                estimatedTokens: 1200,
                addedAt: Date().addingTimeInterval(-200)
            ),
            ContextFile(
                path: "/package.json",
                type: .json,
                estimatedTokens: 150,
                addedAt: Date().addingTimeInterval(-100)
            )
        ]
    }

    private func toggleSection(_ section: ContextSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func addFileToContext(_ filePath: String) {
        let fileType = ContextFileType(extension: (filePath as NSString).pathExtension)
        let newFile = ContextFile(
            path: filePath,
            type: fileType,
            estimatedTokens: 500, // Estimate
            addedAt: Date()
        )
        contextFiles.append(newFile)
        showAddFileSheet = false
    }

    private func removeFileFromContext(_ file: ContextFile) {
        contextFiles.removeAll { $0.id == file.id }
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        return text.count / 4
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Context Section

enum ContextSection: String, CaseIterable {
    case claudeMd = "claudeMd"
    case files = "files"
    case breakdown = "breakdown"
}

// MARK: - Context File

struct ContextFile: Identifiable {
    let id = UUID()
    let path: String
    let type: ContextFileType
    let estimatedTokens: Int
    let addedAt: Date

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

// MARK: - Context File Type

enum ContextFileType: String {
    case swift = "swift"
    case typescript = "ts"
    case javascript = "js"
    case python = "py"
    case json = "json"
    case markdown = "md"
    case other = "other"

    init(extension ext: String) {
        switch ext.lowercased() {
        case "swift": self = .swift
        case "ts", "tsx": self = .typescript
        case "js", "jsx": self = .javascript
        case "py": self = .python
        case "json": self = .json
        case "md", "markdown": self = .markdown
        default: self = .other
        }
    }

    var icon: String {
        switch self {
        case .swift: return "swift"
        case .typescript, .javascript: return "chevron.left.forwardslash.chevron.right"
        case .python: return "text.alignleft"
        case .json: return "curlybraces"
        case .markdown: return "doc.text"
        case .other: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .swift: return .orange
        case .typescript: return .blue
        case .javascript: return .yellow
        case .python: return .green
        case .json: return .purple
        case .markdown: return .gray
        case .other: return .ds.tertiary
        }
    }
}

// MARK: - Context Breakdown

struct ContextBreakdown {
    var claudeMd: Int = 0
    var files: Int = 0
    var conversation: Int = 0
    var toolOutputs: Int = 0

    var total: Int {
        claudeMd + files + conversation + toolOutputs
    }
}

// MARK: - Context File Row

struct ContextFileRow: View {
    let file: ContextFile
    let onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            // File type icon
            Image(systemName: file.type.icon)
                .font(.system(size: 11))
                .foregroundStyle(file.type.color)
                .frame(width: 14)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .dsTextStyle(.caption)
                    .lineLimit(1)

                Text("~\(file.estimatedTokens) tokens")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }

            Spacer()

            // Remove button (visible on hover)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.negative)
                }
                .buttonStyle(.plain)
                .help("Remove from context")
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.leading, DSSpacing.lg)
        .padding(.vertical, DSSpacing.xxs)
        .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Context Breakdown Row

struct ContextBreakdownRow: View {
    let label: String
    let tokens: Int
    let color: Color
    var bold: Bool = false

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .dsTextStyle(bold ? .body : .caption, color: bold ? .ds.foreground : .ds.secondary)
                .fontWeight(bold ? .medium : .regular)

            Spacer()

            Text(formatTokens(tokens))
                .dsTextStyle(.monoSmall, color: bold ? .ds.foreground : .ds.secondary)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Add Context File Sheet

struct AddContextFileSheet: View {
    let projectPath: String?
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    @State private var filePath: String = ""
    @State private var recentFiles: [String] = []

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Header
            HStack {
                Text("Add File to Context")
                    .dsTextStyle(.subtitle)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // File path input
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("File Path")
                    .dsTextStyle(.caption, color: .ds.secondary)

                HStack {
                    TextField("Enter file path...", text: $filePath)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        // Open file picker
                        openFilePicker()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Recent files
            if !recentFiles.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Recent Files")
                        .dsTextStyle(.caption, color: .ds.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(recentFiles, id: \.self) { file in
                                Button {
                                    filePath = file
                                } label: {
                                    HStack {
                                        Image(systemName: "doc")
                                            .foregroundStyle(Color.ds.tertiary)
                                        Text(file)
                                            .dsTextStyle(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, DSSpacing.sm)
                                    .padding(.vertical, DSSpacing.xs)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(Color.ds.surface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                }
            }

            Spacer()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button("Add") {
                    onAdd(filePath)
                }
                .buttonStyle(.borderedProminent)
                .disabled(filePath.isEmpty)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 450, height: 350)
        .onAppear {
            loadRecentFiles()
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if let projectPath = projectPath {
            panel.directoryURL = URL(fileURLWithPath: projectPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
        }
    }

    private func loadRecentFiles() {
        // Demo recent files
        recentFiles = [
            "/src/App.swift",
            "/src/Models/User.swift",
            "/src/Services/APIClient.swift"
        ]
    }
}

// MARK: - Previews

#Preview("Enhanced Context Sidebar") {
    EnhancedContextSidebarView(sessionId: UUID(), events: [])
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Enhanced Context Sidebar - Empty") {
    EnhancedContextSidebarView(sessionId: nil, events: [])
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
