import SwiftUI

// MARK: - Logs Sidebar View

/// Tab 11: Unified log viewer for app logs, CLI stderr, and hook output.
///
/// **Phase 2 Spec:**
/// - Unified log viewer: App logs + CLI stderr + Hook output
/// - Filters: Level (debug/info/warn/error), Source (app/cli/hooks)
/// - Auto-scroll with pause on hover
/// - Timestamp + level + source + message format
/// - Clear logs button
struct LogsSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var logs: [LogEntry] = []
    @State private var filteredLogs: [LogEntry] = []
    @State private var selectedLevel: LogLevel? = nil
    @State private var selectedSource: LogSource? = nil
    @State private var searchText: String = ""
    @State private var isAutoScrollEnabled: Bool = true
    @State private var isPaused: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with filters
            headerView

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Log list
            if filteredLogs.isEmpty {
                emptyView
            } else {
                logListView
            }

            // Footer with stats
            footerView
        }
        .task {
            await loadLogs()
        }
        .onChange(of: selectedLevel) { _, _ in applyFilters() }
        .onChange(of: selectedSource) { _, _ in applyFilters() }
        .onChange(of: searchText) { _, _ in applyFilters() }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("Logs", systemImage: "doc.text.fill")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Auto-scroll toggle
            Button {
                isAutoScrollEnabled.toggle()
            } label: {
                Image(systemName: isAutoScrollEnabled ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isAutoScrollEnabled ? Color.ds.accent : Color.ds.tertiary)
            }
            .buttonStyle(.plain)
            .help(isAutoScrollEnabled ? "Auto-scroll enabled" : "Auto-scroll disabled")

            // Clear logs
            Button {
                clearLogs()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
            .help("Clear logs")
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: DSSpacing.xs) {
            // Level filter (scrollable for narrow sidebars)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.xs) {
                    Text("Level:")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                        .fixedSize()

                    ForEach([nil] + LogLevel.allCases, id: \.self) { level in
                        FilterButton(
                            label: level?.rawValue ?? "All",
                            isSelected: selectedLevel == level,
                            color: level?.color ?? .ds.secondary
                        ) {
                            selectedLevel = level
                        }
                        .fixedSize()
                    }
                }
            }

            // Source filter (scrollable for narrow sidebars)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.xs) {
                    Text("Source:")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                        .fixedSize()

                    ForEach([nil] + LogSource.allCases, id: \.self) { source in
                        FilterButton(
                            label: source?.rawValue ?? "All",
                            isSelected: selectedSource == source,
                            color: source?.color ?? .ds.secondary
                        ) {
                            selectedSource = source
                        }
                        .fixedSize()
                    }
                }
            }

            // Search
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.tertiary)

                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.ds.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxs)
            .background(Color.ds.surface.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Logs")
                .dsTextStyle(.subtitle)

            if selectedLevel != nil || selectedSource != nil || !searchText.isEmpty {
                Text("No logs match the current filters")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Button("Clear Filters") {
                    selectedLevel = nil
                    selectedSource = nil
                    searchText = ""
                }
                .buttonStyle(.bordered)
            } else {
                Text("Logs will appear here as the session runs")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Log List View

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredLogs) { log in
                        LogEntryRow(log: log)
                            .id(log.id)
                    }
                }
                .padding(.vertical, DSSpacing.xs)
            }
            .onHover { hovering in
                isPaused = hovering
            }
            .onChange(of: filteredLogs.count) { _, _ in
                if isAutoScrollEnabled && !isPaused,
                   let lastLog = filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            // Log count
            Text("\(filteredLogs.count) of \(logs.count) entries")
                .dsTextStyle(.micro, color: .ds.tertiary)

            Spacer()

            // Error/warning counts
            let errorCount = logs.filter { $0.level == .error }.count
            let warnCount = logs.filter { $0.level == .warn }.count

            if errorCount > 0 {
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.ds.negative)
                        .frame(width: 6, height: 6)

                    Text("\(errorCount)")
                        .dsTextStyle(.micro, color: .ds.negative)
                }
            }

            if warnCount > 0 {
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.ds.warning)
                        .frame(width: 6, height: 6)

                    Text("\(warnCount)")
                        .dsTextStyle(.micro, color: .ds.warning)
                }
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Color.ds.surface.opacity(0.2))
    }

    // MARK: - Actions

    private func applyFilters() {
        filteredLogs = logs.filter { log in
            // Level filter
            if let level = selectedLevel, log.level != level {
                return false
            }

            // Source filter
            if let source = selectedSource, log.source != source {
                return false
            }

            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return log.message.lowercased().contains(searchLower) ||
                       log.source.rawValue.lowercased().contains(searchLower)
            }

            return true
        }
    }

    private func clearLogs() {
        logs.removeAll()
        filteredLogs.removeAll()
    }

    private func loadLogs() async {
        guard let sessionId = sessionId,
              let logStore = appState.logStore else {
            logs = []
            applyFilters()
            return
        }
        do {
            logs = try await logStore.getLogsForSession(sessionId)
            applyFilters()
        } catch {
            print("[LogsSidebarView] Failed to load logs: \(error)")
        }
    }
}

// MARK: - LogLevel and LogSource Extensions

extension LogLevel {
    var color: Color {
        switch self {
        case .debug: return .ds.tertiary
        case .info: return .ds.info
        case .warn: return .ds.warning
        case .error: return .ds.negative
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    var abbreviation: String {
        switch self {
        case .debug: return "DBG"
        case .info: return "INF"
        case .warn: return "WRN"
        case .error: return "ERR"
        }
    }
}

extension LogSource {
    var color: Color {
        switch self {
        case .app: return .ds.accent
        case .cli: return .purple
        case .hooks: return .ds.positive
        }
    }

    var icon: String {
        switch self {
        case .app: return "app.badge"
        case .cli: return "terminal"
        case .hooks: return "gearshape.2"
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? Color.ds.foreground : color)
                .padding(.horizontal, DSSpacing.xs)
                .padding(.vertical, 2)
                .background(
                    isSelected
                        ? color.opacity(0.2)
                        : Color.ds.surface.opacity(0.3)
                )
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let log: LogEntry

    @State private var isHovered: Bool = false
    @State private var isCopied: Bool = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.xs) {
            // Timestamp
            Text(Self.timeFormatter.string(from: log.timestamp))
                .dsTextStyle(.monoSmall, color: .ds.tertiary)
                .frame(width: 70, alignment: .leading)

            // Level badge
            Text(log.level.abbreviation)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(log.level.color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(log.level.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Source badge
            Text(log.source.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(log.source.color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(log.source.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Message
            Text(log.message)
                .dsTextStyle(.monoSmall)
                .lineLimit(3)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            // Copy button (on hover)
            if isHovered {
                Button {
                    copyLog()
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(isCopied ? Color.ds.positive : Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
    }

    private func copyLog() {
        let formatted = "\(Self.timeFormatter.string(from: log.timestamp)) [\(log.level.abbreviation)] [\(log.source.rawValue)] \(log.message)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formatted, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}

// MARK: - Previews

#Preview("Logs Sidebar") {
    LogsSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 320, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Logs Sidebar - Empty") {
    let view = LogsSidebarView(sessionId: nil)
    return view
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
