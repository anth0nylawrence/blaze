# Settings Panel Overhaul - Atom-Ready Specification

## Epic: E004 - Settings & Theming Overhaul

**Epic ID**: E004
**Severity**: P2
**Status**: planned
**Owner**: blaze-team
**Created**: 2026-01-07
**Updated**: 2026-01-07

### Overview

Comprehensive redesign of Blaze's settings system: 12 categories, theme system with "Nebula" default, glass styling, and visual hooks builder.

### Key Decisions

- **Theme name**: "Nebula" is the default theme (NON-NEGOTIABLE)
- **Preset themes**: Nebula, Obsidian, Aurora, Sunrise, Monochrome
- **Custom themes**: Full CRUD with JSON storage
- **Hooks builder**: n8n-style drag-and-drop canvas (E004-F005, 8 atoms)
- **Settings window**: NavigationSplitView with glass styling and search

---

## Feature Hierarchy

| Feature ID | Feature Name | Atoms |
|------------|--------------|-------|
| E004-F000 | Nebula Theme Baseline | (ref) |
| E004-F001 | Theme System Foundation | 5 |
| E004-F002 | Settings Window Architecture | 4 |
| E004-F003 | Category Views | 12 |
| E004-F004 | Theme Editor | 2 |
| E004-F005-R000 | Hook Builder Reference | (ref) |
| E004-F005 | Hooks Builder | 8 |
| E004-F006 | Integration | 3 |
| **Total** | | **34** |

*F000 and F005-R000 are reference specifications, not implementation atoms.*

---

## Cross-Cutting Assumptions

These assumptions apply to ALL atoms in E004:

1. Blaze app builds successfully with `swift build` before work begins
2. Existing DesignSystem tokens are available:
   - `DSColors` - Semantic color tokens (`Blaze/Sources/DesignSystem/Tokens/DSColors.swift`)
   - `DSGlass` - Glass level and animation tokens (`Blaze/Sources/DesignSystem/Tokens/DSGlass.swift`)
   - `DSTypography` - Font styles (`Blaze/Sources/DesignSystem/Tokens/DSTypography.swift`)
   - `DSSpacing` - Spacing scale (`Blaze/Sources/DesignSystem/Tokens/DSSpacing.swift`)
   - `DSShadows` - Elevation system (`Blaze/Sources/DesignSystem/Tokens/DSShadows.swift`)
   - `FormSection`, `FormRow` - Form components (`Blaze/Sources/DesignSystem/Components/FormRow.swift`)
   - `GlassPanel` - Glass panel modifier (`Blaze/Sources/DesignSystem/Components/GlassPanel.swift`)
3. @AppStorage is the persistence mechanism for user preferences
4. Actor-based stores (HookStore pattern) are the standard for data persistence
5. SwiftUI NavigationSplitView is available (macOS 14.0+)
6. File storage path: `~/Library/Application Support/Blaze/`

## Cross-Cutting Constraints

1. Must not block main UI thread
2. Must use glass styling via DSGlass for all settings panels
3. Must support keyboard navigation (accessibility)
4. Must persist state across app restarts
5. All user-facing strings must be localizable (use String constants)
6. No third-party dependencies without explicit approval

## Common Telemetry Patterns

All atoms should emit these event types where applicable:
- `settings_changed(category, key, old_value, new_value)` - When user changes a setting
- `theme_applied(theme_id, is_custom)` - When theme is applied
- `settings_window_opened` / `settings_window_closed` - Window lifecycle

## Common Test Patterns

- Unit: Test models/stores in isolation with mock data
- Integration: Test view model → store → persistence flow
- UI: Verify SwiftUI previews render without crash
- Perf: Measure theme application latency (<16ms for 60fps)
- Security: Verify no sensitive data logged, file permissions correct

---

## Supporting Type Definitions

These types are referenced by atoms but not defined in existing atoms. Create these alongside the first atom that needs them.

### AccentColorOption

```swift
// File: Blaze/Sources/Core/Theme/AccentColorOption.swift
enum AccentColorOption: String, Codable, CaseIterable, Identifiable {
    case purple, blue, cyan, green, yellow, orange, red, pink, gray

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .purple: return Color(hex: "#9b59b6")
        case .blue: return Color(hex: "#3498db")
        case .cyan: return Color(hex: "#1abc9c")
        case .green: return Color(hex: "#2ecc71")
        case .yellow: return Color(hex: "#f1c40f")
        case .orange: return Color(hex: "#e67e22")
        case .red: return Color(hex: "#e74c3c")
        case .pink: return Color(hex: "#e91e63")
        case .gray: return Color(hex: "#95a5a6")
        }
    }
}
```

### FontOverrides

```swift
// File: Blaze/Sources/Core/Theme/FontOverrides.swift
struct FontOverrides: Codable, Equatable {
    /// Custom UI font family name (nil = use system SF Pro)
    var uiFontFamily: String?

    /// Custom monospace font family name (nil = use SF Mono)
    var monoFontFamily: String?

    /// Base font size multiplier (1.0 = default)
    var sizeMultiplier: CGFloat

    init(uiFontFamily: String? = nil, monoFontFamily: String? = nil, sizeMultiplier: CGFloat = 1.0) {
        self.uiFontFamily = uiFontFamily
        self.monoFontFamily = monoFontFamily
        self.sizeMultiplier = sizeMultiplier
    }
}
```

### ResolvedThemeColors

```swift
// File: Blaze/Sources/Core/Theme/ResolvedThemeColors.swift
/// Fully resolved color set with no optionals.
/// Created by merging ThemeColors overrides with DSColors defaults.
struct ResolvedThemeColors {
    let background: Color
    let surface: Color
    let surfaceHover: Color
    let accent: Color
    let accentHover: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let border: Color
    let success: Color
    let warning: Color
    let error: Color

    /// Apply these colors to the environment
    func applyToEnvironment() -> some ViewModifier {
        ResolvedThemeColorsModifier(colors: self)
    }
}

// Extension on ThemeColors to resolve
extension ThemeColors {
    func resolved() -> ResolvedThemeColors {
        ResolvedThemeColors(
            background: background ?? Color.ds.bg0,
            surface: surface ?? Color.ds.surface,
            surfaceHover: surfaceHover ?? Color.ds.surface.opacity(0.8),
            accent: accent ?? Color.ds.accent,
            accentHover: accentHover ?? Color.ds.accent.opacity(0.8),
            textPrimary: textPrimary ?? Color.ds.foreground,
            textSecondary: textSecondary ?? Color.ds.secondary,
            textMuted: textMuted ?? Color.ds.tertiary,
            border: border ?? Color.ds.border,
            success: success ?? Color.ds.positive,
            warning: warning ?? Color.ds.warning,
            error: error ?? Color.ds.negative
        )
    }
}
```

### MCPServerConfig

```swift
// File: Blaze/Sources/Core/Engines/MCPServerConfig.swift
struct MCPServerConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var args: [String]
    var env: [String: String]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.isEnabled = isEnabled
    }
}
```

### AnyCodable (Utility)

```swift
// File: Blaze/Sources/Core/Utilities/AnyCodable.swift
/// Type-erased Codable wrapper for heterogeneous dictionaries.
/// Used in HookNode.config for flexible configuration values.
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String: try container.encode(string)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
```

---

## Atom Dependency Graph

Atoms must be implemented in dependency order. An atom cannot be implemented until all its dependencies are complete.

```
Level 0 (No dependencies - implement first):
├── E004-F001-A001: ThemeProfile.swift
├── E004-F001-A002: ThemeColors.swift
├── E004-F002-A002: SettingsCategory.swift
└── E004-F005-A001: HooksPipeline.swift

Level 1 (Depends on Level 0):
├── E004-F001-A003: BuiltInThemes.swift       → depends on ThemeProfile, ThemeColors
├── E004-F001-A004: ThemeStore.swift          → depends on ThemeProfile
├── E004-F002-A003: SettingsSearchViewModel   → depends on SettingsCategory
└── E004-F005-A002: HooksCanvas.swift         → depends on HooksPipeline

Level 2 (Depends on Level 1):
├── E004-F001-A005: ThemeManager.swift        → depends on ThemeStore, BuiltInThemes
├── E004-F002-A004: CategoryDetailRouter      → depends on SettingsCategory
├── E004-F005-A003: HookNodeView.swift        → depends on HooksPipeline
├── E004-F005-A004: HookConnectionView.swift  → depends on HooksPipeline
└── E004-F005-A006: HooksInstallationService.swift → depends on HooksPipeline

Level 3 (Depends on Level 2):
├── E004-F002-A001: SettingsWindow.swift      → depends on CategoryDetailRouter, ThemeManager
├── E004-F003-A001: AppearanceSettingsView    → depends on ThemeManager, SettingsCategory
├── E004-F003-A002-A012: [Other Category Views] → depend on SettingsCategory
├── E004-F005-A005: HookInspectorView.swift   → depends on HooksPipeline, HookNodeView
└── E004-F005-A007: HooksLifecycleView.swift  → depends on HooksInstallationService

Level 4 (Integration - implement last):
├── E004-F004-A001: ThemeEditorView.swift     → depends on ThemeManager, AppearanceSettingsView
├── E004-F004-A002: ThemePreviewPanel.swift   → depends on ThemeManager
├── E004-F006-A001: SettingsIntegration.swift → depends on SettingsWindow, all Category Views
├── E004-F006-A002: SettingsKeyboardShortcuts → depends on SettingsWindow
├── E004-F006-A003: SettingsMigration.swift   → depends on ThemeStore, all stores
└── E004-F005-A008: HooksLifecycleMapView.swift → depends on HooksLifecycleView
```

**Implementation Order Summary:**
1. Data models first (ThemeProfile, ThemeColors, SettingsCategory, HooksPipeline)
2. Storage layer (ThemeStore)
3. Managers (ThemeManager)
4. Individual views (Category views, Hook views)
5. Hooks integration and lifecycle tooling
6. Integration atoms last

---

# F000: Nebula Theme Baseline (Reference Specification)

**Feature ID**: E004-F000
**Story**: Reference documentation defining the current app appearance that constitutes the "Nebula" theme

This section is NOT an implementation atom - it's a reference specification. All theme properties below must be capturable in ThemeProfile and applicable by ThemeManager. Implementing agents should reference this section when building ThemeProfile, ThemeColors, and BuiltInThemes.nebula.

---

## Window Configuration

| Property | Value | Notes |
|----------|-------|-------|
| Default size | 1200 × 800 | Resizable |
| Min size | 800 × 600 | Enforced |
| Style mask | hiddenTitleBar | Ghostty-style |
| Content mode | fullSizeContentView | Extends under titlebar |
| Background | .clear | Fully transparent |
| isOpaque | false | Enables transparency |
| Shadow | true | Window drop shadow |
| Titlebar | transparent, hidden title | Traffic lights visible |

---

## Background Aesthetic

The Nebula background creates depth through layered radial gradients on a transparent window:

| Layer | Type | Color | Position | Opacity | Radius | Blur |
|-------|------|-------|----------|---------|--------|------|
| Base | Solid | #0a1020 (dark navy) | Full | 0.80 | — | — |
| Blue glow | Radial | Blue | Top-left | 0.30 | 350pt | 120pt |
| Purple glow | Radial | Purple | Bottom-right | 0.20 | 300pt | 100pt |

**Implementation**: `AmbientGradientBackground` in BlazeApp.swift

---

## Color Palette

### Base Colors (System-Adaptive)

These use macOS semantic colors that auto-adapt to light/dark mode:

| Token | System Color | Purpose |
|-------|--------------|---------|
| bg0 | windowBackgroundColor | Window background |
| bg1 | controlBackgroundColor | Primary background |
| surface | textBackgroundColor | Interactive surfaces |
| panel | underPageBackgroundColor | Panel/card backgrounds |

### Text Colors

| Token | System Color | Purpose |
|-------|--------------|---------|
| foreground | labelColor | Primary text |
| secondary | secondaryLabelColor | Subdued text |
| tertiary | tertiaryLabelColor | Disabled/hint text |
| placeholder | placeholderTextColor | Input placeholders |

### Border Colors

| Token | Definition | Purpose |
|-------|------------|---------|
| border | separatorColor | Standard borders |
| borderSubtle | separatorColor @ 50% | Subtle dividers |
| gridLine | gridColor | Table/grid lines |

### Semantic State Colors

| Token | Color | Purpose |
|-------|-------|---------|
| positive | .green | Success states |
| warning | .orange | Warning states |
| negative | .red | Error states |
| info | .blue | Informational |
| accent | .accentColor | System accent (user-configurable) |

### Glass Effect Colors

| Token | Definition | Purpose |
|-------|------------|---------|
| glassTint | primary @ 3% | Subtle surface tint |
| glassHighlight | white @ 15% | Top/left edge shine |
| glassShadow | black @ 10% | Bottom/right edge shadow |

### Diff Visualization Colors

| Token | Definition | Purpose |
|-------|------------|---------|
| diffAdd | green @ 15% | Added lines background |
| diffRemove | red @ 15% | Removed lines background |
| diffModify | orange @ 15% | Modified indicator |

### Terminal Prompt Colors (Nebula-specific)

The terminal uses a multi-segment colorful prompt. These colors are distinctive to Nebula:

| Segment | Color | Hex | Purpose |
|---------|-------|-----|---------|
| Username | Orange | #e67e22 | User identity (e.g., "anthony") |
| Path | Cyan | #1abc9c | Current directory abbreviation |
| Git Hash | Yellow | #f1c40f | Commit reference (7-char) |
| Session ID | Magenta | #9b59b6 | Blaze session identifier |
| Time | White | #ffffff | HH:MM display |
| Prompt Arrow | Green | #2ecc71 | Input cursor marker |

### UI Badge Colors

| Badge Type | Color | Hex | Purpose |
|------------|-------|-----|---------|
| Commit Hash | Gold | #f1c40f | Git commit references in session list |
| Token Count (Info) | Blue | #3498db | Comment/info token count |
| Token Count (Error) | Red | #e74c3c | Error/warning token count |
| Token Count (Success) | Green | #2ecc71 | Success token count |
| Token Count (Total) | Gray | #95a5a6 | Total token count |

### Selection & Focus Colors

| State | Color | Opacity | Purpose |
|-------|-------|---------|---------|
| Tab Selected | Blue | 100% | Active tab indicator (e.g., Timeline) |
| Row Hover | White | 5% | List row hover state |
| Row Selected | Accent | 15% | Selected list row background |
| Focus Ring | Accent | 60% | Keyboard focus indicator |

---

## Glass Configuration

### Glass Levels (5-tier system)

| Level | Material | Blur | Bg Opacity | Border Opacity | Highlight Opacity |
|-------|----------|------|------------|----------------|-------------------|
| subtle | ultraThinMaterial | 8pt | 0.30 | 0.08 | 0.05 |
| light | thinMaterial | 12pt | 0.50 | 0.12 | 0.08 |
| **regular** | regularMaterial | 20pt | 0.70 | 0.15 | 0.12 |
| prominent | thickMaterial | 30pt | 0.85 | 0.20 | 0.15 |
| solid | ultraThickMaterial | 40pt | 0.95 | 0.25 | 0.18 |

**Nebula default**: `regular`

### Surface Opacity

All panels in Nebula use consistent surface opacity to create a unified glass canvas:

```swift
Color.ds.surface.opacity(0.15)  // Applied to all sidebars and panels
```

### Border Styles

| Style | Description | Line Width |
|-------|-------------|------------|
| none | No border | 0 |
| subtle | Single line | 0.5pt |
| **standard** | Gradient (white→clear→black) | 1pt |
| layered | Triple layer (outer+gradient+inner) | 1pt |
| gradient | Pure gradient stroke | 1pt |

**Nebula default**: `standard`

**Standard border gradient** (4 stops):
1. Top-left: white @ highlightOpacity
2. Mid-upper: clear
3. Mid-lower: clear
4. Bottom-right: black @ (borderOpacity × 0.5)

---

## Typography

### Font Families

| Role | Family | Fallback |
|------|--------|----------|
| Primary | SF Pro (system) | — |
| Monospace | SF Mono | Menlo |

### Type Scale

| Style | Size | Weight | Line Height | Letter Spacing | Use |
|-------|------|--------|-------------|----------------|-----|
| hero | 32pt | bold | 1.2 | -0.5 | Large headlines |
| title | 20pt | semibold | 1.3 | -0.3 | Section titles |
| subtitle | 16pt | medium | 1.35 | 0 | Subsections |
| body | 14pt | regular | 1.4 | 0 | Primary content |
| caption | 12pt | regular | 1.4 | +0.1 | Secondary text |
| micro | 11pt | regular | 1.4 | +0.1 | Labels, badges |
| mono | 13pt | regular | 1.5 | 0 | Code blocks |
| monoSmall | 11pt | regular | 1.5 | 0 | Inline code |
| monoLarge | 15pt | regular | 1.5 | 0 | Terminal output |

---

## Spacing System (4pt Grid)

| Token | Value | Use |
|-------|-------|-----|
| xxs | 4pt | Hairline gaps |
| xs | 8pt | Tight spacing |
| sm | 12pt | Compact layouts |
| md | 16pt | Standard spacing |
| lg | 24pt | Comfortable spacing |
| xl | 32pt | Section gaps |
| xxl | 48pt | Major sections |
| huge | 64pt | Page-level spacing |

---

## Corner Radii

| Token | Value | Use |
|-------|-------|-----|
| sm | 4pt | Buttons, badges |
| md | 8pt | Cards, inputs |
| **lg** | 12pt | Panels (default) |
| xl | 16pt | Modals, sheets |
| xxl | 20pt | Large containers |
| full | 9999pt | Pills, fully rounded |

**Nebula default panel radius**: `lg` (12pt)

---

## Elevation/Shadow System

| Level | Color | Blur | Y-Offset | Use |
|-------|-------|------|----------|-----|
| none | clear | 0 | 0 | Flat on surface |
| low | black @ 6% | 2pt | 1pt | Slightly raised |
| **medium** | black @ 10% | 6pt | 2pt | Default cards |
| high | black @ 15% | 12pt | 4pt | Floating elements |
| overlay | black @ 25% | 24pt | 8pt | Modals, dialogs |

**Nebula default panel elevation**: `medium`

---

## Animation Parameters

| Property | Value | Notes |
|----------|-------|-------|
| Hover duration | 0.2s | Transition in |
| Press duration | 0.1s | Faster feedback |
| Focus duration | 0.25s | Ring appearance |
| Hover scale | 1.015 | Subtle lift |
| Press scale | 0.98 | Slight press-in |
| Hover brightness | +0.03 | Lighten on hover |
| Press brightness | -0.02 | Darken on press |
| Spring response | 0.35 | Physics timing |
| Spring damping | 0.7 | Bounce control |

---

## Layout Structure

### Three-Pane Dimensions

| Pane | Default | Min | Max | Content |
|------|---------|-----|-----|---------|
| Left sidebar | 280px | 200px | 400px | Sessions, file tree |
| Center | flexible | 350px | ∞ | Chat/Files/Split |
| Right sidebar | 300px | 200px | 500px | Inspector tabs |

### File Tree Height (resizable)
- Default: 200px
- Min: 100px
- Max: 800px

### Divider Hit Targets
- Width: 8px
- Cursor: resize (on hover)
- Visual indicator: 3-line grab pattern

### Content Organization

**Left Sidebar:**
- Title bar clearance (30px spacer)
- Collapsible project groups
- Sessions grouped by project path
- Resizable file tree below

**Center Pane:**
- Mode toggle (Chat/Files/Split)
- Chat: Streaming timeline with tool cards
- Files: Tab bar + syntax-highlighted viewer
- Split: HSplitView with both

**Right Sidebar (5 categories, 20 tabs):**
1. Activity: Timeline, Tools, Tasks
2. Files & Code: Files, Git, Search, Bookmarks
3. Context: Tokens, MCP, Hooks, Policies
4. System: Engines, Logs, Performance
5. Nav: Sessions, Prompts, Agents, Approvals, Context, Settings

