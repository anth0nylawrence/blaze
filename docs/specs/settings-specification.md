# Cogit0 Blaze Settings Specification

**Version:** 1.0.0
**Date:** 2025-12-25
**Status:** Draft

---

## Overview

The Settings panel in Cogit0 Blaze is divided into two major sections:

1. **App Settings** - General application preferences (appearance, typography, behavior)
2. **Claude Code Settings** - Configuration for Claude Code CLI integration (hooks, agents, skills, MCP, permissions)

Settings are accessed via:
- Menu: `Blaze → Settings...` (⌘,)
- Command Palette: "Open Settings"

---

## Part 1: App Settings

### 1.1 Appearance

#### Theme

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Color Scheme** | Enum | System, Light, Dark | System |
| **Accent Color** | Color Picker | System Blue, Purple, Pink, Red, Orange, Yellow, Green, Custom | System Blue |
| **Sidebar Style** | Enum | Default, Compact, Minimal | Default |
| **Window Vibrancy** | Bool | Enable/Disable | Enabled |
| **Reduce Transparency** | Bool | Follow system setting | System |

#### Chat Appearance

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Message Bubbles** | Enum | Rounded, Square, Minimal | Rounded |
| **User Message Alignment** | Enum | Right, Left | Right |
| **Show Avatars** | Bool | Enable/Disable | Enabled |
| **Avatar Style** | Enum | Circle, Rounded Square, Initials Only | Circle |
| **Message Spacing** | Enum | Compact, Comfortable, Spacious | Comfortable |
| **Show Timestamps** | Enum | Always, Hover, Never | Hover |
| **Timestamp Format** | Enum | Relative, Absolute, Both | Relative |

#### Tool Cards

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Default State** | Enum | Expanded, Collapsed | Collapsed |
| **Show Duration** | Bool | Enable/Disable | Enabled |
| **Show Input Preview** | Bool | First line when collapsed | Enabled |
| **Syntax Highlighting** | Bool | Enable/Disable | Enabled |
| **Max Output Height** | Number | 100-1000px | 300px |
| **Truncate Long Output** | Bool | Enable/Disable | Enabled |

### 1.2 Typography

#### Font Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **UI Font Family** | Font Picker | System, SF Pro, Inter, Custom | System |
| **UI Font Size** | Slider | 11-18pt | 13pt |
| **UI Font Weight** | Enum | Regular, Medium | Regular |

#### Chat Typography

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Chat Font Family** | Font Picker | System, SF Pro, Inter, Custom | System |
| **Chat Font Size** | Slider | 12-24pt | 14pt |
| **Chat Line Height** | Slider | 1.2-2.0 | 1.5 |
| **Chat Letter Spacing** | Slider | -0.5 to 1.0 | 0 |

#### Code Typography

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Code Font Family** | Font Picker | SF Mono, JetBrains Mono, Fira Code, Menlo, Custom | SF Mono |
| **Code Font Size** | Slider | 10-20pt | 12pt |
| **Code Line Height** | Slider | 1.2-2.0 | 1.4 |
| **Enable Ligatures** | Bool | Enable/Disable | Enabled |
| **Tab Width** | Number | 2, 4, 8 | 4 |

#### Diff Viewer Typography

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Diff Font Family** | Font Picker | Same as Code, Custom | Same as Code |
| **Diff Font Size** | Slider | 10-18pt | 12pt |
| **Show Line Numbers** | Bool | Enable/Disable | Enabled |
| **Wrap Long Lines** | Bool | Enable/Disable | Disabled |

### 1.3 Editor & Diff Viewer

#### Editor Behavior

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Word Wrap** | Enum | Off, On, Bounded (80/120 chars) | Off |
| **Show Invisibles** | Bool | Whitespace, tabs, newlines | Disabled |
| **Show Indent Guides** | Bool | Enable/Disable | Enabled |
| **Highlight Current Line** | Bool | Enable/Disable | Enabled |
| **Bracket Matching** | Bool | Enable/Disable | Enabled |
| **Auto-Indent** | Bool | Enable/Disable | Enabled |
| **Minimap** | Bool | Enable/Disable | Disabled |

#### Diff Viewer Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Default View Mode** | Enum | Unified, Side-by-Side, Inline | Unified |
| **Show Unchanged Context** | Number | 0-10 lines | 3 |
| **Highlight Inline Changes** | Bool | Word-level diffs | Enabled |
| **Collapse Unchanged Regions** | Bool | Enable/Disable | Enabled |
| **Color Scheme** | Enum | Default, GitHub, Monokai, Solarized | Default |

#### Syntax Highlighting

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Theme** | Picker | Xcode, GitHub, Dracula, One Dark, Solarized, Custom | Xcode (auto light/dark) |
| **Language Detection** | Bool | Auto-detect from file extension | Enabled |

### 1.4 Keyboard Shortcuts

#### Customizable Shortcuts

| Action | Default | Customizable |
|--------|---------|--------------|
| **Open Command Palette** | ⌘K | Yes |
| **New Session** | ⌘N | Yes |
| **Send Message** | ⌘↵ | Yes |
| **Cancel Run** | ⌘. | Yes |
| **Toggle Diff Viewer** | ⌘D | Yes |
| **Toggle Timeline** | ⌘T | Yes |
| **Switch Sidebar Tabs** | ⌘1-5 | Yes |
| **Navigate Sessions** | ⌘[ / ⌘] | Yes |
| **Copy Last Response** | ⌘⇧C | Yes |
| **Export Session** | ⌘⇧E | Yes |
| **Focus Chat Input** | ⌘L | Yes |
| **Toggle Sidebar** | ⌘\ | Yes |
| **Toggle Sessions Panel** | ⌘⇧L | Yes |
| **Quick Open File** | ⌘P | Yes |
| **Search in Session** | ⌘F | Yes |
| **Accept All Diffs** | ⌘⇧A | Yes |
| **Reject All Diffs** | ⌘⇧R | Yes |

#### Shortcut Editor

- Search shortcuts by action name
- Detect conflicts with existing shortcuts
- Reset individual or all shortcuts to defaults
- Import/export shortcut configurations

### 1.5 Notifications

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Enable Notifications** | Bool | Enable/Disable | Enabled |
| **Session Complete** | Bool | Notify when session ends | Enabled |
| **Tool Failure** | Bool | Notify on tool errors | Enabled |
| **Approval Required** | Bool | Notify when approval needed | Enabled |
| **Background Task Complete** | Bool | Notify when background tasks finish | Enabled |
| **Sound Effects** | Bool | Enable/Disable | Disabled |
| **Sound for Notifications** | Picker | System sounds | Default |
| **Badge App Icon** | Bool | Show unread count | Enabled |

