//
//  ThemeEditorView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI
import os.log

// MARK: - Theme Editor View

/// A comprehensive theme editor for creating and modifying custom themes.
/// Supports all semantic colors, glass levels, font overrides, and validation.
public struct ThemeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    /// The theme being edited (nil = create new theme)
    let sourceTheme: ThemeProfile?
    let onSave: ((ThemeProfile) -> Void)?

    // MARK: - State

    @State private var themeName: String
    @State private var selectedGlassLevel: DSGlassLevel

    // Background colors
    @State private var backgroundColor: Color
    @State private var surfaceColor: Color
    @State private var surfaceHoverColor: Color

    // Accent colors
    @State private var accentColor: Color
    @State private var accentHoverColor: Color

    // Text colors
    @State private var textPrimaryColor: Color
    @State private var textSecondaryColor: Color
    @State private var textMutedColor: Color

    // State colors
    @State private var borderColor: Color
    @State private var successColor: Color
    @State private var warningColor: Color
    @State private var errorColor: Color

    // Font overrides
    @State private var uiFont: String
    @State private var monoFont: String

    // Validation
    @State private var nameError: String?
    @State private var showDeleteConfirmation = false
    @State private var showDuplicateWarning = false

    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "ThemeEditor")

    // MARK: - Initialization

    /// Creates a theme editor.
    /// - Parameters:
    ///   - theme: The theme to edit, or nil to create a new theme
    ///   - onSave: Callback when theme is saved
    public init(
        theme: ThemeProfile? = nil,
        onSave: ((ThemeProfile) -> Void)? = nil
    ) {
        self.sourceTheme = theme
        self.onSave = onSave

        // Determine base theme (use provided or default)
        let base = theme ?? ThemeProfile.default

        // Initialize name (append suffix for built-in themes)
        let initialName = base.isBuiltIn ? "\(base.name) (Custom)" : base.name
        _themeName = State(initialValue: initialName)
        _selectedGlassLevel = State(initialValue: base.glassLevel)

        // Background colors
        _backgroundColor = State(initialValue: base.colors.background ?? Color(hex: "#0A1020")!)
        _surfaceColor = State(initialValue: base.colors.surface ?? Color(hex: "#1A1725")!)
        _surfaceHoverColor = State(initialValue: base.colors.surfaceHover ?? Color(hex: "#251F35")!)

        // Accent colors
        _accentColor = State(initialValue: base.colors.accent ?? Color(hex: "#9966FF")!)
        _accentHoverColor = State(initialValue: base.colors.accentHover ?? Color(hex: "#B38AFF")!)

        // Text colors
        _textPrimaryColor = State(initialValue: base.colors.textPrimary ?? Color(hex: "#E8E4F0")!)
        _textSecondaryColor = State(initialValue: base.colors.textSecondary ?? Color(hex: "#A89FC4")!)
        _textMutedColor = State(initialValue: base.colors.textMuted ?? Color(hex: "#6B6280")!)

        // State colors
        _borderColor = State(initialValue: base.colors.border ?? Color(hex: "#3D3555")!)
        _successColor = State(initialValue: base.colors.success ?? Color.green)
        _warningColor = State(initialValue: base.colors.warning ?? Color.orange)
        _errorColor = State(initialValue: base.colors.error ?? Color.red)

        // Font overrides
        _uiFont = State(initialValue: base.fontOverrides?.uiFont ?? "")
        _monoFont = State(initialValue: base.fontOverrides?.monoFont ?? "")
    }

    // MARK: - Computed Properties

    private var isBuiltInTheme: Bool {
        sourceTheme?.isBuiltIn ?? false
    }

    private var canDelete: Bool {
        guard let theme = sourceTheme else { return false }
        return !theme.isBuiltIn
    }

    private var isNameValid: Bool {
        !themeName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isDuplicateName: Bool {
        guard let manager = themeManager else { return false }

        let trimmedName = themeName.trimmingCharacters(in: .whitespaces)

        // Check built-in themes
        if BuiltInThemes.all.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            // Allow if editing that exact theme
            if let source = sourceTheme, source.name.lowercased() == trimmedName.lowercased() {
                return false
            }
            return true
        }

        // Check custom themes
        for custom in manager.customThemes {
            if custom.name.lowercased() == trimmedName.lowercased() {
                // Allow if editing the same theme
                if let source = sourceTheme, source.id == custom.id {
                    return false
                }
                return true
            }
        }

        return false
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    nameSection
                    glassLevelSection
                    backgroundColorsSection
                    textColorsSection
                    accentColorsSection
                    stateColorsSection
                    fontSection
                    previewSection
                }
                .padding(DSSpacing.lg)
            }

            // Footer with delete button (for custom themes)
            if canDelete {
                Divider()
                footerView
            }
        }
        .frame(width: 560, height: 700)
        .background(Color.ds.bg0)
        .onAppear {
            logTelemetry("theme_editor_opened")
        }
        .alert("Delete Theme", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTheme()
            }
        } message: {
            Text("Are you sure you want to delete \"\(sourceTheme?.name ?? "this theme")\"? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(sourceTheme == nil ? "New Theme" : "Edit Theme")
                .font(.headline)
                .foregroundStyle(Color.ds.foreground)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Save") {
                saveTheme()
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!isNameValid)
        }
        .padding()
        .background(Color.ds.surface.opacity(0.5))
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Theme", systemImage: "trash")
                    .foregroundStyle(Color.ds.negative)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .background(Color.ds.surface.opacity(0.3))
    }

    // MARK: - Name Section

    private var nameSection: some View {
        FormSection(title: "Theme Name") {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                TextField("Theme Name", text: $themeName)
                    .textFieldStyle(.plain)
                    .padding(DSSpacing.sm)
                    .background(Color.ds.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                    .onChange(of: themeName) { _, newValue in
                        validateName(newValue)
                    }

                if let error = nameError {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                        Text(error)
                    }
                    .dsTextStyle(.caption, color: .ds.negative)
                } else if isDuplicateName {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("A theme with this name already exists")
                    }
                    .dsTextStyle(.caption, color: .ds.warning)
                }
            }
        }
    }

    // MARK: - Glass Level Section

    private var glassLevelSection: some View {
        FormSection(
            title: "Glass Level",
            description: "Controls transparency and blur intensity"
        ) {
            Picker("Glass Level", selection: $selectedGlassLevel) {
                ForEach(DSGlassLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Color Sections

    private var twoColumnGrid: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var backgroundColorsSection: some View {
        FormSection(title: "Background Colors", description: "Window and surface backgrounds") {
            LazyVGrid(columns: twoColumnGrid, spacing: DSSpacing.md) {
                ColorPickerCard(label: "Background", description: "Window background", color: $backgroundColor)
                ColorPickerCard(label: "Surface", description: "Panel backgrounds", color: $surfaceColor)
                ColorPickerCard(label: "Surface Hover", description: "Hovered surfaces", color: $surfaceHoverColor)
            }
        }
    }

    private var textColorsSection: some View {
        FormSection(title: "Text Colors", description: "Typography color hierarchy") {
            LazyVGrid(columns: twoColumnGrid, spacing: DSSpacing.md) {
                ColorPickerCard(label: "Primary", description: "Main text", color: $textPrimaryColor)
                ColorPickerCard(label: "Secondary", description: "Subdued text", color: $textSecondaryColor)
                ColorPickerCard(label: "Muted", description: "Disabled/placeholder", color: $textMutedColor)
            }
        }
    }

    private var accentColorsSection: some View {
        FormSection(title: "Accent Colors", description: "Interactive elements and highlights") {
            LazyVGrid(columns: twoColumnGrid, spacing: DSSpacing.md) {
                ColorPickerCard(label: "Accent", description: "Buttons, links", color: $accentColor)
                ColorPickerCard(label: "Accent Hover", description: "Hovered accents", color: $accentHoverColor)
            }
        }
    }

    private var stateColorsSection: some View {
        FormSection(title: "State Colors", description: "Feedback and status indicators") {
            LazyVGrid(columns: twoColumnGrid, spacing: DSSpacing.md) {
                ColorPickerCard(label: "Border", description: "Dividers, outlines", color: $borderColor)
                ColorPickerCard(label: "Success", description: "Positive states", color: $successColor)
                ColorPickerCard(label: "Warning", description: "Caution states", color: $warningColor)
                ColorPickerCard(label: "Error", description: "Negative states", color: $errorColor)
            }
        }
    }

    // MARK: - Font Section

    private var fontSection: some View {
        FormSection(title: "Font Overrides", description: "Leave empty to use system defaults") {
            VStack(spacing: DSSpacing.md) {
                fontField(label: "UI Font", placeholder: "System Default", text: $uiFont, help: "e.g., SF Pro")
                fontField(label: "Mono Font", placeholder: "System Mono", text: $monoFont, help: "e.g., SF Mono")
            }
        }
    }

    private func fontField(label: String, placeholder: String, text: Binding<String>, help: String) -> some View {
        FormRow(label: label, helpText: help) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(DSSpacing.sm)
                .background(Color.ds.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        }
    }

    // MARK: - Preview Section

    private var previewColors: ResolvedThemeColors {
        ResolvedThemeColors(background: backgroundColor, surface: surfaceColor, surfaceHover: surfaceHoverColor,
                           accent: accentColor, accentHover: accentHoverColor, textPrimary: textPrimaryColor,
                           textSecondary: textSecondaryColor, textMuted: textMutedColor, border: borderColor,
                           success: successColor, warning: warningColor, error: errorColor)
    }

    private var previewSection: some View {
        FormSection(title: "Preview", description: "Live preview of your theme") {
            ThemePreviewPanel(colors: previewColors)
        }
    }

    // MARK: - Actions

    private func validateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            nameError = "Theme name cannot be empty"
        } else {
            nameError = nil
        }
    }

    private func saveTheme() {
        guard isNameValid else { return }

        // Create new UUID for built-in themes (to preserve originals)
        let themeId = isBuiltInTheme ? UUID() : (sourceTheme?.id ?? UUID())

        // Build font overrides (nil if both empty)
        let fontOverrides: FontOverrides? = {
            let ui = uiFont.trimmingCharacters(in: .whitespaces)
            let mono = monoFont.trimmingCharacters(in: .whitespaces)
            if ui.isEmpty && mono.isEmpty {
                return nil
            }
            return FontOverrides(
                uiFont: ui.isEmpty ? nil : ui,
                monoFont: mono.isEmpty ? nil : mono
            )
        }()

        let newTheme = ThemeProfile(
            id: themeId,
            name: themeName.trimmingCharacters(in: .whitespaces),
            isBuiltIn: false,
            colors: ThemeColors(
                background: backgroundColor,
                surface: surfaceColor,
                surfaceHover: surfaceHoverColor,
                accent: accentColor,
                accentHover: accentHoverColor,
                textPrimary: textPrimaryColor,
                textSecondary: textSecondaryColor,
                textMuted: textMutedColor,
                border: borderColor,
                success: successColor,
                warning: warningColor,
                error: errorColor
            ),
            glassLevel: selectedGlassLevel,
            accentOption: .custom,
            fontOverrides: fontOverrides
        )

        logTelemetry("theme_saved")
        onSave?(newTheme)
        dismiss()
    }

    private func deleteTheme() {
        guard let theme = sourceTheme, !theme.isBuiltIn else { return }

        Task {
            await themeManager?.deleteCustomTheme(id: theme.id)
            logTelemetry("theme_deleted")
            await MainActor.run {
                dismiss()
            }
        }
    }

    private func logTelemetry(_ event: String) {
        // Telemetry placeholder - integrate with analytics system
        logger.info("Telemetry: \(event) - theme: \(sourceTheme?.name ?? "new")")
    }
}

// MARK: - Color Picker Card

private struct ColorPickerCard: View {
    let label: String
    let description: String
    @Binding var color: Color

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .dsTextStyle(.body)
                    .foregroundStyle(Color.ds.foreground)

                Text(description)
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }

            Spacer()
        }
        .padding(DSSpacing.sm)
        .background(Color.ds.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
    }
}

// MARK: - DSGlassLevel Display Name

extension DSGlassLevel {
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Theme Editor") {
    ThemeEditorView(theme: BuiltInThemes.nebula, onSave: { _ in })
}
#endif
