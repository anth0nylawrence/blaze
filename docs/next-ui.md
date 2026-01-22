# Blaze Kanban & Roadmap: Complete UI/UX Specification

**Version:** 1.0.0
**Created:** 2026-01-22
**Status:** Ready for Implementation

---

> ⚠️ **CRITICAL: DO NOT MODIFY THE MAIN APP WINDOW**
>
> This specification is for a **NEW, SEPARATE POPUP WINDOW** only.
>
> **DO NOT:**
> - Change `ContentView.swift` layout or navigation
> - Modify the 3-column structure (Left Panel / Center Pane / Right Sidebar)
> - Alter the existing `CenterPaneMode` enum or title bar controls
> - Touch any existing UI components in the main window
>
> **DO:**
> - Add ONE button to the main window toolbar to trigger the popup
> - Create ALL new components in a separate `ProjectManagement/` directory
> - Keep the popup window completely isolated from main app architecture

---

## Executive Summary

### What We're Building

A **separate popup window** for project management that provides:

1. **Kanban Board** - 4-column task management (Planning, In Progress, Review, Done)
2. **Visual Roadmap** - MoSCoW priority matrix for feature planning
3. **Git Worktree Integration** - Master overview of ALL features across ALL worktrees

### Why a Separate Popup Window

- **Parallel visibility** - View Kanban while working in main chat
- **Dedicated focus** - Project management deserves its own space
- **Multi-monitor support** - Drag to second display
- **Consistent mental model** - Separate concerns, separate windows

### Key User Flows

1. **Session to Kanban**: User starts session in main app, card auto-appears in Kanban "In Progress" column
2. **Progress Tracking**: Real-time progress updates as CLI runs (dots fill, percentage increases)
3. **Merge Flow**: Session completes, user drags card to "Review", clicks "Merge to Main"
4. **Cross-Worktree View**: See all active sessions across all git worktrees in one board

---

## 1. Window Architecture

> 🚨 **WARNING: ISOLATION BOUNDARY**
>
> The Kanban popup is a **completely separate window** using SwiftUI's `Window` scene.
> It shares state via environment objects but has **zero layout coupling** to `ContentView`.
>
> **The ONLY change to the main app is adding ONE button to open this window.**
> Do not refactor, restructure, or "improve" the main window as part of this work.

### 1.1 Window Trigger

The Kanban popup is triggered by a **single button** added to the main window's top-right toolbar area.

```
ACTUAL Main Window Title Bar (DO NOT CHANGE EXISTING LAYOUT):
┌──────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  [+]              [Chat|Files|Split]              [🐙] [📋] [⚙] [🔍] │
│   ↑         ↑                  ↑                          ↑    ↑            │
│ traffic   new              CenterPaneToggle            GitHub  │            │
│ lights   session           (CENTERED, existing)         etc    │            │
│                                                                 │            │
│                                            ADD KANBAN BUTTON HERE ──────────│
│                                            (next to GitHub icon)             │
└──────────────────────────────────────────────────────────────────────────────┘

WHERE TO ADD THE BUTTON:
- File: ContentView.swift, lines ~92-100 (topTrailing overlay, HStack)
- Add ONE icon button: Image(systemName: "rectangle.3.group")
- Place it in the existing HStack alongside GitHub/Discord/Settings icons
```

**Keyboard shortcut:** `Cmd+Shift+K`

> ⚠️ **DO NOT** add a 4th mode to `CenterPaneToggle`. The Kanban is a **separate window**, not a center pane mode.

### 1.2 SwiftUI Window Configuration

```swift
// BlazeApp.swift

@main
struct BlazeApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)

        // Kanban popup window
        Window("Project Management", id: "kanban-popup") {
            KanbanRoadmapWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        .keyboardShortcut("K", modifiers: [.command, .shift])
    }
}
```

### 1.3 Window Dimensions

| Property | Value | Notes |
|----------|-------|-------|
| Default Size | 1200 x 800 px | Comfortable 4-column Kanban |
| Minimum Size | 900 x 600 px | Below this, columns collapse |
| Maximum Size | Screen bounds | Full-screen capable |
| Aspect Ratio | ~1.5:1 | Landscape optimized |

### 1.4 Glass Transparency Implementation

The popup inherits Blaze's glass aesthetic via macOS vibrancy:

```swift
struct KanbanRoadmapWindow: View {
    var body: some View {
        ZStack {
            // Background material
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow
            )

            // Gradient tint for warmth
            LinearGradient(
                colors: [
                    Color(hex: "#0f0f23").opacity(0.7),
                    Color(hex: "#1a1a3e").opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content
            KanbanRoadmapContent()
        }
        .overlay(
            // Border gradient (top-left light, bottom-right dark)
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.15), location: 0),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.2), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
```

### 1.5 State Synchronization

The popup window shares state with the main app via SwiftUI's environment:

```swift
// Shared state container
@Observable
@MainActor
final class ProjectManagementState {
    var kanbanCards: [UUID: KanbanCard] = [:]
    var selectedCardId: UUID?
    var activeView: ProjectView = .kanban
    var isLoading: Bool = false

    enum ProjectView {
        case kanban
        case roadmap
    }
}

// In BlazeApp
@State private var projectState = ProjectManagementState()

WindowGroup {
    ContentView()
        .environment(projectState)
}

Window("Project Management", id: "kanban-popup") {
    KanbanRoadmapWindow()
        .environment(projectState)  // Same instance
}
```

---

## 2. Design System

> ⚠️ **INHERIT FROM MAIN APP - DO NOT CREATE NEW TOKENS**
>
> The popup window **MUST use existing design tokens** from:
> - `Blaze/Sources/DesignSystem/Tokens/DSColors.swift` (theme-aware)
> - `Blaze/Sources/DesignSystem/Tokens/DSTypography.swift` (`DSTextStyle` enum)
> - `Blaze/Sources/DesignSystem/Tokens/DSSpacing.swift` (4pt grid: xxs=4, xs=8, etc.)
> - `Blaze/Sources/DesignSystem/Tokens/DSGlass.swift` (glass effects)
>
> **DO NOT** define new `DSTypography` structs or hardcoded colors.
> **DO** use `Color.ds.foreground`, `DSTextStyle.body.font`, `DSSpacing.md`, etc.
>
> The values below are **reference only** - always use the existing Swift tokens.

