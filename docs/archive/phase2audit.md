# Phase 2 Sidebar System Audit Report (CORRECTED)

**Date:** 2026-01-04
**Auditor:** Alfred (CTO Agent) - CORRECTED AUDIT
**Scope:** `/docs/phase2.md` lines 1079-2315 (Feature 6: Comprehensive Sidebar System)

---

## Executive Summary

**CRITICAL FINDING:** The Phase 2 sidebar system (17-20 tabs across 5 collapsible categories) is **NOT IMPLEMENTED** in the running application. The app currently renders a simple 3-tab segmented picker (Timeline, Tools, Context).

| Metric | Spec | Actual |
|--------|------|--------|
| Tabs in Specification | 17-20 | **3** |
| Collapsible Category Groups | 5 | **0** |
| Sidebar View Files Created | 17 | 17 |
| Sidebar View Files **Actually Rendered** | 17 | **3** |
| Dead Code Files | 0 | **14** |

**Previous audit was WRONG.** It claimed "17/17 UI components present" but failed to verify they are actually rendered in the app.

---

## Root Cause Analysis

### What the Spec Promises (phase2.md lines 1079-1138)

```
┌─────────────────────────────────────┐
│ ▼ ACTIVITY                          │
│   Timeline │ Tools │ Tasks          │
├─────────────────────────────────────┤
│ ▼ FILES & CODE                      │
│   Files │ Git │ Search │ Bookmarks  │
├─────────────────────────────────────┤
│ ▼ SYSTEM                            │
│   Tokens │ MCP │ Hooks │ Logs       │
├─────────────────────────────────────┤
│ ▼ NAVIGATION                        │
│   Sessions │ Prompts │ Agents       │
├─────────────────────────────────────┤
│ ▼ GOVERNANCE                        │
│   Approvals │ Context               │
└─────────────────────────────────────┘
```

### What Actually Renders in the App

**File:** `Blaze/Sources/App/ContentView.swift` (lines 410-463)

```swift
struct SidebarView: View {
    enum SidebarTab: String, CaseIterable {
        case timeline = "Timeline"
        case tools = "Tools"
        case context = "Context"  // ← ONLY 3 TABS!
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)  // ← Simple picker, NOT collapsible categories
            // ...
        }
    }
}
```

### Code Path Proving This

```
BlazeApp.swift
  → ContentView.swift (line 31: ThreeColumnLayout)
    → right: { ... } (line 58-64)
      → SidebarView(sessionId: ...) ← Uses SIMPLE 3-tab SidebarView
        → enum SidebarTab { timeline, tools, context } ← Only 3 tabs!
```

**`SidebarContainer.swift` (with 20 tabs) is NEVER in the render chain.**

---

## The Two SidebarViews

### 1. `SidebarView` in `ContentView.swift` (ACTUALLY USED)

- Location: `Blaze/Sources/App/ContentView.swift` lines 410-463
- Tabs: **3 only** (Timeline, Tools, Context)
- UI: Simple segmented picker
- **This is what users see**

### 2. `SidebarContainer` in `SidebarContainer.swift` (DEAD CODE)

- Location: `Blaze/Sources/UI/Sidebar/SidebarContainer.swift`
- Tabs: **20** across 5 collapsible categories
- UI: Sophisticated with `SidebarCategoryView` groups
- **This is NEVER rendered** - only exists in SwiftUI Previews

---

## File-by-File Audit

### Files That EXIST but Are NEVER RENDERED

| File | Purpose | Status |
|------|---------|--------|
| `SidebarContainer.swift` | 20-tab container with categories | **DEAD CODE** |
| `SidebarCategoryView.swift` | Collapsible category groups | **DEAD CODE** |
| `TasksSidebarView.swift` | Tasks tab | **DEAD CODE** |
| `FilesSidebarView.swift` | Files tab | **DEAD CODE** |
| `GitSidebarView.swift` | Git tab | **DEAD CODE** |
| `SearchSidebarView.swift` | Search tab | **DEAD CODE** |
| `BookmarksSidebarView.swift` | Bookmarks tab | **DEAD CODE** |
| `TokensSidebarView.swift` | Tokens tab | **DEAD CODE** |
| `MCPSidebarView.swift` | MCP tab | **DEAD CODE** |
| `HooksSidebarView.swift` | Hooks tab | **DEAD CODE** |
| `LogsSidebarView.swift` | Logs tab | **DEAD CODE** |
| `SessionsSidebarView.swift` | Sessions tab | **DEAD CODE** |
| `PromptsSidebarView.swift` | Prompts tab | **DEAD CODE** |
| `AgentsSidebarView.swift` | Agents tab | **DEAD CODE** |
| `ApprovalsSidebarView.swift` | Approvals tab | **DEAD CODE** |
| `SettingsSidebarView.swift` | Settings tab | **DEAD CODE** |
| `ContextSidebarView.swift` (in SidebarContainer) | Context tab | **DEAD CODE** |

