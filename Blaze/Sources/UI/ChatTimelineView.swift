import SwiftUI

// MARK: - Mention Context

/// Tracks the state of an active @ mention
struct MentionContext: Equatable {
    let triggerIndex: String.Index  // Where @ was typed
    var query: String               // Text after @
    var selectedIndex: Int = 0      // Keyboard navigation index

    /// The range to replace when inserting a file reference
    func replacementRange(in text: String) -> Range<String.Index> {
        // Include the @ and the query
        let endIndex = text.index(triggerIndex, offsetBy: query.count + 1, limitedBy: text.endIndex) ?? text.endIndex
        return triggerIndex..<endIndex
    }
}

// MARK: - Chat Timeline View

/// Main chat timeline with streaming support and auto-scroll
struct ChatTimelineView: View {
    let session: Session
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fileTreeViewModel: FileTreeViewModel
    @State private var inputText: String = ""
    @State private var isAtBottom: Bool = true
    @State private var subagentCorrelations: [SubagentCorrelation] = []
    @Namespace private var bottomAnchor

    // Model/Reasoning state (synced with session via AppState)
    // NOTE: Empty string initial value - actual value set on onAppear/onChange
    // to ensure provider-correct model is used (not hardcoded "sonnet")
    @State private var selectedModelId: String = ""
    @State private var selectedReasoningEffort: ReasoningEffort = .medium

    /// Read messages directly from appState to ensure we always have current data.
    /// This is a safety net in case any mutation path misses the copy-modify-reassign pattern.
    /// Falls back to session.messages if session not found (defensive).
    private var currentMessages: [Message] {
        appState.sessions.first { $0.id == session.id }?.messages ?? session.messages
    }

    /// Get current session from AppState (for reading live values)
    private var currentSession: Session {
        appState.sessions.first { $0.id == session.id } ?? session
    }

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = appState.currentError {
                ErrorBanner(message: error) {
                    appState.currentError = nil
                }
            }

            // Messages area with auto-scroll - fills remaining space
            // Wrapped in container with proper padding and encapsulation
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Use currentMessages (reads from appState.sessions) instead of session.messages
                        // to ensure SwiftUI sees updates when @Published array elements are mutated
                        ForEach(currentMessages) { message in
                            MessageBubble(message: message) { filePath in
                                let resolvedPath = resolveFilePath(filePath)
                                appState.openFile(resolvedPath, asPreview: false)
                            }
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }

                        // Active subagent blocks (shown when subagents are running)
                        ForEach(subagentCorrelations.filter { $0.status == .running }, id: \.internalId) { correlation in
                            SubagentBlockView(correlation: correlation, events: [])
                                .id("subagent-\(correlation.internalId)")
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                        }

