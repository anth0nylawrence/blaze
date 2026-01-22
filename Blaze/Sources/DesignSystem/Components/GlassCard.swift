import SwiftUI

// MARK: - Glass Card

/// A content card with header, body, and optional footer sections.
/// Built on the glass aesthetic with configurable styling.
public struct GlassCard<Header: View, Content: View, Footer: View>: View {
    let level: DSGlassLevel
    let cornerRadius: CGFloat
    let showDividers: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    public init(
        level: DSGlassLevel = .regular,
        cornerRadius: CGFloat = DSRadius.lg,
        showDividers: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.level = level
        self.cornerRadius = cornerRadius
        self.showDividers = showDividers
        self.header = header
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header()
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
                .dsHairlineDivider(color: showDividers ? Color.ds.border.opacity(0.5) : .clear)

            // Content
            content()
                .padding(DSSpacing.md)

            // Footer
            footer()
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(Color.ds.foreground.opacity(0.02))
        }
        .dsGlassPanel(
            level: level,
            cornerRadius: cornerRadius,
            elevation: .medium,
            border: .standard
        )
    }
}

// MARK: - Convenience: Header + Content Only

public extension GlassCard where Footer == EmptyView {
    init(
        level: DSGlassLevel = .regular,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            level: level,
            header: header,
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Convenience: Content Only

public extension GlassCard where Header == EmptyView, Footer == EmptyView {
    init(
        level: DSGlassLevel = .regular,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            level: level,
            showDividers: false,
            header: { EmptyView() },
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Simple Card (Title + Subtitle)

/// A simplified card with just a title, subtitle, and icon.
public struct SimpleCard: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let action: (() -> Void)?

    @State private var isHovered = false

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = .accentColor,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: DSSize.lg))
                    .foregroundStyle(iconColor)
                    .frame(width: DSSize.xl, height: DSSize.xl)
                    .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .low)
            }

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .dsTextStyle(.subtitle)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .dsTextStyle(.caption, color: .ds.secondary)
                }
            }

            Spacer()

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.ds.tertiary)
            }
        }
        .padding(DSSpacing.md)
        .dsGlassPanel(
            level: .regular,
            cornerRadius: DSRadius.lg,
            elevation: isHovered ? .medium : .low,
            isInteractive: action != nil
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            action?()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Glass Card") {
    VStack(spacing: DSSpacing.lg) {
        GlassCard {
            HStack {
                Label("Settings", systemImage: "gear")
                    .dsTextStyle(.subtitle)
                Spacer()
            }
        } content: {
            Text("Configure your preferences and customize the application behavior.")
                .dsTextStyle(.body, color: .ds.secondary)
        } footer: {
            HStack {
                Spacer()
                GlassButton("Save", style: .primary, size: .small) {}
                GlassButton("Cancel", style: .ghost, size: .small) {}
            }
        }
        .frame(width: 400)

        SimpleCard(
            title: "Quick Action",
            subtitle: "Tap to perform this action",
            icon: "bolt.fill",
            iconColor: .orange
        ) {
            print("Tapped")
        }
        .frame(width: 400)
    }
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}
#endif
