//
//  OtherSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

/// Settings view for miscellaneous options including developer tools.
struct OtherSettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showResetConfirmation = false
    @State private var showResetFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Onboarding Section
                FormSection(
                    title: "Onboarding",
                    description: "Reset first-run experience to see the welcome flow again"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack(spacing: DSSpacing.md) {
                            GlassButton(
                                "Reset Onboarding",
                                icon: "arrow.counterclockwise",
                                style: .secondary,
                                size: .medium
                            ) {
                                showResetConfirmation = true
                            }

                            if hasCompletedOnboarding {
                                HStack(spacing: DSSpacing.xs) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.ds.positive)
                                        .font(.system(size: 12))
                                    Text("Onboarding completed")
                                        .dsTextStyle(.caption, color: .ds.secondary)
                                }
                            } else {
                                HStack(spacing: DSSpacing.xs) {
                                    Image(systemName: "circle")
                                        .foregroundStyle(Color.ds.secondary)
                                        .font(.system(size: 12))
                                    Text("Onboarding not completed")
                                        .dsTextStyle(.caption, color: .ds.secondary)
                                }
                            }
                        }

                        if showResetFeedback {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.ds.positive)
                                Text("Onboarding reset. Restart the app to see the welcome flow.")
                                    .dsTextStyle(.caption, color: .ds.secondary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(
            "Reset Onboarding?",
            isPresented: $showResetConfirmation
        ) {
            Button("Reset", role: .destructive) {
                resetOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset the onboarding state. Restart the app to see the welcome flow again.")
        }
    }

    // MARK: - Actions

    private func resetOnboarding() {
        hasCompletedOnboarding = false

        // Show feedback with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            showResetFeedback = true
        }

        // Hide feedback after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showResetFeedback = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OtherSettingsView()
        .frame(width: 600, height: 400)
        .background(Color.ds.bg0)
}
