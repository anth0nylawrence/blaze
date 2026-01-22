# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cogit0 Blaze** is a native macOS SwiftUI application that serves as a "harness" for agentic coding CLIs (Claude Code, Gemini CLI, OpenAI Codex CLI). Rather than calling provider APIs directly, it spawns CLI processes and parses their structured streaming output (NDJSON/stream-json) to render a polished desktop UX.

### Core Thesis
This is NOT a terminal emulator or web wrapper. It's:
- A **structured event renderer** consuming JSON events from CLI stdout
- A **governance layer** with policies, permissions, and review gates
- A **productivity cockpit** with timeline, tasks, and multi-file workspace
- A **concurrency orchestrator** for background work, hooks, and daemons

## Architecture

```
┌─────────────────── macOS App (SwiftUI) ───────────────────┐
│  UI Layer:           Chat timeline, tool cards, diffs    │
│  Orchestration:      SessionStore, EngineManager, Hooks  │
│  EngineAdapter:      ClaudeCodeAdapter, GeminiCliAdapter, │
│                      CodexCliAdapter                      │
└────────────────────────────┬──────────────────────────────┘
                             │ spawn child process / pipes
                             ▼
         Provider CLIs (unmodified binaries)
```

### Key Components (planned)
- **EngineAdapter**: Protocol abstracting CLI invocation, authentication, streaming events, and session lifecycle
- **NormalizedEvent**: Unified event schema (AssistantDelta, ToolCallStarted, FileDiffProduced, etc.) mapped from each CLI's output format
- **SessionStore**: SQLite + append-only JSONL for crash-safe event persistence
- **HookRunner**: Triggers automation on normalized events (OnToolEnd, OnDiffReady, etc.)
- **ProcessRunner**: Child process management with pipes and cancellation (SIGINT/SIGKILL)

### Golden Constraints
1. Never impersonate provider auth - only invoke each vendor's CLI login flow
2. Never parse ANSI terminal output - always use structured JSON output modes
3. Keep clean boundary between engine state and UI state
4. Be paranoid about security: file access, sandbox, approvals, secrets must be explicit

## Tech Stack

- **UI**: SwiftUI with NavigationSplitView (3-pane: Sessions | Chat | Sidebar)
- **Storage**: SQLite + append-only JSONL event logs
- **Distribution**: Developer ID signed + notarized `.dmg` (not App Store)
- **Target**: macOS only (no Windows/Linux initially)

## CLI Invocation Patterns

### Claude Code (primary)
```bash
claude -p "<prompt>" --output-format stream-json --allowedTools <tools>
```
Headless mode does NOT persist sessions - the harness manages conversation continuity via stored event logs and context prefaces.

### Gemini CLI
```bash
gemini -p "<prompt>" --output-format stream-json
gemini --resume  # for session continuity
```
Has native session persistence.

### OpenAI Codex CLI
```bash
codex exec --json "<prompt>"
codex exec resume  # for multi-turn
```
Supports sandbox policies and approval policies (`--full-auto`, etc.)

## Security Modes

Three user-selectable modes:
1. **Review Mode (default)**: Risky tools gated, file writes require review, shell commands need confirmation
2. **Trusted Mode**: Minimal gates for experienced users
3. **Sandbox Mode**: Read-only + safe tools only

## Development Phases

1. **MVP (7 days)**: Claude-only, headless turns, streaming UI, tool cards, basic diff viewer
2. **30 days**: Multi-engine architecture, Gemini integration, engine-agnostic hooks
3. **3 months**: Codex integration, worktree-per-task, multi-agent orchestration
4. **6 months**: Plugin system, policy templates, marketplace patterns

## Feature Roadmap (Atoms)

The feature roadmap is managed through a deterministic, validated JSONL pipeline:

```
docs/atoms/atoms.jsonl    ← Single source of truth (JSONL, v2 schema)
     ↓ (validate)
scripts/validate_atoms.py  ← Enforces schema, no truncation, no /mnt/ refs
     ↓ (render)
docs/roadmap/feature-roadmap.md  ← Derived markdown (do NOT edit directly)
```

### Working with Atoms

**DO NOT edit `docs/roadmap/feature-roadmap.md` directly.** Always edit `atoms.jsonl` and regenerate.

```bash
# Validate and render (run before commit)
make atoms

# Validate only
make validate-atoms

# Render only (after fixing validation errors)
make render-roadmap
```

### Atom Schema (v2)

Each atom must include:
- `schema_version: "v2"` - Required marker
- `created_at` / `updated_at` - ISO 8601 timestamps
- `source_refs_strict` - Repo-relative paths or https URLs only (no `/mnt/`)
- `na_justifications` - Explain any N/A fields
- `verification_steps` - How to prove completion (min 2)
- `risk_register` - Risks, mitigations, blast radius

### Validation Rules

The validator (`scripts/validate_atoms.py`) enforces:
- No ellipsis (`...`) in any field (truncation = build failure)
- No `/mnt/data` paths (use repo-relative paths)
- N/A justification required for all N/A fields
- Max 20% of fields can be N/A
- At least one non-N/A test in test_plan
- Dependency IDs must exist (no cycles)

See `docs/atoms/README.md` for full documentation.

## File Structure (planned)

```
cogit0-blaze/
  Blaze/Sources/          # Swift source code
  docs/atoms/             # Atom schema and JSONL source of truth
  docs/roadmap/           # Generated markdown (do not edit)
  scripts/                # Validation and rendering scripts
```
