<p align="center">
  <img src="./readme-logo.png" alt="Blaze Logo" width="200" height="200" />
</p>

<h1 align="center">Blaze</h1>

<h3 align="center">The Native Control Plane for Agentic Coding</h3>

<p align="center">
  <strong>Claude Code. Gemini CLI. OpenAI Codex. One cockpit.</strong>
</p>

<p align="center">
  <a href="https://getblaze.dev/docs/">Documentation</a> |
  <a href="#quick-start">Quick Start</a> |
  <a href="#feature-tour">Features</a> |
  <a href="#architecture">Architecture</a> |
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square&logo=apple" />
  <img alt="Swift 5.9" src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" />
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-Native-blue?style=flat-square&logo=swift" />
  <img alt="License AGPL-3.0" src="https://img.shields.io/badge/license-AGPL--3.0-green?style=flat-square" />
  <img alt="Build Status" src="https://img.shields.io/badge/build-passing-brightgreen?style=flat-square" />
  <img alt="PRs Welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square" />
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-supported-blueviolet?style=flat-square" />
  <img alt="Gemini CLI" src="https://img.shields.io/badge/Gemini%20CLI-supported-blue?style=flat-square" />
  <img alt="Codex CLI" src="https://img.shields.io/badge/Codex%20CLI-planned-yellow?style=flat-square" />
  <img alt="Native Performance" src="https://img.shields.io/badge/Native-60fps-success?style=flat-square" />
</p>

---

## Three Promises

| Promise | What It Means |
|---------|---------------|
| **Native Performance** | SwiftUI with glass effects, 60fps streaming, zero Electron bloat |
| **Visual Automation** | Node-based hooks builder. Drag. Connect. Ship. |
| **Parallel Agents** | Claude fixes bugs while Codex writes tests. Same repo. Different worktrees. |

---

## Table of Contents

<!-- TOC START -->

