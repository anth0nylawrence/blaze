# E005: Session Creation UX + Onboarding Epic

## Overview

This epic enhances the user experience for new users and improves session creation with multi-provider support. Based on the design mockups provided.

**Total Atoms**: 19
**Estimated Effort**: 7-9 days

---

## Feature Breakdown

### F001: Enhanced Session Creation Dialog (6 atoms)
Enhance NewSessionModal with directory source options and provider/model selection.

### F002: Sidebar Enhancements (3 atoms)
Add notification badges and vendor logos to session rows.

### F003: Onboarding + Tutorial (5 atoms)
7-screen first-launch onboarding wizard and interactive tutorial overlay.

### F004: Multi-CLI Hooks Support (5 atoms)
Update Hooks Builder for Claude/Gemini/Codex differences.

---

## F001: Enhanced Session Creation Dialog

### Context
- **Current**: `NewSessionModal.swift` has directory browse + trust mode picker
- **Gap**: No GitHub clone, no provider/model selection
- **Session model** already has `engineType` but not exposed in UI

### Atoms

#### A001-MODEL: Data Model Enhancements
Add provider/model types and extend Session model.

**Files to modify:**
- `Blaze/Sources/Core/Models.swift` - Add AIProvider, AIModel, AIModelRegistry, DirectorySource enums
- `Blaze/Sources/Data/SessionStore.swift` - Add provider/model_id columns
- `Blaze/Sources/Data/Migrations.swift` - Migration v7

**New Types:**
```swift
enum AIProvider: String, Codable, CaseIterable {
    case anthropic, openai, google
}

struct AIModel: Identifiable, Codable {
    let id: String, name: String, provider: AIProvider, tier: ModelTier
}

enum AIModelRegistry {
    static let anthropic: [AIModel] = [opus-4.5, sonnet-4.5, haiku-4.5]
    static let openai: [AIModel] = [codex-5.2-xhigh/high/medium]
    static let google: [AIModel] = [gemini-3.0-pro/flash]
}

enum DirectorySource { case browse, clone, create }
```

**Verification:** Unit test model registry, session persistence with provider/model

---

#### A002-CLONE: Git Clone Support
Add repository cloning capability.

**Files to modify:**
- `Blaze/Sources/Core/GitWorktreeManager.swift` - Add `cloneRepository(url:destination:shallow:)`

**Implementation:**
```swift
func cloneRepository(url: String, destination: String, shallow: Bool = false) async throws -> String
```

**Verification:** Integration test cloning public GitHub repo

---

#### A003-DIRSRC: Directory Source UI
Add segmented picker for directory source (Browse/Clone/Create).

**Files to modify:**
- `Blaze/Sources/UI/NewSessionModal.swift` - Add DirectorySourcePicker, conditional views

**UI Structure:**
```
DirectorySourcePicker (Segmented: Browse | Clone | Create)
├── BrowseDirectoryView (existing NSOpenPanel)
├── CloneRepositoryView (URL input + progress)
└── CreateProjectView (name input + git init toggle)
```

**Verification:** UI test source switching, clone flow, create flow

---

#### A004-PROVMOD: Provider/Model Selector
Add provider/model selection section.

**Files to modify:**
- `Blaze/Sources/UI/NewSessionModal.swift` - Add ProviderModelSection

**UI Structure:**
```
ProviderModelSection
├── Provider Picker (Segmented: Anthropic | OpenAI | Google)
└── Model List (Radio buttons with tier badges)
    ├── [●] Claude Opus 4.5 [flagship] - Most capable
    ├── [○] Claude Sonnet 4.5 [balanced] - Balanced
    └── [○] Claude Haiku 4.5 [fast] - Fastest
```

**Verification:** Provider change updates model list, selection persists

---

#### A005-CREATE: Session Creation Flow Update
Wire new options into session creation.

