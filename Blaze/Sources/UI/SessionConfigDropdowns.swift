import SwiftUI

// MARK: - Model Selector Dropdown

/// Compact dropdown for selecting AI model in the chat input bar.
/// Shows provider-appropriate models based on current session.
struct ModelSelectorDropdown: View {
    let provider: AIProvider
    @Binding var selectedModelId: String

    private var availableModels: [AIModel] {
        AIModelRegistry.models(for: provider)
    }

    private var selectedModel: AIModel? {
        availableModels.first { $0.id == selectedModelId }
    }

    var body: some View {
        Menu {
            ForEach(availableModels, id: \.id) { model in
                Button {
                    selectedModelId = model.id
                } label: {
                    HStack {
                        Text(model.name)
                        if model.isDefault {
                            Text("(Default)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.id == selectedModelId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tierIcon)
                    .font(.system(size: 10))
                Text(selectedModel?.name ?? "Model")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.ds.surface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.ds.border.opacity(0.5), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var tierIcon: String {
        switch selectedModel?.tier {
        case .flagship: return "star.fill"
        case .balanced: return "scale.3d"
        case .fast: return "hare"
        case nil: return "cpu"
        }
    }
}

// MARK: - Reasoning Selector Dropdown

/// Compact dropdown for selecting reasoning effort (OpenAI o-series only).
struct ReasoningSelectorDropdown: View {
    @Binding var selectedEffort: ReasoningEffort

    var body: some View {
        Menu {
            ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                Button {
                    selectedEffort = effort
                } label: {
                    HStack {
                        Image(systemName: effort.icon)
                        Text(effort.displayName)
                        Spacer()
                        if effort == selectedEffort {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10))
                Text(selectedEffort.displayName.lowercased())
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.ds.surface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.ds.border.opacity(0.5), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Combined Session Config Bar

/// Container that shows provider-appropriate dropdowns.
/// - Claude: Model only (Sonnet, Opus, Haiku)
/// - OpenAI: Model + Reasoning effort
/// - Gemini: Model only
struct SessionConfigBar: View {
    let provider: AIProvider
    @Binding var modelId: String
    @Binding var reasoningEffort: ReasoningEffort

    var body: some View {
        HStack(spacing: 6) {
            // Model dropdown (all providers)
            ModelSelectorDropdown(
                provider: provider,
                selectedModelId: $modelId
            )

            // Reasoning dropdown (OpenAI only)
            if provider == .openai {
                ReasoningSelectorDropdown(
                    selectedEffort: $reasoningEffort
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Model Selector - Claude") {
    @Previewable @State var modelId = "sonnet"

    ModelSelectorDropdown(
        provider: .anthropic,
        selectedModelId: $modelId
    )
    .padding()
}

#Preview("Reasoning Selector") {
    @Previewable @State var effort = ReasoningEffort.medium

    ReasoningSelectorDropdown(selectedEffort: $effort)
        .padding()
}

#Preview("Session Config Bar - OpenAI") {
    @Previewable @State var modelId = "gpt-5.2-codex"
    @Previewable @State var effort = ReasoningEffort.medium

    SessionConfigBar(
        provider: .openai,
        modelId: $modelId,
        reasoningEffort: $effort
    )
    .padding()
}

#Preview("Session Config Bar - Claude") {
    @Previewable @State var modelId = "sonnet"
    @Previewable @State var effort = ReasoningEffort.medium

    SessionConfigBar(
        provider: .anthropic,
        modelId: $modelId,
        reasoningEffort: $effort
    )
    .padding()
}
