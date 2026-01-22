import SwiftUI

// MARK: - Gallery Section

/// Navigation sections in the UI Gallery.
public enum GallerySection: String, CaseIterable, Identifiable {
    case components = "Components"
    case screens = "Screens"
    case layouts = "Layouts"
    case themeLab = "Theme Lab"
    case effectsLab = "Effects Lab"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .components: return "square.grid.2x2"
        case .screens: return "rectangle.on.rectangle"
        case .layouts: return "rectangle.3.group"
        case .themeLab: return "paintpalette"
        case .effectsLab: return "wand.and.stars"
        }
    }

    var description: String {
        switch self {
        case .components: return "Design System components"
        case .screens: return "Feature screens"
        case .layouts: return "Window size presets"
        case .themeLab: return "Theme customization"
        case .effectsLab: return "Glass effects testing"
        }
    }
}

// MARK: - Preview State

/// State variants for component previews.
public enum PreviewState: String, CaseIterable, Identifiable {
    case loading = "Loading"
    case empty = "Empty"
    case error = "Error"
    case success = "Success"
    case edge = "Edge Case"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .loading: return "hourglass"
        case .empty: return "tray"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        case .edge: return "exclamationmark.triangle"
        }
    }
}

// MARK: - UI Gallery View

/// Main view for the UI Gallery - an in-app storybook for design system components.
public struct UIGalleryView: View {
    @State private var selectedSection: GallerySection = .components
    @State private var selectedItem: String?

    // Theme Lab state
    @State private var isDarkMode = false
    @State private var accentColorHue: Double = 0.6

    // Effects Lab state
    @State private var glassLevel: DSGlassLevel = .regular
    @State private var elevation: DSElevation = .medium
    @State private var showNoise: Bool = false

    // Preview state
    @State private var previewState: PreviewState = .success

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // Sidebar - Section navigation
            GallerySidebar(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } content: {
            // Content - Item list for selected section
            GalleryContentList(
                section: selectedSection,
                selectedItem: $selectedItem
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 320)
        } detail: {
            // Detail - Preview pane
            GalleryDetailView(
                section: selectedSection,
                itemId: selectedItem,
                previewState: $previewState,
                isDarkMode: $isDarkMode,
                accentHue: $accentColorHue,
                glassLevel: $glassLevel,
                elevation: $elevation,
                showNoise: $showNoise
            )
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .navigationTitle("UI Gallery")
    }
}

// MARK: - Gallery Sidebar

/// Navigation sidebar for section selection.
struct GallerySidebar: View {
    @Binding var selectedSection: GallerySection