### 1.6 Privacy & Telemetry

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Anonymous Usage Analytics** | Bool | Opt-in telemetry | Disabled |
| **Crash Reports** | Bool | Send crash reports | Enabled |
| **Session History Retention** | Enum | Forever, 1 Year, 6 Months, 3 Months, 1 Month | Forever |
| **Clear Session History** | Action | Delete all sessions | - |
| **Private Mode Default** | Bool | Start sessions in private mode | Disabled |
| **Exclude from Spotlight** | Bool | Don't index sessions | Disabled |

### 1.7 Updates

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Check for Updates** | Enum | Automatically, Weekly, Never | Automatically |
| **Download Updates Automatically** | Bool | Enable/Disable | Enabled |
| **Include Pre-release Versions** | Bool | Beta channel | Disabled |
| **Show Release Notes** | Bool | Display changelog after update | Enabled |

### 1.8 Window & Layout

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Remember Window Position** | Bool | Restore on launch | Enabled |
| **Default Window Size** | Preset | Small, Medium, Large, Maximized | Medium |
| **Sessions Panel Width** | Slider | 150-400px | 250px |
| **Sidebar Width** | Slider | 200-500px | 300px |
| **Chat Panel Min Width** | Slider | 400-800px | 500px |
| **Open New Sessions in** | Enum | Same Window, New Window, New Tab | Same Window |
| **Restore Sessions on Launch** | Bool | Reopen last session | Enabled |

### 1.9 Accessibility

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Reduce Motion** | Bool | Follow system / Override | System |
| **Increase Contrast** | Bool | Follow system / Override | System |
| **VoiceOver Descriptions** | Bool | Enhanced descriptions for tool cards | Enabled |
| **Keyboard Navigation** | Bool | Full keyboard accessibility | Enabled |
| **Focus Indicators** | Enum | Default, High Visibility | Default |

---

## Part 2: Claude Code Settings

### 2.1 Account & Authentication

