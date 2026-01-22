//
//  ShortcutsSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

/// Settings view showing keyboard shortcuts reference.
struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Navigation Section
                FormSection(
                    title: "Navigation",
                    description: "Move around the app"
                ) {
                    shortcutRow("New Session", keys: "\u{2318}N")
                    shortcutRow("Toggle Sidebar", keys: "\u{2318}\\")
                    shortcutRow("Quick Tab 1-9", keys: "\u{2318}1-9")
                    shortcutRow("Focus Input", keys: "\u{2318}L")
                }

                // Chat Section
                FormSection(
                    title: "Chat",
                    description: "Interact with the assistant"
                ) {
                    shortcutRow("Send Message", keys: "\u{2318}\u{21A9}")
                    shortcutRow("Cancel", keys: "Esc")
                    shortcutRow("Clear Chat", keys: "\u{2318}K")
                }

                // Display Section
                FormSection(
                    title: "Display",
                    description: "Adjust the interface"
                ) {
                    shortcutRow("Increase Font Size", keys: "\u{2318}+")
                    shortcutRow("Decrease Font Size", keys: "\u{2318}-")
                    shortcutRow("Reset Font Size", keys: "\u{2318}0")
                }

                // Application Section
                FormSection(
                    title: "Application",
                    description: "General app controls"
                ) {
                    shortcutRow("Preferences", keys: "\u{2318},")
                    shortcutRow("Close Window", keys: "\u{2318}W")
                    shortcutRow("Quit", keys: "\u{2318}Q")
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Shortcut Row

    private func shortcutRow(_ name: String, keys: String) -> some View {
        HStack {
            Text(name)
                .dsTextStyle(.body)

            Spacer()

            Text(keys)
                .dsTextStyle(.mono, color: .ds.secondary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xxs)
                .background(Color.ds.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

#Preview {
    ShortcutsSettingsView()
        .frame(width: 600, height: 500)
        .background(Color.ds.bg0)
}
