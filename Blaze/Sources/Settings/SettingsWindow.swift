import SwiftUI
import AppKit

struct SettingsWindowContent: View {
    @Environment(\.themeManager) private var themeManager
    @AppStorage("customGlassLevel") private var glassLevel: String = "regular"
    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var searchText: String = ""
    @State private var searchViewModel = SettingsSearchViewModel()
    @State private var sidebarWidth: CGFloat = 220
    @State private var isDraggingDivider = false

    private let minSidebarWidth: CGFloat = 180
    private let maxSidebarWidth: CGFloat = 320

    /// Opacity based on glass level setting
    private var backgroundOpacity: Double {
        switch glassLevel {
        case "subtle": return 0.95
        case "light": return 0.90
        case "regular": return 0.85
        case "prominent": return 0.75
        default: return 0.85
        }
    }

    var body: some View {
        ZStack {
            // Theme-aware background - uses active theme's background color
            Color.ds.bg0
                .opacity(backgroundOpacity)

            // Custom two-column layout with resizable sidebar
            HStack(spacing: 0) {
                // Sidebar
                VStack(spacing: 0) {
                    // Search bar (with top padding for traffic lights)
                    TextField("Search settings", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.ds.surface.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 12)
                        .padding(.top, 44)  // Space for traffic lights
                        .padding(.bottom, 8)
                        .onChange(of: searchText) { _, newValue in
                            searchViewModel.query = newValue
                            searchViewModel.updateSearch()
                        }

                    // Category list
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(searchViewModel.filteredCategories) { category in
                                SettingsCategoryRow(
                                    category: category,
                                    isSelected: selectedCategory == category
                                )
                                .onTapGesture {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .frame(width: sidebarWidth)
                .background(Color.ds.surface.opacity(0.15))

                // Resizable divider
                SettingsResizableDivider(
                    isDragging: $isDraggingDivider,
                    onDrag: { delta in
                        let newWidth = sidebarWidth + delta
                        sidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
                    }
                )

                // Detail panel
                CategoryDetailRouter.view(for: selectedCategory)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 44)  // Space for title bar area
                    .background(Color.ds.surface.opacity(0.15))
            }
        }
        .ignoresSafeArea()
        .frame(minWidth: 650, minHeight: 450)
        .background(
            // Configure window for transparency
            SettingsWindowAccessor()
        )
    }
}

// MARK: - Category Row

private struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.accentColor : Color.ds.secondary)
                .frame(width: 20)

            Text(category.displayName)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.ds.foreground : Color.ds.secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Resizable Divider

/// Draggable divider for settings sidebar
private struct SettingsResizableDivider: View {
    @Binding var isDragging: Bool
    let onDrag: (CGFloat) -> Void

    @State private var isHovered = false
    @State private var lastDragX: CGFloat = 0

    var body: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(isHovered || isDragging ? Color.accentColor : Color.ds.border.opacity(0.3))
                    .frame(width: isHovered || isDragging ? 3 : 1)
            }
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else if !isDragging {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            lastDragX = value.location.x
                        } else {
                            let delta = value.location.x - lastDragX
                            lastDragX = value.location.x
                            onDrag(delta)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastDragX = 0
                        if !isHovered {
                            NSCursor.pop()
                        }
                    }
            )
    }
}

// MARK: - Settings Window Accessor

/// Accesses NSWindow to configure transparency for Settings window.
/// With .windowStyle(.hiddenTitleBar), most transparency is automatic.
private struct SettingsWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = SettingsWindowAccessorView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class SettingsWindowAccessorView: NSView {
    private var hasConfigured = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowIfNeeded()
    }

    private func configureWindowIfNeeded() {
        guard !hasConfigured, let window = window else { return }
        hasConfigured = true

        DispatchQueue.main.async { [weak window] in
            guard let window = window else { return }

            // Make window transparent - hiddenTitleBar handles the rest
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true

            // Ensure resizable
            window.styleMask.insert(.resizable)
        }
    }
}

#Preview {
    SettingsWindowContent()
}