#### Account Overview Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ Account                                                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────┐                                                       │
│  │  👤  │  anthony@example.com                                  │
│  └──────┘  Logged in via Claude Code CLI                        │
│                                                                 │
│  Plan: Claude Max                                    [Manage →] │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Usage This Month                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ████████████████████████░░░░░░░░░░  65% of limit used   │   │
│  └─────────────────────────────────────────────────────────┘   │
│  Tokens: 6.5M / 10M  •  Resets: Jan 1, 2026                    │
│                                                                 │
│  [View Full Usage] [Upgrade Plan] [Log Out]                     │
└─────────────────────────────────────────────────────────────────┘
```

#### Account Settings

| Setting | Type | Description |
|---------|------|-------------|
| **Email** | Display | Account email address |
| **Plan Type** | Display | Free, Pro, Max, Team, Enterprise |
| **Plan Limits** | Display | Token limits, feature access |
| **Usage This Period** | Display | Current usage vs limits |
| **Billing Cycle** | Display | Reset date for usage |
| **Organization** | Display | Team/org name (if applicable) |

#### Plan Comparison Display

| Feature | Free | Pro ($20/mo) | Max ($100/mo) |
|---------|------|--------------|---------------|
| **Claude 3.5 Sonnet** | Limited | Unlimited | Unlimited |
| **Claude Opus 4** | ❌ | Limited | Unlimited |
| **Context Window** | 100K | 200K | 200K |
| **Priority Access** | ❌ | ✓ | ✓✓ |
| **Claude Code** | Limited | ✓ | Unlimited |

#### Authentication Actions

| Action | Description |
|--------|-------------|
| **Log In** | Trigger `claude login` - opens browser for OAuth |
| **Log Out** | Trigger `claude logout` - clear credentials |
| **Switch Account** | Log out and log in with different account |
| **Refresh Token** | Force re-authentication |
| **View in Browser** | Open console.anthropic.com |

#### CLI Connection Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Claude Code CLI Path** | File Picker | Auto-detect or custom path | Auto-detect |
| **CLI Version** | Display | Show installed version | - |
| **Check for CLI Updates** | Action | Check Claude Code CLI version | - |
| **Authentication Status** | Display | Logged in as / Not logged in | - |
| **Re-authenticate** | Action | Trigger `claude login` | - |
| **API Base URL** | Text | For enterprise/proxy setups | Default |
| **Proxy Settings** | Text | HTTP/HTTPS proxy URL | None |

### 2.2 Permission Modes

#### Trust Mode Selection

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Default Trust Mode** | Enum | Review, Trusted, Sandbox | Review |
| **Per-Project Override** | Bool | Allow project-specific modes | Enabled |
| **Show Mode in Toolbar** | Bool | Always visible indicator | Enabled |

#### Review Mode Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Gate File Writes** | Bool | Require approval | Enabled |
| **Gate Shell Commands** | Bool | Require approval for bash | Enabled |
| **Gate Network Access** | Bool | Require approval for web tools | Enabled |
| **Gate Git Operations** | Bool | Require approval for git push/commit | Enabled |
| **Auto-approve Read Operations** | Bool | Don't prompt for reads | Enabled |

#### Sandbox Mode Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Block All Writes** | Bool | No file modifications | Enabled |
| **Block Shell Commands** | Bool | No bash execution | Enabled |
| **Allow Specific Tools** | Multi-select | Whitelist safe tools | Read, Glob, Grep |

### 2.3 Hooks Management

#### Hooks Overview Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ Hooks                                                     [+ Add]│
├─────────────────────────────────────────────────────────────────┤
│ ☑ PreToolUse: Security Scanner        [Edit] [Delete] [Disable] │
│   Scans tool calls for dangerous patterns                       │
│   Scope: All Projects  |  Events: PreToolUse                    │
├─────────────────────────────────────────────────────────────────┤
│ ☑ PostToolUse: Auto-Test Runner       [Edit] [Delete] [Disable] │
│   Runs tests after file modifications                           │
│   Scope: ~/Projects/*  |  Events: PostToolUse                   │
├─────────────────────────────────────────────────────────────────┤
│ ☐ SessionStart: Context Loader        [Edit] [Delete] [Enable]  │
│   Loads project context on session start                        │
│   Scope: All Projects  |  Events: SessionStart                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Hook CRUD Operations

**Create Hook:**

| Field | Type | Description |
|-------|------|-------------|
| **Name** | Text | Human-readable hook name |
| **Description** | Text | What this hook does |
| **Event Type** | Multi-select | PreToolUse, PostToolUse, SessionStart, SessionStop, PreCompact, NotificationSend |
| **Scope** | Enum | All Projects, Specific Project, Glob Pattern |
| **Scope Pattern** | Text | e.g., `~/Projects/work/*` |
| **Matcher** | Object | Tool name pattern, file pattern, etc. |
| **Script Type** | Enum | Shell Script, Python, Node.js, Binary |
| **Script Path** | File Picker | Path to hook script |
| **Inline Script** | Code Editor | Or write script inline |
| **Timeout** | Number | Max execution time (ms) | 10000 |
| **Fail Behavior** | Enum | Block, Warn, Ignore | Block |
| **Environment Variables** | Key-Value | Custom env vars for hook |

**Hook Event Types:**

| Event | Trigger | Common Use Cases |
|-------|---------|------------------|
| **PreToolUse** | Before tool executes | Security scanning, policy enforcement, logging |
| **PostToolUse** | After tool completes | Auto-testing, notifications, metrics |
| **SessionStart** | New session begins | Context loading, project setup |
| **SessionStop** | Session ends | Summary generation, cleanup |
| **PreCompact** | Before context compaction | Memory writeback, checkpoint |
| **NotificationSend** | Before notification | Custom notification routing |

**Matcher Configuration:**

```json
{
  "tool_name": "bash",
  "tool_input": {
    "command": {
      "contains": ["rm -rf", "git push --force"]
    }
  }
}
```

#### Hook Import/Export

| Action | Description |
|--------|-------------|
| **Export Hook** | Save hook as JSON file |
| **Export All Hooks** | Export all hooks as pack |
| **Import Hook** | Load from JSON file |
| **Import Hook Pack** | Load multiple hooks |
| **Share Hook** | Generate shareable link (future) |

#### Built-in Hook Templates

| Template | Description |
|----------|-------------|
| **Security Scanner** | Block dangerous shell commands |
| **Auto-Test Runner** | Run tests after file changes |
| **Context Logger** | Log all tool calls to file |
| **Notification Sender** | Desktop notifications for events |
| **Git Safety** | Require confirmation for push/force |
| **Secret Detector** | Block commits with secrets |

### 2.4 Agents Management

#### Available Agents Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ Agents                                              [Refresh]   │
├─────────────────────────────────────────────────────────────────┤
│ ☑ Explore                                                       │
│   Fast agent for codebase exploration                           │
│   Source: Built-in  |  Tools: Glob, Grep, Read                  │
├─────────────────────────────────────────────────────────────────┤
│ ☑ Plan                                                          │
│   Software architect for implementation planning                │
│   Source: Built-in  |  Tools: All                               │
├─────────────────────────────────────────────────────────────────┤
│ ☑ code-reviewer                                                 │
│   Reviews code for quality and security                         │
│   Source: Plugin  |  Tools: Read, Grep, Glob                    │
├─────────────────────────────────────────────────────────────────┤
│ ☐ debugger (disabled)                                           │
│   Debugging specialist for errors                               │
│   Source: Custom  |  Tools: All                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Agent Settings

| Setting | Type | Description |
|---------|------|-------------|
| **Enabled** | Bool | Enable/disable agent |
| **Name** | Display | Agent identifier |
| **Description** | Display | What agent does |
| **Source** | Display | Built-in, Plugin, Custom |
| **Available Tools** | Display | Tools agent can access |
| **Model Override** | Enum | Default, Sonnet, Opus, Haiku |
| **Custom Instructions** | Text | Additional system prompt |

#### Custom Agent Creation

| Field | Type | Description |
|-------|------|-------------|
| **Agent Name** | Text | Unique identifier |
| **Display Name** | Text | Human-readable name |
| **Description** | Text | Agent purpose |
| **System Prompt** | Code Editor | Custom instructions |
| **Allowed Tools** | Multi-select | Tools agent can use |
| **Default Model** | Enum | Preferred model |
| **Max Turns** | Number | Maximum conversation turns |
| **Temperature** | Slider | 0.0 - 1.0 |

### 2.5 Skills Management

#### Skills Overview Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ Skills                                      [+ Create] [Refresh]│
├─────────────────────────────────────────────────────────────────┤
│ ☑ commit                                              [Built-in]│
│   Generate commit messages and commit changes                   │
│   Trigger: /commit                                              │
├─────────────────────────────────────────────────────────────────┤
│ ☑ review-pr                                           [Built-in]│
│   Review pull request for issues                                │
│   Trigger: /review-pr                                           │
├─────────────────────────────────────────────────────────────────┤
│ ☑ ui-ux-pro-max                                         [Custom]│
│   UI/UX design intelligence                                     │
│   Trigger: /ui-design                                           │
├─────────────────────────────────────────────────────────────────┤
│ ☑ backend-dev-guidelines                                [Custom]│
│   Backend development patterns                                  │
│   Trigger: /backend                                             │
└─────────────────────────────────────────────────────────────────┘
```

#### Skill CRUD Operations

**Create Skill:**

| Field | Type | Description |
|-------|------|-------------|
| **Skill Name** | Text | Unique identifier (kebab-case) |
| **Display Name** | Text | Human-readable name |
| **Description** | Text | When to use this skill |
| **Trigger** | Text | Slash command (e.g., `/my-skill`) |
| **Content** | Code Editor | Markdown content with instructions |
| **Scope** | Enum | Global, Project, Directory |
| **Auto-invoke** | Bool | Automatically suggest when relevant |
| **Tags** | Tags | Categorization |

**Skill Content Editor:**

```markdown
---
name: my-custom-skill
description: When to trigger this skill
---

# My Custom Skill

## Instructions

[Your detailed instructions here...]

## Checklist

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

## Examples

<example>
User: "..."
Assistant: "..."
</example>
```

#### Skill Import/Export

| Action | Description |
|--------|-------------|
| **Export Skill** | Save skill as .md file |
| **Export All Skills** | Export as skill pack |
| **Import Skill** | Load from .md file |
| **Import from URL** | Fetch skill from URL |
| **Duplicate Skill** | Create copy for editing |

#### Skill Discovery

| Feature | Description |
|---------|-------------|
| **Browse Community Skills** | Gallery of shared skills |
| **Search Skills** | Find by name, tag, description |
| **Skill Ratings** | Community ratings (future) |
| **Install from Gallery** | One-click install |

### 2.6 MCP Servers Management

#### MCP Servers Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ MCP Servers                                 [+ Add] [Scan]      │
├─────────────────────────────────────────────────────────────────┤
│ ● filesystem                                          [Running] │
│   Local filesystem access                                       │
│   Tools: read_file, write_file, list_directory                  │
│   Resources: file://                                            │
│                                        [Configure] [Stop] [Logs]│
├─────────────────────────────────────────────────────────────────┤
│ ● context7                                            [Running] │
│   Library documentation lookup                                  │
│   Tools: resolve-library-id, get-library-docs                   │
│                                        [Configure] [Stop] [Logs]│
├─────────────────────────────────────────────────────────────────┤
│ ○ postgres                                            [Stopped] │
│   PostgreSQL database access                                    │
│   Tools: query, list_tables                                     │
│                                       [Configure] [Start] [Logs]│
└─────────────────────────────────────────────────────────────────┘
```

#### MCP Server CRUD

**Add MCP Server:**

| Field | Type | Description |
|-------|------|-------------|
| **Name** | Text | Server identifier |
| **Type** | Enum | stdio, HTTP, WebSocket |
| **Command** | Text | Command to start server |
| **Arguments** | Array | Command arguments |
| **Working Directory** | Path | CWD for server |
| **Environment Variables** | Key-Value | Custom env vars |
| **Auto-start** | Bool | Start with app |
| **Restart on Failure** | Bool | Auto-restart |
| **Scope** | Enum | Global, Project-specific |

**Server Configuration:**

```json
{
  "name": "my-mcp-server",
  "type": "stdio",
  "command": "node",
  "args": ["./server.js"],
  "cwd": "/path/to/server",
  "env": {
    "API_KEY": "${secrets.MY_API_KEY}"
  },
  "autoStart": true,
  "restartOnFailure": true
}
```

#### MCP Tools & Resources

| Tab | Content |
|-----|---------|
| **Tools** | List of available tools with descriptions |
| **Resources** | Available resources (files, URIs) |
| **Prompts** | Pre-defined prompts from server |
| **Logs** | Server stdout/stderr |
| **Health** | Connection status, uptime, errors |

### 2.7 Allowed Tools Configuration

#### Tools Allowlist

```
┌─────────────────────────────────────────────────────────────────┐
│ Allowed Tools                                      [Presets ▼]  │
├─────────────────────────────────────────────────────────────────┤
│ Core Tools                                                      │
│  ☑ Read         ☑ Write        ☑ Edit         ☑ Glob           │
│  ☑ Grep         ☑ LS           ☑ Bash         ☐ WebSearch      │
│  ☑ WebFetch     ☑ TodoWrite    ☐ Task                          │
├─────────────────────────────────────────────────────────────────┤
│ MCP Tools                                                       │
│  ☑ filesystem/*                                                 │
│  ☑ context7/resolve-library-id                                  │
│  ☑ context7/get-library-docs                                    │
│  ☐ postgres/*                                                   │
├─────────────────────────────────────────────────────────────────┤
│ Dangerous Tools (require confirmation)                          │
│  ☑ Bash (with pattern restrictions)                             │
│  ☐ Full Bash (no restrictions)                                  │
│  ☐ KillShell                                                    │
└─────────────────────────────────────────────────────────────────┘
```

#### Tool Presets

| Preset | Tools Enabled |
|--------|---------------|
| **Safe** | Read, Glob, Grep, LS, WebFetch |
| **Standard** | All except WebSearch, dangerous MCP |
| **Full** | All tools enabled |
| **Read-Only** | Read, Glob, Grep, LS only |
| **Custom** | User-defined selection |

#### Per-Tool Settings

| Tool | Settings |
|------|----------|
| **Bash** | Blocked patterns, require confirmation patterns, max execution time |
| **Write** | Blocked file patterns (e.g., `**/.env*`) |
| **WebFetch** | Allowed domains, blocked domains |
| **WebSearch** | Max results, blocked domains |

### 2.8 Context & Memory Settings

#### Context Management

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Max Context Tokens** | Number | Model limit | Model default |
| **Show Context Budget** | Bool | Display in sidebar | Enabled |
| **Context Warning Threshold** | Percent | Warn at % used | 80% |
| **Auto-Compact Threshold** | Percent | Trigger compaction | 90% |
| **Pre-Compact Action** | Enum | Warn, Auto-summarize, None | Warn |

#### Memory Layer Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Enable Local Memory** | Bool | Pin/retrieve context | Enabled |
| **Memory Storage Location** | Path | Where to store memories | ~/.cogit0-blaze/memory |
| **Auto-Pin Important Items** | Bool | Automatically pin | Disabled |
| **Memory Retrieval Count** | Number | Items to retrieve | 5 |
| **Show Retrieval Sources** | Bool | Display why retrieved | Enabled |

#### Session Continuity

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Continuity Mode** | Enum | Full History, Summary, Minimal | Summary |
| **Include Tool Outputs** | Bool | In continuity context | Enabled |
| **Include Diffs** | Bool | In continuity context | Enabled |
| **Max History Turns** | Number | Turns to include | 20 |

### 2.9 Model & Generation Settings

#### Model Selection

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Default Model** | Enum | Claude Sonnet, Claude Opus, Claude Haiku | Sonnet |
| **Allow Model Override** | Bool | Per-session model switching | Enabled |
| **Show Model in Chat** | Bool | Display active model | Enabled |

#### Generation Parameters

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Temperature** | Slider | 0.0 - 1.0 | Engine default |
| **Max Tokens** | Number | Output limit | Model default |
| **Max Turns** | Number | Per-session limit | Unlimited |
| **Stop Sequences** | Array | Custom stop strings | None |

### 2.10 Master Prompt / System Instructions

#### System Prompt Overview

The Master Prompt (also called System Instructions) is prepended to every session, allowing you to customize Claude's behavior, coding style, and project-specific context globally or per-project.

#### System Prompt Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ System Instructions                              [Templates ▼]  │
├─────────────────────────────────────────────────────────────────┤
│ Scope: ○ Global  ● Project: ~/Projects/my-app  ○ Session Only  │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ # Project Context                                           │ │
│ │                                                             │ │
│ │ You are working on a Next.js 15 application with:          │ │
│ │ - TypeScript strict mode                                    │ │
│ │ - Tailwind CSS for styling                                  │ │
│ │ - Prisma for database access                                │ │
│ │ - React Query for data fetching                             │ │
│ │                                                             │ │
│ │ ## Coding Standards                                         │ │
│ │ - Use functional components with hooks                      │ │
│ │ - Prefer named exports                                      │ │
│ │ - Write tests for all new functions                         │ │
│ │ - Use `pnpm` as package manager                             │ │
│ │                                                             │ │
│ │ ## File Structure                                           │ │
│ │ - Components in `src/components/`                           │ │
│ │ - API routes in `src/app/api/`                              │ │
│ │ - Utilities in `src/lib/`                                   │ │
│ │                                                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Token count: 847 tokens                    [Preview] [Save]     │
└─────────────────────────────────────────────────────────────────┘
```

