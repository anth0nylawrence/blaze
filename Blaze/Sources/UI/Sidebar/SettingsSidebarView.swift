import SwiftUI

// MARK: - Settings Sidebar View

/// Tab 17: Quick settings access sidebar.
///
/// **Phase 2 Spec:**
/// - Quick settings access (subset of full preferences)
/// - Sections:
///   - Appearance: Theme toggle, transparency slider
///   - Engine: Default CLI, model selection
///   - Trust: Trust mode selector
/// - Link to full preferences window
struct SettingsSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var expandedSections: Set<SettingsSection> = Set(SettingsSection.allCases)

    // Quick settings state
    @AppStorage("appearanceTheme") private var appearanceTheme: AppearanceTheme = .system
    @AppStorage("windowTransparency") private var windowTransparency: Double = 0.95
    @AppStorage("defaultEngine") private var defaultEngine: String = "claude"
    @AppStorage("defaultModel") private var defaultModel: String = "sonnet"
    @AppStorage("defaultTrustMode") private var defaultTrustMode: String = "prompt"
    @AppStorage("enableSoundEffects") private var enableSoundEffects: Bool = true
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true

    // Terminal settings
    @AppStorage("terminalBackend") private var terminalBackend: String = "SwiftTerm"

    // Subagent settings
    @AppStorage("maxConcurrentSubagents") private var maxConcurrentSubagents: Int = 10
    @AppStorage("autoThrottleSubagents") private var autoThrottleSubagents: Bool = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Settings sections
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    appearanceSection
                    engineSection
                    terminalSection
                    subagentsSection
                    trustSection

                    Divider()
                        .padding(.vertical, DSSpacing.sm)

                    // Open full preferences button
                    fullPreferencesButton
                }
                .padding(.vertical, DSSpacing.xs)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Label("Quick Settings", systemImage: "gearshape.fill")
                .dsTextStyle(.caption, color: .ds.secondary)

            Spacer()

            // Reset to defaults button
            Button {
                resetToDefaults()
            } label: {
                Text("Reset")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }
            .buttonStyle(.plain)
            .help("Reset to default settings")
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        settingsSection(section: .appearance, icon: "paintbrush.fill") {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Theme picker
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Theme")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Picker("", selection: $appearanceTheme) {
                        ForEach(AppearanceTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Transparency slider
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    HStack {
                        Text("Transparency")
                            .dsTextStyle(.micro, color: .ds.tertiary)

                        Spacer()

                        Text("\(Int(windowTransparency * 100))%")
                            .dsTextStyle(.monoSmall, color: .ds.tertiary)
                    }

                    Slider(value: $windowTransparency, in: 0.80...1.0, step: 0.05)
                        .tint(Color.ds.accent)
                        .onChange(of: windowTransparency) { _, newValue in
                            applyWindowTransparency(newValue)
                        }

                    Text("Controls window opacity (80-100%)")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }

                // Code display toggles
                Toggle(isOn: $showLineNumbers) {
                    Text("Show Line Numbers")
                        .dsTextStyle(.caption)
                }
                .toggleStyle(.switch)

                Toggle(isOn: $enableSoundEffects) {
                    Text("Sound Effects")
                        .dsTextStyle(.caption)
                }
                .toggleStyle(.switch)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
        }
    }

    // MARK: - Engine Section

    private var engineSection: some View {
        settingsSection(section: .engine, icon: "cpu") {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Default engine picker
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Default CLI")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Picker("", selection: $defaultEngine) {
                        Text("Claude Code").tag("claude")
                        Text("Gemini CLI").tag("gemini")
                        Text("Codex CLI").tag("codex")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Model picker
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Default Model")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Picker("", selection: $defaultModel) {
                        ForEach(currentEngineModels, id: \.id) { model in
                            Text(model.pickerLabel).tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: defaultEngine) { _, newEngine in
                        // Reset to default model for the new engine
                        if let engine = engineTypeFromString(newEngine) {
                            defaultModel = ModelService.defaultModel(for: engine)
                        }
                    }
                }

                // Engine status
                HStack(spacing: DSSpacing.xs) {
                    Circle()
                        .fill(Color.ds.positive)
                        .frame(width: 6, height: 6)

                    Text("Claude Code installed")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
        }
    }

    // MARK: - Terminal Section

    private var terminalSection: some View {
        settingsSection(section: .terminal, icon: "terminal") {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Backend picker
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Backend")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Picker("", selection: $terminalBackend) {
                        Text("SwiftTerm").tag("SwiftTerm")
                        HStack {
                            Text("Ghostty")
                            Text("Coming Soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }.tag("Ghostty")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Backend status
                HStack(spacing: DSSpacing.xs) {
                    Circle()
                        .fill(terminalBackend == "SwiftTerm" ? Color.ds.positive : Color.ds.warning)
                        .frame(width: 6, height: 6)

                    Text(terminalBackend == "SwiftTerm" ? "SwiftTerm active" : "Ghostty not available yet")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
        }
    }

    // MARK: - Subagents Section

    private var subagentsSection: some View {
        settingsSection(section: .subagents, icon: "person.3") {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Concurrency slider
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    HStack {
                        Text("Max Concurrent")
                            .dsTextStyle(.micro, color: .ds.tertiary)

                        Spacer()

                        Text("\(maxConcurrentSubagents)")
                            .dsTextStyle(.monoSmall, color: .ds.tertiary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(maxConcurrentSubagents) },
                            set: { maxConcurrentSubagents = Int($0) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                    .tint(Color.ds.accent)
                }

                // Quick presets
                HStack(spacing: DSSpacing.xs) {
                    ForEach([10, 25, 50, 100], id: \.self) { preset in
                        Button("\(preset)") {
                            maxConcurrentSubagents = preset
                        }
                        .buttonStyle(.bordered)
                        .tint(maxConcurrentSubagents == preset ? Color.ds.accent : Color.ds.tertiary)
                        .controlSize(.small)
                    }
                }

                // Auto-throttle toggle
                Toggle(isOn: $autoThrottleSubagents) {
                    Text("Auto-throttle on low memory")
                        .dsTextStyle(.caption)
                }
                .toggleStyle(.switch)

                Text("Default: 10 • Power users: 50-100")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
        }
    }

    // MARK: - Trust Section

    private var trustSection: some View {
        settingsSection(section: .trust, icon: "shield.fill") {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Trust mode picker
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("Default Trust Mode")
                        .dsTextStyle(.micro, color: .ds.tertiary)

                    Picker("", selection: $defaultTrustMode) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                            Text("Review Mode")
                        }.tag("prompt")

                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Trusted Mode")
                        }.tag("trusted")

                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Sandbox Mode")
                        }.tag("sandbox")
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                // Trust mode description
                Text(trustModeDescription)
                    .dsTextStyle(.micro, color: .ds.tertiary)
                    .padding(DSSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ds.surface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.leading, DSSpacing.lg)
        }
    }

    private var trustModeDescription: String {
        switch defaultTrustMode {
        case "prompt":
            return "Risky tools gated, file writes require review, shell commands need confirmation."
        case "trusted":
            return "Minimal gates for experienced users. Most operations auto-approved."
        case "sandbox":
            return "Read-only access with safe tools only. Maximum security."
        default:
            return ""
        }
    }

    // MARK: - Full Preferences Button

    private var fullPreferencesButton: some View {
        Button {
            openFullPreferences()
        } label: {
            HStack {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ds.accent)

                Text("Open Full Preferences...")
                    .dsTextStyle(.caption, color: .ds.accent)

                Spacer()

                Text("\u{2318},")
                    .dsTextStyle(.monoSmall, color: .ds.tertiary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Helper

    private func settingsSection<Content: View>(
        section: SettingsSection,
        icon: String,
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

                    Text(section.rawValue)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .fontWeight(.medium)

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

    // MARK: - Computed Properties

    /// Get models for the currently selected engine
    private var currentEngineModels: [ModelService.ModelInfo] {
        guard let engine = engineTypeFromString(defaultEngine) else {
            return []
        }
        return ModelService.models(for: engine)
    }

    // MARK: - Helper Methods

    /// Convert engine string identifier to EngineType
    private func engineTypeFromString(_ engineString: String) -> EngineType? {
        switch engineString {
        case "claude": return .claude
        case "gemini": return .gemini
        case "codex": return .codex
        default: return nil
        }
    }

    // MARK: - Actions

    private func toggleSection(_ section: SettingsSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func resetToDefaults() {
        appearanceTheme = .system
        windowTransparency = 0.95
        defaultEngine = "claude"
        defaultModel = "sonnet"
        defaultTrustMode = "prompt"
        enableSoundEffects = true
        showLineNumbers = true
    }

    private func openFullPreferences() {
        // Use keyboard shortcut simulation - most reliable way to open Settings
        if let mainMenu = NSApp.mainMenu,
           let appMenu = mainMenu.items.first?.submenu,
           let settingsItem = appMenu.items.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
            settingsItem.target?.perform(settingsItem.action, with: settingsItem)
        } else {
            // Fallback: simulate Cmd+, keyboard shortcut
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: ",",
                charactersIgnoringModifiers: ",",
                isARepeat: false,
                keyCode: 43  // comma key
            )
            if let event = event {
                NSApp.sendEvent(event)
            }
        }
    }

    /// Apply window transparency to all windows
    private func applyWindowTransparency(_ opacity: Double) {
        // Clamp to valid range (0.8 - 1.0)
        let clampedOpacity = max(0.8, min(1.0, opacity))

        // Apply to all windows
        for window in NSApp.windows {
            window.alphaValue = clampedOpacity
        }
    }
}

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable {
    case appearance = "Appearance"
    case engine = "Engine"
    case terminal = "Terminal"
    case subagents = "Subagents"
    case trust = "Trust Mode"
}

// MARK: - Appearance Theme

enum AppearanceTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Previews

#Preview("Settings Sidebar") {
    SettingsSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}

#Preview("Settings Sidebar - Collapsed") {
    SettingsSidebarView(sessionId: nil)
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
        .background(Color.ds.bg0)
}
