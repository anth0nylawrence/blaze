import SwiftUI

// MARK: - Tokens Sidebar View

/// Tab 8: Token usage sidebar showing pre-loaded, session, and available tokens.
///
/// **Phase 2 Spec:**
/// - Three-tier display: Pre-loaded | Session | Available
/// - Pre-loaded: Estimate from CLAUDE.md + context files (~4 chars per token)
/// - Progress bar showing usage vs model limit
/// - Model detection: Parse from CLI output or default to Claude
/// - Show breakdown by category (system prompt, conversation, tools)
struct TokensSidebarView: View {
    let sessionId: UUID?
    let events: [EventEnvelope]

    @EnvironmentObject var appState: AppState
    @State private var breakdown: TokenEstimator.TokenBreakdown = .init()
    @State private var selectedModelId: String = "sonnet"
    @State private var isLoading: Bool = false

    // Get models from ModelService based on current engine
    private var availableModels: [ModelService.ModelInfo] {
        let engineType = appState.currentSession?.engineType ?? .claude
        return ModelService.models(for: engineType)
    }

    private var selectedModel: ModelService.ModelInfo? {
        availableModels.first { $0.id == selectedModelId }
    }

    private var contextLimit: Int {
        // Claude models: 200K context
        // Can be extended based on model when more info available
        200_000
    }

    // MARK: - Computed Properties

    private var latestTokenUsage: TokenUsage? {
        for envelope in events.reversed() {
            if case .tokenUsage(let usage) = envelope.event {
                return usage
            }
        }
        return nil
    }

    private var session: Session? {
        guard let id = sessionId else { return nil }
        return appState.sessions.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                // Usage progress bar
                usageProgressSection

                Divider()

                // Model selector
                modelSelectorSection

                Divider()

                // Token breakdown by category
                breakdownSection

                // Actual usage from CLI (if available)
                if let usage = latestTokenUsage {
                    Divider()
                    actualUsageSection(usage)
                }

                Spacer()
            }
            .padding(DSSpacing.md)
        }
        .task {
            await calculateTokens()
        }
    }

    // MARK: - Usage Progress Section

    /// Use CLI data when available, fall back to estimates
    private var effectiveUsedTokens: Int {
        if let usage = latestTokenUsage {
            return usage.totalTokens
        }
        return breakdown.total
    }

    private var effectiveUsagePercentage: Double {
        Double(effectiveUsedTokens) / Double(contextLimit)
    }

    private var effectiveAvailable: Int {
        max(0, contextLimit - effectiveUsedTokens)
    }

    private var usageProgressSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Header
            HStack {
                Label("Context Usage", systemImage: "chart.bar.fill")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await calculateTokens()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ds.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Progress bar - use CLI data when available
            TokenProgressBar(
                used: effectiveUsedTokens,
                limit: contextLimit,
                usagePercentage: effectiveUsagePercentage
            )

            // Summary stats - use CLI data when available
            HStack(spacing: DSSpacing.lg) {
                TokenStatBadge(
                    label: "Used",
                    value: effectiveUsedTokens.formattedTokens,
                    color: usageColor
                )

                TokenStatBadge(
                    label: "Available",
                    value: effectiveAvailable.formattedTokens,
                    color: .ds.positive
                )

                TokenStatBadge(
                    label: "Limit",
                    value: contextLimit.formattedTokens,
                    color: .ds.secondary
                )
            }
        }
        .padding(DSSpacing.md)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.lg, elevation: .low)
    }

    private var usageColor: Color {
        if effectiveUsagePercentage > 0.9 {
            return .ds.negative
        } else if effectiveUsagePercentage > 0.7 {
            return .ds.warning
        }
        return .ds.info
    }

    // MARK: - Model Selector Section

    private var modelSelectorSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Model", systemImage: "cpu")
                .dsTextStyle(.caption, color: .ds.secondary)

            Picker("Model", selection: $selectedModelId) {
                ForEach(availableModels) { model in
                    Text(model.displayName)
                        .tag(model.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: selectedModelId) { _, _ in
                Task {
                    await calculateTokens()
                }
            }
        }
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Breakdown", systemImage: "chart.pie")
                .dsTextStyle(.caption, color: .ds.secondary)

            VStack(spacing: DSSpacing.xs) {
                TokenBreakdownRow(
                    label: "Pre-loaded (CLAUDE.md, context)",
                    tokens: breakdown.preloaded,
                    icon: "doc.text.fill",
                    color: .ds.accent
                )

                TokenBreakdownRow(
                    label: "System Prompt",
                    tokens: breakdown.systemPrompt,
                    icon: "gearshape.fill",
                    color: .ds.info
                )

                TokenBreakdownRow(
                    label: "Conversation",
                    tokens: breakdown.conversation,
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .ds.positive
                )

                TokenBreakdownRow(
                    label: "Tool Outputs",
                    tokens: breakdown.toolOutputs,
                    icon: "wrench.and.screwdriver.fill",
                    color: .ds.warning
                )
            }
            .padding(DSSpacing.sm)
            .background(Color.ds.surface.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        }
    }

    // MARK: - Actual Usage Section (from CLI)

    private func actualUsageSection(_ usage: TokenUsage) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Actual Usage (from CLI)", systemImage: "checkmark.circle.fill")
                .dsTextStyle(.caption, color: .ds.positive)

            VStack(spacing: DSSpacing.xs) {
                ActualTokenRow(label: "Input Tokens", value: usage.inputTokens)
                ActualTokenRow(label: "Output Tokens", value: usage.outputTokens)
                if let cacheRead = usage.cacheReadTokens {
                    ActualTokenRow(label: "Cache Read", value: cacheRead)
                }

                Divider()

                ActualTokenRow(label: "Total", value: usage.totalTokens, bold: true)
            }
            .padding(DSSpacing.sm)
            .background(Color.ds.positive.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        }
    }

    // MARK: - Calculate Tokens

    private func calculateTokens() async {
        isLoading = true
        defer { isLoading = false }

        // Try to get aggregated usage from TokenStore first
        if let store = appState.tokenStore, let sid = sessionId {
            do {
                let aggregated = try await store.getAggregatedUsage(sessionId: sid)

                // Use actual token data from store
                await MainActor.run {
                    let total = aggregated.grandTotalTokens
                    let available = max(0, contextLimit - total)

                    // Break down by input/output since we have that data
                    breakdown = TokenEstimator.TokenBreakdown(
                        preloaded: 0, // Not tracked separately in store yet
                        systemPrompt: aggregated.totalInputTokens, // System + user input
                        conversation: 0, // Included in input
                        toolOutputs: aggregated.totalOutputTokens,
                        available: available
                    )
                }
                return
            } catch {
                // Fall back to estimation if store fails
                print("[TokensSidebarView] Failed to get usage from store: \(error)")
            }
        }

        // Fallback: Estimate tokens if store is unavailable
        let estimator = TokenEstimator()

        // Get preloaded content
        var preloadedTokens = 0
        if let projectPath = session?.effectiveWorkingDirectory {
            let claudeMDPath = URL(fileURLWithPath: projectPath).appendingPathComponent("CLAUDE.md")
            if FileManager.default.fileExists(atPath: claudeMDPath.path) {
                preloadedTokens += (try? await estimator.estimateFileTokens(claudeMDPath)) ?? 0
            }
        }

        // Estimate conversation tokens from messages
        var conversationTokens = 0
        if let messages = session?.messages {
            for message in messages {
                conversationTokens += await estimator.estimateMessageTokens(message.content)
            }
        }

        // Estimate tool output tokens from events
        var toolOutputTokens = 0
        for envelope in events {
            switch envelope.event {
            case .toolCallComplete(let complete):
                if let output = complete.output {
                    toolOutputTokens += await estimator.estimateTokens(output)
                }
            case .toolResult(let result):
                if let output = result.output {
                    toolOutputTokens += await estimator.estimateTokens(output)
                }
            default:
                break
            }
        }

        // Calculate breakdown
        let systemPromptTokens = 1500 // Rough estimate for Claude Code system prompt

        await MainActor.run {
            let total = preloadedTokens + systemPromptTokens + conversationTokens + toolOutputTokens
            let available = max(0, contextLimit - total)

            breakdown = TokenEstimator.TokenBreakdown(
                preloaded: preloadedTokens,
                systemPrompt: systemPromptTokens,
                conversation: conversationTokens,
                toolOutputs: toolOutputTokens,
                available: available
            )
        }
    }
}