                        // Tool prompt card (shown when Claude requests user input)
                        if let prompt = appState.currentToolPrompt {
                            ToolPromptCard(
                                prompt: prompt,
                                submissionState: appState.promptSubmissionState,
                                pendingCount: appState.pendingPromptCount,
                                onSubmit: { response in
                                    Task {
                                        await appState.submitPromptResponse(response)
                                    }
                                },
                                onRetry: {
                                    Task {
                                        // Get current selection from the card's state
                                        // For retry, we'd need to track last response - simplified for now
                                        await appState.submitPromptResponse(.freeText(""))
                                    }
                                }
                            )
                            .id("tool-prompt-\(prompt.id)")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))

                            // Policy warning banner
                            if case .requireConfirmation(let reason) = appState.promptPolicyDecision {
                                HStack(spacing: DSSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.ds.warning)
                                    Text(reason)
                                        .dsTextStyle(.caption, color: .ds.warning)
                                }
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.xs)
                                .background(Color.ds.warning.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                            }
                        }

                        // Typing indicator when streaming (per-session)
                        if appState.isProcessing(sessionId: session.id) {
                            TypingIndicator()
                                .id("typing")
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        // Invisible anchor for scroll-to-bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, DSSpacing.lg)  // Horizontal padding for content
                    .padding(.vertical, DSSpacing.md)     // Vertical padding for content
                    .animation(.easeInOut(duration: 0.2), value: currentMessages.count)
                }
                .scrollDismissesKeyboard(.interactively)
                .id(session.id)  // Force new ScrollView instance on session change
                .onChange(of: currentMessages.count) { _, _ in
                    scrollToBottomIfNeeded(proxy: proxy)
                }
                .onChange(of: appState.processingSessionIds) { _, newIds in
                    // Scroll when this session starts processing
                    if newIds.contains(session.id) {
                        scrollToBottomIfNeeded(proxy: proxy)
                    }
                }
                .onAppear {
                    // Scroll to first message first to force LazyVStack to render,
                    // then scroll to bottom after a brief delay
                    if let firstMsg = currentMessages.first {
                        proxy.scrollTo(firstMsg.id, anchor: .top)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                    }
                }
                // Note: .id(session.id) above forces new ScrollView on session change,
                // which triggers onAppear again - no need for onChange(of: session.id)
            }
            .layoutPriority(1)  // ScrollView fills remaining space
            .background(.clear)  // Background applied at ContentView level

            // Input area - fixed size, always visible
            ChatInputView(
                text: $inputText,
                onSend: { sendMessage() },
                provider: currentSession.provider,
                modelId: $selectedModelId,
                reasoningEffort: $selectedReasoningEffort
            )
            .padding(.horizontal, DSSpacing.lg)  // Match content padding
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        // Note: navigationTitle removed - using custom CenterPaneHeader instead
        .task {
            await loadSubagents()
        }
        .task(id: appState.isProcessing(sessionId: session.id)) {
            // Refresh subagents when this session's processing state changes
            await loadSubagents()
        }
        // Sync model/reasoning state with session on appear and when session changes
        .onAppear {
            syncModelState()
        }
        .onChange(of: session.id) { _, _ in
            syncModelState()
        }
        // Re-sync when currentSession's provider/modelId changes (e.g., DB load completes)
        // This fixes race condition where session parameter has stale provider/model
        .onChange(of: currentSession.provider) { _, _ in
            syncModelState()
        }
        .onChange(of: currentSession.modelId) { _, newModelId in
            // Only sync if different from selected (avoid loop)
            if selectedModelId != newModelId {
                syncModelState()
            }
        }
        // Update session in AppState when dropdown values change
        .onChange(of: selectedModelId) { _, newValue in
            appState.updateSessionConfig(sessionId: session.id, modelId: newValue)
        }
        .onChange(of: selectedReasoningEffort) { _, newValue in
            appState.updateSessionConfig(sessionId: session.id, reasoningEffort: newValue)
        }
    }

    private func loadSubagents() async {
        subagentCorrelations = await appState.getSubagents(for: session.id)
    }

    /// Sync local model/reasoning state from currentSession.
    /// Handles provider-aware defaults when modelId is empty or invalid.
    private func syncModelState() {
        let session = currentSession

        // Get the model ID from session, falling back to provider default if empty/invalid
        var modelId = session.modelId
        let providerModels = AIModelRegistry.models(for: session.provider)

        // If modelId is empty or not valid for this provider, use provider default
        if modelId.isEmpty || !providerModels.contains(where: { $0.id == modelId }) {
            modelId = AIModelRegistry.defaultModel(for: session.provider)?.id
                ?? providerModels.first?.id
                ?? ""
        }

        // Only update if different (avoid triggering onChange loop)
        if selectedModelId != modelId {
            selectedModelId = modelId
        }
        if selectedReasoningEffort != session.reasoningEffort {
            selectedReasoningEffort = session.reasoningEffort
        }
    }

    private func scrollToBottomIfNeeded(proxy: ScrollViewProxy) {
        if isAtBottom {
            scrollToBottom(proxy: proxy, animated: true)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Send via AppState orchestrator (tokens like @folder:path are already inline)
        appState.sendMessage(trimmed)
        inputText = ""
    }

    /// Resolve a file path, prepending working directory for relative paths
    private func resolveFilePath(_ path: String) -> String {
        // Already absolute
        if path.hasPrefix("/") {
            return path
        }

        // Get the base directory (prefer session's working dir, fallback to file tree root)
        let baseDir: String
        if let workingDir = session.effectiveWorkingDirectory {
            baseDir = workingDir
        } else {
            let rootPath = fileTreeViewModel.rootURL.path
            if !rootPath.isEmpty && rootPath != NSTemporaryDirectory() {
                baseDir = rootPath
            } else {
                return path // No valid base directory
            }
        }

        // First try: direct path resolution
        let directPath = URL(fileURLWithPath: baseDir)
            .appendingPathComponent(path)
            .path
        if FileManager.default.fileExists(atPath: directPath) {
            return directPath
        }

        // Second try: if path has no directory component, search entire file tree
        if !path.contains("/") {
            if let foundNode = fileTreeViewModel.findFile(named: path) {
                return foundNode.url.path
            }
        }

        // Fallback to direct path
        return directPath
    }
}

