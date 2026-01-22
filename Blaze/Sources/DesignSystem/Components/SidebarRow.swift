import SwiftUI

// MARK: - Sidebar Row

/// A styled row for sidebar navigation lists.
public struct SidebarRow: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let badge: String?
    let badgeVariant: BadgeVariant
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    public init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        badgeVariant: BadgeVariant = .default,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.badgeVariant = badgeVariant
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DSSize.sm))
                        .foregroundStyle(iconColor)
                        .frame(width: DSSize.md)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .dsTextStyle(.body, color: titleColor)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .dsTextStyle(.caption, color: .ds.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Badge
                if let badge = badge {
                    Badge(badge, variant: badgeVariant, size: .small)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        isSelected ? .accentColor : Color.ds.secondary
    }

    private var titleColor: Color {
        isSelected ? Color.ds.foreground : Color.ds.foreground
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.ds.foreground.opacity(0.05)
        }
        return .clear
    }
}

// MARK: - Sidebar Section Header

/// A styled section header for sidebar groupings.
public struct SidebarSectionHeader: View {
    let title: String
    let action: (() -> Void)?

    public init(_ title: String, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .dsTextStyle(.micro, color: .ds.tertiary)
                .tracking(0.5)

            Spacer()

            if let action = action {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
    }
}

// MARK: - Sidebar Divider

/// A styled divider for sidebar sections.
public struct SidebarDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.ds.border.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
    }
}

// MARK: - Expandable Sidebar Row

/// A sidebar row that can expand to show child items.
public struct ExpandableSidebarRow<Content: View>: View {
    let icon: String?
    let title: String
    let badge: String?
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    public init(
        icon: String? = nil,
        title: String,
        badge: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.badge = badge
        self._isExpanded = isExpanded
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DSSpacing.sm) {
                    // Disclosure indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.ds.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    // Icon
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: DSSize.sm))
                            .foregroundStyle(Color.ds.secondary)
                            .frame(width: DSSize.md)
                    }

                    Text(title)
                        .dsTextStyle(.body)
                        .lineLimit(1)

                    Spacer()

                    if let badge = badge {
                        Badge(badge, size: .small)
                    }
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                content()
                    .padding(.leading, DSSpacing.lg)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Sidebar Rows") {
    VStack(alignment: .leading, spacing: 0) {
        SidebarSectionHeader("Sessions") {
            print("Add")
        }

        SidebarRow(
            icon: "message.fill",
            title: "Current Session",
            subtitle: "3 messages",
            badge: "Active",
            badgeVariant: .success,
            isSelected: true
        ) {}

        SidebarRow(
            icon: "message",
            title: "Previous Session",
            subtitle: "Yesterday"
        ) {}

        SidebarRow(
            icon: "message",
            title: "Old Session"
        ) {}

        SidebarDivider()

        SidebarSectionHeader("Projects")

        SidebarRow(
            icon: "folder.fill",
            title: "Blaze",
            badge: "12"
        ) {}

        SidebarRow(
            icon: "folder",
            title: "Other Project"
        ) {}
    }
    .frame(width: 250)
    .padding(.vertical, DSSpacing.sm)
    .background(Color.ds.bg1)
}
#endif