#### System Prompt Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Enable System Prompt** | Bool | Enable/Disable | Enabled |
| **Prompt Scope** | Enum | Global, Per-Project, Per-Session | Global |
| **Show in Context Budget** | Bool | Display token count | Enabled |
| **Prompt Position** | Enum | Before CLAUDE.md, After CLAUDE.md | Before |
| **Allow Session Override** | Bool | Modify per-session | Enabled |

#### Prompt Composition (Order)

```
1. [Master Prompt - Global]           ← Your global instructions
2. [Master Prompt - Project]          ← Project-specific overrides
3. [CLAUDE.md from repo]              ← Auto-loaded from project
4. [Session-specific instructions]    ← Added at session start
5. [Context from memory layer]        ← Retrieved relevant context
6. [Conversation history]             ← Previous messages
```

#### System Prompt Editor Features

| Feature | Description |
|---------|-------------|
| **Syntax Highlighting** | Markdown highlighting in editor |
| **Token Counter** | Live token count display |
| **Preview Mode** | See rendered markdown |
| **Variables** | `{{PROJECT_NAME}}`, `{{DATE}}`, `{{USER}}` |
| **Include Files** | `@include: ./prompts/coding-style.md` |
| **Conditional Sections** | `{{#if language:python}}...{{/if}}` |