// MARK: - Message Bubble

/// Individual message bubble with role-based styling
struct MessageBubble: View {
    let message: Message
    var onFilePathTapped: ((String) -> Void)?
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            if message.role == .assistant {
                assistantAvatar
                assistantContent
                Spacer(minLength: DSSpacing.xl)
            } else if message.role == .user {
                Spacer(minLength: DSSpacing.xl)
                userContent
            } else {
                // System/tool messages
                systemContent
            }
        }
        .onHover { isHovered = $0 }
    }

    // MARK: - Avatar

    private var assistantAvatar: some View {
        Circle()
            .fill(Color.ds.accent.gradient)
            .frame(width: DSSize.lg, height: DSSize.lg)
            .overlay {
                Image(systemName: "brain")
                    .font(.system(size: DSSize.xs, weight: .medium))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - User Content

    private var userContent: some View {
        VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
            UserMessageContent(content: message.content, onFilePathTapped: onFilePathTapped)
                .frame(maxWidth: 500, alignment: .leading)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs + 2)
                .background(Color.ds.accent.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: DSRadius.xl,
                        bottomLeadingRadius: DSRadius.xl,
                        bottomTrailingRadius: DSRadius.sm,
                        topTrailingRadius: DSRadius.xl
                    )
                )

            messageMetadata
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Assistant Content

    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Thinking section (collapsible)
            if let thinking = message.thinking, !thinking.isEmpty {
                ThinkingDisclosure(thinking: thinking)
            }

            MarkdownRenderer(content: message.content, onFilePathTapped: onFilePathTapped)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs + 2)
                .dsGlassPanel(level: .light, cornerRadius: DSRadius.xl, elevation: .none, border: .subtle)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: DSRadius.sm,
                        bottomLeadingRadius: DSRadius.xl,
                        bottomTrailingRadius: DSRadius.xl,
                        topTrailingRadius: DSRadius.xl
                    )
                )

            // Tool calls inline
            if !message.toolCalls.isEmpty {
                ForEach(message.toolCalls) { toolCall in
                    ToolCallCard(toolCall: toolCall)
                }
            }

            messageMetadata
        }
    }

    // MARK: - System Content

    private var systemContent: some View {
        HStack {
            Spacer()
            Text(message.content)
                .dsTextStyle(.caption, color: .ds.secondary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs - 2)
                .background(Color.ds.border.opacity(0.3))
                .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - Metadata

    private var messageMetadata: some View {
        HStack(spacing: DSSpacing.xs) {
            Text(message.timestamp, style: .time)
                .dsTextStyle(.micro, color: .ds.tertiary)

            // Copy button on hover
            if isHovered {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .dsTextStyle(.micro)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.tertiary)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Streaming Text

/// Text view optimized for streaming updates with markdown support and clickable file paths
struct StreamingText: View {
    let text: String
    var onFilePathTapped: ((String) -> Void)?

    var body: some View {
        // Use Text with AttributedString for markdown rendering
        // This is performant as SwiftUI handles incremental updates
        Text(attributedText)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
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
        // Try to parse as markdown, fall back to plain text
        do {
            var attributed = try AttributedString(markdown: text, options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            ))
            // Add clickable file path links
            highlightFilePaths(&attributed)
            return attributed
        } catch {
            var attributed = AttributedString(text)
            highlightFilePaths(&attributed)
            return attributed
        }
    }

    /// Detect and highlight file paths and @file:/@folder: tokens, making them clickable
    private func highlightFilePaths(_ attributed: inout AttributedString) {
        let text = String(attributed.characters)

        // First pass: Handle @file: and @folder: tokens (convert to display name + link)
        let tokenPattern = #"@(file|folder):([^\s]+)"#
        if let tokenRegex = try? NSRegularExpression(pattern: tokenPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = tokenRegex.matches(in: text, range: nsRange)

            // Process in reverse to preserve indices
            for match in matches.reversed() {
                if let fullSwiftRange = Range(match.range, in: text),
                   let pathRange = Range(match.range(at: 2), in: text),
                   let typeRange = Range(match.range(at: 1), in: text),
                   let attributedFullRange = Range(fullSwiftRange, in: attributed) {
                    let pathString = String(text[pathRange])
                    let typeString = String(text[typeRange])
                    let isFolder = typeString == "folder"

                    // Extract display name (last path component)
                    let displayName = URL(fileURLWithPath: pathString).lastPathComponent
                    let icon = isFolder ? "📁 " : "📄 "

                    // Create the styled replacement with visual pill markers
                    // Since AttributedString backgroundColor doesn't render in SwiftUI Text,
                    // we use visual brackets and styling to indicate it's a file reference
                    let pillText = "[\(icon) \(displayName)]"
                    var replacement = AttributedString(pillText)
                    if let encodedPath = pathString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                       let url = URL(string: "blazefile:\(encodedPath)") {
                        replacement.link = url
                    }
                    replacement.foregroundColor = Color.ds.accent
                    replacement.font = .system(size: 12, weight: .semibold)
                    // Try setting background again with higher opacity
                    replacement.backgroundColor = Color.ds.accent.opacity(0.25)

                    attributed.replaceSubrange(attributedFullRange, with: replacement)
                }
            }
        }

        // Second pass: Match common file path patterns (unchanged text)
        let updatedText = String(attributed.characters)
        let patterns = [
            #"/[a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+"#,  // Unix absolute paths
            #"\./[a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+"#, // Relative paths
            #"(?<![/@])[a-zA-Z0-9_\-]+\.(swift|py|js|ts|tsx|jsx|json|md|txt|yaml|yml|sh|bash|go|rs|toml|html|css)"#  // File names with common extensions (not after @ or /)
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            let nsRange = NSRange(updatedText.startIndex..., in: updatedText)
            let matches = regex.matches(in: updatedText, range: nsRange)

            for match in matches.reversed() {
                if let swiftRange = Range(match.range, in: updatedText),
                   let attributedRange = Range(swiftRange, in: attributed) {
                    let pathString = String(attributed[attributedRange].characters)
                    // Skip if already processed (has a link)
                    if attributed[attributedRange].link != nil { continue }

                    // Use custom scheme to avoid URL parsing issues with file://
                    // Add visual brackets since backgroundColor doesn't render in SwiftUI Text
                    if let encodedPath = pathString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                       let url = URL(string: "blazefile:\(encodedPath)") {
                        let displayName = URL(fileURLWithPath: pathString).lastPathComponent
                        var replacement = AttributedString("[📄 \(displayName)]")
                        replacement.link = url
                        replacement.foregroundColor = Color.ds.accent
                        replacement.font = .system(size: 12, weight: .semibold)
                        attributed.replaceSubrange(attributedRange, with: replacement)
                    }
                }
            }
        }
    }
}

// MARK: - Typing Indicator

/// Animated typing indicator shown during streaming
struct TypingIndicator: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            // Avatar
            Circle()
                .fill(Color.ds.accent.gradient)
                .frame(width: DSSize.lg, height: DSSize.lg)
                .overlay {
                    Image(systemName: "brain")
                        .font(.system(size: DSSize.xs, weight: .medium))
                        .foregroundStyle(.white)
                }

            // Dots
            HStack(spacing: DSSpacing.xxs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.ds.secondary)
                        .frame(width: DSSpacing.xs, height: DSSpacing.xs)
                        .scaleEffect(animatingDot == index ? 1.2 : 0.8)
                        .opacity(animatingDot == index ? 1.0 : 0.4)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.sm)
            .dsGlassPanel(level: .light, cornerRadius: DSRadius.xl, elevation: .none, border: .subtle)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: DSRadius.sm,
                    bottomLeadingRadius: DSRadius.xl,
                    bottomTrailingRadius: DSRadius.xl,
                    topTrailingRadius: DSRadius.xl
                )
            )

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Smooth cycling animation
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: false)) {
            animatingDot = 1
        }

        // Chain animations for each dot
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
}

