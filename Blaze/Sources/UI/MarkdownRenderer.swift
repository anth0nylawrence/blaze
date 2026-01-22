import SwiftUI

// MARK: - Markdown Renderer

/// Enhanced markdown rendering with code blocks, links, and file path detection
struct MarkdownRenderer: View {
    let content: String
    let onFilePathTapped: ((String) -> Void)?

    init(content: String, onFilePathTapped: ((String) -> Void)? = nil) {
        self.content = content
        self.onFilePathTapped = onFilePathTapped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    // MARK: - Block Parsing

    private var blocks: [MarkdownBlock] {
        parseMarkdownBlocks(content)
    }

    private func parseMarkdownBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentCodeBlock: (language: String, lines: [String])? = nil
        var currentParagraph: [String] = []

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            // Check for code block fence
            if line.hasPrefix("```") {
                if let codeBlock = currentCodeBlock {
                    // End of code block
                    blocks.append(.codeBlock(
                        codeBlock.language,
                        codeBlock.lines.joined(separator: "\n")
                    ))
                    currentCodeBlock = nil
                } else {
                    // Start of code block - flush paragraph first
                    if !currentParagraph.isEmpty {
                        blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                        currentParagraph = []
                    }
                    let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentCodeBlock = (language: language.isEmpty ? "text" : language, lines: [])
                }
                continue
            }

            if currentCodeBlock != nil {
                currentCodeBlock?.lines.append(line)
                continue
            }

            // Headers
            if line.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                blocks.append(.heading(1, String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                blocks.append(.heading(2, String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                blocks.append(.heading(3, String(line.dropFirst(4))))
            }
            // Bullet points
            else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                blocks.append(.listItem(String(line.dropFirst(2))))
            }
            // Numbered list
            else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                let text = String(line[match.upperBound...])
                blocks.append(.orderedListItem(text))
            }
            // Blockquote
            else if line.hasPrefix("> ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                blocks.append(.blockquote(String(line.dropFirst(2))))
            }
            // Horizontal rule
            else if line == "---" || line == "***" || line == "___" {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                blocks.append(.horizontalRule)
            }
            // Empty line - paragraph break
            else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
            }
            // Table row (starts with |)
            else if line.hasPrefix("|") && line.hasSuffix("|") {
                // Check if this is a separator row (|---|---|)
                let isSeparator = line.contains("---") || line.contains(":--") || line.contains("--:")
                if !isSeparator {
                    // Parse table cells
                    let cells = line
                        .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                        .components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }

                    // Check if we already have a table in progress
                    if case .table(var rows) = blocks.last {
                        blocks.removeLast()
                        rows.append(cells)
                        blocks.append(.table(rows))
                    } else {
                        // Flush paragraph and start new table
                        if !currentParagraph.isEmpty {
                            blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                            currentParagraph = []
                        }
                        blocks.append(.table([cells]))
                    }
                }
            }
            // Regular text
            else {
                currentParagraph.append(line)
            }
        }

        // Flush remaining content
        if let codeBlock = currentCodeBlock {
            blocks.append(.codeBlock(
                codeBlock.language,
                codeBlock.lines.joined(separator: "\n")
            ))
        }
        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
        }

        return blocks
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)

        case .paragraph(let text):
            paragraphView(text: text)

        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)

        case .listItem(let text):
            listItemView(text: text, ordered: false)

        case .orderedListItem(let text):
            listItemView(text: text, ordered: true)

        case .blockquote(let text):
            blockquoteView(text: text)

        case .horizontalRule:
            Divider()
                .padding(.vertical, DSSpacing.sm)

        case .table(let rows):
            tableView(rows: rows)
        }
    }

    private func tableView(rows: [[String]]) -> some View {
        TableRenderView(rows: rows)
    }
}

// MARK: - Table Render View (broken out for compiler performance)

private struct TableRenderView: View {
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                tableRow(row: row, isHeader: rowIndex == 0)
                if rowIndex == 0 {
                    Divider()
                }
            }
        }
        .background(Color.ds.surface.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .stroke(Color.ds.border.opacity(0.3), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func tableRow(row: [String], isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                tableCell(cell: cell, isHeader: isHeader)
                if colIndex < row.count - 1 {
                    Divider().frame(height: 20)
                }
            }
        }
    }

    private func tableCell(cell: String, isHeader: Bool) -> some View {
        Text(cell)
            .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
            .foregroundStyle(isHeader ? Color.ds.foreground : Color.ds.secondary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHeader ? Color.ds.surface.opacity(0.5) : Color.clear)
    }
}

// MARK: - MarkdownRenderer View Functions (continued)

private extension MarkdownRenderer {
    func headingView(level: Int, text: String) -> some View {
        let style: DSTextStyle = level == 1 ? .title : (level == 2 ? .subtitle : .body)
        return Text(text)
            .dsTextStyle(style, weight: .semibold)
            .padding(.top, level == 1 ? DSSpacing.md : DSSpacing.sm)
    }

    private func paragraphView(text: String) -> some View {
        ClickableTextView(
            text: text,
            onFilePathTapped: onFilePathTapped
        )
    }