### 2.1 Philosophy: Five Principles

1. **Purposeful Restraint** - Every element earns its place. No decorative gradients, bouncy animations, or color for color's sake.

2. **Keyboard Primacy** - Power users never need the mouse. Vim navigation (j/k/h/l), single-key actions, Command palette (Cmd+K).

3. **Information Density Without Clutter** - Show more data in less space with clear visual hierarchy. Title is king, metadata is court, actions are servants.

4. **Speed as Feature** - Drag feedback in <16ms, optimistic updates, no spinners for <200ms operations.

5. **macOS Native** - Use NSVisualEffectView, SwiftUI springs, native drag-drop. Respect reduced motion.

### 2.2 Color Palette

> **USE EXISTING:** `DSColors` from `DSColors.swift` (theme-aware via `ThemeManager`)

**DO NOT hardcode hex values.** Use the theme-aware color tokens:

```swift
// EXISTING API - backgrounds
Color.ds.bg0         // Deepest background (window)
Color.ds.bg1         // Primary background
Color.ds.panel       // Panel/card background
Color.ds.surface     // Interactive surface

// EXISTING API - text
Color.ds.foreground  // Primary text
Color.ds.secondary   // Secondary text
Color.ds.tertiary    // Muted text
Color.ds.placeholder // Placeholder text

// EXISTING API - semantic
Color.ds.accent      // Interactive elements
Color.ds.positive    // Success states
Color.ds.warning     // Warning states
Color.ds.negative    // Error states
Color.ds.border      // Borders
```

These colors adapt to the user's selected theme. **Hardcoded hex values will break theming.**

**Reference hex values (for design reference only - DO NOT use in code):**

| Token | Approximate Hex | Usage |
|-------|-----------------|-------|
| bg0 | `#0A0A0B` | Window chrome |
| surface | `#0F0F10` | App background |
| foreground | `#FAFAFA` | Primary text |
| secondary | `#A3A3A8` | Metadata text |

**Column Colors (4-Tier Kanban)**

| Column | Hex | SF Symbol |
|--------|-----|-----------|
| Planning | `#6B7280` (Gray) | `doc.text` |
| In Progress | `#3B82F6` (Blue) | `gearshape` |
| Review | `#F59E0B` (Amber) | `eye` |
| Done | `#10B981` (Emerald) | `checkmark.circle` |

**Priority Colors (MoSCoW)**

| Priority | Hex | Description |
|----------|-----|-------------|
| Must Have | `#22C55E` (Green) | High impact, must ship |
| Should Have | `#3B82F6` (Blue) | High value, can defer |
| Could Have | `#F59E0B` (Amber) | Nice to have |
| Won't Have | `#6B7280` (Gray) | Not now |

**Effort/Impact Badges**

| Effort Level | Hex |
|--------------|-----|
| Low | `#22C55E` (Green) |
| Medium | `#EAB308` (Yellow) |
| High | `#EF4444` (Red) |

| Impact Level | Hex |
|--------------|-----|
| Low | `#6B7280` (Gray) |
| Medium | `#60A5FA` (Blue) |
| High | `#A78BFA` (Violet) |

**Engine Brand Colors**

| Engine | Hex |
|--------|-----|
| Claude | `#D97757` (Terracotta) |
| Gemini | `#4285F4` (Google Blue) |
| Codex | `#10A37F` (OpenAI Green) |

**Accent & Focus**

| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | `#5E6AD2` | Interactive elements |
| `accent-hover` | `#6D79E0` | Hover states |
| `accent-muted` | `#5E6AD2` @ 20% | Backgrounds |
| `focus-ring` | `#5E6AD2` @ 50% | 2px focus ring |

### 2.3 Typography

> **USE EXISTING:** `DSTextStyle` enum from `DSTypography.swift`

**DO NOT create custom fonts.** Use the existing system font styles:

```swift
// EXISTING API - use this:
DSTextStyle.hero.font      // 32pt bold (display text)
DSTextStyle.title.font     // 20pt semibold (section headers)
DSTextStyle.subtitle.font  // 16pt medium (card titles)
DSTextStyle.body.font      // 14pt regular (descriptions)
DSTextStyle.caption.font   // 12pt regular (metadata)
DSTextStyle.micro.font     // 11pt regular (timestamps)
DSTextStyle.mono.font      // 13pt monospaced (branch names, IDs)
DSTextStyle.monoSmall.font // 11pt monospaced (small code)
```

**Mapping for Kanban:**

| Element | Use |
|---------|-----|
| Card title | `DSTextStyle.subtitle.font` |
| Card description | `DSTextStyle.body.font` |
| Timestamps | `DSTextStyle.micro.font` |
| Branch names | `DSTextStyle.mono.font` |
| Status badges | `DSTextStyle.caption.font` |
| Column headers | `DSTextStyle.title.font` |

### 2.4 Spacing Scale (4px Grid)

> **USE EXISTING:** `DSSpacing` enum from `DSSpacing.swift`

```swift
// EXISTING API - use these exact values:
DSSpacing.xxs   // 4pt  - tight gaps
DSSpacing.xs    // 8pt  - icon padding
DSSpacing.sm    // 12pt - compact layouts
DSSpacing.md    // 16pt - standard padding
DSSpacing.lg    // 24pt - comfortable spacing
DSSpacing.xl    // 32pt - section gaps
DSSpacing.xxl   // 48pt - major sections
DSSpacing.huge  // 64pt - page-level
```

**DO NOT** redefine these values. The main app uses `xxs=4`, not `xxs=2`.

### 2.5 Border Radius

> **USE EXISTING:** `DSRadius` enum from `DSSpacing.swift`

