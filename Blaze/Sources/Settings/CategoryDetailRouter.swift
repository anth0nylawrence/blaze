//
//  CategoryDetailRouter.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

struct CategoryDetailRouter {
    @ViewBuilder
    static func view(for category: SettingsCategory) -> some View {
        switch category {
        case .appearance:
            AppearanceSettingsView()
        case .chat:
            ChatSettingsView()
        case .models:
            ModelsSettingsView()
        case .security:
            SecuritySettingsView()
        case .engines:
            EnginesSettingsView()
        case .terminal:
            TerminalSettingsView()
        case .agents:
            AgentsSettingsView()
        case .files:
            FilesSettingsView()
        case .notifications:
            NotificationsSettingsView()
        case .cliPower:
            CLIPowerSettingsView()
        case .memory:
            MemorySettingsView()
        case .git:
            GitSettingsView()
        case .hooks:
            HooksBuilderView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .other:
            OtherSettingsView()
        }
    }
}
