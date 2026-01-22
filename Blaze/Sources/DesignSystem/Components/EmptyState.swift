import SwiftUI

// MARK: - Empty State

/// A placeholder view for empty/zero states.
/// Displays an icon, title, description, and optional action.
public struct EmptyState: View {
    let icon: String
    let title: String
    let description: String?
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        description: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: DSSize.xxl))
                .foregroundStyle(Color.ds.tertiary)
                .frame(width: DSSize.huge, height: DSSize.huge)
                .background(
                    Circle()
                        .fill(Color.ds.foreground.opacity(0.05))
                )

            // Text content
            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .dsTextStyle(.subtitle)
                    .multilineTextAlignment(.center)

                if let description = description {
                    Text(description)
                        .dsTextStyle(.body, color: .ds.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }

            // Action button
            if let actionTitle = actionTitle, let action = action {
                GlassButton(actionTitle, style: .primary, size: .medium, action: action)
                    .padding(.top, DSSpacing.xs)
            }
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Convenience Initializers

public extension EmptyState {
    /// Create an empty state for no search results.
    static func noResults(query: String, action: (() -> Void)? = nil) -> EmptyState {
        EmptyState(
            icon: "magnifyingglass",
            title: "No Results",
            description: "No results found for \"\(query)\". Try a different search term.",
            actionTitle: action != nil ? "Clear Search" : nil,
            action: action
        )
    }

    /// Create an empty state for no items.
    static func noItems(
        itemName: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> EmptyState {
        EmptyState(
            icon: "tray",
            title: "No \(itemName)",
            description: "You don't have any \(itemName.lowercased()) yet.",
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Create an empty state for no connection.
    static func noConnection(retryAction: @escaping () -> Void) -> EmptyState {
        EmptyState(
            icon: "wifi.slash",
            title: "No Connection",
            description: "Please check your internet connection and try again.",
            actionTitle: "Retry",
            action: retryAction
        )
    }
}

// MARK: - Compact Empty State

/// A smaller, inline empty state for constrained spaces.
public struct CompactEmptyState: View {
    let icon: String
    let message: String

    public init(icon: String, message: String) {
        self.icon = icon
        self.message = message
    }

    public var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DSSize.sm))
                .foregroundStyle(Color.ds.tertiary)

            Text(message)
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty States") {
    VStack(spacing: DSSpacing.xl) {
        EmptyState(
            icon: "folder",
            title: "No Sessions",
            description: "Start a new session to begin coding with AI assistance.",
            actionTitle: "New Session"
        ) {
            print("New session")
        }
        .frame(height: 300)
        .dsGlassPanel(level: .subtle)

        EmptyState.noResults(query: "test query") {
            print("Clear search")
        }
        .frame(height: 250)

        CompactEmptyState(icon: "doc.text", message: "No files selected")
    }
    .padding(DSSpacing.lg)
    .background(Color.ds.bg0)
}
#endif