```swift
// EXISTING API:
DSRadius.sm    // 4pt  - buttons, badges
DSRadius.md    // 8pt  - cards
DSRadius.lg    // 12pt - prominent elements
DSRadius.xl    // 16pt - modals, sheets
DSRadius.xxl   // 20pt - extra large
DSRadius.full  // 9999pt - pill/circular
```

**Critical: Always use `.continuous` corner style**

```swift
RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
```

### 2.6 Animation System (Spring Presets)

```swift
struct DSMotion {
    // Snappy - Quick feedback, minimal travel
    // Use for: hover states, small state changes
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.85)

    // Standard - Everyday transitions
    // Use for: view switches, card movements
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.80)

    // Smooth - Polished feel
    // Use for: modals, panels sliding in
    static let smooth = Animation.spring(response: 0.40, dampingFraction: 0.82)

    // Bouncy - Success moments ONLY
    // Use for: task completion, achievement
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.65)

    // Reduced motion fallback
    static let instant = Animation.linear(duration: 0.01)

    // Duration tokens (non-spring)
    static let instantDuration: Double = 0.1
    static let fastDuration: Double = 0.15
    static let normalDuration: Double = 0.2
    static let slowDuration: Double = 0.3
}
```

### 2.7 Shadow Tokens

```swift
struct DSShadow {
    // Ambient shadow (always present)
    static let ambient = Shadow(
        color: .black.opacity(0.15),
        radius: 12,
        x: 0, y: 4
    )

    // Elevated (hover)
    static let elevated = Shadow(
        color: .black.opacity(0.25),
        radius: 20,
        x: 0, y: 8
    )

    // Dragging
    static let dragging = Shadow(
        color: .black.opacity(0.35),
        radius: 30,
        x: 0, y: 12
    )

    // Glow (success, focus)
    static func glow(_ color: Color) -> Shadow {
        Shadow(color: color.opacity(0.4), radius: 16, x: 0, y: 0)
    }
}
```

### 2.8 Premium Touches

**1. Progress Border Gradient**

Card border shows progress by filling with accent color:

```swift
RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
    .strokeBorder(
        LinearGradient(
            stops: [
                .init(color: .accent, location: progress),
                .init(color: .border.opacity(0.15), location: progress)
            ],
            startPoint: .leading,
            endPoint: .trailing
        ),
        lineWidth: 2
    )
```

**2. Engine-Specific Ambient Glow**

Active session cards glow in their engine's brand color:

```swift
if card.status == .active {
    RoundedRectangle(cornerRadius: DSRadius.md + 4)
        .fill(card.engineColor.opacity(0.15))
        .blur(radius: 20)
        .offset(y: 4)
}
```

**3. Staggered Card Entrance**

Cards fade in 30ms apart for polished loading:

```swift
ForEach(cards.indices, id: \.self) { index in
    CardView(card: cards[index])
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 20)),
            removal: .opacity
        ))
        .animation(
            DSMotion.smooth.delay(Double(index) * 0.03),
            value: cards
        )
}
```

---

## 3. Navigation & Layout

### 3.1 Window Structure

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●                                            [Search]  [Filter]  [+ New]    │
├───────────────────┬─────────────────────────────────────────────────────────────┤
│                   │                                                             │
│   LEFT SIDEBAR    │                    MAIN CONTENT AREA                        │
│   (220px fixed)   │                    (Flexible width)                         │
│                   │                                                             │
│  ┌─────────────┐  │  ┌─────────────────────────────────────────────────────┐   │
│  │ PROJECT     │  │  │                                                     │   │
│  │ ─────────── │  │  │   Kanban Board OR Roadmap View                      │   │
│  │ ▶ Kanban    │◀─┼──│   (Based on sidebar selection)                      │   │
│  │   Roadmap   │  │  │                                                     │   │
│  │             │  │  │                                                     │   │
│  │ TOOLS       │  │  │                                                     │   │
│  │ ─────────── │  │  │                                                     │   │
│  │   Worktrees │  │  │                                                     │   │
│  │             │  │  │                                                     │   │
│  └─────────────┘  │  └─────────────────────────────────────────────────────┘   │
│                   │                                                             │
│  ┌─────────────┐  │                                                             │
│  │ + New Task  │  │                                                             │
│  └─────────────┘  │                                                             │
└───────────────────┴─────────────────────────────────────────────────────────────┘
```

### 3.2 Sidebar Specification

| Property | Value |
|----------|-------|
| Width | 220px fixed (resizable 200-280px) |
| Background | `bg-canvas` @ 60% opacity |
| Border (right) | 1px `white` @ 8% |

**Sidebar Items**

| Section | Item | Icon (SF Symbol) | Shortcut |
|---------|------|------------------|----------|
| PROJECT | Kanban Board | `rectangle.3.group` | Cmd+1 |
| PROJECT | Roadmap | `map` | Cmd+2 |
| TOOLS | Worktrees | `arrow.triangle.branch` | Cmd+3 |

**Item States**

```
NORMAL:    opacity 0.8, background transparent
HOVER:     opacity 1.0, background white/5%
ACTIVE:    opacity 1.0, background accent/20%, left border 2px accent
```

### 3.3 View Switching (Kanban ↔ Roadmap)

**Pill-Style Segmented Control** in content header:

```
         ╭─────────────────────────────────────╮
         │  [Kanban]  [Roadmap]                │
         ╰─────────────────────────────────────╯
              ↑          ↑
            active    inactive
           (filled)   (ghost)
