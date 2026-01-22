import SwiftUI

// MARK: - Component Preview View

/// Preview container for individual components with state handling.
struct ComponentPreviewView: View {
    let componentId: String?
    let state: PreviewState

    var body: some View {
        if let componentId = componentId {
            VStack(spacing: DSSpacing.lg) {
                // Component name header
                HStack {
                    Text(componentId)
                        .dsTextStyle(.title)
                    Spacer()
                    Badge(state.rawValue, variant: badgeVariant(for: state), size: .small)
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)

                // Preview container
                previewContent(for: componentId)
                    .padding(DSSpacing.lg)

                Spacer()
            }
        } else {
            EmptyState(
                icon: "square.grid.2x2",
                title: "Select a Component",
                description: "Choose a component from the list to preview it."
            )
        }
    }

    @ViewBuilder
    private func previewContent(for id: String) -> some View {
        switch id {
        // Containers
        case "GlassPanel":
            GlassPanelPreview(state: state)
        case "GlassCard":
            GlassCardPreview(state: state)

        // Buttons
        case "GlassButton":
            GlassButtonPreview(state: state)
        case "GlassIconButton":
            GlassIconButtonPreview(state: state)

        // Indicators
        case "Badge":
            BadgePreview(state: state)
        case "DotIndicator":
            DotIndicatorPreview(state: state)
        case "CountBadge":
            CountBadgePreview(state: state)

        // States
        case "EmptyState":
            EmptyStatePreview(state: state)
        case "ErrorState":
            ErrorStatePreview(state: state)
        case "LoadingSkeleton":
            LoadingSkeletonPreview(state: state)

        // Form
        case "FormRow":
            FormRowPreview(state: state)
        case "GlassTextField":
            GlassTextFieldPreview(state: state)
        case "GlassToggle":
            GlassTogglePreview(state: state)

        // Navigation
        case "SidebarRow":
            SidebarRowPreview(state: state)

        default:
            Text("Preview not implemented for \(id)")
                .dsTextStyle(.body, color: .ds.secondary)
        }
    }

    private func badgeVariant(for state: PreviewState) -> BadgeVariant {
        switch state {
        case .loading: return .info
        case .empty: return .default
        case .error: return .error
        case .success: return .success
        case .edge: return .warning
        }
    }
}

// MARK: - Individual Component Previews

struct GlassPanelPreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Show different levels
            HStack(spacing: DSSpacing.md) {
                ForEach([DSGlassLevel.subtle, .light, .regular, .prominent, .solid], id: \.self) { level in
                    GlassPanel(level: level) {
                        VStack {
                            Text(level.rawValue.capitalized)
                                .dsTextStyle(.caption)
                            Text("Panel")
                                .dsTextStyle(.micro, color: .ds.secondary)
                        }
                        .frame(width: 80)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(colors: [.purple, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
        }
    }
}

struct GlassCardPreview: View {
    let state: PreviewState

    var body: some View {
        GlassCard {
            HStack {
                Label("Card Header", systemImage: "doc.fill")
                    .dsTextStyle(.subtitle)
                Spacer()
            }
        } content: {
            switch state {
            case .loading:
                TextSkeleton(lines: 3)
            case .empty:
                Text("No content available")
                    .dsTextStyle(.body, color: .ds.secondary)
            case .error:
                Text("Failed to load content")
                    .dsTextStyle(.body, color: .ds.negative)
            case .success:
                Text("This is sample card content demonstrating the glass aesthetic.")
                    .dsTextStyle(.body, color: .ds.secondary)
            case .edge:
                Text(String(repeating: "Long text content. ", count: 20))
                    .dsTextStyle(.body, color: .ds.secondary)
            }
        } footer: {
            HStack {
                Spacer()
                GlassButton("Action", style: .primary, size: .small) {}
            }
        }
        .frame(width: 400)
    }
}

struct GlassButtonPreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Styles
            HStack(spacing: DSSpacing.md) {
                GlassButton("Primary", icon: "star.fill", action: {})
                GlassButton("Secondary", style: .secondary, action: {})
                GlassButton("Ghost", style: .ghost, action: {})
                GlassButton("Destructive", style: .destructive, action: {})
            }

            // Sizes
            HStack(spacing: DSSpacing.md) {
                GlassButton("Small", size: .small, action: {})
                GlassButton("Medium", size: .medium, action: {})
                GlassButton("Large", size: .large, action: {})
            }

            // States
            HStack(spacing: DSSpacing.md) {
                GlassButton("Loading", isLoading: state == .loading, action: {})
                GlassButton("Disabled", isDisabled: state == .error, action: {})
            }
        }
    }
}

