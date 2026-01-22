//
//  SettingsSearchViewModel.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

@Observable
class SettingsSearchViewModel {
    var query: String = ""
    var filteredCategories: [SettingsCategory] = SettingsCategory.allCases
    var filteredSettings: [SettingsSearchResult] = []

    private var debounceTask: Task<Void, Never>?

    struct SettingsSearchResult: Identifiable {
        let id = UUID()
        let category: SettingsCategory
        let settingKey: String
        let displayName: String
        let matchRange: Range<String.Index>?
    }

    func updateSearch() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            filteredCategories = Array(SettingsCategory.allCases)
            filteredSettings = []
            return
        }

        let searchTerm = String(trimmed.prefix(100)).lowercased()

        // Filter categories by display name
        filteredCategories = SettingsCategory.allCases.filter {
            $0.displayName.lowercased().contains(searchTerm)
        }

        // Settings filtering would go here when settings are defined
        filteredSettings = []
    }
}
