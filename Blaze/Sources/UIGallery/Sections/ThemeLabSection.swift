import SwiftUI

// MARK: - Theme Lab View

/// Interactive controls for testing theme variations.
struct ThemeLabView: View {
    @Binding var isDarkMode: Bool
    @Binding var accentHue: Double

    // Accent color presets
    private let accentPresets: [(name: String, hue: Double, color: Color)] = [
        ("Blue", 0.6, .blue),
        ("Purple", 0.75, .purple),
        ("Pink", 0.9, .pink),
        ("Red", 0.0, .red),
        ("Orange", 0.08, .orange),
        ("Green", 0.35, .green),
        ("Teal", 0.5, .teal),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Controls panel
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    // Color Scheme
                    FormSection(title: "Color Scheme", description: "Toggle between light and dark mode") {
                        GlassToggle("Dark Mode", isOn: $isDarkMode, description: "Enable dark color scheme")
                    }

                    // Accent Color
                    FormSection(title: "Accent Color", description: "Customize the primary accent color") {
                        // Hue slider
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Text("Custom Hue")
                                .dsTextStyle(.caption, color: .ds.secondary)

                            HStack {
                                Slider(value: $accentHue, in: 0...1)
                                    .tint(Color(hue: accentHue, saturation: 0.8, brightness: 0.9))

                                Circle()
                                    .fill(Color(hue: accentHue, saturation: 0.8, brightness: 0.9))
                                    .frame(width: 24, height: 24)
                            }
                        }

                        // Preset colors
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Text("Presets")
                                .dsTextStyle(.caption, color: .ds.secondary)

                            HStack(spacing: DSSpacing.sm) {
                                ForEach(accentPresets, id: \.hue) { preset in
                                    Button {
                                        withAnimation {
                                            accentHue = preset.hue
                                        }
                                    } label: {
                                        Circle()
                                            .fill(preset.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.ds.foreground, lineWidth: abs(accentHue - preset.hue) < 0.05 ? 2 : 0)
                                                    .padding(2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .help(preset.name)
                                }
                            }
                        }
                    }

                    // Color Palette Preview
                    FormSection(title: "Color Palette", description: "Current semantic colors") {
                        VStack(spacing: DSSpacing.sm) {
                            colorRow("Background 0", Color.ds.bg0)
                            colorRow("Background 1", Color.ds.bg1)
                            colorRow("Panel", Color.ds.panel)
                            colorRow("Surface", Color.ds.surface)

                            Divider()

                            colorRow("Foreground", Color.ds.foreground)
                            colorRow("Secondary", Color.ds.secondary)
                            colorRow("Tertiary", Color.ds.tertiary)

                            Divider()

                            colorRow("Border", Color.ds.border)
                            colorRow("Accent", Color.ds.accent)

                            Divider()

                            colorRow("Positive", Color.ds.positive)
                            colorRow("Warning", Color.ds.warning)
                            colorRow("Negative", Color.ds.negative)
                        }
                    }
                }
                .padding(DSSpacing.lg)
            }
            .frame(width: 350)

            Divider()

            // Live preview panel
            VStack(spacing: DSSpacing.lg) {
                Text("Live Preview")
                    .dsTextStyle(.subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Sample UI
                GlassCard {
                    HStack {
                        Label("Sample Card", systemImage: "star.fill")
                            .dsTextStyle(.subtitle)
                        Spacer()
                        Badge("New", variant: .primary)
                    }
                } content: {
                    Text("This card demonstrates how your theme choices affect the UI appearance across different components.")
                        .dsTextStyle(.body, color: .ds.secondary)
                } footer: {
                    HStack {
                        Spacer()
                        GlassButton("Secondary", style: .secondary, size: .small) {}
                        GlassButton("Primary", style: .primary, size: .small) {}
                    }
                }

                // Buttons row
                HStack(spacing: DSSpacing.md) {
                    GlassButton("Primary", icon: "star.fill", action: {})
                    GlassButton("Secondary", style: .secondary, action: {})
                    GlassButton("Ghost", style: .ghost, action: {})
                }

                // Badges
                HStack(spacing: DSSpacing.sm) {
                    Badge("Default")
                    Badge("Primary", variant: .primary)
                    Badge("Success", variant: .success)
                    Badge("Warning", variant: .warning)
                    Badge("Error", variant: .error)
                }

                // Form elements
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    GlassTextField("Sample input", text: .constant(""), icon: "magnifyingglass")
                    GlassToggle("Sample toggle", isOn: .constant(true))
                }
                .frame(width: 280)

                Spacer()
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(Color.ds.bg0)
        }
    }

    private func colorRow(_ name: String, _ color: Color) -> some View {
        HStack {
            Text(name)
                .dsTextStyle(.caption)
            Spacer()
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .fill(color)
                .frame(width: 60, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .stroke(Color.ds.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Theme Lab") {
    ThemeLabView(isDarkMode: .constant(false), accentHue: .constant(0.6))
        .frame(width: 900, height: 700)
}
#endif