**Files to modify:**
- `Blaze/Sources/UI/NewSessionModal.swift` - Update createSession()
- `Blaze/Sources/App/BlazeApp.swift` - Update createSessionWithWorktree()

**Verification:** E2E test creating session with each source type + provider/model

---

#### A006-ENGINE: Engine Adapter Wiring
Map provider selection to correct CLI adapter.

**Files to modify:**
- `Blaze/Sources/Engine/EngineManager.swift` - Use session's provider for adapter selection

**Verification:** Correct CLI spawned based on session provider

---

## F002: Sidebar Enhancements

### Context
- **Current**: SessionRow shows status icon, name, time
- **Gap**: No unread counts, no vendor logos
- **CountBadge component exists** in design system

### Atoms

#### S001-UNREAD: Unread Badge State Management
Track read positions per session.

**New files:**
- `Blaze/Sources/Data/ReadStateStore.swift` - Persistence actor

**Files to modify:**
- `Blaze/Sources/Core/Models.swift` - Add SessionReadState
- `Blaze/Sources/Data/Migrations.swift` - Migration v7 (session_read_states table)
- `Blaze/Sources/App/BlazeApp.swift` - Add unreadCounts, markSessionAsRead()

**Schema:**
```sql
CREATE TABLE session_read_states (
    session_id TEXT PRIMARY KEY,
    last_read_sequence INTEGER NOT NULL DEFAULT 0,
    last_read_at DATETIME NOT NULL
);
```

**Verification:** Unread count calculates correctly, persists across restart

---

#### S002-BADGE: Unread Badge UI
Display count badges on session rows.

**Files to modify:**
- `Blaze/Sources/UI/Sidebar/SessionsSidebarView.swift` - Add unreadCount param to SessionRow

**UI:**
```
[●status] [Logo] [Name/Time] [Spacer] [CountBadge] [hover buttons]
```

**Verification:** Badge appears when unread > 0, hides for current session

---

#### S003-LOGOS: Vendor Brand Logos
Display actual brand logos instead of SF Symbols.

**New files:**
- `Blaze/Sources/DesignSystem/Components/VendorLogo.swift`

**New assets:**
- `Blaze/Resources/Assets.xcassets/logo-anthropic.imageset/` (16px @1x/2x/3x, template)
- `Blaze/Resources/Assets.xcassets/logo-google.imageset/`
- `Blaze/Resources/Assets.xcassets/logo-openai.imageset/`

**Files to modify:**
- `Blaze/Sources/UI/Sidebar/SessionsSidebarView.swift` - Use VendorLogo in SessionRow
- `Blaze/Sources/Core/Models.swift` - Extend EngineType with logoAssetName

**Verification:** Logos render at 16px, adapt to light/dark themes

---

## F003: Onboarding + Tutorial

### Context
- **Current**: No first-launch experience
- **Available patterns**: AppStorage, .fullScreenCover(), GlassPanel, FormSection
- **CLI detection**: EngineAdapter.validateInstallation() exists

### Atoms

#### O001-INFRA: Onboarding Infrastructure
State machine and container views.

**New files:**
- `Blaze/Sources/Onboarding/OnboardingStep.swift` - Step enum
- `Blaze/Sources/Onboarding/OnboardingViewModel.swift` - State management
- `Blaze/Sources/Onboarding/OnboardingRootView.swift` - Full-screen container
- `Blaze/Sources/Onboarding/OnboardingNavigationBar.swift` - Progress dots + nav

**State:**
```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome, userProfile, cliDetection,
         skillsRecommendations, pluginsRecommendations,
         agentsRecommendations, completion
}
```

**Verification:** Navigation works, step skipping works, AppStorage persists

---

#### O002-SCREENS: Onboarding Screen Views
Seven screen implementations.

