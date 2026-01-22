# Design System / Component Library

> Cogit0 Blaze - GORGEOUS by Default

## Overview

This design system defines the visual language, components, and patterns for Cogit0 Blaze. Every element is crafted to be **beautiful**, **consistent**, and **purposeful**—creating an experience that developers will love using every day.

---

## 1. Design Tokens

### 1.1 Spacing Scale

```swift
// Spacing.swift

enum Spacing {
    static let xxxs: CGFloat = 2    // Tight internal spacing
    static let xxs: CGFloat = 4     // Icon padding
    static let xs: CGFloat = 8      // Compact gaps
    static let sm: CGFloat = 12     // Small component padding
    static let md: CGFloat = 16     // Standard padding
    static let lg: CGFloat = 24     // Section spacing
    static let xl: CGFloat = 32     // Large section gaps
    static let xxl: CGFloat = 48    // Major section breaks
    static let xxxl: CGFloat = 64   // Page-level spacing
}
```

### 1.2 Typography Scale

```swift
// Typography.swift

enum Typography {
    // Display - Hero text
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .default)
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .default)

    // Headings
    static let h1 = Font.system(size: 24, weight: .bold, design: .default)
    static let h2 = Font.system(size: 20, weight: .semibold, design: .default)
    static let h3 = Font.system(size: 18, weight: .semibold, design: .default)
    static let h4 = Font.system(size: 16, weight: .medium, design: .default)

    // Body
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // Mono - Code and technical
    static let codeLarge = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let code = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)

    // UI
    static let label = Font.system(size: 12, weight: .medium, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let overline = Font.system(size: 10, weight: .semibold, design: .default)
}
```

### 1.3 Border Radius

```swift
// Radius.swift

enum Radius {
    static let none: CGFloat = 0
    static let xs: CGFloat = 4      // Tags, small pills
    static let sm: CGFloat = 6      // Buttons, inputs
    static let md: CGFloat = 8      // Cards
    static let lg: CGFloat = 12     // Modals, large cards
    static let xl: CGFloat = 16     // Panels
    static let full: CGFloat = 9999 // Circular elements
}
```

### 1.4 Icon Sizes

```swift
// IconSize.swift

enum IconSize {
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

---

## 2. Core Components

### 2.1 Buttons

```swift
// BlazeButton.swift

struct BlazeButton: View {
    enum Style { case primary, secondary, ghost, destructive }
    enum Size { case small, medium, large }

    let title: String
    let icon: String?
    let style: Style
    let size: Size
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                }
                Text(title)
                    .font(font)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(border)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                DarkGradient.accent
            case .secondary:
                DarkBackground.raised
            case .ghost:
                Color.clear
            case .destructive:
                DarkAccent.error
            }
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return DarkText.primary
        case .ghost: return DarkText.secondary
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Radius.sm)
            .strokeBorder(
                style == .secondary ? DarkBorder.default : .clear,
                lineWidth: 1
            )
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return Spacing.sm
        case .medium: return Spacing.md
        case .large: return Spacing.lg
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return Spacing.xs
        case .medium: return Spacing.sm
        case .large: return Spacing.md
        }
    }

    private var font: Font {
        switch size {
        case .small: return Typography.bodySmall.weight(.medium)
        case .medium: return Typography.body.weight(.medium)
        case .large: return Typography.bodyLarge.weight(.semibold)
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: return IconSize.sm
        case .medium: return IconSize.md
        case .large: return IconSize.lg
        }
    }
}

// Usage
BlazeButton(title: "Send", icon: "paperplane", style: .primary, size: .medium) {
    sendMessage()
}
```

### 2.2 Text Fields

```swift
// BlazeTextField.swift

struct BlazeTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let isMultiline: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(isFocused ? DarkAccent.primary : DarkText.tertiary)
                    .font(.system(size: IconSize.md))
            }

            if isMultiline {
                TextEditor(text: $text)
                    .font(Typography.body)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .font(Typography.body)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
        }
        .padding(Spacing.sm)
        .background(DarkBackground.raised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .strokeBorder(
                    isFocused ? DarkAccent.primary : DarkBorder.subtle,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
```

### 2.3 Cards

```swift
// BlazeCard.swift

struct BlazeCard<Content: View>: View {
    let padding: CGFloat
    let showBorder: Bool
    let showShadow: Bool
    @ViewBuilder let content: () -> Content

    init(
        padding: CGFloat = Spacing.md,
        showBorder: Bool = true,
        showShadow: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.showBorder = showBorder
        self.showShadow = showShadow
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(DarkBackground.raised)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(DarkBorder.subtle, lineWidth: 1)
                }
            }
            .shadow(
                color: showShadow ? .black.opacity(0.3) : .clear,
                radius: showShadow ? 4 : 0,
                y: showShadow ? 2 : 0
            )
    }
}
```

### 2.4 Badges

```swift
// BlazeBadge.swift

struct BlazeBadge: View {
    enum Variant { case neutral, info, success, warning, error }

