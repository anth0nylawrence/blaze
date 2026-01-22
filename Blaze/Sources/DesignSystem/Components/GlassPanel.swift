import SwiftUI

// MARK: - Glass Panel

/// A premium glass-styled container with configurable material, borders, and animations.
/// The foundation component for the Blaze glass aesthetic.
public struct GlassPanel<Content: View>: View {
    let level: DSGlassLevel
    let cornerRadius: CGFloat
    let elevation: DSElevation
    let border: DSGlassBorder
    let padding: EdgeInsets
    let isInteractive: Bool
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @State private var isPressed = false

    public init(
        level: DSGlassLevel = .regular,
        cornerRadius: CGFloat = DSRadius.lg,
        elevation: DSElevation = .medium,
        border: DSGlassBorder = .standard,
        padding: EdgeInsets = EdgeInsets(top: DSSpacing.md, leading: DSSpacing.md, bottom: DSSpacing.md, trailing: DSSpacing.md),
        isInteractive: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.level = level
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.border = border
        self.padding = padding
        self.isInteractive = isInteractive
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .dsGlassPanel(
                level: level,
                cornerRadius: cornerRadius,
                elevation: elevation,
                border: border,
                isInteractive: isInteractive
            )
    }
}

// MARK: - Convenience Initializers

public extension GlassPanel {
    /// Create a compact glass panel with smaller padding.
    static func compact(
        level: DSGlassLevel = .regular,
        @ViewBuilder content: @escaping () -> Content
    ) -> GlassPanel {
        GlassPanel(
            level: level,
            padding: EdgeInsets(top: DSSpacing.sm, leading: DSSpacing.sm, bottom: DSSpacing.sm, trailing: DSSpacing.sm),
            content: content
        )
    }

    /// Create a glass panel with no padding (content fills to edges).
    static func flush(
        level: DSGlassLevel = .regular,
        cornerRadius: CGFloat = DSRadius.lg,
        @ViewBuilder content: @escaping () -> Content
    ) -> GlassPanel {
        GlassPanel(
            level: level,
            cornerRadius: cornerRadius,
            padding: EdgeInsets(),
            content: content
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Glass Panel Levels") {
    HStack(spacing: DSSpacing.lg) {
        ForEach([DSGlassLevel.subtle, .light, .regular, .prominent, .solid], id: \.self) { level in
            GlassPanel(level: level) {
                VStack {
                    Text(level.rawValue.capitalized)
                        .dsTextStyle(.subtitle)
                    Text("Glass Panel")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }
                .frame(width: 100)
            }
        }
    }
    .padding(DSSpacing.xl)
    .background(
        LinearGradient(
            colors: [.purple, .blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Glass Panel Dark") {
    GlassPanel {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Premium Glass")
                .dsTextStyle(.title)
            Text("This panel demonstrates the glass aesthetic with layered borders and subtle depth.")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .frame(width: 300)
    }
    .padding(DSSpacing.xl)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
#endif