    var body: some View {
        List(selection: $selectedSection) {
            Section("Catalog") {
                ForEach([GallerySection.components, .screens, .layouts], id: \.self) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Labs") {
                ForEach([GallerySection.themeLab, .effectsLab], id: \.self) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Gallery Content List

/// List of items within a section.
struct GalleryContentList: View {
    let section: GallerySection
    @Binding var selectedItem: String?

    var body: some View {
        List(selection: $selectedItem) {
            switch section {
            case .components:
                ComponentsListContent(selectedItem: $selectedItem)
            case .screens:
                ScreensListContent(selectedItem: $selectedItem)
            case .layouts:
                LayoutsListContent(selectedItem: $selectedItem)
            case .themeLab, .effectsLab:
                // Labs don't have item lists
                Text("Select options in the detail pane")
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Components List

struct ComponentsListContent: View {
    @Binding var selectedItem: String?

    private let components: [(category: String, items: [(id: String, name: String, icon: String)])] = [
        ("Containers", [
            ("GlassPanel", "Glass Panel", "square.fill"),
            ("GlassCard", "Glass Card", "rectangle.fill"),
        ]),
        ("Buttons", [
            ("GlassButton", "Glass Button", "hand.tap.fill"),
            ("GlassIconButton", "Icon Button", "circle.fill"),
        ]),
        ("Indicators", [
            ("Badge", "Badge", "seal.fill"),
            ("DotIndicator", "Dot Indicator", "circle.fill"),
            ("CountBadge", "Count Badge", "number.circle.fill"),
        ]),
        ("States", [
            ("EmptyState", "Empty State", "tray"),
            ("ErrorState", "Error State", "exclamationmark.triangle"),
            ("LoadingSkeleton", "Loading Skeleton", "rectangle.dashed"),
        ]),
        ("Form", [
            ("FormRow", "Form Row", "textformat"),
            ("GlassTextField", "Text Field", "character.cursor.ibeam"),
            ("GlassToggle", "Toggle", "switch.2"),
        ]),
        ("Navigation", [
            ("SidebarRow", "Sidebar Row", "sidebar.left"),
        ]),
    ]

    var body: some View {
        ForEach(components, id: \.category) { group in
            Section(group.category) {
                ForEach(group.items, id: \.id) { item in
                    Label(item.name, systemImage: item.icon)
                        .tag(item.id)
                }
            }
        }
    }
}

// MARK: - Screens List

struct ScreensListContent: View {
    @Binding var selectedItem: String?

    private let screens: [(id: String, name: String, icon: String)] = [
        ("ChatTimeline", "Chat Timeline", "bubble.left.and.bubble.right"),
        ("DiffViewer", "Diff Viewer", "doc.badge.plus"),
        ("Settings", "Settings", "gear"),
        ("SessionList", "Session List", "list.bullet"),
    ]

    var body: some View {
        ForEach(screens, id: \.id) { screen in
            Label(screen.name, systemImage: screen.icon)
                .tag(screen.id)
        }
    }
}

// MARK: - Layouts List

struct LayoutsListContent: View {
    @Binding var selectedItem: String?

    private let layouts: [(id: String, name: String, size: String)] = [
        ("compact", "Compact", "800 x 600"),
        ("default", "Default", "1200 x 800"),
        ("wide", "Wide", "1600 x 900"),
        ("ultrawide", "Ultrawide", "2100 x 900"),
    ]

    var body: some View {
        ForEach(layouts, id: \.id) { layout in
            HStack {
                Text(layout.name)
                Spacer()
                Text(layout.size)
                    .dsTextStyle(.caption, color: .ds.secondary)
            }
            .tag(layout.id)
        }
    }
}

// MARK: - Gallery Detail View

/// Detail pane showing the selected item or lab controls.
struct GalleryDetailView: View {
    let section: GallerySection
    let itemId: String?
    @Binding var previewState: PreviewState
    @Binding var isDarkMode: Bool
    @Binding var accentHue: Double
    @Binding var glassLevel: DSGlassLevel
    @Binding var elevation: DSElevation
    @Binding var showNoise: Bool

    var body: some View {
        VStack(spacing: 0) {
            // State picker (for components/screens)
            if section == .components || section == .screens {
                statePickerBar
                Divider()
            }

            // Main content
            ScrollView {
                switch section {
                case .components:
                    ComponentPreviewView(componentId: itemId, state: previewState)
                case .screens:
                    ScreenPreviewView(screenId: itemId, state: previewState)
                case .layouts:
                    LayoutPreviewView(layoutId: itemId)
                case .themeLab:
                    ThemeLabView(isDarkMode: $isDarkMode, accentHue: $accentHue)
                case .effectsLab:
                    EffectsLabView(
                        glassLevel: $glassLevel,
                        elevation: $elevation,
                        showNoise: $showNoise
                    )
                }
            }
        }
        .background(Color.ds.bg0)
    }

    private var statePickerBar: some View {
        HStack(spacing: DSSpacing.sm) {
            Text("State:")
                .dsTextStyle(.caption, color: .ds.secondary)

            Picker("State", selection: $previewState) {
                ForEach(PreviewState.allCases) { state in
                    Label(state.rawValue, systemImage: state.icon)
                        .tag(state)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)

            Spacer()
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(Color.ds.bg1)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("UI Gallery") {
    UIGalleryView()
        .frame(width: 1200, height: 800)
}
#endif
