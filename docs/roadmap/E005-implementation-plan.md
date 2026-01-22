# E005 Multi-CLI Support: Implementation Plan

**Generated:** 2026-01-11
**Total Atoms:** 74
**Estimated Duration:** 3-4 days with parallel execution

---

## Executive Summary

E005 enables Blaze to support multiple CLI backends (Claude Code, Gemini CLI, Codex CLI) with a unified UX. The implementation is highly parallelizable: **81% of atoms have no dependencies** and all 9 features can start simultaneously.

### Key Stats
| Metric | Value |
|--------|-------|
| Features | 9 |
| Total Atoms | 74 |
| Root Atoms (parallelizable) | 59 |
| Cross-Feature Dependencies | 1 |
| Max Critical Path Length | 3 atoms |

---

## Agent Assignment Strategy

### Agent Roles

| Agent | Role | Best For |
|-------|------|----------|
| `kraken` | Heavy Implementation | Complex features, multiple files, new systems |
| `spark` | Light Implementation | Single-file changes, quick fixes, UI tweaks |
| `architect` | Design & Planning | API design, protocol definitions |
| `scout` | Research | Finding existing patterns, code exploration |

### Feature-to-Agent Mapping

| Feature | Primary Agent | Rationale |
|---------|---------------|-----------|
| F001 Data Models | `kraken` | Core foundation, multiple interdependent types |
| F002 Notifications | `spark` | Small UI additions, badge rendering |
| F003 Onboarding | `kraken` | Complex multi-screen flow with state |
| F004 Hook Provider | `kraken` | New abstraction layer, service architecture |
| F005 CLI Detection | `kraken` | Process management, installation logic |
| F006 Registry | `kraken` | Network + SQLite + models |
| F007 Gantt View | `spark` | Primarily UI components |
| F008 Codex Integration | `kraken` | New adapter, process lifecycle |
| F009 Hook Types | `kraken` | Type system foundation, many files |

---

## Wave Execution Plan

### Wave 1: Foundation Layer (Parallel Start)

**All features begin simultaneously.** Focus on root atoms with no dependencies.

#### Stream A: Data Layer (3 parallel agents)

```
Agent 1 (kraken): F001 - Data Models
├── E005-F001-S001-T001-A001: AIProvider, AIModel, ProviderCapability enums
├── E005-F001-S001-T002-A001: Git clone backend
├── E005-F001-S001-T003-A001: Directory source picker
├── E005-F001-S001-T004-A001: Provider model selector
├── E005-F001-S001-T005-A001: Session creation modal
├── E005-F001-S001-T006-A001: Engine adapter routing
├── E005-F001-S001-T007-A001: CLI availability checker
└── E005-F001-S001-T008-A001: Provider defaults persistence

Agent 2 (kraken): F006 - Registry Data Layer
├── E005-F006-S001-T001-A001: RegistryItem, SkillManifest models
├── E005-F006-S001-T002-A001: RegistryFetcher (GitHub API)
├── E005-F006-S001-T004-A001: RegistryInstaller
├── E005-F006-S001-T005-A001: RegistryCoordinator
├── E005-F006-S002-T001-A001: Skills selection view
├── E005-F006-S002-T002-A001: Plugins selection view
└── E005-F006-S002-T003-A001: Agents selection view

Agent 3 (kraken): F009 - Hook Type System
├── E005-F009-S001-T001-A001: HookType enum
├── E005-F009-S001-T002-A001: HookMatchers
├── E005-F009-S001-T003-A001: HookInput struct
├── E005-F009-S001-T004-A001: HookOutputSchema
├── E005-F009-S001-T005-A001: Template struct
├── E005-F009-S001-T006-A001: HookTestRunner
├── E005-F009-S001-T007-A001: HookEnvironment
├── E005-F009-S002-T001-A001: Visual hook builder
├── E005-F009-S002-T002-A001: Template gallery
├── E005-F009-S002-T003-A001: Test panel view
├── E005-F009-S002-T004-A001: Env reference view
├── E005-F009-S002-T005-A001: HookValidator
├── E005-F009-S002-T006-A001: HookDebugService
└── E005-F009-S002-T007-A001: HookExportService
```

#### Stream B: Integration Layer (2 parallel agents)

```
Agent 4 (kraken): F004 - Hook Provider Abstraction
├── E005-F004-S001-T001-A001: HookProvider enum
├── E005-F004-S001-T002-A001: Per-provider event definitions
├── E005-F004-S001-T003-A001: MultiProviderHooksService
├── E005-F004-S001-T004-A001: Provider-aware executeHooks
├── E005-F004-S001-T005-A001: Provider selector control
├── E005-F004-S001-T006-A001: Hook description field
└── E005-F004-S001-T007-A001: HookMigrator

Agent 5 (kraken): F008 - Codex App-Server
├── E005-F008-S001-T001-A001: CodexAppServerAdapter
├── E005-F008-S001-T002-A001: App-server lifecycle manager
├── E005-F008-S001-T003-A001: Event stream parser
└── E005-F008-S001-T005-A001: CodexAppServerConfig
```

