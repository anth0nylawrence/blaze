//
//  SettingsCategory.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

/// Categories for organizing settings in the preferences window.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance
    case chat
    case models
    case security
    case engines
    case terminal
    case agents
    case files
    case notifications
    case cliPower
    case memory
    case git
    case hooks
    case shortcuts
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appearance: return "Appearance"
        case .chat: return "Chat & Input"
        case .models: return "Models"
        case .security: return "Security & Trust"
        case .engines: return "Engines"
        case .terminal: return "Terminal"
        case .agents: return "Agents"
        case .files: return "Files & Editor"
        case .notifications: return "Notifications"
        case .cliPower: return "CLI Power"
        case .memory: return "Memory & Context"
        case .git: return "Git"
        case .hooks: return "Hooks Builder"
        case .shortcuts: return "Shortcuts"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .chat: return "bubble.left.and.bubble.right"
        case .models: return "cpu"
        case .security: return "lock.shield"
        case .engines: return "gearshape.2"
        case .terminal: return "terminal"
        case .agents: return "person.3"
        case .files: return "doc.text"
        case .notifications: return "bell"
        case .cliPower: return "command"
        case .memory: return "brain"
        case .git: return "arrow.triangle.branch"
        case .hooks: return "link"
        case .shortcuts: return "keyboard"
        case .other: return "ellipsis.circle"
        }
    }
}