**New files:**
- `Blaze/Sources/Onboarding/Screens/WelcomeOnboardingView.swift` - Animated welcome
- `Blaze/Sources/Onboarding/Screens/UserProfileOnboardingView.swift` - Name/email form
- `Blaze/Sources/Onboarding/Screens/CLIDetectionOnboardingView.swift` - Engine scanning
- `Blaze/Sources/Onboarding/Screens/SkillsRecommendationsView.swift` - Placeholder
- `Blaze/Sources/Onboarding/Screens/PluginsRecommendationsView.swift` - Placeholder
- `Blaze/Sources/Onboarding/Screens/AgentsRecommendationsView.swift` - Placeholder
- `Blaze/Sources/Onboarding/Screens/CompletionOnboardingView.swift` - Finish/tutorial

**CLI Detection Flow:**
1. Scan for claude, codex, gemini CLIs
2. Show detected version or "Not installed"
3. Install button opens vendor URL

**Verification:** CLI detection runs async, install buttons work, profile saves to AppStorage

---

#### O003-TUTORIAL: Tutorial Overlay System
Interactive spotlight tutorial.

**New files:**
- `Blaze/Sources/Tutorial/TutorialTarget.swift` - 7 target areas
- `Blaze/Sources/Tutorial/TutorialViewModel.swift` - Navigation state
- `Blaze/Sources/Tutorial/TutorialOverlayView.swift` - Main overlay
- `Blaze/Sources/Tutorial/TutorialBackdrop.swift` - Dimmed backdrop with cutout
- `Blaze/Sources/Tutorial/TutorialCallout.swift` - Cloud callout bubble
- `Blaze/Sources/Tutorial/TutorialAnchorPreferenceKey.swift` - Anchor registration

**Tutorial Targets:**
1. New Session button
2. Worktree sidebar
3. File tree
4. Terminal panel
5. Chat area
6. Chat input
7. Right sidebar (Timeline, Tools, Tasks, Tokens, Hooks)

**Verification:** Spotlight highlights correct areas, callout repositions, Complete dismisses

---

#### O004-INTEGRATE: App Integration
Wire onboarding and tutorial into app lifecycle.

**Files to modify:**
- `Blaze/Sources/App/BlazeApp.swift` - Add .fullScreenCover for onboarding, .overlay for tutorial
- `Blaze/Sources/App/ContentView.swift` - Add .tutorialTarget() modifiers

**New files:**
- `Blaze/Sources/DesignSystem/Components/WelcomeBackToast.swift`

**Logic:**
```swift
if !hasCompletedOnboarding {
    showOnboarding = true
} else if !userFirstName.isEmpty {
    showWelcomeBack = true  // 3-second toast
}
```

**Verification:** First launch shows onboarding, subsequent shows toast, Help menu can re-trigger tutorial

---

#### O005-POLISH: Animation Polish
Tasteful motion and transitions.

**Deliverables:**
- Welcome logo animation (scale + fade, 1.2s)
- Page transitions (horizontal slide, 0.35s spring)
- Callout entrance (scale + opacity, 0.35s)
- Toast slide-down (0.3s)

**Accessibility:** Check `accessibilityReduceMotion`, skip animations if enabled

**Verification:** Animations < 500ms, no janky transitions

---

## F004: Multi-CLI Hooks Support

### Context
Current Hooks Builder is provider-agnostic - no awareness of Claude vs Gemini vs Codex differences.

**CLI Hook Differences:**

| Aspect | Claude Code | Gemini CLI | Codex CLI |
|--------|-------------|------------|-----------|
| Hook support | Full | Full | None |
| Event prefix | Pre/Post | Before/After | N/A |
| Extra events | SubagentStop, PermissionRequest | BeforeModel, AfterModel, BeforeToolSelection | N/A |
| Config path | .claude/settings.json | .gemini/settings.json | N/A |
| Tool: shell | `Bash` | `run_shell_command` | N/A |
| Tool: edit | `Edit` | `replace` | N/A |
| Tool: write | `Write` | `write_file` | N/A |
| Tool: read | `Read` | `read_file` | N/A |
| Tool: glob | `Glob` | `glob` | N/A |
| Tool: search | `Grep` | `search_file_content` | N/A |