```

**Transition:** Cross-fade, 150ms, ease-out

**State Preservation:** Selected card stays selected when switching views

### 3.4 Keyboard Shortcuts

**Global**

| Shortcut | Action |
|----------|--------|
| Cmd+1 | Kanban view |
| Cmd+2 | Roadmap view |
| Cmd+K | Command palette |
| Cmd+N | New task |
| Cmd+F | Focus search |
| Cmd+W | Close window |
| Escape | Clear selection / Close modal |
| Cmd+/ | Show shortcuts help |

**Navigation (Vim-style)**

| Shortcut | Action |
|----------|--------|
| j / Arrow Down | Move down |
| k / Arrow Up | Move up |
| h / Arrow Left | Move left (between columns) |
| l / Arrow Right | Move right (between columns) |
| Enter | Open selected |
| Space | Quick preview |

**Actions**

| Shortcut | Action |
|----------|--------|
| s | Start session |
| m | Merge to main |
| b | Copy branch name |
| 1-4 | Move to column 1-4 |
| d | Toggle description |

---

## 4. Kanban Board

### 4.1 Four-Column Layout

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                                KANBAN BOARD                                     │
├─────────────────────┬─────────────────────┬─────────────────────┬──────────────┤
│                     │                     │                     │              │
│  PLANNING           │  IN PROGRESS        │  REVIEW             │  DONE        │
│  ──────────────     │  ──────────────     │  ──────────────     │  ────────    │
│  (3)  [+]           │  (2)                │  (1)                │  (5)         │
│                     │                     │                     │              │
│  ┌───────────────┐  │  ┌───────────────┐  │  ┌───────────────┐  │  ┌────────┐  │
│  │ Task Card     │  │  │ Task Card     │  │  │ Task Card     │  │  │ Card   │  │
│  │               │  │  │ (running)     │  │  │               │  │  │        │  │
│  └───────────────┘  │  └───────────────┘  │  └───────────────┘  │  └────────┘  │
│                     │                     │                     │              │
│  ┌───────────────┐  │  ┌───────────────┐  │                     │  ┌────────┐  │
│  │ Task Card     │  │  │ Task Card     │  │    Empty State:     │  │ Card   │  │
│  │               │  │  │               │  │    "No tasks        │  │        │  │
│  └───────────────┘  │  └───────────────┘  │    awaiting         │  └────────┘  │
│                     │                     │    review"          │              │
│  ┌───────────────┐  │                     │                     │  ┌────────┐  │
│  │ Task Card     │  │                     │                     │  │ Card   │  │
│  │               │  │                     │                     │  │        │  │
│  └───────────────┘  │                     │                     │  └────────┘  │
│                     │                     │                     │              │
└─────────────────────┴─────────────────────┴─────────────────────┴──────────────┘
```

### 4.2 Column Specifications

```swift
struct KanbanColumnSpec {
    static let columnWidth: CGFloat = 280
    static let columnMinWidth: CGFloat = 240
    static let columnMaxWidth: CGFloat = 360
    static let columnGap: CGFloat = 16
    static let headerHeight: CGFloat = 48

    static let columns: [ColumnDef] = [
        ColumnDef(
            id: "planning",
            title: "Planning",
            color: Color(hex: "#6B7280"),
            icon: "doc.text",
            canAddCards: true,
            wipLimit: nil
        ),
        ColumnDef(
            id: "in_progress",
            title: "In Progress",
            color: Color(hex: "#3B82F6"),
            icon: "gearshape",
            canAddCards: false,
            wipLimit: 3
        ),
        ColumnDef(
            id: "review",
            title: "Review",
            color: Color(hex: "#F59E0B"),
            icon: "eye",
            canAddCards: false,
            wipLimit: nil
        ),
        ColumnDef(
            id: "done",
            title: "Done",
            color: Color(hex: "#10B981"),
            icon: "checkmark.circle",
            canAddCards: false,
            wipLimit: nil
        )
    ]
}
```

### 4.3 Column Header Design

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  COLUMN HEADER (48px height)                                    │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ●  Planning                          (3)   [+]           │  │
│  │  ↑  ↑                                  ↑     ↑            │  │
│  │  │  Title (titleMedium)                │     Add btn      │  │
│  │  │                                     │     (Planning    │  │
│  │  Status dot (column color, 8px)        │      only)       │  │
│  │                                   Count badge             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Background: white @ 5%                                         │
│  Border-radius: 8px (top corners only)                          │
│  Padding: 12px 16px                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.4 Task Card Anatomy

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  TASK CARD (min 120px height)                                   │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ┌────────┐                                               │  │
│  │  │ Claude │  Add OAuth to login flow          [Pending]   │  │
│  │  └────────┘                                               │  │
│  │  ─────────────────────────────────────────────────────    │  │
│  │  Add OAuth2 integration with GitHub                       │  │
│  │  for user authentication flow...                          │  │
│  │                                                           │  │
│  │  ●●●●●●○○○○  60%                            [Start]       │  │
│  │                                                           │  │
│  │  🧠 3 memories   📝 12 turns   ⏱ 4:32      2m ago        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  LAYOUT BREAKDOWN:                                              │
│                                                                 │
│  Row 1: Engine badge + Title + Status badge                     │
│  Row 2: Separator (1px, white @ 10%)                            │
│  Row 3: Description (2 lines max, ellipsis)                     │
│  Row 4: Progress dots + percentage + Action button              │
│  Row 5: Metadata (memories, turns, duration, timestamp)         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Card Dimensions**

| Property | Value |
|----------|-------|
| Width | Fill column |
| Min Height | 120px |
| Max Height | 200px |
| Corner Radius | 12px (continuous) |
| Padding | 16px top/sides, 12px bottom |
| Card Gap | 12px |
| Background | `#141416` @ 80% (raised) |
| Border | 1px white @ 10% |

### 4.5 Status Badges

```swift
struct StatusBadgeSpec {
    static let badges: [StatusBadge] = [
        StatusBadge(
            status: .pending,
            label: "Pending",
            background: Color(hex: "#374151"),       // Gray-700
            foreground: Color(hex: "#D1D5DB"),       // Gray-300
            icon: nil
        ),
        StatusBadge(
            status: .inProgress,
            label: "Running",
            background: Color(hex: "#1D4ED8").opacity(0.3),
            foreground: Color(hex: "#60A5FA"),       // Blue-400
            icon: "arrow.triangle.2.circlepath"
        ),
        StatusBadge(
            status: .needsReview,
            label: "Review",
            background: Color(hex: "#D97706").opacity(0.3),
            foreground: Color(hex: "#FBBF24"),       // Amber-400
            icon: "eye"
        ),
        StatusBadge(
            status: .completed,
            label: "Done",
            background: Color(hex: "#059669").opacity(0.3),
            foreground: Color(hex: "#34D399"),       // Emerald-400
            icon: "checkmark"
        ),
        StatusBadge(
            status: .blocked,
            label: "Blocked",
            background: Color(hex: "#DC2626").opacity(0.3),
            foreground: Color(hex: "#F87171"),       // Red-400
            icon: "exclamationmark.triangle"
        )
    ]

    static let height: CGFloat = 24
    static let paddingH: CGFloat = 8
    static let paddingV: CGFloat = 4
    static let cornerRadius: CGFloat = 6
}
```

