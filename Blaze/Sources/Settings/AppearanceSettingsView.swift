//
//  AppearanceSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI
import AppKit

struct AppearanceSettingsView: View {
    @Environment(\.themeManager) private var themeManager
    @AppStorage("activeThemeId") private var activeThemeId: String = ""
    @AppStorage("customGlassLevel") private var glassLevel: String = "regular"
    @AppStorage("accentColor") private var accentColor: String = "blue"

    @State private var editingTheme: ThemeProfile?

    private let glassLevels: [(String, String)] = [
        ("None", "subtle"),
        ("Subtle", "light"),
        ("Regular", "regular"),
        ("Prominent", "prominent")
    ]

    private let accentColors: [(String, String)] = [
        ("Blue", "blue"),
        ("Purple", "purple"),
        ("Pink", "pink"),
        ("Red", "red"),
        ("Orange", "orange"),
        ("Yellow", "yellow"),
        ("Green", "green"),
        ("Mint", "mint"),
        ("Teal", "teal")
    ]

    /// Returns the currently active theme name for display
    private var activeThemeName: String {
        if let manager = themeManager {
            return manager.activeTheme.name
        }
        // Fallback: look up from activeThemeId
        if let uuid = UUID(uuidString: activeThemeId),
           let theme = BuiltInThemes.theme(forId: uuid) {
            return theme.name
        }
        return "Nebula"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                // Current Active Theme Display
                FormSection(
                    title: "Current Theme",
                    description: "Your active appearance settings"
                ) {
                    HStack(spacing: DSSpacing.md) {
                        // Theme color preview circles
                        if let manager = themeManager {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(manager.activeTheme.colors.background ?? Color.ds.bg0)
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(manager.activeTheme.colors.surface ?? Color.ds.surface)
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(manager.activeTheme.colors.accent ?? Color.ds.accent)
                                    .frame(width: 24, height: 24)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeThemeName)
                                .dsTextStyle(.subtitle)
                                .foregroundStyle(Color.ds.foreground)

                            Text("Glass: \(glassLevel.capitalized) | Accent: \(accentColor.capitalized)")
                                .dsTextStyle(.caption, color: .ds.secondary)
                        }

                        Spacer()
                    }
                }