### Files That ARE Actually Rendered

| File | Used By | Status |
|------|---------|--------|
| `TimelineSidebarView.swift` | ContentView.swift line 441 | ✅ RENDERED |
| `ToolsSidebarView.swift` | ContentView.swift line 449 | ✅ RENDERED |
| Inline `ContextSidebarView` | ContentView.swift line 451 | ✅ RENDERED |

Note: The `ContextSidebarView` in `SidebarContainer.swift` is NOT used. ContentView uses its own inline version.

---

## Visual Evidence (User Screenshots)

User-provided screenshots confirm:

1. **Only 3 tabs visible:** Timeline | Tools | Context
2. **UI is segmented picker**, NOT collapsible categories
3. **No ACTIVITY/FILES & CODE/SYSTEM/NAV/GOVERNANCE groupings**
4. Features like Tasks, Files, Git, Search, Bookmarks, Tokens, MCP, Hooks, Logs, Sessions, Prompts, Agents, Approvals, Settings are **completely absent**

---

## Remediation Options

### Option A: Wire Up SidebarContainer (Full Implementation)

**Change in `ContentView.swift` line 58-64:**

```swift
// BEFORE (current):
right: {
    SidebarView(sessionId: selectedSessionId) { eventId in
        appState.scrollToEvent(eventId)
    }
    .background(Color.ds.surface.opacity(0.15))
}

// AFTER (using SidebarContainer):
right: {
    SidebarContainer(
        sessionId: selectedSessionId,
        events: appState.eventsForSession(selectedSessionId ?? UUID()),
        onEventTapped: { eventId in
            appState.scrollToEvent(eventId)
        }
    )
    .background(Color.ds.surface.opacity(0.15))
}
```

**Additional work required:**
1. Ensure `SidebarCategoryView` styles match app theme
2. Test all 20 tabs render correctly
3. Wire up data stores for each tab (many use mock data)

### Option B: Incremental Tab Addition

Add tabs to the existing `SidebarView` one at a time:

1. Add to `enum SidebarTab` in ContentView.swift
2. Add case to switch statement
3. Import and render the corresponding view
4. Test with real data

### Option C: Delete Dead Code (Descope)

If the 17-tab sidebar is no longer required:
1. Delete all unused sidebar view files
2. Update phase2.md to reflect reduced scope
3. Update atoms.jsonl to mark features as "descoped" or "dropped"

---

## Conclusion

| Question | Answer |
|----------|--------|
| Are the sidebar view FILES created? | Yes (17 files exist) |
| Are they wired into the app? | **NO** |
| Do users see them? | **NO** (only 3 tabs visible) |
| Is atoms.jsonl accurate? | Yes (marked "planned") |
| Were previous audit/handoffs misleading? | **YES** |

**Bottom Line:** 14+ sidebar view files are dead code sitting in `Blaze/Sources/UI/Sidebar/`. The sophisticated `SidebarContainer` with 5 collapsible categories was built but **never connected** to `ContentView.swift`. Users see only 3 tabs (Timeline, Tools, Context) via a simple segmented picker defined inline in ContentView.

---

## Appendix: Full File Tree

```
Blaze/Sources/UI/Sidebar/
├── AgentsSidebarView.swift      (20,121 bytes) - DEAD CODE
├── ApprovalsSidebarView.swift   (23,089 bytes) - DEAD CODE
├── BookmarksSidebarView.swift   (14,509 bytes) - DEAD CODE
├── ContextSidebarView.swift     (24,179 bytes) - DEAD CODE (duplicate in ContentView)
├── FilesSidebarView.swift       (18,602 bytes) - DEAD CODE
├── GitSidebarView.swift         (24,715 bytes) - DEAD CODE
├── HooksSidebarView.swift       (20,405 bytes) - DEAD CODE
├── LogsSidebarView.swift        (14,469 bytes) - DEAD CODE
├── MCPSidebarView.swift         (15,082 bytes) - DEAD CODE
├── PromptsSidebarView.swift     (25,124 bytes) - DEAD CODE
├── SearchSidebarView.swift      (20,439 bytes) - DEAD CODE
├── SessionsSidebarView.swift    (18,755 bytes) - DEAD CODE
├── SettingsSidebarView.swift    (15,062 bytes) - DEAD CODE
├── SidebarCategoryView.swift    (7,662 bytes)  - DEAD CODE (supports SidebarContainer)
├── SidebarContainer.swift       (13,135 bytes) - DEAD CODE (never wired to ContentView)
├── TasksSidebarView.swift       (11,882 bytes) - DEAD CODE
├── TimelineSidebarView.swift    (17,516 bytes) - ✅ USED
├── TokensSidebarView.swift      (14,051 bytes) - DEAD CODE
└── ToolsSidebarView.swift       (19,542 bytes) - ✅ USED

Total dead code: ~280KB of Swift files never rendered
```
