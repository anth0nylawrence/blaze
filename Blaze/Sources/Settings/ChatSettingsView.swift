//
//  ChatSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import AppKit
import SwiftUI

/// Settings view for chat and input preferences.
/// Model settings have been moved to ModelsSettingsView.
struct ChatSettingsView: View {
    @AppStorage("sendKey") private var sendKey: String = "enter"
    @AppStorage("showCost") private var showCost: Bool = true
    @AppStorage("showTimestamps") private var showTimestamps: Bool = true
    @AppStorage("chatFontSize") private var fontSize: Int = 14
    @AppStorage("chatFontFamily") private var fontFamily: String = "system"

    /// Font families with display name, lookup ID, and whether it's a monospace font.
    /// Uses actual macOS font family names for reliable lookup.
    private let fontFamilies: [(name: String, id: String, monospace: Bool)] = [
        ("System Default", "system", false),
        ("SF Pro", "SF Pro", false),
        ("SF Mono", "SF Mono", true),
        ("New York", "New York", false),
        ("Menlo", "Menlo", true),
        ("Monaco", "Monaco", true),
        ("JetBrains Mono", "JetBrains Mono", true),
        ("Fira Code", "Fira Code", true),
        ("Source Code Pro", "Source Code Pro", true)
    ]

    /// Check if a font family is installed on the system.
    private func isFontAvailable(_ familyName: String) -> Bool {
        guard familyName != "system" else { return true }
        return NSFontManager.shared.availableFontFamilies.contains(familyName)
    }

    /// Returns the Homebrew cask name for installable fonts.
    private func brewCaskName(for fontFamily: String) -> String? {
        switch fontFamily {
        case "JetBrains Mono": return "font-jetbrains-mono"
        case "Fira Code": return "font-fira-code"
        case "Source Code Pro": return "font-source-code-pro"
        default: return nil
        }
    }

    /// Opens Terminal and runs the Homebrew font install command.
    private func installFont(cask: String) {
        let script = "brew install --cask \(cask)"

        // Create AppleScript to open Terminal and run the command
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(script)"
        end tell
        """

        if let scriptObject = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)

            if error != nil {
                // Fallback: copy command to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(script, forType: .string)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Typography Section
                FormSection(
                    title: "Typography",
                    description: "Customize the appearance of chat messages"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Font Family
                        HStack {
                            Text("Font Family")
                                .dsTextStyle(.body)
                            Spacer()
                            Picker("Font Family", selection: $fontFamily) {
                                ForEach(fontFamilies, id: \.id) { family in
                                    if isFontAvailable(family.id) {
                                        Text(family.name).tag(family.id)
                                    } else {
                                        Text("\(family.name) (not installed)")
                                            .foregroundStyle(.secondary)
                                            .tag(family.id)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 200)

                            // Install button for missing fonts with known Homebrew casks
                            if !isFontAvailable(fontFamily),
                               let cask = brewCaskName(for: fontFamily) {
                                Button("Install") {
                                    installFont(cask: cask)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        // Font Size
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            HStack {
                                Text("Font Size")
                                    .dsTextStyle(.body)
                                Spacer()
                                Text("\(fontSize) pt")
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(fontSize) },
                                    set: { fontSize = Int($0) }
                                ),
                                in: 10...24,
                                step: 1
                            )
                        }

                        // Preview
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            HStack {
                                Text("Preview")
                                    .dsTextStyle(.caption, color: .ds.secondary)
                                if !isFontAvailable(fontFamily) {
                                    Text("— using fallback")
                                        .dsTextStyle(.caption, color: .ds.warning)
                                }
                            }

                            Text("The quick brown fox jumps over the lazy dog. 0123456789")
                                .font(previewFont)
                                .padding(DSSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.ds.surface.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                // Input Behavior
                FormSection(
                    title: "Input Behavior",
                    description: "Choose how to send messages from the input field"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack {
                            Text("Send Message Key")
                                .dsTextStyle(.body)
                            Spacer()
                            Picker("Send Key", selection: $sendKey) {
                                Text("Enter").tag("enter")
                                Text("Cmd+Enter").tag("cmd+enter")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 200)
                        }

                        Text(sendKey == "enter"
                            ? "Press Enter to send, Shift+Enter for new line"
                            : "Press Cmd+Enter to send, Enter for new line"
                        )
                        .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Display Options
                FormSection(
                    title: "Display",
                    description: "Control what information appears in the chat"
                ) {
                    GlassToggle(
                        "Show estimated cost",
                        isOn: $showCost,
                        description: "Display token usage and cost estimates for each message"
                    )

                    GlassToggle(
                        "Show timestamps",
                        isOn: $showTimestamps,
                        description: "Display time sent for each message"
                    )
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Computed Properties

    /// Returns a Font that actually renders the selected font family.
    /// Uses NSFont for reliable font lookup and falls back to system monospace
    /// if the requested font isn't installed.
    private var previewFont: Font {
        let size = CGFloat(fontSize)

        if fontFamily == "system" {
            return .system(size: size)
        }

        // Check if font family exists using NSFontManager
        if NSFontManager.shared.availableFontFamilies.contains(fontFamily),
           let nsFont = NSFont(name: fontFamily, size: size) {
            return Font(nsFont)
        }

        // Fallback: system monospace for code fonts, system default otherwise
        let isMonospace = fontFamilies.first { $0.id == fontFamily }?.monospace ?? false
        return isMonospace ? .system(size: size, design: .monospaced) : .system(size: size)
    }
}

#Preview {
    ChatSettingsView()
        .frame(width: 600, height: 600)
        .background(Color.ds.bg0)
}