#### Prompt Templates Library

| Template | Description |
|----------|-------------|
| **Blank** | Start from scratch |
| **Full-Stack Web** | Next.js, React, Node.js standards |
| **Python Backend** | FastAPI, Django, typing standards |
| **Mobile (React Native)** | RN, Expo best practices |
| **Mobile (Swift)** | iOS, SwiftUI conventions |
| **Data Science** | Jupyter, pandas, ML patterns |
| **DevOps** | Terraform, Docker, CI/CD |
| **Security-Focused** | OWASP, secure coding practices |

#### Project-Specific Prompts

```
┌─────────────────────────────────────────────────────────────────┐
│ Project Prompts                                        [+ Add]  │
├─────────────────────────────────────────────────────────────────┤
│ ~/Projects/my-app                                               │
│   System prompt: 847 tokens                    [Edit] [Delete]  │
├─────────────────────────────────────────────────────────────────┤
│ ~/Projects/backend-api                                          │
│   System prompt: 1,203 tokens                  [Edit] [Delete]  │
├─────────────────────────────────────────────────────────────────┤
│ ~/Projects/mobile-app                                           │
│   System prompt: 562 tokens                    [Edit] [Delete]  │
└─────────────────────────────────────────────────────────────────┘
```

#### Import/Export

| Action | Description |
|--------|-------------|
| **Export Prompt** | Save as .md file |
| **Import Prompt** | Load from .md file |
| **Sync with CLAUDE.md** | Push to repo's CLAUDE.md |
| **Pull from CLAUDE.md** | Import from repo's CLAUDE.md |
| **Share Prompt** | Generate shareable link (future) |

### 2.11 Policy Engine Configuration

#### Policy Management

```
┌─────────────────────────────────────────────────────────────────┐
│ Policies                                [+ Create] [Import]     │
├─────────────────────────────────────────────────────────────────┤
│ ● Safe Default (Active)                              [Built-in] │
│   Blocks .env writes, requires confirm for git push             │
│   Rules: 5  |  Scope: Global                                    │
│                                         [View] [Duplicate] [Set]│
├─────────────────────────────────────────────────────────────────┤
│ ○ Paranoid                                           [Built-in] │
│   Maximum restrictions, confirm everything                      │
│   Rules: 12  |  Scope: Global                                   │
│                                         [View] [Duplicate] [Set]│
├─────────────────────────────────────────────────────────────────┤
│ ○ Work Projects                                        [Custom] │
│   Custom rules for ~/Projects/work/*                            │
│   Rules: 8  |  Scope: ~/Projects/work/*                         │
│                                    [View] [Edit] [Delete] [Set] │
└─────────────────────────────────────────────────────────────────┘
```

#### Policy Rule Editor

**Rule Types:**

| Rule Type | Parameters |
|-----------|------------|
| **deny_file_write** | glob pattern, reason |
| **deny_file_read** | glob pattern, reason |
| **deny_bash** | command pattern (regex), reason |
| **require_confirm_bash** | command pattern, reason |
| **allow_bash** | command pattern (whitelist) |
| **deny_tool** | tool name, reason |
| **require_confirm_tool** | tool name, reason |
| **deny_mcp** | server/tool pattern, reason |

