import SwiftUI

// MARK: - Theme Preview Panel

/// A rich, realistic preview panel that demonstrates theme colors in context.
/// Shows sample chat bubbles, tool cards, code blocks, buttons, and state indicators.
/// Designed for ~300-400pt width with flexible height.
public struct ThemePreviewPanel: View {
    let colors: ResolvedThemeColors

    public init(colors: ResolvedThemeColors) {
        self.colors = colors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Chat Messages Section
            chatMessagesSection

            // Tool Card Section
            toolCardSection

            // Code Block Section
            codeBlockSection

            // Buttons Section
            buttonsSection

            // Text Hierarchy Section
            textHierarchySection

            // State Indicators Section
            stateIndicatorsSection

            // Glass Panel Section
            glassPanelSection
        }
        .padding(DSSpacing.lg)
        .background(colors.background)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    // MARK: - Chat Messages

    private var chatMessagesSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            sectionHeader("Chat")

            // User message (right-aligned)
            HStack {
                Spacer()
                Text("How do I fix this bug?")
                    .font(DSTextStyle.body.font)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .background(colors.accent.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(colors.accent.opacity(0.4), lineWidth: 1)
                    )
            }

            // Assistant message (left-aligned)
            HStack {
                Text("Let me check the code...")
                    .font(DSTextStyle.body.font)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(colors.border, lineWidth: 1)
                    )
                Spacer()
            }
        }
    }

    // MARK: - Tool Card

    private var toolCardSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            sectionHeader("Tool")

            HStack(spacing: DSSpacing.sm) {
                // Document icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colors.accent)
                    .frame(width: DSSize.md, height: DSSize.md)
                    .background(colors.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Read file")
                        .font(DSTextStyle.caption.font)
                        .fontWeight(.medium)
                        .foregroundStyle(colors.textPrimary)

                    Text("src/main.swift")
                        .font(DSTextStyle.monoSmall.font)
                        .foregroundStyle(colors.textSecondary)
                }

                Spacer()

                // Completion checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(colors.success)
            }
            .padding(DSSpacing.sm)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Code Block

    private var codeBlockSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            sectionHeader("Code")

            VStack(alignment: .leading, spacing: 0) {
                // Code header
                HStack {
                    Text("main.swift")
                        .font(DSTextStyle.monoSmall.font)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(colors.surfaceHover)

                // Code content with syntax highlighting
                VStack(alignment: .leading, spacing: 2) {
                    codeLineView(lineNumber: 1, content: syntaxHighlightedFunc)
                    codeLineView(lineNumber: 2, content: syntaxHighlightedPrint)
                    codeLineView(lineNumber: 3, content: syntaxHighlightedBrace)
                }
                .padding(DSSpacing.sm)
            }
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(colors.border, lineWidth: 1)
            )
        }
    }

    private func codeLineView(lineNumber: Int, content: some View) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.xs) {
            Text("\(lineNumber)")
                .font(DSTextStyle.monoSmall.font)
                .foregroundStyle(colors.textMuted)
                .frame(width: 16, alignment: .trailing)

            content
        }
    }

    // Syntax highlighted: func hello() {
    private var syntaxHighlightedFunc: some View {
        HStack(spacing: 0) {
            Text("func")
                .foregroundStyle(syntaxKeyword)
            Text(" hello() {")
                .foregroundStyle(colors.textPrimary)
        }
        .font(DSTextStyle.monoSmall.font)
    }

    // Syntax highlighted:     print("world")
    private var syntaxHighlightedPrint: some View {
        HStack(spacing: 0) {
            Text("    print(")
                .foregroundStyle(colors.textPrimary)
            Text("\"world\"")
                .foregroundStyle(syntaxString)
            Text(")")
                .foregroundStyle(colors.textPrimary)
        }
        .font(DSTextStyle.monoSmall.font)
    }

    // Closing brace: }
    private var syntaxHighlightedBrace: some View {
        Text("}")
            .font(DSTextStyle.monoSmall.font)
            .foregroundStyle(colors.textPrimary)
    }

    // Syntax highlighting colors derived from theme
    private var syntaxKeyword: Color {
        // Keywords get accent color (purple/blue tint)
        colors.accent
    }

    private var syntaxString: Color {
        // Strings get success color (green tint)
        colors.success
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            sectionHeader("Buttons")

            HStack(spacing: DSSpacing.sm) {
                // Primary button
                previewButton(
                    title: "Save",
                    background: colors.accent,
                    foreground: .white,
                    borderColor: nil
                )

                // Secondary button
                previewButton(
                    title: "Cancel",
                    background: colors.surface,
                    foreground: colors.textSecondary,
                    borderColor: colors.border
                )

                // Destructive button
                previewButton(
                    title: "Delete",
                    background: colors.error.opacity(0.15),
                    foreground: colors.error,
                    borderColor: colors.error.opacity(0.4)
                )
            }
        }
    }

    private func previewButton(
        title: String,
        background: Color,
        foreground: Color,
        borderColor: Color?
    ) -> some View {
        Text(title)
            .font(DSTextStyle.caption.font)
            .fontWeight(.medium)
            .foregroundStyle(foreground)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
            .overlay {
                if let borderColor {
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
    }

    // MARK: - Text Hierarchy

    private var textHierarchySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            sectionHeader("Text")

            Text("Primary text")
                .font(DSTextStyle.body.font)
                .foregroundStyle(colors.textPrimary)

            Text("Secondary text")
                .font(DSTextStyle.caption.font)
                .foregroundStyle(colors.textSecondary)

            Text("Muted text")
                .font(DSTextStyle.micro.font)
                .foregroundStyle(colors.textMuted)
        }
    }

    // MARK: - State Indicators

    private var stateIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            sectionHeader("States")

            HStack(spacing: DSSpacing.lg) {
                stateIndicator(color: colors.success, label: "Success")
                stateIndicator(color: colors.warning, label: "Warning")
                stateIndicator(color: colors.error, label: "Error")
            }
        }
    }

    private func stateIndicator(color: Color, label: String) -> some View {
        HStack(spacing: DSSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(DSTextStyle.micro.font)
                .foregroundStyle(colors.textSecondary)
        }
    }

    // MARK: - Glass Panel

    private var glassPanelSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            sectionHeader("Glass")

            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.accent)

                Text("Floating panel with blur")
                    .font(DSTextStyle.caption.font)
                    .foregroundStyle(colors.textSecondary)

                Spacer()
            }
            .padding(DSSpacing.sm)
            .background {
                ZStack {
                    // Glass effect simulation
                    colors.surface.opacity(0.7)

                    // Subtle gradient overlay for glass depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                colors.border,
                                Color.black.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DSTextStyle.micro.font)
            .fontWeight(.semibold)
            .foregroundStyle(colors.textMuted)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Preview

#if DEBUG
struct ThemePreviewPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Nebula theme preview
            ThemePreviewPanel(colors: ThemeColors.nebula.resolved(with: DSColors.self))
                .frame(width: 340)
                .padding()
                .background(Color(hex: "#0A1020") ?? .black)
                .previewDisplayName("Nebula")

            // Hyperion theme preview
            ThemePreviewPanel(colors: ThemeColors.hyperion.resolved(with: DSColors.self))
                .frame(width: 340)
                .padding()
                .background(Color(hex: "#0D0B14") ?? .black)
                .previewDisplayName("Hyperion")
        }
    }
}
#endif