---

## Accent Color Options

Nebula default accent: **Purple** (`#9b59b6` or system .accentColor)

### Preset Palette

| Name | Hex | SwiftUI |
|------|-----|---------|
| Purple | #9b59b6 | .purple |
| Blue | #3498db | .blue |
| Cyan | #1abc9c | .cyan |
| Green | #2ecc71 | .green |
| Yellow | #f1c40f | .yellow |
| Orange | #e67e22 | .orange |
| Red | #e74c3c | .red |
| Pink | #e91e63 | .pink |
| Gray | #95a5a6 | .gray |

---

## Key Implementation Files

| Component | File Path |
|-----------|-----------|
| Colors | `Blaze/Sources/DesignSystem/Tokens/DSColors.swift` |
| Glass | `Blaze/Sources/DesignSystem/Tokens/DSGlass.swift` |
| Typography | `Blaze/Sources/DesignSystem/Tokens/DSTypography.swift` |
| Spacing | `Blaze/Sources/DesignSystem/Tokens/DSSpacing.swift` |
| Shadows | `Blaze/Sources/DesignSystem/Tokens/DSShadows.swift` |
| GlassPanel | `Blaze/Sources/DesignSystem/Components/GlassPanel.swift` |
| Window config | `Blaze/Sources/App/BlazeApp.swift` (configureLiquidGlassWindow) |
| Background | `Blaze/Sources/App/BlazeApp.swift` (AmbientGradientBackground) |
| Layout | `Blaze/Sources/App/ThreeColumnLayout.swift` |

---

# F001: Theme System Foundation

**Feature ID**: E004-F001
**Story**: Implement the core theme infrastructure for storing, loading, and applying visual themes across the app

---

## E004-F001-S001-T001-A001: ThemeProfile.swift

**Problem Statement**: The app needs a structured data model to represent themes with colors, glass levels, accent options, and font overrides. Without this, theme data would be scattered and inconsistent.

**Scope**
- In: Define ThemeProfile struct with all theme properties; implement Codable conformance; provide default values
- Out: Theme persistence (handled by ThemeStore); theme application logic (handled by ThemeManager); built-in theme definitions (handled by BuiltInThemes)

**Assumptions**
- DSGlassLevel enum exists in DesignSystem
- AccentColorOption exists or will be created alongside this atom
- FontOverrides is a simple struct for UI and mono font names

**Constraints**
- Struct must be Codable for JSON serialization
- Must use UUID for unique identification
- Built-in themes must be distinguishable from custom themes via `isBuiltIn` flag

**Functional Requirements**
1. ThemeProfile stores: id (UUID), name (String), isBuiltIn (Bool), colors (ThemeColors), glassLevel (DSGlassLevel), accentOption (AccentColorOption), fontOverrides (FontOverrides?)
2. ThemeProfile conforms to Identifiable, Codable, Equatable

**Non-Functional Requirements**
- Encoding/decoding must complete in <1ms for typical themes

**Implementation Steps**
1. Create directory `Blaze/Sources/Core/Theme/` if not exists
2. Create ThemeProfile.swift with struct definition
3. Add Codable conformance with CodingKeys if needed
4. Add static `default` property returning Nebula-like defaults
5. Add unit test for encode/decode round-trip

**Files**
- New: `Blaze/Sources/Core/Theme/ThemeProfile.swift`
- Touched: None

**Data Model**
```swift
struct ThemeProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isBuiltIn: Bool
    var colors: ThemeColors
    var glassLevel: DSGlassLevel
    var accentOption: AccentColorOption
    var fontOverrides: FontOverrides?

    static var `default`: ThemeProfile { /* Nebula defaults */ }
}
```

**API Contracts**
- `ThemeProfile.default` - Returns default Nebula-like theme
- `init(from decoder: Decoder)` - Decode from JSON
- `encode(to encoder: Encoder)` - Encode to JSON

**Event Contracts**
- N/A (data model only, no events emitted)

**UI States**
- N/A (data model, not a view)

**UI Interactions**
- N/A (data model, not a view)

**UI Copy**
- N/A (data model, not a view)

**Edge Cases**
1. Decoding theme with missing optional fields (fontOverrides) - should use nil
2. Theme with empty name - validation should reject in ThemeStore, not here
3. UUID collision (astronomically unlikely) - no special handling needed

**Failure Modes**
- JSON decode failure due to schema mismatch - throw DecodingError, caller handles

**Rollback Plan**: Delete `Blaze/Sources/Core/Theme/ThemeProfile.swift` and remove any imports referencing it

**Test Plan**
- Unit: Test encode/decode round-trip preserves all fields
- Unit: Test default theme has expected values
- Integration: N/A (no external dependencies)
- UI: N/A (data model)
- Perf: Verify encode/decode <1ms
- Security: N/A (no sensitive data)

**Telemetry Events**: N/A (data model)

**Metrics**: N/A (data model)

**Log Expectations**: N/A (data model)

**Acceptance Criteria**
1. ThemeProfile compiles and conforms to Identifiable, Codable, Equatable
2. Round-trip JSON encoding preserves all fields

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Schema changes may break existing saved themes
- Mitigations: Use CodingKeys with default values for new fields
- Blast Radius: Affects theme persistence and all theme-related UI
- Fallback: Fall back to default theme if decode fails

**Verification Steps**
1. Run `swift build` - compiles without errors
2. Run `swift test --filter ThemeProfile` - all tests pass

**Artifact Outputs**: `Blaze/Sources/Core/Theme/ThemeProfile.swift`

---

## E004-F001-S001-T002-A001: ThemeColors.swift

**Problem Statement**: Themes need semantic color definitions (background, surface, accent, text, states) that override system colors. A dedicated struct ensures color consistency and easy serialization.

**Scope**
- In: Define ThemeColors struct with semantic color properties; provide Codable conformance; support optional overrides (nil = use system default)
- Out: Color application to DSColors (handled by ThemeManager); color picker UI

**Assumptions**
- SwiftUI Color can be encoded/decoded via hex string or RGBA components
- Semantic colors follow existing DSColors naming conventions

**Constraints**
- Colors must serialize to JSON (use hex string representation)
- Must support nil values for "use system default" behavior

**Functional Requirements**
1. ThemeColors stores: background, surface, surfaceHover, accent, accentHover, textPrimary, textSecondary, textMuted, border, success, warning, error (all optional Color?)
2. Provides `resolved(with systemColors: DSColors) -> DSColors` method to merge with defaults

**Non-Functional Requirements**
- Color parsing must handle invalid hex gracefully (return nil)

**Implementation Steps**
1. Create ThemeColors.swift in Core/Theme/
2. Define struct with optional Color properties
3. Implement custom Codable using hex strings
4. Add `resolved(with:)` method for merging
5. Add tests for hex parsing edge cases

**Files**
- New: `Blaze/Sources/Core/Theme/ThemeColors.swift`
- Touched: None

**Data Model**
```swift
struct ThemeColors: Codable, Equatable {
    var background: Color?
    var surface: Color?
    var surfaceHover: Color?
    var accent: Color?
    var accentHover: Color?
    var textPrimary: Color?
    var textSecondary: Color?
    var textMuted: Color?
    var border: Color?
    var success: Color?
    var warning: Color?
    var error: Color?

    func resolved(with system: DSColors) -> ResolvedThemeColors
}
```

**API Contracts**
- `init()` - All colors nil (use system defaults)
- `resolved(with:)` - Returns resolved colors with fallbacks
- Hex encoding: `#RRGGBBAA` format

**Event Contracts**
- N/A (data model only)

**UI States**
- N/A (data model)

**UI Interactions**
- N/A (data model)

**UI Copy**
- N/A (data model)