struct GlassIconButtonPreview: View {
    let state: PreviewState

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            GlassIconButton(icon: "plus", action: {})
            GlassIconButton(icon: "gear", style: .secondary, action: {})
            GlassIconButton(icon: "xmark", style: .ghost, action: {})
            GlassIconButton(icon: "trash", style: .destructive, action: {})
        }
    }
}

struct BadgePreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            HStack(spacing: DSSpacing.sm) {
                Badge("Default")
                Badge("Primary", variant: .primary)
                Badge("Success", icon: "checkmark", variant: .success)
                Badge("Warning", variant: .warning)
                Badge("Error", variant: .error)
            }

            HStack(spacing: DSSpacing.sm) {
                Badge("Small", size: .small)
                Badge("Medium", size: .medium)
                Badge("Large", size: .large)
            }
        }
    }
}

struct DotIndicatorPreview: View {
    let state: PreviewState

    var body: some View {
        HStack(spacing: DSSpacing.lg) {
            VStack(spacing: DSSpacing.xs) {
                DotIndicator(color: .green)
                Text("Online").dsTextStyle(.caption)
            }
            VStack(spacing: DSSpacing.xs) {
                DotIndicator(color: .orange)
                Text("Away").dsTextStyle(.caption)
            }
            VStack(spacing: DSSpacing.xs) {
                DotIndicator(color: .red, isPulsing: state == .loading)
                Text("Busy").dsTextStyle(.caption)
            }
        }
    }
}

struct CountBadgePreview: View {
    let state: PreviewState

    var body: some View {
        HStack(spacing: DSSpacing.lg) {
            CountBadge(3)
            CountBadge(42)
            CountBadge(150)
            CountBadge(5, variant: .error)
        }
    }
}

struct EmptyStatePreview: View {
    let state: PreviewState

    var body: some View {
        EmptyState(
            icon: "folder",
            title: "No Sessions",
            description: "Start a new session to begin coding with AI assistance.",
            actionTitle: "New Session"
        ) {}
        .frame(height: 300)
        .dsGlassPanel(level: .subtle)
    }
}

struct ErrorStatePreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ErrorState(
                severity: state == .edge ? .critical : .error,
                title: "Connection Failed",
                message: "Unable to connect to the server. Please check your network.",
                retryAction: {}
            )
            .frame(height: 280)
            .dsGlassPanel(level: .subtle)

            DSErrorBanner(severity: .warning, message: "This is a warning banner", dismissAction: {})
        }
        .frame(width: 400)
    }
}

struct LoadingSkeletonPreview: View {
    let state: PreviewState

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            HStack(spacing: DSSpacing.md) {
                LoadingSkeleton(width: 100, height: 20)
                LoadingSkeleton(width: 40, height: 40, shape: .circle)
                LoadingSkeleton(width: 80, height: 24, shape: .capsule)
            }

            CardSkeleton()
                .frame(width: 350)

            MessageSkeleton(lines: 2)
                .frame(width: 350)
        }
    }
}

struct FormRowPreview: View {
    let state: PreviewState
    @State private var text = ""

    var body: some View {
        FormSection(title: "Account", description: "Manage your account") {
            FormRow(
                label: "Username",
                helpText: "Your unique identifier",
                isRequired: true,
                errorMessage: state == .error ? "Username is required" : nil
            ) {
                GlassTextField("Enter username", text: $text, icon: "person")
            }
        }
        .frame(width: 400)
    }
}

struct GlassTextFieldPreview: View {
    let state: PreviewState
    @State private var text = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            GlassTextField("Enter text", text: $text, icon: "magnifyingglass")
            GlassTextField("Password", text: $password, icon: "lock", isSecure: true)
        }
        .frame(width: 300)
    }
}

struct GlassTogglePreview: View {
    let state: PreviewState
    @State private var isOn = true

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            GlassToggle("Enable notifications", isOn: $isOn, description: "Receive updates about your sessions")
            GlassToggle("Dark mode", isOn: .constant(false))
        }
        .frame(width: 300)
    }
}

struct SidebarRowPreview: View {
    let state: PreviewState
    @State private var selected = "current"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionHeader("Sessions") {}

            SidebarRow(
                icon: "message.fill",
                title: "Current Session",
                subtitle: "3 messages",
                badge: "Active",
                badgeVariant: .success,
                isSelected: selected == "current"
            ) { selected = "current" }

            SidebarRow(
                icon: "message",
                title: "Previous Session",
                isSelected: selected == "previous"
            ) { selected = "previous" }

            SidebarDivider()

            SidebarRow(
                icon: "folder",
                title: "Project",
                badge: "12",
                isSelected: selected == "project"
            ) { selected = "project" }
        }
        .frame(width: 250)
        .background(Color.ds.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
    }
}