    private func codeBlockView(language: String, code: String) -> some View {
        let lang = SyntaxHighlighter.Language.from(extension: language)

        return VStack(alignment: .leading, spacing: 0) {
            // Language label
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .dsTextStyle(.micro, color: .ds.secondary)
                Spacer()
                CopyButton(text: code)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(Color.ds.surface.opacity(0.5))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(SyntaxHighlighter.highlight(code, language: lang))
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(DSSpacing.sm)
            }
        }
        .background(Color.ds.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.ds.border.opacity(0.3), lineWidth: 1)
        }
    }

    private func listItemView(text: String, ordered: Bool) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.xs) {
            if ordered {
                Text("\u{2022}")
                    .dsTextStyle(.body, color: .ds.secondary)
            } else {
                Text("\u{2022}")
                    .dsTextStyle(.body, color: .ds.secondary)
            }

            ClickableTextView(text: text, onFilePathTapped: onFilePathTapped)
        }
        .padding(.leading, DSSpacing.md)
    }

    private func blockquoteView(text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.ds.accent.opacity(0.5))
                .frame(width: 3)

            Text(text)
                .dsTextStyle(.body, color: .ds.secondary)
                .italic()
                .padding(.leading, DSSpacing.sm)
        }
        .padding(.vertical, DSSpacing.xxs)
    }
}

// MARK: - Markdown Block Types

enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case codeBlock(String, String)
    case listItem(String)
    case orderedListItem(String)
    case blockquote(String)
    case horizontalRule
    case table([[String]])  // Array of rows, each row is array of cells
}

// MARK: - Clickable Text View

/// Text view that detects and highlights file paths, making them clickable
struct ClickableTextView: View {
    let text: String
    let onFilePathTapped: ((String) -> Void)?

    var body: some View {
        Text(attributedText)
            .dsTextStyle(.body)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "blazefile" {
                    // Extract path from blazefile:encodedPath format
                    let urlString = url.absoluteString
                    if let colonIndex = urlString.firstIndex(of: ":") {
                        let encodedPath = String(urlString[urlString.index(after: colonIndex)...])
                        if let path = encodedPath.removingPercentEncoding {
                            onFilePathTapped?(path)
                            return .handled
                        }
                    }
                }
                return .systemAction
            })
    }

    private var attributedText: AttributedString {
        var attributed = AttributedString(text)

        // Apply inline markdown formatting
        applyInlineFormatting(&attributed)

        // Detect and link file paths
        highlightFilePaths(&attributed)

        return attributed
    }

    private func applyInlineFormatting(_ attributed: inout AttributedString) {
        // Bold: **text** or __text__
        let boldRanges = findPatternRanges(in: attributed, pattern: #"\*\*(.+?)\*\*"#)
        for range in boldRanges {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
        }

        // Italic: *text* or _text_
        let italicRanges = findPatternRanges(in: attributed, pattern: #"\*(.+?)\*"#)
        for range in italicRanges {
            attributed[range].inlinePresentationIntent = .emphasized
        }

        // Code: `text`
        let codeRanges = findPatternRanges(in: attributed, pattern: #"`([^`]+)`"#)
        for range in codeRanges {
            attributed[range].font = .system(size: 13, design: .monospaced)
            attributed[range].backgroundColor = Color.ds.surface.opacity(0.5)
        }
    }

    private func highlightFilePaths(_ attributed: inout AttributedString) {
        // Match common file path patterns
        let patterns = [
            #"/[a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+"#,  // Unix absolute paths
            #"\./[a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+"#, // Relative paths
            #"[a-zA-Z0-9_\-]+\.(swift|py|js|ts|tsx|jsx|json|md|txt|yaml|yml|sh|bash)"#  // File names
        ]

        for pattern in patterns {
            let ranges = findPatternRanges(in: attributed, pattern: pattern)
            for range in ranges {
                let pathString = String(attributed[range].characters)
                // Use custom scheme to avoid URL parsing issues with file://
                if let encodedPath = pathString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                   let url = URL(string: "blazefile:\(encodedPath)") {
                    attributed[range].link = url
                    attributed[range].foregroundColor = Color.ds.accent
                    // Pill-like styling: background + no underline
                    attributed[range].backgroundColor = Color.ds.accent.opacity(0.15)
                    attributed[range].font = .system(size: 13, weight: .medium)
                }
            }
        }
    }

    private func findPatternRanges(
        in attributed: AttributedString,
        pattern: String
    ) -> [Range<AttributedString.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let text = String(attributed.characters)
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var ranges: [Range<AttributedString.Index>] = []
        for match in matches {
            if let swiftRange = Range(match.range, in: text),
               let attributedRange = Range(swiftRange, in: attributed) {
                ranges.append(attributedRange)
            }
        }
        return ranges
    }
}

// MARK: - Copy Button

struct CopyButton: View {
    let text: String
    @State private var copied: Bool = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                if copied {
                    Text("Copied")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(copied ? Color.ds.positive : Color.ds.secondary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}

// MARK: - Previews

#Preview("Markdown Renderer") {
    let sampleMarkdown = """
    # Welcome to Blaze

    This is a **bold** statement and this is *italic*.

    ## Features

    - Syntax highlighting for `Swift`, `Python`, and more
    - File path detection: /Users/dev/project/main.swift
    - Code blocks with copy button

    ### Code Example

    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, World!")
        }
    }
    ```

    > This is a blockquote with important information.

    ---

    Check out ./README.md for more details.
    """

    return ScrollView {
        MarkdownRenderer(content: sampleMarkdown) { path in
            print("Tapped file path: \(path)")
        }
        .padding()
    }
    .frame(width: 600, height: 600)
    .background(Color.ds.bg0)
}

#Preview("Code Block") {
    let code = """
    func greet(name: String) {
        print("Hello, \\(name)!")
    }
    """

    return MarkdownRenderer(content: "```swift\n\(code)\n```")
        .padding()
        .frame(width: 400)
        .background(Color.ds.bg0)
}