**Rule Editor UI:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Edit Rule                                                       │
├─────────────────────────────────────────────────────────────────┤
│ Type:     [deny_file_write          ▼]                          │
│                                                                 │
│ Pattern:  [**/.env*                   ]                         │
│                                                                 │
│ Reason:   [Secrets file - never write to .env files]           │
│                                                                 │
│ Priority: [1    ] (lower = higher priority)                     │
│                                                                 │
│ Overridable: [☑] Allow user to approve anyway                   │
│                                                                 │
│                                          [Cancel] [Save Rule]   │
└─────────────────────────────────────────────────────────────────┘
```

#### Policy Templates

| Template | Description |
|----------|-------------|
| **Minimal** | No restrictions |
| **Safe Default** | Block .env, confirm git push |
| **Paranoid** | Confirm everything risky |
| **Read-Only** | Block all writes |
| **No Network** | Block web tools |
| **Production Safe** | Block prod paths, force confirm deploys |

### 2.11 Output & Logging

#### Session Logging

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Log Level** | Enum | Debug, Info, Warn, Error | Info |
| **Log Location** | Path | Log file directory | ~/.cogit0-blaze/logs |
| **Log Rotation** | Enum | Daily, Weekly, Size-based | Daily |
| **Max Log Size** | Number | MB per file | 100 |
| **Log Retention** | Number | Days to keep | 30 |

#### Event Export

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Export Format** | Enum | JSON, Markdown, HTML | JSON |
| **Include Tool Outputs** | Bool | Full outputs in export | Enabled |
| **Include Diffs** | Bool | Full diffs in export | Enabled |
| **Redact Secrets** | Bool | Scrub sensitive data | Enabled |

### 2.12 Advanced Settings

#### CLI Invocation

| Setting | Type | Description | Default |
|---------|------|-------------|---------|
| **Extra CLI Arguments** | Text | Additional args for claude command | None |
| **Environment Passthrough** | Multi-select | Env vars to pass to CLI | PATH, HOME |
| **Custom Working Directory** | Path | Override project cwd | None |
| **Shell** | Enum | /bin/zsh, /bin/bash, custom | /bin/zsh |

#### Experimental Features

| Setting | Type | Description | Default |
|---------|------|-------------|---------|
| **Enable Experimental** | Bool | Access beta features | Disabled |
| **Multi-Agent Mode** | Bool | Run parallel agents | Disabled |
| **Consensus Mode** | Bool | Require agent agreement | Disabled |
| **Local Vector Search** | Bool | Semantic memory search | Disabled |

#### Debug Settings

| Setting | Type | Description | Default |
|---------|------|-------------|---------|
| **Show Raw Events** | Bool | Display raw NDJSON | Disabled |
| **Log CLI Commands** | Bool | Log exact CLI invocations | Disabled |
| **Performance Metrics** | Bool | Show timing data | Disabled |
| **Export Debug Bundle** | Action | Generate support bundle | - |

### 2.15 Observability & Analytics Dashboard

The Observability panel provides beautiful, real-time visualizations of Claude Code's performance, token usage, session metrics, and long-running agentic behavior.

#### Dashboard Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Observability                                    [Today ▼] [Export] [⟳]    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │ Sessions Today  │  │ Tokens Used     │  │ Avg Session     │             │
│  │      12         │  │    847,293      │  │    23m 47s      │             │
│  │   ↑ 20% vs avg  │  │   ↓ 5% vs avg   │  │   ↑ 15% vs avg  │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                             │
│  Token Usage Over Time                                         [7 days ▼]  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │     ▂                                                               │   │
│  │    ▄█▂      ▂                                                       │   │
│  │   ▆███▄    ▄█▂         ▂▄                                           │   │
│  │  ▇█████▆  ▆███▂      ▄████▄         ▂                               │   │
│  │ ████████▇███████▆▄▂▆███████▆▄▂    ▄███▂                             │   │
│  │ █████████████████████████████████▇██████▆▄                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│    Mon     Tue     Wed     Thu     Fri     Sat     Sun                     │
│                                                                             │
│  ■ Input Tokens  ■ Output Tokens  ■ Cached Tokens                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Token Usage Analytics

##### Real-Time Token Display

```
┌─────────────────────────────────────────────────────────────────┐
│ Token Usage                                        [This Month] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Total Tokens                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ████████████████████████████░░░░░░░░░░  6.2M / 10M      │   │
│  └─────────────────────────────────────────────────────────┘   │
│  62% of monthly limit  •  Resets in 7 days                     │
│                                                                 │
│  Breakdown                                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Input Tokens     ████████████░░░░░░░░░  3.1M  (50%)     │  │
│  │ Output Tokens    ██████░░░░░░░░░░░░░░░  1.8M  (29%)     │  │
│  │ Cached Tokens    ████░░░░░░░░░░░░░░░░░  1.3M  (21%)     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Daily Average: 207,433 tokens                                  │
│  Projected End of Month: 8.3M tokens                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Token Usage by Category

| Metric | Description | Visualization |
|--------|-------------|---------------|
| **By Session** | Tokens per session | Bar chart |
| **By Project** | Tokens by project | Pie chart |
| **By Model** | Sonnet vs Opus vs Haiku | Stacked bar |
| **By Tool** | Tokens consumed by tool calls | Horizontal bars |
| **By Time** | Hourly/daily/weekly trends | Line chart |

##### Token Breakdown Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ Token Breakdown by Project                         [This Week] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ~/Projects/my-app              ████████████████  412,847  45% │
│  ~/Projects/backend-api         ████████░░░░░░░░  198,234  22% │
│  ~/Projects/mobile-app          █████░░░░░░░░░░░  156,721  17% │
│  ~/Projects/docs                ███░░░░░░░░░░░░░   89,432  10% │
│  Other                          █░░░░░░░░░░░░░░░   54,231   6% │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Performance Metrics

##### Response Time Analytics

```
┌─────────────────────────────────────────────────────────────────┐
│ Response Times                                      [Last 24h] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Time to First Token (TTFT)                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         ▂▃▄▅▆▇█▇▆▅▄▃▂                                   │   │
│  │     ▂▄▆████████████████▆▄▂                              │   │
│  │  ▂▅█████████████████████████▅▂                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│     0ms    500ms    1s    1.5s    2s    2.5s    3s             │
│                                                                 │
│  Median: 847ms  •  P95: 2.1s  •  P99: 3.4s                     │
│                                                                 │
│  Total Response Time                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │      ▂▃▄▅▆▇█▇▆▅▄▃▂                                      │   │
│  │  ▂▄▆███████████████▆▄▂                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│     0s      5s      10s     15s     20s     25s     30s        │
│                                                                 │
│  Median: 8.2s  •  P95: 18.4s  •  P99: 32.1s                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Performance Metrics Table

| Metric | Description | Target |
|--------|-------------|--------|
| **Time to First Token (TTFT)** | Latency before streaming starts | < 1s |
| **Tokens per Second** | Streaming output speed | > 50 t/s |
| **Total Response Time** | Full turn completion | Varies |
| **Tool Execution Time** | Average tool call duration | < 5s |
| **Session Start Time** | Time to initialize session | < 2s |

##### Tool Performance Breakdown

```
┌─────────────────────────────────────────────────────────────────┐
│ Tool Performance                                   [Last 7 days]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Tool              Calls    Avg Time    Success    Total Time   │
│  ─────────────────────────────────────────────────────────────  │
│  Read              1,247      45ms       100%        56.1s      │
│  Edit                892     123ms        98%       109.7s      │
│  Bash                456     2.4s         94%      1094.4s      │
│  Glob                723      89ms       100%        64.3s      │
│  Grep                534     156ms       100%        83.3s      │
│  Write               234     201ms        97%        47.0s      │
│  WebFetch             89     1.8s         91%       160.2s      │
│  Task (Agent)         45    12.3s         89%       553.5s      │
│                                                                 │
│  [View Details] [Export CSV]                                    │
└─────────────────────────────────────────────────────────────────┘
```

#### Session Analytics

##### Session Duration & Activity

```
┌─────────────────────────────────────────────────────────────────┐
│ Session Analytics                                  [This Month] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Session Duration Distribution                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    ▂▄▆█▇▅▃▂                             │   │
│  │               ▂▄▆████████████▆▄▂                        │   │
│  │           ▂▅████████████████████████▅▂                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│     0m    15m    30m    45m    1h    1.5h    2h    3h+         │
│                                                                 │
│  Average Duration: 23m 47s                                      │
│  Longest Session: 4h 12m (Project: ~/Projects/refactor)        │
│  Total Active Time: 47h 23m                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Long-Running Agentic Sessions