// MARK: - Token Progress Bar

struct TokenProgressBar: View {
    let used: Int
    let limit: Int
    let usagePercentage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ds.surface.opacity(0.5))

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillGradient)
                    .frame(width: geometry.size.width * min(usagePercentage, 1.0))
                    .animation(.easeInOut(duration: 0.3), value: usagePercentage)

                // Threshold markers
                thresholdMarkers(width: geometry.size.width)
            }
        }
        .frame(height: 8)
    }

    private var fillGradient: LinearGradient {
        let color: Color = {
            if usagePercentage > 0.9 {
                return .ds.negative
            } else if usagePercentage > 0.7 {
                return .ds.warning
            }
            return .ds.accent
        }()

        return LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private func thresholdMarkers(width: CGFloat) -> some View {
        // 70% warning threshold
        Rectangle()
            .fill(Color.ds.warning.opacity(0.5))
            .frame(width: 1, height: 8)
            .offset(x: width * 0.7)

        // 90% danger threshold
        Rectangle()
            .fill(Color.ds.negative.opacity(0.5))
            .frame(width: 1, height: 8)
            .offset(x: width * 0.9)
    }
}

// MARK: - Token Stat Badge

struct TokenStatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)

            Text(label)
                .dsTextStyle(.micro, color: .ds.tertiary)
        }
    }
}

// MARK: - Token Breakdown Row

struct TokenBreakdownRow: View {
    let label: String
    let tokens: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .dsTextStyle(.caption)
                .lineLimit(1)

            Spacer()

            Text(tokens.formattedTokens)
                .dsTextStyle(.monoSmall, color: color)
        }
    }
}

// MARK: - Actual Token Row

struct ActualTokenRow: View {
    let label: String
    let value: Int
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .dsTextStyle(bold ? .body : .caption, color: bold ? .ds.foreground : .ds.secondary)

            Spacer()

            Text(value.formattedTokens)
                .dsTextStyle(.monoSmall, color: bold ? .ds.foreground : .ds.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Tokens Sidebar") {
    TokensSidebarView(sessionId: UUID(), events: [])
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
        .background(Color.ds.bg0)
}
