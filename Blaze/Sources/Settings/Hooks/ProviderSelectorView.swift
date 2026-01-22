import SwiftUI

// MARK: - Provider Selector View

/// A segmented control for selecting a hook provider.
///
/// Displays all HookProvider cases with event count badges.
/// Providers that don't support hooks are disabled.
///
/// **E005-F004-S001-T005-A001**
public struct ProviderSelectorView: View {
    // MARK: - Properties

    @Binding var selectedProvider: HookProvider

    // MARK: - Body

    public var body: some View {
        Picker("Provider", selection: $selectedProvider) {
            ForEach(HookProvider.allCases) { provider in
                providerLabel(for: provider)
                    .tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: - Private Views

    @ViewBuilder
    private func providerLabel(for provider: HookProvider) -> some View {
        let capability = HookCapability.forProvider(provider)
        let eventCount = capability.supportedEvents.count

        HStack(spacing: 4) {
            Text(provider.displayName)

            Text("(\(eventCount))")
                .foregroundStyle(provider.supportsHooks ? .secondary : .tertiary)
        }
        .opacity(provider.supportsHooks ? 1.0 : 0.5)
    }

    // MARK: - Initializer

    public init(selectedProvider: Binding<HookProvider>) {
        self._selectedProvider = selectedProvider
    }
}

// MARK: - Preview

#if DEBUG
struct ProviderSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        ProviderSelectorPreviewContainer()
            .padding()
            .frame(width: 400)
    }
}

private struct ProviderSelectorPreviewContainer: View {
    @State private var selected: HookProvider = .claude

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Selected: \(selected.displayName)")
                .font(.headline)

            ProviderSelectorView(selectedProvider: $selected)

            Text("Supports hooks: \(selected.supportsHooks ? "Yes" : "No")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