**Source References:**
- Claude: https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f
- Gemini: https://geminicli.com/docs/hooks/
- Codex: https://github.com/openai/codex/discussions/2150 (no hooks yet)

### Atoms

#### H001-SCHEMA: Hook Schema Types
Define provider-specific hook schemas.

**New files:**
- `Blaze/Sources/Core/Hooks/HookSchema.swift` - Per-provider schemas

**Types:**
```swift
enum HookProvider: String, CaseIterable {
    case claude, gemini, codex

    var supportsHooks: Bool {
        self != .codex
    }

    var events: [HookEventDefinition] { ... }
    var toolNameMapping: [String: String] { ... }
    var configPath: String { ... }
}

struct HookEventDefinition {
    let id: String
    let displayName: String
    let description: String
    let inputFields: [HookFieldDefinition]
    let outputFields: [HookFieldDefinition]
    let matchers: [String]?  // nil if no matchers
}

// Event registry per provider
enum ClaudeHookEvents {
    static let all: [HookEventDefinition] = [
        .init(id: "PreToolUse", ...),
        .init(id: "PostToolUse", ...),
        .init(id: "Stop", ...),
        .init(id: "SubagentStop", ...),
        .init(id: "UserPromptSubmit", ...),
        .init(id: "SessionStart", matchers: ["startup", "resume", "clear", "compact"]),
        .init(id: "SessionEnd", ...),
        .init(id: "PreCompact", ...),
        .init(id: "Notification", ...),
        .init(id: "PermissionRequest", ...)
    ]
}

enum GeminiHookEvents {
    static let all: [HookEventDefinition] = [
        .init(id: "BeforeTool", ...),
        .init(id: "AfterTool", ...),
        .init(id: "BeforeAgent", ...),  // = UserPromptSubmit
        .init(id: "AfterAgent", ...),   // = Stop
        .init(id: "BeforeModel", ...),  // NEW
        .init(id: "AfterModel", ...),   // NEW
        .init(id: "BeforeToolSelection", ...),  // NEW
        .init(id: "SessionStart", matchers: ["startup", "resume", "clear"]),
        .init(id: "SessionEnd", matchers: ["exit", "clear", "logout", "prompt_input_exit", "other"]),
        .init(id: "PreCompress", matchers: ["manual", "auto"]),
        .init(id: "Notification", matchers: ["ToolPermission"])
    ]
}
```

**Verification:** Unit tests for event definitions, tool mappings

---

#### H002-MIGRATE: Hook Migration Utilities
Convert hooks between providers.

**New files:**
- `Blaze/Sources/Core/Hooks/HookMigrator.swift`

**Functions:**
```swift
func migrateHook(from: HookProvider, to: HookProvider, hook: HookNode) -> HookNode?
func mapEventName(from: HookProvider, to: HookProvider, event: String) -> String?
func mapToolName(from: HookProvider, to: HookProvider, tool: String) -> String?
```

**Event Mapping (Claude → Gemini):**
- PreToolUse → BeforeTool
- PostToolUse → AfterTool
- UserPromptSubmit → BeforeAgent
- Stop → AfterAgent
- PreCompact → PreCompress

**Verification:** Round-trip migration preserves semantics

---

#### H003-UIPROVIDER: Provider-Aware Hooks Builder UI
Add provider selector and filter events/tools.

**Files to modify:**
- `Blaze/Sources/Settings/HooksBuilderView.swift` - Add provider picker
- `Blaze/Sources/Settings/Hooks/HookInspectorView.swift` - Filter events by provider
- `Blaze/Sources/Settings/Hooks/HookNodeView.swift` - Show provider-specific tool names