### 4.6 Progress Indicator (Dot Style)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  PROGRESS BAR                                                   │
│                                                                 │
│  ●●●●●●○○○○  60%                                               │
│  ↑                                                              │
│  10 dots (filled = completed, hollow = remaining)               │
│                                                                 │
│  SPECIFICATIONS:                                                │
│  - Dot diameter: 6px                                            │
│  - Dot spacing: 4px                                             │
│  - Filled color: Column color (blue for In Progress)            │
│  - Empty color: white @ 20%                                     │
│  - Percentage: caption font, medium weight                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation**

```swift
struct ProgressDots: View {
    let completed: Int
    let total: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < completed ? accentColor : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
            }

            Text("\(Int((Double(completed) / Double(total)) * 100))%")
                .font(DSTypography.captionBold)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }
}
```

### 4.7 Empty Column State

```
┌───────────────────────────────────────────────────────┐
│                                                       │
│                      ○                                │
│                  (ghost icon)                         │
│                  32px, white @ 15%                    │
│                                                       │
│              No tasks in progress                     │
│                                                       │
│        Drag tasks here or start a session             │
│                                                       │
│                  [Start Session]                      │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## 5. Roadmap View

### 5.1 Priority Matrix Layout (MoSCoW)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                ROADMAP                                           │
│                                                                                  │
│  Impact                                                                          │
│    ▲                                                                             │
│    │                                                                             │
│  HIGH   ┌─────────────────────────────┬─────────────────────────────┐           │
│    │    │                             │                             │           │
│    │    │     SHOULD HAVE             │      MUST HAVE              │           │
│    │    │     Quick wins              │      Critical path          │           │
│    │    │     (High impact, low eff)  │      (High impact, high eff)│           │
│    │    │                             │                             │           │
│    │    │  ┌────────┐ ┌────────┐      │  ┌────────┐ ┌────────┐      │           │
│    │    │  │ Card   │ │ Card   │      │  │ Card   │ │ Card   │      │           │
│    │    │  └────────┘ └────────┘      │  └────────┘ └────────┘      │           │
│    │    │                             │                             │           │
│    │    ├─────────────────────────────┼─────────────────────────────┤           │
│    │    │                             │                             │           │
│    │    │     WON'T HAVE              │      COULD HAVE             │           │
│    │    │     Deprioritized           │      Nice to have           │           │
│    │    │     (Low impact, low eff)   │      (Low impact, high eff) │           │
│    │    │                             │                             │           │
│    │    │  ┌────────┐                 │  ┌────────┐ ┌────────┐      │           │
│    │    │  │ Card   │                 │  │ Card   │ │ Card   │      │           │
│    │    │  └────────┘                 │  └────────┘ └────────┘      │           │
│  LOW    │                             │                             │           │
│    │    └─────────────────────────────┴─────────────────────────────┘           │
│    └───────────────────────────────────────────────────────────────►  Effort    │
│                          LOW                          HIGH                       │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Quadrant Specifications

```swift
struct RoadmapQuadrantSpec {
    static let quadrants: [Quadrant] = [
        Quadrant(
            id: "must_have",
            title: "Must Have",
            subtitle: "High impact, high effort - Critical path",
            position: .topRight,
            color: Color(hex: "#22C55E"),  // Green
            icon: "star.fill"
        ),
        Quadrant(
            id: "should_have",
            title: "Should Have",
            subtitle: "High impact, low effort - Quick wins",
            position: .topLeft,
            color: Color(hex: "#3B82F6"),  // Blue
            icon: "bolt.fill"
        ),
        Quadrant(
            id: "could_have",
            title: "Could Have",
            subtitle: "Low impact, high effort - Nice to have",
            position: .bottomRight,
            color: Color(hex: "#F59E0B"),  // Amber
            icon: "sparkles"
        ),
        Quadrant(
            id: "wont_have",
            title: "Won't Have",
            subtitle: "Low impact, low effort - Not now",
            position: .bottomLeft,
            color: Color(hex: "#6B7280"),  // Gray
            icon: "minus.circle"
        )
    ]

    static let gap: CGFloat = 2
    static let padding: CGFloat = 16
    static let headerHeight: CGFloat = 48
    static let background = Color.white.opacity(0.03)
    static let borderColor = Color.white.opacity(0.08)
    static let cornerRadius: CGFloat = 16
}
```

### 5.3 Roadmap Feature Card

```
┌───────────────────────────────────────────────────────┐
│                                                       │
│  ROADMAP CARD (Compact, 80px height)                  │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │  OAuth Integration                              │  │
│  │                                                 │  │
│  │  [High Effort]  [Critical Impact]              │  │
│  │                                                 │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  Width: Auto-fit grid (min 180px, max 280px)          │
│  Background: white @ 5%                               │
│  Border: 1px white @ 10%                              │
│  Border radius: 10px                                  │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### 5.4 Effort & Impact Badges

```swift
struct EffortImpactBadgeSpec {
    // Effort badges
    static let effortBadges: [Badge] = [
        Badge(level: .low, label: "Low Effort", color: Color(hex: "#22C55E")),
        Badge(level: .medium, label: "Med Effort", color: Color(hex: "#F59E0B")),
        Badge(level: .high, label: "High Effort", color: Color(hex: "#EF4444"))
    ]

    // Impact badges
    static let impactBadges: [Badge] = [
        Badge(level: .low, label: "Low Impact", color: Color(hex: "#6B7280")),
        Badge(level: .medium, label: "Med Impact", color: Color(hex: "#3B82F6")),
        Badge(level: .high, label: "Critical", color: Color(hex: "#8B5CF6"))
    ]

    static let height: CGFloat = 20
    static let paddingH: CGFloat = 6
    static let paddingV: CGFloat = 2
    static let cornerRadius: CGFloat = 4
    static let gap: CGFloat = 4
}
```

