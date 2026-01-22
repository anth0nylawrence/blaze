import SwiftUI

// MARK: - Effects Lab View

/// Interactive controls for testing glass effects and visual parameters.
struct EffectsLabView: View {
    @Binding var glassLevel: DSGlassLevel
    @Binding var elevation: DSElevation
    @Binding var showNoise: Bool

    @State private var customBlurRadius: CGFloat = 20
    @State private var borderOpacity: Double = 0.15
    @State private var highlightOpacity: Double = 0.12

    var body: some View {
        HStack(spacing: 0) {
            // Controls panel
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    // Glass Level
                    FormSection(title: "Glass Material", description: "Adjust the glass panel material intensity") {
                        Picker("Level", selection: $glassLevel) {
                            ForEach(DSGlassLevel.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            Text("Current: \(glassLevel.rawValue.capitalized)")
                                .dsTextStyle(.caption, color: .ds.secondary)
                            Text("Blur: \(Int(glassLevel.blurRadius))pt")
                                .dsTextStyle(.micro, color: .ds.tertiary)
                        }
                    }

                    // Custom Blur
                    FormSection(title: "Custom Blur", description: "Override blur radius manually") {
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            HStack {
                                Text("Radius")
                                    .dsTextStyle(.caption)
                                Spacer()
                                Text("\(Int(customBlurRadius))pt")
                                    .dsTextStyle(.monoSmall, color: .ds.secondary)
                            }
                            Slider(value: $customBlurRadius, in: 0...60)
                        }
                    }

                    // Elevation
                    FormSection(title: "Elevation", description: "Shadow depth level") {
                        Picker("Elevation", selection: $elevation) {
                            ForEach(DSElevation.allCases, id: \.self) { level in
                                Text(String(describing: level).capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Border Effects
                    FormSection(title: "Border Effects", description: "Glass panel border styling") {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                HStack {
                                    Text("Border Opacity")
                                        .dsTextStyle(.caption)
                                    Spacer()
                                    Text("\(Int(borderOpacity * 100))%")
                                        .dsTextStyle(.monoSmall, color: .ds.secondary)
                                }
                                Slider(value: $borderOpacity, in: 0...0.5)
                            }

                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                HStack {
                                    Text("Highlight Opacity")
                                        .dsTextStyle(.caption)
                                    Spacer()
                                    Text("\(Int(highlightOpacity * 100))%")
                                        .dsTextStyle(.monoSmall, color: .ds.secondary)
                                }
                                Slider(value: $highlightOpacity, in: 0...0.3)
                            }
                        }
                    }

                    // Noise Effect
                    FormSection(title: "Noise/Grain", description: "Subtle texture overlay") {
                        GlassToggle("Enable Noise", isOn: $showNoise, description: "Adds subtle grain to prevent color banding")
                    }
                }
                .padding(DSSpacing.lg)
            }
            .frame(width: 350)

            Divider()

            // Live preview panel
            ZStack {
                // Gradient background to show glass effect
                LinearGradient(
                    colors: [.purple, .blue, .cyan, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: DSSpacing.xl) {
                    Text("Glass Effect Preview")
                        .dsTextStyle(.title, color: .white)
                        .shadow(radius: 4)

                    // Preview panels at different levels
                    HStack(spacing: DSSpacing.lg) {
                        effectPreviewPanel(title: "Selected Level", level: glassLevel)
                    }

                    // All levels comparison
                    HStack(spacing: DSSpacing.md) {
                        ForEach(DSGlassLevel.allCases, id: \.self) { level in
                            VStack(spacing: DSSpacing.xs) {
                                effectMiniPanel(level: level)
                                Text(level.rawValue.capitalized)
                                    .dsTextStyle(.micro, color: .white)
                                    .shadow(radius: 2)
                            }
                        }
                    }

                    // Interactive panel
                    interactivePanel

                    // Button showcase
                    HStack(spacing: DSSpacing.md) {
                        GlassButton("Primary", icon: "star.fill", action: {})
                        GlassButton("Secondary", style: .secondary, action: {})
                    }
                }
                .padding(DSSpacing.xl)
            }
        }
    }

    private func effectPreviewPanel(title: String, level: DSGlassLevel) -> some View {
        VStack(spacing: DSSpacing.sm) {
            Text(title)
                .dsTextStyle(.subtitle)

            Text("This panel demonstrates the glass material at the '\(level.rawValue)' level with configurable elevation and border effects.")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: DSSpacing.sm) {
                Badge("Glass", variant: .primary)
                Badge("Effect", variant: .default)
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 300)
        .dsGlassPanel(
            level: level,
            cornerRadius: DSRadius.xl,
            elevation: elevation,
            border: .layered
        )
    }

    private func effectMiniPanel(level: DSGlassLevel) -> some View {
        RoundedRectangle(cornerRadius: DSRadius.md)
            .fill(level.material)
            .frame(width: 60, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(level.highlightOpacity), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .dsElevation(elevation)
    }

    private var interactivePanel: some View {
        VStack(spacing: DSSpacing.md) {
            Text("Interactive")
                .dsTextStyle(.subtitle)

            Text("Hover over this panel to see interaction states")
                .dsTextStyle(.caption, color: .ds.secondary)

            GlassButton("Hover Me", style: .secondary, action: {})
        }
        .padding(DSSpacing.lg)
        .frame(width: 250)
        .background(glassLevel.material)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(highlightOpacity),
                            .clear,
                            .black.opacity(borderOpacity * 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .dsElevation(elevation)
    }
}

// MARK: - Layouts Preview View

struct LayoutPreviewView: View {
    let layoutId: String?

    private let layouts: [(id: String, width: CGFloat, height: CGFloat)] = [
        ("compact", 800, 600),
        ("default", 1200, 800),
        ("wide", 1600, 900),
        ("ultrawide", 2100, 900),
    ]

    var body: some View {
        if let layoutId = layoutId,
           let layout = layouts.first(where: { $0.id == layoutId }) {
            VStack(spacing: DSSpacing.lg) {
                Text("\(layoutId.capitalized) Layout")
                    .dsTextStyle(.title)

                Text("\(Int(layout.width)) x \(Int(layout.height))")
                    .dsTextStyle(.subtitle, color: .ds.secondary)

                // Scaled preview placeholder
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(Color.ds.border, lineWidth: 2)
                    .aspectRatio(layout.width / layout.height, contentMode: .fit)
                    .frame(maxWidth: 600)
                    .overlay(
                        Text("App Preview")
                            .dsTextStyle(.body, color: .ds.tertiary)
                    )

                Text("Window size presets help test responsive layouts")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()
            }
            .padding(DSSpacing.xl)
        } else {
            EmptyState(
                icon: "rectangle.3.group",
                title: "Select a Layout",
                description: "Choose a layout preset to preview window dimensions."
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Effects Lab") {
    EffectsLabView(
        glassLevel: .constant(.regular),
        elevation: .constant(.medium),
        showNoise: .constant(false)
    )
    .frame(width: 1000, height: 700)
}
#endif
