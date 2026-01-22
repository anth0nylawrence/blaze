# Kanban + Roadmap Popup Window - UI/UX Specification

> **Version:** 1.0.0
> **Last Updated:** 2026-01-22
> **Status:** Ready for Implementation

---

## Executive Summary

This specification defines the complete UI/UX for Blaze's Kanban Board and Visual Roadmap popup window. The popup provides project management and feature planning capabilities in a standalone window, featuring a 4-column Kanban board and a priority-matrix Roadmap view.

**Design Philosophy:** Dark, glass-morphic aesthetic consistent with Blaze's main app. Every interaction should feel responsive, purposeful, and polished.

---

## Table of Contents

1. [Window Specifications](#1-window-specifications)
2. [Navigation & Layout](#2-navigation--layout)
3. [Kanban Board Specification](#3-kanban-board-specification)
4. [Roadmap View Specification](#4-roadmap-view-specification)
5. [Interaction Design](#5-interaction-design)
6. [Animation Specifications](#6-animation-specifications)
7. [Accessibility](#7-accessibility)
8. [Component Library Reference](#8-component-library-reference)
9. [Implementation Checklist](#9-implementation-checklist)

---

## 1. Window Specifications

### 1.1 Window Dimensions

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Default Size:    1200px (w) x 800px (h)                   │
│  Minimum Size:    900px (w) x 600px (h)                    │
│  Maximum Size:    Screen bounds                             │
│                                                             │
│  Aspect Ratio:    1.5:1 (recommended)                      │
│  Resizable:       Yes, all edges and corners               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Window Style

```swift
// Window Configuration
struct KanbanRoadmapWindow {
    // Title bar
    let titleBarStyle: NSWindow.TitleVisibility = .hidden
    let titleBarHeight: CGFloat = 0  // Integrated into content
    let trafficLightPosition: CGPoint = CGPoint(x: 16, y: 16)

    // Background
    let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "#0f0f23"),  // Deep navy
            Color(hex: "#1a1a3e")   // Subtle purple tint
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Glass effect
    let material: NSVisualEffectView.Material = .hudWindow
    let blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    // Shadow
    let shadowRadius: CGFloat = 40
    let shadowOpacity: Float = 0.5
    let shadowOffset: CGSize = CGSize(width: 0, height: -10)
}
```

### 1.3 Window Chrome

```
┌─────────────────────────────────────────────────────────────────────┐
│ ● ● ●                                                               │
│  ↑                                                                  │
│  Traffic lights (hover reveals minimize/maximize)                   │
│                                                                     │
│  No visible title bar - content extends to top edge                │
│  Window draggable from top 40px of content area                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- Use `.windowStyle(.hiddenTitleBar)` for borderless appearance
- Implement custom drag region in top area
- Traffic lights should use macOS native appearance
- Window remembers last position/size per user

---

## 2. Navigation & Layout

### 2.1 Three-Column Layout

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●                                            [Search]  [Filter]  [+New]    │
├───────────────────┬─────────────────────────────────────────────────────────────┤
│                   │                                                             │
│   LEFT SIDEBAR    │                    MAIN CONTENT AREA                        │
│   (220px fixed)   │                    (Flexible width)                         │
│                   │                                                             │
│  ┌─────────────┐  │  ┌────────────────────────────────────────────────────┐    │
│  │ PROJECT     │  │  │                                                    │    │
│  │ ─────────── │  │  │   Kanban Board OR Roadmap View                     │    │
│  │ ▶ Kanban    │◀─┼──│   (Based on sidebar selection)                     │    │
│  │   Terminals │  │  │                                                    │    │
│  │   Insights  │  │  │                                                    │    │
│  │ ▶ Roadmap   │  │  │                                                    │    │
│  │   Ideation  │  │  │                                                    │    │
│  │   Changelog │  │  │                                                    │    │
│  │   Context   │  │  │                                                    │    │
│  │             │  │  │                                                    │    │
│  │ TOOLS       │  │  │                                                    │    │
│  │ ─────────── │  │  │                                                    │    │
│  │   GitHub    │  │  │                                                    │    │
│  │   Worktrees │  │  │                                                    │    │
│  │             │  │  │                                                    │    │
│  └─────────────┘  │  └────────────────────────────────────────────────────┘    │
│                   │                                                             │
│  ┌─────────────┐  │                                                             │
│  │ ⚙ Settings  │  │                                                             │
│  │ + New Task  │  │                                                             │
│  └─────────────┘  │                                                             │
└───────────────────┴─────────────────────────────────────────────────────────────┘
```

### 2.2 Left Sidebar Specification

```swift
struct SidebarSpec {
    // Dimensions
    static let width: CGFloat = 220
    static let minWidth: CGFloat = 200
    static let maxWidth: CGFloat = 280

    // Spacing
    static let sectionHeaderPadding = EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)
    static let itemPadding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    static let itemSpacing: CGFloat = 2

    // Colors
    static let background = Color(hex: "#0a0a1a").opacity(0.6)
    static let border = Color.white.opacity(0.08)
    static let sectionHeaderColor = Color.white.opacity(0.4)
    static let itemColor = Color.white.opacity(0.8)
    static let itemActiveBackground = Color(hex: "#3B82F6").opacity(0.2)
    static let itemActiveAccent = Color(hex: "#3B82F6")
    static let itemHoverBackground = Color.white.opacity(0.05)
}
```

**Sidebar Items:**

| Section | Item | Icon (SF Symbol) | Keyboard Shortcut |
|---------|------|------------------|-------------------|
| PROJECT | Kanban Board | `rectangle.3.group` | Cmd+1 |
| PROJECT | Agent Terminals | `terminal` | Cmd+2 |
| PROJECT | Insights | `chart.bar` | Cmd+3 |
| PROJECT | Roadmap | `map` | Cmd+4 |
| PROJECT | Ideation | `lightbulb` | Cmd+5 |
| PROJECT | Changelog | `clock.arrow.circlepath` | Cmd+6 |
| PROJECT | Context | `doc.text.magnifyingglass` | Cmd+7 |
| TOOLS | GitHub Issues | `arrow.up.right.square` | Cmd+8 |
| TOOLS | Worktrees | `arrow.triangle.branch` | Cmd+9 |

**Sidebar Item States:**

```
┌───────────────────────────────────────────────────────────┐
│  NORMAL STATE                                              │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  ○  Kanban Board                                    │  │
│  │     opacity: 0.8, background: transparent           │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  HOVER STATE                                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  ○  Kanban Board                                    │  │
│  │     opacity: 1.0, background: white/5%              │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ACTIVE STATE                                              │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  ●  Kanban Board                           [active] │  │
│  │     opacity: 1.0, background: blue/20%              │  │
│  │     left border: 2px solid blue                     │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

### 2.3 Top Toolbar

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●        Blaze - Kanban Board        [🔍 Search...]  [Filter ▾]  [+ New Task]│
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Height: 52px                                                                    │
│  Background: transparent (inherits window gradient)                             │
│  Border-bottom: 1px solid rgba(255,255,255,0.08)                               │
│                                                                                  │
│  Window title: centered, font: Typography.body.weight(.medium)                  │
│  Changes based on active view: "Kanban Board", "Roadmap", etc.                 │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Toolbar Components:**

| Component | Position | Width | Description |
|-----------|----------|-------|-------------|
| Window Title | Center | Auto | Current view name |
| Search Field | Right-3 | 180px | Quick search tasks |
| Filter Dropdown | Right-2 | Auto | Filter by status/assignee/priority |
| New Task Button | Right-1 | Auto | Primary action button |

---

## 3. Kanban Board Specification

### 3.1 Board Layout

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                KANBAN BOARD                                      │
├────────────────────┬────────────────────┬────────────────────┬──────────────────┤
│                    │                    │                    │                  │
│  PLANNING          │  IN PROGRESS       │  REVIEW            │  DONE            │
│  ──────────────    │  ──────────────    │  ──────────────    │  ──────────────  │
│  (3)  [+]          │  (2)               │  (1)               │  (5)             │
│                    │                    │                    │                  │
│  ┌──────────────┐  │  ┌──────────────┐  │  ┌──────────────┐  │  ┌────────────┐  │
│  │ Task Card    │  │  │ Task Card    │  │  │ Task Card    │  │  │ Task Card  │  │
│  │              │  │  │              │  │  │              │  │  │            │  │
│  └──────────────┘  │  └──────────────┘  │  └──────────────┘  │  └────────────┘  │
│                    │                    │                    │                  │
│  ┌──────────────┐  │  ┌──────────────┐  │                    │  ┌────────────┐  │
│  │ Task Card    │  │  │ Task Card    │  │                    │  │ Task Card  │  │
│  │              │  │  │              │  │    Empty State:    │  │            │  │
│  └──────────────┘  │  └──────────────┘  │    "No tasks       │  └────────────┘  │
│                    │                    │    awaiting        │                  │
│  ┌──────────────┐  │                    │    review"         │  ┌────────────┐  │
│  │ Task Card    │  │                    │                    │  │ Task Card  │  │
│  │              │  │                    │    [Drag tasks     │  │            │  │
│  └──────────────┘  │                    │    here]           │  └────────────┘  │
│                    │                    │                    │                  │
│  Drop Zone         │                    │                    │                  │
│  (dashed border    │                    │                    │                  │
│   when dragging)   │                    │                    │                  │
│                    │                    │                    │                  │
└────────────────────┴────────────────────┴────────────────────┴──────────────────┘
```

### 3.2 Column Specifications

```swift
struct KanbanColumnSpec {
    // Dimensions
    static let columnWidth: CGFloat = 280
    static let columnMinWidth: CGFloat = 240
    static let columnMaxWidth: CGFloat = 360
    static let columnGap: CGFloat = 16
    static let headerHeight: CGFloat = 48

    // Column definitions
    static let columns: [KanbanColumnDef] = [
        KanbanColumnDef(
            id: "planning",
            title: "Planning",
            color: Color(hex: "#6B7280"),  // Gray
            icon: "doc.text",
            canAddCards: true,
            wipLimit: nil
        ),
        KanbanColumnDef(
            id: "in_progress",
            title: "In Progress",
            color: Color(hex: "#3B82F6"),  // Blue
            icon: "gearshape",
            canAddCards: false,
            wipLimit: 3  // Optional WIP limit
        ),
        KanbanColumnDef(
            id: "review",
            title: "Review",
            color: Color(hex: "#F59E0B"),  // Amber
            icon: "eye",
            canAddCards: false,
            wipLimit: nil
        ),
        KanbanColumnDef(
            id: "done",
            title: "Done",
            color: Color(hex: "#10B981"),  // Green
            icon: "checkmark.circle",
            canAddCards: false,
            wipLimit: nil
        )
    ]

    // Styling
    static let headerBackground = Color.white.opacity(0.05)
    static let headerBorderRadius: CGFloat = 8
    static let countBadgeSize: CGFloat = 20
}
```

### 3.3 Column Header Design

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  COLUMN HEADER (48px height)                               │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  ●  Planning                          (3)   [+]       │ │
│  │  ↑  ↑                                  ↑     ↑        │ │
│  │  │  │                                  │     │        │ │
│  │  │  Title (Typography.h4)              │     Add btn  │ │
│  │  │                                     │     (only    │ │
│  │  Status dot (column color)             │     Planning)│ │
│  │                                        │              │ │
│  │                                   Count badge         │ │
│  │                                   (gray bg, white #)  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  Background: rgba(255,255,255,0.05)                        │
│  Border-radius: 8px (top corners only)                     │
│  Padding: 12px 16px                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 Task Card Design

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  TASK CARD (Variable height, min 120px)                    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  Implement auth feature              [Pending]        │ │
│  │  ─────────────────────────────────────────────        │ │
│  │  Add OAuth2 integration with GitHub                   │ │
│  │  for user authentication flow...                      │ │
│  │                                                       │ │
│  │  Progress  ●●●●●●○○○○  60%               [Start]      │ │
│  │  ⏱ 2h ago                                             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  LAYOUT BREAKDOWN:                                         │
│                                                             │
│  Row 1: Title + Status Badge                               │
│  Row 2: Separator (1px, white/10%)                        │
│  Row 3: Description (2 lines max, ellipsis)               │
│  Row 4: Progress bar + percentage + Action button          │
│  Row 5: Timestamp + metadata                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Card Dimensions:**

```swift
struct TaskCardSpec {
    // Dimensions
    static let width: CGFloat = .infinity  // Fill column
    static let minHeight: CGFloat = 120
    static let maxHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 12
    static let padding = EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16)
    static let cardSpacing: CGFloat = 12

    // Background
    static let background = Color(hex: "#1a1a2e").opacity(0.8)
    static let backgroundHover = Color(hex: "#1a1a2e")
    static let backgroundDragging = Color(hex: "#252545")

    // Border
    static let borderColor = Color.white.opacity(0.1)
    static let borderColorHover = Color.white.opacity(0.2)
    static let borderWidth: CGFloat = 1

    // Shadow
    static let shadowRadius: CGFloat = 4
    static let shadowColor = Color.black.opacity(0.2)
    static let shadowRadiusDragging: CGFloat = 16

    // Typography
    static let titleFont = Typography.body.weight(.semibold)
    static let descriptionFont = Typography.bodySmall
    static let descriptionMaxLines = 2
    static let timestampFont = Typography.caption
}
```

### 3.5 Status Badge Specification

```swift
struct StatusBadgeSpec {
    static let badges: [StatusBadgeDef] = [
        StatusBadgeDef(
            status: .pending,
            label: "Pending",
            background: Color(hex: "#374151"),  // Gray-700
            foreground: Color(hex: "#D1D5DB"),  // Gray-300
            icon: nil
        ),
        StatusBadgeDef(
            status: .inProgress,
            label: "In Progress",
            background: Color(hex: "#1D4ED8").opacity(0.3),  // Blue-700/30%
            foreground: Color(hex: "#60A5FA"),  // Blue-400
            icon: "arrow.triangle.2.circlepath"
        ),
        StatusBadgeDef(
            status: .needsReview,
            label: "Needs Review",
            background: Color(hex: "#D97706").opacity(0.3),  // Amber-600/30%
            foreground: Color(hex: "#FBBF24"),  // Amber-400
            icon: "eye"
        ),
        StatusBadgeDef(
            status: .completed,
            label: "Completed",
            background: Color(hex: "#059669").opacity(0.3),  // Emerald-600/30%
            foreground: Color(hex: "#34D399"),  // Emerald-400
            icon: "checkmark"
        ),
        StatusBadgeDef(
            status: .blocked,
            label: "Blocked",
            background: Color(hex: "#DC2626").opacity(0.3),  // Red-600/30%
            foreground: Color(hex: "#F87171"),  // Red-400
            icon: "exclamationmark.triangle"
        )
    ]

    // Dimensions
    static let height: CGFloat = 24
    static let paddingH: CGFloat = 8
    static let paddingV: CGFloat = 4
    static let cornerRadius: CGFloat = 6
    static let font = Typography.caption.weight(.medium)
    static let iconSize: CGFloat = 10
}
```

### 3.6 Progress Indicator

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  PROGRESS BAR                                              │
│                                                             │
│  Progress  ●●●●●●○○○○  60%                                 │
│            ↑                                                │
│            │                                                │
│            10 segments (filled = completed, hollow = rem)  │
│                                                             │
│  SPECIFICATIONS:                                           │
│  - Width: 100px (10 dots x 8px + 2px spacing)             │
│  - Dot diameter: 6px                                        │
│  - Dot spacing: 4px                                         │
│  - Filled color: Column color (blue for In Progress)       │
│  - Empty color: rgba(255,255,255,0.2)                      │
│  - Label: "Progress" in Typography.caption                  │
│  - Percentage: Typography.caption.weight(.medium)           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.7 Empty Column State

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  EMPTY COLUMN STATE                                        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                                                       │ │
│  │                      ○                               │ │
│  │                  (ghost icon)                        │ │
│  │                                                       │ │
│  │              No tasks in progress                    │ │
│  │                                                       │ │
│  │        Drag tasks here or click [+] to add          │ │
│  │                                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  SPECIFICATIONS:                                           │
│  - Icon: SF Symbol matching column type                    │
│  - Icon size: 32px                                          │
│  - Icon color: rgba(255,255,255,0.15)                      │
│  - Title: Typography.body, rgba(255,255,255,0.4)           │
│  - Subtitle: Typography.caption, rgba(255,255,255,0.25)    │
│  - Background: dashed border when dragging over            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Roadmap View Specification

### 4.1 Priority Matrix Layout

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                ROADMAP                                           │
│                                                                                  │
│  Impact ▲                                                                        │
│         │                                                                        │
│    HIGH │  ┌─────────────────────────┬─────────────────────────┐               │
│         │  │                         │                         │               │
│         │  │     SHOULD HAVE         │      MUST HAVE          │               │
│         │  │     (3 features)        │      (5 features)       │               │
│         │  │                         │                         │               │
│         │  │  ┌────────┐ ┌────────┐  │  ┌────────┐ ┌────────┐  │               │
│         │  │  │ Card   │ │ Card   │  │  │ Card   │ │ Card   │  │               │
│         │  │  └────────┘ └────────┘  │  └────────┘ └────────┘  │               │
│         │  │                         │                         │               │
│         │  ├─────────────────────────┼─────────────────────────┤               │
│         │  │                         │                         │               │
│         │  │     WON'T HAVE          │      COULD HAVE         │               │
│    LOW  │  │     (1 feature)         │      (4 features)       │               │
│         │  │                         │                         │               │
│         │  │  ┌────────┐             │  ┌────────┐ ┌────────┐  │               │
│         │  │  │ Card   │             │  │ Card   │ │ Card   │  │               │
│         │  │  └────────┘             │  └────────┘ └────────┘  │               │
│         │  │                         │                         │               │
│         │  └─────────────────────────┴─────────────────────────┘               │
│         └──────────────────────────────────────────────────────► Effort         │
│                            LOW                     HIGH                          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Quadrant Specifications

```swift
struct RoadmapQuadrantSpec {
    static let quadrants: [QuadrantDef] = [
        QuadrantDef(
            id: "must_have",
            title: "Must Have",
            subtitle: "High impact, high effort",
            position: .topRight,
            color: Color(hex: "#22C55E"),  // Green-500
            icon: "star.fill"
        ),
        QuadrantDef(
            id: "should_have",
            title: "Should Have",
            subtitle: "High impact, low effort",
            position: .topLeft,
            color: Color(hex: "#3B82F6"),  // Blue-500
            icon: "bolt.fill"
        ),
        QuadrantDef(
            id: "could_have",
            title: "Could Have",
            subtitle: "Low impact, high effort",
            position: .bottomRight,
            color: Color(hex: "#F59E0B"),  // Amber-500
            icon: "sparkles"
        ),
        QuadrantDef(
            id: "wont_have",
            title: "Won't Have",
            subtitle: "Low impact, low effort - not now",
            position: .bottomLeft,
            color: Color(hex: "#6B7280"),  // Gray-500
            icon: "minus.circle"
        )
    ]

    // Styling
    static let gap: CGFloat = 2
    static let padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    static let headerHeight: CGFloat = 48
    static let background = Color.white.opacity(0.03)
    static let borderColor = Color.white.opacity(0.08)
    static let cornerRadius: CGFloat = 16
}
```

### 4.3 Roadmap Feature Card

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ROADMAP CARD (Compact design, different from Kanban)      │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  OAuth Integration                                    │ │
│  │                                                       │ │
│  │  [High Effort]  [Critical Impact]                    │ │
│  │                                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  SPECIFICATIONS:                                           │
│  - Width: Auto-fit grid (min 180px, max 280px)            │
│  - Height: ~80px                                            │
│  - Corner radius: 10px                                      │
│  - Background: rgba(255,255,255,0.05)                      │
│  - Border: 1px solid rgba(255,255,255,0.1)                 │
│  - Title: Typography.bodySmall.weight(.medium)             │
│  - Badges: Compact effort/impact indicators                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.4 Effort & Impact Badges

```swift
struct EffortImpactBadgeSpec {
    // Effort badges
    static let effortBadges: [BadgeDef] = [
        BadgeDef(level: .low, label: "Low Effort", color: Color(hex: "#22C55E")),
        BadgeDef(level: .medium, label: "Med Effort", color: Color(hex: "#F59E0B")),
        BadgeDef(level: .high, label: "High Effort", color: Color(hex: "#EF4444"))
    ]

    // Impact badges
    static let impactBadges: [BadgeDef] = [
        BadgeDef(level: .low, label: "Low Impact", color: Color(hex: "#6B7280")),
        BadgeDef(level: .medium, label: "Med Impact", color: Color(hex: "#3B82F6")),
        BadgeDef(level: .high, label: "Critical Impact", color: Color(hex: "#8B5CF6"))
    ]

    // Styling
    static let height: CGFloat = 20
    static let paddingH: CGFloat = 6
    static let paddingV: CGFloat = 2
    static let cornerRadius: CGFloat = 4
    static let font = Typography.caption
    static let gap: CGFloat = 4
}
```

---

## 5. Interaction Design

### 5.1 Hover States

**Task Card Hover:**
```swift
struct TaskCardHoverState {
    // Visual changes
    let backgroundOpacity: Double = 1.0  // From 0.8
    let borderOpacity: Double = 0.2      // From 0.1
    let shadowRadius: CGFloat = 8        // From 4
    let scale: CGFloat = 1.005           // Subtle lift

    // Timing
    let transitionDuration: Double = 0.15
    let transitionCurve = Animation.easeOut
}
```

**Sidebar Item Hover:**
```swift
struct SidebarItemHoverState {
    let backgroundOpacity: Double = 0.05
    let textOpacity: Double = 1.0        // From 0.8
    let transitionDuration: Double = 0.1
}
```

### 5.2 Click Behaviors

| Element | Single Click | Double Click | Right Click |
|---------|--------------|--------------|-------------|
| Task Card | Select card (highlight) | Open edit modal | Context menu |
| Column Header | Toggle collapse | N/A | Column options menu |
| Sidebar Item | Switch view | N/A | N/A |
| Start Button | Start task / Move to In Progress | N/A | N/A |
| Status Badge | Open status picker | N/A | N/A |
| Roadmap Card | Select feature | Open detail modal | Context menu |

### 5.3 Drag-Drop Behavior

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  DRAG-DROP SEQUENCE                                        │
│                                                             │
│  1. GRAB (mouseDown + 150ms hold)                          │
│     - Cursor: grabbing                                      │
│     - Card: scale(1.02), shadow(16px), opacity(0.9)        │
│     - Ghost card remains in original position (faded)       │
│                                                             │
│  2. DRAG (mousemove)                                        │
│     - Card follows cursor with 8px offset                  │
│     - Valid drop zones highlight with dashed border        │
│     - Invalid zones show "no drop" cursor                  │
│     - Other cards animate to make space                    │
│                                                             │
│  3. HOVER OVER COLUMN (300ms)                              │
│     - Column header pulses with column color               │
│     - Drop indicator appears at insertion point            │
│     - Cards above/below slide apart                        │
│                                                             │
│  4. DROP (mouseUp)                                         │
│     - Card animates to final position (spring)             │
│     - Ghost disappears                                      │
│     - Optimistic update (immediate visual change)          │
│     - Persist to backend                                    │
│     - If fails: animate rollback with shake                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Drop Zone Indicator:**
```swift
struct DropZoneIndicator {
    let style: StrokeStyle = StrokeStyle(
        lineWidth: 2,
        dash: [8, 4]
    )
    let color = Color(hex: "#3B82F6")  // Blue
    let backgroundColor = Color(hex: "#3B82F6").opacity(0.1)
    let cornerRadius: CGFloat = 8
    let animation = Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true)
}
```

### 5.4 Context Menus

**Task Card Context Menu:**
```
┌───────────────────────────────────┐
│  Edit Task               Cmd+E    │
│  ─────────────────────────────    │
│  Move to →               ▶        │
│    │ Planning                     │
│    │ In Progress                  │
│    │ Review                       │
│    └ Done                         │
│  ─────────────────────────────    │
│  Set Priority →          ▶        │
│    │ Low                          │
│    │ Medium                       │
│    │ High                         │
│    └ Urgent                       │
│  ─────────────────────────────    │
│  Duplicate              Cmd+D     │
│  Archive                          │
│  ─────────────────────────────    │
│  Delete                 Cmd+⌫     │
└───────────────────────────────────┘
```

### 5.5 Multi-Select

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  MULTI-SELECT INTERACTIONS                                 │
│                                                             │
│  Shift+Click:                                              │
│  - Selects range from last selected to clicked card        │
│  - Selected cards: blue border (2px)                       │
│  - Selection count badge appears in toolbar                │
│                                                             │
│  Cmd+Click:                                                │
│  - Toggles individual card selection                       │
│  - Adds/removes from current selection                     │
│                                                             │
│  Cmd+A (when Kanban focused):                              │
│  - Selects all cards in current column                     │
│                                                             │
│  Escape:                                                    │
│  - Clears all selection                                    │
│                                                             │
│  Bulk Actions (when multiple selected):                    │
│  - Floating action bar appears at bottom                   │
│  - Options: Move to, Set Priority, Archive, Delete         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Animation Specifications

### 6.1 Animation Tokens

```swift
enum KanbanAnimations {
    // Duration scale
    static let instant: Double = 0.1       // Hover, focus
    static let fast: Double = 0.2          // Micro-interactions
    static let normal: Double = 0.3        // Standard transitions
    static let slow: Double = 0.5          // Page transitions

    // Spring presets (for physics-based animations)
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.85)

    // Standard curves
    static let easeOut = Animation.easeOut(duration: 0.2)
    static let easeInOut = Animation.easeInOut(duration: 0.3)
}
```

### 6.2 Specific Animation Definitions

**Card Drag Animation:**
```swift
struct CardDragAnimation {
    // Pickup
    static let pickupScale: CGFloat = 1.02
    static let pickupShadow: CGFloat = 16
    static let pickupOpacity: Double = 0.9
    static let pickupAnimation = Animation.spring(response: 0.25, dampingFraction: 0.7)

    // Drop
    static let dropAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)

    // Rollback (on failure)
    static let rollbackAnimation = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let rollbackShakeAmplitude: CGFloat = 8
    static let rollbackShakeCount = 3
}
```

**View Transition Animation:**
```swift
struct ViewTransitionAnimation {
    // Between Kanban ↔ Roadmap
    static let crossDissolve = AnyTransition.opacity.animation(.easeInOut(duration: 0.2))

    // Sidebar selection
    static let slideFromLeading = AnyTransition.move(edge: .leading)
        .combined(with: .opacity)
        .animation(.easeOut(duration: 0.2))
}
```

**Card Appearance (Staggered):**
```swift
struct CardAppearanceAnimation {
    static let baseDelay: Double = 0.03     // Per card
    static let maxDelay: Double = 0.3       // Cap total stagger
    static let offset: CGFloat = 20         // Starting offset Y
    static let animation = Animation.spring(response: 0.4, dampingFraction: 0.8)
}
```

### 6.3 Reduced Motion Fallbacks

```swift
struct ReducedMotionFallbacks {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var cardTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    var dragAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var hoverAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.15)
    }
}
```

---

## 7. Accessibility

### 7.1 Keyboard Navigation

**Global Shortcuts:**

| Shortcut | Action | Context |
|----------|--------|---------|
| `Cmd+1` | Switch to Kanban Board | Global |
| `Cmd+2` | Switch to Agent Terminals | Global |
| `Cmd+3` | Switch to Insights | Global |
| `Cmd+4` | Switch to Roadmap | Global |
| `Cmd+N` | New Task | Global |
| `Cmd+F` | Focus search | Global |
| `Cmd+W` | Close popup window | Global |
| `Escape` | Clear selection / Close modal | Context-dependent |

**Kanban-Specific Shortcuts:**

| Shortcut | Action |
|----------|--------|
| `Arrow Left/Right` | Move between columns |
| `Arrow Up/Down` | Move between cards in column |
| `Enter` | Open selected card for editing |
| `Space` | Toggle card selection |
| `Cmd+Shift+Arrow` | Move selected card(s) to adjacent column |
| `Tab` | Move to next card |
| `Shift+Tab` | Move to previous card |
| `Home` | Jump to first card in column |
| `End` | Jump to last card in column |

**Roadmap-Specific Shortcuts:**

| Shortcut | Action |
|----------|--------|
| `Arrow keys` | Navigate between quadrants |
| `Tab` | Move to next feature in quadrant |
| `Enter` | Open feature details |
| `Cmd+1/2/3/4` | Jump to specific quadrant |

### 7.2 VoiceOver Labels

```swift
struct KanbanAccessibility {
    // Card label template
    static func cardLabel(card: KanbanCard) -> String {
        var parts: [String] = []
        parts.append(card.title)
        parts.append("Status: \(card.status.displayName)")
        if let progress = card.progress {
            parts.append("Progress: \(Int(progress.percentComplete ?? 0 * 100))%")
        }
        parts.append("Column: \(card.columnName)")
        return parts.joined(separator: ", ")
    }

    // Column label template
    static func columnLabel(column: KanbanColumn) -> String {
        "\(column.name) column, \(column.cardCount) tasks"
    }

    // Drag hint
    static let dragHint = "Double-tap and hold, then drag to move task"

    // Drop zone announcement
    static func dropZoneAnnouncement(column: String, position: Int) -> String {
        "Drop zone: \(column), position \(position)"
    }
}
```

### 7.3 Focus Indicators

```swift
struct FocusIndicatorStyle {
    // Standard focus ring
    static let ring = RoundedRectangle(cornerRadius: 12)
        .stroke(Color(hex: "#3B82F6"), lineWidth: 2)
        .padding(-4)

    // High contrast mode
    static let highContrastRing = RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white, lineWidth: 3)
        .padding(-6)

    // Focus always visible (no fade)
    static let alwaysVisible = true
}
```

### 7.4 Screen Reader Announcements

```swift
struct DynamicAnnouncements {
    // Card moved
    static func cardMoved(title: String, fromColumn: String, toColumn: String) -> String {
        "\(title) moved from \(fromColumn) to \(toColumn)"
    }

    // Card created
    static func cardCreated(title: String, column: String) -> String {
        "New task created: \(title) in \(column)"
    }

    // View changed
    static func viewChanged(newView: String) -> String {
        "Now showing \(newView)"
    }

    // Selection changed
    static func selectionChanged(count: Int) -> String {
        count == 1 ? "1 task selected" : "\(count) tasks selected"
    }
}
```

---

## 8. Component Library Reference

### 8.1 Design Token Mappings

| Token | Value | Usage |
|-------|-------|-------|
| `DarkBackground.canvas` | `#0f0f23` | Window background base |
| `DarkBackground.raised` | `#1a1a2e` | Card backgrounds |
| `DarkBackground.elevated` | `#252545` | Hover/selected states |
| `DarkBorder.subtle` | `white/10%` | Card borders |
| `DarkBorder.default` | `white/15%` | Focus borders |
| `DarkText.primary` | `white/90%` | Primary text |
| `DarkText.secondary` | `white/70%` | Secondary text |
| `DarkText.tertiary` | `white/50%` | Timestamps, hints |
| `DarkAccent.primary` | `#3B82F6` | Interactive elements |
| `DarkAccent.success` | `#10B981` | Done column, success |
| `DarkAccent.warning` | `#F59E0B` | Review column, warnings |
| `DarkAccent.error` | `#EF4444` | Blocked status |

### 8.2 Typography Mappings

| Element | Token | Size | Weight |
|---------|-------|------|--------|
| Window Title | `Typography.body` | 14pt | Medium |
| Sidebar Section Header | `Typography.caption` | 11pt | Semibold |
| Sidebar Item | `Typography.body` | 14pt | Regular |
| Column Header | `Typography.h4` | 16pt | Medium |
| Card Title | `Typography.body` | 14pt | Semibold |
| Card Description | `Typography.bodySmall` | 13pt | Regular |
| Card Timestamp | `Typography.caption` | 11pt | Regular |
| Badge Text | `Typography.caption` | 11pt | Medium |
| Progress Label | `Typography.caption` | 11pt | Regular |

### 8.3 Reusable Components

```swift
// Components to create or reuse from design system
struct ComponentReuse {
    // From existing design system
    let blazeButton = "BlazeButton"           // Primary actions
    let blazeBadge = "BlazeBadge"             // Status badges
    let blazeCard = "BlazeCard"               // Base card container
    let blazeTooltip = "BlazeTooltip"         // Hover hints

    // New components needed
    let kanbanColumn = "KanbanColumn"         // Column container
    let taskCard = "TaskCard"                 // Kanban task card
    let roadmapCard = "RoadmapCard"           // Feature card
    let progressDots = "ProgressDots"         // Dot-based progress
    let priorityMatrix = "PriorityMatrix"     // 2x2 grid layout
    let dropZone = "DropZone"                 // Drag-drop target
    let sidebarNav = "PopupSidebarNav"        // Navigation list
}
```

---

## 9. Implementation Checklist

### 9.1 Phase 1: Window & Layout

- [ ] Create new SwiftUI window type with hidden title bar
- [ ] Implement gradient background with glass material
- [ ] Build left sidebar navigation component
- [ ] Add view switching logic (Kanban ↔ Roadmap)
- [ ] Implement top toolbar with search, filter, new task button
- [ ] Add keyboard shortcut bindings (Cmd+1/2/3/4)

### 9.2 Phase 2: Kanban Board

- [ ] Create KanbanColumn component
- [ ] Create TaskCard component with all states
- [ ] Implement status badges
- [ ] Implement progress indicator (dot style)
- [ ] Add empty column state
- [ ] Connect to KanbanStore from API layer

### 9.3 Phase 3: Drag-Drop

- [ ] Implement drag gesture recognizer
- [ ] Create ghost card during drag
- [ ] Add drop zone highlighting
- [ ] Implement card reordering animation
- [ ] Add optimistic update with rollback
- [ ] Test all drag scenarios

### 9.4 Phase 4: Roadmap View

- [ ] Create PriorityMatrix 2x2 layout
- [ ] Create RoadmapCard component
- [ ] Add quadrant headers
- [ ] Implement drag-drop between quadrants
- [ ] Add effort/impact badges

### 9.5 Phase 5: Interactions & Polish

- [ ] Implement context menus
- [ ] Add multi-select functionality
- [ ] Create bulk action bar
- [ ] Add all hover states
- [ ] Implement view transition animations
- [ ] Add staggered card reveal animation

### 9.6 Phase 6: Accessibility

- [ ] Add all VoiceOver labels
- [ ] Implement full keyboard navigation
- [ ] Add focus indicators
- [ ] Implement reduced motion fallbacks
- [ ] Add dynamic announcements
- [ ] Test with VoiceOver

### 9.7 Phase 7: Integration & Testing

- [ ] Connect to KanbanStore (persistence)
- [ ] Connect to MemoryStore (if needed)
- [ ] Add error handling and loading states
- [ ] Performance testing (100+ cards)
- [ ] E2E test all user flows
- [ ] Fix any visual regressions

---

## Appendix A: Color Palette Reference

```
BACKGROUND COLORS
─────────────────────────────────────────────────────────
#0f0f23  ████████████  Canvas (window background)
#1a1a2e  ████████████  Raised (card background)
#1a1a3e  ████████████  Gradient end point
#252545  ████████████  Elevated (hover state)

COLUMN COLORS
─────────────────────────────────────────────────────────
#6B7280  ████████████  Planning (Gray)
#3B82F6  ████████████  In Progress (Blue)
#F59E0B  ████████████  Review (Amber)
#10B981  ████████████  Done (Emerald)

ACCENT COLORS
─────────────────────────────────────────────────────────
#3B82F6  ████████████  Primary (Blue-500)
#60A5FA  ████████████  Primary Light (Blue-400)
#1D4ED8  ████████████  Primary Dark (Blue-700)
#22C55E  ████████████  Success (Green-500)
#F59E0B  ████████████  Warning (Amber-500)
#EF4444  ████████████  Error (Red-500)
#8B5CF6  ████████████  Critical Impact (Violet-500)

TEXT COLORS
─────────────────────────────────────────────────────────
#FFFFFF (90%)  Primary text
#FFFFFF (70%)  Secondary text
#FFFFFF (50%)  Tertiary text
#FFFFFF (25%)  Disabled text

BORDER COLORS
─────────────────────────────────────────────────────────
#FFFFFF (10%)  Subtle border
#FFFFFF (15%)  Default border
#FFFFFF (20%)  Hover border
```

---

## Appendix B: SF Symbol Reference

```
SIDEBAR ICONS
─────────────────────────────────────────────────────────
rectangle.3.group      Kanban Board
terminal               Agent Terminals
chart.bar              Insights
map                    Roadmap
lightbulb              Ideation
clock.arrow.circlepath Changelog
doc.text.magnifyingglass Context
arrow.up.right.square  GitHub Issues
arrow.triangle.branch  Worktrees
gearshape              Settings

STATUS ICONS
─────────────────────────────────────────────────────────
circle                 Pending (hollow)
arrow.triangle.2.circlepath In Progress
eye                    Needs Review
checkmark              Completed
exclamationmark.triangle Blocked

PRIORITY ICONS
─────────────────────────────────────────────────────────
arrow.down             Low
minus                  Medium
arrow.up               High
exclamationmark.2      Urgent

ROADMAP ICONS
─────────────────────────────────────────────────────────
star.fill              Must Have
bolt.fill              Should Have
sparkles               Could Have
minus.circle           Won't Have
```

---

**End of Specification**

---

*This specification provides complete implementation guidance for the Kanban + Roadmap popup window. All values are final unless marked with [TBD]. Coordinate with the design system for any token changes.*