---

## 6. Worktree Integration

### 6.1 Data Model

```swift
/// Kanban card linked to a git worktree
public struct KanbanCard: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String?
    public var columnId: UUID
    public var order: Int

    // Session link
    public var sessionId: UUID?

    // Worktree link
    public var worktreeInfo: WorktreeInfo?

    // Progress
    public var progress: CardProgress?

    // Metadata
    public var engineType: EngineType?
    public var memoryCount: Int
    public var turnCount: Int
    public var duration: TimeInterval?
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
}

/// Git worktree information
public struct WorktreeInfo: Codable, Sendable {
    public let path: String                    // /path/to/.worktrees/feature-branch
    public let branchName: String              // blaze/add-oauth-login
    public let repoPath: String                // /path/to/main/repo
    public let baseCommit: String              // SHA of branch point
    public var gitStatus: WorktreeGitStatus?
}

public struct WorktreeGitStatus: Codable, Sendable {
    public var filesChanged: Int
    public var insertions: Int
    public var deletions: Int
    public var hasConflicts: Bool
    public var aheadBy: Int
    public var behindBy: Int
}
```

### 6.2 State Machine (Column Transitions)

```
                         ┌──────────────────────────────────────┐
                         ▼                                      │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌──────┴──────┐
│   PLANNING  │───▶│ IN PROGRESS │───▶│   REVIEW    │───▶│    DONE     │
│             │    │             │    │             │    │             │
│  (queued)   │    │  (running)  │    │ (needs attn)│    │ (completed) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                   │
       │                  │                  │                   │
       ▼                  ▼                  ▼                   ▼
    Manual            Session            Session            Merge
    drag              started            stopped            completed
                                         (or error)
```

**Auto-Move Triggers**

| Trigger | From | To |
|---------|------|-----|
| `sessionStarted` | Planning | In Progress |
| `sessionStopped` (success) | In Progress | Review |
| `sessionStopped` (error) | In Progress | Review (with error badge) |
| `mergeComplete` | Review | Done |
| `toolApprovalPending` | In Progress | Review |
| Manual drag | Any | Any |

### 6.3 Git Status Indicators on Card

```
┌────────────────────────────────────────────────────────────────┐
│  ┌────────┐  Add OAuth to login flow              [Running]    │
│  │ Claude │  ──────────────────────────────                   │
│  └────────┘  Planning phase                                    │
│                                                                │
│  ●●●●●●○○○○  60%                                              │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  📂 blaze/add-oauth-login              [Copy Branch]     │  │
│  │  Changed: 3 files (+142, -28)          [View Diff]       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  🧠 3 memories   📝 12 turns   ⏱ 4:32            2m ago       │
└────────────────────────────────────────────────────────────────┘
```

**Git Status Indicators**

| Status | Icon | Color |
|--------|------|-------|
| Clean | None | -- |
| Has changes | `+` / `-` counts | `text-secondary` |
| Ahead | `arrow.up.circle` | `#22C55E` (green) |
| Behind | `arrow.down.circle` | `#F59E0B` (amber) |
| Conflicts | `exclamationmark.triangle` | `#EF4444` (red) |

### 6.4 Session Linking

When a session starts, it auto-links to a Kanban card:

```swift
// In SessionOrchestrator
func onSessionStarted(session: Session) async {
    // Create Kanban card
    let card = KanbanCard(
        id: UUID(),
        title: session.name,
        columnId: kanbanStore.inProgressColumnId,
        sessionId: session.id,
        worktreeInfo: session.worktreeInfo,
        engineType: session.engineType,
        progress: CardProgress(status: .running),
        createdAt: Date()
    )

    await kanbanStore.createCard(card)
}

// Route CLI events to Kanban progress
func onCLIEvent(_ event: NormalizedEvent, sessionId: UUID) async {
    await kanbanStore.handleEvent(event, sessionId: sessionId)
}
```

### 6.5 Conflict Handling

When merge conflicts are detected:

1. Card status changes to "Blocked" (red badge)
2. Warning icon appears in git status section
3. Click card opens conflict resolution UI in main window

---

## 7. Interactions & Animations

### 7.1 Hover States

**Cards**

```
At rest:         Hovered:
bg #141416       bg #1A1A1D (+1 step lighter)
shadow ambient   shadow elevated
border 10%       border 20%
                 action icons fade in (0→1)
```

Transition: `DSMotion.snappy` (0.25s spring)

**Buttons**

```
At rest:         Hovered:
accent bg        accent-hover bg (+10% lighter)
scale 1.0        scale 1.0 (NO scale on buttons)
```

### 7.2 Press States

**Cards**

```
Pressed:
scale 0.98
bg #141416 (back to rest, dimmer)
shadow reduced
```

**Buttons**

```
Pressed:
scale 0.95
brightness 0.9
```

### 7.3 Drag-Drop Feedback

```
1. GRAB (mouseDown + 150ms hold)
   ─────────────────────────────
   - Cursor: grabbing
   - Card: scale 1.02, shadow 30px radius
   - Ghost placeholder at original position (dashed border)
   - Z-index to front

2. DRAG (mousemove)
   ──────────────────
   - Card follows cursor with 8px offset
   - Valid drop zones: bg pulse animation (subtle breathing)
   - Invalid zones: forbidden cursor
   - Other cards animate to make space

3. HOVER OVER COLUMN (300ms)
   ──────────────────────────
   - Column header pulses with column color
   - Drop indicator appears at insertion point
   - Cards above/below slide apart

4. DROP (on valid zone)
   ─────────────────────
   - Snap to new position (DSMotion.bouncy)
   - Scale 1.02 → 1.0 with overshoot
   - Success glow pulse (1 cycle)
   - Optimistic update, persist in background

5. DROP (on invalid zone / cancel)
   ────────────────────────────────
   - Return to original position (DSMotion.smooth)
   - Shake animation: +/- 4px horizontal, 3 cycles, 0.4s
   - No glow
```

