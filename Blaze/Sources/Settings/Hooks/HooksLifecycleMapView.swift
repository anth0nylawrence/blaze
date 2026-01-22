import SwiftUI

// MARK: - Hooks Lifecycle Map View

/// Visual lifecycle event map showing hooks attached to each Claude Code event.
/// Displays all 12 hook events as "swimlanes" with badges for attached hooks.
public struct HooksLifecycleMapView: View {
    // MARK: - State

    @State private var installedHooks: [InstalledHookSummary] = []
    @State private var scopeFilter: HookInstallScope? = nil
    @State private var isLoading = false
    @State private var error: String?

    // MARK: - Computed Properties

    /// All 12 Claude Code hook events in lifecycle order
    private let hookEvents: [HookEventInfo] = [
        HookEventInfo(name: "SessionStart", icon: "play.rectangle", description: "Session initialization"),
        HookEventInfo(name: "UserPromptSubmit", icon: "text.bubble", description: "Before processing user input"),
        HookEventInfo(name: "PermissionRequest", icon: "lock.circle", description: "Tool permission requested"),
        HookEventInfo(name: "PreToolUse", icon: "play.circle", description: "Before tool execution"),
        HookEventInfo(name: "PostToolUse", icon: "checkmark.circle", description: "After successful tool execution"),
        HookEventInfo(name: "PostToolUseFailure", icon: "xmark.circle", description: "After failed tool execution"),
        HookEventInfo(name: "Notification", icon: "bell", description: "System notification"),
        HookEventInfo(name: "SubagentStart", icon: "arrow.branch", description: "Subagent spawned"),
        HookEventInfo(name: "SubagentStop", icon: "arrow.merge", description: "Subagent completed"),
        HookEventInfo(name: "PreCompact", icon: "compress", description: "Before context compaction"),
        HookEventInfo(name: "Stop", icon: "stop.circle", description: "Agent stopped"),
        HookEventInfo(name: "SessionEnd", icon: "stop.rectangle", description: "Session terminated")
    ]

    /// Build event lanes with attached hooks
    private var eventLanes: [HookEventLane] {
        hookEvents.map { event in
            let hooksForEvent = filteredHooks.filter { $0.eventName == event.name }
            return HookEventLane(
                id: event.name,
                eventName: event.name,
                eventIcon: event.icon,
                eventDescription: event.description,
                hooks: hooksForEvent
            )
        }
    }

