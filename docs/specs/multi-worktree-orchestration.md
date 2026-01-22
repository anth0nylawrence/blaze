# Multi-Worktree Orchestration Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

This specification defines how Blaze integrates with Git worktrees to enable parallel development workflows. Users can create isolated worktrees for different tasks, run separate AI sessions in each, and merge changes back safely.

**Why This Matters:** Power users often work on multiple features simultaneously. Worktrees provide true isolation without branch switching overhead.

---

## Table of Contents

1. [Core Concepts](#1-core-concepts)
2. [Worktree Lifecycle](#2-worktree-lifecycle)
3. [Session Integration](#3-session-integration)
4. [UI Design](#4-ui-design)
5. [Merge Workflows](#5-merge-workflows)
6. [Implementation](#6-implementation)

---

## 1. Core Concepts

### 1.1 What is a Git Worktree?

A **worktree** is a separate working directory linked to the same Git repository. Each worktree can have a different branch checked out, allowing parallel development without stashing or switching.

```
Main Repository: ~/projects/my-app/
├── .git/                          # Shared Git data
├── src/                           # Main branch working files
└── ...

Worktree 1: ~/projects/my-app-worktrees/feature-auth/
├── src/                           # feature/auth branch
└── ...

Worktree 2: ~/projects/my-app-worktrees/bugfix-123/
├── src/                           # bugfix/issue-123 branch
└── ...
```

### 1.2 Blaze Worktree Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                     BLAZE WORKTREE ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Project (~/projects/my-app)                                        │
│     │                                                                │
│     ├─── Main Worktree (default)                                    │
│     │    └─── Session: "General development"                        │
│     │                                                                │
│     ├─── Task Worktree: "Add authentication"                        │
│     │    ├─── Branch: feature/auth                                  │
│     │    ├─── Path: ~/.cogit0-blaze/worktrees/my-app/feature-auth   │
│     │    └─── Session: "Implement OAuth flow"                       │
│     │                                                                │
│     └─── Task Worktree: "Fix login bug"                             │
│          ├─── Branch: bugfix/issue-123                              │
│          ├─── Path: ~/.cogit0-blaze/worktrees/my-app/bugfix-123     │
│          └─── Session: "Debug login failure"                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 Benefits

| Benefit | Description |
|---------|-------------|
| **True Isolation** | Changes in one worktree don't affect others |
| **Parallel AI Work** | Multiple Claude sessions on different features |
| **Quick Context Switch** | No stashing, no branch switching |
| **Safe Experimentation** | Discard worktree if experiment fails |
| **Team Collaboration** | Share worktrees across team members |

---

## 2. Worktree Lifecycle

### 2.1 State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WORKTREE STATE MACHINE                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                      ┌───────────┐                                  │
│                      │ Creating  │                                  │
│                      └─────┬─────┘                                  │
│                            │ git worktree add                       │
│                            ▼                                         │
│     ┌──────────────────────────────────────────────────┐            │
│     │                    Active                         │            │
│     │  ┌──────────┐                    ┌──────────┐    │            │
│     │  │  Clean   │◀──────────────────▶│  Dirty   │    │            │
│     │  └────┬─────┘    file changes    └────┬─────┘    │            │
│     │       │                               │          │            │
│     │       │ merge/discard                 │ commit   │            │
│     │       ▼                               ▼          │            │
│     └──────────────────────────────────────────────────┘            │
│                            │                                         │
│              ┌─────────────┼─────────────┐                          │
│              │             │             │                          │
│              ▼             ▼             ▼                          │
│        ┌──────────┐  ┌──────────┐  ┌──────────┐                     │
│        │  Merged  │  │ Archived │  │ Deleted  │                     │
│        └──────────┘  └──────────┘  └──────────┘                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Worktree Operations

| Operation | Git Command | Blaze Action |
|-----------|-------------|--------------|
| **Create** | `git worktree add` | Create worktree + session |
| **List** | `git worktree list` | Show in project sidebar |
| **Switch** | Change active tab | Switch session context |
| **Prune** | `git worktree prune` | Clean up stale references |
| **Remove** | `git worktree remove` | Archive or delete worktree |

### 2.3 Creation Flow

```swift
struct WorktreeCreationRequest {
    let projectId: Project.ID
    let branchName: String          // New branch name
    let baseBranch: String?         // Branch to base on (default: current)
    let worktreeName: String?       // Human-readable name
    let createSession: Bool         // Auto-create session?
    let sessionPrompt: String?      // Initial prompt for session
}

func createWorktree(_ request: WorktreeCreationRequest) async throws -> Worktree {
    let project = try await projectStore.get(request.projectId)

    // Step 1: Determine worktree path
    let worktreePath = blazeWorktreesPath
        .appendingPathComponent(project.name)
        .appendingPathComponent(request.branchName.sanitizedForPath)

    // Step 2: Create the git worktree
    let baseBranch = request.baseBranch ?? "HEAD"
    try await git.run([
        "worktree", "add",
        "-b", request.branchName,
        worktreePath.path,
        baseBranch
    ], in: project.path)

    // Step 3: Create Blaze worktree record
    let worktree = Worktree(
        id: UUID(),
        projectId: project.id,
        path: worktreePath,
        branchName: request.branchName,
        name: request.worktreeName ?? request.branchName,
        baseBranch: baseBranch,
        state: .active,
        createdAt: Date()
    )

    await worktreeStore.insert(worktree)

    // Step 4: Create session if requested
    if request.createSession {
        let session = try await sessionManager.createSession(
            project: project,
            worktree: worktree,
            name: worktree.name
        )

        if let prompt = request.sessionPrompt {
            try await sessionManager.send(message: prompt, to: session.id)
        }
    }

    return worktree
}
```

---

## 3. Session Integration

### 3.1 Session-Worktree Binding

Each session is bound to a specific worktree:

```swift
struct Session {
    let id: UUID
    let projectId: Project.ID
    let worktreeId: Worktree.ID?    // nil = main worktree
    let workingDirectory: URL       // Actual path for CLI
    // ...
}

extension Session {
    var isMainWorktree: Bool {
        worktreeId == nil
    }

    func resolveWorkingDirectory(project: Project, worktree: Worktree?) -> URL {
        if let worktree = worktree {
            return worktree.path
        }
        return project.path
    }
}
```

### 3.2 Context Inheritance

Sessions in worktrees can inherit context from parent:

```swift
struct WorktreeSessionConfig {
    let inheritSystemPrompt: Bool = true
    let inheritPolicies: Bool = true
    let inheritHistory: Bool = false    // Start fresh by default
    let inheritPinnedFiles: Bool = true
}

func createWorktreeSession(
    project: Project,
    worktree: Worktree,
    config: WorktreeSessionConfig
) async throws -> Session {
    var session = Session(
        projectId: project.id,
        worktreeId: worktree.id,
        workingDirectory: worktree.path
    )

    if config.inheritSystemPrompt {
        session.systemPrompt = project.defaultSystemPrompt
    }

    if config.inheritPolicies {
        session.policies = project.policies
    }

    if config.inheritPinnedFiles {
        // Copy pinned file references (not contents)
        session.pinnedFiles = project.pinnedFiles
    }

    // Add worktree context
    session.systemPrompt += """

    [WORKTREE CONTEXT]
    You are working in a git worktree:
    - Branch: \(worktree.branchName)
    - Based on: \(worktree.baseBranch)
    - Purpose: \(worktree.name)

    Changes in this worktree are isolated from the main branch.
    """

    return session
}
```

### 3.3 Cross-Worktree Operations

```swift
// Copy changes between worktrees
func copyChanges(
    from sourceWorktree: Worktree,
    to targetWorktree: Worktree,
    files: [String]
) async throws {
    for file in files {
        let sourcePath = sourceWorktree.path.appendingPathComponent(file)
        let targetPath = targetWorktree.path.appendingPathComponent(file)

        try FileManager.default.copyItem(at: sourcePath, to: targetPath)
    }

    // Stage changes in target
    try await git.run(["add"] + files, in: targetWorktree.path)
}

// Cherry-pick commits between worktrees
func cherryPick(
    commit: String,
    from sourceWorktree: Worktree,
    to targetWorktree: Worktree
) async throws {
    try await git.run(
        ["cherry-pick", commit],
        in: targetWorktree.path
    )
}
```

---

## 4. UI Design

### 4.1 Project Sidebar

```swift
struct ProjectSidebarView: View {
    let project: Project
    @State private var worktrees: [Worktree] = []
    @State private var selectedWorktreeId: Worktree.ID?

    var body: some View {
        List(selection: $selectedWorktreeId) {
            // Main worktree
            WorktreeRow(
                name: "Main",
                branch: project.currentBranch,
                isMain: true,
                state: .active
            )
            .tag(nil as Worktree.ID?)

            // Task worktrees
            Section("Worktrees") {
                ForEach(worktrees) { worktree in
                    WorktreeRow(
                        name: worktree.name,
                        branch: worktree.branchName,
                        isMain: false,
                        state: worktree.state
                    )
                    .tag(worktree.id as Worktree.ID?)
                    .contextMenu {
                        WorktreeContextMenu(worktree: worktree)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showCreateWorktreeSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct WorktreeRow: View {
    let name: String
    let branch: String
    let isMain: Bool
    let state: WorktreeState

    var body: some View {
        HStack {
            Image(systemName: isMain ? "folder.fill" : "arrow.branch")
                .foregroundColor(stateColor)

            VStack(alignment: .leading) {
                Text(name)
                    .fontWeight(isMain ? .semibold : .regular)
                Text(branch)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state == .dirty {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var stateColor: Color {
        switch state {
        case .creating: return .gray
        case .active: return .blue
        case .dirty: return .orange
        case .merged: return .green
        case .archived: return .secondary
        }
    }
}
```

### 4.2 Create Worktree Sheet

```swift
struct CreateWorktreeSheet: View {
    @Environment(\.dismiss) var dismiss
    let project: Project

    @State private var branchName = ""
    @State private var baseBranch = "main"
    @State private var worktreeName = ""
    @State private var taskDescription = ""
    @State private var createSession = true

    var body: some View {
        Form {
            Section("Branch") {
                TextField("Branch name", text: $branchName)
                    .textFieldStyle(.roundedBorder)

                Picker("Based on", selection: $baseBranch) {
                    ForEach(project.branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
            }

            Section("Task") {
                TextField("Name (e.g., 'Add authentication')", text: $worktreeName)

                TextEditor(text: $taskDescription)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }

            Section {
                Toggle("Create AI session", isOn: $createSession)

                if createSession && !taskDescription.isEmpty {
                    Text("Claude will start with: \"\(taskDescription)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { createWorktree() }
                    .disabled(branchName.isEmpty)
            }
        }
    }
}
```

### 4.3 Worktree Status Bar

```swift
struct WorktreeStatusBar: View {
    let worktree: Worktree
    @State private var gitStatus: GitStatus?

    var body: some View {
        HStack(spacing: 12) {
            // Branch indicator
            HStack(spacing: 4) {
                Image(systemName: "arrow.branch")
                Text(worktree.branchName)
                    .fontWeight(.medium)
            }

            Divider()
                .frame(height: 16)

            // Status indicators
            if let status = gitStatus {
                if status.ahead > 0 {
                    Label("\(status.ahead)↑", systemImage: "arrow.up")
                        .font(.caption)
                }
                if status.behind > 0 {
                    Label("\(status.behind)↓", systemImage: "arrow.down")
                        .font(.caption)
                }
                if status.hasChanges {
                    Label("\(status.changedFiles)", systemImage: "doc.badge.ellipsis")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Actions
            Button("Merge") {
                showMergeSheet = true
            }
            .buttonStyle(.bordered)
            .disabled(gitStatus?.hasChanges == true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}
```

---

## 5. Merge Workflows

### 5.1 Merge Strategies

| Strategy | Description | Best For |
|----------|-------------|----------|
| **Merge commit** | Standard merge with commit | Feature branches |
| **Squash** | Combine all commits into one | Small features |
| **Rebase** | Replay commits on top of base | Clean history |
| **Fast-forward** | Move pointer if possible | Simple updates |

### 5.2 Merge Flow

```swift
struct MergeWorkflow {
    let worktree: Worktree
    let targetBranch: String
    let strategy: MergeStrategy

    func execute() async throws -> MergeResult {
        // Step 1: Verify clean state
        let status = try await git.status(in: worktree.path)
        guard !status.hasUncommittedChanges else {
            throw MergeError.uncommittedChanges
        }

        // Step 2: Fetch latest
        try await git.run(["fetch", "origin"], in: worktree.path)

        // Step 3: Switch to target branch (in main worktree)
        let project = try await projectStore.get(worktree.projectId)
        try await git.run(["checkout", targetBranch], in: project.path)

        // Step 4: Perform merge
        let mergeArgs: [String]
        switch strategy {
        case .merge:
            mergeArgs = ["merge", worktree.branchName]
        case .squash:
            mergeArgs = ["merge", "--squash", worktree.branchName]
        case .rebase:
            mergeArgs = ["rebase", worktree.branchName]
        case .fastForward:
            mergeArgs = ["merge", "--ff-only", worktree.branchName]
        }

        do {
            try await git.run(mergeArgs, in: project.path)
        } catch {
            // Handle merge conflicts
            let conflicts = try await git.getConflicts(in: project.path)
            return .conflicts(conflicts)
        }

        // Step 5: Create squash commit if needed
        if strategy == .squash {
            try await git.run([
                "commit", "-m",
                "Merge \(worktree.name) (\(worktree.branchName))"
            ], in: project.path)
        }

        return .success
    }
}

enum MergeResult {
    case success
    case conflicts([ConflictFile])
    case fastForwarded
    case nothingToMerge
}
```

### 5.3 Conflict Resolution UI

```swift
struct MergeConflictView: View {
    let conflicts: [ConflictFile]
    @State private var resolutions: [String: ConflictResolution] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge Conflicts")
                .font(.headline)

            Text("\(conflicts.count) file(s) have conflicts that need resolution")
                .foregroundStyle(.secondary)

            List {
                ForEach(conflicts, id: \.path) { conflict in
                    ConflictFileRow(
                        conflict: conflict,
                        resolution: $resolutions[conflict.path]
                    )
                }
            }

            HStack {
                Button("Abort Merge") {
                    abortMerge()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Open in Editor") {
                    openInEditor()
                }
                .buttonStyle(.bordered)

                Button("Apply Resolutions") {
                    applyResolutions()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allResolved)
            }
        }
        .padding()
    }

    private var allResolved: Bool {
        conflicts.allSatisfy { resolutions[$0.path] != nil }
    }
}
```

### 5.4 Post-Merge Cleanup

```swift
func completeWorktreeMerge(
    worktree: Worktree,
    options: WorktreeCleanupOptions
) async throws {
    // Step 1: Push merged changes
    if options.pushAfterMerge {
        try await git.run(["push"], in: projectPath)
    }

    // Step 2: Archive or delete worktree
    if options.deleteAfterMerge {
        // Delete branch
        if options.deleteBranch {
            try await git.run(
                ["branch", "-d", worktree.branchName],
                in: projectPath
            )
        }

        // Remove worktree
        try await git.run(
            ["worktree", "remove", worktree.path.path],
            in: projectPath
        )

        // Update Blaze records
        await worktreeStore.delete(worktree.id)
    } else {
        // Archive worktree
        await worktreeStore.updateState(worktree.id, to: .merged)
    }

    // Step 3: Archive associated sessions
    if let sessionId = worktree.sessionId {
        await sessionManager.archive(sessionId)
    }
}

struct WorktreeCleanupOptions {
    var pushAfterMerge: Bool = true
    var deleteAfterMerge: Bool = false
    var deleteBranch: Bool = false
    var archiveSessions: Bool = true
}
```

---

## 6. Implementation

### 6.1 Data Model

```swift
struct Worktree: Identifiable, Codable {
    let id: UUID
    let projectId: Project.ID
    let path: URL
    let branchName: String
    var name: String
    let baseBranch: String
    var state: WorktreeState
    let createdAt: Date
    var mergedAt: Date?
    var sessionId: Session.ID?
}

enum WorktreeState: String, Codable {
    case creating
    case active
    case dirty       // Has uncommitted changes
    case merged
    case archived
    case deleted
}

// LanceDB storage
extension LanceDBStore {
    func getWorktrees(for projectId: Project.ID) async -> [Worktree] {
        await query(
            table: "worktrees",
            filter: "project_id = '\(projectId)' AND state != 'deleted'",
            orderBy: "created_at DESC"
        )
    }
}
```

### 6.2 Git Integration

```swift
actor GitWorktreeManager {
    private let git: GitExecutor

    func listWorktrees(in projectPath: URL) async throws -> [GitWorktreeInfo] {
        let output = try await git.run(
            ["worktree", "list", "--porcelain"],
            in: projectPath
        )

        return parseWorktreeList(output)
    }

    func add(
        path: URL,
        branch: String,
        baseBranch: String,
        in projectPath: URL
    ) async throws {
        try await git.run([
            "worktree", "add",
            "-b", branch,
            path.path,
            baseBranch
        ], in: projectPath)
    }

    func remove(path: URL, force: Bool, in projectPath: URL) async throws {
        var args = ["worktree", "remove"]
        if force {
            args.append("--force")
        }
        args.append(path.path)

        try await git.run(args, in: projectPath)
    }

    func prune(in projectPath: URL) async throws {
        try await git.run(["worktree", "prune"], in: projectPath)
    }

    private func parseWorktreeList(_ output: String) -> [GitWorktreeInfo] {
        // Parse porcelain format
        var worktrees: [GitWorktreeInfo] = []
        var current: [String: String] = [:]

        for line in output.split(separator: "\n") {
            if line.isEmpty {
                if let path = current["worktree"] {
                    worktrees.append(GitWorktreeInfo(
                        path: URL(fileURLWithPath: path),
                        head: current["HEAD"] ?? "",
                        branch: current["branch"]?.replacingOccurrences(of: "refs/heads/", with: "")
                    ))
                }
                current = [:]
            } else if let spaceIndex = line.firstIndex(of: " ") {
                let key = String(line[..<spaceIndex])
                let value = String(line[line.index(after: spaceIndex)...])
                current[key] = value
            }
        }

        return worktrees
    }
}
```

### 6.3 File Watcher

```swift
class WorktreeFileWatcher {
    private var watchers: [Worktree.ID: DirectoryWatcher] = [:]

    func watch(_ worktree: Worktree) {
        let watcher = DirectoryWatcher(url: worktree.path) { [weak self] changes in
            Task {
                await self?.handleChanges(changes, in: worktree)
            }
        }

        watchers[worktree.id] = watcher
        watcher.start()
    }

    func unwatch(_ worktreeId: Worktree.ID) {
        watchers[worktreeId]?.stop()
        watchers.removeValue(forKey: worktreeId)
    }

    private func handleChanges(_ changes: [FileChange], in worktree: Worktree) async {
        // Update worktree state
        let hasUncommitted = await checkForUncommittedChanges(worktree)

        if hasUncommitted && worktree.state == .active {
            await worktreeStore.updateState(worktree.id, to: .dirty)
        } else if !hasUncommitted && worktree.state == .dirty {
            await worktreeStore.updateState(worktree.id, to: .active)
        }
    }
}
```

---

## Acceptance Criteria

- [ ] Create worktree with new branch
- [ ] Session runs in worktree directory
- [ ] UI shows worktree status (clean/dirty)
- [ ] Merge workflow with conflict resolution
- [ ] Cleanup removes worktree and updates records
- [ ] Cross-worktree file operations work
- [ ] Multiple worktrees per project supported
- [ ] State persists across app restarts

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |
