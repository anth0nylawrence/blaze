import SwiftUI

// MARK: - File Tab Bar

/// Horizontal tab bar for open files with close buttons and drag reordering
struct FileTabBar: View {
    @Binding var tabs: [FileTab]
    @Binding var activeTabId: UUID?
    let onClose: (UUID) -> Void
    let onCloseAll: () -> Void
    let onCloseOthers: (UUID) -> Void

    @State private var draggedTab: FileTab?

    var body: some View {
        HStack(spacing: 0) {
            // Tabs scroll area
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        FileTabItem(
                            tab: tab,
                            isActive: tab.id == activeTabId,
                            onSelect: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    activeTabId = tab.id
                                }
                            },
                            onClose: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    onClose(tab.id)
                                }
                            },
                            onMiddleClick: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    onClose(tab.id)
                                }
                            }
                        )
                        .onDrag {
                            draggedTab = tab
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            item: tab,
                            items: $tabs,
                            draggedItem: $draggedTab
                        ))
                    }
                }
                .padding(.horizontal, DSSpacing.xxs)
            }

            Spacer()

            // Tab actions
            if !tabs.isEmpty {
                Menu {
                    Button("Close All") {
                        onCloseAll()
                    }

                    if let activeId = activeTabId {
                        Button("Close Others") {
                            onCloseOthers(activeId)
                        }
                        .disabled(tabs.count <= 1)
                    }

                    Divider()

                    Button("Close Tab", action: {
                        if let activeId = activeTabId {
                            onClose(activeId)
                        }
                    })
                    .keyboardShortcut("w", modifiers: .command)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.secondary)
                        .frame(width: DSSize.md, height: DSSize.md)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .padding(.trailing, DSSpacing.xs)
            }
        }
        .frame(height: 32)
        .background(Color.ds.surface.opacity(0.3))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ds.border.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - File Tab Item

/// Individual tab in the file tab bar
struct FileTabItem: View {
    let tab: FileTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onMiddleClick: () -> Void

    @State private var isHovered: Bool = false
    @State private var isCloseHovered: Bool = false

    private var language: SyntaxHighlighter.Language {
        SyntaxHighlighter.Language.from(extension: tab.fileExtension)
    }

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            // Dirty indicator (•) or file icon
            if tab.isDirty {
                Circle()
                    .fill(Color.ds.accent)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: language.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(language.color)
            }

            // File name (italic for preview tabs)
            Text(tab.fileName)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .italic(tab.isPreview)
                .lineLimit(1)
                .foregroundStyle(isActive ? Color.ds.foreground : Color.ds.secondary)

            // Close button (visible on hover or when active)
            if isHovered || isActive {
                Button(action: onClose) {
                    Image(systemName: tab.isDirty ? "circle.fill" : "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(
                            isCloseHovered
                                ? (tab.isDirty ? Color.ds.accent : Color.ds.foreground)
                                : Color.ds.tertiary
                        )
                        .frame(width: 14, height: 14)
                        .background(
                            isCloseHovered
                                ? Color.ds.surface
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .onHover { isCloseHovered = $0 }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                // Spacer to maintain consistent width
                Spacer()
                    .frame(width: 14)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .frame(maxWidth: 200)
        .background(
            Group {
                if isActive {
                    Color.ds.surface.opacity(0.8)
                } else if isHovered {
                    Color.ds.surface.opacity(0.4)
                } else {
                    Color.clear
                }
            }
        )
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(Color.ds.accent)
                    .frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.ds.border.opacity(0.2))
                .frame(width: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isActive)
        .gesture(
            // Middle-click to close
            TapGesture()
                .modifiers(.option)
                .onEnded { _ in onMiddleClick() }
        )
        .help(tab.filePath)
    }
}

// MARK: - Tab Drop Delegate

/// Handles drag-and-drop reordering of tabs
struct TabDropDelegate: DropDelegate {
    let item: FileTab
    @Binding var items: [FileTab]
    @Binding var draggedItem: FileTab?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id })
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Empty Tab Bar State

/// Shown when no files are open
struct EmptyFileTabBar: View {
    var body: some View {
        HStack {
            Text("No files open")
                .dsTextStyle(.caption, color: .ds.tertiary)
            Spacer()
        }
        .padding(.horizontal, DSSpacing.md)
        .frame(height: 32)
        .background(Color.ds.surface.opacity(0.3))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ds.border.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Previews

#Preview("File Tab Bar") {
    struct PreviewWrapper: View {
        @State private var tabs: [FileTab] = [
            FileTab(filePath: "/Users/dev/project/Sources/App/BlazeApp.swift", isPreview: false),
            FileTab(filePath: "/Users/dev/project/Sources/UI/ContentView.swift", isPreview: true),
            FileTab(filePath: "/Users/dev/project/Package.swift", isPreview: false),
            FileTab(filePath: "/Users/dev/project/README.md", isPreview: false),
        ]
        @State private var activeTabId: UUID?

        var body: some View {
            VStack(spacing: 0) {
                FileTabBar(
                    tabs: $tabs,
                    activeTabId: $activeTabId,
                    onClose: { id in
                        tabs.removeAll { $0.id == id }
                        if activeTabId == id {
                            activeTabId = tabs.last?.id
                        }
                    },
                    onCloseAll: {
                        tabs.removeAll()
                        activeTabId = nil
                    },
                    onCloseOthers: { keepId in
                        tabs.removeAll { $0.id != keepId }
                    }
                )
                .onAppear {
                    activeTabId = tabs.first?.id
                }

                // Content area
                Color.ds.bg0
                    .frame(height: 200)
            }
            .frame(width: 600)
        }
    }

    return PreviewWrapper()
}

#Preview("Empty Tab Bar") {
    EmptyFileTabBar()
        .frame(width: 400)
}

#Preview("Single Tab") {
    struct PreviewWrapper: View {
        @State private var tabs: [FileTab] = [
            FileTab(filePath: "/Users/dev/project/main.swift", isPreview: true)
        ]
        @State private var activeTabId: UUID?

        var body: some View {
            FileTabBar(
                tabs: $tabs,
                activeTabId: $activeTabId,
                onClose: { _ in },
                onCloseAll: {},
                onCloseOthers: { _ in }
            )
            .onAppear {
                activeTabId = tabs.first?.id
            }
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
