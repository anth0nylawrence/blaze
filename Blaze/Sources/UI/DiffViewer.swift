import SwiftUI

// MARK: - Diff Viewer

/// Main diff viewer component for displaying file diffs with accept/reject actions
struct DiffViewer: View {
    let fileDiff: FileDiff
    let onAccept: (() -> Void)?
    let onReject: (() -> Void)?

    @State private var isExpanded: Bool = true
    @State private var showAllHunks: Bool = false

    // Large diff threshold (D8.7)
    private let maxVisibleLines = 2000
    private let truncationThreshold = 50

    private var totalLines: Int {
        fileDiff.hunks.flatMap(\.lines).count
    }

    private var isLargeDiff: Bool {
        totalLines > maxVisibleLines
    }

    private var fileName: String {
        (fileDiff.filePath as NSString).lastPathComponent
    }

    private var fileExtension: String {
        (fileDiff.filePath as NSString).pathExtension.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            diffHeader

            // Content
            if isExpanded {
                Divider()
                diffContent
            }
        }
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor.opacity(0.3), lineWidth: 1)
        }
    }

    // MARK: - Header

    private var diffHeader: some View {
        HStack(spacing: 8) {
            // Expand/collapse button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // File icon
                    Image(systemName: fileIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)

                    // File name
                    Text(fileName)
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                        .lineLimit(1)

                    // Stats badges
                    HStack(spacing: 4) {
                        if fileDiff.stats.additions > 0 {
                            Text("+\(fileDiff.stats.additions)")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        if fileDiff.stats.deletions > 0 {
                            Text("-\(fileDiff.stats.deletions)")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    // Decision indicator
                    if fileDiff.decision != .pending {
                        decisionBadge
                    }

                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Accept/Reject buttons (D8.3)
            if fileDiff.decision == .pending {
                actionButtons
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Action Buttons (D8.3)

    private var actionButtons: some View {
        HStack(spacing: 6) {
            // Accept button
            if let onAccept {
                Button {
                    onAccept()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Reject button
            if let onReject {
                Button {
                    onReject()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Decision Badge

    private var decisionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: decisionIcon)
            Text(decisionText)
        }
        .font(.caption)
        .foregroundStyle(decisionColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(decisionColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Diff Content (D8.1)

    private var diffContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large diff warning (D8.7)
            if isLargeDiff && !showAllHunks {
                largeDiffWarning
            }

            // Diff hunks
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleHunks.enumerated()), id: \.offset) { index, hunk in
                        VStack(alignment: .leading, spacing: 0) {
                            // Hunk header
                            hunkHeader(hunk: hunk)

                            // Diff lines
                            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { lineIndex, line in
                                DiffLineView(
                                    line: line,
                                    fileExtension: fileExtension
                                )
                            }
                        }

                        // Separator between hunks
                        if index < visibleHunks.count - 1 {
                            hunkSeparator
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    private var visibleHunks: [DiffHunk] {
        if isLargeDiff && !showAllHunks {
            // Truncate to first few hunks (D8.7)
            let truncatedHunks = fileDiff.hunks.prefix(while: { hunk in
                true // Could add smarter truncation logic
            })
            return Array(truncatedHunks.prefix(5))
        }
        return fileDiff.hunks
    }

    // MARK: - Large Diff Warning (D8.7)

    private var largeDiffWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Large diff (\(totalLines) lines). Showing first \(truncationThreshold) lines.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Show All") {
                withAnimation {
                    showAllHunks = true
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Hunk Header

    private func hunkHeader(hunk: DiffHunk) -> some View {
        Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.separatorColor).opacity(0.3))
    }

    // MARK: - Hunk Separator

    private var hunkSeparator: some View {
        HStack {
            ForEach(0..<3) { _ in
                Text("·")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color(.separatorColor).opacity(0.2))
    }

    // MARK: - Styling Properties

    private var borderColor: Color {
        switch fileDiff.decision {
        case .pending:
            return .blue
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .modified:
            return .orange
        }
    }

    private var fileIcon: String {
        switch fileExtension {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "py": return "number"
        case "md": return "doc.text"
        case "json", "yaml", "yml": return "curlybraces"
        case "css", "scss": return "paintbrush"
        case "html": return "globe"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        switch fileExtension {
        case "swift": return .orange
        case "js", "ts": return .yellow
        case "py": return .blue
        case "md": return .gray
        default: return .secondary
        }
    }

    private var decisionIcon: String {
        switch fileDiff.decision {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .modified: return "pencil.circle.fill"
        }
    }

    private var decisionText: String {
        switch fileDiff.decision {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        case .modified: return "Modified"
        }
    }

    private var decisionColor: Color {
        switch fileDiff.decision {
        case .pending: return .blue
        case .accepted: return .green
        case .rejected: return .red
        case .modified: return .orange
        }
    }
}

// MARK: - Diff Line View (D8.1 + D8.2)

/// Individual diff line with syntax highlighting
struct DiffLineView: View {
    let line: DiffLine
    let fileExtension: String

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Gutter with line numbers
            lineNumberGutter

            // Line prefix (+, -, or space)
            linePrefix

            // Line content with syntax highlighting (D8.2)
            lineContent
        }
        .background(backgroundColor)
        .onHover { isHovered = $0 }
    }

    // MARK: - Line Number Gutter

    private var lineNumberGutter: some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 4)

            // New line number
            Text(line.newLineNumber.map { String($0) } ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 4)
        }
        .background(gutterBackgroundColor)
    }

    // MARK: - Line Prefix

    private var linePrefix: some View {
        Text(prefixCharacter)
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .foregroundStyle(prefixColor)
            .frame(width: 20)
    }

    // MARK: - Line Content with Syntax Highlighting (D8.2)

    private var lineContent: some View {
        Text(highlightedContent)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)
    }

    private var highlightedContent: AttributedString {
        var attributed = AttributedString(line.content)

        // Apply basic syntax highlighting based on file extension (D8.2)
        applySyntaxHighlighting(to: &attributed)

        return attributed
    }

    private func applySyntaxHighlighting(to text: inout AttributedString) {
        // Keywords for various languages
        let keywords: [String: [String]] = [
            "swift": ["func", "var", "let", "struct", "class", "enum", "protocol", "import",
                     "if", "else", "guard", "switch", "case", "for", "while", "return",
                     "private", "public", "internal", "fileprivate", "static", "final",
                     "async", "await", "throws", "try", "catch", "self", "Self", "nil",
                     "true", "false", "init", "deinit", "extension", "where", "in"],
            "js": ["function", "const", "let", "var", "class", "import", "export",
                  "if", "else", "switch", "case", "for", "while", "return", "async",
                  "await", "try", "catch", "throw", "new", "this", "super", "null",
                  "undefined", "true", "false", "default", "from"],
            "ts": ["function", "const", "let", "var", "class", "import", "export",
                  "if", "else", "switch", "case", "for", "while", "return", "async",
                  "await", "try", "catch", "throw", "new", "this", "super", "null",
                  "undefined", "true", "false", "interface", "type", "enum", "as",
                  "implements", "extends", "readonly", "private", "public", "protected"],
            "py": ["def", "class", "import", "from", "if", "elif", "else", "for", "while",
                  "return", "try", "except", "finally", "raise", "with", "as", "pass",
                  "break", "continue", "lambda", "yield", "async", "await", "None",
                  "True", "False", "and", "or", "not", "in", "is", "self"]
        ]

        guard let langKeywords = keywords[fileExtension] ?? keywords["swift"] else { return }

        let lineContent = line.content

        // Highlight comments first (overrides everything)
        if lineContent.trimmingCharacters(in: .whitespaces).hasPrefix("//") ||
           lineContent.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            text.foregroundColor = .secondary
            return
        }

        // Simple keyword highlighting
        let textContent = String(text.characters)
        for keyword in langKeywords {
            // Match whole word occurrences
            if let range = text.range(of: keyword) {
                // Check if it's a whole word (simple heuristic)
                if let nsRange = Range(range, in: textContent) {
                    let start = nsRange.lowerBound
                    let end = nsRange.upperBound

                    let beforeIsWord = start == textContent.startIndex ||
                        !textContent[textContent.index(before: start)].isLetter
                    let afterIsWord = end == textContent.endIndex ||
                        !textContent[end].isLetter

                    if beforeIsWord && afterIsWord {
                        text[range].foregroundColor = .purple
                    }
                }
            }
        }
    }

    // MARK: - Styling Properties

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(isHovered ? 0.2 : 0.1)
        case .deletion:
            return Color.red.opacity(isHovered ? 0.2 : 0.1)
        case .context:
            return isHovered ? Color(.separatorColor).opacity(0.1) : .clear
        }
    }

    private var gutterBackgroundColor: Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(0.15)
        case .deletion:
            return Color.red.opacity(0.15)
        case .context:
            return Color(.separatorColor).opacity(0.1)
        }
    }

    private var prefixCharacter: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .secondary
        }
    }
}