**UI Changes:**
```
HooksBuilderView
├── Header
│   ├── Provider Picker (Claude | Gemini | [Codex disabled])
│   └── (Codex: "Hooks not supported" banner)
├── Canvas (filtered by provider)
└── Inspector (events/tools filtered by provider)
```

**Codex Handling:**
- Disable hooks builder when Codex selected
- Show informational banner: "OpenAI Codex CLI does not support hooks yet"
- Link to GitHub discussion for updates

**Verification:** Events change when provider changes, Codex shows disabled state

---

#### H004-EXPORT: Provider-Specific Export
Export hooks to correct CLI config path.

**Files to modify:**
- `Blaze/Sources/Core/Hooks/HooksPipeline.swift` - Add provider param to export
- `Blaze/Sources/Settings/Hooks/HooksInstallationService.swift` - Use correct path

**Export Logic:**
```swift
func exportToSettings(for provider: HookProvider) -> [String: Any] {
    // Map event names to provider format
    // Map tool names in matchers
    // Return provider-specific JSON structure
}

func installHooks(for provider: HookProvider, projectPath: String) throws {
    let configPath = provider == .claude
        ? "\(projectPath)/.claude/settings.json"
        : "\(projectPath)/.gemini/settings.json"
    // Write to correct path
}
```

**Verification:** Export generates valid JSON for each provider

---

#### H005-SESSIONHOOK: Session-Aware Hook Context
Pass session provider to hook execution.

**Files to modify:**
- `Blaze/Sources/Engine/HookRunner.swift` - Add provider context
- `Blaze/Sources/App/BlazeApp.swift` - Pass session's provider to hook runner

**Changes:**
```swift
// HookRunner now knows which CLI is running
func executeHook(event: String, input: [String: Any], provider: HookProvider) async throws {
    // Load hooks from provider-specific config
    // Execute with provider context
}
```

**Verification:** Hooks execute from correct provider's config file

---

## Implementation Order

```
Week 1: F001 (Session Dialog)
  A001-MODEL → A002-CLONE → A003-DIRSRC → A004-PROVMOD → A005-CREATE → A006-ENGINE

Week 2: F002 + F003 (Sidebar + Onboarding)
  S001-UNREAD → S002-BADGE → S003-LOGOS
  O001-INFRA → O002-SCREENS → O003-TUTORIAL → O004-INTEGRATE → O005-POLISH

Week 3: F004 (Multi-CLI Hooks)
  H001-SCHEMA → H002-MIGRATE → H003-UIPROVIDER → H004-EXPORT → H005-SESSIONHOOK
```

---

## Key Files Summary

### Modified Files
| File | Feature |
|------|---------|
| `Blaze/Sources/Core/Models.swift` | F001, F002 |
| `Blaze/Sources/Data/SessionStore.swift` | F001 |
| `Blaze/Sources/Data/Migrations.swift` | F001, F002 |
| `Blaze/Sources/Core/GitWorktreeManager.swift` | F001 |
| `Blaze/Sources/UI/NewSessionModal.swift` | F001 |
| `Blaze/Sources/UI/Sidebar/SessionsSidebarView.swift` | F002 |
| `Blaze/Sources/App/BlazeApp.swift` | F001, F002, F003, F004 |
| `Blaze/Sources/App/ContentView.swift` | F003 |
| `Blaze/Sources/Engine/EngineManager.swift` | F001 |
| `Blaze/Sources/Settings/HooksBuilderView.swift` | F004 |
| `Blaze/Sources/Settings/Hooks/HookInspectorView.swift` | F004 |
| `Blaze/Sources/Settings/Hooks/HookNodeView.swift` | F004 |
| `Blaze/Sources/Core/Hooks/HooksPipeline.swift` | F004 |
| `Blaze/Sources/Settings/Hooks/HooksInstallationService.swift` | F004 |
| `Blaze/Sources/Engine/HookRunner.swift` | F004 |

### New Directories
- `Blaze/Sources/Onboarding/` - 8 files
- `Blaze/Sources/Tutorial/` - 6 files

