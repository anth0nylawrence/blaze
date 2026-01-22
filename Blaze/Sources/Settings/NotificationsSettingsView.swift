//
//  NotificationsSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import AppKit
import SwiftUI
import UserNotifications

/// Settings view for notification preferences.
/// Includes desktop notifications, sound picker, badge, DND schedule, and test notification.
struct NotificationsSettingsView: View {
    @AppStorage("enableNotifications") private var enabled: Bool = true
    @AppStorage("notificationSound") private var sound: String = "default"
    @AppStorage("showBadge") private var badge: Bool = true
    @AppStorage("dndStart") private var dndStart: Int = 22
    @AppStorage("dndEnd") private var dndEnd: Int = 8

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var hasCheckedPermission = false
    @State private var systemSounds: [String] = []
    @State private var isPlayingPreview = false
    @State private var showTestFeedback = false

    /// Check if we have a valid bundle (required for UNUserNotificationCenter)
    private var hasBundleIdentifier: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Debug build warning (no bundle = no notifications)
                if !hasBundleIdentifier {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.ds.secondary)
                        Text("Notifications unavailable in debug builds. Run from .app bundle to enable.")
                            .dsTextStyle(.body, color: .ds.secondary)
                    }
                    .padding(DSSpacing.md)
                    .background(Color.ds.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Permission Status Banner (if denied)
                if hasBundleIdentifier && notificationStatus == .denied {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ds.warning)
                        Text("Notifications are disabled in System Settings")
                            .dsTextStyle(.body, color: .ds.warning)
                        Spacer()
                        Button("Open Settings") {
                            openNotificationSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(DSSpacing.md)
                    .background(Color.ds.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Alerts Section
                FormSection(
                    title: "Alerts",
                    description: "Control how Blaze notifies you about important events"
                ) {
                    GlassToggle(
                        "Desktop Notifications",
                        isOn: $enabled,
                        description: "Show system notifications for task completions and errors"
                    )
                    .onChange(of: enabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }

                    GlassToggle(
                        "Badge on Dock",
                        isOn: $badge,
                        description: "Show unread count on app icon"
                    )
                }

                // Sound Section
                FormSection(
                    title: "Sound",
                    description: "Choose the sound for notifications"
                ) {
                    HStack(spacing: DSSpacing.md) {
                        Picker("Sound", selection: $sound) {
                            Text("None").tag("none")
                            Text("Default").tag("default")
                            Divider()
                            ForEach(systemSounds, id: \.self) { soundName in
                                Text(soundName).tag(soundName.lowercased())
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(minWidth: 150)

                        Button {
                            playPreviewSound()
                        } label: {
                            Image(systemName: isPlayingPreview ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .frame(width: 20)
                        }
                        .buttonStyle(.bordered)
                        .disabled(sound == "none")
                        .help("Preview sound")
                    }
                }

                // Test Notification Section
                FormSection(
                    title: "Test",
                    description: hasBundleIdentifier
                        ? "Send a test notification to verify your settings"
                        : "Preview sound (notifications require app bundle)"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        GlassButton(
                            hasBundleIdentifier ? "Send Test Notification" : "Play Sound Preview",
                            icon: hasBundleIdentifier ? "bell.badge" : "speaker.wave.2",
                            style: .secondary,
                            size: .medium,
                            action: sendTestNotification
                        )

                        if showTestFeedback {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.ds.positive)
                                Text(hasBundleIdentifier
                                    ? "Test notification sent"
                                    : "Sound preview (notifications require app bundle)")
                                    .dsTextStyle(.caption, color: .ds.secondary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Do Not Disturb Section
                FormSection(
                    title: "Do Not Disturb",
                    description: "Silence notifications during these hours (24-hour format)"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Start hour picker
                        HStack {
                            Text("Start")
                                .dsTextStyle(.body)
                                .frame(width: 80, alignment: .leading)

                            Picker("Start Hour", selection: $dndStart) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        // End hour picker
                        HStack {
                            Text("End")
                                .dsTextStyle(.body)
                                .frame(width: 80, alignment: .leading)

                            Picker("End Hour", selection: $dndEnd) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        // DND status display
                        if isDNDActive {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 12))
                                Text("Do Not Disturb is currently active")
                                    .dsTextStyle(.caption, color: .ds.secondary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Load system sounds
            loadSystemSounds()

            // Check permission on appear (avoids .task async issues)
            // Only check if we have a valid bundle (required for UNUserNotificationCenter)
            if !hasCheckedPermission && hasBundleIdentifier {
                hasCheckedPermission = true
                checkNotificationPermissionSync()
            }
        }
        .alert(
            "Notification Permission Required",
            isPresented: $showingPermissionAlert
        ) {
            Button("Open System Settings") {
                openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications in System Settings to receive alerts from Blaze.")
        }
    }

    // MARK: - Helpers

    private var isDNDActive: Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        if dndStart < dndEnd {
            // Same day range (e.g., 8am to 10pm)
            return currentHour >= dndStart && currentHour < dndEnd
        } else {
            // Overnight range (e.g., 10pm to 8am)
            return currentHour >= dndStart || currentHour < dndEnd
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a" // e.g., "10 PM"

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0

        guard let date = calendar.date(from: components) else {
            return "\(hour):00"
        }

        return formatter.string(from: date)
    }

    /// Scan /System/Library/Sounds/ for available .aiff files
    private func loadSystemSounds() {
        let soundsPath = "/System/Library/Sounds"
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: soundsPath) else {
            // Fallback to known macOS sounds if directory scan fails
            systemSounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
                           "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
                           "Submarine", "Tink"]
            return
        }

        // Filter for .aiff files and extract names
        systemSounds = contents
            .filter { $0.hasSuffix(".aiff") }
            .map { $0.replacingOccurrences(of: ".aiff", with: "") }
            .sorted()
    }

    /// Play preview of the selected sound
    private func playPreviewSound() {
        guard sound != "none" else { return }

        // Map stored value back to sound name
        let soundName: String
        if sound == "default" {
            // Default system alert sound
            NSSound.beep()
            return
        } else {
            // Find matching system sound (case-insensitive)
            soundName = systemSounds.first { $0.lowercased() == sound } ?? sound.capitalized
        }

        // Play the sound using NSSound
        if let nsSound = NSSound(named: NSSound.Name(soundName)) {
            isPlayingPreview = true
            nsSound.play()

            // Reset icon after sound duration (most are ~0.5s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPlayingPreview = false
            }
        }
    }

    /// Synchronous permission check that dispatches to async context safely
    private func checkNotificationPermissionSync() {
        guard hasBundleIdentifier else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        guard hasBundleIdentifier else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission request failed: \(error)")
                    return
                }
                if !granted {
                    self.showingPermissionAlert = true
                }
                self.checkNotificationPermissionSync()
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func sendTestNotification() {
        // Always play sound preview first (works without bundle)
        playPreviewSound()

        // Show feedback with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            showTestFeedback = true
        }

        // Hide feedback after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTestFeedback = false
            }
        }

        // Only send actual notification if we have bundle
        guard hasBundleIdentifier else { return }
        guard enabled else {
            print("Notifications are disabled")
            return
        }

        // Check if we're in DND
        if isDNDActive {
            print("Do Not Disturb is active, skipping notification")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Blaze. Your notification settings are working correctly."

        // Set sound based on preference
        switch sound {
        case "none":
            content.sound = nil
        case "default":
            content.sound = .default
        default:
            // System sounds - find matching name and use .aiff extension
            let soundName = systemSounds.first { $0.lowercased() == sound } ?? sound.capitalized
            content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundName).aiff"))
        }

        // Set badge if enabled
        if badge {
            content.badge = 1
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error)")
            } else {
                print("Test notification sent successfully")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationsSettingsView()
        .frame(width: 600, height: 700)
        .background(Color.ds.bg0)
}
