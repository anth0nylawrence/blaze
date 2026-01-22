import SwiftUI

// MARK: - GhosttyUnavailableBanner (E003-F001-S003-T003-A003)

/// Warning banner shown when Ghostty backend is selected but not available.
///
/// **Phase 3 Ghostty Integration:**
/// - Shows when user selects Ghostty but libghostty is not installed
/// - Offers quick switch to SwiftTerm fallback
/// - Informative message about Ghostty availability
struct GhosttyUnavailableBanner: View {
    let onSwitchToSwiftTerm: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ds.warning)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Ghostty Terminal Not Available")
                    .dsTextStyle(.body, color: .ds.warning)
                    .fontWeight(.medium)

                Text("libghostty is not yet released. Using SwiftTerm as fallback.")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }

            Spacer()

            Button("Switch to SwiftTerm") {
                onSwitchToSwiftTerm()
            }
            .buttonStyle(.bordered)
        }
        .padding(DSSpacing.md)
        .background(Color.ds.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - Previews

#Preview("Ghostty Unavailable Banner") {
    GhosttyUnavailableBanner(onSwitchToSwiftTerm: {})
        .padding()
        .background(Color.ds.bg0)
}
