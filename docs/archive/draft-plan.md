# Blaze Feature Plans: Subagent Support & Ghostty Integration

**Created**: 2026-01-05
**Status**: Consolidated from original plans
**Source Plans**:
- `thoughts/shared/plans/2026-01-05-subagent-support.md` (~800 lines)
- `thoughts/shared/plans/2026-01-05-ghostty-integration.md` (~490 lines)

---

## Part 1: Concurrent Subagent Support

**Estimated Effort**: 15-20 engineering days

### Executive Summary

Implement comprehensive subagent support in Blaze to display, track, and manage concurrent Claude Code subagents spawned via the Task tool. The CLI handles subagent spawning internally; Blaze parses events and provides rich UI for monitoring 20-30 concurrent agents with pooling/queueing.

### User Requirements

| Requirement | Decision |
|-------------|----------|
| **Invocation** | Both user-explicit AND Claude auto-spawn |
| **Agent ID correlation** | Dual: tool_use.id + internal registry |
| **Spawn model** | CLI handles spawning (Blaze parses) |
| **Max concurrency** | Default 10, configurable up to 100+ (limited by RAM/CLI) |
| **Queue cancellation** | Ask user per case via dialog |
| **Event display** | Show all events, collapsed by default |
| **Token display** | Hierarchical breakdown + Timeline chart + Per-subagent cards |
| **Timeline granularity** | Auto-scale based on session duration |
| **Queue UX** | Drag to reorder priority |

### Implementation Phases

#### Phase 1A: Event Detection & Correlation (3 days)
- Add NormalizedEvent cases: subagentSpawned, subagentProgress, subagentCompleted, subagentFailed
- Modify ClaudeEventMapper to detect Task tool_use
- Route subagent events through SessionOrchestrator

#### Phase 1B: Registry & Pool (4 days)
- Create SubagentRegistry actor with dual correlation (toolUseId + internalId)
- Create SubagentPool actor for concurrency management
- Implement queue with priority ordering

#### Phase 1C: Chat Timeline UI (3 days)
- Create SubagentBlockView for collapsible subagent events
- Integrate into MessageBubbleView
- Show status badges and token summaries

#### Phase 1D: Sidebar Cards & Queue UI (4 days)
- Create SubagentsSidebarView with draggable queue cards
- Add to SidebarContainer tabs
- Implement drag-to-reorder priority

#### Phase 1E: Token Visualization (3 days)
- Create TokenHierarchyView for parent + children breakdown
- Create TokenTimelineChart with auto-scaling time axis
- Integrate into sidebar

#### Phase 1F: Settings UI for Concurrency (1 day)
- Create SubagentSettingsView with slider and presets
- Add auto-throttle on low memory

#### Phase 1G: Cancel Dialog & Integration (2 days)
- Create CancelQueuedSubagentsDialog
- Integrate cancel flow into SessionOrchestrator

### Database Migration v7
- Add parent_session_id to sessions table
- Create subagent_correlations table

### Files Summary
**New**: SubagentRegistry.swift, SubagentPool.swift, SubagentEventRouter.swift, SubagentBlockView.swift, SubagentsSidebarView.swift, TokenHierarchyView.swift, TokenTimelineChart.swift, CancelQueuedSubagentsDialog.swift, SubagentSettingsView.swift

**Modified**: NormalizedEvent.swift, ClaudeEventMapper.swift, SessionOrchestrator.swift, Migrations.swift, SessionStore.swift, Models.swift, BlazeApp.swift, SidebarContainer.swift, TokensSidebarView.swift, MessageBubbleView.swift

---

## Part 2: Ghostty Terminal Backend Integration

**Estimated Effort**: 5-8 engineering days (when libghostty available)

### Executive Summary

Add Ghostty as an optional terminal backend alongside SwiftTerm. The current architecture is already well-abstracted with a `TerminalBackend` protocol and factory pattern. Ghostty will be available as a settings dropdown option, with SwiftTerm remaining the default.

### User Requirements

| Requirement | Decision |
|-------------|----------|
| **Primary motivation** | Performance, Terminal compatibility, Future-proofing |
| **Strategy** | Design abstraction now, implement when libghostty ships |
| **Default backend** | SwiftTerm (stable, proven) |
| **User selection** | Settings dropdown to choose terminal backend |
| **Transition** | Feature flag not needed; direct settings toggle |

### Current Architecture (Already Ready)
- `TerminalBackend` protocol: Fully backend-agnostic
- `TerminalBackendFactory`: Factory pattern supports multiple backends
- `TerminalManager`: Uses `any TerminalBackend`, no SwiftTerm refs

### Implementation Phases

#### Phase 1: Abstraction Preparation ✅ DONE
Architecture is already abstracted. No changes needed.

#### Phase 2: Settings UI (1 day)
- Add terminal backend picker to TerminalSettingsView
- Persist choice with @AppStorage

#### Phase 3: Stub Backend (1 day)
- Create GhosttyBackend.swift as stub
- Throw informative error when selected

#### Phase 4: Factory Extension (0.5 day)
- Add TerminalBackendType enum
- Update factory to create correct backend

#### Phase 5: Full Implementation (4-5 days, when libghostty ships)
- Implement full GhosttyBackend with libghostty
- Metal rendering integration
- PTY management via forkpty()

### Files Summary
**New**: GhosttyBackend.swift, TerminalSettingsView.swift (if not exists)

**Modified**: TerminalBackend.swift, SettingsView.swift

---

## Atom Reference

Atoms for both features are tracked in `docs/atoms/atoms.jsonl` with prefixes:
- **ATOM-SUB-xxx**: Subagent support atoms
- **ATOM-GHO-xxx**: Ghostty integration atoms

See full implementation details in:
- `thoughts/shared/plans/2026-01-05-subagent-support.md`
- `thoughts/shared/plans/2026-01-05-ghostty-integration.md`