```
┌─────────────────────────────────────────────────────────────────┐
│ Long-Running Sessions                              [Active Now] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🟢 ACTIVE: Refactoring auth system                             │
│     Duration: 2h 47m 23s  •  Turns: 47  •  Tools: 234          │
│     Project: ~/Projects/backend-api                             │
│     Status: Running tests after edit                            │
│     Tokens: 1.2M input, 847K output                             │
│     ┌───────────────────────────────────────────────────────┐  │
│     │ ████████████████████████████████░░░░░░  78% complete  │  │
│     └───────────────────────────────────────────────────────┘  │
│     [View] [Pause] [Stop]                                       │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  🟡 PAUSED: Database migration                                  │
│     Duration: 1h 12m  •  Turns: 23  •  Awaiting approval       │
│     [Resume] [Abort]                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Session Metrics

| Metric | Description |
|--------|-------------|
| **Total Sessions** | Count of sessions in period |
| **Average Duration** | Mean session length |
| **Longest Session** | Maximum uninterrupted runtime |
| **Sessions by Project** | Distribution across projects |
| **Sessions by Time of Day** | When you're most active |
| **Completion Rate** | Sessions that achieved goal |
| **Interruption Rate** | Sessions cancelled or errored |

#### Agentic Behavior Analytics

##### Autonomous Operation Metrics

```
┌─────────────────────────────────────────────────────────────────┐
│ Agentic Performance                                [This Week] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Autonomy Metrics                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Avg Turns per Session      ████████████░░░░░  18.4       │  │
│  │ Avg Tools per Turn         ████░░░░░░░░░░░░░   3.2       │  │
│  │ Uninterrupted Sequences    █████████░░░░░░░░  12.7       │  │
│  │ Self-Correction Rate       ██████░░░░░░░░░░░  23%        │  │
│  │ Task Completion Rate       ████████████████░  89%        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Longest Uninterrupted Run: 47 turns (2h 12m)                   │
│  Most Tools in Single Turn: 12 tools                            │
│  Highest Token Session: 2.3M tokens                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Agentic Flow Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│ Session Flow: "Implement user authentication"                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐          │
│  │Plan │───▶│Read │───▶│Edit │───▶│Test │───▶│Fix  │──┐       │
│  │     │    │x12  │    │x8   │    │     │    │     │  │       │
│  └─────┘    └─────┘    └─────┘    └─────┘    └─────┘  │       │
│                                                        │       │
│       ┌────────────────────────────────────────────────┘       │
│       │                                                         │
│       ▼                                                         │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐                      │
│  │Test │───▶│Pass │───▶│Commit│───▶│Done │                      │
│  │     │    │  ✓  │    │     │    │  ✓  │                      │
│  └─────┘    └─────┘    └─────┘    └─────┘                      │
│                                                                 │
│  Duration: 34m 12s  |  Turns: 23  |  Tools: 89  |  Tokens: 456K│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Error & Recovery Analytics

##### Error Tracking

```
┌─────────────────────────────────────────────────────────────────┐
│ Errors & Recovery                                  [Last 7 days]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Error Rate Over Time                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     ▂                                    │   │
│  │  ▂      ▂    ▂    ▄█▂         ▂                         │   │
│  │ ▄█▂    ▄█▂  ▄█▂  ▆███▂      ▄██▂                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│    Mon    Tue    Wed    Thu    Fri    Sat    Sun               │
│                                                                 │
│  Error Breakdown                                                │
│  ─────────────────────────────────────────────────────────────  │
│  Tool Failures         ████████████░░░░░   47  (58%)           │
│  Rate Limits           ████░░░░░░░░░░░░░   15  (19%)           │
│  Timeout Errors        ███░░░░░░░░░░░░░░   12  (15%)           │
│  Parse Errors          █░░░░░░░░░░░░░░░░    4  (5%)            │
│  Auth Errors           █░░░░░░░░░░░░░░░░    3  (4%)            │
│                                                                 │
│  Recovery Rate: 89% of errors auto-recovered                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Error Details Table

| Error Type | Count | Recovery Rate | Common Cause |
|------------|-------|---------------|--------------|
| **Tool Failure** | 47 | 92% | Test failures, lint errors |
| **Rate Limit** | 15 | 100% | High usage periods |
| **Timeout** | 12 | 67% | Long-running bash commands |
| **Parse Error** | 4 | 50% | Malformed CLI output |
| **Auth Error** | 3 | 100% | Token expiry |

#### Cost Analytics (Estimated)

##### Cost Tracking

```
┌─────────────────────────────────────────────────────────────────┐
│ Estimated Costs                                    [This Month] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Total Estimated Cost: $47.23                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ████████████████████████████░░░░░░░░░░  $47 / $100 cap  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  By Model                                                       │
│  ─────────────────────────────────────────────────────────────  │
│  Claude Sonnet        █████████████████░░   $34.21  (72%)      │
│  Claude Opus          █████░░░░░░░░░░░░░░   $11.87  (25%)      │
│  Claude Haiku         █░░░░░░░░░░░░░░░░░░    $1.15  (3%)       │
│                                                                 │
│  Daily Trend                                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │      ▂▄▆█▇▅▃▂                                           │   │
│  │  ▂▄▆███████████▆▄▂                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│    $0    $2    $4    $6    $8    $10                           │
│                                                                 │
│  Average Daily: $1.89  |  Projected Month-End: $58.59          │
│                                                                 │
│  ⚠️ Note: Costs are estimates based on public API pricing.     │
│     Actual costs depend on your plan (Pro/Max/Team).            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Observability Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| **Enable Analytics** | Bool | Track usage metrics | Enabled |
| **Data Retention** | Enum | 7 days, 30 days, 90 days, 1 year | 30 days |
| **Show Cost Estimates** | Bool | Display cost analytics | Enabled |
| **Cost Alert Threshold** | Number | Alert at $ amount | $50 |
| **Dashboard Refresh** | Enum | Real-time, 1m, 5m, Manual | 1m |
| **Show in Menu Bar** | Bool | Quick stats in menu bar | Disabled |
| **Export Format** | Enum | JSON, CSV, PDF | CSV |