    let text: String
    let variant: Variant
    let icon: String?

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: IconSize.xs))
            }
            Text(text)
                .font(Typography.caption.weight(.medium))
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxxs)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch variant {
        case .neutral: return DarkBackground.elevated
        case .info: return DarkAccent.info.opacity(0.2)
        case .success: return DarkAccent.success.opacity(0.2)
        case .warning: return DarkAccent.warning.opacity(0.2)
        case .error: return DarkAccent.error.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .neutral: return DarkText.secondary
        case .info: return DarkAccent.info
        case .success: return DarkAccent.success
        case .warning: return DarkAccent.warning
        case .error: return DarkAccent.error
        }
    }
}
```

### 2.5 Tooltips

```swift
// BlazeTooltip.swift

struct BlazeTooltip<Content: View>: View {
    let text: String
    @ViewBuilder let content: () -> Content

    @State private var isShowing = false

    var body: some View {
        content()
            .onHover { hovering in
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isShowing = true
                        }
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.1)) {
                        isShowing = false
                    }
                }
            }
            .overlay(alignment: .top) {
                if isShowing {
                    Text(text)
                        .font(Typography.caption)
                        .foregroundStyle(DarkText.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(DarkBackground.overlay)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                        .shadow(DarkShadow.md)
                        .offset(y: -8)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
    }
}
```

---

## 3. Composite Components

### 3.1 Message Bubble

```swift
// MessageBubble.swift

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Avatar
            if message.isAssistant {
                AvatarView(type: .assistant)
            }

            VStack(alignment: message.isAssistant ? .leading : .trailing, spacing: Spacing.xs) {
                // Content
                BlazeCard(padding: Spacing.sm, showBorder: false) {
                    MessageContent(message: message)
                }
                .background(
                    message.isAssistant
                        ? DarkBackground.raised
                        : DarkAccent.primary.opacity(0.15)
                )

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(Typography.caption)
                    .foregroundStyle(DarkText.disabled)
            }
            .frame(maxWidth: 600, alignment: message.isAssistant ? .leading : .trailing)

            if !message.isAssistant {
                AvatarView(type: .user)
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}

struct AvatarView: View {
    enum AvatarType { case user, assistant }
    let type: AvatarType

    var body: some View {
        Circle()
            .fill(type == .assistant ? DarkAccent.primary : DarkBackground.elevated)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: type == .assistant ? "sparkles" : "person.fill")
                    .font(.system(size: IconSize.sm))
                    .foregroundStyle(type == .assistant ? .white : DarkText.secondary)
            }
    }
}
```

### 3.2 Tool Card

```swift
// ToolCard.swift

struct ToolCard: View {
    let tool: ToolUse
    @State private var isExpanded = false

    var body: some View {
        BlazeCard(padding: 0) {
            VStack(spacing: 0) {
                // Header
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        StatusIndicator(status: tool.status)

                        Image(systemName: tool.icon)
                            .foregroundStyle(DarkText.secondary)

                        Text(tool.name)
                            .font(Typography.code)
                            .foregroundStyle(DarkText.primary)

                        Spacer()

                        if let duration = tool.duration {
                            Text(duration.formatted())
                                .font(Typography.caption)
                                .foregroundStyle(DarkText.tertiary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: IconSize.xs, weight: .bold))
                            .foregroundStyle(DarkText.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(Spacing.sm)
                }
                .buttonStyle(.plain)

                // Expanded content
                if isExpanded {
                    Divider()
                        .background(DarkBorder.subtle)

                    ToolDetailView(tool: tool)
                        .padding(Spacing.sm)
                }
            }
        }
    }
}

struct StatusIndicator: View {
    let status: ToolStatus

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay {
                if status == .running {
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: status)
                }
            }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return DarkText.disabled
        case .running: return DarkAccent.info
        case .completed: return DarkAccent.success
        case .error: return DarkAccent.error
        }
    }
}
```

### 3.3 Code Block

```swift
// CodeBlock.swift

struct CodeBlock: View {
    let code: String
    let language: String?
    let showLineNumbers: Bool

    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let language = language {
                HStack {
                    Text(language)
                        .font(Typography.caption)
                        .foregroundStyle(DarkText.tertiary)

                    Spacer()

                    Button {
                        copyCode()
                    } label: {
                        Label(
                            isCopied ? "Copied!" : "Copy",
                            systemImage: isCopied ? "checkmark" : "doc.on.doc"
                        )
                        .font(Typography.caption)
                        .foregroundStyle(isCopied ? DarkAccent.success : DarkText.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(DarkBackground.surface)
            }

            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if showLineNumbers {
                        LineNumbers(count: code.components(separatedBy: "\n").count)
                    }

                    Text(code)
                        .font(Typography.code)
                        .foregroundStyle(DarkText.primary)
                        .textSelection(.enabled)
                        .padding(Spacing.sm)
                }
            }
            .background(DarkBackground.canvas)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .strokeBorder(DarkBorder.subtle, lineWidth: 1)
        )
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

struct LineNumbers: View {
    let count: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...count, id: \.self) { line in
                Text("\(line)")
                    .font(Typography.code)
                    .foregroundStyle(DarkText.disabled)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.sm)
        .background(DarkBackground.surface)
    }
}
```

### 3.4 Session List Item

```swift
// SessionListItem.swift