// MARK: - Thinking Disclosure

/// Collapsible disclosure view for Claude's extended thinking
struct ThinkingDisclosure: View {
    let thinking: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: DSSize.xs))
                        .foregroundStyle(Color.ds.tertiary)

                    Text("Thinking")
                        .dsTextStyle(.caption, color: .ds.tertiary)

                    Spacer()

                    Text(thinkingPreview)
                        .dsTextStyle(.caption, color: .ds.tertiary)
                        .lineLimit(1)
                        .opacity(isExpanded ? 0 : 0.7)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, DSSpacing.sm)

                ScrollView {
                    Text(thinking)
                        .dsTextStyle(.body, color: .ds.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSSpacing.sm)
                }
                .frame(maxHeight: 200)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(Color.ds.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.ds.border.opacity(0.3), lineWidth: 1)
        }
    }

    private var thinkingPreview: String {
        let trimmed = thinking.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        if firstLine.count > 50 {
            return String(firstLine.prefix(50)) + "..."
        }
        return firstLine
    }
}

// MARK: - Tool Call Card

/// Compact card showing tool execution with matched geometry transitions
struct ToolCallCard: View {
    let toolCall: ToolCall
    @State private var isExpanded: Bool = false
    @Namespace private var toolCardNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (compact view)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    statusIcon
                        .frame(width: DSSize.xs, height: DSSize.xs)
                        .matchedGeometryEffect(id: "status-\(toolCall.id)", in: toolCardNamespace)