### New Files (F004)
- `Blaze/Sources/Core/Hooks/HookSchema.swift` - Per-provider event/tool definitions
- `Blaze/Sources/Core/Hooks/HookMigrator.swift` - Cross-provider hook migration

### New Assets
- `Blaze/Resources/Assets.xcassets/logo-anthropic.imageset/`
- `Blaze/Resources/Assets.xcassets/logo-google.imageset/`
- `Blaze/Resources/Assets.xcassets/logo-openai.imageset/`

---

## Verification Plan

### E2E Tests
1. **Session Creation**: Create session via Browse/Clone/Create with each provider
2. **Sidebar Badges**: Receive events in background session, verify badge increments
3. **Onboarding Flow**: Complete all 7 screens, verify AppStorage persists
4. **Tutorial**: Step through all 7 highlights, verify Complete dismisses
5. **Hooks Builder**: Create hook for Claude, export, verify JSON format
6. **Hooks Builder**: Create hook for Gemini, export, verify JSON format
7. **Hooks Builder**: Select Codex, verify disabled state

### Manual QA
- [ ] Provider/model selector UI matches mockup
- [ ] Clone from GitHub works with public repo
- [ ] Vendor logos visible at 16px in both themes
- [ ] Onboarding animation is tasteful, not overwhelming
- [ ] Tutorial callouts don't overlap highlighted areas
- [ ] Hooks builder shows correct events per provider
- [ ] Hooks builder shows "not supported" for Codex
- [ ] Hook export writes to correct config path (.claude/ vs .gemini/)

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Model scope | Per-worktree | Enables concurrent multi-model workflows |
| Vendor logos | Brand assets | User preference; template rendering for theme compat |
| Onboarding data | Placeholder UI | Build screens first, real data later |
| Tutorial positioning | PreferenceKey anchors | Dynamic, works with window resize |
| Welcome animation | Single high-impact | Tasteful, not overwhelming |
| Hook schema source | External specs | Claude gist + Gemini docs are authoritative |
| Codex hooks | Show disabled | No hooks support yet; link to GitHub discussion |
| Hook migration | Bidirectional | Allow converting hooks between Claude/Gemini |
| Provider picker in hooks | Top-level | Clear context for which CLI's hooks are being edited |

---

## CLI Hook Event Reference

### Claude Code Events (10)
| Event | Matchers | Description |
|-------|----------|-------------|
| PreToolUse | tool patterns | Before tool execution |
| PostToolUse | tool patterns | After tool completion |
| Stop | - | Main agent stopping |
| SubagentStop | - | Subagent finished |
| UserPromptSubmit | - | User submitted prompt |
| SessionStart | startup, resume, clear, compact | Session beginning |
| SessionEnd | - | Session conclusion |
| PreCompact | - | Before context compaction |
| Notification | - | Generic notification |
| PermissionRequest | - | Permission dialog (v2.1.0+) |

### Gemini CLI Events (11)
| Event | Matchers | Description |
|-------|----------|-------------|
| BeforeTool | tool patterns | Before tool execution |
| AfterTool | tool patterns | After tool completion |
| BeforeAgent | - | Pre-planning after user prompt |
| AfterAgent | - | Agent loop completion |
| BeforeModel | - | Before LLM request |
| AfterModel | - | After LLM response |
| BeforeToolSelection | - | Pre-tool filtering |
| SessionStart | startup, resume, clear | Session initialization |
| SessionEnd | exit, clear, logout, prompt_input_exit, other | Session termination |
| PreCompress | manual, auto | Before context compression |
| Notification | ToolPermission | Permission notifications |

### Tool Name Mapping
| Claude | Gemini |
|--------|--------|
| Bash | run_shell_command |
| Edit | replace |
| Write | write_file |
| Read | read_file |
| Glob | glob |
| Grep | search_file_content |
| LS | list_directory |