**Drop Zone Indicator**

```swift
struct DropZoneIndicator {
    let strokeStyle = StrokeStyle(lineWidth: 2, dash: [8, 4])
    let color = Color(hex: "#3B82F6")
    let backgroundColor = Color(hex: "#3B82F6").opacity(0.1)
    let cornerRadius: CGFloat = 8
    let animation = Animation.easeInOut(duration: 0.3).repeatForever()
}
```

### 7.4 Success/Error Feedback

**Success (task completed, merge done)**

```
- Brief scale overshoot: 1.0 → 1.05 → 1.0
- Green glow pulse: opacity 0 → 0.4 → 0
- Sound: subtle chime (optional, off by default)
```

**Error (operation failed)**

```
- Shake: +/- 4px horizontal, 3 oscillations
- Red border flash: 2 pulses
- Error icon appears inline (NOT a modal)
```

**Progress tick (step completed)**

```
- Progress dot fills: scale 0 → 1.1 → 1.0
- Progress bar segment animates fill
- Percentage counter animates
```

### 7.5 Micro-interactions

**Copy Branch Name**

```
[Copy Branch] → Click
    ↓
[checkmark.circle] → 1s fade → [Copy Branch]
```

No toast notification. Inline confirmation only.

**Card Selection**

```
Click card → 2px focus ring with blur
Focus ring: accent @ 60%, blur 2px
```

---

## 8. Accessibility

### 8.1 Keyboard Navigation

**Kanban Board**

| Shortcut | Action |
|----------|--------|
| Arrow Left/Right | Move between columns |
| Arrow Up/Down | Move between cards in column |
| Enter | Open selected card for editing |
| Space | Toggle card selection |
| Cmd+Shift+Arrow | Move card(s) to adjacent column |
| Tab | Next card |
| Shift+Tab | Previous card |
| Home | First card in column |
| End | Last card in column |

**Roadmap**

| Shortcut | Action |
|----------|--------|
| Arrow keys | Navigate between quadrants |
| Tab | Next feature in quadrant |
| Enter | Open feature details |
| Cmd+1/2/3/4 | Jump to specific quadrant |

### 8.2 VoiceOver Labels

```swift
struct KanbanAccessibility {
    // Card label template
    static func cardLabel(card: KanbanCard) -> String {
        var parts: [String] = []
        parts.append(card.title)
        parts.append("Status: \(card.status.displayName)")
        if let progress = card.progress?.percentComplete {
            parts.append("Progress: \(Int(progress * 100))%")
        }
        parts.append("Column: \(card.columnName)")
        if let engine = card.engineType {
            parts.append("Engine: \(engine.displayName)")
        }
        return parts.joined(separator: ", ")
    }

    // Column label
    static func columnLabel(column: KanbanColumn) -> String {
        "\(column.name) column, \(column.cardCount) tasks"
    }

    // Drag hint
    static let dragHint = "Double-tap and hold, then drag to move task"
}
```

### 8.3 Focus Indicators

```swift
struct FocusIndicatorStyle {
    // Standard focus ring (blurred for premium feel)
    static let ring = RoundedRectangle(cornerRadius: 12)
        .stroke(Color.accent.opacity(0.6), lineWidth: 2)
        .blur(radius: 2)
        .padding(-4)

    // High contrast mode
    static let highContrastRing = RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white, lineWidth: 3)
        .padding(-6)
}
```

### 8.4 Reduced Motion

```swift
struct MotionAwareModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? DSMotion.instant : animation,
            value: /* binding */
        )
    }
}
```

When `accessibilityReduceMotion` is enabled:

- All springs become instant (0.01s linear)
- Staggered card entrance disabled
- Breathing animations disabled
- Drag preview is static

---

## 9. Implementation Plan

> ⛔ **IMPLEMENTATION BOUNDARY - READ BEFORE CODING**
>
> **Files you MAY modify in the main app:**
> - `BlazeApp.swift` - Add `Window("Project Management", ...)` scene
> - `ContentView.swift` - Add ONE button to toolbar (lines ~90-100 area)
>
> **Files you MUST NOT modify:**
> - `ThreeColumnLayout.swift` - Do not touch
> - `ProjectListView.swift` - Do not touch
> - `ChatTimelineView.swift` - Do not touch
> - `SidebarContainer.swift` - Do not touch
> - Any existing navigation or layout code
>
> **All new code goes in:** `Blaze/Sources/ProjectManagement/`

### Phase 1: Window & Layout (3-4 days)

- [ ] Create `KanbanRoadmapWindow` as new SwiftUI Window
- [ ] Implement `VisualEffectBackground` with gradient tint
- [ ] Build left sidebar navigation component
- [ ] Add view switching logic (Kanban / Roadmap)
- [ ] Implement top toolbar (search, filter, new task)
- [ ] Add keyboard shortcut bindings (Cmd+1/2)
- [ ] Wire window trigger from main app (Cmd+Shift+K)

**Files to create:**

```
Blaze/Sources/
  ProjectManagement/
    KanbanRoadmapWindow.swift
    ProjectManagementState.swift
    SidebarView.swift
    ToolbarView.swift
```

### Phase 2: Kanban Core (5-6 days)

- [ ] Create `KanbanColumnView` component
- [ ] Create `TaskCardView` with all states
- [ ] Implement status badges
- [ ] Implement progress dots indicator
- [ ] Add empty column states
- [ ] Connect to `KanbanStore` (from internal API spec)
- [ ] Wire CLI events to progress updates

**Files to create:**

```
Blaze/Sources/
  ProjectManagement/
    Kanban/
      KanbanBoardView.swift
      KanbanColumnView.swift
      TaskCardView.swift
      ProgressDotsView.swift
      StatusBadge.swift
```

