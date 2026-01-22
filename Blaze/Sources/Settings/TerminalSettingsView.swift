//
//  TerminalSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import AppKit
import SwiftUI

struct TerminalSettingsView: View {
    @AppStorage("terminalBackend") private var backend: String = "swiftterm"
    @AppStorage("terminalFont") private var font: String = "SF Mono"
    @AppStorage("terminalFontSize") private var fontSize: Int = 12
    @AppStorage("terminalCursor") private var cursor: String = "block"
    @AppStorage("terminalScrollback") private var scrollback: Int = 10000

    /// Available monospace fonts from the system
    private var monospaceFonts: [String] {
        let fontManager = NSFontManager.shared
        return fontManager.availableFontFamilies.filter { family in
            // Check if this font family has a monospace trait
            if let font = NSFont(name: family, size: 12) {
                let traits = fontManager.traits(of: font)
                return traits.contains(.fixedPitchFontMask)
            }
            return false
        }.sorted()
    }

    /// Display name for backend with active indicator
    private func backendDisplayName(_ value: String) -> String {
        let name = value == "swiftterm" ? "SwiftTerm" : "Ghostty (Experimental)"
        return value == backend ? "\(name) (Active)" : name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                // Backend Section
                FormSection(
                    title: "Backend",
                    description: "Choose which terminal emulator backend to use"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        FormRow(label: "Terminal Backend") {
                            Picker("", selection: $backend) {
                                Text(backendDisplayName("swiftterm")).tag("swiftterm")
                                Text(backendDisplayName("ghostty")).tag("ghostty")
                            }
                            .pickerStyle(.menu)
                            .frame(minWidth: 200, alignment: .leading)
                            .disabled(backend == "ghostty")
                        }

                        if backend == "ghostty" {
                            Text("Ghostty integration is experimental and currently disabled")
                                .dsTextStyle(.caption, color: .ds.warning)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Font Section
                FormSection(
                    title: "Font",
                    description: "Configure terminal font family and size"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        FormRow(label: "Font Name") {
                            Picker("", selection: $font) {
                                ForEach(monospaceFonts, id: \.self) { fontName in
                                    Text(fontName)
                                        .font(.custom(fontName, size: 13))
                                        .tag(fontName)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minWidth: 200, alignment: .leading)
                        }

                        FormRow(label: "Font Size") {
                            HStack(spacing: DSSpacing.sm) {
                                Slider(value: Binding(
                                    get: { Double(fontSize) },
                                    set: { fontSize = Int($0) }
                                ), in: 8...24, step: 1)
                                .frame(width: 200)

                                Text("\(fontSize)pt")
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Cursor Section
                FormSection(
                    title: "Cursor",
                    description: "Choose your preferred cursor style"
                ) {
                    FormRow(label: "Cursor Style") {
                        Picker("", selection: $cursor) {
                            Text("Block").tag("block")
                            Text("Underline").tag("underline")
                            Text("Bar").tag("bar")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Scrollback Section
                FormSection(
                    title: "Scrollback",
                    description: "Number of lines to keep in terminal history"
                ) {
                    FormRow(
                        label: "Scrollback Lines",
                        helpText: "Valid range: 100-100,000"
                    ) {
                        GlassTextField("Lines", text: Binding(
                            get: { String(scrollback) },
                            set: {
                                if let value = Int($0) {
                                    scrollback = min(max(value, 100), 100_000)
                                }
                            }
                        ))
                        .frame(width: 100)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Preview Section
                FormSection(
                    title: "Preview",
                    description: "Preview your terminal font settings"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                            .font(.custom(font, size: CGFloat(fontSize)))
                        Text("abcdefghijklmnopqrstuvwxyz")
                            .font(.custom(font, size: CGFloat(fontSize)))
                        Text("0123456789 !@#$%^&*()_+-=[]{}|;:',.<>?")
                            .font(.custom(font, size: CGFloat(fontSize)))
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(.custom(font, size: CGFloat(fontSize)))
                    }
                    .padding(DSSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ds.surface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .strokeBorder(Color.ds.border, lineWidth: 1)
                    )
                }
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    TerminalSettingsView()
        .frame(width: 700, height: 600)
}
