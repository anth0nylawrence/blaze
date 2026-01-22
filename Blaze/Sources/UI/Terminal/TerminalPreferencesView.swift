import SwiftUI

// MARK: - TerminalPreferencesView (E001-F006-S001-T008-A001)

/// Settings panel for terminal preferences.
///
/// **Phase 2 System Contract:**
/// - Backend selection (SwiftTerm, future: libghostty)
/// - Font and appearance settings
/// - Scrollback limit configuration
/// - Auto-show behavior toggle
public struct TerminalPreferencesView: View {
    @Binding var preferences: TerminalPreferences
    var onSave: () -> Void

    @State private var detectedShell: String = ShellConfiguration.detectDefaultShell()

    public init(preferences: Binding<TerminalPreferences>, onSave: @escaping () -> Void) {
        self._preferences = preferences
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            // Backend Section
            Section("Terminal Backend") {
                backendSection
            }

            // Shell Section
            Section("Shell") {
                shellSection
            }

            // Appearance Section
            Section("Appearance") {
                appearanceSection
            }

            // Behavior Section
            Section("Behavior") {
                behaviorSection
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .padding()
    }

    // MARK: - Backend Section

    private var backendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Backend", selection: $preferences.backendType) {
                ForEach(TerminalBackendType.allCases, id: \.self) { type in
                    HStack {
                        Text(type.rawValue)
                        if !type.isAvailable {
                            Text("Coming Soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.menu)
            .disabled(!preferences.backendType.isAvailable)

            Text(preferences.backendType.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Shell Section

    private var shellSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Default Shell")
                Spacer()

                if let shell = preferences.defaultShell {
                    Text(shell)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Auto-detect (\(detectedShell))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Button("Choose...") {
                    chooseShell()
                }
            }

            if preferences.defaultShell != nil {
                Button("Reset to Auto-detect") {
                    preferences.defaultShell = nil
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Font Family
            HStack {
                Text("Font Family")
                Spacer()
                Picker("", selection: $preferences.fontFamily) {
                    Text("SF Mono").tag("SF Mono")
                    Text("Menlo").tag("Menlo")
                    Text("Monaco").tag("Monaco")
                    Text("Courier New").tag("Courier New")
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            // Font Size
            HStack {
                Text("Font Size")
                Spacer()
                Stepper(
                    value: $preferences.fontSize,
                    in: 9...24,
                    step: 1
                ) {
                    Text("\(Int(preferences.fontSize)) pt")
                        .frame(width: 50)
                }
            }

            // Line Height
            HStack {
                Text("Line Height")
                Spacer()
                Slider(value: $preferences.lineHeight, in: 1.0...2.0, step: 0.1)
                    .frame(width: 150)
                Text(String(format: "%.1f", preferences.lineHeight))
                    .frame(width: 30)
            }

            // Cursor Style
            HStack {
                Text("Cursor Style")
                Spacer()
                Picker("", selection: $preferences.cursorStyle) {
                    ForEach(CursorStylePreference.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // Cursor Blink
            Toggle("Blinking Cursor", isOn: $preferences.cursorBlink)
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Scrollback Limit
            HStack {
                Text("Scrollback Lines")
                Spacer()
                Picker("", selection: $preferences.scrollbackLimit) {
                    Text("1,000").tag(1_000)
                    Text("5,000").tag(5_000)
                    Text("10,000").tag(10_000)
                    Text("25,000").tag(25_000)
                    Text("50,000").tag(50_000)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            Text("Higher values use more memory (~2MB per 10,000 lines)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Auto-show
            Toggle("Auto-show when Claude runs foreground commands", isOn: $preferences.autoShowOnForegroundCommand)

            // Copy on Select
            Toggle("Copy text on selection", isOn: $preferences.copyOnSelect)

            // Bell Style
            HStack {
                Text("Bell Style")
                Spacer()
                Picker("", selection: $preferences.bellStyle) {
                    ForEach(BellStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
    }

    // MARK: - Helpers

    private func chooseShell() {
        let panel = NSOpenPanel()
        panel.message = "Choose a shell executable"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/bin")

        if panel.runModal() == .OK, let url = panel.url {
            preferences.defaultShell = url.path
        }
    }
}

// MARK: - Terminal Preferences Sheet

/// Sheet wrapper for terminal preferences
public struct TerminalPreferencesSheet: View {
    @Binding var isPresented: Bool
    @Binding var preferences: TerminalPreferences
    var onSave: () -> Void

    @State private var editingPreferences: TerminalPreferences

    public init(
        isPresented: Binding<Bool>,
        preferences: Binding<TerminalPreferences>,
        onSave: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self._preferences = preferences
        self.onSave = onSave
        self._editingPreferences = State(initialValue: preferences.wrappedValue)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Terminal Settings")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                TerminalPreferencesView(preferences: $editingPreferences) {
                    save()
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Reset to Defaults") {
                    editingPreferences = .default
                }

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func save() {
        preferences = editingPreferences
        onSave()
        isPresented = false
    }
}

// MARK: - Inline Terminal Settings

/// Compact inline settings for terminal panel header
public struct InlineTerminalSettings: View {
    @Binding var preferences: TerminalPreferences
    var onPreferencesChanged: () -> Void

    public var body: some View {
        Menu {
            // Font size quick adjust
            Menu("Font Size") {
                ForEach([10, 11, 12, 13, 14, 16, 18], id: \.self) { size in
                    Button {
                        preferences.fontSize = CGFloat(size)
                        onPreferencesChanged()
                    } label: {
                        HStack {
                            Text("\(size) pt")
                            if Int(preferences.fontSize) == size {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            // Auto-show toggle
            Toggle("Auto-show on Commands", isOn: Binding(
                get: { preferences.autoShowOnForegroundCommand },
                set: {
                    preferences.autoShowOnForegroundCommand = $0
                    onPreferencesChanged()
                }
            ))

            // Copy on select toggle
            Toggle("Copy on Select", isOn: Binding(
                get: { preferences.copyOnSelect },
                set: {
                    preferences.copyOnSelect = $0
                    onPreferencesChanged()
                }
            ))

            Divider()

            // Open full settings
            Button("Terminal Settings...") {
                // This would open the full preferences sheet
            }

        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
    }
}

// MARK: - Previews

#Preview("Terminal Preferences") {
    struct PreviewWrapper: View {
        @State var preferences = TerminalPreferences.default

        var body: some View {
            TerminalPreferencesView(preferences: $preferences) {
                print("Saved preferences")
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Terminal Preferences Sheet") {
    struct PreviewWrapper: View {
        @State var isPresented = true
        @State var preferences = TerminalPreferences.default

        var body: some View {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    TerminalPreferencesSheet(
                        isPresented: $isPresented,
                        preferences: $preferences
                    ) {
                        print("Saved preferences")
                    }
                }
        }
    }

    return PreviewWrapper()
}