// MARK: - Diff Card (D8.6)

/// Compact diff card for chat timeline integration
struct DiffCard: View {
    let fileDiff: FileDiff
    let onAccept: (() -> Void)?
    let onReject: (() -> Void)?
    let onTap: (() -> Void)?

    @State private var isHovered: Bool = false

    private var fileName: String {
        (fileDiff.filePath as NSString).lastPathComponent
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 10) {
                // File icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(fileDiff.hunks.count) hunk\(fileDiff.hunks.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Text("+\(fileDiff.stats.additions)")
                                .foregroundStyle(.green)
                            Text("-\(fileDiff.stats.deletions)")
                                .foregroundStyle(.red)
                        }
                        .font(.caption2)
                    }
                }

                Spacer()

                // Quick action buttons
                if isHovered && fileDiff.decision == .pending {
                    HStack(spacing: 4) {
                        if let onAccept {
                            Button {
                                onAccept()
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }
                        if let onReject {
                            Button {
                                onReject()
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity)
                }

                // Decision indicator
                if fileDiff.decision != .pending {
                    Image(systemName: decisionIcon)
                        .foregroundStyle(decisionColor)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var decisionIcon: String {
        switch fileDiff.decision {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .modified: return "pencil.circle.fill"
        }
    }

    private var decisionColor: Color {
        switch fileDiff.decision {
        case .pending: return .blue
        case .accepted: return .green
        case .rejected: return .red
        case .modified: return .orange
        }
    }

    private var borderColor: Color {
        fileDiff.decision == .pending ? .blue : decisionColor
    }
}

// MARK: - Diff Viewer Sheet

/// Full-screen diff viewer presented as a sheet
struct DiffViewerSheet: View {
    let diffs: [FileDiff]
    @Binding var selectedDiffId: UUID?
    let onAccept: ((FileDiff) -> Void)?
    let onReject: ((FileDiff) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            // File list sidebar
            List(diffs, selection: $selectedDiffId) { diff in
                DiffFileRow(diff: diff)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            if let selectedId = selectedDiffId,
               let diff = diffs.first(where: { $0.id == selectedId }) {
                DiffViewer(
                    fileDiff: diff,
                    onAccept: { onAccept?(diff) },
                    onReject: { onReject?(diff) }
                )
                .padding()
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text",
                    description: Text("Choose a file from the sidebar to view its diff")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

/// Row for file list in diff viewer sheet
struct DiffFileRow: View {
    let diff: FileDiff

    private var fileName: String {
        (diff.filePath as NSString).lastPathComponent
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("+\(diff.stats.additions)")
                        .foregroundStyle(.green)
                    Text("-\(diff.stats.deletions)")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }

            Spacer()

            // Decision indicator
            if diff.decision != .pending {
                Image(systemName: decisionIcon)
                    .foregroundStyle(decisionColor)
            }
        }
        .tag(diff.id)
    }

    private var decisionIcon: String {
        switch diff.decision {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .modified: return "pencil.circle.fill"
        }
    }

    private var decisionColor: Color {
        switch diff.decision {
        case .pending: return .blue
        case .accepted: return .green
        case .rejected: return .red
        case .modified: return .orange
        }
    }
}

// MARK: - Previews

#Preview("Diff Viewer") {
    let sampleHunk = DiffHunk(
        oldStart: 1,
        oldCount: 5,
        newStart: 1,
        newCount: 7,
        lines: [
            DiffLine(type: .context, content: "import SwiftUI", oldLineNumber: 1, newLineNumber: 1),
            DiffLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 2),
            DiffLine(type: .deletion, content: "struct OldView: View {", oldLineNumber: 3, newLineNumber: nil),
            DiffLine(type: .addition, content: "struct NewView: View {", oldLineNumber: nil, newLineNumber: 3),
            DiffLine(type: .addition, content: "    let title: String", oldLineNumber: nil, newLineNumber: 4),
            DiffLine(type: .context, content: "    var body: some View {", oldLineNumber: 4, newLineNumber: 5),
            DiffLine(type: .deletion, content: "        Text(\"Hello\")", oldLineNumber: 5, newLineNumber: nil),
            DiffLine(type: .addition, content: "        Text(title)", oldLineNumber: nil, newLineNumber: 6),
            DiffLine(type: .addition, content: "            .font(.headline)", oldLineNumber: nil, newLineNumber: 7),
            DiffLine(type: .context, content: "    }", oldLineNumber: 6, newLineNumber: 8),
        ]
    )

    let diff = FileDiff(filePath: "/Users/dev/project/Sources/Views/ContentView.swift", hunks: [sampleHunk])

    return DiffViewer(
        fileDiff: diff,
        onAccept: { print("Accept") },
        onReject: { print("Reject") }
    )
    .frame(width: 600, height: 400)
    .padding()
}

#Preview("Diff Card") {
    let sampleHunk = DiffHunk(
        oldStart: 1,
        oldCount: 3,
        newStart: 1,
        newCount: 5,
        lines: [
            DiffLine(type: .context, content: "import SwiftUI", oldLineNumber: 1, newLineNumber: 1),
            DiffLine(type: .deletion, content: "let x = 1", oldLineNumber: 2, newLineNumber: nil),
            DiffLine(type: .addition, content: "let x = 2", oldLineNumber: nil, newLineNumber: 2),
            DiffLine(type: .addition, content: "let y = 3", oldLineNumber: nil, newLineNumber: 3),
        ]
    )

    let diff = FileDiff(filePath: "/path/to/file.swift", hunks: [sampleHunk])

    return VStack {
        DiffCard(
            fileDiff: diff,
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onTap: { print("Tap") }
        )
        .frame(width: 400)
    }
    .padding()
}
