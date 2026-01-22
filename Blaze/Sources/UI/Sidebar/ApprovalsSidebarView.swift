import SwiftUI

// MARK: - Approvals Sidebar View

/// Tab 15: Pending tool approvals queue sidebar.
///
/// **Phase 2 Spec:**
/// - Pending tool approvals queue
/// - Show: Tool name, arguments preview, risk level
/// - Actions: Approve, Deny, Approve All Similar
/// - History of recent approvals/denials
/// - Trust mode indicator
struct ApprovalsSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var pendingApprovals: [ToolApproval] = []
    @State private var approvalHistory: [ToolApproval] = []
    @State private var showHistory: Bool = false
    @State private var selectedApproval: ToolApproval?
    @State private var showDetailsSheet: Bool = false
    @State private var showTrustConfirmation: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with trust mode indicator
            headerView

            Divider()

            // Tab selector: Pending | History
            tabSelector

            Divider()

            // Content based on selected tab
            if showHistory {
                historyView
            } else {
                pendingView
            }
        }
        .task {
            await loadApprovals()
        }
        .sheet(isPresented: $showDetailsSheet) {
            if let approval = selectedApproval {
                ApprovalDetailsSheet(
                    approval: approval,
                    onApprove: {
                        approveApproval(approval, approveAll: false)
                    },
                    onApproveAll: {
                        approveApproval(approval, approveAll: true)
                    },
                    onDeny: {
                        denyApproval(approval)
                    },
                    onDismiss: {
                        showDetailsSheet = false
                    }
                )
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack {
                Label("Approvals", systemImage: "checkmark.shield.fill")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Pending count badge
                if !pendingApprovals.isEmpty {
                    Text("\(pendingApprovals.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.ds.warning)
                        .clipShape(Capsule())
                }

                // Refresh button
                Button {
                    Task {
                        await loadApprovals()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Trust mode indicator
            trustModeIndicator
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    private var trustModeIndicator: some View {
        let targetSessionId = sessionId ?? appState.currentSessionId
        let session = appState.sessions.first { $0.id == targetSessionId }
        let trustMode = session?.trustMode ?? .prompt

        return HStack(spacing: DSSpacing.xs) {
            Image(systemName: trustMode.sidebarIcon)
                .font(.system(size: 10))
                .foregroundStyle(trustMode.sidebarColor)

            Text(trustMode.displayName)
                .dsTextStyle(.micro, color: trustMode.sidebarColor)

            Spacer()

            // Quick toggle to unrestricted mode
            if trustMode != .unrestricted {
                Button {
                    showTrustConfirmation = true
                } label: {
                    Text("Enable Trust")
                        .dsTextStyle(.micro, color: .ds.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(trustMode.sidebarColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .confirmationDialog(
            "Enable Unrestricted Mode?",
            isPresented: $showTrustConfirmation,
            titleVisibility: .visible
        ) {
            Button("Enable Trust", role: .destructive) {
                enableUnrestrictedMode()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("In unrestricted mode, all tool calls will be auto-approved without review. This is recommended only for trusted projects.")
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Pending", count: pendingApprovals.count, isSelected: !showHistory) {
                withAnimation { showHistory = false }
            }

            tabButton(title: "History", count: approvalHistory.count, isSelected: showHistory) {
                withAnimation { showHistory = true }
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    private func tabButton(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xxs) {
                Text(title)
                    .dsTextStyle(.caption, color: isSelected ? .ds.foreground : .ds.tertiary)
                    .fontWeight(isSelected ? .medium : .regular)

                if count > 0 {
                    Text("\(count)")
                        .dsTextStyle(.micro, color: isSelected ? .ds.accent : .ds.tertiary)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(isSelected ? Color.ds.surface.opacity(0.5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pending View

    private var pendingView: some View {
        Group {
            if pendingApprovals.isEmpty {
                emptyPendingView
            } else {
                pendingListView
            }
        }
    }

    private var emptyPendingView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.positive)

            Text("No Pending Approvals")
                .dsTextStyle(.subtitle)

            Text("All tool calls have been approved or the session is in trusted mode")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pendingListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Approve all button
                if pendingApprovals.count > 1 {
                    Button {
                        approveAllPending()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.ds.positive)

                            Text("Approve All (\(pendingApprovals.count))")
                                .dsTextStyle(.caption, color: .ds.positive)

                            Spacer()
                        }
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xs)
                        .background(Color.ds.positive.opacity(0.1))
                    }
                    .buttonStyle(.plain)

                    Divider()
                }

                ForEach(pendingApprovals) { approval in
                    ApprovalRow(
                        approval: approval,
                        isPending: true,
                        onTap: {
                            selectedApproval = approval
                            showDetailsSheet = true
                        },
                        onApprove: {
                            approveApproval(approval, approveAll: false)
                        },
                        onDeny: {
                            denyApproval(approval)
                        }
                    )

                    if approval.id != pendingApprovals.last?.id {
                        Divider()
                            .padding(.leading, DSSpacing.lg)
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    // MARK: - History View

    private var historyView: some View {
        Group {
            if approvalHistory.isEmpty {
                emptyHistoryView
            } else {
                historyListView
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("No History")
                .dsTextStyle(.subtitle)

            Text("Approval decisions will appear here")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(approvalHistory) { approval in
                    ApprovalRow(
                        approval: approval,
                        isPending: false,
                        onTap: {
                            selectedApproval = approval
                            showDetailsSheet = true
                        },
                        onApprove: {},
                        onDeny: {}
                    )

                    if approval.id != approvalHistory.last?.id {
                        Divider()
                            .padding(.leading, DSSpacing.lg)
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        }
    }

    // MARK: - Actions

    private func enableUnrestrictedMode() {
        // Use passed sessionId or fall back to current session
        let targetSessionId = sessionId ?? appState.currentSessionId
        if let targetSessionId = targetSessionId {
            appState.updateSessionTrustMode(targetSessionId, trustMode: .unrestricted)
        }
    }

    private func loadApprovals() async {
        // Generate demo data
        pendingApprovals = [
            ToolApproval(
                toolName: "Write",
                arguments: ["file_path": "/src/components/Button.swift", "content": "..."],
                riskLevel: .medium,
                requestedAt: Date().addingTimeInterval(-30)
            ),
            ToolApproval(
                toolName: "Bash",
                arguments: ["command": "npm install lodash"],
                riskLevel: .high,
                requestedAt: Date().addingTimeInterval(-60)
            ),
            ToolApproval(
                toolName: "Edit",
                arguments: ["file_path": "/src/App.swift", "old_string": "...", "new_string": "..."],
                riskLevel: .low,
                requestedAt: Date().addingTimeInterval(-90)
            )
        ]

        approvalHistory = [
            ToolApproval(
                toolName: "Read",
                arguments: ["file_path": "/src/config.json"],
                riskLevel: .low,
                requestedAt: Date().addingTimeInterval(-300),
                decision: .approved,
                decidedAt: Date().addingTimeInterval(-295)
            ),
            ToolApproval(
                toolName: "Bash",
                arguments: ["command": "rm -rf /tmp/cache"],
                riskLevel: .high,
                requestedAt: Date().addingTimeInterval(-600),
                decision: .denied,
                decidedAt: Date().addingTimeInterval(-590)
            ),
            ToolApproval(
                toolName: "Write",
                arguments: ["file_path": "/src/utils.swift"],
                riskLevel: .medium,
                requestedAt: Date().addingTimeInterval(-900),
                decision: .approved,
                decidedAt: Date().addingTimeInterval(-890)
            )
        ]
    }

    private func approveApproval(_ approval: ToolApproval, approveAll: Bool) {
        var updated = approval
        updated.decision = .approved
        updated.decidedAt = Date()

        pendingApprovals.removeAll { $0.id == approval.id }
        approvalHistory.insert(updated, at: 0)

        // Notify approval
        NotificationCenter.default.post(
            name: .toolApprovalDecision,
            object: nil,
            userInfo: [
                "approvalId": approval.id,
                "decision": "approved",
                "approveAllSimilar": approveAll
            ]
        )

        showDetailsSheet = false
    }

    private func denyApproval(_ approval: ToolApproval) {
        var updated = approval
        updated.decision = .denied
        updated.decidedAt = Date()

        pendingApprovals.removeAll { $0.id == approval.id }
        approvalHistory.insert(updated, at: 0)

        // Notify denial
        NotificationCenter.default.post(
            name: .toolApprovalDecision,
            object: nil,
            userInfo: [
                "approvalId": approval.id,
                "decision": "denied"
            ]
        )

        showDetailsSheet = false
    }

    private func approveAllPending() {
        for approval in pendingApprovals {
            var updated = approval
            updated.decision = .approved
            updated.decidedAt = Date()
            approvalHistory.insert(updated, at: 0)
        }
        pendingApprovals.removeAll()
    }
}

// MARK: - Tool Approval

struct ToolApproval: Identifiable {
    let id = UUID()
    let toolName: String
    let arguments: [String: String]
    let riskLevel: ApprovalRiskLevel
    let requestedAt: Date
    var decision: ApprovalDecision?
    var decidedAt: Date?
}

// MARK: - Approval Risk Level

enum ApprovalRiskLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var icon: String {
        switch self {
        case .low: return "shield"
        case .medium: return "shield.lefthalf.filled"
        case .high: return "exclamationmark.shield"
        }
    }

    var color: Color {
        switch self {
        case .low: return .ds.positive
        case .medium: return .ds.warning
        case .high: return .ds.negative
        }
    }
}

// MARK: - Approval Decision

enum ApprovalDecision: String {
    case approved = "Approved"
    case denied = "Denied"

    var icon: String {
        switch self {
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .approved: return .ds.positive
        case .denied: return .ds.negative
        }
    }
}

// MARK: - Trust Mode UI Extension

extension TrustMode {
    /// Icon for trust mode display in sidebar
    var sidebarIcon: String {
        switch self {
        case .lockedDown: return "lock.shield"
        case .prompt: return "shield.lefthalf.filled"
        case .allowlisted: return "shield.checkered"
        case .unrestricted: return "checkmark.shield.fill"
        }
    }

    /// Color for trust mode display in sidebar
    var sidebarColor: Color {
        switch self {
        case .lockedDown: return .ds.info
        case .prompt: return .ds.warning
        case .allowlisted: return .ds.accent
        case .unrestricted: return .ds.positive
        }
    }
}

// MARK: - Approval Row

struct ApprovalRow: View {
    let approval: ToolApproval
    let isPending: Bool
    let onTap: () -> Void
    let onApprove: () -> Void
    let onDeny: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.sm) {
                // Risk indicator
                Image(systemName: approval.riskLevel.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(approval.riskLevel.color)
                    .frame(width: 16)

                // Approval info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(approval.toolName)
                            .dsTextStyle(.caption)
                            .fontWeight(.medium)

                        // Decision badge (for history)
                        if let decision = approval.decision {
                            HStack(spacing: 2) {
                                Image(systemName: decision.icon)
                                    .font(.system(size: 8))
                                Text(decision.rawValue)
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(decision.color)
                        }
                    }

                    // Arguments preview
                    Text(argumentsPreview)
                        .dsTextStyle(.micro, color: .ds.tertiary)
                        .lineLimit(1)

                    // Timestamp
                    Text(formatRelativeTime(isPending ? approval.requestedAt : (approval.decidedAt ?? approval.requestedAt)))
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }

                Spacer()

                // Quick action buttons (for pending)
                if isPending && isHovered {
                    HStack(spacing: DSSpacing.xxs) {
                        Button(action: onApprove) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.ds.positive)
                        }
                        .buttonStyle(.plain)
                        .help("Approve")

                        Button(action: onDeny) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.ds.negative)
                        }
                        .buttonStyle(.plain)
                        .help("Deny")
                    }
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.ds.surface.opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
    }

    private var argumentsPreview: String {
        let args = approval.arguments.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return String(args.prefix(50)) + (args.count > 50 ? "..." : "")
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Approval Details Sheet

struct ApprovalDetailsSheet: View {
    let approval: ToolApproval
    let onApprove: () -> Void
    let onApproveAll: () -> Void
    let onDeny: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Header
            HStack {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: approval.riskLevel.icon)
                        .foregroundStyle(approval.riskLevel.color)

                    Text(approval.toolName)
                        .dsTextStyle(.subtitle)
                }

                Spacer()

                // Risk badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(approval.riskLevel.color)
                        .frame(width: 6, height: 6)
                    Text(approval.riskLevel.rawValue + " Risk")
                        .dsTextStyle(.micro, color: approval.riskLevel.color)
                }
                .padding(.horizontal, DSSpacing.xs)
                .padding(.vertical, 2)
                .background(approval.riskLevel.color.opacity(0.1))
                .clipShape(Capsule())

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Arguments
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Arguments")
                    .dsTextStyle(.caption, color: .ds.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        ForEach(Array(approval.arguments.keys.sorted()), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key)
                                    .dsTextStyle(.micro, color: .ds.tertiary)

                                Text(approval.arguments[key] ?? "")
                                    .dsTextStyle(.monoSmall)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(DSSpacing.xs)
                            .background(Color.ds.surface.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Divider()

            // Actions
            HStack {
                Button(action: onDeny) {
                    Label("Deny", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.ds.negative)

                Spacer()

                Button(action: onApproveAll) {
                    Label("Approve All Similar", systemImage: "checkmark.circle.badge.checkmark")
                }
                .buttonStyle(.bordered)

                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 450, height: 400)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toolApprovalDecision = Notification.Name("toolApprovalDecision")
}

// MARK: - Previews

#Preview("Approvals Sidebar") {
    ApprovalsSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Approvals Sidebar - Empty") {
    ApprovalsSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