#### Stream C: User Experience (2 parallel agents)

```
Agent 6 (kraken): F003 - Onboarding Flow
├── E005-F003-S001-T001-A001: OnboardingManager
├── E005-F003-S001-T002-A001: Welcome screen
├── E005-F003-S001-T003-A001: User profile screen
├── E005-F003-S001-T004-A001: CLI detection screen
├── E005-F003-S001-T007-A001: Agents recommendations
├── E005-F003-S002-T001-A001: Tutorial overlay infra
├── E005-F003-S002-T002-A001: Tutorial step views
└── E005-F003-S003-T002-A001: Animation polish

Agent 7 (kraken): F005 - CLI Detection
├── E005-F005-S001-T001-A001: CLI type definitions
├── E005-F005-S001-T003-A001: CLISetupState enum
└── E005-F005-S001-T004-A001: CLI setup view
```

#### Stream D: UI Components (2 parallel agents)

```
Agent 8 (spark): F002 - Notifications
├── E005-F002-S001-T001-A001: ReadStateStore
├── E005-F002-S001-T002-A001: Unread badge UI
└── E005-F002-S001-T004-A001: Badge animation

Agent 9 (spark): F007 - Gantt Visualization
├── E005-F007-S001-T001-A001: HookTimelineEvent model
├── E005-F007-S001-T002-A001: HookTimelineBuilder
├── E005-F007-S001-T003-A001: HookGanttViewModel
├── E005-F007-S001-T004-A001: Gantt container view
└── E005-F007-S001-T007-A001: HookTooltip view
```

---

### Wave 2: Dependent Atoms (After Wave 1 Completes)

These atoms unblock as their dependencies complete. Can be assigned dynamically.

#### F001 Dependents (unblocks after F001-T001)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F002-S001-T003-A001 | VendorLogo component | `spark` |

#### F003 Dependents (unblocks after F003-T001, F003-T004)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F003-S001-T005-A001 | Skills recommendations screen | `spark` |
| E005-F003-S001-T006-A001 | Plugins recommendations screen | `spark` |
| E005-F003-S001-T008-A001 | Completion screen | `spark` |
| E005-F003-S003-T001-A001 | BlazeApp integration | `spark` |

#### F004 Dependents (unblocks after F004-T001)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F004-S001-T008-A001 | Provider-specific hook export | `spark` |
| E005-F004-S001-T009-A001 | Session-aware hook context | `spark` |

#### F005 Dependents (unblocks after F005-T001, F005-T003)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F005-S001-T002-A001 | CLIInstallationService | `kraken` |
| E005-F005-S001-T005-A001 | InstallationProgressView | `spark` |
| E005-F005-S001-T006-A001 | CLI setup ViewModel | `spark` |

#### F006 Dependents (unblocks after F006-T001)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F006-S001-T003-A001 | Registry SQLite cache | `spark` |

#### F007 Dependents (unblocks after F007-T001)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F007-S001-T005-A001 | GanttRow view | `spark` |
| E005-F007-S001-T006-A001 | GanttBar view | `spark` |

#### F008 Dependents (unblocks after F008-T001, F008-T002)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F008-S001-T004-A001 | CodexAppServerSession | `spark` |

#### F009 Dependents (unblocks after F009-T005)
| Atom | Description | Agent |
|------|-------------|-------|
| E005-F009-S002-T008-A001 | Production Hook Recipes (17 templates from community gist) | `spark` |

---

### Wave 3: Integration & Polish

After all atoms complete, integration testing and polish.

| Task | Agent | Description |
|------|-------|-------------|
| E2E Flow Testing | `atlas` | Test complete onboarding flow |
| Hook System Integration | `arbiter` | Verify hook routing across providers |
| Performance Audit | `profiler` | Check startup time, memory usage |
| Security Review | `aegis` | Audit CLI spawning, file access |

---

## Critical Path Analysis

### Longest Dependency Chain: F005 (3 atoms)
```
T001 (Types) → T002 (Service) ─┐
T003 (State) ────────────────────┼→ T006 (ViewModel)
```

### Cross-Feature Dependency (Only 1)
```
F001-T001 (AIProvider enum) → F002-T003 (VendorLogo)
```
**Mitigation:** F001-T001 is a root atom, will complete early.

---

## Parallel Execution Diagram

