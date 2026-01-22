# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cogit0 Blaze** is a native macOS SwiftUI application that serves as a "harness" for agentic coding CLIs (Claude Code, Gemini CLI, OpenAI Codex CLI). It spawns CLI processes, parses their structured NDJSON output, and renders everything in a polished desktop UX with tool cards, diff viewers, and approval workflows.

**Core thesis:** This is NOT a terminal emulator. It's a structured event renderer + governance layer + productivity cockpit for AI coding agents.

## Build Commands

```bash
# Build the project
make build
# or directly:
cd Blaze && swift build

# Run all tests
make test
# or directly:
cd Blaze && swift test

# Run a specific test
cd Blaze && swift test --filter NDJSONParserTests
cd Blaze && swift test --filter "testParseSingleLine"

# Clean build artifacts
make clean
```

## Feature Roadmap (Atoms)

The roadmap uses a validated JSONL pipeline. **Never edit `docs/roadmap/feature-roadmap.md` directly.**

```bash
# Validate and render (run before commit)
make atoms

# Validate only
make validate-atoms

# Render only
make render-roadmap
```

## Architecture

```
┌──────────────── macOS App (SwiftUI) ────────────────┐
│  UI Layer           → Chat, tool cards, diff viewer │
│  SessionOrchestrator → CLI→parse→map→store→UI       │
│  EngineAdapter      → Protocol per CLI vendor       │
└──────────────────────────┬──────────────────────────┘
                           │ spawn child process / PTY
                           ▼
              Provider CLIs (unmodified binaries)
```

### Event Pipeline

1. **ProcessRunner/PtyProcessRunner** spawns CLI with `--output-format stream-json`
2. **NDJSONParser** parses streaming newline-delimited JSON chunks
3. **ClaudeEventMapper** (or vendor-specific) maps raw events to `NormalizedEvent`
4. **SessionOrchestrator** coordinates storage + UI updates
5. **EventStore** persists to SQLite + per-session NDJSON (belt and suspenders)

### Key Types

| Type | Location | Purpose |
|------|----------|---------|
| `EngineAdapter` | `Engine/EngineAdapter.swift` | Protocol for CLI adapters |
| `NormalizedEvent` | `Engine/NormalizedEvent.swift` | Engine-agnostic event enum |
| `SessionOrchestrator` | `Engine/SessionOrchestrator.swift` | Central turn coordinator |
| `ProcessRunner` | `Engine/ProcessRunner.swift` | Async process with pipes |
| `PtyProcessRunner` | `Engine/PtyProcessRunner.swift` | PTY for bidirectional stdin |
| `EventStore` | `Data/EventStore.swift` | SQLite + NDJSON persistence |
| `AppState` | `Core/AppState.swift` | @Observable root state |

### Source Layout

```
Blaze/Sources/
├── App/           # BlazeApp entry, ContentView, layout
├── Engine/        # Adapters, parsers, orchestrator, process runners
├── Core/          # AppState, utilities, git worktree manager
├── Data/          # Stores (Session, Event, Token, Hook, etc.)
├── UI/            # Views, sidebars, diff viewer, tool cards
├── DesignSystem/  # Glass components, tokens, modifiers
├── Settings/      # Preferences UI
├── Terminal/      # Terminal backend integration
└── LanguageServices/ # Syntax highlighting, diagnostics
```

## CLI Invocation

### Claude Code (primary)
```bash
claude -p "<prompt>" --output-format stream-json --allowedTools <tools>
```
Headless mode doesn't persist sessions - Blaze manages continuity via stored events.

### Gemini CLI
```bash
gemini -p "<prompt>" --output-format stream-json
```

### OpenAI Codex CLI
```bash
codex exec --json "<prompt>"
```

## Trust Modes

| Mode | Behavior |
|------|----------|
| **Review** (default) | Approve each tool call |
| **Trusted** | Ask once per tool type |
| **Sandbox** | Read-only tools only |

## Golden Constraints

1. Never impersonate provider auth - only invoke vendor CLI login flows
2. Never parse ANSI terminal output - always use structured JSON modes
3. Keep clean boundary between engine state and UI state
4. Security-paranoid: file access, approvals, secrets must be explicit

## Testing Patterns

Tests use `@testable import Blaze` and XCTest:

```swift
final class NDJSONParserTests: XCTestCase {
    func testParseSingleLine() async {
        let parser = NDJSONParser()
        let events = await parser.parse(chunk: data)
        XCTAssertEqual(events.count, 1)
    }
}
```

Test fixtures for NDJSON are in `Tests/Fixtures/NDJSON/`.

## Dependencies

- **GRDB** - SQLite wrapper for persistence
- **swift-async-algorithms** - Async streaming utilities
- **swift-collections** - OrderedDictionary, Deque
- **SwiftUIX** - AppKit-like SwiftUI extensions
- **SwiftTerm** - Terminal emulator for PTY
- **Inject** - Hot reload (DEBUG only)
