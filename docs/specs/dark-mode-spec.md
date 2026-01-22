# Dark Mode Spec

> Cogit0 Blaze - Darkness Done Right

## Overview

Dark mode in Blaze isn't just inverted colors—it's a carefully crafted visual experience inspired by the best in class: **Raycast**, **Linear**, **Zed**, **Arc**, and **Alfred**. Our dark theme is the default, designed to reduce eye strain during long coding sessions while maintaining clarity and hierarchy.

---

## 1. Design Philosophy

### 1.1 Inspiration Analysis

| App | Strength | What We Adopt |
|-----|----------|---------------|
| **Raycast** | Deep blacks, vibrant accents | True black backgrounds, saturated highlights |
| **Linear** | Subtle gradients, refined grays | Layered surfaces, soft depth |
| **Zed** | Code-focused contrast | Syntax highlighting approach |
| **Arc** | Playful yet professional | Accent color personality |
| **Alfred** | Minimal, focused | Distraction-free modal design |

### 1.2 Core Principles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      DARK MODE PRINCIPLES                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐     │
│  │  DEPTH     │   │  CONTRAST  │   │  WARMTH    │   │  VIBRANCY  │     │
│  ├────────────┤   ├────────────┤   ├────────────┤   ├────────────┤     │
│  │ Layers of  │   │ Clear      │   │ Slight     │   │ Saturated  │     │
│  │ darkness   │   │ hierarchy  │   │ warm tint  │   │ accents    │     │
│  │ create UI  │   │ without    │   │ to reduce  │   │ that pop   │     │
│  │ dimension  │   │ harshness  │   │ eye strain │   │ on dark    │     │
│  └────────────┘   └────────────┘   └────────────┘   └────────────┘     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Color Palette

### 2.1 Background Layers

```swift
// DarkTheme.swift

enum DarkBackground {
    /// Deepest layer - window background
    /// Pure black with slight warmth
    static let canvas = Color(hex: "#0A0A0B")        // HSB: 240°, 4%, 4%

    /// Primary surface - main content area
    static let surface = Color(hex: "#111113")       // HSB: 240°, 4%, 7%

    /// Raised surface - cards, panels
    static let raised = Color(hex: "#18181B")        // HSB: 240°, 4%, 10%

    /// Elevated surface - modals, popovers
    static let elevated = Color(hex: "#1F1F23")      // HSB: 240°, 5%, 14%

    /// Highest surface - tooltips, menus
    static let overlay = Color(hex: "#27272B")       // HSB: 240°, 5%, 17%
}
```

**Visual Stack:**
```
┌─────────────────────────────────────────┐
│ overlay    #27272B  ████████████████    │  ← Tooltip
├─────────────────────────────────────────┤
│ elevated   #1F1F23  ██████████████      │  ← Modal
├─────────────────────────────────────────┤
│ raised     #18181B  ████████████        │  ← Card
├─────────────────────────────────────────┤
│ surface    #111113  ██████████          │  ← Content
├─────────────────────────────────────────┤
│ canvas     #0A0A0B  ████████            │  ← Window
└─────────────────────────────────────────┘
```

### 2.2 Text Colors

```swift
enum DarkText {
    /// Primary text - headings, important content
    static let primary = Color(hex: "#FAFAFA")       // 98% white

    /// Secondary text - body, descriptions
    static let secondary = Color(hex: "#A1A1AA")     // Zinc 400

    /// Tertiary text - labels, captions
    static let tertiary = Color(hex: "#71717A")      // Zinc 500

    /// Disabled text
    static let disabled = Color(hex: "#52525B")      // Zinc 600

    /// Placeholder text
    static let placeholder = Color(hex: "#3F3F46")   // Zinc 700
}
```

### 2.3 Accent Colors

```swift
enum DarkAccent {
    /// Primary brand accent - buttons, links
    static let primary = Color(hex: "#3B82F6")       // Vibrant blue

    /// Success states
    static let success = Color(hex: "#22C55E")       // Green 500

    /// Warning states
    static let warning = Color(hex: "#F59E0B")       // Amber 500

    /// Error states
    static let error = Color(hex: "#EF4444")         // Red 500

    /// Info states
    static let info = Color(hex: "#06B6D4")          // Cyan 500
}
```

### 2.4 Semantic Colors