                // Theme Section
                FormSection(
                    title: "Theme",
                    description: "Choose a built-in theme or create your own"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text("Built-in Themes")
                            .dsTextStyle(.caption, color: .ds.secondary)

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 150), spacing: DSSpacing.md)
                            ],
                            spacing: DSSpacing.md
                        ) {
                            ForEach(BuiltInThemes.all) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: activeThemeId == theme.id.uuidString,
                                    onSelect: {
                                        selectTheme(theme)
                                    },
                                    onDelete: nil
                                )
                            }
                        }

                        // Custom Themes Section
                        if let manager = themeManager, !manager.customThemes.isEmpty {
                            Divider()
                                .padding(.vertical, DSSpacing.xs)

                            Text("Custom Themes")
                                .dsTextStyle(.caption, color: .ds.secondary)

                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 150), spacing: DSSpacing.md)
                                ],
                                spacing: DSSpacing.md
                            ) {
                                ForEach(manager.customThemes) { theme in
                                    ThemeCard(
                                        theme: theme,
                                        isSelected: activeThemeId == theme.id.uuidString,
                                        onSelect: {
                                            selectTheme(theme)
                                        },
                                        onDelete: {
                                            deleteCustomTheme(id: theme.id)
                                        }
                                    )
                                }
                            }
                        }

                        HStack(spacing: DSSpacing.sm) {
                            Button {
                                editingTheme = themeManager?.activeTheme ?? ThemeProfile.default
                            } label: {
                                Label("Edit Theme", systemImage: "paintbrush.pointed")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                // Create blank theme for editing (starts from Nebula as base)
                                editingTheme = ThemeProfile(
                                    id: UUID(),
                                    name: "New Theme",
                                    isBuiltIn: false,
                                    colors: ThemeColors.nebula,
                                    glassLevel: .regular,
                                    accentOption: .purple
                                )
                            } label: {
                                Label("New Theme", systemImage: "plus.circle")
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button {
                                themeManager?.resetToDefaults()
                            } label: {
                                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                            .help("Reset to the default Nebula theme")
                        }
                    }
                }
                .sheet(item: $editingTheme) { theme in
                    ThemeEditorView(
                        theme: theme,
                        onSave: { updatedTheme in
                            themeManager?.applyTheme(updatedTheme)
                            activeThemeId = updatedTheme.id.uuidString
                        }
                    )
                }

                // Glass Effect Section
                FormSection(
                    title: "Glass Effect",
                    description: "Adjust the transparency and blur intensity"
                ) {
                    FormRow(label: "Glass Level") {
                        Picker("Glass Level", selection: $glassLevel) {
                            ForEach(glassLevels, id: \.1) { name, value in
                                Text(name).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Accent Color Section
                FormSection(
                    title: "Accent Color",
                    description: "Choose your primary accent color"
                ) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 60), spacing: DSSpacing.sm)
                        ],
                        spacing: DSSpacing.sm
                    ) {
                        ForEach(accentColors, id: \.0) { name, colorName in
                            AccentColorSwatch(
                                name: name,
                                colorName: colorName,
                                isSelected: accentColor == colorName
                            ) {
                                selectAccentColor(colorName)
                            }
                        }
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Actions

    private func selectTheme(_ theme: ThemeProfile) {
        // Update AppStorage (persists the ID)
        activeThemeId = theme.id.uuidString

        // Apply via ThemeManager if available (triggers visual change)
        themeManager?.applyTheme(theme)
    }

    private func deleteCustomTheme(id: UUID) {
        guard let manager = themeManager else { return }

        Task {
            await manager.deleteCustomTheme(id: id)
        }
    }

    private func selectAccentColor(_ colorName: String) {
        accentColor = colorName

        // Map string to AccentColorOption and resolve color
        guard let accentOption = AccentColorOption(rawValue: colorName),
              let resolvedColor = accentOption.color,
              let manager = themeManager else {
            return
        }

        // Create updated theme with new accent color
        var updatedTheme = manager.activeTheme
        updatedTheme.colors = ThemeColors(
            background: updatedTheme.colors.background,
            surface: updatedTheme.colors.surface,
            surfaceHover: updatedTheme.colors.surfaceHover,
            accent: resolvedColor,
            accentHover: resolvedColor.lighter(by: 0.15),
            textPrimary: updatedTheme.colors.textPrimary,
            textSecondary: updatedTheme.colors.textSecondary,
            textMuted: updatedTheme.colors.textMuted,
            border: updatedTheme.colors.border,
            success: updatedTheme.colors.success,
            warning: updatedTheme.colors.warning,
            error: updatedTheme.colors.error
        )

        // For built-in themes, create a variant with new ID to preserve original
        if updatedTheme.isBuiltIn {
            let customTheme = ThemeProfile(
                id: UUID(),
                name: "\(updatedTheme.name) (Custom)",
                isBuiltIn: false,
                colors: updatedTheme.colors,
                glassLevel: updatedTheme.glassLevel,
                accentOption: accentOption,
                fontOverrides: updatedTheme.fontOverrides
            )
            manager.applyTheme(customTheme)
            activeThemeId = customTheme.id.uuidString
        } else {
            // For custom themes, update in place
            let updated = ThemeProfile(
                id: updatedTheme.id,
                name: updatedTheme.name,
                isBuiltIn: false,
                colors: updatedTheme.colors,
                glassLevel: updatedTheme.glassLevel,
                accentOption: accentOption,
                fontOverrides: updatedTheme.fontOverrides
            )
            manager.applyTheme(updated)
        }
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    let theme: ThemeProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Color preview with optional delete button
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.colors.background ?? Color.ds.bg0)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(theme.colors.surface ?? Color.ds.surface)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(theme.colors.accent ?? Color.ds.accent)
                    .frame(width: 16, height: 16)

                Spacer()

                // Delete button for custom themes (shown on hover)
                if let onDelete = onDelete, !theme.isBuiltIn {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.ds.negative.opacity(isHovering ? 1 : 0.7))
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1 : 0)
                    .help("Delete custom theme")
                }
            }

            Text(theme.name)
                .dsTextStyle(.body)
                .foregroundStyle(isSelected ? Color.accentColor : Color.ds.foreground)

            if theme.isBuiltIn {
                Text("Built-in")
                    .dsTextStyle(.caption, color: .ds.tertiary)
            } else {
                Text("Custom")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }
        }
        .padding(DSSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassPanel(
            level: isSelected ? .regular : .subtle,
            cornerRadius: DSRadius.md,
            elevation: isSelected ? .medium : .low,
            border: isSelected ? .layered : .subtle
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Accent Color Swatch

private struct AccentColorSwatch: View {
    let name: String
    let colorName: String
    let isSelected: Bool
    let onSelect: () -> Void

    private var swatchColor: Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: DSSpacing.xxs) {
            Circle()
                .fill(swatchColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.white : Color.clear,
                            lineWidth: 3
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.ds.border.opacity(0.3),
                            lineWidth: 1
                        )
                )

            Text(name)
                .dsTextStyle(.caption, color: isSelected ? .ds.foreground : .ds.secondary)
                .font(.system(size: 10))
        }
        .onTapGesture {
            onSelect()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Theme Editor (Standalone)
// Note: ThemeEditorView is now in Settings/Theme/ThemeEditorView.swift
// This section previously contained embedded ThemeEditorSheet, ColorPickerRow, and ThemePreviewCard
// which have been superseded by the standalone implementations with enhanced features.

// MARK: - Color Extensions

extension Color {
    /// Creates a lighter version of this color
    fileprivate func lighter(by amount: Double) -> Color {
        // Use NSColor for manipulation
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            return self
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let newBrightness = min(1.0, brightness + CGFloat(amount))
        return Color(NSColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha))
    }
}

// MARK: - Preview

#Preview {
    AppearanceSettingsView()
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}

#Preview("Theme Editor") {
    ThemeEditorView(
        theme: BuiltInThemes.nebula,
        onSave: { _ in }
    )
}
