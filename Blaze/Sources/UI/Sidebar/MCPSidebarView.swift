import SwiftUI

// MARK: - MCP Sidebar View

/// Tab 9: MCP (Model Context Protocol) sidebar showing configured servers and their status.
///
/// **Phase 2 Spec:**
/// - List configured MCP servers
/// - Status indicators: Connected (green) / Disconnected (gray) / Error (red)
/// - Show server name, tool count
/// - Actions: Reconnect button, View logs
struct MCPSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var servers: [MCPServerInfo] = []
    @State private var isLoading: Bool = false
    @State private var error: String?
    @State private var expandedServers: Set<String> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with refresh
            headerView

            Divider()

            // Server list
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if servers.isEmpty {
                emptyView
            } else {
                serverListView
            }
        }
        .task {
            await loadMCPServers()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("MCP Servers", systemImage: "server.rack")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Status summary
            if !servers.isEmpty {
                HStack(spacing: DSSpacing.xs) {
                    let connected = servers.filter { $0.status == .connected }.count
                    Text("\(connected)/\(servers.count)")
                        .dsTextStyle(.monoSmall, color: connected == servers.count ? .ds.positive : .ds.warning)

                    Circle()
                        .fill(connected == servers.count ? Color.ds.positive : Color.ds.warning)
                        .frame(width: 6, height: 6)
                }
            }

            // Refresh button
            Button {
                Task {
                    await loadMCPServers()
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading MCP servers...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.warning)

            Text("Failed to Load")
                .dsTextStyle(.subtitle)

            Text(message)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadMCPServers()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "server.rack")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No MCP Servers")
                .dsTextStyle(.subtitle)

            Text("Configure MCP servers in your settings.json to enable additional tools")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Button {
                // Open MCP configuration docs
                if let url = URL(string: "https://modelcontextprotocol.io/") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Learn More", systemImage: "book")
            }
            .buttonStyle(.bordered)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Server List View

    private var serverListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(servers) { server in
                    MCPServerRow(
                        server: server,
                        isExpanded: expandedServers.contains(server.id),
                        onToggle: {
                            toggleServer(server.id)
                        },
                        onReconnect: {
                            Task {
                                await reconnectServer(server.id)
                            }
                        },
                        onViewLogs: {
                            viewServerLogs(server.id)
                        }
                    )

                    if server.id != servers.last?.id {
                        Divider()
                            .padding(.leading, DSSpacing.lg + DSSpacing.sm)
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    // MARK: - Actions

    private func toggleServer(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedServers.contains(id) {
                expandedServers.remove(id)
            } else {
                expandedServers.insert(id)
            }
        }
    }

    private func reconnectServer(_ id: String) async {
        // Mark as reconnecting
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].status = .connecting
        }

        // Simulate reconnection (actual implementation would call MCP runtime)
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Update status
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].status = .connected
            servers[index].lastConnected = Date()
        }
    }

    private func viewServerLogs(_ id: String) {
        // TODO: Open logs view for this server
        print("[MCP] View logs for server: \(id)")
    }

    // MARK: - Load MCP Servers

    private func loadMCPServers() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Try to read MCP configuration from settings.json
        guard let session = appState.sessions.first(where: { $0.id == sessionId }),
              let projectPath = session.effectiveWorkingDirectory else {
            // No project path, show empty state
            servers = []
            return
        }

        let settingsPath = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")

        // Check if settings.json exists
        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            // No settings file, generate mock data for demo
            servers = generateDemoServers()
            return
        }

        do {
            let data = try Data(contentsOf: settingsPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let mcpServers = json["mcpServers"] as? [String: Any] {
                servers = mcpServers.map { name, config in
                    let configDict = config as? [String: Any] ?? [:]
                    return MCPServerInfo(
                        id: name,
                        name: name,
                        command: configDict["command"] as? String ?? "unknown",
                        args: configDict["args"] as? [String] ?? [],
                        status: .connected, // Assume connected for now
                        toolCount: Int.random(in: 3...15), // Demo value
                        lastConnected: Date()
                    )
                }.sorted { $0.name < $1.name }
            } else {
                servers = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func generateDemoServers() -> [MCPServerInfo] {
        // Demo servers for UI preview
        [
            MCPServerInfo(
                id: "filesystem",
                name: "filesystem",
                command: "npx",
                args: ["-y", "@anthropic/mcp-server-filesystem"],
                status: .connected,
                toolCount: 8,
                lastConnected: Date()
            ),
            MCPServerInfo(
                id: "github",
                name: "github",
                command: "npx",
                args: ["-y", "@anthropic/mcp-server-github"],
                status: .connected,
                toolCount: 12,
                lastConnected: Date().addingTimeInterval(-3600)
            ),
            MCPServerInfo(
                id: "postgres",
                name: "postgres",
                command: "npx",
                args: ["-y", "@anthropic/mcp-server-postgres"],
                status: .disconnected,
                toolCount: 5,
                lastConnected: nil
            )
        ]
    }
}

// MARK: - MCP Server Info

struct MCPServerInfo: Identifiable {
    let id: String
    let name: String
    let command: String
    let args: [String]
    var status: MCPServerStatus
    let toolCount: Int
    var lastConnected: Date?
}

enum MCPServerStatus: String {
    case connected = "Connected"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case error = "Error"

    var color: Color {
        switch self {
        case .connected: return .ds.positive
        case .connecting: return .ds.info
        case .disconnected: return .ds.tertiary
        case .error: return .ds.negative
        }
    }

    var icon: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.trianglehead.2.clockwise"
        case .disconnected: return "circle"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - MCP Server Row

struct MCPServerRow: View {
    let server: MCPServerInfo
    let isExpanded: Bool
    let onToggle: () -> Void
    let onReconnect: () -> Void
    let onViewLogs: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: DSSpacing.sm) {
                    // Status indicator
                    statusIndicator

                    // Server info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .dsTextStyle(.body)
                            .fontWeight(.medium)

                        HStack(spacing: DSSpacing.xs) {
                            Text("\(server.toolCount) tools")
                                .dsTextStyle(.micro, color: .ds.tertiary)

                            if let lastConnected = server.lastConnected {
                                Text("•")
                                    .dsTextStyle(.micro, color: .ds.tertiary)

                                Text(formatRelativeTime(lastConnected))
                                    .dsTextStyle(.micro, color: .ds.tertiary)
                            }
                        }
                    }

                    Spacer()

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)
            .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
            .onHover { isHovered = $0 }

            // Expanded details
            if isExpanded {
                expandedContent
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if server.status == .connecting {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: server.status.icon)
                .font(.system(size: 12))
                .foregroundStyle(server.status.color)
                .frame(width: 16)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Command info
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Command")
                    .dsTextStyle(.micro, color: .ds.tertiary)

                Text("\(server.command) \(server.args.joined(separator: " "))")
                    .dsTextStyle(.monoSmall)
                    .lineLimit(2)
            }

            // Actions
            HStack(spacing: DSSpacing.sm) {
                Button {
                    onReconnect()
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .disabled(server.status == .connecting)

                Button {
                    onViewLogs()
                } label: {
                    Label("Logs", systemImage: "doc.text")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.leading, DSSpacing.lg)
        .padding(.bottom, DSSpacing.sm)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview("MCP Sidebar - Connected") {
    MCPSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 500)
        .background(Color.ds.bg0)
}

#Preview("MCP Sidebar - Empty") {
    MCPSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