1. [What is Blaze?](#what-is-blaze)
   - [Plain English Explanation](#plain-english-explanation)
   - [What Blaze is NOT](#what-blaze-is-not)
   - [The Core Thesis](#the-core-thesis)
2. [Why Blaze? The Problem We Solve](#why-blaze-the-problem-we-solve)
   - [The Pain of CLI-Only Development](#the-pain-of-cli-only-development)
   - [Before and After: A Visual Comparison](#before-and-after-a-visual-comparison)
   - [The Opportunity Cost](#the-opportunity-cost)
3. [What Makes Blaze Different?](#what-makes-blaze-different)
   - [Unique Value Propositions](#unique-value-propositions)
   - [Feature Comparison Matrix](#feature-comparison-matrix)
   - [Decision Guide](#decision-guide)
4. [Who is Blaze For?](#who-is-blaze-for)
   - [Great Fit](#great-fit)
   - [Not a Fit](#not-a-fit)
   - [User Stories](#user-stories)
5. [Quick Start](#quick-start)
   - [System Requirements](#system-requirements)
   - [Prerequisites](#prerequisites)
   - [Installation Methods](#installation-methods)
   - [First Launch Setup](#first-launch-setup)
   - [Your First Session](#your-first-session)
6. [Feature Tour](#feature-tour)
   - [6.1 Multi-Engine Orchestration](#61-multi-engine-orchestration)
   - [6.2 Provider-Aware Model Selection](#62-provider-aware-model-selection)
   - [6.3 Session Management](#63-session-management)
   - [6.4 Chat Interface](#64-chat-interface)
   - [6.5 Tool Execution Display](#65-tool-execution-display)
   - [6.6 Subagent Display](#66-subagent-display)
   - [6.7 File Tree and Navigation](#67-file-tree-and-navigation)
   - [6.8 Diff Viewer](#68-diff-viewer)
   - [6.9 Security and Trust Modes](#69-security-and-trust-modes)
   - [6.10 Tool Approval System](#610-tool-approval-system)
   - [6.11 Command Allowlist](#611-command-allowlist)
   - [6.12 Design System and Theming](#612-design-system-and-theming)
   - [6.13 Terminal Integration](#613-terminal-integration)
   - [6.14 Hooks System](#614-hooks-system)
   - [6.15 Visual Hooks Builder](#615-visual-hooks-builder)
   - [6.16 Sidebar Panels](#616-sidebar-panels)
   - [6.17 Onboarding Flow](#617-onboarding-flow)
   - [6.18 Git Integration and Worktrees](#618-git-integration-and-worktrees)
7. [Settings Reference](#settings-reference)
   - [7.1 Appearance Settings](#71-appearance-settings)
   - [7.2 Chat and Input Settings](#72-chat-and-input-settings)
   - [7.3 Models Settings](#73-models-settings)
   - [7.4 Security and Trust Settings](#74-security-and-trust-settings)
   - [7.5 Engines Settings](#75-engines-settings)
   - [7.6 Terminal Settings](#76-terminal-settings)
   - [7.7 Agents Settings](#77-agents-settings)
   - [7.8 Files and Editor Settings](#78-files-and-editor-settings)
   - [7.9 Notifications Settings](#79-notifications-settings)
   - [7.10 CLI Power Settings](#710-cli-power-settings)
   - [7.11 Memory and Context Settings](#711-memory-and-context-settings)
   - [7.12 Git Settings](#712-git-settings)
   - [7.13 Shortcuts Settings](#713-shortcuts-settings)
8. [Architecture](#architecture)
   - [System Overview](#system-overview)
   - [Component Architecture](#component-architecture)
   - [Event Pipeline](#event-pipeline)
   - [Multi-Engine Flow](#multi-engine-flow)
   - [Session Lifecycle](#session-lifecycle)
   - [Approval Flow](#approval-flow)
   - [Hook System Architecture](#hook-system-architecture)
   - [Worktree Structure](#worktree-structure)
   - [UI Layout Architecture](#ui-layout-architecture)
   - [Data Layer Architecture](#data-layer-architecture)
   - [Subagent Orchestration](#subagent-orchestration)
9. [CLI Invocation Patterns](#cli-invocation-patterns)
   - [Claude Code](#claude-code)
   - [Gemini CLI](#gemini-cli)
   - [OpenAI Codex CLI](#openai-codex-cli)
10. [Data Layer Deep Dive](#data-layer-deep-dive)
    - [SessionStore](#sessionstore)
    - [EventStore](#eventstore)
    - [TokenStore](#tokenstore)
    - [HookStore](#hookstore)
    - [NDJSONLogger](#ndjsonlogger)
    - [BackupManager](#backupmanager)
11. [Subagent System](#subagent-system)
    - [SubagentRegistry](#subagentregistry)
    - [SubagentPool](#subagentpool)
    - [SubagentEventRouter](#subagenteventrouter)
12. [Keyboard Shortcuts Reference](#keyboard-shortcuts-reference)
    - [Global Shortcuts](#global-shortcuts)
    - [Chat Shortcuts](#chat-shortcuts)
    - [Navigation Shortcuts](#navigation-shortcuts)
    - [Diff Viewer Shortcuts](#diff-viewer-shortcuts)
    - [File Tree Shortcuts](#file-tree-shortcuts)
13. [Performance Notes](#performance-notes)
    - [Performance Budgets](#performance-budgets)
    - [Memory Budgets](#memory-budgets)
    - [Known Bottlenecks](#known-bottlenecks)
14. [Security Model](#security-model)
    - [Threat Model](#threat-model)
    - [Trust Mode Spectrum](#trust-mode-spectrum)
    - [Approval Workflows](#approval-workflows)
    - [Audit Logging](#audit-logging)
15. [Privacy and Telemetry](#privacy-and-telemetry)
    - [What Stays Local](#what-stays-local)
    - [What Leaves Your Machine](#what-leaves-your-machine)
    - [Optional Telemetry](#optional-telemetry)
16. [Troubleshooting](#troubleshooting)
    - [Installation Issues](#installation-issues)
    - [Authentication Issues](#authentication-issues)
    - [Tool Permission Issues](#tool-permission-issues)
    - [Hooks Not Firing](#hooks-not-firing)
    - [Diagnostics](#diagnostics)
17. [FAQ](#faq)
18. [Roadmap](#roadmap)
    - [Now (In Progress)](#now-in-progress)
    - [Next (30-90 days)](#next-30-90-days)
    - [Later (3-6 months)](#later-3-6-months)
    - [What We Are NOT Building](#what-we-are-not-building)
19. [Contributing](#contributing)
    - [Development Setup](#development-setup)
    - [Repository Layout](#repository-layout)
    - [Code Style](#code-style)
    - [PR Guidelines](#pr-guidelines)
20. [License](#license)
21. [Acknowledgments](#acknowledgments)

<!-- TOC END -->

---

## What is Blaze?

Blaze is a **native macOS desktop application** that wraps agentic coding CLIs (Claude Code, Gemini CLI, OpenAI Codex CLI) in a polished, high-performance interface.

### Plain English Explanation

Think of Blaze as **Mission Control for AI coding agents**. The CLI does the work. Blaze shows you what's happening, lets you approve dangerous operations, and keeps a perfect audit trail.

It spawns CLI processes, reads their structured JSON output, and renders everything in a proper GUI. No API keys to manage. No token counting in your head. Just run `claude` or `gemini` through a UI that doesn't make your eyes bleed.

```
+------------------------------------------------------------------+
|                         THE BLAZE CONCEPT                         |
+------------------------------------------------------------------+
|                                                                   |
|   YOU  ------>  BLAZE  ------>  CLI  ------>  AI PROVIDER        |
|                   |                                               |
|                   |  - Structured event rendering                 |
|                   |  - Visual diff review                         |
|                   |  - Approval workflows                         |
|                   |  - Session persistence                        |
|                   |  - Hooks automation                           |
|                                                                   |
+------------------------------------------------------------------+
```

### What Blaze is NOT

| Not This | This Instead |
|----------|--------------|
| Terminal emulator | Structured event renderer |
| Web wrapper / Electron app | Native SwiftUI with glass materials |
| API client | CLI orchestrator (uses official CLIs) |
| Code editor | Coding agent cockpit |
| Token counter | Visual progress and cost tracker |
| Chat app | Workflow automation platform |

### The Core Thesis

```
+------------------------------------------------------------------+
|                        BLAZE ARCHITECTURE                         |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  |                    macOS App (SwiftUI)                      |  |
|  |                                                              |  |
|  |  UI Layer:        Chat timeline, tool cards, diffs          |  |
|  |  Orchestration:   SessionStore, EngineManager, Hooks        |  |
|  |  EngineAdapter:   ClaudeCodeAdapter, GeminiCliAdapter,      |  |
|  |                   CodexCliAdapter                            |  |
|  +-----------------------------+--------------------------------+  |
|                                |                                   |
|                                | spawn child process / pipes       |
|                                v                                   |
|  +------------------------------------------------------------+  |
|  |              Provider CLIs (unmodified binaries)            |  |
|  |                                                              |  |
|  |  claude -p "..." --output-format stream-json                |  |
|  |  gemini -p "..." --output-format stream-json                |  |
|  |  codex exec --json "..."                                    |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

**Key insight**: Blaze is NOT a terminal emulator. It's NOT a web wrapper. It's a **structured event renderer** that consumes JSON events from CLI stdout and presents them as interactive UI components.

---

## Why Blaze? The Problem We Solve

### The Pain of CLI-Only Development

Terminal-based AI coding is powerful but exhausting:

| Pain Point | Description |
|------------|-------------|
| **Context blindness** | You can't see what the agent is about to do until it does it |
| **Scroll archaeology** | Finding that one tool call from 10 minutes ago |
| **Copy-paste diffs** | Reviewing changes means manual `git diff` gymnastics |
| **No pause button** | Agent runs wild. You watch. You pray. |
| **Session amnesia** | Close terminal, lose context. Start over. |
| **Multi-tool fatigue** | Different CLIs, different interfaces, different workflows |
| **Approval friction** | Y/N prompts with no context or preview |
| **Hook hell** | Writing JSON configs and shell scripts for automation |

### Before and After: A Visual Comparison

```
+------------------------------------------------------------------+
|                    WITHOUT BLAZE (Terminal)                       |
+------------------------------------------------------------------+
|                                                                   |
|  $ claude -p "Fix the auth bug"                                  |
|                                                                   |
|  I'll look at the authentication code...                         |
|                                                                   |
|  [Tool: Read] src/auth/login.ts                                  |
|  ... 200 lines of code scrolling by ...                          |
|                                                                   |
|  [Tool: Read] src/auth/session.ts                                |
|  ... more scrolling ...                                          |
|                                                                   |
|  I found the issue. Let me fix it.                               |
|                                                                   |
|  [Tool: Write] src/auth/login.ts                                 |
|  Allow this operation? [y/N]                                     |
|                                                                   |
|  (What changed? How many lines? Which functions?)                |
|  (Scrolls up frantically to find context)                        |
|                                                                   |
+------------------------------------------------------------------+

+------------------------------------------------------------------+
|                      WITH BLAZE (Native GUI)                      |
+------------------------------------------------------------------+
|                                                                   |
|  +----------------+  +---------------------------------------+   |
|  | Sessions       |  | Fix the auth bug           [Claude]  |   |
|  |                |  +---------------------------------------+   |
|  | > Auth Bug     |  |                                       |   |
|  |   API Refactor |  | YOU: Fix the auth bug                 |   |
|  |   Tests        |  |                                       |   |
|  |                |  | CLAUDE: I'll analyze the auth flow... |   |
|  +----------------+  |                                       |   |
|                      | +-----------------------------------+ |   |
|  +----------------+  | | [v] Read: src/auth/login.ts  1.2s | |   |
|  | Files          |  | |     245 lines | [Expand]          | |   |
|  |                |  | +-----------------------------------+ |   |
|  | src/           |  |                                       |   |
|  |   auth/        |  | +-----------------------------------+ |   |
|  |     login.ts   |  | | [v] Read: src/auth/session.ts 0.8s| |   |
|  |     session.ts |  | |     189 lines | [Expand]          | |   |
|  |                |  | +-----------------------------------+ |   |
|  +----------------+  |                                       |   |
|                      | I found the issue in the token...    |   |
|  +----------------+  |                                       |   |
|  | Approvals (1)  |  | +-----------------------------------+ |   |
|  |                |  | | Diff: src/auth/login.ts   +5 -2   | |   |
|  | Write: login.ts|  | |                                   | |   |
|  | [Accept][Deny] |  | | - if (expired) return null;       | |   |
|  |                |  | | + if (expired) {                  | |   |
|  +----------------+  | | +   await refreshToken();         | |   |
|  | [Preview diff] |  | | + }                               | |   |
|  +----------------+  | |                                   | |   |
|                      | | [Accept] [Reject] [Edit]          | |   |
|                      | +-----------------------------------+ |   |
|                      +---------------------------------------+   |
|                                                                   |
+------------------------------------------------------------------+
```

### The Opportunity Cost

Every hour spent fighting terminal UX is an hour not shipping.

| Task | Terminal Time | Blaze Time | Savings |
|------|---------------|------------|---------|
| Review multi-file diff | 5-10 min | 30 sec | 90% |
| Find specific tool call | 2-3 min | 5 sec | 95% |
| Set up approval hook | 30 min | 2 min | 93% |
| Compare sessions | Manual | 1 click | 100% |
| Resume after crash | Start over | Automatic | 100% |

The hooks builder alone saves days of YAML wrangling. Drag a "PreToolUse" trigger, connect it to a "Block if path matches" condition, wire up a notification action. Export. Done.

And with git worktree support, you can run Claude Code on a bug fix while Codex writes integration tests - simultaneously, isolated, on the same repo. That's not a workflow optimization. That's a multiplier.

---

## What Makes Blaze Different?

### Unique Value Propositions

```
+------------------------------------------------------------------+
|                  BLAZE DIFFERENTIATORS                            |
+------------------------------------------------------------------+
|                                                                   |
|  1. MULTI-ENGINE ORCHESTRATION                                   |
|     +--------+     +--------+     +--------+                     |
|     | Claude |     | Gemini |     | Codex  |                     |
|     +--------+     +--------+     +--------+                     |
|          \             |             /                            |
|           \            |            /                             |
|            +------------------------+                             |
|            |    Unified Interface   |                             |
|            +------------------------+                             |
|                                                                   |
|  2. VISUAL HOOKS BUILDER (Only in Blaze)                         |
|     [Trigger] ---> [Filter] ---> [Action] ---> [Output]          |
|         |             |             |             |               |
|     Drag & Drop   Conditions    Scripts      Notifications       |
|                                                                   |
|  3. PARALLEL WORKTREES                                           |
|     main/  -----------> Session A (Claude: features)             |
|       |                                                          |
|       +--worktree-1/ -> Session B (Codex: tests)                 |
|       |                                                          |
|       +--worktree-2/ -> Session C (Claude: docs)                 |
|                                                                   |
|  4. NATIVE PERFORMANCE                                           |
|     SwiftUI + Metal = 60fps streaming, glass effects, <1s launch |
|                                                                   |
+------------------------------------------------------------------+
```

### Feature Comparison Matrix

| Feature | Blaze | Warp 2.0 | Cursor | VS Code + Extensions | CLI Direct | Commander | CodexMonitor |
|---------|-------|----------|--------|---------------------|------------|-----------|--------------|
| **Platform** | Native macOS | Native | Electron | Electron | Terminal | Native macOS | Tauri |
| **Multi-CLI Support** | Claude, Gemini, Codex | Warp agents | Cursor models | Via extensions | Single CLI | Claude only | Codex only |
| **Structured Events** | Yes | Partial | No | No | N/A | TBD | Yes |
| **Visual Diff Review** | Yes | No | Yes | Via extensions | No | Yes | Yes |
| **Visual Hooks Builder** | Yes | No | No | No | No | No | No |
| **Trust Modes** | 4 modes + allowlists | Model-level | Project rules | Extension settings | CLI flags | TBD | Via Codex |
| **Session Persistence** | SQLite + JSONL | Warp Drive | Project-based | Workspace | Varies | TBD | Thread storage |
| **Worktree Support** | Yes | No | No | No | Manual | No | Yes |
| **Subagent Display** | Yes | No | No | No | Text only | No | Yes |
| **Token Visualization** | Yes | No | No | No | No | No | No |
| **60fps Streaming** | Yes | Yes | No | No | N/A | TBD | Yes |
| **Glass Effects** | 5 levels | Some | No | No | N/A | Some | No |
| **Price** | TBD | Free + Pro | $20/mo | Free + ext | Free (API) | Free | Free |

### Decision Guide

```
+------------------------------------------------------------------+
|                    SHOULD YOU USE BLAZE?                          |
+------------------------------------------------------------------+
|                                                                   |
|              Do you use AI coding assistants?                     |
|                          |                                        |
|              +-----------+-----------+                            |
|              |                       |                            |
|             Yes                     No                            |
|              |                       |                            |
|     Are you on macOS?         Not for you                        |
|              |                (try Claude web)                    |
|     +--------+--------+                                          |
|     |                 |                                          |
|    Yes               No                                          |
|     |                 |                                          |
| Do you want GUI?   Windows/Linux                                 |
|     |              not supported                                 |
|  +--+--+                                                         |
|  |     |                                                         |
| Yes   No                                                         |
|  |     |                                                         |
|  |   Use CLI                                                     |
|  |   directly                                                    |
|  |                                                               |
| Do you need visual hooks?                                        |
|  |                                                               |
| +--+--+                                                          |
| |     |                                                          |
|Yes   No                                                          |
| |     |                                                          |
| |  Consider Commander                                            |
| |  (simpler, Claude-only)                                        |
| |                                                                |
| +---> BLAZE IS FOR YOU                                           |
|                                                                   |
+------------------------------------------------------------------+
```

---

## Who is Blaze For?

### Great Fit

| User Profile | Why Blaze |
|--------------|-----------|
| **Power Users** | Multiple CLIs, parallel agents, custom hooks |
| **Security-Conscious** | Review mode, approval workflows, audit logs |
| **Visual Thinkers** | Diff preview, tool cards, timeline view |
| **Automation Enthusiasts** | Visual hooks builder, no YAML |
| **Teams** | Consistent workflows, shared hook templates |

### Not a Fit

| User Profile | Better Alternative |
|--------------|-------------------|
| VS Code natives | Cursor, Continue, Copilot |
| Windows/Linux users | CLI direct, web UIs |
| API-first developers | Direct API integration |
| Simple use cases | Claude web, ChatGPT |

### User Stories

**The Security-Conscious Developer**

> "I want to use Claude for coding, but I don't trust giving an AI full access to my filesystem."

How Blaze helps: Review Mode requires explicit approval for every file write and shell command. You see exactly what's being modified before it happens. The PolicyEngine blocks dangerous patterns automatically.

**The Multi-Tool User**

> "I use Claude for some tasks, Gemini for others, and want to try Codex. Managing three different tools is annoying."

How Blaze helps: Blaze provides a unified interface for all three CLIs. Same keyboard shortcuts, same diff viewer, same session history - regardless of which AI you're talking to.

**The Automation Enthusiast**

> "I want to run tests automatically after Claude edits code, and notify Slack when sessions complete."

How Blaze helps: The Hook System lets you trigger custom scripts on any event. Set up a post-hook on file writes to run tests, and a session end hook to call a Slack webhook.

---

## Quick Start

### System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **macOS** | 14.0 (Sonoma) | 15.0 (Sequoia) |
| **Processor** | Apple Silicon or Intel | Apple Silicon (M1+) |
| **RAM** | 8 GB | 16 GB |
| **Disk** | 500 MB | 2 GB (with caches) |
| **Xcode CLT** | Required | Latest |

### Prerequisites

Before installing Blaze, you need at least one supported CLI:

```bash
# Claude Code (recommended)
npm install -g @anthropic-ai/claude-code
claude auth login

# Gemini CLI (optional)
npm install -g @google/gemini-cli
gemini auth login

# OpenAI Codex CLI (optional, coming soon)
# npm install -g @openai/codex-cli
# codex auth login
```

### Installation Methods

#### Method 1: DMG Download (Recommended)

```bash
# Download latest release
curl -L https://github.com/anth0nylawrence/blaze/releases/latest/download/Blaze.dmg -o Blaze.dmg

# Mount and install
hdiutil attach Blaze.dmg
cp -R /Volumes/Blaze/Blaze.app /Applications/
hdiutil detach /Volumes/Blaze

# First launch (will prompt for permissions)
open /Applications/Blaze.app
```

#### Method 2: Build from Source

```bash
# Clone repository
git clone git@github.com:anth0nylawrence/blaze.git
cd blaze

# Build with Xcode
xcodebuild -project Blaze/Blaze.xcodeproj \
  -scheme Blaze \
  -configuration Release \
  -derivedDataPath build

# Copy to Applications
cp -R build/Build/Products/Release/Blaze.app /Applications/
```

### First Launch Setup

On first launch, Blaze will guide you through setup:

```
+------------------------------------------------------------------+
|                     BLAZE ONBOARDING FLOW                         |
+------------------------------------------------------------------+
|                                                                   |
|  Step 1: Welcome                                                 |
|  +------------------------------------------------------------+  |
|  |                                                              |  |
|  |  Welcome to Blaze                                           |  |
|  |                                                              |  |
|  |  The native control plane for agentic coding.               |  |
|  |                                                              |  |
|  |  [Get Started]                                              |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Step 2: CLI Detection                                           |
|  +------------------------------------------------------------+  |
|  |  Detected CLIs:                                             |  |
|  |                                                              |  |
|  |  [x] Claude Code v1.2.3  (authenticated)                   |  |
|  |  [x] Gemini CLI v0.8.1   (needs login)                     |  |
|  |  [ ] Codex CLI           (not installed)                   |  |
|  |                                                              |  |
|  |  [Install Missing] [Continue]                              |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Step 3: Provider Selection                                      |
|  +------------------------------------------------------------+  |
|  |  Default Provider:                                          |  |
|  |                                                              |  |
|  |  ( ) Anthropic (Claude Code)                               |  |
|  |  ( ) Google (Gemini CLI)                                   |  |
|  |  ( ) OpenAI (Codex CLI)                                    |  |
|  |                                                              |  |
|  |  [Continue]                                                 |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Step 4: Directory Selection                                     |
|  +------------------------------------------------------------+  |
|  |  Where do you keep your projects?                           |  |
|  |                                                              |  |
|  |  [~/Projects]  [Browse...]                                  |  |
|  |                                                              |  |
|  |  [Finish Setup]                                             |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### Your First Session

```bash
# 1. Launch Blaze
open /Applications/Blaze.app

# 2. Add a project (Cmd+Shift+N or click +)
# Select your project directory

# 3. Create new session (Cmd+N)
# Choose engine: Claude Code
# Name: "Fix authentication bug"

# 4. Send your first prompt
# "Look at the auth flow in src/auth/ and identify why
#  login fails when the session token expires."

# 5. Watch the magic
# - Tool cards appear for each operation
# - Diffs show with Accept/Reject buttons
# - Streaming text renders at 60fps
```

---

## Feature Tour

### 6.1 Multi-Engine Orchestration

Blaze provides a unified interface for multiple AI coding CLIs.

```
+------------------------------------------------------------------+
|                   MULTI-ENGINE ARCHITECTURE                       |
+------------------------------------------------------------------+
|                                                                   |
|                      +------------------+                         |
|                      |    Blaze UI      |                         |
|                      +--------+---------+                         |
|                               |                                   |
|                      +--------v---------+                         |
|                      | SessionOrchestrator |                      |
|                      +--------+---------+                         |
|                               |                                   |
|        +----------------------+----------------------+            |
|        |                      |                      |            |
|  +-----v------+        +------v-----+        +------v-----+      |
|  |  Claude    |        |  Gemini    |        |  Codex     |      |
|  |  Adapter   |        |  Adapter   |        |  Adapter   |      |
|  +-----+------+        +------+-----+        +------+-----+      |
|        |                      |                      |            |
|        v                      v                      v            |
|   claude -p ...          gemini -p ...         codex exec ...    |
|                                                                   |
+------------------------------------------------------------------+
```

**Supported Providers:**

| Provider | CLI | Model Tiers | Status |
|----------|-----|-------------|--------|
| **Anthropic** | Claude Code | Flagship: Opus 4, Opus 4.5<br>Standard: Sonnet 4, 3.5<br>Speed: Haiku 3.5 | Supported |
| **Google** | Gemini CLI | Flagship: Gemini Ultra<br>Standard: Gemini Pro<br>Speed: Gemini Flash | Supported |
| **OpenAI** | Codex CLI | Flagship: o1, o3<br>Standard: GPT-4, GPT-4.5<br>Speed: o3-mini | Planned |

**Key Features:**

- Unified NormalizedEvent schema across all providers
- Provider-aware model selection with tier groupings
- Reasoning effort control (Low/Medium/High)
- Extended thinking support for Claude models
- CLI authentication delegation to vendor login flows

### 6.2 Provider-Aware Model Selection

```
+------------------------------------------------------------------+
|                    MODEL SELECTION UI                             |
+------------------------------------------------------------------+
|                                                                   |
|  Provider: [Anthropic v]                                         |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | FLAGSHIP                                                     |  |
|  |   (*) Claude Opus 4.5     - Best reasoning, highest cost   |  |
|  |   ( ) Claude Opus 4       - Advanced reasoning             |  |
|  +------------------------------------------------------------+  |
|  | STANDARD                                                     |  |
|  |   ( ) Claude Sonnet 4     - Balanced performance           |  |
|  |   ( ) Claude Sonnet 3.5   - Good for most tasks            |  |
|  +------------------------------------------------------------+  |
|  | SPEED                                                        |  |
|  |   ( ) Claude Haiku 3.5    - Fast, cost-effective           |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Reasoning Effort: [Low] [Medium] [High]                        |
|                                                                   |
|  Extended Thinking: [x] Enable (Opus models only)               |
|                                                                   |
+------------------------------------------------------------------+
```

### 6.3 Session Management

Sessions are the core unit of work in Blaze. Each session represents a conversation with an AI agent.

**Session States:**

| State | Description | Visual |
|-------|-------------|--------|
| Creating | Session initializing | Spinner |
| Ready | Waiting for input | Green dot |
| Running | Agent processing | Pulsing blue |
| Stopped | User paused | Orange dot |
| Errored | Error occurred | Red dot |
| Archived | Completed/stored | Gray dot |

**Session Features:**

```
+------------------------------------------------------------------+
|                    SESSION MANAGEMENT                             |
+------------------------------------------------------------------+
|                                                                   |
|  Session List                    Session Actions                 |
|  +--------------------------+    +---------------------------+   |
|  | > Fix auth bug    [Claude]|    | [Resume] [Fork] [Export] |   |
|  |   API refactor   [Gemini]|    | [Archive] [Delete]       |   |
|  |   Write tests    [Claude]|    +---------------------------+   |
|  |   + New Session          |                                    |
|  +--------------------------+    Export Formats:                 |
|                                  - JSON (full data)              |
|  Search: [____________]          - Markdown (readable)           |
|                                  - HTML (shareable)              |
|  Filter: [All v]                                                 |
|    - All Sessions                                                |
|    - Active                                                      |
|    - Archived                                                    |
|    - By Provider                                                 |
|                                                                   |
+------------------------------------------------------------------+
```

**Session Branching:**

Fork any session at any point to explore alternatives:

```
Session: Fix auth bug
    |
    +-- Turn 1: "Look at auth flow"
    |
    +-- Turn 2: "Found token issue"
    |       |
    |       +-- [Fork] --> "Try approach A"
    |       |
    |       +-- [Fork] --> "Try approach B"
    |
    +-- Turn 3: Continue with original
```

### 6.4 Chat Interface

The chat interface is optimized for code-heavy conversations.

```
+------------------------------------------------------------------+
|                      CHAT INTERFACE                               |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Fix authentication bug                    [Claude Sonnet] |  |
|  +------------------------------------------------------------+  |
|  |                                                              |  |
|  |  10:30 AM  YOU                                              |  |
|  |  +--------------------------------------------------------+ |  |
|  |  | Fix the auth bug in src/auth/. The login fails when    | |  |
|  |  | the session token expires.                              | |  |
|  |  |                                                          | |  |
|  |  | @src/auth/login.ts  @src/auth/session.ts               | |  |
|  |  +--------------------------------------------------------+ |  |
|  |                                                              |  |
|  |  10:30 AM  CLAUDE                                           |  |
|  |  +--------------------------------------------------------+ |  |
|  |  | I'll analyze the authentication flow...                 | |  |
|  |  |                                                          | |  |
|  |  | +----------------------------------------------------+ | |  |
|  |  | | > Thinking...                                 2.3s | | |  |
|  |  | | The token refresh logic appears to be missing a   | | |  |
|  |  | | check for token validity before making API calls. | | |  |
|  |  | +----------------------------------------------------+ | |  |
|  |  |                                                          | |  |
|  |  | Based on my analysis...                                 | |  |
|  |  +--------------------------------------------------------+ |  |
|  |                                                              |  |
|  +------------------------------------------------------------+  |
|  | @mentions | Model: [Sonnet v] | Effort: [Med]  | [Send]    |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

**Chat Features:**

| Feature | Description |
|---------|-------------|
| **Message Bubbles** | Role-based styling (user/assistant) |
| **60fps Streaming** | Token-by-token with auto-scroll |
| **Markdown Rendering** | Full markdown with syntax highlighting |
| **Thinking Disclosure** | Collapsible extended thinking sections |
| **Copy on Hover** | One-click copy for any message |
| **Multi-line Input** | Expandable input area |
| **@ File Mentions** | Autocomplete files and folders |
| **File Pills** | Selected files shown as chips |
| **Model Selector** | Change model mid-session |
| **Reasoning Effort** | Adjust per message |

### 6.5 Tool Execution Display

Every tool call renders as an interactive card.

```
+------------------------------------------------------------------+
|                    TOOL CALL CARDS                                |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [v] Read                                            1.2s   |  |
|  |     src/auth/login.ts                                       |  |
|  |     245 lines                                    [Expand]  |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [>] Bash                                         Running   |  |
|  |     npm test -- --grep "auth"                              |  |
|  |     [===========>                    ] 12s elapsed         |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [x] Write                                         Failed   |  |
|  |     /etc/passwd                                             |  |
|  |     Error: Permission denied                    [Retry]    |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [?] AskUserQuestion                              Pending   |  |
|  |                                                              |  |
|  |  Which approach do you prefer?                              |  |
|  |                                                              |  |
|  |  ( ) Quick Implementation - Fast but minimal               |  |
|  |  (*) Thorough Implementation - Full coverage               |  |
|  |  ( ) Iterative Approach - Start simple                     |  |
|  |                                                              |  |
|  |                                            [Submit]         |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

**Tool Status Indicators:**

| Status | Icon | Description |
|--------|------|-------------|
| Pending | `[ ]` | Waiting to execute |
| Running | `[>]` | Currently executing |
| Succeeded | `[v]` | Completed successfully |
| Failed | `[x]` | Error occurred |
| Rejected | `[-]` | User denied |
| Cancelled | `[o]` | User cancelled |

**Tool Card Actions:**

- **Expand/Collapse**: Show/hide input and output
- **Copy**: Copy tool input or output
- **Rerun**: Execute the tool again
- **Explain**: Ask AI to explain what this tool does

### 6.6 Subagent Display

When the main agent spawns subagents for parallel work, Blaze displays them clearly.

```
+------------------------------------------------------------------+
|                    SUBAGENT BLOCKS                                |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  | Subagent: research-docs                                     |  |
|  | Status: Running                                              |  |
|  | Task: "Research React 18 concurrent features"               |  |
|  |                                                              |  |
|  | Token Usage:                                                 |  |
|  | [=================>                    ] 45,230 / 100,000   |  |
|  |                                                              |  |
|  | Progress: Searching documentation...                        |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | Subagent: write-tests                                       |  |
|  | Status: Completed                                           |  |
|  | Task: "Write unit tests for auth module"                    |  |
|  |                                                              |  |
|  | Token Usage:                                                 |  |
|  | [========================================] 23,456 / 50,000  |  |
|  |                                                              |  |
|  | Result: Created 12 test files                     [Expand]  |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

**Subagent States:**

| State | Description |
|-------|-------------|
| Queued | Waiting to start |
| Running | Currently processing |
| Completed | Finished successfully |
| Failed | Error occurred |
| Cancelled | Terminated by user or parent |

### 6.7 File Tree and Navigation

A virtualized file tree with advanced features.

```
+------------------------------------------------------------------+
|                      FILE TREE                                    |
+------------------------------------------------------------------+
|                                                                   |
|  Search: [auth____________]                    [Sort: Name v]    |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | v my-project/                                               |  |
|  |   v src/                                                    |  |
|  |     v auth/                                                 |  |
|  |       [ts] login.ts                           Modified     |  |
|  |       [ts] session.ts                                       |  |
|  |       [ts] refresh.ts                         New          |  |
|  |     > components/                                           |  |
|  |     > utils/                                                |  |
|  |   v tests/                                                  |  |
|  |     [ts] auth.test.ts                                       |  |
|  |   [json] package.json                                       |  |
|  |   [md] README.md                                            |  |
|  |   [->] node_modules/                          (symlink)    |  |
|  |   [.] .env                                    (hidden)     |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Right-click menu:                                               |
|  +------------------------+                                      |
|  | Open                   |                                      |
|  | Open in Editor         |                                      |
|  | Reveal in Finder       |                                      |
|  | Copy Path              |                                      |
|  | Copy Relative Path     |                                      |
|  | Insert as @reference   |                                      |
|  +------------------------+                                      |
|                                                                   |
+------------------------------------------------------------------+
```

**File Tree Features:**

| Feature | Description |
|---------|-------------|
| **Virtualized** | Handles large directories efficiently |
| **Lazy Loading** | Loads subdirectories on demand |
| **Single Click** | Preview file (temporary tab) |
| **Double Click** | Open file (persistent tab) |
| **Drag to Chat** | Insert @file:path reference |
| **Sort Options** | Name, date, size, extension |
| **Language Icons** | Color-coded by file type |
| **Hidden Files** | Visible but dimmed |
| **Symlink Indicators** | Shows link status |

### 6.8 Diff Viewer

PR-style diff viewing with accept/reject workflow.

```
+------------------------------------------------------------------+
|                      DIFF VIEWER                                  |
+------------------------------------------------------------------+
|                                                                   |
|  src/auth/login.ts                              +12 -5          |
|  +------------------------------------------------------------+  |
|  | @@ -45,8 +45,15 @@ export async function login(creds) {    |  |
|  |                                                              |  |
|  |  45 |  45 |   const token = await fetchToken(creds);       |  |
|  |  46 |     | - if (!token) return null;                     |  |
|  |     |  46 | + if (!token) {                                |  |
|  |     |  47 | +   logger.warn('Token fetch failed');         |  |
|  |     |  48 | +   return { error: 'AUTH_FAILED' };           |  |
|  |     |  49 | + }                                            |  |
|  |  47 |  50 |                                                 |  |
|  |  48 |     | - return { user: decode(token) };              |  |
|  |     |  51 | + const decoded = decode(token);               |  |
|  |     |  52 | + if (isExpired(decoded)) {                    |  |
|  |     |  53 | +   const refreshed = await refresh(token);    |  |
|  |     |  54 | +   return { user: decode(refreshed) };        |  |
|  |     |  55 | + }                                            |  |
|  |     |  56 | + return { user: decoded };                    |  |
|  |  49 |  57 | }                                              |  |
|  |                                                              |  |
|  +------------------------------------------------------------+  |
|  | Hunk 1 of 2        [Accept Hunk] [Reject Hunk] [Edit]      |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Decision: [Pending]     [Accept All] [Reject All] [Edit File] |  |
|                                                                   |
+------------------------------------------------------------------+
```

**Diff Viewer Features:**

| Feature | Description |
|---------|-------------|
| **Unified View** | Standard unified diff format |
| **Split View** | Side-by-side comparison |
| **Line Numbers** | Old and new gutters |
| **Syntax Highlighting** | Language-aware coloring |
| **Addition/Deletion Colors** | Green/red highlighting |
| **Per-File Actions** | Accept/Reject entire file |
| **Per-Hunk Actions** | Accept/Reject individual hunks |
| **Decision Badges** | Pending, Accepted, Rejected, Modified |
| **Large Diff Warning** | "Show All" for big diffs |
| **Stats Badges** | +N additions, -N deletions |

### 6.9 Security and Trust Modes

Four trust levels control agent permissions.

```
+------------------------------------------------------------------+
|                   TRUST MODE SPECTRUM                             |
+------------------------------------------------------------------+
|                                                                   |
|   SANDBOX          REVIEW           TRUSTED          YOLO        |
|   (Locked)        (Default)        (Expert)       (Dangerous)   |
|      |               |                |               |          |
|      v               v                v               v          |
|   +-------+      +-------+       +-------+       +-------+      |
|   |       |      |       |       |       |       |       |      |
|   | Read  |      | Ask   |       | Trust |       | Auto  |      |
|   | Only  |      | First |       | User  |       | Allow |      |
|   |       |      |       |       |       |       |       |      |
|   +-------+      +-------+       +-------+       +-------+      |
|                                                                   |
|   - No writes    - All approvals  - Minimal gates - No gates    |
|   - Safe tools   - Diff preview   - Remember      - Full auto   |
|   - Read only    - Audit log      - preferences   - Risky!      |
|                                                                   |
+------------------------------------------------------------------+
```

**Trust Mode Details:**

| Mode | File Writes | Shell Commands | Network | Best For |
|------|-------------|----------------|---------|----------|
| **Sandbox** | Blocked | Safe only (ls, git status) | Blocked | Exploration |
| **Review** | Requires approval | Requires approval | Logged | Daily dev |
| **Trusted** | Allowed in project | Most allowed | Allowed | Power users |
| **YOLO** | All allowed | All allowed | All | Testing only |

### 6.10 Tool Approval System

Visual approval workflow with risk indicators.

```
+------------------------------------------------------------------+
|                   APPROVAL QUEUE                                  |
+------------------------------------------------------------------+
|                                                                   |
|  Pending Approvals (3)                                           |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [HIGH RISK] Bash                                            |  |
|  | rm -rf ./build/                                              |  |
|  |                                                              |  |
|  | This will delete 147 files in the build directory.         |  |
|  |                                                              |  |
|  | [Deny] [Allow Once] [Allow & Trust Bash]                   |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [MEDIUM RISK] Write                                         |  |
|  | src/auth/login.ts                                           |  |
|  |                                                              |  |
|  | +12 lines, -5 lines                        [Preview Diff]  |  |
|  |                                                              |  |
|  | [Deny] [Allow Once] [Allow Similar]                        |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  | [LOW RISK] Read                                             |  |
|  | package.json                                                 |  |
|  |                                                              |  |
|  | [Deny] [Allow Once] [Always Allow Read]                    |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

**Risk Levels:**

| Level | Color | Examples |
|-------|-------|----------|
| Low | Green | Read, Glob, Grep |
| Medium | Yellow | Write, Edit (in project) |
| High | Red | Bash, Write (outside project) |
| Critical | Purple | rm -rf, git push --force |

### 6.11 Command Allowlist

Granular control over shell commands.

```
+------------------------------------------------------------------+
|                  COMMAND ALLOWLIST                                |
+------------------------------------------------------------------+
|                                                                   |
|  Standard Commands                                               |
|  +------------------------------------------------------------+  |
|  | Command    | Description              | Permission         |  |
|  |------------|--------------------------|-------------------|  |
|  | ls         | List directory           | [x] Read          |  |
|  | cat        | Display file             | [x] Read          |  |
|  | grep       | Search patterns          | [x] Read          |  |
|  | git status | Show git status          | [x] Read          |  |
|  | git diff   | Show changes             | [x] Read          |  |
|  | mkdir      | Create directory         | [ ] Read+Write    |  |
|  | rm         | Remove files             | [ ] Read+Write    |  |
|  | git commit | Commit changes           | [ ] Read+Write    |  |
|  | git push   | Push to remote           | [ ] Read+Write    |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  Auto-Approve Patterns                                           |
|  +------------------------------------------------------------+  |
|  | *.swift     - All Swift files                              |  |
|  | src/*       - Files in src/ directory                      |  |
|  | **/*.ts     - TypeScript files anywhere                    |  |
|  | tests/**/*  - Anything in tests folder                     |  |
|  |                                                              |  |
|  | [Add Pattern]                                               |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### 6.12 Design System and Theming

Comprehensive theming with 6 built-in themes and full customization.

```
+------------------------------------------------------------------+
|                   THEME SYSTEM                                    |
+------------------------------------------------------------------+
|                                                                   |
|  Built-in Themes:                                                |
|                                                                   |
|  +----------+  +----------+  +----------+                        |
|  |  NEBULA  |  | OBSIDIAN |  |  AURORA  |                        |
|  |  Deep    |  |  Pure    |  |  Cyan/   |                        |
|  |  Blue    |  |  Dark    |  |  Teal    |                        |
|  +----------+  +----------+  +----------+                        |
|                                                                   |
|  +----------+  +----------+  +----------+                        |
|  | SUNRISE  |  |  MONO-   |  | HYPERION |                        |
|  |  Warm    |  |  CHROME  |  |  Deep    |                        |
|  |  Orange  |  |  Gray    |  |  Purple  |                        |
|  +----------+  +----------+  +----------+                        |
|                                                                   |
|  Glass Levels:                                                   |
|  [Subtle] [Light] [Regular] [Prominent] [Solid]                 |
|                                                                   |
|  Blur Intensity: [=========>        ] 24px                      |
|                                                                   |
|  Accent Colors:                                                  |
|  [Blue] [Purple] [Pink] [Red] [Orange]                          |
|  [Yellow] [Green] [Mint] [Teal] [Custom]                        |
|                                                                   |
+------------------------------------------------------------------+
```

**Theme Properties:**

| Property | Description |
|----------|-------------|
| `background` | Deepest layer |
| `surface` | Card backgrounds |
| `surfaceHover` | Interactive states |
| `accent` | Primary brand color |
| `accentHover` | Hover states |
| `textPrimary` | Main text |
| `textSecondary` | Subtitles, labels |
| `textMuted` | Tertiary text |
| `border` | Separators, outlines |
| `success` | Positive states |
| `warning` | Caution indicators |
| `error` | Error states |

### 6.13 Terminal Integration

Full terminal emulation for interactive commands.

```
+------------------------------------------------------------------+
|                  TERMINAL INTEGRATION                             |
+------------------------------------------------------------------+
|                                                                   |
|  Terminal Tabs:                                                  |
|  +------------------------------------------------------------+  |
|  | [Claude #1] [Claude #2] [User Terminal] [+]                |  |
|  +------------------------------------------------------------+  |
|  |                                                              |  |
|  | $ npm test -- --grep "auth"                                 |  |
|  |                                                              |  |
|  | PASS  tests/auth.test.ts                                    |  |
|  |   Authentication                                            |  |
|  |     v should login with valid credentials (45ms)           |  |
|  |     v should reject invalid credentials (12ms)              |  |
|  |     v should refresh expired tokens (89ms)                 |  |
|  |                                                              |  |
|  | Test Suites: 1 passed, 1 total                              |  |
|  | Tests:       3 passed, 3 total                              |  |
|  | Time:        1.234s                                         |  |
|  |                                                              |  |
|  | $                                                            |  |
|  |                                                              |  |
|  +------------------------------------------------------------+  |
|  | [Export] [Clear] [Kill Process]                            |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

**Terminal Features:**

| Feature | Description |
|---------|-------------|
| **User Terminals** | Your own interactive shells |
| **Claude Terminals** | Agent-spawned processes |
| **Tab Management** | Multiple terminals in tabs |
| **Scrollback Buffer** | Full history |
| **Export Output** | Save terminal content |
| **Auto-Show** | Opens for foreground commands |
| **Ghostty Backend** | Fast, native rendering |
| **SwiftTerm Backend** | Fallback emulation |
| **Full PTY** | Complete terminal emulation |

### 6.14 Hooks System

Event-driven automation for AI sessions.

```
+------------------------------------------------------------------+
|                     HOOK EVENTS                                   |
+------------------------------------------------------------------+
|                                                                   |
|  EVENT LIFECYCLE:                                                |
|                                                                   |
|  SessionStart ----+                                              |
|                   |                                               |
|                   v                                               |
|  UserPromptSubmit ---> PreToolUse ---> [Tool Executes]           |
|                              |                |                   |
|                              v                v                   |
|                         (can block)     PostToolUse               |
|                                               |                   |
|                                               v                   |
|                   +------ PreCompact <--------+                  |
|                   |                                               |
|                   v                                               |
|  Stop <-----------+                                              |
|                                                                   |
+------------------------------------------------------------------+
```

**Hook Event Reference:**

| Event | When | Can Block | Common Uses |
|-------|------|-----------|-------------|
| `PreToolUse` | Before tool executes | Yes | Block dangerous ops |
| `PostToolUse` | After tool completes | No | Log, validate |
| `UserPromptSubmit` | Before processing prompt | Yes | Sanitize, inject |
| `PreCompact` | Before context compaction | No | Save state |
| `SessionStart` | Session begins/resumes | No | Load context |
| `Stop` | Agent finishes turn | Yes | Enforce DoD |

### 6.15 Visual Hooks Builder

The flagship feature: drag-and-drop hook creation.

```
+------------------------------------------------------------------+
|                  VISUAL HOOKS BUILDER                             |
+------------------------------------------------------------------+
|                                                                   |
|  +--------+  +----------------------------------------+  +------+ |
|  | Nodes  |  |              CANVAS                    |  |Props | |
|  +--------+  +----------------------------------------+  +------+ |
|  |        |  |                                        |  |      | |
|  | Events |  |  +------------+     +------------+    |  |Filter| |
|  | o Pre  |  |  |PreToolUse |---->| Tool=Bash  |    |  |      | |
|  | o Post |  |  | Trigger   |     +-----+------+    |  |Tool: | |
|  | o Start|  |  +------------+          |           |  |[Bash]| |
|  |        |  |                          v           |  |      | |
|  |Filters |  |                    +------------+    |  |Match:| |
|  | o Tool |  |  +------------+<---| rm -rf ?   |    |  |[Regex| |
|  | o Path |  |  | Continue   |    +-----+------+    |  |      | |
|  | o Regex|  |  +------------+          | Yes       |  |      | |
|  |        |  |                          v           |  |      | |
|  |Actions |  |                    +------------+    |  |      | |
|  | o Block|  |                    |   Block    |    |  |      | |
|  | o Log  |  |                    | "Dangerous"|    |  |      | |
|  | o Cmd  |  |                    +------------+    |  |      | |
|  | o Notify|  |                                      |  |      | |
|  +--------+  +----------------------------------------+  +------+ |
|                                                                   |
|  [Test Workflow]  [Export JSON]  [Save]  [Templates v]          |
|                                                                   |
+------------------------------------------------------------------+
```

**Hook Node Types:**

| Category | Nodes | Purpose |
|----------|-------|---------|
| **Events** | PreToolUse, PostToolUse, SessionStart, PreCompact, Stop | Triggers |
| **Filters** | Tool Match, Path Pattern, Content Match, Regex | Conditions |
| **Actions** | Block, Continue, Run Command, Log, Notify, Modify | Effects |
| **Outputs** | System Message, User Notification, File Write | Results |

**22 Built-in Templates:**

- Security: Block destructive, detect secrets, sandbox enforcement
- Productivity: Auto-index, log tools, session continuity
- Integration: Slack, webhooks, custom MCP routing
- Debugging: Trace calls, capture timing, breakpoints

### 6.16 Sidebar Panels

15+ sidebar panels for different workflows.

```
+------------------------------------------------------------------+
|                   SIDEBAR PANELS                                  |
+------------------------------------------------------------------+
|                                                                   |
|  Panel           | Description                                   |
|  ----------------|-----------------------------------------------|
|  Sessions        | Session list, search, filter                  |
|  Files           | Virtualized file tree                         |
|  Git             | Status, branches, stash                       |
|  Subagents       | Active subagent status                        |
|  Approvals       | Pending approval queue                        |
|  Agents          | Agent definitions, config                     |
|  Timeline        | Recent activity stream                        |
|  Context         | Current context window                        |
|  Tokens          | Usage, costs, budget                          |
|  Bookmarks       | Saved messages, files                         |
|  Search          | Full-text search                              |
|  Prompts         | Prompt templates                              |
|  Tools           | Available tools reference                     |
|  Logs            | Debug logs, errors                            |
|  MCP             | MCP server status                             |
|  Hooks           | Hook status, debug                            |
|  Settings        | Quick settings access                         |
|                                                                   |
+------------------------------------------------------------------+
```

### 6.17 Onboarding Flow

Guided first-run experience.

```
+------------------------------------------------------------------+
|                   ONBOARDING STEPS                                |
+------------------------------------------------------------------+
|                                                                   |
|  Step 1: Welcome Screen                                          |
|  - Introduction to Blaze                                         |
|  - Key features overview                                         |
|                                                                   |
|  Step 2: CLI Detection                                           |
|  - Auto-detect Claude, Gemini, Codex                            |
|  - Show installation status                                      |
|  - Guide CLI installation if missing                            |
|                                                                   |
|  Step 3: CLI Installation (if needed)                           |
|  - npm install commands                                          |
|  - Verification steps                                            |
|                                                                   |
|  Step 4: Provider Selection                                      |
|  - Choose default provider                                       |
|  - Configure auth if needed                                      |
|                                                                   |
|  Step 5: Plugin/Skill Selection                                  |
|  - Enable recommended skills                                     |
|  - Custom skill installation                                     |
|                                                                   |
|  Step 6: Directory Source                                        |
|  - Set default projects directory                               |
|  - Import existing projects                                      |
|                                                                   |
|  Step 7: Completion                                              |
|  - Quick start tips                                              |
|  - Link to documentation                                         |
|                                                                   |
+------------------------------------------------------------------+
```

### 6.18 Git Integration and Worktrees

Worktree-per-task isolation for parallel development.

```
+------------------------------------------------------------------+
|                  GIT WORKTREES                                    |
+------------------------------------------------------------------+
|                                                                   |
|  PROJECT STRUCTURE:                                              |
|                                                                   |
|  my-project/                         (Main worktree)             |
|  +-- .git/                           Shared Git data             |
|  +-- .blaze-worktrees/                                           |
|  |   +-- abc12345-session-1/         Claude: auth feature       |
|  |   |   +-- (full checkout)                                     |
|  |   |   +-- .blaze-session/         Session state              |
|  |   |                                                           |
|  |   +-- def67890-session-2/         Codex: query optimization  |
|  |   |   +-- (full checkout)                                     |
|  |   |   +-- .blaze-session/                                     |
|  |   |                                                           |
|  |   +-- ghi11111-session-3/         Claude: write tests        |
|  |       +-- (full checkout)                                     |
|  |       +-- .blaze-session/                                     |
|  |                                                                |
|  +-- src/                            main branch files           |
|  +-- .blaze/                         Project config              |
|                                                                   |
+------------------------------------------------------------------+
|                                                                   |
|  BRANCH NAMING: blaze-session-{short-uuid}                       |
|  ORPHAN DETECTION: Auto-cleanup abandoned worktrees              |
|  PARALLEL SESSIONS: Run multiple agents simultaneously           |
|                                                                   |
+------------------------------------------------------------------+
```

**Worktree Benefits:**

| Benefit | Description |
|---------|-------------|
| **Isolation** | Each agent has its own working directory |
| **No Conflicts** | Changes don't interfere until merge |
| **Parallel Work** | Multiple features simultaneously |
| **Easy Cleanup** | Delete worktree, delete branch |
| **Context Separation** | Each session maintains own state |

---

## Settings Reference

Blaze has 13 settings categories accessible via `Cmd+,` or **Blaze > Settings**.

For full documentation, visit [https://getblaze.dev/docs/](https://getblaze.dev/docs/)

### 7.1 Appearance Settings

| Setting | Options | Default |
|---------|---------|---------|
| Theme | Nebula, Obsidian, Aurora, Sunrise, Monochrome, Hyperion | Nebula |
| Glass Level | Subtle, Light, Regular, Prominent, Solid | Regular |
| Blur Intensity | 8-40px | 24px |
| Accent Color | Blue, Purple, Pink, Red, Orange, Yellow, Green, Mint, Teal, Custom | Blue |
| Border Style | None, Subtle, Standard, Layered, Gradient | Subtle |
| Window Transparency | 0-100% | 95% |

### 7.2 Chat and Input Settings

| Setting | Options | Default |
|---------|---------|---------|
| Message Style | Bubbles, Minimal, Compact | Bubbles |
| Timestamp Format | Relative, Absolute | Relative |
| Code Font | SF Mono, JetBrains Mono, Fira Code, Menlo | SF Mono |
| Code Font Size | 10-20pt | 12pt |
| Enable Ligatures | On/Off | On |
| Auto-scroll | On/Off | On |
| Show Thinking | Always, On Expand, Never | On Expand |

### 7.3 Models Settings

| Setting | Options | Default |
|---------|---------|---------|
| Default Provider | Anthropic, Google, OpenAI | Anthropic |
| Default Model | (per provider) | Sonnet 4 |
| Reasoning Effort | Low, Medium, High | Medium |
| Extended Thinking | On/Off | Off |
| Max Tokens | 1K-200K | 8K |

### 7.4 Security and Trust Settings

| Setting | Options | Default |
|---------|---------|---------|
| Trust Mode | Sandbox, Review, Trusted, YOLO | Review |
| Auto-approve Patterns | Glob patterns | (empty) |
| Blocked Patterns | Glob patterns | rm -rf /, etc. |
| Require Approval | Tool list | Bash, Write |
| Audit Logging | On/Off | On |

### 7.5 Engines Settings

| Setting | Options | Default |
|---------|---------|---------|
| Claude Code Path | File path | /usr/local/bin/claude |
| Gemini CLI Path | File path | /usr/local/bin/gemini |
| Codex CLI Path | File path | /usr/local/bin/codex |
| Default Engine | Claude, Gemini, Codex | Claude |
| Environment Variables | Key-value pairs | (from shell) |

### 7.6 Terminal Settings

| Setting | Options | Default |
|---------|---------|---------|
| Shell | /bin/bash, /bin/zsh, custom | /bin/zsh |
| Scrollback Lines | 1K-100K | 10K |
| Auto-show Terminal | On/Off | On |
| Terminal Font | (same as code fonts) | SF Mono |
| Terminal Font Size | 10-20pt | 12pt |

### 7.7 Agents Settings

| Setting | Options | Default |
|---------|---------|---------|
| Max Concurrent Agents | 1-100 | 10 |
| Max Total Agents | 1-500 | 100 |
| Agent Timeout | 30s-30min | 5min |
| Auto-throttle | On/Off | On |
| Memory Limit | 256MB-4GB | 1GB |

### 7.8 Files and Editor Settings

| Setting | Options | Default |
|---------|---------|---------|
| Default Tab Mode | Preview, Persistent | Preview |
| Show Hidden Files | On/Off | On (dimmed) |
| File Sort | Name, Date, Size, Extension | Name |
| External Editor | VS Code, Xcode, Custom | VS Code |
| Auto-save | On/Off | On |

### 7.9 Notifications Settings

| Setting | Options | Default |
|---------|---------|---------|
| Desktop Notifications | On/Off | On |
| Sound | On/Off | Off |
| Notify on Complete | On/Off | On |
| Notify on Error | On/Off | On |
| Notify on Approval | On/Off | On |

### 7.10 CLI Power Settings

| Setting | Options | Default |
|---------|---------|---------|
| Custom CLI Flags | Text | (empty) |
| Environment Overrides | Key-value | (empty) |
| Working Directory | Path | Project root |
| Shell Profile | .bashrc, .zshrc, custom | .zshrc |

### 7.11 Memory and Context Settings

| Setting | Options | Default |
|---------|---------|---------|
| Auto-compact | On/Off | On |
| Compact Threshold | 50-95% | 80% |
| Preserve Recent | 5-50 messages | 20 |
| Context Window | 8K-200K | 100K |

### 7.12 Git Settings

| Setting | Options | Default |
|---------|---------|---------|
| Auto-create Worktree | On/Off | Off |
| Worktree Location | In-repo, External | In-repo |
| Branch Prefix | Text | blaze-session- |
| Auto-cleanup Orphans | On/Off | On |

### 7.13 Shortcuts Settings

| Action | Default | Customizable |
|--------|---------|--------------|
| New Session | Cmd+N | Yes |
| Send Message | Cmd+Enter | Yes |
| Stop Generation | Cmd+. | Yes |
| Accept All Diffs | Cmd+Shift+A | Yes |
| Toggle Sidebar | Cmd+\ | Yes |
| Command Palette | Cmd+K | Yes |

---

## Architecture

### System Overview

```
+------------------------------------------------------------------+
|                    BLAZE SYSTEM ARCHITECTURE                      |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  |                    macOS App (SwiftUI)                      |  |
|  |                                                              |  |
|  |  +------------------+  +------------------+  +-----------+  |  |
|  |  |    GUI Layer     |  |  Orchestration   |  |  Storage  |  |  |
|  |  |    (SwiftUI)     |  |     Layer        |  |   Layer   |  |  |
|  |  +--------+---------+  +--------+---------+  +-----+-----+  |  |
|  |           |                     |                  |        |  |
|  |  - Chat Timeline         - SessionStore      - SQLite      |  |
|  |  - Tool Cards            - EngineManager     - JSONL       |  |
|  |  - Diff Viewer           - HookRunner        - Keychain    |  |
|  |  - Settings UI           - PolicyEngine      - UserDefs    |  |
|  |  - Command Palette       - ProcessRunner                    |  |
|  |  - File Tree             - SubagentPool                     |  |
|  |                                                              |  |
|  +---------------------------+----------------------------------+  |
|                              |                                    |
|                              | spawn child process / pipes        |
|                              v                                    |
|  +------------------------------------------------------------+  |
|  |                 Provider CLIs (unmodified)                  |  |
|  |                                                              |  |
|  |  +----------------+  +----------------+  +----------------+  |  |
|  |  | ClaudeAdapter  |  | GeminiAdapter  |  | CodexAdapter   |  |  |
|  |  +----------------+  +----------------+  +----------------+  |  |
|  |                                                              |  |
|  +---------------------------+----------------------------------+  |
|                              |                                    |
|                              | HTTPS (CLI handles auth)          |
|                              v                                    |
|  +------------------------------------------------------------+  |
|  |                    AI Provider APIs                         |  |
|  |                                                              |  |
|  |        Anthropic  |  Google AI  |  OpenAI                   |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### Component Architecture

```
+------------------------------------------------------------------+
|                   COMPONENT BREAKDOWN                             |
+------------------------------------------------------------------+
|                                                                   |
|  CORE COMPONENTS                                                 |
|  +------------------------------------------------------------+  |
|  | EngineAdapter    | Protocol for CLI invocation, streaming   |  |
|  | NormalizedEvent  | Unified event schema across providers    |  |
|  | SessionStore     | SQLite + JSONL crash-safe persistence   |  |
|  | HookRunner       | Event-triggered automation               |  |
|  | ProcessRunner    | Child process management                 |  |
|  | PolicyEngine     | Permission enforcement                   |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  DATA COMPONENTS (11 total)                                      |
|  +------------------------------------------------------------+  |
|  | SessionStore     | Branching via parentId/branchPoint       |  |
|  | EventStore       | Sequence numbers, toolUseId correlation  |  |
|  | TokenStore       | Cache metrics, cost calc, budget alerts  |  |
|  | HookStore        | 12 event types, repo-scoped hooks        |  |
|  | NDJSONLogger     | Dual-write for crash safety              |  |
|  | BackupManager    | SHA256 checksums, atomic restore         |  |
|  | PromptStore      | Template management                      |  |
|  | BookmarkStore    | Saved items                              |  |
|  | LogStore         | Debug logs                               |  |
|  | HookExecStore    | Hook execution history                   |  |
|  | ToolApprovalStore| Approval decisions                       |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  UI COMPONENTS                                                   |
|  +------------------------------------------------------------+  |
|  | DesignSystem     | Shared UI, colors, typography            |  |
|  | ChatTimeline     | Message rendering                        |  |
|  | ToolCardView     | Tool call display                        |  |
|  | DiffViewer       | PR-style diff viewing                    |  |
|  | FileTreeView     | Virtualized file browser                 |  |
|  | HooksBuilder     | Visual workflow editor                   |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### Event Pipeline

```
+------------------------------------------------------------------+
|                    EVENT PIPELINE                                 |
+------------------------------------------------------------------+
|                                                                   |
|  CLI stdout (NDJSON)                                             |
|       |                                                          |
|       v                                                          |
|  EngineAdapter.parseEvent()                                      |
|       |                                                          |
|       v                                                          |
|  NormalizedEvent (unified type)                                  |
|       |                                                          |
|       +---> PreHooks (can block/modify)                         |
|       |          |                                               |
|       |          v                                               |
|       |    HookRunner.executePreHooks()                         |
|       |          |                                               |
|       |          +---> Block? --> Return error                  |
|       |          |                                               |
|       |          +---> Modify? --> Update event                 |
|       |                                                          |
|       v                                                          |
|  EventEnvelope (sequenced, timestamped)                         |
|       |                                                          |
|       v                                                          |
|  EventStore (SQLite persistence)                                 |
|       |                                                          |
|       +---> NDJSONLogger (append-only backup)                   |
|       |                                                          |
|       v                                                          |
|  ChatTimeline (SwiftUI rendering)                               |
|       |                                                          |
|       v                                                          |
|  PostHooks (observe, log, notify)                               |
|       |                                                          |
|       v                                                          |
|  HookRunner.executePostHooks()                                  |
|                                                                   |
+------------------------------------------------------------------+
```

### Multi-Engine Flow

```
+------------------------------------------------------------------+
|                   MULTI-ENGINE FLOW                               |
+------------------------------------------------------------------+
|                                                                   |
|  User selects provider in session creation                       |
|       |                                                          |
|       v                                                          |
|  SessionOrchestrator.createSession(provider: .anthropic)        |
|       |                                                          |
|       v                                                          |
|  EngineManager.getAdapter(for: provider)                        |
|       |                                                          |
|       +-------+-------+-------+                                 |
|       |       |       |       |                                 |
|       v       v       v       v                                 |
|   Claude   Gemini   Codex   (future)                            |
|   Adapter  Adapter  Adapter                                      |
|       |       |       |                                          |
|       v       v       v                                          |
|   +-------+ +-------+ +-------+                                 |
|   |claude | |gemini | |codex  |                                 |
|   |-p ... | |-p ... | |exec...|                                 |
|   +-------+ +-------+ +-------+                                 |
|       |       |       |                                          |
|       +-------+-------+                                          |
|               |                                                   |
|               v                                                   |
|       NormalizedEvent                                            |
|       (same type regardless of provider)                         |
|                                                                   |
+------------------------------------------------------------------+
```

### Session Lifecycle

```
+------------------------------------------------------------------+
|                  SESSION LIFECYCLE                                |
+------------------------------------------------------------------+
|                                                                   |
|  [Creating] -----> [Ready] <-----> [Running]                    |
|       |              |                 |                         |
|       |              |                 v                         |
|       |              |           [Streaming]                     |
|       |              |                 |                         |
|       |              v                 v                         |
|       |         [Stopped] <------- [Waiting]                    |
|       |              |                 |                         |
|       v              v                 v                         |
|  [Errored] <---- [Errored] <------ [Errored]                    |
|       |              |                 |                         |
|       +-------+------+-----------------+                         |
|               |                                                   |
|               v                                                   |
|          [Archived]                                              |
|                                                                   |
|  State Persistence:                                              |
|  - SQLite: Session metadata, state transitions                  |
|  - JSONL: Full event log for replay                             |
|  - Memory: Active session state                                  |
|                                                                   |
+------------------------------------------------------------------+
```

### Approval Flow

```
+------------------------------------------------------------------+
|                    APPROVAL FLOW                                  |
+------------------------------------------------------------------+
|                                                                   |
|  Tool Call Request                                               |
|       |                                                          |
|       v                                                          |
|  PolicyEngine.evaluate(tool, input)                             |
|       |                                                          |
|       +---> Check trust mode                                    |
|       |         |                                                |
|       |         +---> YOLO? --> Auto-approve                    |
|       |         |                                                |
|       |         +---> Sandbox? --> Check if safe tool           |
|       |         |                     |                          |
|       |         |                     +---> Safe? --> Allow     |
|       |         |                     |                          |
|       |         |                     +---> Not safe? --> Block |
|       |         |                                                |
|       |         +---> Review/Trusted? --> Continue below        |
|       |                                                          |
|       +---> Check auto-approve patterns                         |
|       |         |                                                |
|       |         +---> Match? --> Allow                          |
|       |         |                                                |
|       |         +---> No match? --> Continue                    |
|       |                                                          |
|       +---> Check blocked patterns                              |
|       |         |                                                |
|       |         +---> Match? --> Block                          |
|       |         |                                                |
|       |         +---> No match? --> Continue                    |
|       |                                                          |
|       +---> Check trusted tools (Trusted mode)                  |
|       |         |                                                |
|       |         +---> Trusted? --> Allow                        |
|       |         |                                                |
|       |         +---> Not trusted? --> Queue for approval       |
|       |                                                          |
|       v                                                          |
|  Show Approval Dialog                                            |
|       |                                                          |
|       +---> [Deny] --> Block, continue session                  |
|       |                                                          |
|       +---> [Allow Once] --> Execute, don't remember            |
|       |                                                          |
|       +---> [Allow & Trust] --> Execute, add to trusted list    |
|                                                                   |
+------------------------------------------------------------------+
```

### Hook System Architecture

```
+------------------------------------------------------------------+
|                 HOOK SYSTEM ARCHITECTURE                          |
+------------------------------------------------------------------+
|                                                                   |
|  Event Occurs                                                    |
|       |                                                          |
|       v                                                          |
|  HookRunner.dispatch(event)                                      |
|       |                                                          |
|       v                                                          |
|  HookStore.getHooks(event.type)                                  |
|       |                                                          |
|       v                                                          |
|  For each hook:                                                  |
|       |                                                          |
|       +---> Check matcher (tool name, path pattern, etc.)       |
|       |         |                                                |
|       |         +---> No match? --> Skip                        |
|       |         |                                                |
|       |         +---> Match? --> Execute                        |
|       |                                                          |
|       +---> Execute hook command                                 |
|       |         |                                                |
|       |         +---> stdin: JSON event                         |
|       |         |                                                |
|       |         +---> stdout: JSON result                       |
|       |         |                                                |
|       |         +---> Parse result:                             |
|       |               - block: true --> Block event             |
|       |               - additionalContext --> Inject context    |
|       |               - updatedInput --> Modify input           |
|       |                                                          |
|       v                                                          |
|  HookExecutionStore.log(hook, result, duration)                 |
|                                                                   |
+------------------------------------------------------------------+
```

### Worktree Structure

```
+------------------------------------------------------------------+
|                  WORKTREE STRUCTURE                               |
+------------------------------------------------------------------+
|                                                                   |
|  my-project/                                                     |
|  |                                                                |
|  +-- .git/                    <-- Shared Git data               |
|  |   +-- objects/                                                |
|  |   +-- refs/                                                   |
|  |   +-- worktrees/           <-- Worktree metadata             |
|  |       +-- abc12345/                                           |
|  |       +-- def67890/                                           |
|  |                                                                |
|  +-- .blaze-worktrees/        <-- Blaze worktree location       |
|  |   |                                                           |
|  |   +-- abc12345-session-1/  <-- Worktree 1                    |
|  |   |   +-- src/             <-- Full checkout                 |
|  |   |   +-- tests/                                              |
|  |   |   +-- .blaze-session/  <-- Session state                 |
|  |   |       +-- state.json                                      |
|  |   |       +-- events.jsonl                                    |
|  |   |                                                           |
|  |   +-- def67890-session-2/  <-- Worktree 2                    |
|  |       +-- src/                                                |
|  |       +-- tests/                                              |
|  |       +-- .blaze-session/                                     |
|  |                                                                |
|  +-- src/                     <-- Main worktree files           |
|  +-- tests/                                                      |
|  +-- .blaze/                  <-- Project config                |
|      +-- config.json                                             |
|      +-- hooks/                                                  |
|                                                                   |
+------------------------------------------------------------------+
```

### UI Layout Architecture

```
+------------------------------------------------------------------+
|                    UI LAYOUT                                      |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  | Menu Bar                                                    |  |
|  +------------------------------------------------------------+  |
|  |          |                                    |             |  |
|  | Sidebar  |           Main Content             |  Inspector  |  |
|  | (240px)  |                                    |  (280px)    |  |
|  |          |  +--------------------------------+|             |  |
|  | Sessions |  |        Chat Timeline           ||  Context    |  |
|  | Files    |  |                                ||  Tokens     |  |
|  | Git      |  |  +------------------------+   ||  Actions    |  |
|  | Agents   |  |  | Message Bubbles        |   ||             |  |
|  | ...      |  |  | Tool Cards             |   ||             |  |
|  |          |  |  | Diff Viewers           |   ||             |  |
|  |          |  |  +------------------------+   ||             |  |
|  |          |  |                                ||             |  |
|  |          |  +--------------------------------+|             |  |
|  |          |  |        Input Area              ||             |  |
|  |          |  +--------------------------------+|             |  |
|  +----------+------------------------------------+-------------+  |
|  | Status Bar                                                  |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  NavigationSplitView with:                                       |
|  - Resizable dividers                                            |
|  - Column visibility toggles                                     |
|  - Keyboard navigation                                           |
|  - Drag-to-resize                                                |
|                                                                   |
+------------------------------------------------------------------+
```

### Data Layer Architecture

```
+------------------------------------------------------------------+
|                  DATA LAYER ARCHITECTURE                          |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------------------------------------------------+  |
|  |                      SQLite Database                        |  |
|  |                                                              |  |
|  |  +----------------+  +----------------+  +----------------+ |  |
|  |  |    sessions    |  |     events     |  |     tokens     | |  |
|  |  |----------------|  |----------------|  |----------------| |  |
|  |  | id             |  | id             |  | session_id     | |  |
|  |  | name           |  | session_id     |  | input_tokens   | |  |
|  |  | provider       |  | sequence       |  | output_tokens  | |  |
|  |  | model          |  | type           |  | cache_hit      | |  |
|  |  | status         |  | payload        |  | cost_usd       | |  |
|  |  | parent_id      |  | tool_use_id    |  | timestamp      | |  |
|  |  | branch_point   |  | timestamp      |  +----------------+ |  |
|  |  | created_at     |  +----------------+                     |  |
|  |  | updated_at     |                                         |  |
|  |  +----------------+  +----------------+  +----------------+ |  |
|  |                      |     hooks      |  |   approvals    | |  |
|  |                      |----------------|  |----------------| |  |
|  |                      | id             |  | id             | |  |
|  |                      | event_type     |  | session_id     | |  |
|  |                      | matcher        |  | tool_name      | |  |
|  |                      | script_path    |  | decision       | |  |
|  |                      | repo_scope     |  | scope          | |  |
|  |                      | enabled        |  | timestamp      | |  |
|  |                      +----------------+  +----------------+ |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |                    JSONL Event Logs                         |  |
|  |                                                              |  |
|  |  ~/.blaze/sessions/{session_id}/events.jsonl               |  |
|  |  - Append-only                                              |  |
|  |  - Crash-safe                                               |  |
|  |  - Replayable                                               |  |
|  +------------------------------------------------------------+  |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |                    Backup Manager                           |  |
|  |                                                              |  |
|  |  - SHA256 checksums                                         |  |
|  |  - Atomic restore                                           |  |
|  |  - Scheduled backups                                        |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### Subagent Orchestration

```
+------------------------------------------------------------------+
|                SUBAGENT ORCHESTRATION                             |
+------------------------------------------------------------------+
|                                                                   |
|  Main Agent                                                      |
|       |                                                          |
|       v                                                          |
|  SubagentRegistry.spawn(task, config)                           |
|       |                                                          |
|       v                                                          |
|  SubagentPool.acquire()                                          |
|       |                                                          |
|       +---> Check pool capacity                                 |
|       |         |                                                |
|       |         +---> Under limit? --> Create subagent          |
|       |         |                                                |
|       |         +---> At limit? --> Queue or reject             |
|       |                                                          |
|       +---> Check memory                                        |
|       |         |                                                |
|       |         +---> Low memory? --> Throttle                  |
|       |                                                          |
|       v                                                          |
|  Subagent Process                                                |
|       |                                                          |
|       +---> Dual correlation:                                   |
|       |     - session_id: Links to parent                       |
|       |     - subagent_id: Unique identifier                    |
|       |                                                          |
|       +---> SubagentEventRouter                                 |
|             |                                                    |
|             +---> spawned --> UI shows new subagent block       |
|             |                                                    |
|             +---> progress --> Update progress bar              |
|             |                                                    |
|             +---> completed --> Show result                     |
|             |                                                    |
|             +---> failed --> Show error                         |
|                                                                   |
|  Pool Configuration:                                             |
|  - Default: 10 concurrent                                        |
|  - Max: 500 total                                                |
|  - Memory-aware throttling                                       |
|                                                                   |
+------------------------------------------------------------------+
```

---

## CLI Invocation Patterns

### Claude Code

```bash
# Basic headless invocation
claude -p "<prompt>" --output-format stream-json

# With allowed tools
claude -p "<prompt>" --output-format stream-json --allowedTools Read,Write,Edit,Bash

# With max tokens
claude -p "<prompt>" --output-format stream-json --max-tokens 8000

# Skip permissions (YOLO mode)
claude -p "<prompt>" --output-format stream-json --dangerously-skip-permissions

# With model override
claude -p "<prompt>" --output-format stream-json --model claude-sonnet-4

# Headless mode does NOT persist sessions
# Blaze manages conversation continuity via stored event logs
```

### Gemini CLI

```bash
# Basic headless invocation
gemini -p "<prompt>" --output-format stream-json

# Resume session (Gemini has native persistence)
gemini --resume

# With model selection
gemini -p "<prompt>" --output-format stream-json --model gemini-pro
```

### OpenAI Codex CLI

```bash
# Basic execution
codex exec --json "<prompt>"

# Resume multi-turn
codex exec resume

# Full auto mode
codex exec --json "<prompt>" --full-auto

# With sandbox
codex exec --json "<prompt>" --sandbox
```

---

## Data Layer Deep Dive

### SessionStore

Manages session lifecycle with SQLite persistence.

```swift
struct Session {
    let id: UUID
    var name: String
    var provider: AIProvider
    var model: String
    var status: SessionStatus
    var parentId: UUID?      // For branching
    var branchPoint: Int?    // Event index where branch occurred
    var createdAt: Date
    var updatedAt: Date
}

// Branching support
func fork(session: Session, atEvent: Int) -> Session {
    return Session(
        parentId: session.id,
        branchPoint: atEvent,
        // ... copy other properties
    )
}
```

### EventStore

Handles event persistence with sequence numbers.

```swift
struct EventEnvelope {
    let id: UUID
    let sessionId: UUID
    let sequence: Int        // Monotonic sequence number
    let type: EventType
    let payload: NormalizedEvent
    let toolUseId: String?   // For correlation
    let timestamp: Date
}
```

### TokenStore

Tracks token usage and costs.

```swift
struct TokenUsage {
    let sessionId: UUID
    var inputTokens: Int
    var outputTokens: Int
    var cacheHitTokens: Int
    var costUSD: Decimal
    let timestamp: Date
}

// Budget alerts
func checkBudget(session: Session) -> BudgetStatus {
    let usage = getUsage(session.id)
    let budget = getBudget(session.id)

    if usage.costUSD > budget.limit {
        return .exceeded
    } else if usage.costUSD > budget.limit * 0.8 {
        return .warning
    }
    return .ok
}
```

### HookStore

Manages hook definitions with repo scoping.

```swift
struct HookDefinition {
    let id: UUID
    let eventType: HookEventType  // 12 types supported
    let matcher: [String]?
    let scriptPath: String
    let repoScope: String?        // Optional repo restriction
    var enabled: Bool
}

enum HookEventType {
    case preToolUse
    case postToolUse
    case userPromptSubmit
    case preCompact
    case sessionStart
    case sessionEnd
    case notification
    case stop
    // ... 4 more
}
```

### NDJSONLogger

Dual-write logging for crash safety.

```swift
class NDJSONLogger {
    private let fileHandle: FileHandle
    private let queue: DispatchQueue

    func log(event: EventEnvelope) {
        queue.async {
            let json = try! JSONEncoder().encode(event)
            self.fileHandle.write(json + "\n")
            self.fileHandle.synchronizeFile()  // Ensure durability
        }
    }

    func replay() -> [EventEnvelope] {
        // Read line by line, parse each as JSON
    }
}
```

### BackupManager

Handles backups with integrity verification.

```swift
class BackupManager {
    func backup(session: Session) throws {
        let data = try export(session)
        let checksum = SHA256.hash(data)

        let backup = Backup(
            sessionId: session.id,
            data: data,
            checksum: checksum.hexString,
            timestamp: Date()
        )

        try save(backup)
    }

    func restore(backupId: UUID) throws -> Session {
        let backup = try load(backupId)

        // Verify checksum
        let checksum = SHA256.hash(backup.data)
        guard checksum.hexString == backup.checksum else {
            throw BackupError.corruptedBackup
        }

        return try import(backup.data)
    }
}
```

---

## Subagent System

### SubagentRegistry

Tracks subagent relationships.

```swift
class SubagentRegistry {
    // Dual correlation
    private var bySessionId: [UUID: [Subagent]] = [:]
    private var bySubagentId: [UUID: Subagent] = [:]

    func spawn(
        parentSession: UUID,
        task: String,
        config: SubagentConfig
    ) -> Subagent {
        let subagent = Subagent(
            id: UUID(),
            parentSessionId: parentSession,
            task: task,
            status: .queued,
            config: config
        )

        bySessionId[parentSession, default: []].append(subagent)
        bySubagentId[subagent.id] = subagent

        return subagent
    }
}
```

### SubagentPool

Manages concurrency and resources.

```swift
class SubagentPool {
    let defaultConcurrency = 10
    let maxConcurrency = 500

    private var active: [Subagent] = []
    private var queued: [Subagent] = []

    func acquire(for subagent: Subagent) throws {
        // Check memory
        if isMemoryLow() {
            throttle()
        }

        // Check capacity
        if active.count >= maxConcurrency {
            throw PoolError.atCapacity
        }

        if active.count >= defaultConcurrency {
            queued.append(subagent)
            return
        }

        active.append(subagent)
        start(subagent)
    }

    func release(_ subagent: Subagent) {
        active.removeAll { $0.id == subagent.id }

        if let next = queued.first {
            queued.removeFirst()
            start(next)
        }
    }
}
```

### SubagentEventRouter

Routes events to UI.

```swift
class SubagentEventRouter {
    func route(_ event: SubagentEvent) {
        switch event.type {
        case .spawned:
            NotificationCenter.default.post(
                name: .subagentSpawned,
                object: event.subagent
            )

        case .progress:
            NotificationCenter.default.post(
                name: .subagentProgress,
                object: event.progress
            )

        case .completed:
            NotificationCenter.default.post(
                name: .subagentCompleted,
                object: event.result
            )

        case .failed:
            NotificationCenter.default.post(
                name: .subagentFailed,
                object: event.error
            )
        }
    }
}
```

---

## Keyboard Shortcuts Reference

### Global Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New session |
| `Cmd+Shift+N` | New project |
| `Cmd+O` | Open project |
| `Cmd+W` | Close session |
| `Cmd+Q` | Quit Blaze |
| `Cmd+,` | Open settings |
| `Cmd+K` | Command palette |
| `Cmd+\` | Toggle sidebar |
| `Cmd+Shift+\` | Toggle inspector |

### Chat Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Enter` | Send message |
| `Shift+Enter` | New line in input |
| `Cmd+.` | Stop generation |
| `Cmd+L` | Clear chat (new turn) |
| `Cmd+C` | Copy selected text |
| `Cmd+Shift+C` | Copy code block |
| `Escape` | Cancel current action |

### Navigation Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+1` | Sessions panel |
| `Cmd+2` | Files panel |
| `Cmd+3` | Git panel |
| `Cmd+4` | Approvals panel |
| `Cmd+[` | Previous session |
| `Cmd+]` | Next session |
| `Cmd+Up` | Scroll to top |
| `Cmd+Down` | Scroll to bottom |

### Diff Viewer Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+A` | Accept all diffs |
| `Cmd+Shift+R` | Reject all diffs |
| `Cmd+D` | Toggle diff view mode |
| `J` | Next hunk |
| `K` | Previous hunk |
| `A` | Accept current hunk |
| `R` | Reject current hunk |

### File Tree Shortcuts

| Shortcut | Action |
|----------|--------|
| `Enter` | Open file |
| `Space` | Preview file |
| `Cmd+Shift+R` | Reveal in Finder |
| `Cmd+Shift+C` | Copy path |
| `Cmd+Shift+I` | Insert as @reference |

---

## Performance Notes

### Performance Budgets

| Metric | Target | Critical |
|--------|--------|----------|
| App Launch (cold) | < 1.0s | < 2.0s |
| App Launch (warm) | < 0.3s | < 0.5s |
| Command Palette | < 50ms | < 100ms |
| First Token Render | < 100ms | < 200ms |
| Tool Card Render | < 50ms | < 100ms |
| Diff Render (1K lines) | < 100ms | < 300ms |
| Diff Render (10K lines) | < 500ms | < 1s |
| Message Send | < 30ms | < 100ms |
| Scroll (60fps) | 16.6ms/frame | 33ms/frame |

### Memory Budgets

| State | Target | Critical |
|-------|--------|----------|
| Idle | < 150 MB | < 300 MB |
| Active Session | < 300 MB | < 500 MB |
| Large Session (1000 events) | < 400 MB | < 600 MB |
| Memory Growth/Hour | < 10 MB | < 50 MB |

### Known Bottlenecks

| Area | Issue | Mitigation |
|------|-------|------------|
| Large diffs | 10K+ line rendering | Virtualization |
| Long sessions | Memory growth | Event pruning |
| Streaming | High token rate | Batched updates |
| Database | Large queries | Pagination |

---

## Security Model

### Threat Model

| Threat | Risk | Mitigation |
|--------|------|------------|
| Accidental file deletion | High | Pre-hook blocking |
| Secret exfiltration | Critical | Pattern scanning |
| Unreviewed code changes | Medium | Mandatory diff review |
| Shell command injection | High | Command allowlisting |
| Scope creep | Medium | Directory restrictions |
| Runaway resource usage | Low | Timeout enforcement |

### Trust Mode Spectrum

```
SANDBOX -------- REVIEW -------- TRUSTED -------- YOLO
(Locked)       (Default)        (Expert)      (Dangerous)

Read-only      Approvals        Minimal        No gates
Safe tools     Required         gates          Auto-approve
No writes                                      everything
```

### Approval Workflows

| Scope | Duration | Use Case |
|-------|----------|----------|
| Once | This operation | One-time commands |
| Session | Until session ends | Repeated tools |
| Project | Persisted | Project-specific trust |
| Always | Global preference | Common tools |

### Audit Logging

All operations logged to append-only trail:

```
~/.blaze/audit/
  sessions.jsonl      # Session lifecycle
  tools.jsonl         # Tool decisions
  approvals.jsonl     # User approvals
  blocked.jsonl       # Blocked operations
```

---

## Privacy and Telemetry

### What Stays Local

| Data | Location | Encrypted |
|------|----------|-----------|
| Sessions | `~/.blaze/sessions/` | Optional |
| Event logs | `~/.blaze/events/` | No |
| Audit trail | `~/.blaze/audit/` | No |
| Database | `~/.blaze/blaze.db` | Optional |
| Preferences | `~/.blaze/config.json` | No |

### What Leaves Your Machine

1. **Provider CLIs** - Your prompts go to AI providers
2. **Webhooks** - Only if YOU configure them
3. **Telemetry** - Disabled by default

### Optional Telemetry

Disabled by default. If opted in:

| Data | Purpose | Identifiable? |
|------|---------|---------------|
| Crashes | Stability | Hashed device |
| Feature counts | Prioritization | No |
| Performance | Optimization | No |

---

## Troubleshooting

### Installation Issues

**"Blaze can't be opened because it is from an unidentified developer"**

```bash
xattr -d com.apple.quarantine /Applications/Blaze.app
```

**Missing CLI binary**

```bash
which claude || npm install -g @anthropic-ai/claude-code
```

### Authentication Issues

**"Not logged in" error**

```bash
claude logout && claude login
```

### Tool Permission Issues

1. Check trust mode in Settings
2. Review blocked patterns
3. Check hook logs

### Hooks Not Firing

1. Verify hook is enabled
2. Check event type matches
3. Review hook timeout
4. Check logs: `tail -f ~/.blaze/logs/hooks.log`

### Diagnostics

```bash
# Application logs
tail -f ~/Library/Logs/com.blaze.app/blaze.log

# Reset settings
rm -rf ~/.blaze/settings.json
```

---

## Hook Cookbook

### Recipe 1: Auto-Run Tests After File Changes

**Goal:** Run tests whenever Claude edits code files.

```json
{
  "id": "auto-test",
  "event": "PostToolUse",
  "matcher": ["Write", "Edit"],
  "type": "post",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/run-tests.sh"
  }
}
```

**Script (`~/.blaze/hooks/run-tests.sh`):**

```bash
#!/bin/bash
cd "$BLAZE_PROJECT_PATH"

# Run tests and capture result
OUTPUT=$(npm test 2>&1)
EXIT_CODE=$?

# Return structured JSON for context injection
if [ $EXIT_CODE -eq 0 ]; then
  echo '{"additionalContext": "Tests passed."}'
else
  FAILURES=$(echo "$OUTPUT" | grep -A5 "FAIL\|Error" | head -20)
  cat << EOF
{
  "additionalContext": "Tests failed. Summary:\n$FAILURES",
  "decision": "block",
  "reason": "Tests are failing. Please fix before continuing."
}
EOF
fi
```

### Recipe 2: Block Destructive Commands

**Goal:** Prevent `rm -rf`, force pushes, and other dangerous operations.

```json
{
  "id": "block-dangerous",
  "event": "PreToolUse",
  "matcher": ["Bash"],
  "type": "pre",
  "canBlock": true,
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/check-dangerous.sh"
  }
}
```

**Script (`~/.blaze/hooks/check-dangerous.sh`):**

```bash
#!/bin/bash

EVENT=$(cat)
COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // empty')

DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \*"
  "git push.*--force"
  "git reset --hard"
  "chmod -R 777"
  "> /dev/sd"
  "mkfs\."
  "dd if="
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    cat << EOF
{
  "block": true,
  "reason": "Blocked dangerous command matching: $pattern"
}
EOF
    exit 0
  fi
done

echo '{"block": false}'
```

### Recipe 3: Require Approval for Writes Outside Safe Paths

**Goal:** Allow writes to `src/` and `tests/` without approval; require approval elsewhere.

```json
{
  "id": "path-gating",
  "event": "PreToolUse",
  "matcher": ["Write", "Edit"],
  "type": "pre",
  "canBlock": true,
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/check-write-path.sh"
  }
}
```

**Script (`~/.blaze/hooks/check-write-path.sh`):**

```bash
#!/bin/bash

EVENT=$(cat)
FILE_PATH=$(echo "$EVENT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

SAFE_PATHS=("src/" "tests/" "docs/")

for safe in "${SAFE_PATHS[@]}"; do
  if [[ "$FILE_PATH" == *"$safe"* ]]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
  fi
done

cat << EOF
{
  "permissionDecision": "ask",
  "permissionDecisionReason": "File is outside safe directories: $FILE_PATH"
}
EOF
```

### Recipe 4: Load Project Context on Session Start

**Goal:** Automatically inject project-specific context when a session begins.

```json
{
  "id": "load-context",
  "event": "SessionStart",
  "matcher": ["startup", "resume"],
  "type": "post",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/load-context.sh"
  }
}
```

**Script (`~/.blaze/hooks/load-context.sh`):**

```bash
#!/bin/bash

cd "$BLAZE_PROJECT_PATH"

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log -1 --oneline 2>/dev/null || echo "no commits")
TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l | tr -d ' ')

cat << EOF
{
  "additionalContext": "Project context: Branch '$BRANCH', last commit: $LAST_COMMIT, $TODO_COUNT TODOs in src/"
}
EOF
```

### Recipe 5: Slack Notification on Session Complete

**Goal:** Send a Slack message when a long-running session finishes.

```json
{
  "id": "slack-notify",
  "event": "Stop",
  "type": "observer",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/slack-notify.sh"
  }
}
```

**Script (`~/.blaze/hooks/slack-notify.sh`):**

```bash
#!/bin/bash

EVENT=$(cat)
SESSION_NAME=$(echo "$EVENT" | jq -r '.session_name // "Unknown session"')

curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"Blaze session completed: $SESSION_NAME\"}" \
  "$SLACK_WEBHOOK_URL"
```

### Recipe 6: Auto-Format Code Before Commit

**Goal:** Run prettier/eslint before allowing git commit commands.

```json
{
  "id": "pre-commit-format",
  "event": "PreToolUse",
  "matcher": ["Bash"],
  "type": "pre",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/pre-commit-format.sh"
  }
}
```

**Script:**

```bash
#!/bin/bash

EVENT=$(cat)
COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // empty')

# Only intercept git commit
if [[ "$COMMAND" == *"git commit"* ]]; then
  cd "$BLAZE_PROJECT_PATH"

  # Run formatter
  npm run format 2>/dev/null
  npm run lint --fix 2>/dev/null

  # Stage any formatting changes
  git add -u
fi

echo '{"block": false}'
```

### Recipe 7: Detect Secrets in Code

**Goal:** Block writes that appear to contain API keys or secrets.

```bash
#!/bin/bash

EVENT=$(cat)
CONTENT=$(echo "$EVENT" | jq -r '.tool_input.content // empty')

SECRET_PATTERNS=(
  "api[_-]?key"
  "secret[_-]?key"
  "password\s*="
  "AWS_SECRET"
  "PRIVATE_KEY"
  "-----BEGIN RSA"
  "sk-[a-zA-Z0-9]{48}"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -qiE "$pattern"; then
    cat << EOF
{
  "block": true,
  "reason": "Detected potential secret in code. Pattern: $pattern"
}
EOF
    exit 0
  fi
done

echo '{"block": false}'
```

### Recipe 8: Rate Limit Tool Calls

**Goal:** Prevent runaway agents by limiting tool calls per minute.

```bash
#!/bin/bash

RATE_FILE="/tmp/blaze-rate-$BLAZE_SESSION_ID"
MAX_CALLS_PER_MINUTE=30

# Get current count
NOW=$(date +%s)
if [ -f "$RATE_FILE" ]; then
  LAST_RESET=$(head -1 "$RATE_FILE")
  COUNT=$(tail -1 "$RATE_FILE")

  # Reset if minute has passed
  if [ $((NOW - LAST_RESET)) -gt 60 ]; then
    echo "$NOW" > "$RATE_FILE"
    echo "1" >> "$RATE_FILE"
    COUNT=1
  else
    COUNT=$((COUNT + 1))
    echo "$LAST_RESET" > "$RATE_FILE"
    echo "$COUNT" >> "$RATE_FILE"
  fi
else
  echo "$NOW" > "$RATE_FILE"
  echo "1" >> "$RATE_FILE"
  COUNT=1
fi

if [ $COUNT -gt $MAX_CALLS_PER_MINUTE ]; then
  echo '{"block": true, "reason": "Rate limit exceeded. Slow down."}'
else
  echo '{"block": false}'
fi
```

---

## FAQ

### Safety and Security

**Q: Can the AI delete my files?**

A: Only if you approve it. In Review mode (default), every file write requires explicit approval. Even in Trusted mode, dangerous patterns like `rm -rf /` are blocked by the PolicyEngine. Only YOLO mode bypasses all checks - and even then, some patterns are hardcoded as blocked.

**Q: What about prompt injection attacks?**

A: Blaze inherits the security properties of the underlying CLIs. We add an additional layer via the PolicyEngine that can block suspicious patterns. However, AI systems are fundamentally unpredictable - always review before approving. The diff viewer exists specifically to help you verify changes.

**Q: What if Claude tries `rm -rf /`?**

A: Blocked by PolicyEngine, even in Trusted mode. Certain patterns are hardcoded as never-allow regardless of your trust settings:
- `rm -rf /`
- `rm -rf ~`
- `chmod -R 777 /`
- `dd if=/dev/zero of=/dev/sda`
- And several others

**Q: How do I audit what the AI has done?**

A: Everything is logged:
- `~/.blaze/audit/tools.jsonl` - All tool calls with inputs and outputs
- `~/.blaze/audit/approvals.jsonl` - Your approval decisions
- `~/.blaze/audit/blocked.jsonl` - What was blocked and why
- Each session has a complete event log in JSONL format

### Privacy

**Q: Does Blaze phone home?**

A: No. Blaze itself sends zero data to any server. Your conversations go only to the AI provider you choose (Anthropic, Google, or OpenAI) via their official CLI tools.

**Q: Is telemetry enabled?**

A: Optional and disabled by default. If you opt in, only anonymous usage stats (crash reports, feature counts) are collected - never conversation content or code.

**Q: Where is my data stored?**

A: Everything stays local on your machine:
- Sessions: `~/.blaze/sessions/`
- Event logs: `~/.blaze/events/`
- Settings: `~/.blaze/config.json`
- Audit logs: `~/.blaze/audit/`
- Database: `~/.blaze/blaze.db`

**Q: Is my code sent anywhere besides the AI provider?**

A: No. Only to the provider APIs via their official CLIs. Blaze adds no additional data transmission.

### Authentication

**Q: Do I need an API key?**

A: No. Blaze uses each provider's CLI login flow. For Claude Code, you authenticate via `claude login` which opens a browser flow. No raw API keys are stored in Blaze.

**Q: How does authentication work?**

A: Each CLI manages its own authentication:
- **Claude**: OAuth via browser, tokens stored in system keychain
- **Gemini**: Google account OAuth
- **Codex**: OpenAI API key or OAuth

Blaze never sees or stores your credentials directly.

**Q: What if my token expires?**

A: Blaze detects auth failures and prompts you to re-authenticate via the CLI's login flow.

### Features

**Q: Does it work offline?**

A: No. Blaze requires internet access because AI inference happens on provider servers.

**Q: Can I use local LLMs?**

A: On the roadmap. Support for Ollama and LM Studio is planned for the 6-month timeframe.

**Q: Can I use Blaze with my team?**

A: Currently single-user. Team features (shared sessions, policy templates, collaborative review) are planned for the 6-month milestone.

**Q: Can I use custom MCP servers?**

A: MCP server management UI is on the 30-90 day roadmap. Currently, you can configure MCP via the CLI's native settings.

### Comparisons

**Q: How is Blaze different from Cursor?**

A: Cursor is a full IDE (VS Code fork) with AI built in. Blaze is an agent cockpit - it doesn't replace your editor but works alongside it. Choose Cursor if you want inline completions in your editor. Choose Blaze if you want visual governance, multi-CLI support, and hook automation.

**Q: How is Blaze different from Warp?**

A: Warp is a terminal replacement with AI features. Blaze is a structured event renderer that sits above CLIs. Warp shows terminal output; Blaze parses JSON events into tool cards, diff viewers, and approval flows.

**Q: Why not just use the CLI directly?**

A: You can! Blaze adds value if you want:
- Visual diff review before accepting changes
- Approval workflows with preview
- Session persistence and search
- Visual hook builder
- Multi-CLI unified interface
- Parallel agent support via worktrees

If you're terminal-native and don't need these, the CLI is great.

### Technical

**Q: Why native macOS only?**

A: We prioritized depth over breadth. Native SwiftUI enables 60fps streaming, glass effects, and system integration that Electron can't match. Cross-platform is being evaluated for later.

**Q: What's the memory footprint?**

A: Target is <150MB idle, <300MB with active session. We use virtualized lists and lazy loading to stay lean.

**Q: Can I extend Blaze with plugins?**

A: Plugin system is on the 3-6 month roadmap. Currently, hooks provide extensibility at the event level.

**Q: Does Blaze modify the CLI binaries?**

A: No. Blaze spawns unmodified CLI processes and reads their stdout. We never patch or wrap the binaries.

### Troubleshooting

**Q: My hooks aren't firing, what do I check?**

A: Check in order:
1. Is the hook enabled in Settings?
2. Does the event type match?
3. Does the matcher match the tool name?
4. Is the script executable? (`chmod +x`)
5. Check logs: `tail -f ~/.blaze/logs/hooks.log`

**Q: The diff viewer shows wrong colors, how do I fix it?**

A: Check Settings > Appearance > Theme. Some custom themes may have insufficient contrast. Try a built-in theme to verify.

**Q: Session won't load after crash, what do I do?**

A: Sessions have crash-safe JSONL backup. Try:
1. Check `~/.blaze/sessions/{id}/events.jsonl` exists
2. Restart Blaze - it auto-recovers on launch
3. If still broken, check `~/.blaze/backups/` for recent backup

---

## Roadmap

### Now (In Progress)

- Multi-CLI support (Claude + Gemini + Codex)
- Hook system with visual builder
- Streaming UI polish
- Session continuity across restarts

### Next (30-90 days)

- Worktree-per-task isolation
- Multi-agent orchestration
- MCP server management UI
- Voice dictation mode
- Branch conversations

### Later (3-6 months)

- Plugin/extension system
- Policy templates marketplace
- Team collaboration
- Local LLM support
- Windows/Linux (evaluating)

### What We Are NOT Building

- Terminal emulator (use iTerm2)
- IDE (use VS Code, Cursor)
- Web wrapper (we're native)
- Our own AI model (we orchestrate)

---

## Contributing

### Development Setup

```bash
# Prerequisites
# - macOS 14.0+
# - Xcode 15.0+
# - Claude Code CLI

# Clone and build
git clone git@github.com:anth0nylawrence/blaze.git
cd blaze/Blaze
swift build

# Or open in Xcode
open Package.swift
```

### Repository Layout

```
blaze/
+-- Blaze/
|   +-- Sources/
|   |   +-- App/          # Entry point
|   |   +-- Core/         # Models, events
|   |   +-- Data/         # Database
|   |   +-- DesignSystem/ # UI components
|   |   +-- Engine/       # CLI adapters
|   |   +-- Security/     # Policy engine
|   |   +-- UI/           # Main views
|   +-- Tests/
+-- docs/
|   +-- atoms/            # Feature roadmap
+-- scripts/
```

### Code Style

- Swift API Design Guidelines
- swift-format defaults
- Files < 500 LOC
- Conventional commits

### PR Guidelines

1. One feature per PR
2. Tests required
3. Update docs if needed
4. Conventional commit prefix

---

## License

This project is licensed under the **GNU Affero General Public License v3.0 or later** (AGPL-3.0-or-later).

See LICENSE file for details.

---

## Acknowledgments

- **Anthropic** - Claude Code CLI
- **Google** - Gemini CLI
- **OpenAI** - Codex CLI
- **SwiftUI Team** - Native macOS frameworks
- **Open Source Community** - Inspiration and tools

---

<p align="center">
  <strong>Documentation:</strong> <a href="https://getblaze.dev/docs/">getblaze.dev/docs</a>
</p>

<p align="center">
  <em>Last updated: January 2026</em>
</p>