                    Text(toolCall.name)
                        .dsTextStyle(.monoSmall, weight: .medium)
                        .matchedGeometryEffect(id: "name-\(toolCall.id)", in: toolCardNamespace)

                    Spacer()

                    durationDisplay
                        .matchedGeometryEffect(id: "duration-\(toolCall.id)", in: toolCardNamespace)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .dsTextStyle(.micro, color: .ds.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(.horizontal, DSSpacing.xs + 2)
                .padding(.vertical, DSSpacing.xs)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, DSSpacing.xs + 2)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    // Input section with copy button
                    ToolCardSection(
                        title: "Input",
                        content: toolCall.input,
                        namespace: toolCardNamespace,
                        sectionId: "input-\(toolCall.id)"
                    )

                    // Output section with copy button
                    if let output = toolCall.output {
                        ToolCardSection(
                            title: "Output",
                            content: output,
                            namespace: toolCardNamespace,
                            sectionId: "output-\(toolCall.id)"
                        )
                    }
                }
                .padding(DSSpacing.xs + 2)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .low, border: .subtle)
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        }
    }

    // MARK: - Duration Display (live counter for running tools)

    @ViewBuilder
    private var durationDisplay: some View {
        if toolCall.status == .running {
            // Live counter for running tools
            LiveDurationCounter(startTime: toolCall.startedAt)
        } else if let duration = toolCall.duration {
            Text(formatDuration(duration))
                .dsTextStyle(.micro, color: .ds.tertiary)
        }
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        Group {
            switch toolCall.status {
            case .pending, .approved:
                ProgressView()
                    .scaleEffect(0.5)
            case .running:
                ProgressView()
                    .scaleEffect(0.5)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.ds.positive)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.ds.negative)
            case .rejected, .cancelled:
                Image(systemName: "slash.circle.fill")
                    .foregroundStyle(Color.ds.warning)
            }
        }
    }

    private var statusColor: Color {
        switch toolCall.status {
        case .pending, .approved, .running:
            return Color.ds.info
        case .succeeded:
            return Color.ds.positive
        case .failed:
            return Color.ds.negative
        case .rejected, .cancelled:
            return Color.ds.warning
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Tool Card Section (with copy button)

/// Reusable section for tool card input/output with copy functionality
struct ToolCardSection: View {
    let title: String
    let content: String
    let namespace: Namespace.ID
    let sectionId: String

    @State private var isHovered: Bool = false
    @State private var showCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            HStack {
                Text(title)
                    .dsTextStyle(.micro, color: .ds.secondary)

                Spacer()

                // Copy button (visible on hover)
                if isHovered || showCopied {
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack(spacing: DSSpacing.xxs) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            if showCopied {
                                Text("Copied")
                            }
                        }
                        .dsTextStyle(.micro, color: showCopied ? .ds.positive : .ds.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .dsTextStyle(.monoSmall)
                    .textSelection(.enabled)
                    .lineLimit(title == "Output" ? 10 : nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DSSpacing.xs)
        .background(Color.ds.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm + 2))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: showCopied)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

// MARK: - Live Duration Counter

/// Displays elapsed time that updates every 100ms while tool is running
struct LiveDurationCounter: View {
    let startTime: Date

    var body: some View {
        TimelineView(.periodic(from: startTime, by: 0.1)) { context in
            let elapsed = context.date.timeIntervalSince(startTime)
            Text(formatElapsed(elapsed))
                .dsTextStyle(.micro, color: .ds.info)
                .monospacedDigit()
        }
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        if elapsed < 1 {
            return String(format: "%.0fms", elapsed * 1000)
        } else if elapsed < 60 {
            return String(format: "%.1fs", elapsed)
        } else {
            let minutes = Int(elapsed / 60)
            let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Mention Dropdown

/// Floating autocomplete dropdown for @ file mentions
struct MentionDropdown: View {
    let files: [FlattenedNode]
    let selectedIndex: Int
    let onSelect: (FlattenedNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if files.isEmpty {
                Text("No matching files")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(files.enumerated()), id: \.element.id) { index, flatNode in
                                MentionRow(
                                    node: flatNode.node,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(flatNode)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 250, maxWidth: 400)
        .dsGlassPanel(level: .light, cornerRadius: DSRadius.md, elevation: .high, border: .subtle)
    }
}

/// Single row in the mention dropdown
struct MentionRow: View {
    let node: FileTreeNode
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: node.iconName)
                .font(.system(size: 12))
                .foregroundStyle(Color.ds.secondary)
                .frame(width: 16)

            Text(node.name)
                .dsTextStyle(.body)
                .lineLimit(1)

            Spacer()

            // Show parent directory for context
            if let parent = parentPath {
                Text(parent)
                    .dsTextStyle(.caption, color: .ds.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(isSelected ? Color.ds.accent.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }

    private var parentPath: String? {
        let path = node.url.deletingLastPathComponent().lastPathComponent
        return path.isEmpty || path == "/" ? nil : path
    }
}

// MARK: - File Pill

/// Pill-style display for a mentioned file
struct FilePill: View {
    let file: FileReference
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(Color.ds.secondary)

            Text(file.url.lastPathComponent)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.ds.foreground)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.ds.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.ds.accent.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.ds.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var iconName: String {
        if file.isDirectory {
            return "folder.fill"
        }
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "markdown": return "doc.text"
        case "json": return "curlybraces"
        case "sh", "bash": return "terminal"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "ts", "js": return "j.square"
        default: return "doc"
        }
    }
}

// MARK: - Mention Chip (Removable, for input area)

/// Chip-style display for selected file mentions above the input field
struct MentionChip: View {
    let mention: FileReference
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))

            Text(mention.url.lastPathComponent)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(Color.ds.accent.gradient)
        .clipShape(Capsule())
    }

    private var iconName: String {
        if mention.isDirectory {
            return "folder.fill"
        }
        let ext = mention.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "markdown": return "doc.text"
        case "json": return "curlybraces"
        case "sh", "bash": return "terminal"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "ts", "js": return "j.square"
        default: return "doc"
        }
    }
}

// MARK: - File Pill Inline (Read-Only)

/// Read-only pill for displaying file mentions in message bubbles
struct FilePillInline: View {
    let path: String
    let isDirectory: Bool
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: 9))

                Text(displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "markdown": return "doc.text"
        case "json": return "curlybraces"
        case "sh", "bash": return "terminal"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "ts", "js": return "j.square"
        default: return "doc"
        }
    }
}