**Edge Cases**
1. Invalid hex string in JSON - decode as nil, use system default
2. All colors nil - theme uses 100% system colors
3. Hex without alpha (#RRGGBB) - assume alpha = FF

**Failure Modes**
- Malformed JSON color value - log warning, decode as nil

**Rollback Plan**: Delete ThemeColors.swift and update ThemeProfile to remove colors field

**Test Plan**
- Unit: Test hex encode/decode for various formats
- Unit: Test resolved() merges correctly with system colors
- Unit: Test invalid hex returns nil gracefully
- Integration: N/A
- UI: N/A
- Perf: N/A (trivial operations)
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**
- WARN: Invalid hex color in theme: [hex value]

**Acceptance Criteria**
1. ThemeColors encodes/decodes to JSON correctly
2. Invalid hex values degrade gracefully to nil

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Color representation differences across displays
- Mitigations: Use standard sRGB color space
- Blast Radius: Affects all themed colors in the app
- Fallback: Invalid colors fall back to system defaults

**Verification Steps**
1. Run `swift test --filter ThemeColors`
2. Verify hex "#FF5733FF" round-trips correctly

**Artifact Outputs**: `Blaze/Sources/Core/Theme/ThemeColors.swift`

---

## E004-F001-S001-T003-A001: BuiltInThemes.swift

**Problem Statement**: The app ships with 5 preset themes (Nebula, Obsidian, Aurora, Sunrise, Monochrome). These must be defined as static constants, immutable, and always available.

**Scope**
- In: Define 5 built-in ThemeProfile constants with complete color definitions
- Out: Custom theme creation; theme persistence; theme selection UI

**Assumptions**
- ThemeProfile and ThemeColors are implemented
- Color values have been specified by design (or use sensible defaults)

**Constraints**
- Built-in themes must have `isBuiltIn: true`
- Built-in themes must have stable UUIDs (hardcoded) for identification
- Nebula is the default and must exist

**Functional Requirements**
1. Provide static constants: `nebula`, `obsidian`, `aurora`, `sunrise`, `monochrome`
2. Provide `all: [ThemeProfile]` array for iteration
3. Each theme has unique, stable UUID

**Non-Functional Requirements**
- Built-in themes load instantly (static data)

**Implementation Steps**
1. Create BuiltInThemes.swift in Core/Theme/
2. Define enum or struct with static theme constants
3. Define color palettes for each theme
4. Add `all` property returning array of all built-ins
5. Verify Nebula is listed first (default)

**Files**
- New: `Blaze/Sources/Core/Theme/BuiltInThemes.swift`
- Touched: None

**Data Model**
```swift
enum BuiltInThemes {
    static let nebula = ThemeProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Nebula",
        isBuiltIn: true,
        colors: ThemeColors(/* deep purples and blues */),
        glassLevel: .regular,
        accentOption: .purple,
        fontOverrides: nil
    )

    static let obsidian: ThemeProfile
    static let aurora: ThemeProfile
    static let sunrise: ThemeProfile
    static let monochrome: ThemeProfile

    static var all: [ThemeProfile] { [nebula, obsidian, aurora, sunrise, monochrome] }
}
```

**API Contracts**
- `BuiltInThemes.nebula` - Default theme
- `BuiltInThemes.all` - All built-in themes
- `BuiltInThemes.theme(forId:)` - Find built-in by UUID (returns nil for custom)

**Event Contracts**
- N/A (static data)

**UI States**
- N/A (static data)

**UI Interactions**
- N/A (static data)

**UI Copy**
- Theme names: "Nebula", "Obsidian", "Aurora", "Sunrise", "Monochrome"

**Edge Cases**
1. Request for non-existent built-in ID - return nil
2. Built-in theme modified by user - not possible (isBuiltIn prevents edit)

**Failure Modes**
- None (static compile-time data)

**Rollback Plan**: Delete BuiltInThemes.swift; ThemeManager must provide fallback default

**Test Plan**
- Unit: Verify all 5 themes exist with expected names
- Unit: Verify nebula is first in `all` array
- Unit: Verify all have isBuiltIn=true and stable UUIDs
- Integration: N/A
- UI: N/A
- Perf: N/A
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. Five built-in themes accessible via static properties
2. Nebula is the default (first in array)

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Color choices may not match design intent
- Mitigations: Review with design before finalizing
- Blast Radius: Visual appearance of all built-in themes
- Fallback: Nebula always exists as safe default

**Verification Steps**
1. `print(BuiltInThemes.all.count)` outputs 5
2. `print(BuiltInThemes.nebula.name)` outputs "Nebula"

**Artifact Outputs**: `Blaze/Sources/Core/Theme/BuiltInThemes.swift`

---

## E004-F001-S002-T001-A001: ThemeStore.swift

**Problem Statement**: Custom themes need persistent storage with CRUD operations. Following the actor-based HookStore pattern ensures thread safety and consistent file I/O.

**Scope**
- In: Actor-based store for custom themes; CRUD operations; file persistence in ~/Library/Application Support/Blaze/themes/
- Out: Built-in themes (static); theme application (ThemeManager); active theme tracking (@AppStorage)

**Assumptions**
- ThemeProfile is Codable
- File system access is available (non-sandboxed app)
- HookStore pattern is established and can be referenced

**Constraints**
- Actor isolation for thread safety
- Must handle concurrent save/load operations
- Directory creation if not exists

**Functional Requirements**
1. `loadThemes() async -> [ThemeProfile]` - Load all custom themes from disk
2. `saveTheme(_ theme: ThemeProfile) async throws` - Save/update a custom theme
3. `deleteTheme(id: UUID) async throws` - Delete a custom theme
4. Auto-create themes directory on first save

**Non-Functional Requirements**
- File operations must not block UI
- Support up to 100 custom themes without performance degradation

**Implementation Steps**
1. Create ThemeStore.swift in Data/
2. Define as actor with fileManager dependency
3. Implement loadThemes with directory enumeration
4. Implement saveTheme with atomic write
5. Implement deleteTheme with file removal
6. Add error handling for permission/disk issues

**Files**
- New: `Blaze/Sources/Data/ThemeStore.swift`
- Touched: None

**Data Model**
```swift
actor ThemeStore {
    private let themesURL: URL  // ~/Library/Application Support/Blaze/themes/

    func loadThemes() async -> [ThemeProfile]
    func saveTheme(_ theme: ThemeProfile) async throws
    func deleteTheme(id: UUID) async throws
}
```

**API Contracts**
- `loadThemes()` - Returns array, empty if none exist
- `saveTheme(_:)` - Creates or updates; throws on write failure
- `deleteTheme(id:)` - Throws if theme not found or delete fails

**Event Contracts**
- N/A (store notifies via @Published or callbacks if needed)

**UI States**
- N/A (data layer)

**UI Interactions**
- N/A (data layer)

**UI Copy**
- N/A (data layer)

**Edge Cases**
1. Themes directory doesn't exist - create on first save
2. Invalid JSON file in themes/ - skip and log warning
3. Permission denied on write - throw error with user-friendly message
4. Disk full - throw error

**Failure Modes**
- File system errors - throw ThemeStoreError with details
- Corrupted theme file - skip file, log warning, continue loading others

**Rollback Plan**: Delete ThemeStore.swift; custom themes feature unavailable

**Test Plan**
- Unit: Test save/load/delete with temp directory
- Unit: Test directory creation on first save
- Unit: Test graceful skip of invalid JSON files
- Integration: Test with real file system paths
- UI: N/A
- Perf: Load 100 themes in <100ms
- Security: Verify files written with appropriate permissions (0600)

**Telemetry Events**
- `custom_theme_saved(theme_id)`
- `custom_theme_deleted(theme_id)`
- `theme_load_error(filename, error)`

**Metrics**
- `custom_themes_count` (gauge) - Number of custom themes loaded

**Log Expectations**
- INFO: Loaded N custom themes from disk
- WARN: Skipping invalid theme file: [filename]
- ERROR: Failed to save theme: [error]

**Acceptance Criteria**
1. Custom themes persist across app restarts
2. Invalid theme files don't crash loading

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: File corruption could lose user's custom themes
- Mitigations: Atomic writes; validate before save; consider backup
- Blast Radius: All custom themes
- Fallback: Fall back to built-in themes if custom load fails

**Verification Steps**
1. Save a theme, restart app, verify it loads
2. Corrupt a theme JSON file, verify app loads without crash

**Artifact Outputs**: `Blaze/Sources/Data/ThemeStore.swift`

---

## E004-F001-S002-T002-A001: ThemeManager.swift

**Problem Statement**: The app needs a central coordinator to track the active theme, apply it to DSColors, handle theme switching with animation, and observe theme changes reactively.

**Scope**
- In: @Observable manager for active theme; theme application logic; animated theme switching; environment injection
- Out: Theme persistence (ThemeStore); theme editing UI; settings UI

**Assumptions**
- ThemeProfile, ThemeColors, ThemeStore exist
- @Observable macro is available (Swift 5.9+)
- DSColors can accept runtime overrides

**Constraints**
- Must be injectable via SwiftUI environment
- Theme changes must animate smoothly
- Must support both built-in and custom themes

**Functional Requirements**
1. Track `activeTheme: ThemeProfile` as observable state
2. `applyTheme(_ theme: ThemeProfile, animated: Bool)` - Switch active theme
3. `resolvedColors: DSColors` - Current theme colors merged with system
4. Initialize with activeThemeId from @AppStorage

**Non-Functional Requirements**
- Theme switch animation completes in <300ms
- No UI flicker during theme application

**Implementation Steps**
1. Create ThemeManager.swift in Core/Theme/
2. Define @Observable class
3. Implement init loading from AppStorage + ThemeStore
4. Implement applyTheme with animation wrapper
5. Add environment key for SwiftUI injection
6. Wire up in BlazeApp

**Files**
- New: `Blaze/Sources/Core/Theme/ThemeManager.swift`
- Touched: `Blaze/Sources/App/BlazeApp.swift` (inject into environment)

**Data Model**
```swift
@Observable
final class ThemeManager {
    private(set) var activeTheme: ThemeProfile
    private let themeStore: ThemeStore
    @AppStorage("activeThemeId") private var activeThemeId: String = ""

    /// Resolved colors with theme overrides applied.
    /// Views access this to get current theme colors.
    var resolvedColors: ResolvedThemeColors {
        activeTheme.colors.resolved()
    }

    init(themeStore: ThemeStore) {
        self.themeStore = themeStore
        // Load theme from stored ID or default to Nebula
        self.activeTheme = BuiltInThemes.nebula
    }

    func applyTheme(_ theme: ThemeProfile, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                activeTheme = theme
            }
        } else {
            activeTheme = theme
        }
        activeThemeId = theme.id.uuidString
    }

    func loadActiveTheme() async {
        // Try to load from stored ID
        if let uuid = UUID(uuidString: activeThemeId) {
            // Check built-ins first
            if let builtIn = BuiltInThemes.theme(forId: uuid) {
                activeTheme = builtIn
                return
            }
            // Check custom themes
            let customs = await themeStore.loadThemes()
            if let custom = customs.first(where: { $0.id == uuid }) {
                activeTheme = custom
                return
            }
        }
        // Fallback to Nebula
        activeTheme = BuiltInThemes.nebula
    }
}

// Environment key for SwiftUI injection
struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager? = nil
}

extension EnvironmentValues {
    var themeManager: ThemeManager? {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// Usage in BlazeApp.swift:
// ContentView()
//     .environment(\.themeManager, themeManager)
```

**Color Application Mechanism**

The theme system applies colors through a layered approach:

1. **DSColors** - Static system color tokens (always available)
2. **ThemeColors** - Optional overrides per theme (nil = use DSColors)
3. **ResolvedThemeColors** - Computed merge: `themeColor ?? dsColor`

Views should use `@Environment(\.themeManager) var themeManager` and access
`themeManager?.resolvedColors.accent` etc. For backwards compatibility,
DSColors static properties remain unchanged - the theme layer sits above.

```swift
// Example view usage:
struct MyView: View {
    @Environment(\.themeManager) var themeManager

    var body: some View {
        Text("Hello")
            .foregroundStyle(themeManager?.resolvedColors.textPrimary ?? Color.ds.foreground)
    }
}
```

**API Contracts**
- `ThemeManager.activeTheme` - Current theme (read-only, @Observable)
- `ThemeManager.applyTheme(_:animated:)` - Switch theme with optional animation
- `ThemeManager.resolvedColors` - ResolvedThemeColors with theme overrides applied
- `ThemeManager.loadActiveTheme()` - Async load from persistence on app launch

**Event Contracts**
- Theme change triggers SwiftUI re-render via @Observable

**UI States**
- N/A (manager, not view)

**UI Interactions**
- N/A (manager, not view)

**UI Copy**
- N/A (manager, not view)

**Edge Cases**
1. Active theme ID not found (deleted) - fall back to Nebula
2. Apply same theme twice - no-op, skip animation
3. App launched with corrupted theme store - fall back to Nebula

**Failure Modes**
- Theme load failure - use Nebula default, log error

**Rollback Plan**: Remove ThemeManager; remove environment injection; app uses system colors only

**Test Plan**
- Unit: Test applyTheme updates activeTheme
- Unit: Test fallback to Nebula when theme not found
- Integration: Test with ThemeStore integration
- UI: Verify theme changes reflect in SwiftUI views
- Perf: Verify theme switch <300ms
- Security: N/A

**Telemetry Events**
- `theme_applied(theme_id, is_custom, animated)`
- `theme_fallback_triggered(reason)`

**Metrics**
- `theme_switch_duration_ms` (timer)

**Log Expectations**
- INFO: Applied theme: [name] (id: [id])
- WARN: Theme [id] not found, falling back to Nebula

**Acceptance Criteria**
1. Changing theme updates all themed UI elements
2. Theme persists across app restarts

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Memory leak if ThemeManager not properly scoped
- Mitigations: Use @Observable (not ObservableObject) for automatic lifecycle
- Blast Radius: All themed UI in the app
- Fallback: Nebula default always available

**Verification Steps**
1. Apply Obsidian theme, verify UI colors change
2. Restart app, verify Obsidian still active

**Artifact Outputs**: `Blaze/Sources/Core/Theme/ThemeManager.swift`

---

# F002: Settings Window Architecture

**Feature ID**: E004-F002
**Story**: Create a modern settings window with NavigationSplitView, search, and 12 category tabs

---

## E004-F002-S001-T001-A001: SettingsWindow.swift

**Problem Statement**: The current settings UI is a basic TabView. A modern macOS app needs a NavigationSplitView with sidebar navigation, search, and glass styling.

**Scope**
- In: Settings window container with NavigationSplitView; category sidebar; search bar; detail panel routing
- Out: Individual category view implementations; actual settings logic

**Assumptions**
- NavigationSplitView is available (macOS 14.0+)
- SettingsCategory enum exists
- Category detail views exist or will be stubbed

**Constraints**
- Must follow macOS Settings window conventions
- Must use glass styling via DSGlass
- Must support keyboard navigation

**Functional Requirements**
1. Display sidebar with all 12 SettingsCategory options
2. Route category selection to appropriate detail view
3. Include search bar that filters categories and settings
4. Apply glass styling to both sidebar and detail panels

**Non-Functional Requirements**
- Window resizes smoothly
- Sidebar minimum width: 200pt

**Implementation Steps**
1. Create SettingsWindow.swift in Settings/
2. Implement NavigationSplitView structure
3. Add sidebar with category list
4. Add search bar with filtering logic
5. Implement detail panel routing
6. Apply DSGlass styling

**Files**
- New: `Blaze/Sources/Settings/SettingsWindow.swift`
- Touched: `Blaze/Sources/App/BlazeApp.swift` (register Settings scene)

**Data Model**
```swift
struct SettingsWindow: Scene {
    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var searchText: String = ""

    var body: some Scene {
        Window("Settings", id: "settings") {
            NavigationSplitView {
                SettingsSidebar(selection: $selectedCategory, searchText: $searchText)
            } detail: {
                CategoryDetailView(category: selectedCategory)
            }
        }
    }
}
```

**API Contracts**
- Scene registered as "settings" window
- Opened via `openWindow(id: "settings")`

**Event Contracts**
- `settings_window_opened`
- `settings_window_closed`

**UI States**
- Default: Appearance category selected
- Search active: Filtered category list
- Search no results: "No matching settings" message

**UI Interactions**
- Click category in sidebar → detail panel updates
- Type in search bar → sidebar filters
- Press Cmd+, → Opens settings window

**UI Copy**
- Window title: "Settings"
- Search placeholder: "Search settings"
- No results: "No matching settings"

**Edge Cases**
1. Search returns no results - show empty state message
2. Window opened while already open - bring existing to front
3. Selected category filtered out by search - keep selection, show filtered sidebar

**Failure Modes**
- Category detail view crashes - show error view, don't crash app

**Rollback Plan**: Revert to previous TabView-based settings; remove SettingsWindow.swift

**Test Plan**
- Unit: N/A (SwiftUI view)
- Integration: Test category routing works
- UI: Verify previews render; manual test navigation
- Perf: Window opens in <200ms
- Security: N/A

**Telemetry Events**
- `settings_window_opened`
- `settings_category_selected(category)`

**Metrics**
- `settings_window_open_duration_ms` (timer)

**Log Expectations**
- INFO: Settings window opened
- INFO: Settings category selected: [category]

**Acceptance Criteria**
1. Settings window opens with Cmd+,
2. Category selection updates detail panel

**Definition of Done**
- [x] Code compiles without warnings
- [x] Window opens and navigates
- [ ] Code reviewed

**Risk Register**
- Risks: NavigationSplitView behavior may differ from expectations
- Mitigations: Test on macOS 14.0 minimum
- Blast Radius: Settings window only
- Fallback: Revert to TabView if NavigationSplitView issues

**Verification Steps**
1. Press Cmd+, → Settings window opens
2. Click "Security" in sidebar → Security settings shown

**Artifact Outputs**: `Blaze/Sources/Settings/SettingsWindow.swift`

---

## E004-F002-S001-T002-A001: SettingsCategory.swift

**Problem Statement**: Settings are organized into 12 logical categories. An enum provides type-safe category handling with associated metadata (icon, title).

**Scope**
- In: Define SettingsCategory enum with 12 cases; provide display name and SF Symbol icon for each
- Out: Category view implementations; routing logic

**Assumptions**
- SF Symbols are available for all needed icons
- 12 categories as specified in design

**Constraints**
- Enum must be CaseIterable for sidebar iteration
- Icons must use SF Symbols (no custom assets)

**Functional Requirements**
1. Define enum cases: appearance, chat, security, engines, terminal, agents, files, notifications, cliPower, memory, git, hooks
2. Provide `displayName: String` computed property
3. Provide `icon: String` (SF Symbol name) computed property

**Non-Functional Requirements**
- N/A (simple enum)

**Implementation Steps**
1. Create SettingsCategory.swift in Core/Settings/
2. Define enum with 12 cases
3. Add displayName switch
4. Add icon switch
5. Conform to CaseIterable, Identifiable

**Files**
- New: `Blaze/Sources/Core/Settings/SettingsCategory.swift`
- Touched: None

**Data Model**
```swift
enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance
    case chat
    case security
    case engines
    case terminal
    case agents
    case files
    case notifications
    case cliPower
    case memory
    case git
    case hooks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appearance: return "Appearance"
        case .chat: return "Chat & Input"
        case .security: return "Security & Trust"
        case .engines: return "Engines"
        case .terminal: return "Terminal"
        case .agents: return "Agents"
        case .files: return "Files & Editor"
        case .notifications: return "Notifications"
        case .cliPower: return "CLI Power"
        case .memory: return "Memory & Context"
        case .git: return "Git"
        case .hooks: return "Hooks Builder"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .chat: return "bubble.left.and.bubble.right"
        case .security: return "lock.shield"
        case .engines: return "gearshape.2"
        case .terminal: return "terminal"
        case .agents: return "person.3"
        case .files: return "doc.text"
        case .notifications: return "bell"
        case .cliPower: return "command"
        case .memory: return "brain"
        case .git: return "arrow.triangle.branch"
        case .hooks: return "link"
        }
    }
}
```

**API Contracts**
- `SettingsCategory.allCases` - All 12 categories
- `.displayName` - Human-readable name
- `.icon` - SF Symbol name

**Event Contracts**
- N/A (enum definition)

**UI States**
- N/A (data type)

**UI Interactions**
- N/A (data type)

**UI Copy**
- Category names: "Appearance", "Chat & Input", "Security & Trust", "Engines", "Terminal", "Agents", "Files & Editor", "Notifications", "CLI Power", "Memory & Context", "Git", "Hooks Builder"

**Edge Cases**
1. New category added - must update enum and views

**Failure Modes**
- N/A (compile-time checked)

**Rollback Plan**: Delete file; update references to use strings directly

**Test Plan**
- Unit: Verify 12 cases exist
- Unit: Verify each has non-empty displayName and icon
- Integration: N/A
- UI: N/A
- Perf: N/A
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. Enum has exactly 12 cases
2. All cases have display names and icons

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Category names may change per design feedback
- Mitigations: Use computed properties for easy updates
- Blast Radius: All settings UI using categories
- Fallback: N/A (low risk)

**Verification Steps**
1. `print(SettingsCategory.allCases.count)` outputs 12
2. Each case has non-empty displayName

**Artifact Outputs**: `Blaze/Sources/Core/Settings/SettingsCategory.swift`

---

## E004-F002-S001-T003-A001: SettingsSearchViewModel.swift

**Problem Statement**: Users need to search settings by keyword. A view model handles search logic, filtering categories and individual settings, and highlighting matches.

**Scope**
- In: Search query processing; category filtering; settings item filtering; search result ranking
- Out: UI rendering; actual settings modification

**Assumptions**
- Each settings category provides searchable terms
- Search is client-side (no network)

**Constraints**
- Search must be responsive (<100ms for typical query)
- Case-insensitive matching
- Must highlight matching terms in results

**Functional Requirements**
1. Accept search query string
2. Filter categories by name match
3. Filter individual settings by label/description match
4. Return ranked results with match highlights
5. Debounce input to avoid excessive filtering

**Non-Functional Requirements**
- <100ms latency for queries
- Support up to 200 searchable settings

**Implementation Steps**
1. Create SettingsSearchViewModel.swift in Settings/
2. Define @Observable class
3. Implement debounced search
4. Implement category and settings filtering
5. Add result ranking (exact match > prefix > contains)

**Files**
- New: `Blaze/Sources/Settings/SettingsSearchViewModel.swift`
- Touched: None

**Data Model**
```swift
@Observable
class SettingsSearchViewModel {
    var query: String = ""
    var filteredCategories: [SettingsCategory] = SettingsCategory.allCases
    var filteredSettings: [SettingsSearchResult] = []

    struct SettingsSearchResult {
        let category: SettingsCategory
        let settingKey: String
        let displayName: String
        let matchRange: Range<String.Index>?
    }
}
```

**API Contracts**
- `query` - Bindable search text
- `filteredCategories` - Categories matching query
- `filteredSettings` - Individual settings matching query

**Event Contracts**
- N/A (internal filtering)

**UI States**
- Empty query: All categories shown
- Query entered: Filtered results
- No matches: Empty results array

**UI Interactions**
- User types → filteredCategories/Settings update
- User clears query → All categories restored

**UI Copy**
- N/A (logic only)

**Edge Cases**
1. Empty query - show all categories
2. Query with only whitespace - treat as empty
3. Very long query - truncate at 100 chars
4. Special characters - escape for safe matching

**Failure Modes**
- Regex crash on invalid pattern - fall back to contains() match

**Rollback Plan**: Remove search functionality; sidebar shows all categories always

**Test Plan**
- Unit: Test filtering with various queries
- Unit: Test debounce behavior
- Unit: Test special character handling
- Integration: N/A
- UI: N/A
- Perf: Test <100ms for 200 settings
- Security: N/A

**Telemetry Events**
- `settings_searched(query_length, results_count)`

**Metrics**
- `settings_search_duration_ms` (timer)

**Log Expectations**
- DEBUG: Settings search: "[query]" → [count] results

**Acceptance Criteria**
1. Typing "theme" shows Appearance category
2. Clearing search shows all categories

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Search may miss relevant settings if keywords not indexed
- Mitigations: Comprehensive keyword list per setting
- Blast Radius: Settings search only
- Fallback: Users can browse manually

**Verification Steps**
1. Type "git" in search → Git category shown
2. Type "xyz123" → No results

**Artifact Outputs**: `Blaze/Sources/Settings/SettingsSearchViewModel.swift`

---

## E004-F002-S001-T004-A001: CategoryDetailRouter.swift

**Problem Statement**: The settings detail panel needs to route from SettingsCategory enum to the appropriate SwiftUI view. A router provides centralized, type-safe navigation.

**Scope**
- In: Map SettingsCategory to corresponding View; provide @ViewBuilder factory
- Out: Individual view implementations

**Assumptions**
- All 12 category views exist (or stubbed)
- SwiftUI @ViewBuilder is used

**Constraints**
- Must return valid View for all 12 cases
- No optional returns (exhaustive switch)

**Functional Requirements**
1. `view(for category: SettingsCategory) -> some View` - Return appropriate view
2. Exhaustive switch ensures compile-time safety

**Non-Functional Requirements**
- View creation is instant (no heavy init)

**Implementation Steps**
1. Create CategoryDetailRouter.swift in Settings/
2. Implement @ViewBuilder function
3. Switch on all 12 cases
4. Return stub views for unimplemented categories

**Files**
- New: `Blaze/Sources/Settings/CategoryDetailRouter.swift`
- Touched: None

**Data Model**
```swift
struct CategoryDetailRouter {
    @ViewBuilder
    static func view(for category: SettingsCategory) -> some View {
        switch category {
        case .appearance: AppearanceSettingsView()
        case .chat: ChatSettingsView()
        case .security: SecuritySettingsView()
        case .engines: EnginesSettingsView()
        case .terminal: TerminalSettingsView()
        case .agents: AgentsSettingsView()
        case .files: FilesSettingsView()
        case .notifications: NotificationsSettingsView()
        case .cliPower: CLIPowerSettingsView()
        case .memory: MemorySettingsView()
        case .git: GitSettingsView()
        case .hooks: HooksBuilderView()
        }
    }
}
```

**API Contracts**
- `CategoryDetailRouter.view(for:)` - Returns View for category

**Event Contracts**
- N/A (view factory)

**UI States**
- N/A (routing only)

**UI Interactions**
- N/A (routing only)

**UI Copy**
- N/A (routing only)

**Edge Cases**
1. New category added - compiler error until case added (by design)

**Failure Modes**
- N/A (compile-time exhaustive switch)

**Rollback Plan**: Inline switch in SettingsWindow; remove router file

**Test Plan**
- Unit: Verify all categories return non-crashing views
- Integration: N/A
- UI: Verify each routed view renders
- Perf: N/A
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. All 12 categories route to views without crash
2. Compiler catches missing cases

**Definition of Done**
- [x] Code compiles without warnings
- [x] All cases handled
- [ ] Code reviewed

**Risk Register**
- Risks: Low (simple routing)
- Mitigations: Exhaustive switch
- Blast Radius: Settings navigation
- Fallback: Inline switch if file removed

**Verification Steps**
1. Iterate all cases, verify each returns a view
2. Add fake 13th case, verify compiler error

**Artifact Outputs**: `Blaze/Sources/Settings/CategoryDetailRouter.swift`

---

# F003: Category Views

**Feature ID**: E004-F003
**Story**: Implement the 12 individual settings category views with appropriate controls and persistence

---

## E004-F003-S001-T001-A001: AppearanceSettingsView.swift

**Problem Statement**: Users need to customize app appearance including theme selection, transparency, glass intensity, and accent colors.

**Scope**
- In: Theme picker (built-in + custom); glass level slider; accent color grid; "Edit Theme" button; transparency toggle
- Out: Theme creation (ThemeEditorView); custom theme CRUD

**Assumptions**
- ThemeManager is available in environment
- BuiltInThemes provides presets
- DSGlassLevel has appropriate cases

**Constraints**
- Must use FormSection for consistent styling
- Changes apply immediately (no save button)

**Functional Requirements**
1. Display grid of available themes (built-in + custom)
2. Show current theme selection with checkmark
3. Provide glass intensity picker (none/subtle/regular/prominent)
4. Provide accent color picker (9 color options)
5. Provide "Edit Theme" button opening ThemeEditorView

**Non-Functional Requirements**
- Theme preview thumbnails load <50ms
- Theme change applies in <300ms

**Implementation Steps**
1. Create AppearanceSettingsView.swift in Settings/
2. Add theme grid section with thumbnails
3. Add glass level picker
4. Add accent color grid
5. Wire to ThemeManager
6. Add "Edit Theme" navigation

**Files**
- New: `Blaze/Sources/Settings/AppearanceSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct AppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage("customGlassLevel") private var glassLevel: String = "regular"

    var body: some View {
        Form {
            FormSection("Themes") { /* theme grid */ }
            FormSection("Glass Effect") { /* slider */ }
            FormSection("Accent Color") { /* color grid */ }
        }
    }
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- `theme_applied(theme_id)` via ThemeManager

**UI States**
- Default: Current theme highlighted
- Hovering theme: Hover effect on thumbnail
- Theme selected: Checkmark overlay

**UI Interactions**
- Click theme thumbnail → Apply theme
- Drag glass slider → Update glass level
- Click accent color → Apply accent
- Click "Edit Theme" → Open editor sheet

**UI Copy**
- Section titles: "Themes", "Glass Effect", "Accent Color"
- Button: "Edit Theme", "Create Custom Theme"
- Labels: "None", "Subtle", "Regular", "Prominent"

**Edge Cases**
1. No custom themes - show only built-ins
2. Many custom themes (>10) - scrollable grid
3. Current theme deleted - fall back to Nebula

**Failure Modes**
- Theme apply fails - show error toast, keep previous theme

**Rollback Plan**: Show minimal theme picker without glass/accent options

**Test Plan**
- Unit: N/A (view)
- Integration: Test theme selection updates ThemeManager
- UI: Verify grid renders with themes; verify selection works
- Perf: Theme switch <300ms
- Security: N/A

**Telemetry Events**
- `appearance_theme_selected(theme_id)`
- `appearance_glass_changed(level)`
- `appearance_accent_changed(color)`

**Metrics**
- `theme_switch_count` (counter)

**Log Expectations**
- INFO: Theme selected: [name]
- INFO: Glass level changed: [level]

**Acceptance Criteria**
1. Can select and apply any theme
2. Glass level changes apply immediately

**Definition of Done**
- [x] Code compiles without warnings
- [x] Theme selection works
- [ ] Code reviewed

**Risk Register**
- Risks: Theme thumbnails may be expensive to generate
- Mitigations: Use cached/static thumbnails
- Blast Radius: Appearance settings only
- Fallback: Text-only theme list if thumbnails fail

**Verification Steps**
1. Click "Obsidian" theme → UI becomes dark
2. Move glass slider to "Prominent" → Glass effect increases

**Artifact Outputs**: `Blaze/Sources/Settings/AppearanceSettingsView.swift`

---

## E004-F003-S001-T002-A001: ChatSettingsView.swift

**Problem Statement**: Users need to configure chat behavior including default model, thinking level, temperature, send key, and cost display.

**Scope**
- In: Model picker; thinking level slider (0-3); temperature slider; top-p slider; send key toggle; cost display toggle; sycophancy stripping toggle
- Out: Model API configuration; actual chat behavior implementation

**Assumptions**
- ModelService provides available models
- @AppStorage persists all settings

**Constraints**
- Temperature range: 0.0-2.0
- Top-p range: 0.0-1.0
- Thinking level: 0 (none), 1 (low), 2 (medium), 3 (high)

**Functional Requirements**
1. Model picker with available models (opus, sonnet, haiku)
2. Thinking level picker (None/Low/Medium/High)
3. Temperature slider with numeric display
4. Top-p slider with numeric display
5. Send key toggle (Enter vs Cmd+Enter)
6. Show cost toggle

**Non-Functional Requirements**
- Settings save instantly on change

**Implementation Steps**
1. Create ChatSettingsView.swift in Settings/
2. Add model picker section
3. Add thinking/temperature/top-p sliders
4. Add send key toggle
5. Add cost display toggle
6. Wire all to @AppStorage

**Files**
- New: `Blaze/Sources/Settings/ChatSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct ChatSettingsView: View {
    @AppStorage("defaultModel") private var model: String = "sonnet"
    @AppStorage("thinkingLevel") private var thinkingLevel: Int = 2
    @AppStorage("temperature") private var temperature: Double = 1.0
    @AppStorage("topP") private var topP: Double = 1.0
    @AppStorage("sendKey") private var sendKey: String = "enter"
    @AppStorage("showCost") private var showCost: Bool = true
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Default: Sonnet selected, thinking=Medium
- Slider dragging: Live value preview

**UI Interactions**
- Select model → @AppStorage updates
- Drag temperature slider → Value updates live
- Toggle send key → Setting flips

**UI Copy**
- Section: "Model", "Thinking", "Parameters", "Input"
- Labels: "Default Model", "Thinking Level", "Temperature", "Top-p", "Send Key", "Show Cost"
- Thinking options: "None", "Low", "Medium", "High"
- Send key options: "Enter to send", "Cmd+Enter to send"

**Edge Cases**
1. Model not available - show as disabled
2. Temperature at extreme - show warning

**Failure Modes**
- Invalid AppStorage value - reset to default

**Rollback Plan**: Remove view; chat uses hardcoded defaults

**Test Plan**
- Unit: N/A (view)
- Integration: Verify settings persist across restart
- UI: Verify all controls work
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `chat_settings_changed(key, old_value, new_value)`

**Metrics**: N/A

**Log Expectations**
- DEBUG: Chat setting changed: [key] = [value]

**Acceptance Criteria**
1. All settings persist across restart
2. Sliders show current numeric values

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Invalid parameter values could affect chat quality
- Mitigations: Clamp values to valid ranges
- Blast Radius: Chat behavior
- Fallback: Use API defaults if invalid

**Verification Steps**
1. Set temperature to 0.5, restart, verify still 0.5
2. Toggle send key, verify chat input respects it

**Artifact Outputs**: `Blaze/Sources/Settings/ChatSettingsView.swift`

---

## E004-F003-S001-T003-A001: SecuritySettingsView.swift

**Problem Statement**: Users need to configure security policies including trust mode, command allowlist, file access restrictions, and sandbox settings.

**Scope**
- In: Trust mode picker (Review/Trusted/Sandbox); command allowlist tag editor; path restrictions; sandbox toggle
- Out: Actual permission enforcement (EngineManager)

**Assumptions**
- Trust modes are predefined (Review, Trusted, Sandbox)
- Command allowlist supports glob patterns

**Constraints**
- Sandbox mode must be clearly warned
- Trusted mode requires confirmation

**Functional Requirements**
1. Trust mode picker with descriptions
2. Command allowlist with add/remove tags
3. Path restrictions list
4. "Reset to defaults" button
5. Confirmation dialog for Trusted mode

**Non-Functional Requirements**
- Changes apply immediately to new sessions

**Implementation Steps**
1. Create SecuritySettingsView.swift in Settings/
2. Add trust mode picker with descriptions
3. Add command allowlist tag editor
4. Add path restrictions editor
5. Add confirmation for Trusted mode
6. Add reset button

**Files**
- New: `Blaze/Sources/Settings/SecuritySettingsView.swift`
- Touched: None

**Data Model**
```swift
struct SecuritySettingsView: View {
    @AppStorage("trustMode") private var trustMode: String = "review"
    @AppStorage("commandAllowlist") private var allowlist: String = ""
    @State private var showTrustedConfirmation = false
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Review mode: Normal state (default)
- Trusted mode: Warning banner shown
- Sandbox mode: Indicator that writes are disabled

**UI Interactions**
- Select trust mode → Confirmation if Trusted
- Add command tag → Allowlist updates
- Remove command tag → Tag removed
- Click Reset → Defaults restored with confirmation

**UI Copy**
- Trust modes: "Review Mode (Recommended)", "Trusted Mode", "Sandbox Mode"
- Descriptions: "Prompts for confirmation on risky actions", "Minimal gates for experienced users", "Read-only mode with safe tools only"
- Warning: "Trusted mode reduces safety gates. Are you sure?"

**Edge Cases**
1. Empty allowlist - all commands require approval
2. Glob pattern syntax error - show validation error
3. Reset while in Trusted mode - confirms twice

**Failure Modes**
- Invalid allowlist pattern - reject with error message

**Rollback Plan**: Remove view; use hardcoded Review mode

**Test Plan**
- Unit: N/A (view)
- Integration: Verify trust mode affects engine
- UI: Verify confirmation dialogs work
- Perf: N/A
- Security: Verify Trusted mode warning appears

**Telemetry Events**
- `trust_mode_changed(old_mode, new_mode)`
- `security_reset_to_defaults`

**Metrics**: N/A

**Log Expectations**
- WARN: Trust mode changed to: [mode]
- INFO: Security settings reset to defaults

**Acceptance Criteria**
1. Switching to Trusted requires confirmation
2. Command allowlist persists correctly

**Definition of Done**
- [x] Code compiles without warnings
- [x] Confirmations work
- [ ] Code reviewed

**Risk Register**
- Risks: Users may enable Trusted mode without understanding risks
- Mitigations: Require explicit confirmation with warning
- Blast Radius: All command execution
- Fallback: Review mode as safe default

**Verification Steps**
1. Select Trusted → Confirmation dialog appears
2. Add "git*" to allowlist → Persists after restart

**Artifact Outputs**: `Blaze/Sources/Settings/SecuritySettingsView.swift`

---

## E004-F003-S001-T004-A001: EnginesSettingsView.swift

**Problem Statement**: Users need to configure CLI backends including engine selection, environment variables, and MCP server management.

**Scope**
- In: Engine picker (Claude/Gemini/Codex); env var editor; MCP server list with add/remove; API key status
- Out: Actual CLI invocation; MCP protocol implementation

**Assumptions**
- Multiple engines may be available
- MCP servers are JSON-configured

**Constraints**
- API keys must not be shown in plain text
- MCP server configs are JSON

**Functional Requirements**
1. Engine picker showing available CLIs
2. Environment variable key-value editor
3. MCP server list with add/edit/remove
4. API key status indicator (configured/not configured)
5. "Test Connection" button per engine

**Non-Functional Requirements**
- API keys stored in Keychain (not @AppStorage)

**Implementation Steps**
1. Create EnginesSettingsView.swift in Settings/
2. Add engine picker section
3. Add env var editor
4. Add MCP server manager
5. Add API key status indicators
6. Add test connection button

**Files**
- New: `Blaze/Sources/Settings/EnginesSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct EnginesSettingsView: View {
    @AppStorage("defaultEngine") private var engine: String = "claude"
    @State private var envVars: [String: String] = [:]
    @State private var mcpServers: [MCPServerConfig] = []
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Engine selected: Checkmark indicator
- API key configured: Green status
- API key missing: Red status with setup link
- Test in progress: Spinner

**UI Interactions**
- Select engine → Default changes
- Add env var → New row appears
- Edit MCP server → Sheet opens
- Click Test → Connection tested

**UI Copy**
- Engines: "Claude Code", "Gemini CLI", "Codex CLI"
- Status: "Configured", "Not configured"
- Buttons: "Add Variable", "Add MCP Server", "Test Connection"

**Edge Cases**
1. No engines installed - show installation instructions
2. MCP server config invalid - validation error
3. Test connection timeout - show timeout message

**Failure Modes**
- Engine not found in PATH - show error with fix instructions

**Rollback Plan**: Remove view; use Claude-only hardcoded

**Test Plan**
- Unit: N/A (view)
- Integration: Test connection actually works
- UI: Verify all controls render
- Perf: N/A
- Security: Verify API keys not shown in logs

**Telemetry Events**
- `engine_changed(old, new)`
- `mcp_server_added(server_name)`
- `engine_test_result(engine, success)`

**Metrics**: N/A

**Log Expectations**
- INFO: Default engine changed to: [engine]
- INFO: MCP server added: [name]
- DEBUG: Engine test: [engine] → [result]

**Acceptance Criteria**
1. Can switch between engines
2. MCP servers can be added and removed

**Definition of Done**
- [x] Code compiles without warnings
- [x] Engine selection persists
- [ ] Code reviewed

**Risk Register**
- Risks: Invalid MCP config could break server
- Mitigations: Validate JSON before save
- Blast Radius: Engine/MCP functionality
- Fallback: Claude default if config invalid

**Verification Steps**
1. Select Gemini → Verify it's now default
2. Add MCP server → Verify appears in list

**Artifact Outputs**: `Blaze/Sources/Settings/EnginesSettingsView.swift`

---

## E004-F003-S001-T005-A001: TerminalSettingsView.swift

**Problem Statement**: Users need to configure terminal appearance including backend selection, font, size, cursor style, and scrollback.

**Scope**
- In: Backend picker (SwiftTerm/Ghostty); font picker; font size; cursor style; scrollback lines
- Out: Actual terminal rendering; pty management

**Assumptions**
- SwiftTerm is default backend
- Ghostty may be unavailable (libghostty deferred)

**Constraints**
- Ghostty option disabled if not available
- Font must be monospace

**Functional Requirements**
1. Backend picker (SwiftTerm/Ghostty with availability status)
2. Font family picker (system monospace fonts)
3. Font size slider (8-24pt)
4. Cursor style picker (block/underline/bar)
5. Scrollback lines input (100-100000)

**Non-Functional Requirements**
- Font preview shows live sample

**Implementation Steps**
1. Create TerminalSettingsView.swift in Settings/
2. Add backend picker with availability check
3. Add font picker with system font enumeration
4. Add size slider
5. Add cursor style picker
6. Add scrollback input with validation

**Files**
- New: `Blaze/Sources/Settings/TerminalSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct TerminalSettingsView: View {
    @AppStorage("terminalBackend") private var backend: String = "swiftterm"
    @AppStorage("terminalFont") private var font: String = "SF Mono"
    @AppStorage("terminalFontSize") private var fontSize: Int = 12
    @AppStorage("terminalCursor") private var cursor: String = "block"
    @AppStorage("terminalScrollback") private var scrollback: Int = 10000
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- SwiftTerm selected: Default
- Ghostty selected: May show warning if unavailable
- Font preview: Shows sample text in selected font

**UI Interactions**
- Select backend → Setting changes
- Select font → Preview updates
- Drag size slider → Preview updates
- Select cursor → Setting changes

**UI Copy**
- Backends: "SwiftTerm (Built-in)", "Ghostty (Experimental)"
- Cursor: "Block", "Underline", "Bar"
- Labels: "Font", "Size", "Cursor Style", "Scrollback Lines"

**Edge Cases**
1. Ghostty unavailable - option disabled with explanation
2. Font not available - fall back to system monospace
3. Scrollback too large - warn about memory usage

**Failure Modes**
- Selected font missing - use system monospace

**Rollback Plan**: Remove view; use SwiftTerm defaults

**Test Plan**
- Unit: N/A (view)
- Integration: Verify terminal uses selected settings
- UI: Verify font picker shows monospace fonts
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `terminal_backend_changed(old, new)`
- `terminal_font_changed(font, size)`

**Metrics**: N/A

**Log Expectations**
- INFO: Terminal backend changed to: [backend]
- DEBUG: Terminal font: [font] @ [size]pt

**Acceptance Criteria**
1. Font changes apply to terminal
2. Cursor style changes apply to terminal

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Ghostty backend may not be stable
- Mitigations: Mark as experimental; keep SwiftTerm default
- Blast Radius: Terminal rendering
- Fallback: SwiftTerm always available

**Verification Steps**
1. Change font to Monaco → Terminal uses Monaco
2. Change cursor to underline → Cursor changes

**Artifact Outputs**: `Blaze/Sources/Settings/TerminalSettingsView.swift`

---

## E004-F003-S001-T006-A001: AgentsSettingsView.swift

**Problem Statement**: Users need to configure agent behavior including concurrency limits, memory thresholds, and throttling.

**Scope**
- In: Concurrency slider (1-100); auto-throttle toggle; memory threshold; agent timeout
- Out: Actual agent spawning; SubagentPool implementation

**Assumptions**
- SubagentPool exists and respects these settings
- Memory monitoring is available

**Constraints**
- Max concurrency depends on available RAM
- Throttle triggers at memory threshold

**Functional Requirements**
1. Concurrency limit slider (1-100, default 10)
2. Auto-throttle toggle (reduce when low memory)
3. Memory threshold slider (50-90% of system RAM)
4. Agent timeout input (seconds)
5. Show current agent count

**Non-Functional Requirements**
- Settings apply to new agents immediately

**Implementation Steps**
1. Create AgentsSettingsView.swift in Settings/
2. Add concurrency slider with system RAM context
3. Add auto-throttle toggle
4. Add memory threshold slider
5. Add timeout input
6. Add current agent count indicator

**Files**
- New: `Blaze/Sources/Settings/AgentsSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct AgentsSettingsView: View {
    @AppStorage("agentConcurrency") private var concurrency: Int = 10
    @AppStorage("agentAutoThrottle") private var autoThrottle: Bool = true
    @AppStorage("agentMemoryThreshold") private var memoryThreshold: Int = 80
    @AppStorage("agentTimeout") private var timeout: Int = 300
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Default: 10 concurrent, auto-throttle on
- High concurrency: Warning about memory

**UI Interactions**
- Drag concurrency slider → Limit updates
- Toggle auto-throttle → Setting changes
- Drag memory threshold → Threshold updates

**UI Copy**
- Labels: "Max Concurrent Agents", "Auto-Throttle", "Memory Threshold", "Agent Timeout"
- Warning: "High concurrency may impact system performance"

**Edge Cases**
1. System has low RAM - cap concurrency recommendation
2. All agents busy - show status indicator
3. Timeout = 0 - disable timeout (warn user)

**Failure Modes**
- Invalid concurrency value - clamp to valid range

**Rollback Plan**: Remove view; use hardcoded defaults

**Test Plan**
- Unit: N/A (view)
- Integration: Verify concurrency limit respected
- UI: Verify slider works
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `agent_concurrency_changed(old, new)`
- `agent_throttle_toggled(enabled)`

**Metrics**: N/A

**Log Expectations**
- INFO: Agent concurrency changed to: [value]
- INFO: Auto-throttle: [enabled/disabled]

**Acceptance Criteria**
1. Concurrency limit respected by SubagentPool
2. Auto-throttle reduces agents when memory high

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: High concurrency could exhaust system resources
- Mitigations: Auto-throttle; memory warnings
- Blast Radius: All agent operations
- Fallback: Conservative defaults

**Verification Steps**
1. Set concurrency to 5 → Max 5 agents run
2. Enable auto-throttle → Reduces under memory pressure

**Artifact Outputs**: `Blaze/Sources/Settings/AgentsSettingsView.swift`

---

## E004-F003-S001-T007-A001: FilesSettingsView.swift

**Problem Statement**: Users need to configure file viewer behavior including line numbers, word wrap, tab size, and diff style.

**Scope**
- In: Line numbers toggle; word wrap toggle; tab size picker; diff style (unified/split); syntax theme
- Out: Actual file rendering; syntax highlighting implementation

**Assumptions**
- Syntax highlighting is available
- Diff viewer exists

**Constraints**
- Tab size: 2, 4, or 8
- Diff style affects diff view layout

**Functional Requirements**
1. Line numbers toggle
2. Word wrap toggle
3. Tab size picker (2/4/8)
4. Diff style picker (unified/split)
5. Syntax theme picker

**Non-Functional Requirements**
- Changes apply to open files immediately

**Implementation Steps**
1. Create FilesSettingsView.swift in Settings/
2. Add line numbers toggle
3. Add word wrap toggle
4. Add tab size segmented picker
5. Add diff style picker
6. Add syntax theme picker

**Files**
- New: `Blaze/Sources/Settings/FilesSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct FilesSettingsView: View {
    @AppStorage("showLineNumbers") private var lineNumbers: Bool = true
    @AppStorage("wordWrap") private var wordWrap: Bool = false
    @AppStorage("tabSize") private var tabSize: Int = 4
    @AppStorage("diffStyle") private var diffStyle: String = "unified"
    @AppStorage("syntaxTheme") private var syntaxTheme: String = "default"
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Default: Lines on, wrap off, tabs=4, unified diff

**UI Interactions**
- Toggle line numbers → Files update
- Toggle word wrap → Files update
- Select tab size → Files update
- Select diff style → Diff view updates

**UI Copy**
- Labels: "Line Numbers", "Word Wrap", "Tab Size", "Diff Style", "Syntax Theme"
- Tab sizes: "2 spaces", "4 spaces", "8 spaces"
- Diff styles: "Unified", "Split"

**Edge Cases**
1. Very long lines + no wrap - horizontal scroll
2. Mixed tab/space files - show as configured tab size

**Failure Modes**
- Invalid tab size value - default to 4

**Rollback Plan**: Remove view; use hardcoded defaults

**Test Plan**
- Unit: N/A (view)
- Integration: Verify file viewer respects settings
- UI: Verify toggles work
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `files_setting_changed(key, value)`

**Metrics**: N/A

**Log Expectations**
- DEBUG: Files setting changed: [key] = [value]

**Acceptance Criteria**
1. Line numbers can be toggled
2. Diff style changes diff view layout

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Low risk settings
- Mitigations: N/A
- Blast Radius: File viewer appearance
- Fallback: Safe defaults

**Verification Steps**
1. Toggle line numbers off → Numbers disappear
2. Set diff to split → Diff shows side-by-side

**Artifact Outputs**: `Blaze/Sources/Settings/FilesSettingsView.swift`

---

## E004-F003-S001-T008-A001: NotificationsSettingsView.swift

**Problem Statement**: Users need to configure notification behavior including desktop alerts, sounds, badges, and Do Not Disturb schedule.

**Scope**
- In: Desktop notifications toggle; sound picker; badge toggle; DND schedule
- Out: Actual notification delivery; system notification integration

**Assumptions**
- System notifications are available (UNUserNotificationCenter)
- Sound files are bundled

**Constraints**
- Must request notification permission
- DND uses 24-hour time

**Functional Requirements**
1. Desktop notifications toggle
2. Sound picker (none, default, custom sounds)
3. Badge toggle (show unread count on dock)
4. DND schedule (start hour, end hour)
5. Test notification button

**Non-Functional Requirements**
- Permission request handled gracefully

**Implementation Steps**
1. Create NotificationsSettingsView.swift in Settings/
2. Add notifications toggle with permission check
3. Add sound picker
4. Add badge toggle
5. Add DND time pickers
6. Add test notification button

**Files**
- New: `Blaze/Sources/Settings/NotificationsSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct NotificationsSettingsView: View {
    @AppStorage("enableNotifications") private var enabled: Bool = true
    @AppStorage("notificationSound") private var sound: String = "default"
    @AppStorage("showBadge") private var badge: Bool = true
    @AppStorage("dndStart") private var dndStart: Int = 22  // 10 PM
    @AppStorage("dndEnd") private var dndEnd: Int = 8       // 8 AM
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Enabled: All options visible
- Disabled: Options grayed out
- Permission denied: Warning shown

**UI Interactions**
- Toggle notifications → Permission requested if needed
- Select sound → Preview plays
- Set DND hours → Schedule saved
- Click Test → Test notification sent

**UI Copy**
- Labels: "Desktop Notifications", "Sound", "Badge on Dock", "Do Not Disturb"
- Sounds: "None", "Default", "Chime", "Ping"
- DND: "From", "To"

**Edge Cases**
1. Permission denied - show system prefs link
2. DND end before start - treat as overnight schedule
3. Sound file missing - fall back to system sound

**Failure Modes**
- Notification permission revoked - show re-enable instructions

**Rollback Plan**: Remove view; no notifications

**Test Plan**
- Unit: N/A (view)
- Integration: Verify notifications respect settings
- UI: Verify time pickers work
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `notifications_toggled(enabled)`
- `notification_sound_changed(sound)`

**Metrics**: N/A

**Log Expectations**
- INFO: Notifications enabled: [yes/no]
- DEBUG: DND schedule: [start]-[end]

**Acceptance Criteria**
1. Notifications can be enabled/disabled
2. DND schedule prevents notifications during hours

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Users may miss important notifications if DND misconfigured
- Mitigations: Clear DND indicator in UI
- Blast Radius: Notification delivery
- Fallback: Notifications on by default

**Verification Steps**
1. Enable notifications → Test notification appears
2. Set DND 0-24 → No notifications during DND

**Artifact Outputs**: `Blaze/Sources/Settings/NotificationsSettingsView.swift`

---

## E004-F003-S001-T009-A001: CLIPowerSettingsView.swift

**Problem Statement**: Power users need to configure advanced CLI features including allowed tools list, path restrictions, and presets for different workflows.

**Scope**
- In: Allowed tools GUI (tag-based); path restrictions; workflow presets; raw CLI flags
- Out: Actual CLI invocation; tool execution

**Assumptions**
- Tool names match Claude Code's --allowedTools format
- Presets are predefined combinations

**Constraints**
- Invalid tool names rejected with error
- Paths must be absolute or repo-relative

**Functional Requirements**
1. Allowed tools tag editor with autocomplete
2. Path restrictions (allowed/blocked paths)
3. Workflow presets (Minimal, Standard, Full, Custom)
4. Raw CLI flags input for advanced users
5. Export/import settings

**Non-Functional Requirements**
- Tool autocomplete is instant

**Implementation Steps**
1. Create CLIPowerSettingsView.swift in Settings/
2. Add allowed tools tag editor
3. Add path restrictions editor
4. Add presets picker
5. Add raw flags input
6. Add export/import buttons

**Files**
- New: `Blaze/Sources/Settings/CLIPowerSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct CLIPowerSettingsView: View {
    @AppStorage("allowedTools") private var allowedTools: String = ""
    @AppStorage("pathRestrictions") private var pathRestrictions: String = ""
    @AppStorage("cliPreset") private var preset: String = "standard"
    @AppStorage("rawCliFlags") private var rawFlags: String = ""
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Preset selected: Tools auto-populated
- Custom: Manual tool editing enabled
- Invalid tool: Error indicator

**UI Interactions**
- Select preset → Tools auto-fill
- Add tool tag → Tool added with validation
- Edit paths → Paths saved
- Click Export → Settings exported to JSON

**UI Copy**
- Presets: "Minimal (safe only)", "Standard", "Full (all tools)", "Custom"
- Labels: "Allowed Tools", "Path Restrictions", "Raw CLI Flags"
- Buttons: "Export Settings", "Import Settings"

**Edge Cases**
1. Empty allowed tools - all tools blocked
2. Conflicting path rules - most specific wins
3. Invalid raw flag - validation error

**Failure Modes**
- Invalid tool name - show error, don't save

**Rollback Plan**: Remove view; use standard preset

**Test Plan**
- Unit: N/A (view)
- Integration: Verify CLI respects allowed tools
- UI: Verify tag editor works
- Perf: N/A
- Security: Verify path restrictions enforced

**Telemetry Events**
- `cli_preset_changed(old, new)`
- `cli_tools_changed(count)`

**Metrics**: N/A

**Log Expectations**
- INFO: CLI preset: [preset]
- DEBUG: Allowed tools: [count] configured

**Acceptance Criteria**
1. Preset selection changes allowed tools
2. Path restrictions enforced in sessions

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Overly restrictive settings could block workflow
- Mitigations: Presets provide known-good configs
- Blast Radius: All CLI sessions
- Fallback: Standard preset

**Verification Steps**
1. Select Minimal preset → Only safe tools allowed
2. Add path restriction → Path blocked in session

**Artifact Outputs**: `Blaze/Sources/Settings/CLIPowerSettingsView.swift`

---

## E004-F003-S001-T010-A001: MemorySettingsView.swift

**Problem Statement**: Users need to configure context management including CLAUDE.md editing, context limits, and memory persistence.

**Scope**
- In: CLAUDE.md editor; context token limit display; auto-clear threshold; memory export
- Out: Actual context management; compaction logic

**Assumptions**
- CLAUDE.md location is known
- Token counting is available

**Constraints**
- CLAUDE.md must be valid markdown
- Context limits depend on model

**Functional Requirements**
1. CLAUDE.md editor with syntax highlighting
2. Current context usage display
3. Auto-clear threshold slider
4. Memory export button (JSON dump)
5. Clear context button with confirmation

**Non-Functional Requirements**
- CLAUDE.md saves on blur

**Implementation Steps**
1. Create MemorySettingsView.swift in Settings/
2. Add CLAUDE.md text editor
3. Add context usage gauge
4. Add auto-clear threshold slider
5. Add export/clear buttons

**Files**
- New: `Blaze/Sources/Settings/MemorySettingsView.swift`
- Touched: None

**Data Model**
```swift
struct MemorySettingsView: View {
    @State private var claudeMd: String = ""
    @AppStorage("autoClearThreshold") private var threshold: Int = 90

    var claudeMdPath: URL { /* project CLAUDE.md path */ }
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- CLAUDE.md loaded: Editor shows content
- CLAUDE.md missing: Create prompt
- Context high: Warning indicator

**UI Interactions**
- Edit CLAUDE.md → Saves on blur
- Drag threshold slider → Threshold updates
- Click Export → JSON file saved
- Click Clear → Confirmation then clear

**UI Copy**
- Labels: "CLAUDE.md", "Context Usage", "Auto-Clear Threshold"
- Buttons: "Export Memory", "Clear Context"
- Warning: "Context usage high - consider clearing"

**Edge Cases**
1. CLAUDE.md doesn't exist - offer to create
2. CLAUDE.md read-only - show error
3. Context near limit - auto-clear if enabled

**Failure Modes**
- File save fails - show error, keep changes in memory

**Rollback Plan**: Remove view; no memory management UI

**Test Plan**
- Unit: N/A (view)
- Integration: Verify CLAUDE.md saves correctly
- UI: Verify editor works
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `claudemd_saved`
- `context_cleared`
- `memory_exported`

**Metrics**: N/A

**Log Expectations**
- INFO: CLAUDE.md saved
- INFO: Context cleared by user

**Acceptance Criteria**
1. CLAUDE.md changes persist
2. Context can be cleared

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Accidental CLAUDE.md deletion
- Mitigations: Backup before clear; confirmation dialog
- Blast Radius: Project context
- Fallback: Can recreate CLAUDE.md

**Verification Steps**
1. Edit CLAUDE.md → Changes persist after restart
2. Click Clear → Context resets

**Artifact Outputs**: `Blaze/Sources/Settings/MemorySettingsView.swift`

---

## E004-F003-S001-T011-A001: GitSettingsView.swift

**Problem Statement**: Users need to configure Git integration including auto-run, commit style, co-author settings, and worktree management.

**Scope**
- In: Auto-run git commands toggle; commit style picker; co-author toggle; auto-stash toggle; worktree settings
- Out: Actual git command execution; worktree management

**Assumptions**
- Git is installed
- Repo is a git repository

**Constraints**
- Some settings only apply to git repos
- Co-author affects commit messages

**Functional Requirements**
1. Auto-run git writes toggle (with security warning)
2. Commit style picker (conventional/free-form)
3. Co-author toggle (include Claude attribution)
4. Auto-stash on branch switch toggle
5. Worktree per task toggle

**Non-Functional Requirements**
- Settings apply to new git operations

**Implementation Steps**
1. Create GitSettingsView.swift in Settings/
2. Add auto-run toggle with warning
3. Add commit style picker
4. Add co-author toggle
5. Add auto-stash toggle
6. Add worktree toggle

**Files**
- New: `Blaze/Sources/Settings/GitSettingsView.swift`
- Touched: None

**Data Model**
```swift
struct GitSettingsView: View {
    @AppStorage("gitAutoRun") private var autoRun: Bool = false
    @AppStorage("commitStyle") private var commitStyle: String = "conventional"
    @AppStorage("includeCoAuthor") private var coAuthor: Bool = true
    @AppStorage("autoStash") private var autoStash: Bool = true
    @AppStorage("worktreePerTask") private var worktree: Bool = false
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Auto-run enabled: Warning banner
- Not a git repo: Settings disabled

**UI Interactions**
- Toggle auto-run → Confirmation required
- Select commit style → Setting changes
- Toggle co-author → Affects future commits

**UI Copy**
- Labels: "Auto-run Git Commands", "Commit Style", "Include Co-Author", "Auto-Stash", "Worktree per Task"
- Styles: "Conventional (feat/fix/etc)", "Free-form"
- Warning: "Auto-run may execute git commands without confirmation"

**Edge Cases**
1. Not a git repo - disable git settings
2. Git not installed - show install prompt
3. Worktree conflicts - warn user

**Failure Modes**
- Git not found - settings disabled with message

**Rollback Plan**: Remove view; manual git only

**Test Plan**
- Unit: N/A (view)
- Integration: Verify commit style applied
- UI: Verify toggles work
- Perf: N/A
- Security: Verify auto-run warning shown

**Telemetry Events**
- `git_autorun_toggled(enabled)`
- `git_commit_style_changed(style)`

**Metrics**: N/A

**Log Expectations**
- WARN: Git auto-run enabled
- INFO: Commit style: [style]

**Acceptance Criteria**
1. Commit style affects new commits
2. Auto-run warning is clear

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Auto-run could execute unwanted commands
- Mitigations: Clear warning; default off
- Blast Radius: Git repository
- Fallback: Manual git commands

**Verification Steps**
1. Enable auto-run → Warning appears
2. Set conventional style → Commits use feat/fix format

**Artifact Outputs**: `Blaze/Sources/Settings/GitSettingsView.swift`

---

## E004-F003-S001-T012-A001: HooksBuilderView.swift (Settings Entry)

**Problem Statement**: Users need access to the visual hooks builder from settings. This view serves as the entry point and hosts the full canvas builder.

**Scope**
- In: Hooks list view; "Create Hook" button; hook enable/disable toggles; link to full builder
- Out: Actual hook execution; canvas implementation (separate atoms)

**Assumptions**
- HookStore exists
- Hook model is defined

**Constraints**
- Canvas builder may be complex; start with list view
- Hooks must be toggleable

**Functional Requirements**
1. List of configured hooks with enable/disable toggle
2. "Create Hook" button opening builder
3. Hook delete with confirmation
4. Quick event type filter
5. Import/export hooks

**Non-Functional Requirements**
- Hooks list loads instantly

**Implementation Steps**
1. Create HooksBuilderView.swift in Settings/
2. Add hooks list with toggles
3. Add create/delete buttons
4. Add event filter
5. Add import/export

**Files**
- New: `Blaze/Sources/Settings/HooksBuilderView.swift`
- Touched: None

**Data Model**
```swift
struct HooksBuilderView: View {
    @State private var hooks: [HookConfig] = []
    @State private var filter: HookEventType? = nil
    @State private var showBuilder = false
}
```

**API Contracts**
- N/A (view only)

**Event Contracts**
- N/A (settings only)

**UI States**
- Empty: "No hooks configured" prompt
- List: Shows configured hooks
- Builder open: Full canvas view

**UI Interactions**
- Toggle hook → Enable/disable
- Click Create → Builder opens
- Click hook → Edit in builder
- Click Delete → Confirmation then delete

**UI Copy**
- Labels: "Hooks", "Event Type"
- Buttons: "Create Hook", "Import", "Export"
- Empty: "No hooks configured. Create one to automate actions."

**Edge Cases**
1. No hooks - show empty state with create prompt
2. Many hooks (>20) - scrollable list
3. Import invalid JSON - show error

**Failure Modes**
- Hook load fails - show error, offer reset

**Rollback Plan**: Remove view; hooks only editable via JSON

**Test Plan**
- Unit: N/A (view)
- Integration: Verify hooks save/load
- UI: Verify list renders
- Perf: N/A
- Security: N/A

**Telemetry Events**
- `hook_created`
- `hook_deleted`
- `hook_toggled(enabled)`

**Metrics**: N/A

**Log Expectations**
- INFO: Hook created: [name]
- INFO: Hook [name] enabled: [yes/no]

**Acceptance Criteria**
1. Hooks can be toggled
2. New hooks can be created

**Definition of Done**
- [x] Code compiles without warnings
- [x] Settings persist
- [ ] Code reviewed

**Risk Register**
- Risks: Complex canvas may have bugs
- Mitigations: Start with list view; canvas is Phase 2
- Blast Radius: Hook configuration
- Fallback: JSON editing

**Verification Steps**
1. Create hook → Appears in list
2. Toggle off → Hook disabled

**Artifact Outputs**: `Blaze/Sources/Settings/HooksBuilderView.swift`

---

# F004: Theme Editor

**Feature ID**: E004-F004
**Story**: Create a visual theme editor for customizing and creating themes

---

## E004-F004-S001-T001-A001: ThemeEditorView.swift

**Problem Statement**: Users need to create and customize themes with color pickers, glass controls, and font selectors in a visual editor.

**Scope**
- In: Color pickers for all semantic colors; glass level picker; accent color grid; font pickers; save/cancel/delete actions
- Out: Theme persistence (ThemeStore); live preview (ThemePreviewPanel)

**Assumptions**
- ThemeProfile model exists
- SwiftUI ColorPicker is available
- System fonts can be enumerated

**Constraints**
- Must support both create and edit modes
- Built-in themes cannot be edited (only duplicated)

**Functional Requirements**
1. All semantic color pickers (background, surface, accent, text variants, states)
2. Glass level picker (none/subtle/regular/prominent)
3. Accent color grid (9 preset + custom)
4. Font family pickers (UI font, mono font)
5. Save, Cancel, Delete buttons with appropriate states
6. Duplicate button for built-in themes

**Non-Functional Requirements**
- Color changes preview immediately
- Picker opens quickly (<100ms)

**Implementation Steps**
1. Create ThemeEditorView.swift in Settings/Theme/
2. Add color picker sections grouped by category
3. Add glass level picker
4. Add accent color grid
5. Add font pickers
6. Add action buttons with state management
7. Wire to ThemeStore for persistence

**Files**
- New: `Blaze/Sources/Settings/Theme/ThemeEditorView.swift`
- Touched: None

**Data Model**
```swift
struct ThemeEditorView: View {
    @Binding var theme: ThemeProfile
    let isNew: Bool
    let onSave: (ThemeProfile) -> Void
    let onCancel: () -> Void
    let onDelete: (() -> Void)?

    @State private var editedTheme: ThemeProfile
}
```

**API Contracts**
- Binding to ThemeProfile for editing
- Callbacks for save/cancel/delete actions

**Event Contracts**
- N/A (editor view)

**UI States**
- Create mode: Save enabled after name entered
- Edit mode: Save enabled after changes
- Built-in: Delete disabled, Duplicate shown

**UI Interactions**
- Pick color → Theme updates live
- Enter name → Validates non-empty
- Click Save → Persists and closes
- Click Cancel → Discards changes
- Click Delete → Confirmation then delete

**UI Copy**
- Section titles: "Colors", "Background", "Surface", "Text", "States", "Effects", "Typography"
- Buttons: "Save Theme", "Cancel", "Delete Theme", "Duplicate"
- Placeholder: "Theme Name"

**Edge Cases**
1. Empty name - Save disabled
2. Duplicate name - Warning shown
3. All colors nil - Valid (uses system defaults)
4. Built-in theme - Edit disabled, must duplicate

**Failure Modes**
- Save fails - Show error, keep editor open

**Rollback Plan**: Remove editor; themes not customizable

**Test Plan**
- Unit: N/A (view)
- Integration: Verify save persists theme
- UI: Verify all pickers work
- Perf: Color picker opens <100ms
- Security: N/A

**Telemetry Events**
- `theme_editor_opened(is_new, is_builtin)`
- `theme_saved(theme_id)`
- `theme_deleted(theme_id)`

**Metrics**: N/A

**Log Expectations**
- INFO: Theme editor opened for: [name]
- INFO: Theme saved: [name]

**Acceptance Criteria**
1. Custom themes can be created
2. Existing themes can be edited

**Definition of Done**
- [x] Code compiles without warnings
- [x] Theme saves correctly
- [ ] Code reviewed

**Risk Register**
- Risks: Color picker may behave differently on different macOS versions
- Mitigations: Test on macOS 14.0+
- Blast Radius: Theme customization
- Fallback: Use built-in themes only

**Verification Steps**
1. Create theme → Appears in theme list
2. Edit color → Live preview updates

**Artifact Outputs**: `Blaze/Sources/Settings/Theme/ThemeEditorView.swift`

---

## E004-F004-S001-T002-A001: ThemePreviewPanel.swift

**Problem Statement**: Theme editors need live preview of changes showing how colors affect real UI components like chat bubbles, tool cards, and code blocks.

**Scope**
- In: Live preview panel with sample chat bubble, tool card, code block, buttons; updates as theme changes
- Out: Actual theme application; color picker implementation

**Assumptions**
- Sample components can be rendered in isolation
- ThemeColors can be applied to preview

**Constraints**
- Preview must update without flicker
- Must show representative UI components

**Functional Requirements**
1. Sample chat bubble (user and assistant)
2. Sample tool card with icon
3. Sample code block with syntax highlighting
4. Sample buttons (primary, secondary, destructive)
5. Live update as colors change

**Non-Functional Requirements**
- Preview updates in <16ms (60fps)

**Implementation Steps**
1. Create ThemePreviewPanel.swift in Settings/Theme/
2. Create sample chat bubble view
3. Create sample tool card view
4. Create sample code block view
5. Create sample buttons
6. Wire to theme binding for live updates

**Files**
- New: `Blaze/Sources/Settings/Theme/ThemePreviewPanel.swift`
- Touched: None

**Data Model**
```swift
struct ThemePreviewPanel: View {
    let theme: ThemeProfile

    var body: some View {
        VStack(spacing: 16) {
            PreviewChatBubble(theme: theme)
            PreviewToolCard(theme: theme)
            PreviewCodeBlock(theme: theme)
            PreviewButtons(theme: theme)
        }
    }
}
```

**API Contracts**
- Input: ThemeProfile to preview
- Output: Visual preview

**Event Contracts**
- N/A (preview only)

**UI States**
- Normal: Shows all preview components
- Loading: N/A (static preview)

**UI Interactions**
- None (display only)

**UI Copy**
- Chat: "Hello, how can I help?", "Sure, I can help with that."
- Tool: "Reading file: example.swift"
- Code: Sample Swift code snippet

**Edge Cases**
1. Very dark theme - text still readable
2. Very light theme - text still readable
3. Missing colors - falls back to system

**Failure Modes**
- Render fails - show placeholder

**Rollback Plan**: Remove preview; editor only shows pickers

**Test Plan**
- Unit: N/A (view)
- Integration: Verify preview reflects theme
- UI: Verify all components render
- Perf: Preview updates at 60fps
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. Preview updates live as colors change
2. All sample components visible

**Definition of Done**
- [x] Code compiles without warnings
- [x] Preview renders
- [ ] Code reviewed

**Risk Register**
- Risks: Preview may not match actual UI perfectly
- Mitigations: Use actual component code where possible
- Blast Radius: Theme preview only
- Fallback: No preview; save and test

**Verification Steps**
1. Change background color → Preview background updates
2. Change accent color → Buttons update

**Artifact Outputs**: `Blaze/Sources/Settings/Theme/ThemePreviewPanel.swift`

---

# F005-R000: Hook & Plugin Builder Reference Specification

**Feature ID**: E004-F005-R000
**Story**: Reference documentation defining hook semantics, node taxonomy, and graph schema for the visual hooks builder

This section is NOT an implementation atom - it's a reference specification. All hook events, node types, and graph structures below must be supported by the Hooks Builder UI. Implementing agents should reference this section when building HooksPipeline, HookNodeView, and HookInspectorView.

---

## Terminology

| Term | Definition |
|------|------------|
| **Hook Event** | A named lifecycle moment when the CLI invokes hooks (e.g., `PreToolUse`, `UserPromptSubmit`) |
| **Hook Matcher** | A filter string (regex-like) that selects which event instances trigger a hook group |
| **Hook Action** | What runs when a hook matches: Command, Prompt, or Agent action |
| **Hook Input Payload** | JSON provided to the hook via stdin with common fields + event-specific fields |
| **Hook Output** | Exit code + stdout/stderr, or structured JSON on stdout (when exit=0) |
| **Plugin** | A distributable package bundling hooks, skills, MCP servers, etc. |

### Matcher Examples by Event Type

| Event Type | Matcher Values |
|------------|----------------|
| Tool events | `Task`, `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`, `WebFetch`, `WebSearch` |
| Notification | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| PreCompact | `manual`, `auto` |
| SessionStart | `startup`, `resume`, `clear`, `compact` |

---

## Mental Model

1. A **Hook Event** fires
2. The runtime forms a **Hook Input** JSON payload
3. The runtime selects **matching hook groups** by matcher
4. **All matched hooks execute in parallel** (default CLI behavior)
5. Each hook returns output; the runtime merges/applies output according to event-specific rules

The visual builder helps users:
- Pick the **event**
- Define **filters/matchers**
- Add **actions**
- Define **decision control / transformations** (when supported)
- Test/trace the workflow

---

## Hook Configuration Structure

### Canonical Format (what the builder compiles to)

```json
{
  "hooks": {
    "<HookEventName>": [
      {
        "matcher": "<optional matcher>",
        "hooks": [
          { "type": "command", "command": "/path/to/script.sh" }
        ]
      }
    ]
  }
}
```

### Environment Variables (show in tooltips)

| Variable | Scope | Description |
|----------|-------|-------------|
| `CLAUDE_PROJECT_DIR` | All events | Project directory path |
| `CLAUDE_PLUGIN_ROOT` | Plugin hooks | Plugin root path for relative scripts |
| `CLAUDE_ENV_FILE` | SessionStart only | Path where hook can persist env vars |

---

## Hook Input Payloads

### Common Fields (all events)

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `transcript_path` | string | Path to conversation json/jsonl |
| `cwd` | string | Current working directory |
| `permission_mode` | string | `default`, `plan`, `acceptEdits`, `dontAsk`, `bypassPermissions` |
| `hook_event_name` | string | The event name |

---

## Hook Output Handling

### Exit Code Mode

| Exit Code | Behavior |
|-----------|----------|
| `0` | Success; stdout shown in verbose mode only (except UserPromptSubmit/SessionStart: injected into context) |
| `2` | Blocking error; behavior varies per event |
| Other | Non-blocking error; continues execution |

### Structured JSON Output (exit code 0)

```json
{
  "continue": true,
  "stopReason": "string",
  "suppressOutput": false,
  "systemMessage": "string",
  "hookSpecificOutput": { /* event-specific */ }
}
```

---

## Hook Event Definitions

### PreToolUse

| Property | Value |
|----------|-------|
| **Trigger** | After tool parameters created, before tool executes |
| **Matcher** | Tool names: `Task`, `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`, `WebFetch`, `WebSearch` |
| **Input** | `tool_name`, `tool_input`, `tool_use_id?` |
| **Decision Control** | `permissionDecision`: `allow \| deny \| ask`, `permissionDecisionReason`, `updatedInput?` |
| **Tooltip (short)** | "Intercept tool calls before they run; allow/deny/ask or rewrite tool input." |
| **Tooltip (long)** | "Runs after Claude drafts the tool arguments but before execution. Use it to enforce guardrails, rewrite risky commands, or auto-approve safe operations." |

---

### PermissionRequest

| Property | Value |
|----------|-------|
| **Trigger** | When a permission dialog is shown to the user |
| **Matcher** | Tool names (same as PreToolUse) |
| **Input** | `tool_name`, `tool_input`, `permission_suggestions?` |
| **Decision Control** | `decision.behavior`: `allow \| deny`, `updatedInput?`, `message?`, `interrupt?` |
| **Tooltip (short)** | "Auto-respond to permission dialogs; allow/deny on behalf of the user." |
| **Tooltip (long)** | "Use when you want hands-free operation with policy. Pair with PreToolUse: pre-screen the call, then auto-accept the dialog." |

---

### PostToolUse

| Property | Value |
|----------|-------|
| **Trigger** | Immediately after a tool completes successfully |
| **Matcher** | Tool names (same as PreToolUse) |
| **Input** | `tool_name`, `tool_input`, `tool_response`, `tool_use_id?` |
| **Decision Control** | `decision: "block"` + `reason`, `hookSpecificOutput.additionalContext` |
| **Tooltip (short)** | "Run after a tool succeeds: validate, annotate, lint, or add context." |
| **Tooltip (long)** | "Use as a verifier. If output violates policy, return decision=block with a reason to force corrective action." |

---

### PostToolUseFailure

| Property | Value |
|----------|-------|
| **Trigger** | After a tool execution fails |
| **Matcher** | Tool names |
| **Input** | `tool_name`, `tool_input`, `error`, `is_interrupt?` |
| **Decision Control** | Add context, notify, or force `continue=false` |
| **Tooltip (short)** | "Handle failed tool runs: alert, retry policy, or capture error context." |
| **Tooltip (long)** | "Best for improving reliability: on failures, log structured traces and nudge Claude toward recovery paths." |

---

### Notification

| Property | Value |
|----------|-------|
| **Trigger** | When the CLI sends a notification |
| **Matcher** | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| **Input** | `message`, `notification_type`, `title?` |
| **Decision Control** | None (side effects only) |
| **Tooltip (short)** | "React to UI/runtime notifications (idle, permission prompt, auth success)." |
| **Tooltip (long)** | "Use for 'out-of-band' automation: desktop notifications, Slack pings, or sound/vibration." |

---

### UserPromptSubmit

| Property | Value |
|----------|-------|
| **Trigger** | When the user submits a prompt, before the model processes it |
| **Matcher** | None |
| **Input** | `prompt` |
| **Decision Control** | Inject context (exit 0), or `decision="block"` + `reason` (removes prompt from context) |
| **Tooltip (short)** | "Validate or enrich user prompts before they run." |
| **Tooltip (long)** | "Add project state, enforce prompt hygiene, or prevent sensitive requests. Use blocking sparingly: it removes the prompt from context." |

---

### Stop

| Property | Value |
|----------|-------|
| **Trigger** | When the main agent has finished responding (not on user interrupt) |
| **Matcher** | None |
| **Input** | `stop_hook_active` (boolean) |
| **Decision Control** | `decision="block"` + `reason` prevents stopping, forces continued work |
| **Tooltip (short)** | "Stop gate: prevent stopping until criteria are satisfied." |
| **Tooltip (long)** | "Use as a 'definition of done' enforcer: run tests, check diffs, verify formatting. Beware infinite loops—respect stop_hook_active." |

---

### SubagentStart

| Property | Value |
|----------|-------|
| **Trigger** | When a subagent is started |
| **Matcher** | None |
| **Input** | `agent_id`, `agent_type` |
| **Decision Control** | Context injector or policy setter |
| **Tooltip (short)** | "Subagent boot hook: set context/policy before delegated work begins." |
| **Tooltip (long)** | "Great for multi-agent coordination: inject guardrails, repo scope, or task-specific conventions." |

---

### SubagentStop

| Property | Value |
|----------|-------|
| **Trigger** | When a subagent attempts to stop |
| **Matcher** | None |
| **Input** | `stop_hook_active` (boolean) |
| **Decision Control** | `decision="block"` + `reason` prevents stopping |
| **Tooltip (short)** | "Stop gate for subagents." |
| **Tooltip (long)** | "Enforce tests/verification inside delegated tasks. Guard against endless retries via stop_hook_active." |

---

### PreCompact

| Property | Value |
|----------|-------|
| **Trigger** | Before the runtime compacts conversation history |
| **Matcher** | `manual` (via `/compact`) or `auto` (context full) |
| **Input** | `trigger`, `custom_instructions` |
| **Decision Control** | None (logging/export only) |
| **Tooltip (short)** | "Before history compaction: export/annotate context." |
| **Tooltip (long)** | "Use to snapshot state, write summaries to disk, or tag the transcript for later retrieval." |

---

### SessionStart

| Property | Value |
|----------|-------|
| **Trigger** | When a new session starts or existing session is resumed |
| **Matcher** | `startup`, `resume`, `clear`, `compact` |
| **Input** | `source` |
| **Decision Control** | `hookSpecificOutput.additionalContext`, can write to `CLAUDE_ENV_FILE` |
| **Tooltip (short)** | "Session bootstrap: load context, set env, prepare workspace." |
| **Tooltip (long)** | "Ideal for auto-installing deps, reading issues/PRs, loading a repo map, and persisting environment variables for later bash tools." |

---

### SessionEnd

| Property | Value |
|----------|-------|
| **Trigger** | When the session ends |
| **Matcher** | None |
| **Input** | `reason` (clear/logout/prompt_input_exit/other) |
| **Decision Control** | Cannot block termination; cleanup/logging only |
| **Tooltip (short)** | "Session teardown: cleanup and write logs." |
| **Tooltip (long)** | "Use to flush traces, upload telemetry, or snapshot workspace state." |

---

## Example Plugin Compositions

### Plugin A: "Autofmt + Lint Gate"

**Goal**: Always format after edits, and refuse to stop until lint passes.

**Hook Graph**:
1. `PreToolUse (Write|Edit)` → rewrite risky edits or auto-approve safe edits
2. `PostToolUse (Write|Edit)` → run formatter, add `additionalContext` if changes made
3. `Stop` → run lint/tests; if failing, `decision="block"` with next-step reason

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh" }]
      }
    ]
  }
}
```

---

### Plugin B: "Secrets Sentinel"

**Goal**: Prevent accidental secret exfiltration and block risky shell commands.

**Hook Graph**:
- `UserPromptSubmit` → block prompts requesting secret disclosure
- `PreToolUse (Bash)` → deny commands resembling secret dumping (`cat ~/.ssh`, `printenv`)
- `PostToolUse (Write)` → scan diffs for secret patterns; if found, `decision="block"`
- `Notification (permission_prompt)` → alert when sensitive permission prompt occurs

---

### Plugin C: "Subagent Governance"

**Goal**: Multi-agent workflows must comply with repo conventions and never skip tests.

**Hook Graph**:
- `SubagentStart` → inject context: allowed directories, definition of done, preferred commands
- `SubagentStop` → block stopping until evidence is present (tests run, etc.)
- `PostToolUseFailure` → on subagent tool failures, log structured error bundle

---

## Visual Builder UX Specification

### Entry Point
- Settings screen: **"Open visual builder"** button
- Opens full-height **overlay** (sheet) on top of Settings
- Closing returns to Settings without navigating away

### Overlay Layout

| Panel | Contents |
|-------|----------|
| Left | **Node palette** (Events, Filters, Actions, Utilities) |
| Center | **Canvas** (pan/zoom, grid background) |
| Right | **Inspector panel** (selected node properties, tooltips, validation) |
| Top bar | "Back", "Save", "Discard", "Test run", "Export" |

### States & Transitions

| State | Description |
|-------|-------------|
| Idle (saved) | No unsaved changes |
| Dirty | Changes exist (dot on title, Save enabled) |
| Validating | Running schema + semantic validation |
| Error | Validation errors exist (Save disabled, click errors to focus nodes) |
| Saving | Persist graph + compiled artifacts |
| Saved | Success toast |
| Discard confirm | Modal if Dirty and user hits Back/close |

### Save/Discard Flows

**Save**:
1. Validate
2. If OK, compile graph
3. Write outputs: `graph.json` (source of truth), `hooks.json` (compiled), generated scripts

**Discard**: Revert to last saved `graph.json`

**Back/close when Dirty**: Modal "Save changes?" with Save / Discard / Cancel

### Tooltips Requirement (non-negotiable)

Every interactive UI element must have:
- **Hover tooltip** (1–2 sentences)
- **"Learn more"** expansion in Inspector (long form)
- **"Examples"** (at least 1) for nodes that can block/allow/transform

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space+Drag` | Pan canvas |
| `Cmd+Scroll` | Zoom |
| `Cmd+C/V` | Copy/paste nodes |
| `Delete` | Remove node |
| `A` | Open palette search |
| `Enter` | Place selected node |
| `Cmd+S` | Save |
| `Cmd+Enter` | Test run |
| `Cmd+Z` / `Cmd+Shift+Z` | Undo/redo |
| `Cmd+I` | Focus inspector |
| `M` | Toggle minimap |

---

## Node Taxonomy

### Event Nodes (Triggers)

| Category | Events |
|----------|--------|
| Tool lifecycle | `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest` |
| Prompt lifecycle | `UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop` |
| Session lifecycle | `SessionStart`, `SessionEnd`, `PreCompact` |
| UI notifications | `Notification` |

### Filter Nodes

| Node | Description |
|------|-------------|
| **Matcher** | Regex/picker for tool names, notification types, etc. |
| **Predicate** | JSONPath-like condition over input payload (advanced) |

### Action Nodes

| Node | Description |
|------|-------------|
| **Command** | Runs a script/command |
| **Prompt** | Runs an LLM prompt (plugins only) |
| **Agent** | Runs an agentic verifier (plugins only) |

### Control Nodes

| Node | Description |
|------|-------------|
| **Decision (Allow/Deny/Ask)** | For `PreToolUse` |
| **Permission Decision** | For `PermissionRequest` |
| **Block w/ Reason** | For `Stop`/`SubagentStop` and other blockable decisions |
| **Continue/Stop** | `continue=false` with `stopReason` as global hard stop |

### Transformation Nodes

| Node | Description |
|------|-------------|
| **Updated Input** | Constructs `updatedInput` object |
| **Additional Context** | Constructs `additionalContext` string |
| **System Message** | Sets `systemMessage` |

### Utility Nodes

| Node | Description |
|------|-------------|
| **Logger** | Write structured logs |
| **Export Trace** | Persist execution traces |
| **Rate limit / Debounce** | For noisy notifications and prompt submit |

---

## Graph JSON Schema (Draft 2020-12)

### High-Level Model

- `graph`: metadata + arrays of `nodes` and `edges`
- `node`: typed object with `inputs`, `outputs`, and `config`
- `edge`: connects `from.nodeId:portId` → `to.nodeId:portId`
- `validation`: stored results with node pointers
- `executionTrace`: per-run events, timings, and outputs

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://blaze.app/schemas/visual-hook-graph.schema.json",
  "title": "Visual Hook Graph",
  "type": "object",
  "required": ["version", "graphId", "nodes", "edges"],
  "properties": {
    "version": { "type": "string", "pattern": "^v\\d+\\.\\d+\\.\\d+$" },
    "graphId": { "type": "string" },
    "name": { "type": "string" },
    "description": { "type": "string" },
    "createdAt": { "type": "string", "format": "date-time" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "nodes": { "type": "array", "items": { "$ref": "#/$defs/node" } },
    "edges": { "type": "array", "items": { "$ref": "#/$defs/edge" } },
    "validation": { "$ref": "#/$defs/validationReport" },
    "executionTraces": { "type": "array", "items": { "$ref": "#/$defs/executionTrace" } }
  },
  "$defs": {
    "hookEventName": {
      "type": "string",
      "enum": ["PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
               "UserPromptSubmit", "Notification", "Stop", "SubagentStart",
               "SubagentStop", "PreCompact", "SessionStart", "SessionEnd"]
    },
    "node": {
      "type": "object",
      "required": ["id", "type", "position", "ports", "config"],
      "properties": {
        "id": { "type": "string" },
        "type": { "type": "string" },
        "label": { "type": "string" },
        "position": {
          "type": "object",
          "required": ["x", "y"],
          "properties": { "x": { "type": "number" }, "y": { "type": "number" } }
        },
        "ports": { "type": "array", "items": { "$ref": "#/$defs/port" } },
        "config": { "type": "object" },
        "ui": {
          "type": "object",
          "properties": {
            "collapsed": { "type": "boolean" },
            "color": { "type": "string" },
            "icon": { "type": "string" }
          }
        }
      }
    },
    "port": {
      "type": "object",
      "required": ["id", "direction", "dataType"],
      "properties": {
        "id": { "type": "string" },
        "direction": { "type": "string", "enum": ["in", "out"] },
        "name": { "type": "string" },
        "dataType": { "type": "string" },
        "required": { "type": "boolean" }
      }
    },
    "edge": {
      "type": "object",
      "required": ["id", "from", "to"],
      "properties": {
        "id": { "type": "string" },
        "from": {
          "type": "object",
          "required": ["nodeId", "portId"],
          "properties": { "nodeId": { "type": "string" }, "portId": { "type": "string" } }
        },
        "to": {
          "type": "object",
          "required": ["nodeId", "portId"],
          "properties": { "nodeId": { "type": "string" }, "portId": { "type": "string" } }
        },
        "enabled": { "type": "boolean", "default": true }
      }
    },
    "validationReport": {
      "type": "object",
      "properties": {
        "status": { "type": "string", "enum": ["ok", "warning", "error"] },
        "issues": { "type": "array", "items": { "$ref": "#/$defs/validationIssue" } }
      }
    },
    "validationIssue": {
      "type": "object",
      "required": ["severity", "message", "nodeId"],
      "properties": {
        "severity": { "type": "string", "enum": ["warning", "error"] },
        "message": { "type": "string" },
        "nodeId": { "type": "string" },
        "portId": { "type": "string" },
        "code": { "type": "string" },
        "help": { "type": "string" }
      }
    },
    "executionTrace": {
      "type": "object",
      "required": ["traceId", "startedAt", "event", "nodeRuns"],
      "properties": {
        "traceId": { "type": "string" },
        "startedAt": { "type": "string", "format": "date-time" },
        "endedAt": { "type": "string", "format": "date-time" },
        "event": {
          "type": "object",
          "required": ["hook_event_name", "input"],
          "properties": {
            "hook_event_name": { "$ref": "#/$defs/hookEventName" },
            "input": { "type": "object" }
          }
        },
        "nodeRuns": { "type": "array", "items": { "$ref": "#/$defs/nodeRun" } },
        "finalHookOutputs": { "type": "array", "items": { "type": "object" } }
      }
    },
    "nodeRun": {
      "type": "object",
      "required": ["nodeId", "status", "startedAt"],
      "properties": {
        "nodeId": { "type": "string" },
        "status": { "type": "string", "enum": ["success", "error", "skipped"] },
        "startedAt": { "type": "string", "format": "date-time" },
        "endedAt": { "type": "string", "format": "date-time" },
        "input": { "type": "object" },
        "output": { "type": "object" },
        "logs": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["ts", "level", "msg"],
            "properties": {
              "ts": { "type": "string", "format": "date-time" },
              "level": { "type": "string", "enum": ["debug", "info", "warn", "error"] },
              "msg": { "type": "string" },
              "data": { "type": "object" }
            }
          }
        }
      }
    }
  }
}
```

---

## Semantic Validation Rules

Beyond JSON Schema, the validator should enforce:

| Rule | Description |
|------|-------------|
| **Event-node uniqueness** | At least one event node per graph; optionally only one |
| **Decision compatibility** | `UpdatedInput` only under `PreToolUse`/`PermissionRequest` with allow; `Stop gate` only under `Stop`/`SubagentStop` |
| **Loop safety** | For `Stop`/`SubagentStop`, require loop breaker (max retries guard or `stop_hook_active` check) |

### Parallel Merge Precedence

If multiple nodes produce conflicting decisions:
1. `continue=false` wins globally
2. Explicit `deny` beats `allow`
3. `ask` beats `allow` when both present
4. For `PostToolUse`, any `decision=block` forces remediation

---

## Sources

- [Hooks reference (CLI)](https://code.claude.com/docs/en/hooks)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Agent SDK hook types](https://platform.claude.com/docs/en/agent-sdk/typescript)

---

# F005: Hooks Builder

**Feature ID**: E004-F005
**Story**: Create a visual drag-and-drop hooks builder for automating actions

---

## E004-F005-S001-T001-A001: HooksPipeline.swift

**Problem Statement**: Hooks need a data model representing the visual pipeline with nodes, connections, and configurations.

**Reference**: See [F005-R000: Graph JSON Schema](#graph-json-schema-draft-2020-12) for the complete graph model definition.

**Scope**
- In: HooksPipeline model with nodes array and connections array; HookNode model with type, position, config; HookConnection model
- Out: Pipeline execution; canvas rendering; JSON conversion to settings.json

**Assumptions**
- Nodes can be triggers, actions, or filters
- Connections are directional (source → target)

**Constraints**
- Must be Codable for persistence
- Position stored as CGPoint for canvas

**Functional Requirements**
1. HooksPipeline contains nodes and connections arrays
2. HookNode has: id, type, eventType, config dictionary, position
3. HookConnection has: id, sourceNodeId, targetNodeId, sourcePort, targetPort
4. Export to settings.json format

**Non-Functional Requirements**
- Model instantiation <1ms

**Implementation Steps**
1. Create HooksPipeline.swift in Core/Hooks/
2. Define HooksPipeline struct
3. Define HookNode struct with types
4. Define HookConnection struct
5. Add export function
6. Add validation function

**Files**
- New: `Blaze/Sources/Core/Hooks/HooksPipeline.swift`
- Touched: None

**Data Model**
```swift
struct HooksPipeline: Codable {
    var nodes: [HookNode]
    var connections: [HookConnection]

    func exportToSettings() -> [String: Any]
    func validate() -> [HookValidationError]
}

struct HookNode: Identifiable, Codable {
    let id: UUID
    var type: HookNodeType
    var eventType: String?
    var config: [String: AnyCodable]
    var position: CGPoint
}

/// Node type categories aligned with F005-R000 Node Taxonomy (27 types total)
enum HookNodeCategory: String, Codable, CaseIterable {
    case event       // 12 types: Trigger nodes
    case filter      // 2 types: Matcher, Predicate
    case action      // 3 types: Command, Prompt, Agent
    case control     // 4 types: Decision nodes
    case transform   // 3 types: Output construction
    case utility     // 3 types: Logging, tracing
}

enum HookNodeType: String, Codable, CaseIterable {
    // Event Nodes (12) - Triggers
    case preToolUse, postToolUse, postToolUseFailure, permissionRequest
    case userPromptSubmit, stop, subagentStart, subagentStop
    case sessionStart, sessionEnd, preCompact, notification

    // Filter Nodes (2)
    case matcher, predicate

    // Action Nodes (3)
    case command, prompt, agent

    // Control Nodes (4)
    case decisionAllowDenyAsk, permissionDecision, blockWithReason, continueStop

    // Transformation Nodes (3)
    case updatedInput, additionalContext, systemMessage

    // Utility Nodes (3)
    case logger, exportTrace, rateLimitDebounce

    var category: HookNodeCategory {
        switch self {
        case .preToolUse, .postToolUse, .postToolUseFailure, .permissionRequest,
             .userPromptSubmit, .stop, .subagentStart, .subagentStop,
             .sessionStart, .sessionEnd, .preCompact, .notification:
            return .event
        case .matcher, .predicate:
            return .filter
        case .command, .prompt, .agent:
            return .action
        case .decisionAllowDenyAsk, .permissionDecision, .blockWithReason, .continueStop:
            return .control
        case .updatedInput, .additionalContext, .systemMessage:
            return .transform
        case .logger, .exportTrace, .rateLimitDebounce:
            return .utility
        }
    }

    var displayName: String {
        switch self {
        case .preToolUse: return "Pre Tool Use"
        case .postToolUse: return "Post Tool Use"
        case .postToolUseFailure: return "Post Tool Use Failure"
        case .permissionRequest: return "Permission Request"
        case .userPromptSubmit: return "User Prompt Submit"
        case .stop: return "Stop"
        case .subagentStart: return "Subagent Start"
        case .subagentStop: return "Subagent Stop"
        case .sessionStart: return "Session Start"
        case .sessionEnd: return "Session End"
        case .preCompact: return "Pre Compact"
        case .notification: return "Notification"
        case .matcher: return "Matcher"
        case .predicate: return "Predicate"
        case .command: return "Command"
        case .prompt: return "Prompt"
        case .agent: return "Agent"
        case .decisionAllowDenyAsk: return "Decision (Allow/Deny/Ask)"
        case .permissionDecision: return "Permission Decision"
        case .blockWithReason: return "Block with Reason"
        case .continueStop: return "Continue/Stop"
        case .updatedInput: return "Updated Input"
        case .additionalContext: return "Additional Context"
        case .systemMessage: return "System Message"
        case .logger: return "Logger"
        case .exportTrace: return "Export Trace"
        case .rateLimitDebounce: return "Rate Limit/Debounce"
        }
    }

    var icon: String { // SF Symbol names
        switch category {
        case .event: return "bolt.fill"
        case .filter: return "line.3.horizontal.decrease.circle"
        case .action: return "play.fill"
        case .control: return "arrow.triangle.branch"
        case .transform: return "arrow.triangle.2.circlepath"
        case .utility: return "wrench.fill"
        }
    }
}

struct HookConnection: Identifiable, Codable {
    let id: UUID
    var sourceNodeId: UUID
    var targetNodeId: UUID
}
```

**API Contracts**
- `HooksPipeline.exportToSettings()` - Returns settings.json compatible dict
- `HooksPipeline.validate()` - Returns validation errors

**Event Contracts**
- N/A (data model)

**UI States**
- N/A (data model)

**UI Interactions**
- N/A (data model)

**UI Copy**
- N/A (data model)

**Edge Cases**
1. Empty pipeline - valid (no hooks)
2. Disconnected node - validation warning
3. Cycle in connections - validation error
4. Multiple triggers - valid (multiple entry points)

**Failure Modes**
- Invalid JSON on decode - throw error

**Rollback Plan**: Remove model; hooks only via JSON

**Test Plan**
- Unit: Test encode/decode round-trip
- Unit: Test validation catches cycles
- Unit: Test export format matches settings.json
- Integration: N/A
- UI: N/A
- Perf: N/A
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. Pipeline encodes/decodes correctly
2. Export matches settings.json format

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: Export format may not match settings.json schema exactly
- Mitigations: Validate against actual settings.json schema
- Blast Radius: Hooks configuration
- Fallback: Manual JSON editing

**Verification Steps**
1. Create pipeline → Export matches expected format
2. Add cycle → Validation returns error

**Artifact Outputs**: `Blaze/Sources/Core/Hooks/HooksPipeline.swift`

---

## E004-F005-S001-T002-A001: HooksCanvas.swift

**Problem Statement**: Users need a visual drag-and-drop canvas to arrange hook nodes and draw connections between them.

**Scope**
- In: Canvas view with drag-drop support; node placement; connection drawing; zoom/pan; grid background
- Out: Node rendering (HookNodeView); connection rendering (HookConnectionView); node configuration

**Assumptions**
- SwiftUI supports drag gestures
- Canvas can be arbitrarily large with scroll

**Constraints**
- Must support 50+ nodes without performance degradation
- Connections drawn as Bezier curves

**Functional Requirements**
1. Infinite canvas with pan gesture
2. Drag nodes to reposition
3. Draw connections between node ports
4. Delete connections by clicking
5. Grid background for alignment
6. Zoom control (50%-200%)

**Non-Functional Requirements**
- 60fps during drag operations
- Support 100 nodes without lag

**Implementation Steps**
1. Create HooksCanvas.swift in Settings/Hooks/
2. Implement canvas background with grid
3. Add pan/zoom gestures
4. Implement node drag positioning
5. Implement connection drawing
6. Add connection deletion

**Files**
- New: `Blaze/Sources/Settings/Hooks/HooksCanvas.swift`
- Touched: None

**Data Model**
```swift
struct HooksCanvas: View {
    @Binding var pipeline: HooksPipeline
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var draggedNode: UUID? = nil
    @State private var pendingConnection: PendingConnection? = nil
}
```

**API Contracts**
- Input: Binding to HooksPipeline
- Output: Updates pipeline as user drags

**Event Contracts**
- N/A (view)

**UI States**
- Default: Nodes displayed at positions
- Dragging node: Node follows cursor
- Drawing connection: Line follows cursor
- Zoomed: Scale applied to canvas

**UI Interactions**
- Drag node → Position updates
- Drag from port → Start connection
- Drop on port → Create connection
- Click connection → Delete it
- Two-finger pan → Canvas scrolls
- Pinch → Canvas zooms

**UI Copy**
- N/A (canvas)

**Edge Cases**
1. Node dragged off screen - canvas auto-scrolls
2. Connection to self - rejected
3. Many overlapping connections - z-ordering
4. Very zoomed out - nodes still clickable

**Failure Modes**
- Gesture conflict - prioritize node drag over pan

**Rollback Plan**: Use list-based hook editor instead

**Test Plan**
- Unit: N/A (view)
- Integration: Verify pipeline updates on drag
- UI: Verify drag/pan/zoom work
- Perf: Test 100 nodes at 60fps
- Security: N/A

**Telemetry Events**
- `hooks_canvas_node_moved`
- `hooks_canvas_connection_created`
- `hooks_canvas_connection_deleted`

**Metrics**: N/A

**Log Expectations**
- DEBUG: Node moved to: [position]
- DEBUG: Connection created: [source] → [target]

**Acceptance Criteria**
1. Nodes can be dragged
2. Connections can be drawn between nodes

**Definition of Done**
- [x] Code compiles without warnings
- [x] Drag works
- [ ] Code reviewed

**Risk Register**
- Risks: Complex gesture handling may have edge cases
- Mitigations: Thorough manual testing
- Blast Radius: Hooks builder UI
- Fallback: List-based editor

**Verification Steps**
1. Drag node → Position updates
2. Draw connection → Appears in pipeline

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HooksCanvas.swift`

---

## E004-F005-S001-T003-A001: HookNodeView.swift

**Problem Statement**: Each hook node needs visual representation showing its type, configuration summary, and connection ports.

**Reference**: See [F005-R000: Node Taxonomy](#node-taxonomy) for the complete list of node types and their categories.

**Scope**
- In: Node card with icon, title, config summary; input/output ports; selection state; resize handles
- Out: Canvas management; node configuration editing

**Assumptions**
- Node types have distinct icons
- Ports are positioned on edges

**Constraints**
- Node must be readable at default zoom
- Ports must be large enough to click

**Functional Requirements**
1. Show node type icon and title
2. Show configuration summary text
3. Display input port(s) on left edge
4. Display output port(s) on right edge
5. Selection highlight when selected
6. Different styling per node type (trigger=green, action=blue, filter=yellow)

**Non-Functional Requirements**
- Render <1ms per node

**Implementation Steps**
1. Create HookNodeView.swift in Settings/Hooks/
2. Implement card layout with icon and title
3. Add config summary section
4. Add port circles on edges
5. Add selection highlighting
6. Add type-specific styling

**Files**
- New: `Blaze/Sources/Settings/Hooks/HookNodeView.swift`
- Touched: None

**Data Model**
```swift
struct HookNodeView: View {
    let node: HookNode
    let isSelected: Bool
    let onPortDragStart: (UUID, PortType) -> Void
    let onPortDrop: (UUID, PortType) -> Void
}
```

**API Contracts**
- Input: HookNode to display
- Output: Port interaction callbacks

**Event Contracts**
- N/A (view)

**UI States**
- Normal: Standard styling
- Selected: Highlighted border
- Hover: Subtle highlight
- Dragging: Slight opacity

**UI Interactions**
- Click → Select
- Drag port → Start connection
- Double-click → Open config editor

**UI Copy**
- Title from node.eventType or node type name
- Config summary from node.config

**Edge Cases**
1. Very long title - truncated with ellipsis
2. No config - shows "Not configured"
3. Many ports - stack vertically

**Failure Modes**
- Invalid node type - show generic icon

**Rollback Plan**: Simple rectangle nodes

**Test Plan**
- Unit: N/A (view)
- Integration: Verify selection works
- UI: Verify all node types render
- Perf: Render 100 nodes <100ms
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. All node types display correctly
2. Ports are visible and clickable

**Definition of Done**
- [x] Code compiles without warnings
- [x] Nodes render
- [ ] Code reviewed

**Risk Register**
- Risks: Node design may not be intuitive
- Mitigations: Follow n8n/similar patterns
- Blast Radius: Node display
- Fallback: Simplified design

**Verification Steps**
1. Add trigger node → Shows with green styling
2. Add action node → Shows with blue styling

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HookNodeView.swift`

---

## E004-F005-S001-T004-A001: HookConnectionView.swift

**Problem Statement**: Connections between nodes need visual representation as curved lines that update as nodes move.

**Scope**
- In: Bezier curve from source port to target port; hover highlighting; click detection for deletion
- Out: Connection creation logic; canvas management

**Assumptions**
- Port positions can be calculated from node positions
- SwiftUI Path supports Bezier curves

**Constraints**
- Curves must be smooth
- Must be clickable for deletion

**Functional Requirements**
1. Draw Bezier curve from source to target
2. Calculate control points for smooth curves
3. Highlight on hover
4. Click detection for delete action
5. Animate when nodes move

**Non-Functional Requirements**
- Render <1ms per connection
- Smooth animation at 60fps

**Implementation Steps**
1. Create HookConnectionView.swift in Settings/Hooks/
2. Implement Bezier path calculation
3. Add hover detection
4. Add click handler
5. Add animation support

**Files**
- New: `Blaze/Sources/Settings/Hooks/HookConnectionView.swift`
- Touched: None

**Data Model**
```swift
struct HookConnectionView: View {
    let connection: HookConnection
    let sourcePosition: CGPoint
    let targetPosition: CGPoint
    let isHovered: Bool
    let onDelete: () -> Void
}
```

**API Contracts**
- Input: Connection with source/target positions
- Output: Delete callback

**Event Contracts**
- N/A (view)

**UI States**
- Normal: Subtle line
- Hovered: Highlighted with delete indicator
- Animating: Smooth position transition

**UI Interactions**
- Hover → Highlight
- Click → Delete

**UI Copy**
- N/A (visual element)

**Edge Cases**
1. Very short connection - still renders
2. Connection crosses other nodes - z-order handles
3. Nodes very far apart - curve stays smooth

**Failure Modes**
- Invalid positions - don't render

**Rollback Plan**: Straight lines instead of curves

**Test Plan**
- Unit: Test Bezier calculation
- Integration: Verify updates with node movement
- UI: Verify click detection
- Perf: 100 connections at 60fps
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. Curves render smoothly
2. Click deletes connection

**Definition of Done**
- [x] Code compiles without warnings
- [x] Curves render
- [ ] Code reviewed

**Risk Register**
- Risks: Bezier math may have edge cases
- Mitigations: Test with various node positions
- Blast Radius: Connection display
- Fallback: Straight lines

**Verification Steps**
1. Create connection → Curve appears
2. Move node → Curve updates smoothly

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HookConnectionView.swift`

---

## E004-F005-S001-T005-A001: HookInspectorView.swift

**Problem Statement**: Selected nodes need a configuration panel to edit their settings including event type, command, filters, and advanced options.

**Reference**: See [F005-R000: Hook Event Definitions](#hook-event-definitions) for tooltip text and decision control options per event type.

**Scope**
- In: Inspector panel for selected node; event type picker; command input; filter config; delete button
- Out: Canvas interaction; node model definition

**Assumptions**
- Inspector shows when node selected
- Config varies by node type

**Constraints**
- Inspector width: ~300pt
- Must validate config before save

**Functional Requirements**
1. Show node type and name
2. Event type picker (for triggers)
3. Command/script input (for actions)
4. Filter expression input (for filters)
5. Validate configuration
6. Delete node button

**Non-Functional Requirements**
- Config changes apply immediately

**Implementation Steps**
1. Create HookInspectorView.swift in Settings/Hooks/
2. Add node type header
3. Add event type picker for triggers
4. Add command input for actions
5. Add filter input for filters
6. Add validation and delete

**Files**
- New: `Blaze/Sources/Settings/Hooks/HookInspectorView.swift`
- Touched: None

**Data Model**
```swift
struct HookInspectorView: View {
    @Binding var node: HookNode?
    let onDelete: (UUID) -> Void
}
```

**API Contracts**
- Input: Binding to selected node
- Output: Delete callback

**Event Contracts**
- N/A (view)

**UI States**
- No selection: Empty/prompt
- Trigger selected: Event picker shown
- Action selected: Command input shown
- Filter selected: Expression input shown

**UI Interactions**
- Select event → Config updates
- Enter command → Config updates
- Click Delete → Node removed

**UI Copy**
- Section: "Configuration", "Event Type", "Command", "Filter"
- Empty: "Select a node to configure"
- Buttons: "Delete Node"

**Edge Cases**
1. No node selected - show empty state
2. Invalid config - show validation error
3. Read-only node - disable editing

**Failure Modes**
- Invalid config syntax - show error, don't save

**Rollback Plan**: In-node config editing

**Test Plan**
- Unit: N/A (view)
- Integration: Verify config saves to node
- UI: Verify all fields work
- Perf: N/A
- Security: Validate command input

**Telemetry Events**
- `hook_node_configured(node_type)`

**Metrics**: N/A

**Log Expectations**
- DEBUG: Node configured: [type]

**Acceptance Criteria**
1. Config changes apply to node
2. Validation prevents invalid config

**Definition of Done**
- [x] Code compiles without warnings
- [x] Config works
- [ ] Code reviewed

**Risk Register**
- Risks: Config UI may be complex for power users
- Mitigations: Add raw JSON mode for advanced users
- Blast Radius: Node configuration
- Fallback: JSON config only

**Verification Steps**
1. Select trigger → Event picker appears
2. Enter invalid config → Error shown

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HookInspectorView.swift`

---

## E004-F005-S002-T001-A001: HooksInstallationService.swift

**Problem Statement**: The visual builder must write the compiled `hooks.json` into Claude Code so the CLI can actually trigger hooks. Without a concrete install path and verification step, the system is only a UI.

**Scope**
- In: Resolve user vs project hook locations; write compiled `hooks.json`; create backups; verify CLI triggers; report install status
- Out: Canvas rendering and node configuration UI (handled by other atoms)

**Assumptions**
- Claude Code CLI is installed and available as `claude`
- Project hooks live at `<repo>/.claude/hooks.json`
- User hooks live at `~/.claude/hooks.json`
- Compiled `hooks.json` is produced by HooksPipeline

**Constraints**
- Must create `.claude/` directory if missing
- Must not overwrite existing hooks without a backup
- Must validate compiled JSON before writing
- Must not block the main UI thread

**Functional Requirements**
1. Provide `installHooks(scope:, compiledHooks:)` to write `hooks.json` to the selected scope
2. Provide `uninstallHooks(scope:)` to remove installed hooks for a scope
3. Provide `listInstalledHooks()` that reads user and project hooks and returns a merged view with scope labels
4. Provide `verifyHooks(scope:)` that runs a minimal CLI trigger and confirms the hook fires
5. Store backups with timestamps, e.g. `hooks.json.bak-YYYYMMDD-HHMMSS`

**Non-Functional Requirements**
- Install/uninstall operations complete in under 250ms for typical hook files
- Verification should fail fast (timeout 5s) with actionable errors

**Implementation Steps**
1. Create `HooksInstallationService.swift` with a dedicated actor for file IO
2. Add path resolution for user and project scopes
3. Validate compiled JSON against the hooks schema before writing
4. Write file atomically using a temp file + rename
5. Implement backup creation and restore on failure
6. Implement CLI verification by running a test hook and checking a marker file

**Files**
- New: `Blaze/Sources/Settings/Hooks/HooksInstallationService.swift`

**Data Model**
```swift
enum HookInstallScope: String, Codable {
    case user
    case project
}

struct InstalledHookSummary: Codable, Identifiable {
    let id: String
    let scope: HookInstallScope
    let eventName: String
    let matcher: String?
    let isEnabled: Bool
}
```

**API Contracts**
- `resolveHookPaths(scope:)` -> returns absolute path for hooks.json and backup dir
- `installHooks(scope:compiledHooks:)` -> throws on validation or write failure
- `verifyHooks(scope:)` -> returns pass/fail with error string

**Event Contracts**
- `hooks_installed(scope, hook_count)`
- `hooks_uninstalled(scope)`
- `hooks_verify_failed(scope, reason)`

**UI States**
- No UI state (service layer)

**UI Interactions**
- No direct UI interactions; called by lifecycle tooling

**UI Copy**
- No UI copy (service layer)

**Edge Cases**
1. `hooks.json` missing for a scope - install should create it
2. Corrupt existing `hooks.json` - backup and replace with validated version
3. CLI not installed - verification fails with a clear error

**Failure Modes**
- Write permission denied - surface error and keep previous file intact
- Verification timeout - report failure and keep install result

**Rollback Plan**: Restore the latest backup and remove the new `hooks.json`

**Test Plan**
- Unit: Path resolution for user/project scopes
- Unit: JSON validation rejects malformed hooks
- Integration: Install to temp directory and verify file contents
- UI: N/A
- Perf: Install under 250ms for a 200KB file
- Security: Ensure backups do not expose secrets in logs

**Telemetry Events**
- `hooks_installed(scope, hook_count)`
- `hooks_uninstalled(scope)`
- `hooks_verify_failed(scope, reason)`

**Metrics**
- `hooks_install_duration_ms` (timer) - install latency
- `hooks_verify_success_rate` (gauge) - percent of successful verifications

**Log Expectations**
- INFO: Installed hooks to [path] with [count] entries
- WARN: Verification failed: [reason]

**Acceptance Criteria**
1. Installing hooks writes valid JSON to the selected scope
2. Verification confirms the CLI fires at least one hook
3. Backups are created and can be restored

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit and integration tests pass
- [ ] CLI verification succeeds locally
- [ ] Code reviewed

**Risk Register**
- Risks: Incorrect install path prevents hooks from firing
- Mitigations: Path resolution tests and explicit scope labels
- Blast Radius: Hooks execution across CLI sessions
- Fallback: Use project scope only and disable user scope

**Verification Steps**
1. Run `swift build`
2. Run `swift test --filter HooksInstallationServiceTests`
3. Install to project scope and confirm `.claude/hooks.json` exists
4. Run CLI verification and confirm the marker file is created

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HooksInstallationService.swift`

---

## E004-F005-S002-T002-A001: HooksLifecycleView.swift

**Problem Statement**: Users need a lifecycle management tool to install, enable, disable, and scope hooks so they do not rebuild existing automation and can control where hooks live.

**Scope**
- In: List all installed hooks, show scope and status, enable/disable, uninstall, choose default install scope
- Out: Visual canvas editing (handled by HooksBuilderView and related atoms)

**Assumptions**
- HooksInstallationService can read and write hooks.json
- Hook summaries can be derived from compiled hooks.json

**Constraints**
- Must support both user and project scopes
- Must show conflicts when the same hook exists in both scopes
- Must not block the main UI thread

**Functional Requirements**
1. Display a list of all installed hooks from user and project scopes
2. Show scope, event name, matcher, and enabled status
3. Allow toggling enable/disable and persist changes
4. Allow uninstall per scope with confirmation
5. Allow setting default install scope for new hooks
6. Provide entry point to the lifecycle map view

**Non-Functional Requirements**
- List refresh completes in under 200ms for 100 hooks
- UI remains responsive during install/uninstall

**Implementation Steps**
1. Create `HooksLifecycleView.swift` with list, filters, and scope selector
2. Add scope picker: User and Project
3. Add list rows with enable toggle and uninstall button
4. Add refresh button and status banner
5. Add link to lifecycle map view
6. Wire view to HooksInstallationService

**Files**
- New: `Blaze/Sources/Settings/Hooks/HooksLifecycleView.swift`
- Touched: `Blaze/Sources/Settings/Hooks/HooksBuilderView.swift` (add tab or link)

**Data Model**
```swift
struct HooksLifecycleState {
    var defaultScope: HookInstallScope
    var installedHooks: [InstalledHookSummary]
    var lastRefresh: Date
}
```

**API Contracts**
- `refreshInstalledHooks()` -> updates list from user and project scopes
- `setDefaultScope(scope:)` -> persists user choice for new installs

**Event Contracts**
- `hooks_scope_changed(scope)`
- `hooks_list_refreshed(count)`
- `hook_toggle_changed(scope, hook_id, enabled)`

**UI States**
- Empty: No hooks installed
- Loaded: Hooks list with counts by scope
- Error: Failed to load hooks.json with retry option

**UI Interactions**
- Toggle hook -> enable/disable in hooks.json
- Change default scope -> new installs use that scope
- Tap map button -> open lifecycle map view

**UI Copy**
- Title: "Hooks Lifecycle"
- Scope label: "Default Install Scope"
- Empty: "No hooks installed. Create one in the builder."
- Buttons: "Refresh", "Uninstall", "View Map"

**Edge Cases**
1. Same hook ID in user and project scopes - show conflict badge
2. Uninstall user hooks while project hooks exist - list remains accurate
3. Hooks list larger than viewport - scrolling remains smooth

**Failure Modes**
- Parse error in hooks.json - show error banner and skip invalid entries
- Toggle fails to persist - revert UI state and show warning

**Rollback Plan**: Remove view and manage hooks via JSON only

**Test Plan**
- Unit: Merge user and project hooks with correct scope labels
- Integration: Toggle enable updates hooks.json and reloads list
- UI: Verify empty, loaded, and error states
- Perf: Refresh within 200ms for 100 hooks
- Security: Do not log hook command contents

**Telemetry Events**
- `hooks_scope_changed(scope)`
- `hooks_list_refreshed(count)`
- `hook_toggle_changed(scope, hook_id, enabled)`

**Metrics**
- `hooks_refresh_duration_ms` (timer) - list refresh time
- `hooks_enabled_count` (gauge) - number of enabled hooks

**Log Expectations**
- INFO: Hooks list refreshed with [count] entries
- WARN: Failed to parse hooks.json at [path]

**Acceptance Criteria**
1. Hooks list shows user and project hooks with scopes
2. Default scope selection is persisted and used for new installs
3. Enable/disable toggles update hooks.json correctly

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] UI states verified
- [ ] List refresh and toggles work
- [ ] Code reviewed

**Risk Register**
- Risks: Large hook lists may impact scroll performance
- Mitigations: Use lazy stacks and stable IDs
- Blast Radius: Hooks management UI
- Fallback: Simplify list to basic text rows

**Verification Steps**
1. Open Hooks Lifecycle -> list loads
2. Toggle a hook -> file updates and list reflects change
3. Change default scope -> persist and reload

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HooksLifecycleView.swift`

---

## E004-F005-S002-T003-A001: HooksLifecycleMapView.swift

**Problem Statement**: Users need a visual map of all active hooks across the CLI lifecycle so they can see which events are already hooked and avoid duplicate automation.

**Scope**
- In: Visual map of hook events, show hooks attached to each event, highlight scope and enabled status
- Out: Editing hook node graphs (handled by HooksBuilderView)

**Assumptions**
- InstalledHookSummary provides event name and scope
- Hook event list matches Claude Code lifecycle events in F005-R000

**Constraints**
- Must render all hook events in order: PreToolUse, PermissionRequest, PostToolUse, PostToolUseFailure, UserPromptSubmit, Notification, Stop, SubagentStart, SubagentStop, PreCompact, SessionStart, SessionEnd
- Must visually distinguish user vs project scope
- Must not block main UI thread

**Functional Requirements**
1. Render a timeline or swimlane map of hook events
2. Show hook badges on each event with name, scope, and enabled status
3. Provide filters for scope and event type
4. Allow clicking a hook badge to open its configuration in the builder
5. Show counts per event to indicate coverage

**Non-Functional Requirements**
- Map renders within 200ms for 100 hooks
- Interactive hit targets meet accessibility requirements

**Implementation Steps**
1. Create `HooksLifecycleMapView.swift` and define event order list
2. Group installed hooks by event and scope
3. Render event lanes with badges for hooks
4. Add filters for scope and enabled status
5. Add tap handling to open the hook in the builder
6. Add legend for scope colors and status

**Files**
- New: `Blaze/Sources/Settings/Hooks/HooksLifecycleMapView.swift`
- Touched: `Blaze/Sources/Settings/Hooks/HooksLifecycleView.swift` (launch map)

**Data Model**
```swift
struct HookEventLane: Identifiable {
    let id: String
    let eventName: String
    let hooks: [InstalledHookSummary]
}
```

**API Contracts**
- Input: `[InstalledHookSummary]` and filter state
- Output: Selection callback with hook ID

**Event Contracts**
- `hooks_map_opened`
- `hooks_map_filter_changed(scope, event)`
- `hooks_map_hook_selected(hook_id)`

**UI States**
- Empty: No hooks installed (show guidance)
- Loaded: Map with event lanes and hook badges
- Filtered: Map updates to show selected scope/event

**UI Interactions**
- Toggle filter -> map updates
- Click hook badge -> open builder at that hook
- Hover event -> show tooltip with event definition

**UI Copy**
- Title: "Hooks Lifecycle Map"
- Legend: "User scope", "Project scope", "Enabled", "Disabled"
- Empty: "No hooks installed. Build a hook to populate the map."

**Edge Cases**
1. Many hooks on one event - wrap badges or provide scroll
2. Unknown event name in hooks.json - show under "Other"
3. Disabled hooks - gray badges but still visible

**Failure Modes**
- Map render fails due to bad data - show error state and refresh button

**Rollback Plan**: Replace map with a simple grouped list

**Test Plan**
- Unit: Group hooks by event and scope correctly
- Integration: Map updates when hooks list changes
- UI: Verify filters and selection behavior
- Perf: Render within 200ms for 100 hooks
- Security: No hook command contents displayed by default

**Telemetry Events**
- `hooks_map_opened`
- `hooks_map_filter_changed(scope, event)`
- `hooks_map_hook_selected(hook_id)`

**Metrics**
- `hooks_map_render_time_ms` (timer) - render latency
- `hooks_event_coverage_count` (gauge) - events with at least one hook

**Log Expectations**
- INFO: Hooks map rendered with [event_count] events
- WARN: Unknown hook event encountered: [event]

**Acceptance Criteria**
1. Map shows all hook events and attached hooks
2. User and project hooks are visually distinct
3. Selecting a hook opens its configuration

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Map renders with real hooks
- [ ] Filters and selection work
- [ ] Code reviewed

**Risk Register**
- Risks: Visual map may become cluttered with many hooks
- Mitigations: Filters, grouping, and scrollable lanes
- Blast Radius: Hooks lifecycle map UI
- Fallback: Use grouped list view

**Verification Steps**
1. Install hooks in user and project scopes
2. Open map -> events show hooks with correct scope labels
3. Click hook badge -> builder opens correct hook

**Artifact Outputs**: `Blaze/Sources/Settings/Hooks/HooksLifecycleMapView.swift`

---

# F006: Integration

**Feature ID**: E004-F006
**Story**: Integrate new settings system into existing app infrastructure

---

## E004-F006-S001-T001-A001: SettingsSidebarView.swift (UPDATE)

**Problem Statement**: The existing SettingsSidebarView needs updates to integrate theme quick-switch, glass styling, and link to the new full settings window.

**Scope**
- In: Add theme dropdown; apply glass styling; add "Open Settings" button; update existing sections
- Out: Full settings window implementation; theme system implementation

**Assumptions**
- Existing SettingsSidebarView works
- ThemeManager is available in environment

**Constraints**
- Must not break existing functionality
- Glass styling via DSGlass

**Functional Requirements**
1. Add theme quick-switch dropdown at top
2. Apply glass styling to all sections
3. Add "Open Full Settings" button linking to SettingsWindow
4. Maintain existing functionality

**Non-Functional Requirements**
- No performance regression

**Implementation Steps**
1. Read existing SettingsSidebarView.swift
2. Add ThemeManager environment
3. Add theme dropdown at top
4. Apply DSGlass to sections
5. Add settings button
6. Test existing functionality

**Files**
- Touched: `Blaze/Sources/UI/Sidebar/SettingsSidebarView.swift`

**Data Model**
- No model changes (view update)

**API Contracts**
- No new APIs

**Event Contracts**
- N/A

**UI States**
- Existing states preserved
- Theme dropdown shows available themes

**UI Interactions**
- Select theme → Theme changes immediately
- Click Open Settings → Window opens

**UI Copy**
- Button: "Open Settings"
- Theme label: "Theme"

**Edge Cases**
1. ThemeManager not in environment - use default
2. Settings window already open - bring to front

**Failure Modes**
- Theme switch fails - log error, keep current theme

**Rollback Plan**: Revert file to previous version

**Test Plan**
- Unit: N/A (view)
- Integration: Verify existing tests pass
- UI: Verify new elements work
- Perf: No regression
- Security: N/A

**Telemetry Events**
- `sidebar_theme_changed(theme_id)`

**Metrics**: N/A

**Log Expectations**
- INFO: Theme changed via sidebar: [name]

**Acceptance Criteria**
1. Theme dropdown works
2. Existing functionality preserved

**Definition of Done**
- [x] Code compiles without warnings
- [x] Existing tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: May break existing sidebar functionality
- Mitigations: Test existing features thoroughly
- Blast Radius: Sidebar UI
- Fallback: Revert changes

**Verification Steps**
1. Change theme via dropdown → Theme applies
2. Verify existing sections still work

**Artifact Outputs**: `Blaze/Sources/UI/Sidebar/SettingsSidebarView.swift` (modified)

---

## E004-F006-S001-T002-A001: BlazeApp.swift (UPDATE)

**Problem Statement**: The app entry point needs to inject ThemeManager into environment and register the new Settings scene.

**Scope**
- In: Create and inject ThemeManager; register Settings scene; apply theme on launch
- Out: ThemeManager implementation; SettingsWindow implementation

**Assumptions**
- ThemeManager is implemented
- SettingsWindow is implemented

**Constraints**
- Must not break existing app startup
- Theme must apply before first render

**Functional Requirements**
1. Create ThemeManager instance
2. Inject into SwiftUI environment
3. Register SettingsWindow scene
4. Apply active theme on launch
5. Handle Cmd+, keyboard shortcut

**Non-Functional Requirements**
- App launch time not significantly increased

**Implementation Steps**
1. Read existing BlazeApp.swift
2. Add ThemeManager @StateObject
3. Inject via .environment()
4. Add Settings scene
5. Apply theme in .task or .onAppear
6. Test app launch

**Files**
- Touched: `Blaze/Sources/App/BlazeApp.swift`

**Data Model**
- No model changes (wiring only)

**API Contracts**
- ThemeManagerKey for environment access

**Event Contracts**
- N/A

**UI States**
- N/A (app structure)

**UI Interactions**
- Cmd+, → Settings window opens

**UI Copy**
- N/A

**Edge Cases**
1. Theme load fails - use Nebula default
2. Settings scene fails - log error, app still works

**Failure Modes**
- Theme crash on launch - catch and use default

**Rollback Plan**: Revert BlazeApp.swift changes

**Test Plan**
- Unit: N/A (app entry)
- Integration: Verify app launches
- UI: Verify Cmd+, works
- Perf: Launch time not increased >100ms
- Security: N/A

**Telemetry Events**
- `app_launched(theme_id)`

**Metrics**
- `app_launch_time_ms` (timer)

**Log Expectations**
- INFO: App launched with theme: [name]

**Acceptance Criteria**
1. ThemeManager available in views
2. Settings window accessible

**Definition of Done**
- [x] Code compiles without warnings
- [x] App launches
- [ ] Code reviewed

**Risk Register**
- Risks: Environment injection order may cause issues
- Mitigations: Test thoroughly; inject early in hierarchy
- Blast Radius: Entire app
- Fallback: Revert changes

**Verification Steps**
1. Launch app → Theme applied
2. Press Cmd+, → Settings opens

**Artifact Outputs**: `Blaze/Sources/App/BlazeApp.swift` (modified)

---

## E004-F006-S001-T003-A001: DSColors.swift (UPDATE)

**Problem Statement**: The design system colors need a `themed()` method that returns colors based on the active ThemeProfile, falling back to system colors when no overrides exist.

**Scope**
- In: Add themed() method; accept ThemeColors input; merge with system defaults
- Out: ThemeManager usage; UI application

**Assumptions**
- DSColors exists with static color properties
- ThemeColors is implemented

**Constraints**
- Must not break existing DSColors usage
- Backward compatible

**Functional Requirements**
1. Add `themed(_ colors: ThemeColors?) -> DSColors` method
2. Merge theme colors with system defaults
3. Return new DSColors instance with overrides applied
4. Handle nil gracefully (return unchanged)

**Non-Functional Requirements**
- Method call <1ms

**Implementation Steps**
1. Read existing DSColors.swift
2. Add themed() method
3. Implement color merging logic
4. Test with various theme inputs
5. Ensure backward compatibility

**Files**
- Touched: `Blaze/Sources/DesignSystem/Tokens/DSColors.swift`

**Data Model**
- No model changes (method addition)

**API Contracts**
- `DSColors.themed(_ colors:)` - Returns themed DSColors

**Event Contracts**
- N/A

**UI States**
- N/A (utility method)

**UI Interactions**
- N/A

**UI Copy**
- N/A

**Edge Cases**
1. nil theme colors - return self unchanged
2. Partial theme colors - merge with defaults
3. All colors overridden - all system colors replaced

**Failure Modes**
- Invalid color values - use system default

**Rollback Plan**: Remove themed() method

**Test Plan**
- Unit: Test themed() with various inputs
- Unit: Test nil input returns unchanged
- Unit: Test partial override merging
- Integration: Verify with ThemeManager
- UI: Verify colors apply correctly
- Perf: Method <1ms
- Security: N/A

**Telemetry Events**: N/A

**Metrics**: N/A

**Log Expectations**: N/A

**Acceptance Criteria**
1. themed() returns correctly merged colors
2. Existing DSColors usage unchanged

**Definition of Done**
- [ ] Code compiles without warnings
- [ ] Unit tests pass
- [ ] Code reviewed

**Risk Register**
- Risks: May affect existing color usage if not careful
- Mitigations: Method returns new instance, doesn't mutate
- Blast Radius: All colored UI elements
- Fallback: Remove method, use system colors

**Verification Steps**
1. Call themed(nil) → Returns unchanged
2. Call themed(custom) → Returns merged colors

**Artifact Outputs**: `Blaze/Sources/DesignSystem/Tokens/DSColors.swift` (modified)

---

# Summary

This specification defines 34 atoms across 6 features for the Settings & Theming Overhaul (Epic E004).

| Feature | Atoms | Key Files |
|---------|-------|-----------|
| F001: Theme Foundation | 5 | ThemeProfile, ThemeColors, BuiltInThemes, ThemeStore, ThemeManager |
| F002: Settings Window | 4 | SettingsWindow, SettingsCategory, SearchViewModel, Router |
| F003: Category Views | 12 | 12 individual settings view files |
| F004: Theme Editor | 2 | ThemeEditorView, ThemePreviewPanel |
| F005: Hooks Builder | 8 | HooksPipeline, Canvas, NodeView, ConnectionView, Inspector, Installation, Lifecycle, Map |
| F006: Integration | 3 | SettingsSidebarView, BlazeApp, DSColors (updates) |

**Total new files**: 31
**Total modified files**: 3
**Estimated effort**: 17-22 days