#### Menu Bar Widget (Optional)

```
┌─────────────────────────────────────────┐
│  ◉ Blaze                                │
├─────────────────────────────────────────┤
│  Today: 3 sessions  |  127K tokens      │
│  Active: Refactoring... (47m)           │
│  ────────────────────────────────────── │
│  This Month: 6.2M / 10M tokens (62%)    │
│  Est. Cost: $47.23                      │
│  ────────────────────────────────────── │
│  [Open Dashboard]  [New Session]        │
└─────────────────────────────────────────┘
```

#### Export & Reporting

| Action | Description |
|--------|-------------|
| **Export Dashboard** | Save current view as PDF/PNG |
| **Export Raw Data** | Download metrics as CSV/JSON |
| **Schedule Reports** | Weekly/monthly email reports |
| **Share Dashboard** | Generate shareable link (future) |
| **API Access** | Programmatic access to metrics |

---

## Part 3: Settings Storage & Sync

### 3.1 Storage Locations

| Settings Type | Location | Format |
|---------------|----------|--------|
| **App Settings** | `~/Library/Preferences/com.cogit0.blaze.plist` | Property List |
| **Claude Code Settings** | `~/.cogit0-blaze/settings.json` | JSON |
| **Hooks** | `~/.cogit0-blaze/hooks/` | JSON + Scripts |
| **Skills** | `~/.cogit0-blaze/skills/` | Markdown |
| **Policies** | `~/.cogit0-blaze/policies/` | JSON |
| **Custom Agents** | `~/.cogit0-blaze/agents/` | JSON |

### 3.2 Settings Sync (Future)

| Feature | Description |
|---------|-------------|
| **iCloud Sync** | Sync settings across Macs |
| **Export All Settings** | Full configuration export |
| **Import Settings** | Restore from export |
| **Settings Profiles** | Named configuration sets |
| **Team Settings** | Shared team configurations (enterprise) |

### 3.3 Settings Reset

| Action | Scope |
|--------|-------|
| **Reset App Settings** | Appearance, typography, shortcuts |
| **Reset Claude Settings** | Permissions, tools, model settings |
| **Reset All Hooks** | Remove all custom hooks |
| **Reset All Skills** | Remove all custom skills |
| **Reset All Policies** | Restore built-in policies |
| **Factory Reset** | Complete reset to defaults |

---

## Part 4: Settings UI Components

### 4.1 Navigation Structure

```
Settings Window
├── App Settings
│   ├── Appearance
│   ├── Typography
│   ├── Editor & Diff
│   ├── Keyboard Shortcuts
│   ├── Notifications
│   ├── Privacy
│   ├── Updates
│   ├── Window & Layout
│   └── Accessibility
│
├── Claude Code
│   ├── Account & Authentication     ← Login, plan, usage overview
│   ├── Permission Modes
│   ├── Hooks                        ← CRUD hooks
│   ├── Agents                       ← Enable/disable, CRUD agents
│   ├── Skills                       ← CRUD skills
│   ├── MCP Servers                  ← CRUD MCP servers
│   ├── Allowed Tools
│   ├── Context & Memory
│   ├── Model Settings
│   ├── System Instructions          ← Master prompt / system prompt
│   ├── Policies                     ← CRUD policy rules
│   ├── Logging
│   └── Advanced
│
├── Observability                    ← Beautiful analytics dashboard
│   ├── Dashboard Overview
│   ├── Token Usage
│   ├── Performance Metrics
│   ├── Session Analytics
│   ├── Agentic Behavior
│   ├── Errors & Recovery
│   ├── Cost Estimates
│   └── Export & Reports
│
└── About
    ├── Version Info
    ├── Licenses
    ├── Support
    └── Feedback
```

### 4.2 Search in Settings

- Global search across all settings
- Fuzzy matching for setting names and descriptions
- Jump to setting location
- Recent searches

### 4.3 Settings Diff (What Changed)

- Show modified settings vs defaults
- Export changes as JSON
- Reset individual settings to default

---

## Appendix A: Default Values Summary

### App Defaults

```json
{
  "appearance": {
    "colorScheme": "system",
    "accentColor": "systemBlue",
    "sidebarStyle": "default"
  },
  "typography": {
    "uiFontSize": 13,
    "chatFontSize": 14,
    "codeFontFamily": "SF Mono",
    "codeFontSize": 12
  },
  "notifications": {
    "enabled": true,
    "sessionComplete": true,
    "toolFailure": true,
    "approvalRequired": true
  }
}
```

### Claude Code Defaults

```json
{
  "trustMode": "review",
  "contextWarningThreshold": 0.8,
  "defaultModel": "sonnet",
  "continuityMode": "summary",
  "logLevel": "info",
  "enableLocalMemory": true
}
```

---

## Appendix B: Keyboard Shortcut Defaults

| Category | Action | Shortcut |
|----------|--------|----------|
| **Navigation** | Command Palette | ⌘K |
| | New Session | ⌘N |
| | Settings | ⌘, |
| **Chat** | Send Message | ⌘↵ |
| | Cancel Run | ⌘. |
| | Focus Input | ⌘L |
| **View** | Toggle Sidebar | ⌘\ |
| | Toggle Timeline | ⌘T |
| | Toggle Diff Viewer | ⌘D |
| **Edit** | Copy Last Response | ⌘⇧C |
| | Accept All Diffs | ⌘⇧A |
| | Reject All Diffs | ⌘⇧R |

---

**End of Document**