// MARK: - User Message Content (with inline pills)

/// Parses @file: and @folder: tokens and renders them as clickable links
struct UserMessageContent: View {
    let content: String
    var onFilePathTapped: ((String) -> Void)?

    var body: some View {
        Text(attributedText)
            .dsTextStyle(.body)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "blazefile" {
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
        var attributed = AttributedString(content)
        let text = content
        let pattern = #"@(file|folder):([^\s]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributed
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        // Process in reverse to preserve indices
        for match in matches.reversed() {
            if let fullRange = Range(match.range, in: text),
               let pathRange = Range(match.range(at: 2), in: text),
               let typeRange = Range(match.range(at: 1), in: text),
               let attributedRange = Range(fullRange, in: attributed) {
                let pathString = String(text[pathRange])
                let typeString = String(text[typeRange])
                let displayName = URL(fileURLWithPath: pathString).lastPathComponent
                let icon = typeString == "folder" ? "📁" : "📄"

                var replacement = AttributedString("[\(icon) \(displayName)]")
                if let encodedPath = pathString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                   let url = URL(string: "blazefile:\(encodedPath)") {
                    replacement.link = url
                }
                replacement.foregroundColor = .white.opacity(0.9)
                replacement.font = .system(size: 13, weight: .medium)

                attributed.replaceSubrange(attributedRange, with: replacement)
            }
        }
        return attributed
    }

    private enum Segment {
        case text(String)
        case file(String)
        case folder(String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var remaining = content

        // Pattern: @file:path or @folder:path (path ends at whitespace or end of string)
        let pattern = #"@(file|folder):([^\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(content)]
        }

        while !remaining.isEmpty {
            let nsRange = NSRange(remaining.startIndex..., in: remaining)
            guard let match = regex.firstMatch(in: remaining, range: nsRange),
                  let typeRange = Range(match.range(at: 1), in: remaining),
                  let pathRange = Range(match.range(at: 2), in: remaining),
                  let fullRange = Range(match.range, in: remaining) else {
                // No more matches - add remaining text
                if !remaining.isEmpty {
                    result.append(.text(remaining))
                }
                break
            }

            // Add text before match
            let textBefore = String(remaining[remaining.startIndex..<fullRange.lowerBound])
            if !textBefore.isEmpty {
                result.append(.text(textBefore))
            }

            // Add file/folder segment
            let type = String(remaining[typeRange])
            let path = String(remaining[pathRange])
            if type == "folder" {
                result.append(.folder(path))
            } else {
                result.append(.file(path))
            }

            // Move past this match
            remaining = String(remaining[fullRange.upperBound...])
        }

        return result
    }
}

// MARK: - Flow Layout

/// Simple flow layout for wrapping content
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Wrap to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

// MARK: - Chat Input View

/// Message input with multi-line support, @ file mentions, and model/reasoning dropdowns
struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void