```
Time →
═══════════════════════════════════════════════════════════════

Wave 1 (all parallel):
┌─────────────────────────────────────────────────────────────┐
│ F001 ████████████████████                                   │
│ F002 ██████████                                             │
│ F003 ████████████████████████████                           │
│ F004 ██████████████████                                     │
│ F005 ████████                                               │
│ F006 ██████████████████████████                             │
│ F007 ████████████████                                       │
│ F008 ██████████████                                         │
│ F009 ████████████████████████████████████                   │
└─────────────────────────────────────────────────────────────┘

Wave 2 (dependent atoms):
┌─────────────────────────────────────────────────────────────┐
│      F002-T003 ████                                         │
│           F003-T005,T006,T008 ████████                      │
│           F003-S003-T001 ████                               │
│              F004-T008,T009 ████                            │
│         F005-T002 ████████                                  │
│              F005-T005,T006 ████                            │
│       F006-T003 ████                                        │
│         F007-T005,T006 ████                                 │
│            F008-T004 ████                                   │
└─────────────────────────────────────────────────────────────┘

Wave 3 (integration):
┌─────────────────────────────────────────────────────────────┐
│                              E2E Testing ████████████       │
│                              Polish ████████                │
└─────────────────────────────────────────────────────────────┘
```

---

## Agent Spawn Commands

### Wave 1 Launch Script

```bash
# Stream A: Data Layer
Task(kraken): "Implement F001 Data Model atoms (8 atoms): AIProvider enum, git clone, pickers, modals, routing, defaults"
Task(kraken): "Implement F006 Registry atoms (7 atoms): models, fetcher, installer, coordinator, selection views"
Task(kraken): "Implement F009 Hook Type System atoms (15 atoms): types, matchers, inputs, outputs, templates, views, services, production recipes"

# Stream B: Integration
Task(kraken): "Implement F004 Hook Provider atoms (7 atoms): HookProvider enum, events, service, executeHooks, selector, migrator"
Task(kraken): "Implement F008 Codex atoms (4 atoms): adapter, lifecycle, parser, config"

# Stream C: User Experience
Task(kraken): "Implement F003 Onboarding atoms (8 root atoms): manager, screens, tutorials, polish"
Task(kraken): "Implement F005 CLI Detection atoms (3 root atoms): types, state enum, setup view"

# Stream D: UI Components
Task(spark): "Implement F002 Notification atoms (3 atoms): ReadStateStore, badge UI, animations"
Task(spark): "Implement F007 Gantt atoms (5 root atoms): timeline model, builder, viewmodel, container, tooltip"
```

---

## Verification Checklist

### Per-Feature Acceptance Criteria

| Feature | Verification |
|---------|-------------|
| F001 | `claude --version`, `gemini --version` detected; session creates with selected provider |
| F002 | Badge appears on unread sessions; clears on view |
| F003 | Fresh app launch shows onboarding; can skip; completes |
| F004 | Hooks fire for correct provider; export generates valid JSON |
| F005 | Missing CLI prompts install; installed CLI shows checkmark |
| F006 | Registry fetches from GitHub; caches locally; installs selected items |
| F007 | Gantt chart renders hook timeline; tooltips show details |
| F008 | Codex sessions connect via app-server; events stream correctly |
| F009 | Hook types validate; templates apply; test runner executes |

### Integration Tests

```bash
# Full onboarding flow
make test-e2e TEST=onboarding

# Multi-provider session creation
make test-e2e TEST=multi-provider

# Hook routing
make test-e2e TEST=hook-routing
```

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| CLI not installed on user system | High | Medium | F005 handles installation flow |
| Registry API rate limits | Medium | Low | F006-T003 implements SQLite cache |
| Codex app-server not available | Medium | Medium | Graceful degradation in F008 |
| Hook migration breaks existing hooks | Low | High | F004-T007 HookMigrator with backup |

---

## Files Created/Modified (Estimated)

### New Files (~45)
```
Blaze/Sources/Models/AIProvider.swift
Blaze/Sources/Models/AIModel.swift
Blaze/Sources/Models/ProviderCapability.swift
Blaze/Sources/Models/HookProvider.swift
Blaze/Sources/Models/HookType.swift
Blaze/Sources/Models/RegistryItem.swift
Blaze/Sources/Services/CLIInstallationService.swift
Blaze/Sources/Services/RegistryFetcher.swift
Blaze/Sources/Services/MultiProviderHooksService.swift
Blaze/Sources/Views/Onboarding/*.swift (8 files)
Blaze/Sources/Views/Settings/Gantt/*.swift (5 files)
Blaze/Sources/Views/Registry/*.swift (3 files)
Blaze/Sources/Adapters/CodexAppServerAdapter.swift
...
```

### Modified Files (~15)
```
Blaze/Sources/Models/Session.swift (add provider field)
Blaze/Sources/Stores/SessionStore.swift (provider support)
Blaze/Sources/Views/SessionList/*.swift (badges, logos)
Blaze/Sources/BlazeApp.swift (onboarding integration)
...
```

---

## Summary

**Parallelization:** 9 agents can work simultaneously on Wave 1
**Critical Path:** F005 (3-deep dependency chain)
**Bottleneck:** F001-T001 must complete before F002-T003 (only cross-feature dep)
**Estimated Completion:** 3-4 days with full parallel execution

Ready to begin implementation when you give the go-ahead.
