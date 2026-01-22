import SwiftUI

/// Available syntax highlighting themes
private enum SyntaxTheme: String, CaseIterable {
    case `default` = "default"
    case light = "light"
    case dark = "dark"
    case highContrast = "highContrast"

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .light: return "Light"
        case .dark: return "Dark"
        case .highContrast: return "High Contrast"
        }
    }
}

struct FilesSettingsView: View {
    @AppStorage("showLineNumbers") private var lineNumbers: Bool = true
    @AppStorage("wordWrap") private var wordWrap: Bool = false
    @AppStorage("tabSize") private var tabSize: Int = 4
    @AppStorage("diffStyle") private var diffStyle: String = "unified"
    @AppStorage("syntaxTheme") private var syntaxThemeRaw: String = "default"
    @AppStorage("showInvisibles") private var showInvisibles: Bool = false
    @AppStorage("highlightCurrentLine") private var highlightCurrentLine: Bool = true

    /// Safe binding that validates the stored theme value
    private var syntaxTheme: Binding<SyntaxTheme> {
        Binding(
            get: {
                SyntaxTheme(rawValue: syntaxThemeRaw) ?? .default
            },
            set: { newValue in
                syntaxThemeRaw = newValue.rawValue
            }
        )
    }

    /// Current theme value for preview
    private var currentTheme: SyntaxTheme {
        SyntaxTheme(rawValue: syntaxThemeRaw) ?? .default
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Display settings
                FormSection(
                    title: "Display",
                    description: "Configure how code is displayed in the editor"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        GlassToggle(
                            "Show Line Numbers",
                            isOn: $lineNumbers,
                            description: "Display line numbers in the gutter"
                        )

                        GlassToggle(
                            "Word Wrap",
                            isOn: $wordWrap,
                            description: "Wrap long lines to window width"
                        )

                        GlassToggle(
                            "Show Invisible Characters",
                            isOn: $showInvisibles,
                            description: "Display spaces, tabs, and line endings"
                        )

                        GlassToggle(
                            "Highlight Current Line",
                            isOn: $highlightCurrentLine,
                            description: "Subtly highlight the line containing the cursor"
                        )
                    }
                }

                // Editing settings
                FormSection(
                    title: "Editing",
                    description: "Configure indentation and whitespace handling"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            Text("Tab Size")
                                .dsTextStyle(.body)
                            Spacer()
                            Picker("Tab Size", selection: $tabSize) {
                                Text("2").tag(2)
                                Text("4").tag(4)
                                Text("8").tag(8)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        Text("Number of spaces used for tab indentation")
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Diff view settings
                FormSection(
                    title: "Diff View",
                    description: "Configure how file changes are displayed"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            Text("Diff Style")
                                .dsTextStyle(.body)
                            Spacer()
                            Picker("Diff Style", selection: $diffStyle) {
                                Text("Unified").tag("unified")
                                Text("Split").tag("split")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        Text(diffStyle == "unified"
                            ? "Shows changes inline with + and - markers"
                            : "Shows old and new versions side by side"
                        )
                        .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Syntax theme settings
                FormSection(
                    title: "Syntax Highlighting",
                    description: "Choose the color scheme for code highlighting"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            Text("Theme")
                                .dsTextStyle(.body)
                            Spacer()
                            Picker("Syntax Theme", selection: syntaxTheme) {
                                ForEach(SyntaxTheme.allCases, id: \.self) { theme in
                                    Text(theme.displayName).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        // Theme preview
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Text("Preview")
                                .dsTextStyle(.caption, color: .ds.secondary)

                            CodePreview(theme: currentTheme)
                        }
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Code Preview

private struct CodePreview: View {
    let theme: SyntaxTheme

    private var backgroundColor: Color {
        switch theme {
        case .light: return Color(white: 0.95)
        case .dark: return Color(white: 0.1)
        case .highContrast: return .black
        case .default: return Color.ds.surface.opacity(0.5)
        }
    }

    private var textColor: Color {
        switch theme {
        case .light: return .black
        case .highContrast: return .white
        case .dark, .default: return Color.ds.foreground
        }
    }

    private var keywordColor: Color {
        switch theme {
        case .light, .default: return .purple
        case .dark: return .pink
        case .highContrast: return .yellow
        }
    }

    private var stringColor: Color {
        switch theme {
        case .light: return .red
        case .dark, .default: return .green
        case .highContrast: return .cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text("func ")
                    .foregroundStyle(keywordColor)
                Text("greet")
                    .foregroundStyle(textColor)
                Text("(")
                    .foregroundStyle(textColor)
                Text("name")
                    .foregroundStyle(textColor)
                Text(": String")
                    .foregroundStyle(keywordColor)
                Text(") {")
                    .foregroundStyle(textColor)
            }
            HStack(spacing: 0) {
                Text("    print")
                    .foregroundStyle(textColor)
                Text("(")
                    .foregroundStyle(textColor)
                Text("\"Hello, \\(name)!\"")
                    .foregroundStyle(stringColor)
                Text(")")
                    .foregroundStyle(textColor)
            }
            Text("}")
                .foregroundStyle(textColor)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(DSSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview("Files Settings") {
    FilesSettingsView()
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}

#Preview("Code Preview - Themes") {
    VStack(spacing: 16) {
        ForEach(SyntaxTheme.allCases, id: \.self) { theme in
            VStack(alignment: .leading) {
                Text(theme.displayName)
                    .font(.caption)
                CodePreview(theme: theme)
            }
        }
    }
    .padding()
    .background(Color.ds.bg0)
}
