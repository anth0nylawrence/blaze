//
//  ModelsSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

/// Settings view for model selection and sampling parameters.
/// Extracted from ChatSettingsView per F003 UX feedback.
struct ModelsSettingsView: View {
    @AppStorage("defaultModel") private var model: String = "sonnet"
    @AppStorage("thinkingLevel") private var thinkingLevel: Int = 2
    @AppStorage("temperature") private var temperature: Double = 1.0
    @AppStorage("topP") private var topP: Double = 1.0
    @AppStorage("maxTokens") private var maxTokens: Int = 8192

    private let modelOptions: [(name: String, id: String, description: String)] = [
        ("Claude Opus 4.5", "opus", "Most capable, best for complex reasoning"),
        ("Claude Sonnet 4.5", "sonnet", "Balanced performance and speed"),
        ("Claude Haiku 4.0", "haiku", "Fastest, best for simple tasks")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Model Selection
                FormSection(
                    title: "Default Model",
                    description: "Choose the Claude model for new conversations"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        ForEach(modelOptions, id: \.id) { option in
                            ModelSelectionRow(
                                name: option.name,
                                description: option.description,
                                isSelected: model == option.id
                            ) {
                                model = option.id
                            }
                        }
                    }
                }

                // Extended Thinking
                FormSection(
                    title: "Extended Thinking",
                    description: "Higher levels enable deeper reasoning at the cost of latency and tokens"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        HStack {
                            Text("Thinking Level")
                                .dsTextStyle(.body)
                            Spacer()
                            Text(thinkingLevelLabel)
                                .dsTextStyle(.body, color: .ds.secondary)
                        }

                        Picker("Thinking Level", selection: $thinkingLevel) {
                            Text("None").tag(0)
                            Text("Low").tag(1)
                            Text("Medium").tag(2)
                            Text("High").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text(thinkingLevelDescription)
                            .dsTextStyle(.caption, color: .ds.tertiary)
                    }
                }

                // Sampling Parameters
                FormSection(
                    title: "Sampling Parameters",
                    description: "Fine-tune model creativity and output diversity"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        // Temperature slider
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            HStack {
                                Text("Temperature")
                                    .dsTextStyle(.body)
                                Spacer()
                                Text(String(format: "%.2f", temperature))
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .monospacedDigit()
                            }

                            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)

                            Text("Lower = more focused and deterministic, Higher = more creative and varied")
                                .dsTextStyle(.caption, color: .ds.tertiary)
                        }

                        // Top-p slider
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            HStack {
                                Text("Top-p (nucleus sampling)")
                                    .dsTextStyle(.body)
                                Spacer()
                                Text(String(format: "%.2f", topP))
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .monospacedDigit()
                            }

                            Slider(value: $topP, in: 0.0...1.0, step: 0.01)

                            Text("Controls diversity by limiting token probability mass")
                                .dsTextStyle(.caption, color: .ds.tertiary)
                        }

                        // Max tokens
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            HStack {
                                Text("Max Output Tokens")
                                    .dsTextStyle(.body)
                                Spacer()
                                Text("\(maxTokens)")
                                    .dsTextStyle(.body, color: .ds.secondary)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(maxTokens) },
                                    set: { maxTokens = Int($0) }
                                ),
                                in: 1024...32768,
                                step: 1024
                            )

                            Text("Maximum tokens in model response (affects cost)")
                                .dsTextStyle(.caption, color: .ds.tertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Computed Properties

    private var thinkingLevelLabel: String {
        switch thinkingLevel {
        case 0: return "None"
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "Unknown"
        }
    }

    private var thinkingLevelDescription: String {
        switch thinkingLevel {
        case 0: return "Standard response without extended thinking"
        case 1: return "Brief reasoning before responding (~1-2 seconds extra)"
        case 2: return "Moderate reasoning for complex tasks (~3-5 seconds extra)"
        case 3: return "Deep reasoning for difficult problems (~10+ seconds extra)"
        default: return ""
        }
    }
}

// MARK: - Model Selection Row

private struct ModelSelectionRow: View {
    let name: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            // Selection indicator
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.accentColor : Color.ds.border, lineWidth: 2)
                    .frame(width: 20, height: 20)

                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .dsTextStyle(.body)
                    .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.secondary)

                Text(description)
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }

            Spacer()
        }
        .padding(DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.ds.surface.opacity(0.5) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    ModelsSettingsView()
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}