### Phase 3: Drag-Drop (3-4 days)

- [ ] Implement drag gesture recognizer
- [ ] Create ghost card during drag
- [ ] Add drop zone highlighting with breathing
- [ ] Implement card reordering animation
- [ ] Add optimistic update with rollback
- [ ] Test edge cases (blocked cards, WIP limits)

### Phase 4: Roadmap View (3-4 days)

- [ ] Create `PriorityMatrixView` with 2x2 layout
- [ ] Create `RoadmapCardView` component
- [ ] Add quadrant headers with icons
- [ ] Implement drag-drop between quadrants
- [ ] Add effort/impact badge components
- [ ] Cross-fade transition from Kanban

**Files to create:**

```
Blaze/Sources/
  ProjectManagement/
    Roadmap/
      RoadmapView.swift
      PriorityMatrixView.swift
      QuadrantView.swift
      RoadmapCardView.swift
      EffortImpactBadge.swift
```

### Phase 5: Worktree Integration (2-3 days)

- [ ] Link `KanbanCard` to `WorktreeInfo`
- [ ] Display git status on cards
- [ ] Implement auto-move rules on CLI events
- [ ] Add "Copy Branch" and "View Diff" actions
- [ ] Wire session linking (session start -> card create)

### Phase 6: Interactions & Polish (2-3 days)

- [ ] Implement all hover states
- [ ] Add context menus
- [ ] Implement multi-select (Shift+Click)
- [ ] Create bulk action bar
- [ ] Add view transition animations
- [ ] Implement staggered card reveal

### Phase 7: Accessibility (2 days)

- [ ] Add all VoiceOver labels
- [ ] Implement full keyboard navigation
- [ ] Add focus ring indicators
- [ ] Implement reduced motion fallbacks
- [ ] Add dynamic announcements for state changes
- [ ] Test with VoiceOver enabled

**Total: ~20-24 days**

### Verification Steps

1. **Window spawns correctly** - Cmd+Shift+K opens popup, glass effect visible
2. **Columns render** - 4 columns visible, correct colors and icons
3. **Cards display** - Title, status, progress, metadata all visible
4. **Drag-drop works** - Card moves between columns, optimistic update
5. **CLI integration** - Start session, watch card auto-move and progress update
6. **View switch** - Cross-fade between Kanban and Roadmap
7. **Keyboard nav** - Navigate entire board with j/k/h/l
8. **VoiceOver** - Full screen reader support
9. **Reduced motion** - All animations instant when enabled

---

## 10. Open Questions & Decisions

### Confirmed Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Window type | Separate popup | Parallel visibility, multi-monitor support |
| Column count | 4 columns | Simpler mental model, maps to session states |
| View switch location | Sidebar + content header | Linear-style, keyboard accessible |
| Progress indicator | Dot style | More visual, maps to step completion |
| Drag cancel | Return to original | No confirmation dialogs |

### Remaining Decisions for User

| Question | Options | Default |
|----------|---------|---------|
| **Sound effects?** | Silent / Subtle chimes | Silent |
| **Card click behavior** | Open in main window / Show popover | Open in main |
| **Archived cards in Done?** | Always visible / Toggle | Toggle (off by default) |
| **WIP limits?** | Enabled / Disabled | Enabled (3 for In Progress) |
| **Multi-project view?** | Single project / All projects | Single project |

### Future Considerations (Post-MVP)

1. **Timeline view** - Gantt-style horizontal timeline
2. **Insights view** - Analytics on session performance
3. **Changelog** - Auto-generated from completed sessions
4. **GitHub sync** - Two-way sync with GitHub Issues

---

## Appendix A: SF Symbol Reference

**Sidebar**

| Item | Symbol |
|------|--------|
| Kanban Board | `rectangle.3.group` |
| Roadmap | `map` |
| Worktrees | `arrow.triangle.branch` |
| Settings | `gearshape` |

**Status**

| Status | Symbol |
|--------|--------|
| Pending | `circle` (hollow) |
| Running | `arrow.triangle.2.circlepath` |
| Review | `eye` |
| Done | `checkmark` |
| Blocked | `exclamationmark.triangle` |

**Priority (Roadmap)**

| Priority | Symbol |
|----------|--------|
| Must Have | `star.fill` |
| Should Have | `bolt.fill` |
| Could Have | `sparkles` |
| Won't Have | `minus.circle` |

---

## Appendix B: Color Token Mapping

> ⚠️ **FOR DESIGN REFERENCE ONLY - DO NOT USE HEX VALUES IN CODE**
>
> Use the existing `DSColors` API. These hex values are approximate references for designers.

**Use These APIs (from DSColors.swift):**

```swift
// BACKGROUNDS - use theme-aware tokens
Color.ds.bg0         // window chrome
Color.ds.bg1         // app background
Color.ds.panel       // card at rest
Color.ds.surface     // interactive surfaces

// SEMANTIC COLORS - use theme-aware tokens
Color.ds.accent      // primary accent
Color.ds.positive    // success (green)
Color.ds.warning     // warning (amber)
Color.ds.negative    // error (red)

// KANBAN COLUMNS - define in KanbanColumn enum, not hardcoded
KanbanColumn.planning.color    // gray
KanbanColumn.inProgress.color  // blue
KanbanColumn.review.color      // amber
KanbanColumn.done.color        // emerald

// ENGINE BRANDS - already defined in EngineType
EngineType.claude.brandColor   // terracotta
EngineType.gemini.brandColor   // google blue
EngineType.codex.brandColor    // openai green
```

**If new colors are needed:**
1. Add them to `DSColors.swift` with theme-aware fallbacks
2. Do NOT hardcode hex values in view code
3. Update `docs/specs/design-system.md` with the new tokens

---

**End of Specification**

---

*This specification provides complete implementation guidance for the Kanban + Roadmap popup window. Use existing design tokens from `Blaze/Sources/DesignSystem/Tokens/`. Coordinate with `docs/specs/design-system.md` for any token updates.*
