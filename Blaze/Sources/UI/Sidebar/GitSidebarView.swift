import SwiftUI

// MARK: - Git Sidebar View

/// Tab 5: Git sidebar showing branch, diff summary, commits, and worktree status.
///
/// **Phase 2 Spec:**
/// - Current branch: Shows worktree branch name
/// - Uncommitted changes: Staged/unstaged file list
/// - Recent commits: Last 10 commits on this branch
/// - Worktree status: Which worktrees exist for this project
/// - Actions: Commit, Push, Pull (future)
struct GitSidebarView: View {
    let sessionId: UUID?

    @EnvironmentObject var appState: AppState
    @State private var gitStatus: GitStatusInfo?
    @State private var recentCommits: [GitCommitInfo] = []
    @State private var isLoading: Bool = false
    @State private var error: String?
    @State private var expandedSections: Set<GitSection> = [.branch, .changes]

    private var session: Session? {
        guard let id = sessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    private var workingDirectory: String? {
        session?.effectiveWorkingDirectory
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if let status = gitStatus {
                gitContentView(status)
            } else {
                notGitRepoView
            }
        }
        .task {
            await loadGitStatus()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading git status...")
                .dsTextStyle(.caption, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.warning)

            Text("Git Error")
                .dsTextStyle(.subtitle)

            Text(message)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadGitStatus()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Not Git Repo View

    private var notGitRepoView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 28))
                .foregroundStyle(Color.ds.tertiary)

            Text("Not a Git Repository")
                .dsTextStyle(.subtitle)

            Text("This directory is not tracked by git")
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Git Content View

    private func gitContentView(_ status: GitStatusInfo) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Branch section
                collapsibleSection(.branch) {
                    branchSection(status)
                }

                Divider()

                // Changes section
                collapsibleSection(.changes) {
                    changesSection(status)
                }

                Divider()

                // Commits section
                collapsibleSection(.commits) {
                    commitsSection
                }