struct SessionListItem: View {
    let session: Session
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.sm) {
                // Icon
                Circle()
                    .fill(session.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: session.icon)
                            .font(.system(size: IconSize.sm))
                            .foregroundStyle(session.color)
                    }

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(session.title)
                        .font(Typography.body.weight(.medium))
                        .foregroundStyle(DarkText.primary)
                        .lineLimit(1)

                    Text(session.lastMessage ?? "No messages")
                        .font(Typography.caption)
                        .foregroundStyle(DarkText.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(session.updatedAt.formatted(.relative(presentation: .named)))
                    .font(Typography.caption)
                    .foregroundStyle(DarkText.disabled)
            }
            .padding(Spacing.sm)
            .background(isSelected ? DarkAccent.primary.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
    }
}
```

---

## 4. Layout Components

### 4.1 Navigation Split View

```swift
// MainLayout.swift

struct MainLayout: View {
    @State private var selectedSession: Session?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Session List
            SessionListView(selection: $selectedSession)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 350)
        } content: {
            // Main - Chat
            if let session = selectedSession {
                ChatView(session: session)
            } else {
                EmptySessionView()
            }
        } detail: {
            // Detail - Context Panel
            if let session = selectedSession {
                ContextPanel(session: session)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### 4.2 Modal Container

```swift
// ModalContainer.swift

struct ModalContainer<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            if isPresented {
                // Backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isPresented = false }
                    }

                // Modal
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(title)
                            .font(Typography.h3)

                        Spacer()

                        Button {
                            withAnimation { isPresented = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: IconSize.md, weight: .medium))
                                .foregroundStyle(DarkText.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.md)
                    .background(DarkBackground.elevated)

                    Divider()
                        .background(DarkBorder.subtle)

                    // Content
                    content()
                        .padding(Spacing.md)
                }
                .frame(maxWidth: 500)
                .background(DarkBackground.raised)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .shadow(DarkShadow.xl)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}
```

---

## 5. Component Showcase

### 5.1 Storybook-Style Preview

```swift
// ComponentShowcase.swift

struct ComponentShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                // Buttons
                Section("Buttons") {
                    HStack(spacing: Spacing.md) {
                        BlazeButton(title: "Primary", style: .primary, size: .medium) {}
                        BlazeButton(title: "Secondary", style: .secondary, size: .medium) {}
                        BlazeButton(title: "Ghost", style: .ghost, size: .medium) {}
                        BlazeButton(title: "Danger", style: .destructive, size: .medium) {}
                    }
                }

                // Badges
                Section("Badges") {
                    HStack(spacing: Spacing.sm) {
                        BlazeBadge(text: "Neutral", variant: .neutral, icon: nil)
                        BlazeBadge(text: "Info", variant: .info, icon: "info.circle")
                        BlazeBadge(text: "Success", variant: .success, icon: "checkmark")
                        BlazeBadge(text: "Warning", variant: .warning, icon: "exclamationmark.triangle")
                        BlazeBadge(text: "Error", variant: .error, icon: "xmark")
                    }
                }

                // Cards
                Section("Cards") {
                    BlazeCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Card Title")
                                .font(Typography.h4)
                            Text("This is a sample card with some content.")
                                .font(Typography.body)
                                .foregroundStyle(DarkText.secondary)
                        }
                    }
                    .frame(maxWidth: 300)
                }

                // Code Block
                Section("Code Block") {
                    CodeBlock(
                        code: "func greet(name: String) {\n    print(\"Hello, \\(name)!\")\n}",
                        language: "swift",
                        showLineNumbers: true
                    )
                    .frame(maxWidth: 400)
                }
            }
            .padding(Spacing.xl)
        }
    }
}

struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.h3)
                .foregroundStyle(DarkText.primary)

            content()
        }
    }
}
```

---

## 6. Guidelines

### 6.1 Do's and Don'ts

| ✅ Do | ❌ Don't |
|------|--------|
| Use design tokens for all values | Hard-code colors or spacing |
| Keep components focused | Create god-components |
| Follow naming conventions | Invent new patterns |
| Test in both light/dark | Assume one appearance |
| Consider accessibility | Forget keyboard navigation |
| Animate purposefully | Add gratuitous motion |

### 6.2 Naming Conventions

```
Components: PascalCase
├── BlazeButton
├── BlazeCard
├── ToolCard
└── MessageBubble

Tokens: camelCase
├── Spacing.md
├── Typography.body
├── DarkAccent.primary
└── Radius.lg

Modifiers: camelCase verb
├── .blazeCardStyle()
├── .withTooltip()
└── .animateOnAppear()
```

---

## 7. Implementation Checklist

- [ ] Define all design tokens
- [ ] Create base components (Button, Card, TextField, Badge)
- [ ] Create composite components (MessageBubble, ToolCard, CodeBlock)
- [ ] Create layout components (NavigationSplit, Modal, Sidebar)
- [ ] Build component showcase/storybook
- [ ] Add accessibility labels
- [ ] Add reduced motion support
- [ ] Test in light/dark modes
- [ ] Document usage examples
- [ ] Create Figma library (if applicable)