```swift
enum DarkSemantic {
    // Diff colors
    static let diffAddition = Color(hex: "#166534").opacity(0.3)    // Green tint
    static let diffDeletion = Color(hex: "#991B1B").opacity(0.3)    // Red tint
    static let diffModified = Color(hex: "#854D0E").opacity(0.3)    // Yellow tint

    // Syntax highlighting (inspired by One Dark Pro)
    static let syntaxKeyword = Color(hex: "#C678DD")     // Purple
    static let syntaxString = Color(hex: "#98C379")      // Green
    static let syntaxNumber = Color(hex: "#D19A66")      // Orange
    static let syntaxComment = Color(hex: "#5C6370")     // Gray
    static let syntaxFunction = Color(hex: "#61AFEF")    // Blue
    static let syntaxVariable = Color(hex: "#E06C75")    // Red
    static let syntaxType = Color(hex: "#E5C07B")        // Yellow

    // Tool status
    static let toolPending = Color(hex: "#71717A")
    static let toolRunning = Color(hex: "#3B82F6")
    static let toolSuccess = Color(hex: "#22C55E")
    static let toolError = Color(hex: "#EF4444")
}
```

---

## 3. Component Styling

### 3.1 Borders & Dividers

```swift
enum DarkBorder {
    /// Subtle borders - internal dividers
    static let subtle = Color(hex: "#27272A")        // Nearly invisible

    /// Default borders - card edges
    static let `default` = Color(hex: "#3F3F46")

    /// Strong borders - focus rings
    static let strong = Color(hex: "#52525B")

    /// Interactive borders - hover state
    static let interactive = Color(hex: "#71717A")
}
```

### 3.2 Shadows

```swift
enum DarkShadow {
    /// Subtle elevation
    static let sm = Shadow(
        color: .black.opacity(0.3),
        radius: 2,
        y: 1
    )

    /// Card elevation
    static let md = Shadow(
        color: .black.opacity(0.4),
        radius: 4,
        y: 2
    )

    /// Modal elevation
    static let lg = Shadow(
        color: .black.opacity(0.5),
        radius: 8,
        y: 4
    )

    /// Popover elevation
    static let xl = Shadow(
        color: .black.opacity(0.6),
        radius: 16,
        y: 8
    )
}
```

### 3.3 Gradients

```swift
enum DarkGradient {
    /// Subtle surface gradient (adds depth)
    static let surface = LinearGradient(
        colors: [
            Color(hex: "#111113"),
            Color(hex: "#0F0F11")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Accent gradient for buttons
    static let accent = LinearGradient(
        colors: [
            Color(hex: "#3B82F6"),
            Color(hex: "#2563EB")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Success gradient
    static let success = LinearGradient(
        colors: [
            Color(hex: "#22C55E"),
            Color(hex: "#16A34A")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Glow effect for highlights
    static func glow(color: Color) -> RadialGradient {
        RadialGradient(
            colors: [color.opacity(0.3), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
}
```

---

## 4. Component Examples

### 4.1 Chat Message Bubble

```swift
struct MessageBubble: View {
    let message: Message
    let isUser: Bool

    var body: some View {
        Text(message.content)
            .foregroundStyle(DarkText.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isUser ? DarkAccent.primary.opacity(0.15) : DarkBackground.raised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isUser ? DarkAccent.primary.opacity(0.3) : DarkBorder.subtle,
                                lineWidth: 1
                            )
                    )
            )
    }
}
```

### 4.2 Tool Card

```swift
struct ToolCard: View {
    let tool: ToolUse
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                StatusDot(status: tool.status)
                Text(tool.name)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .foregroundStyle(DarkText.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(DarkText.tertiary)
            }
            .padding(12)
            .background(DarkBackground.raised)

            // Expanded content
            if isExpanded {
                Divider()
                    .background(DarkBorder.subtle)

                CodeBlock(code: tool.input)
                    .padding(12)
                    .background(DarkBackground.surface)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(DarkBorder.default, lineWidth: 1)
        )
        .shadow(DarkShadow.sm)
    }
}
```

### 4.3 Diff Viewer

```swift
struct DiffLine: View {
    let line: DiffLineDelta

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            HStack(spacing: 8) {
                Text(line.oldNumber ?? "-")
                    .frame(width: 40, alignment: .trailing)
                Text(line.newNumber ?? "-")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(DarkText.tertiary)
            .padding(.horizontal, 8)
            .background(DarkBackground.surface)

            // Gutter indicator
            Text(line.indicator)
                .frame(width: 20)
                .foregroundStyle(indicatorColor)

            // Content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(DarkText.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .background(backgroundColor)
        }
    }

    var backgroundColor: Color {
        switch line.type {
        case .addition: return DarkSemantic.diffAddition
        case .deletion: return DarkSemantic.diffDeletion
        case .context: return .clear
        }
    }

    var indicatorColor: Color {
        switch line.type {
        case .addition: return DarkAccent.success
        case .deletion: return DarkAccent.error
        case .context: return DarkText.disabled
        }
    }
}
```

### 4.4 Command Palette