                // Worktree section (if in a worktree)
                if session?.hasWorktree == true {
                    Divider()

                    collapsibleSection(.worktree) {
                        worktreeSection
                    }
                }
            }
        }
    }

    // MARK: - Branch Section

    private func branchSection(_ status: GitStatusInfo) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Branch name
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ds.accent)

                Text(status.branch)
                    .dsTextStyle(.body)
                    .fontWeight(.medium)

                Spacer()

                // Ahead/behind badge
                if status.aheadBy > 0 || status.behindBy > 0 {
                    HStack(spacing: DSSpacing.xxs) {
                        if status.aheadBy > 0 {
                            Label("\(status.aheadBy)", systemImage: "arrow.up")
                                .dsTextStyle(.micro, color: .ds.positive)
                        }
                        if status.behindBy > 0 {
                            Label("\(status.behindBy)", systemImage: "arrow.down")
                                .dsTextStyle(.micro, color: .ds.warning)
                        }
                    }
                    .font(.system(size: 10))
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)

            // Worktree badge
            if status.isWorktree {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 11))

                    Text("Worktree")
                        .dsTextStyle(.micro)
                }
                .foregroundStyle(Color.ds.tertiary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.bottom, DSSpacing.xs)
            }
        }
    }

    // MARK: - Changes Section

    private func changesSection(_ status: GitStatusInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary
            HStack {
                let total = status.stagedFiles.count + status.unstagedFiles.count + status.untrackedFiles.count
                Text("\(total) change\(total == 1 ? "" : "s")")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await loadGitStatus()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)

            // Staged files
            if !status.stagedFiles.isEmpty {
                changeGroup(title: "Staged", files: status.stagedFiles, color: .ds.positive)
            }

            // Unstaged files
            if !status.unstagedFiles.isEmpty {
                changeGroup(title: "Changed", files: status.unstagedFiles, color: .ds.warning)
            }

            // Untracked files
            if !status.untrackedFiles.isEmpty {
                untrackedGroup(files: status.untrackedFiles)
            }

            if status.stagedFiles.isEmpty && status.unstagedFiles.isEmpty && status.untrackedFiles.isEmpty {
                Text("Working tree clean")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
            }
        }
    }

    private func changeGroup(title: String, files: [GitFileStatus], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(title)
                    .dsTextStyle(.caption, color: .ds.secondary)

                Text("(\(files.count))")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)

            // Files
            ForEach(files) { file in
                GitFileRow(file: file) {
                    if let path = workingDirectory {
                        let fullPath = (path as NSString).appendingPathComponent(file.path)
                        appState.openFile(fullPath, asPreview: true)
                    }
                }
            }
        }
    }

    private func untrackedGroup(files: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(Color.ds.tertiary)
                    .frame(width: 6, height: 6)

                Text("Untracked")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Text("(\(files.count))")
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)

            ForEach(files, id: \.self) { path in
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 16)

                    Text((path as NSString).lastPathComponent)
                        .dsTextStyle(.caption)
                        .lineLimit(1)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xxs)
            }
        }
    }

    // MARK: - Commits Section

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if recentCommits.isEmpty {
                Text("No commits loaded")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
            } else {
                ForEach(recentCommits) { commit in
                    CommitRow(commit: commit)
                }
            }
        }
    }

    // MARK: - Worktree Section

    private var worktreeSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            if let session {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ds.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session Worktree")
                            .dsTextStyle(.caption)

                        if let worktreePath = session.worktreePath {
                            Text(worktreePath)
                                .dsTextStyle(.micro, color: .ds.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)

                // Actions
                HStack(spacing: DSSpacing.sm) {
                    Button {
                        if let path = session.worktreePath {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                    } label: {
                        Label("Reveal", systemImage: "folder")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.bottom, DSSpacing.xs)
            }
        }
    }

    // MARK: - Collapsible Section

    private func collapsibleSection<Content: View>(
        _ section: GitSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.ds.tertiary)
                        .frame(width: 12)

                    Image(systemName: section.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ds.secondary)

                    Text(section.rawValue)
                        .dsTextStyle(.caption, color: .ds.secondary)
                        .fontWeight(.medium)

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)

            // Content
            if expandedSections.contains(section) {
                content()
            }
        }
    }

    // MARK: - Load Git Status

    private func loadGitStatus() async {
        guard let workingDir = workingDirectory else {
            gitStatus = nil
            return
        }

        isLoading = true
        error = nil

        do {
            // Check if git repo
            let isGitRepo = try await runGitCommand(["rev-parse", "--is-inside-work-tree"], in: workingDir)
            guard isGitRepo.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
                await MainActor.run {
                    isLoading = false
                    gitStatus = nil
                }
                return
            }

            // Get branch name
            let branch = try await runGitCommand(["branch", "--show-current"], in: workingDir)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Check if worktree
            let worktreeCheck = try? await runGitCommand(["rev-parse", "--git-common-dir"], in: workingDir)
            let isWorktree = worktreeCheck?.contains(".git/worktrees") == true

            // Get status
            let statusOutput = try await runGitCommand(["status", "--porcelain"], in: workingDir)
            let (staged, unstaged, untracked) = parseGitStatus(statusOutput)

            // Get ahead/behind
            let (ahead, behind) = try await getAheadBehind(branch: branch, in: workingDir)

            // Get recent commits
            let commitsOutput = try await runGitCommand(
                ["log", "--oneline", "-10", "--format=%H|%h|%s|%an|%ai"],
                in: workingDir
            )
            let commits = parseCommits(commitsOutput)

            await MainActor.run {
                gitStatus = GitStatusInfo(
                    branch: branch.isEmpty ? "HEAD detached" : branch,
                    isWorktree: isWorktree,
                    stagedFiles: staged,
                    unstagedFiles: unstaged,
                    untrackedFiles: untracked,
                    aheadBy: ahead,
                    behindBy: behind
                )
                recentCommits = commits
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func runGitCommand(_ args: [String], in directory: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseGitStatus(_ output: String) -> ([GitFileStatus], [GitFileStatus], [String]) {
        var staged: [GitFileStatus] = []
        var unstaged: [GitFileStatus] = []
        var untracked: [String] = []

        for line in output.split(separator: "\n") {
            guard line.count >= 3 else { continue }

            let indexStatus = line[line.startIndex]
            let worktreeStatus = line[line.index(after: line.startIndex)]
            let path = String(line.dropFirst(3))

            // Staged changes
            if indexStatus != " " && indexStatus != "?" {
                staged.append(GitFileStatus(path: path, status: parseFileStatus(indexStatus)))
            }

            // Worktree changes
            if worktreeStatus != " " && worktreeStatus != "?" {
                unstaged.append(GitFileStatus(path: path, status: parseFileStatus(worktreeStatus)))
            }

            // Untracked
            if indexStatus == "?" && worktreeStatus == "?" {
                untracked.append(path)
            }
        }

        return (staged, unstaged, untracked)
    }

    private func parseFileStatus(_ char: Character) -> GitFileStatusType {
        switch char {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        default: return .modified
        }
    }

    private func getAheadBehind(branch: String, in directory: String) async throws -> (Int, Int) {
        guard !branch.isEmpty else { return (0, 0) }

        do {
            let output = try await runGitCommand(
                ["rev-list", "--left-right", "--count", "\(branch)...@{upstream}"],
                in: directory
            )

            let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if parts.count == 2,
               let ahead = Int(parts[0]),
               let behind = Int(parts[1]) {
                return (ahead, behind)
            }
        } catch {
            // No upstream branch
        }

        return (0, 0)
    }

    private func parseCommits(_ output: String) -> [GitCommitInfo] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 4)
            guard parts.count >= 4 else { return nil }

            let hash = String(parts[0])
            let shortHash = String(parts[1])
            let message = String(parts[2])
            let author = String(parts[3])

            var date: Date?
            if parts.count >= 5 {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime, .withTimeZone]
                date = dateFormatter.date(from: String(parts[4]))
            }

            return GitCommitInfo(
                hash: hash,
                shortHash: shortHash,
                message: message,
                author: author,
                date: date ?? Date()
            )
        }
    }
}