    /// Filtered hooks based on scope filter
    private var filteredHooks: [InstalledHookSummary] {
        guard let filter = scopeFilter else {
            return installedHooks
        }
        return installedHooks.filter { $0.scope == filter }
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Header
                headerView

                // Error banner
                if let error = error {
                    errorBanner(error)
                }

                // Filters
                filterSection

                // Legend
                legendSection

                // Lifecycle map
                if isLoading {
                    loadingView
                } else {
                    lifecycleMapSection
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(Color.ds.bg0)
        .onAppear {
            Task {
                await loadHooks()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Hooks Lifecycle Map")
                .dsTextStyle(.title)

            Text("Visual representation of hooks across Claude Code lifecycle events")
                .dsTextStyle(.body, color: .ds.secondary)
        }
    }

    // MARK: - Filter Section

    @ViewBuilder
    private var filterSection: some View {
        FormSection(
            title: "Filters",
            description: "Filter hooks by installation scope"
        ) {
            HStack(spacing: DSSpacing.md) {
                scopeFilterButton(scope: nil, label: "All")
                scopeFilterButton(scope: .user, label: "User")
                scopeFilterButton(scope: .project, label: "Project")

                Spacer()

                Button {
                    Task {
                        await loadHooks()
                    }
                } label: {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: DSSize.xs))
                        Text("Refresh")
                            .dsTextStyle(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
    }

    @ViewBuilder
    private func scopeFilterButton(scope: HookInstallScope?, label: String) -> some View {
        Button {
            scopeFilter = scope
        } label: {
            Text(label)
                .dsTextStyle(.caption)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
        }
        .buttonStyle(.plain)
        .background(
            scopeFilter == scope ?
                Color.ds.accent.opacity(0.2) :
                Color.ds.surface.opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .strokeBorder(
                    scopeFilter == scope ? Color.ds.accent : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Legend Section

    @ViewBuilder
    private var legendSection: some View {
        FormSection(
            title: "Legend",
            description: "Hook scope indicators"
        ) {
            HStack(spacing: DSSpacing.lg) {
                HStack(spacing: DSSpacing.xs) {
                    Circle()
                        .fill(scopeColor(.user))
                        .frame(width: 12, height: 12)
                    Text("User (Global)")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }

                HStack(spacing: DSSpacing.xs) {
                    Circle()
                        .fill(scopeColor(.project))
                        .frame(width: 12, height: 12)
                    Text("Project")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Lifecycle Map Section

    @ViewBuilder
    private var lifecycleMapSection: some View {
        FormSection(
            title: "Event Lifecycle",
            description: "Hook events in execution order"
        ) {
            VStack(spacing: DSSpacing.sm) {
                ForEach(eventLanes) { lane in
                    eventLaneView(lane)
                }
            }
        }
    }

    // MARK: - Event Lane View

    @ViewBuilder
    private func eventLaneView(_ lane: HookEventLane) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Event header
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: lane.eventIcon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(lane.hooks.isEmpty ? Color.ds.tertiary : Color.ds.accent)
                    .frame(width: DSSize.md)

                VStack(alignment: .leading, spacing: 2) {
                    Text(lane.eventName)
                        .dsTextStyle(.body)

                    Text(lane.eventDescription)
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }

                Spacer()

                // Hook count badge
                if !lane.hooks.isEmpty {
                    Text("\(lane.hooks.count)")
                        .dsTextStyle(.caption)
                        .padding(.horizontal, DSSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.ds.accent.opacity(0.2))
                        .clipShape(Circle())
                }
            }

            // Hook badges
            if lane.hooks.isEmpty {
                Text("No hooks")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(.leading, DSSize.md + DSSpacing.sm)
            } else {
                FlowLayout(spacing: DSSpacing.xs) {
                    ForEach(lane.hooks) { hook in
                        hookBadge(hook)
                    }
                }
                .padding(.leading, DSSize.md + DSSpacing.sm)
            }
        }
        .padding(DSSpacing.md)
        .dsGlassPanel(
            level: lane.hooks.isEmpty ? .subtle : .light,
            cornerRadius: DSRadius.md,
            elevation: lane.hooks.isEmpty ? .none : .low
        )
    }

    // MARK: - Hook Badge

    @ViewBuilder
    private func hookBadge(_ hook: InstalledHookSummary) -> some View {
        HStack(spacing: DSSpacing.xxs) {
            Circle()
                .fill(scopeColor(hook.scope))
                .frame(width: 8, height: 8)

            if !hook.matcher.isEmpty {
                Text(hook.matcher.joined(separator: ", "))
                    .dsTextStyle(.caption)
                    .lineLimit(1)
            } else {
                Text("default")
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }

            if !hook.isEnabled {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ds.warning)
            }
        }
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 4)
        .background(scopeColor(hook.scope).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .strokeBorder(scopeColor(hook.scope).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading hooks...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xxl)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.lg, elevation: .low)
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ds.negative)

            Text(message)
                .dsTextStyle(.body, color: .ds.negative)

            Spacer()

            Button {
                error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.borderless)
        }
        .padding(DSSpacing.md)
        .background(Color.ds.negative.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }

    // MARK: - Actions

    private func loadHooks() async {
        isLoading = true
        error = nil

        do {
            let hooks = try await HooksInstallationService.shared.listInstalledHooks()
            await MainActor.run {
                installedHooks = hooks
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load hooks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Helpers

    private func scopeColor(_ scope: HookInstallScope) -> Color {
        switch scope {
        case .user:
            return Color.ds.info
        case .project:
            return Color.ds.accent
        }
    }
}

// MARK: - Hook Event Lane

/// A single event lane in the lifecycle map
private struct HookEventLane: Identifiable {
    let id: String
    let eventName: String
    let eventIcon: String
    let eventDescription: String
    let hooks: [InstalledHookSummary]
}

// MARK: - Hook Event Info

/// Static metadata for a hook event
private struct HookEventInfo {
    let name: String
    let icon: String
    let description: String
}


// MARK: - Previews

#if DEBUG
#Preview("Lifecycle Map - With Hooks") {
    NavigationStack {
        HooksLifecycleMapView()
    }
}

#Preview("Lifecycle Map - Empty") {
    HooksLifecycleMapView()
}
#endif
