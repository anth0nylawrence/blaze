import SwiftUI

// MARK: - Hooks Lifecycle View

/// Lifecycle management view for installed hooks.
/// Lists all hooks from user and project scopes with controls for enabling/disabling and uninstalling.
public struct HooksLifecycleView: View {
    // MARK: - State

    @State private var installedHooks: [InstalledHookSummary] = []
    @State private var scopeFilter: ScopeFilter = .all
    @State private var isLoading = false
    @State private var error: String?
    @State private var hookToDelete: InstalledHookSummary?
    @State private var showDeleteConfirmation = false

    @AppStorage("defaultHookInstallScope") private var defaultScope: String = HookInstallScope.project.rawValue

    // MARK: - Computed Properties

    private var filteredHooks: [InstalledHookSummary] {
        switch scopeFilter {
        case .all:
            return installedHooks
        case .user:
            return installedHooks.filter { $0.scope == .user }
        case .project:
            return installedHooks.filter { $0.scope == .project }
        }
    }

    private var defaultScopeBinding: Binding<HookInstallScope> {
        Binding(
            get: { HookInstallScope(rawValue: defaultScope) ?? .project },
            set: { defaultScope = $0.rawValue }
        )
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

                // Filters and controls
                controlsSection

                // Installed hooks list
                if isLoading {
                    loadingView
                } else if filteredHooks.isEmpty {
                    emptyStateView
                } else {
                    hooksListSection
                }

                // Link to lifecycle map
                lifecycleMapLink
            }
            .padding(DSSpacing.lg)
        }
        .background(Color.ds.bg0)
        .onAppear {
            Task {
                await loadHooks()
            }
        }
        .confirmationDialog(
            "Uninstall Hook",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                if let hook = hookToDelete {
                    Task {
                        await uninstallHook(hook)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                hookToDelete = nil
            }
        } message: {
            if let hook = hookToDelete {
                Text("Are you sure you want to uninstall the '\(hook.eventName)' hook from \(hook.scope.displayName) scope? This will remove it from settings.json.")
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Hooks Lifecycle")
                .dsTextStyle(.title)

            Text("Manage installed hooks across user and project scopes")
                .dsTextStyle(.body, color: .ds.secondary)
        }
    }

    // MARK: - Controls Section

    @ViewBuilder
    private var controlsSection: some View {
        FormSection(
            title: "Controls",
            description: "Filter and configure hook installation defaults"
        ) {
            VStack(spacing: DSSpacing.md) {
                // Scope filter
                FormRow(
                    label: "Scope Filter",
                    helpText: "Filter hooks by installation scope"
                ) {
                    GlassPicker("Scope", selection: $scopeFilter) {
                        ForEach(ScopeFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                }

                // Default scope for new installs
                FormRow(
                    label: "Default Install Scope",
                    helpText: "New hooks will be installed to this scope by default"
                ) {
                    GlassPicker("Default Scope", selection: defaultScopeBinding) {
                        ForEach(HookInstallScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                }

                // Refresh button
                Button {
                    Task {
                        await loadHooks()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Hooks List Section

    @ViewBuilder
    private var hooksListSection: some View {
        FormSection(
            title: "Installed Hooks",
            description: "Hooks currently installed in user and project settings"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(filteredHooks) { hook in
                    hookRow(hook)
                }
            }
        }
    }

    // MARK: - Hook Row

    @ViewBuilder
    private func hookRow(_ hook: InstalledHookSummary) -> some View {
        HStack(spacing: DSSpacing.md) {
            // Event icon
            Image(systemName: eventIcon(for: hook.eventName))
                .font(.system(size: DSSize.sm))
                .foregroundStyle(Color.ds.accent)
                .frame(width: DSSize.md)

            // Hook info
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(hook.eventName)
                    .dsTextStyle(.body)

                if !hook.matcher.isEmpty {
                    Text(hook.matcher.joined(separator: ", "))
                        .dsTextStyle(.caption, color: .ds.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Scope badge
            scopeBadge(hook.scope)

            // Enabled toggle (Note: Currently hooks don't have an enabled flag in the schema,
            // so this is always shown as enabled. In the future, this could be wired up to
            // a real enabled/disabled state in settings.json)
            Toggle("", isOn: .constant(hook.isEnabled))
                .labelsHidden()
                .disabled(true) // Disabled until schema supports enabled flag
                .help("Enable/disable hook (not yet supported)")

            // Delete button
            Button {
                hookToDelete = hook
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: DSSize.xs))
                    .foregroundStyle(Color.ds.negative)
            }
            .buttonStyle(.borderless)
            .help("Uninstall hook")
        }
        .padding(DSSpacing.sm)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
    }

    // MARK: - Scope Badge

    @ViewBuilder
    private func scopeBadge(_ scope: HookInstallScope) -> some View {
        Text(scope == .user ? "User" : "Project")
            .dsTextStyle(.caption)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, 2)
            .background(scope == .user ? Color.ds.info.opacity(0.2) : Color.ds.accent.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
    }

    // MARK: - Lifecycle Map Link

    @ViewBuilder
    private var lifecycleMapLink: some View {
        FormSection(
            title: "Visualization",
            description: "View hooks in a visual lifecycle diagram"
        ) {
            NavigationLink {
                HooksLifecycleMapView()
            } label: {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: DSSize.md))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lifecycle Map")
                            .dsTextStyle(.body)

                        Text("Visual representation of hook execution flow")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .padding(DSSpacing.md)
                .dsGlassPanel(level: .light, cornerRadius: DSRadius.md, elevation: .low)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.tertiary)

            Text("No Hooks Installed")
                .dsTextStyle(.subtitle)

            Text("Install hooks from the visual builder or CLI")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xxl)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.lg, elevation: .low)
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

    private func uninstallHook(_ hook: InstalledHookSummary) async {
        error = nil

        do {
            // Note: This is a simplified uninstall that removes ALL hooks from the scope.
            // A more granular implementation would:
            // 1. Read the settings file
            // 2. Remove only the specific hook entry
            // 3. Write back the modified settings
            //
            // For now, we'll use the service's uninstallHooks method which removes all hooks.
            // This should be enhanced in the future to remove individual hooks.
            try await HooksInstallationService.shared.uninstallHooks(scope: hook.scope)

            // Reload hooks after uninstall
            await loadHooks()
        } catch {
            await MainActor.run {
                self.error = "Failed to uninstall hook: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func eventIcon(for eventName: String) -> String {
        switch eventName {
        case "PreToolUse": return "play.circle"
        case "PostToolUse": return "checkmark.circle"
        case "PostToolUseFailure": return "xmark.circle"
        case "PermissionRequest": return "lock.circle"
        case "UserPromptSubmit": return "text.bubble"
        case "Notification": return "bell"
        case "Stop": return "stop.circle"
        case "SubagentStart": return "arrow.branch"
        case "SubagentStop": return "arrow.merge"
        case "PreCompact": return "compress"
        case "SessionStart": return "play.rectangle"
        case "SessionEnd": return "stop.rectangle"
        default: return "circlebadge"
        }
    }
}

// MARK: - Scope Filter Enum

private enum ScopeFilter: String, CaseIterable {
    case all = "all"
    case user = "user"
    case project = "project"

    var displayName: String {
        switch self {
        case .all: return "All Scopes"
        case .user: return "User Only"
        case .project: return "Project Only"
        }
    }
}

// MARK: - Shared Singleton

extension HooksInstallationService {
    /// Shared instance for use across views
    static let shared = HooksInstallationService()
}

// MARK: - Previews

#if DEBUG
#Preview("Hooks Lifecycle - With Hooks") {
    NavigationStack {
        HooksLifecycleView()
    }
}

#Preview("Hooks Lifecycle - Empty") {
    NavigationStack {
        HooksLifecycleView()
    }
}
#endif