// MARK: - Supporting Types

enum GitSection: String, CaseIterable {
    case branch = "Branch"
    case changes = "Changes"
    case commits = "Commits"
    case worktree = "Worktree"

    var icon: String {
        switch self {
        case .branch: return "arrow.triangle.branch"
        case .changes: return "doc.badge.ellipsis"
        case .commits: return "clock"
        case .worktree: return "folder.badge.gearshape"
        }
    }
}

struct GitStatusInfo {
    let branch: String
    let isWorktree: Bool
    let stagedFiles: [GitFileStatus]
    let unstagedFiles: [GitFileStatus]
    let untrackedFiles: [String]
    let aheadBy: Int
    let behindBy: Int
}

struct GitFileStatus: Identifiable {
    let id = UUID()
    let path: String
    let status: GitFileStatusType
}

enum GitFileStatusType: String {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"

    var icon: String {
        switch self {
        case .modified: return "pencil.circle.fill"
        case .added: return "plus.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .modified: return .ds.warning
        case .added: return .ds.positive
        case .deleted: return .ds.negative
        case .renamed: return .ds.accent
        case .copied: return .ds.accent
        }
    }
}

struct GitCommitInfo: Identifiable {
    let id = UUID()
    let hash: String
    let shortHash: String
    let message: String
    let author: String
    let date: Date
}

// MARK: - Git File Row

struct GitFileRow: View {
    let file: GitFileStatus
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: file.status.icon)
                .font(.system(size: 11))
                .foregroundStyle(file.status.color)
                .frame(width: 16)

            Text((file.path as NSString).lastPathComponent)
                .dsTextStyle(.caption)
                .lineLimit(1)

            Spacer()

            Text(file.status.rawValue)
                .dsTextStyle(.monoSmall, color: file.status.color)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(isHovered ? Color.ds.surface.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Commit Row

struct CommitRow: View {
    let commit: GitCommitInfo

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DSSpacing.xs) {
                Text(commit.shortHash)
                    .dsTextStyle(.monoSmall, color: .ds.accent)

                Text(commit.message)
                    .dsTextStyle(.caption)
                    .lineLimit(1)
            }

            HStack(spacing: DSSpacing.xs) {
                Text(commit.author)
                    .dsTextStyle(.micro, color: .ds.tertiary)

                Text("•")
                    .dsTextStyle(.micro, color: .ds.tertiary)

                Text(formatRelativeTime(commit.date))
                    .dsTextStyle(.micro, color: .ds.tertiary)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(isHovered ? Color.ds.surface.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy Hash") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.hash, forType: .string)
            }

            Button("Copy Short Hash") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.shortHash, forType: .string)
            }

            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.message, forType: .string)
            }
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview("Git Sidebar") {
    GitSidebarView(sessionId: UUID())
        .environmentObject(AppState())
        .frame(width: 280, height: 500)
        .background(Color.ds.bg0)
}