```swift
struct CommandPalette: View {
    @State private var query = ""
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DarkText.tertiary)
                TextField("Search commands...", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DarkText.primary)
            }
            .padding(16)
            .background(DarkBackground.elevated)

            Divider()
                .background(DarkBorder.subtle)

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.offset) { index, command in
                        CommandRow(
                            command: command,
                            isSelected: index == selectedIndex
                        )
                    }
                }
            }
            .frame(maxHeight: 400)
            .background(DarkBackground.raised)
        }
        .frame(width: 600)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(DarkBorder.default, lineWidth: 1)
        )
        .shadow(DarkShadow.xl)
    }
}

struct CommandRow: View {
    let command: Command
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: command.icon)
                .frame(width: 24)
                .foregroundStyle(isSelected ? DarkAccent.primary : DarkText.secondary)

            Text(command.title)
                .foregroundStyle(DarkText.primary)

            Spacer()

            if let shortcut = command.shortcut {
                KeyboardShortcutView(shortcut: shortcut)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? DarkAccent.primary.opacity(0.1) : .clear)
    }
}
```

---

## 5. Light Mode (Optional)

### 5.1 Light Palette

```swift
enum LightBackground {
    static let canvas = Color(hex: "#FFFFFF")
    static let surface = Color(hex: "#FAFAFA")
    static let raised = Color(hex: "#F4F4F5")
    static let elevated = Color(hex: "#FFFFFF")
    static let overlay = Color(hex: "#FFFFFF")
}

enum LightText {
    static let primary = Color(hex: "#18181B")
    static let secondary = Color(hex: "#52525B")
    static let tertiary = Color(hex: "#71717A")
    static let disabled = Color(hex: "#A1A1AA")
    static let placeholder = Color(hex: "#D4D4D8")
}
```

### 5.2 Theme Toggle

```swift
struct ThemeToggle: View {
    @AppStorage("appearance") var appearance: Appearance = .dark

    enum Appearance: String {
        case light, dark, system
    }

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            Label("Light", systemImage: "sun.max")
                .tag(Appearance.light)
            Label("Dark", systemImage: "moon")
                .tag(Appearance.dark)
            Label("System", systemImage: "laptopcomputer")
                .tag(Appearance.system)
        }
        .pickerStyle(.segmented)
    }
}
```

---

## 6. System Integration

### 6.1 macOS Appearance API

```swift
// AppDelegate.swift

@main
struct BlazeApp: App {
    @AppStorage("appearance") var appearance: Appearance = .dark

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
```

### 6.2 Window Styling

```swift
// WindowController.swift

func configureWindow(_ window: NSWindow) {
    window.backgroundColor = NSColor(DarkBackground.canvas)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.styleMask.insert(.fullSizeContentView)

    // Vibrancy for sidebar
    if let sidebar = window.contentView?.subviews.first(where: { $0 is SidebarView }) {
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        sidebar.addSubview(visualEffect, positioned: .below, relativeTo: nil)
    }
}
```

### 6.3 Menu Bar Integration

```swift
// StatusItem.swift

func configureStatusItem() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem.button {
        button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Blaze")
        button.image?.isTemplate = true // Adapts to menu bar appearance
    }
}
```

---

## 7. Accessibility

### 7.1 Contrast Ratios

| Element | Foreground | Background | Ratio | WCAG |
|---------|------------|------------|-------|------|
| Primary text | #FAFAFA | #111113 | 18.3:1 | AAA |
| Secondary text | #A1A1AA | #111113 | 7.2:1 | AAA |
| Tertiary text | #71717A | #111113 | 4.6:1 | AA |
| Links | #3B82F6 | #111113 | 5.1:1 | AA |
| Error text | #EF4444 | #111113 | 5.3:1 | AA |

### 7.2 High Contrast Mode

```swift
@Environment(\.accessibilityDifferentiateWithoutColor) var needsHighContrast

var borderColor: Color {
    needsHighContrast ? DarkBorder.strong : DarkBorder.subtle
}

var textColor: Color {
    needsHighContrast ? DarkText.primary : DarkText.secondary
}
```

---

## 8. Implementation Checklist

### 8.1 Core Theme

- [ ] Define color tokens in ColorTokens.swift
- [ ] Create Theme environment object
- [ ] Implement dark/light/system toggle
- [ ] Store preference in UserDefaults
- [ ] Apply theme on app launch

### 8.2 Components

- [ ] Message bubbles with theme colors
- [ ] Tool cards with proper contrast
- [ ] Diff viewer with semantic colors
- [ ] Command palette styling
- [ ] Navigation sidebar
- [ ] Modal dialogs
- [ ] Form controls
- [ ] Code blocks with syntax highlighting

### 8.3 Polish

- [ ] Window background matches theme
- [ ] Titlebar integration
- [ ] Menu bar icon adapts
- [ ] Scrollbar styling
- [ ] Selection highlighting
- [ ] Focus rings
- [ ] Loading states
- [ ] Empty states