    // Session config for dropdowns
    let provider: AIProvider
    @Binding var modelId: String
    @Binding var reasoningEffort: ReasoningEffort

    @EnvironmentObject var fileTreeViewModel: FileTreeViewModel
    @FocusState private var isFocused: Bool

    // Mention state
    @State private var mentionContext: MentionContext?
    @State private var filteredFiles: [FlattenedNode] = []

    // Selected file mentions shown as chips above input
    @State private var selectedMentions: [FileReference] = []

    private let maxResults = 10

    /// Whether @ mentions are available (file tree has loaded files)
    private var mentionsEnabled: Bool {
        !fileTreeViewModel.flattenedNodes.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mention dropdown (positioned above input)
            if let context = mentionContext, !filteredFiles.isEmpty || !context.query.isEmpty {
                HStack {
                    MentionDropdown(
                        files: filteredFiles,
                        selectedIndex: context.selectedIndex,
                        onSelect: { flatNode in
                            insertFileReference(flatNode)
                        }
                    )
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.bottom, DSSpacing.xs)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }

            // Selected mentions chips (above input)
            if !selectedMentions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.xs) {
                        ForEach(selectedMentions) { mention in
                            MentionChip(mention: mention) {
                                removeMention(mention)
                            }
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.xs)
                }
                .background(Color.ds.surface.opacity(0.5))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }

            // Input row
            HStack(alignment: .center, spacing: DSSpacing.sm) {
                // Styled input with inline token highlighting
                StyledInputEditor(
                    text: $text,
                    onSubmit: {
                        // If mention dropdown is open and has selection, insert file
                        if let context = mentionContext, !filteredFiles.isEmpty {
                            let index = min(context.selectedIndex, filteredFiles.count - 1)
                            insertFileReference(filteredFiles[index])
                            return
                        }
                        // Otherwise send message
                        sendAndClearChips()
                    },
                    onTextChange: { oldValue, newValue in
                        detectMentionTrigger(oldValue: oldValue, newValue: newValue)
                    },
                    onEscape: {
                        if mentionContext != nil {
                            dismissMention()
                        }
                    },
                    onArrowUp: {
                        _ = handleArrowKey(direction: -1)
                    },
                    onArrowDown: {
                        _ = handleArrowKey(direction: 1)
                    },
                    onTab: {
                        if let context = mentionContext, !filteredFiles.isEmpty {
                            let index = min(context.selectedIndex, filteredFiles.count - 1)
                            insertFileReference(filteredFiles[index])
                        }
                    }
                )

                // Model/Reasoning dropdowns (between input and send button)
                SessionConfigBar(
                    provider: provider,
                    modelId: $modelId,
                    reasoningEffort: $reasoningEffort
                )

                // Send button
                Button(action: sendAndClearChips) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(text.isEmpty ? Color.ds.secondary : Color.ds.accent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, DSSpacing.md)
            .frame(minHeight: 40)
            .background(Color.ds.surface.opacity(0.7))
        }
        .animation(.easeOut(duration: 0.15), value: mentionContext != nil)
    }

    // MARK: - Mention Detection

    private func detectMentionTrigger(oldValue: String, newValue: String) {
        // Skip if mentions not enabled (no file tree available)
        guard mentionsEnabled else { return }

        // Check if @ was just typed
        if newValue.count > oldValue.count {
            let addedCharIndex = newValue.index(newValue.startIndex, offsetBy: oldValue.count)
            if addedCharIndex < newValue.endIndex && newValue[addedCharIndex] == "@" {
                // Check if @ is at start or preceded by whitespace
                if addedCharIndex == newValue.startIndex ||
                   newValue[newValue.index(before: addedCharIndex)].isWhitespace {
                    // Start mention context
                    mentionContext = MentionContext(triggerIndex: addedCharIndex, query: "")
                    updateFilteredFiles(query: "")
                    return
                }
            }
        }

        // If we have an active mention context, update the query
        if var context = mentionContext {
            // Check if the trigger index is still valid
            guard context.triggerIndex < newValue.endIndex,
                  newValue[context.triggerIndex] == "@" else {
                dismissMention()
                return
            }

            // Extract query (text after @ until space or end)
            let afterTrigger = newValue.index(after: context.triggerIndex)
            var endIndex = afterTrigger
            while endIndex < newValue.endIndex && !newValue[endIndex].isWhitespace {
                endIndex = newValue.index(after: endIndex)
            }

            // If there's a space right after the query started, dismiss
            if afterTrigger < newValue.endIndex && newValue[afterTrigger].isWhitespace {
                dismissMention()
                return
            }

            let query = String(newValue[afterTrigger..<endIndex])
            context.query = query
            context.selectedIndex = 0  // Reset selection on query change
            mentionContext = context
            updateFilteredFiles(query: query)
        }
    }

    private func updateFilteredFiles(query: String) {
        // Include both files and directories
        let allNodes = fileTreeViewModel.flattenedNodes

        if query.isEmpty {
            // Show first N nodes when no query
            filteredFiles = Array(allNodes.prefix(maxResults))
        } else {
            // Case-insensitive contains matching
            let lowercaseQuery = query.lowercased()
            filteredFiles = allNodes
                .filter { $0.node.name.lowercased().contains(lowercaseQuery) }
                .prefix(maxResults)
                .map { $0 }
        }
    }

    // MARK: - Keyboard Navigation

    private func handleArrowKey(direction: Int) -> KeyPress.Result {
        guard var context = mentionContext, !filteredFiles.isEmpty else {
            return .ignored
        }

        let newIndex = context.selectedIndex + direction
        if newIndex >= 0 && newIndex < filteredFiles.count {
            context.selectedIndex = newIndex
            mentionContext = context
        }
        return .handled
    }

    // MARK: - File Insertion

    private func insertFileReference(_ flatNode: FlattenedNode) {
        guard let context = mentionContext else { return }

        let fileRef = fileTreeViewModel.createFileReference(for: flatNode.node)

        // Add to selected mentions (shown as chips above input)
        if !selectedMentions.contains(where: { $0.relativePath == fileRef.relativePath }) {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedMentions.append(fileRef)
            }
        }

        // Replace @query with the token inline (e.g., @folder:migrations)
        // This keeps the token at the cursor position in the text
        let replacementRange = context.replacementRange(in: text)
        let tokenText = fileRef.token + " "  // Add trailing space for UX
        text.replaceSubrange(replacementRange, with: tokenText)

        dismissMention()
    }

    private func removeMention(_ mention: FileReference) {
        // Remove from chips
        withAnimation(.easeOut(duration: 0.15)) {
            selectedMentions.removeAll { $0.id == mention.id }
        }

        // Also remove the token from text
        let tokenPattern = mention.token
        if let range = text.range(of: tokenPattern + " ") {
            text.removeSubrange(range)
        } else if let range = text.range(of: tokenPattern) {
            text.removeSubrange(range)
        }
    }

    private func dismissMention() {
        mentionContext = nil
        filteredFiles = []
    }

    private func sendAndClearChips() {
        onSend()
        // Clear the chips after sending
        withAnimation(.easeOut(duration: 0.15)) {
            selectedMentions.removeAll()
        }
    }
}

// MARK: - Preview

// MARK: - Error Banner

/// Dismissible error banner shown at top of chat
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(message)
                .dsTextStyle(.body)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Button {
                withAnimation {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(Color.ds.negative.gradient)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Previews

#Preview("Chat Timeline") {
    let session = Session(name: "Test Session")
    return ChatTimelineView(session: session)
        .environmentObject(AppState())
        .environmentObject(FileTreeViewModel.empty)
        .frame(width: 600, height: 800)
}

#Preview("Message Bubbles") {
    VStack(spacing: DSSpacing.md) {
        MessageBubble(message: Message(role: .user, content: "Hello, can you help me with Swift?"))
        MessageBubble(message: Message(role: .assistant, content: "Of course! I'd be happy to help you with Swift. What would you like to know?"))
        MessageBubble(message: Message(role: .system, content: "Session started"))
    }
    .padding(DSSpacing.md)
    .frame(width: 500)
}

#Preview("Typing Indicator") {
    TypingIndicator()
        .padding()
        .frame(width: 300)
}
