//
//  NewsFocusFilter.swift
//  News Summary
//
//  Focus Filter support for iOS Focus modes
//  Customize news behavior during Focus (Work, Sleep, Personal)
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import AppIntents
import SwiftUI

// MARK: - News Focus Filter

struct NewsFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set News Focus"
    static var description: IntentDescription? = IntentDescription(
        "Configure how News Summary behaves during this Focus mode"
    )

    // Parameters for the focus filter
    @Parameter(title: "Enable Notifications", default: true)
    var enableNotifications: Bool

    @Parameter(title: "Breaking News Only", default: false)
    var breakingNewsOnly: Bool

    @Parameter(title: "Categories to Show")
    var allowedCategories: [NewsCategoryFocusEntity]?

    @Parameter(title: "Mute During Focus", default: false)
    var muteNotifications: Bool

    @Parameter(title: "Disable Background Refresh", default: false)
    var disableBackgroundRefresh: Bool

    static var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "News Settings",
            subtitle: "Customize news during this Focus",
            image: .init(systemName: "newspaper.fill")
        )
    }

    func perform() async throws -> some IntentResult {
        // Save focus filter settings
        let categoryIds = allowedCategories?.map { $0.id } ?? []

        let settings = NewsFocusSettings(
            enableNotifications: enableNotifications,
            breakingNewsOnly: breakingNewsOnly,
            allowedCategories: categoryIds,
            muteNotifications: muteNotifications,
            disableBackgroundRefresh: disableBackgroundRefresh
        )

        await NewsFocusManager.shared.applySettings(settings)

        return .result()
    }
}

// MARK: - News Category Focus Entity

struct NewsCategoryFocusEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Category")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: iconForCategory(name))
        )
    }

    static var defaultQuery = NewsCategoryFocusEntityQuery()

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "technology": return "cpu"
        case "business": return "chart.line.uptrend.xyaxis"
        case "world": return "globe"
        case "politics": return "building.columns"
        case "science": return "atom"
        case "health": return "heart.fill"
        case "entertainment": return "film"
        case "sports": return "sportscourt"
        default: return "newspaper"
        }
    }
}

struct NewsCategoryFocusEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [NewsCategoryFocusEntity] {
        let categories = await NewsFocusManager.shared.getAllCategories()
        return categories.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [NewsCategoryFocusEntity] {
        await NewsFocusManager.shared.getAllCategories()
    }
}

// MARK: - Focus Settings

struct NewsFocusSettings: Codable {
    let enableNotifications: Bool
    let breakingNewsOnly: Bool
    let allowedCategories: [String]
    let muteNotifications: Bool
    let disableBackgroundRefresh: Bool

    static let `default` = NewsFocusSettings(
        enableNotifications: true,
        breakingNewsOnly: false,
        allowedCategories: [],
        muteNotifications: false,
        disableBackgroundRefresh: false
    )

    // Helper to check if a category is allowed
    func isCategoryAllowed(_ category: String) -> Bool {
        if allowedCategories.isEmpty { return true }
        return allowedCategories.contains(category.lowercased())
    }
}

// MARK: - Focus Manager

@MainActor
class NewsFocusManager: ObservableObject {
    static let shared = NewsFocusManager()

    @Published private(set) var currentSettings: NewsFocusSettings = .default
    @Published private(set) var isFocusActive: Bool = false

    private let settingsKey = "newsFocusSettings"

    private init() {
        loadSettings()
    }

    // Apply new focus filter settings
    func applySettings(_ settings: NewsFocusSettings) {
        currentSettings = settings
        isFocusActive = true
        saveSettings()

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .newsFocusSettingsChanged,
            object: nil,
            userInfo: ["settings": settings]
        )

        // Disable background refresh if requested
        if settings.disableBackgroundRefresh {
            NotificationCenter.default.post(
                name: .disableBackgroundRefresh,
                object: nil
            )
        }
    }

    // Reset to default settings
    func resetSettings() {
        currentSettings = .default
        isFocusActive = false
        saveSettings()

        NotificationCenter.default.post(
            name: .newsFocusSettingsChanged,
            object: nil,
            userInfo: ["settings": NewsFocusSettings.default]
        )
    }

    // Get all categories
    func getAllCategories() -> [NewsCategoryFocusEntity] {
        return [
            NewsCategoryFocusEntity(id: "technology", name: "Technology"),
            NewsCategoryFocusEntity(id: "business", name: "Business"),
            NewsCategoryFocusEntity(id: "world", name: "World"),
            NewsCategoryFocusEntity(id: "politics", name: "Politics"),
            NewsCategoryFocusEntity(id: "science", name: "Science"),
            NewsCategoryFocusEntity(id: "health", name: "Health"),
            NewsCategoryFocusEntity(id: "entertainment", name: "Entertainment"),
            NewsCategoryFocusEntity(id: "sports", name: "Sports")
        ]
    }

    // Filter articles based on current focus settings
    func shouldShowArticle(category: String, isBreaking: Bool) -> Bool {
        // If focus not active, show everything
        guard isFocusActive else { return true }

        // If breaking news only mode, only show breaking
        if currentSettings.breakingNewsOnly && !isBreaking {
            return false
        }

        // Check category filter
        return currentSettings.isCategoryAllowed(category)
    }

    // Check if notifications should be shown
    func shouldShowNotification(isBreaking: Bool) -> Bool {
        guard isFocusActive else { return true }

        if currentSettings.muteNotifications {
            return false
        }

        if !currentSettings.enableNotifications {
            return false
        }

        if currentSettings.breakingNewsOnly {
            return isBreaking
        }

        return true
    }

    // Private helpers
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(currentSettings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(NewsFocusSettings.self, from: data) {
            currentSettings = settings
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newsFocusSettingsChanged = Notification.Name("newsFocusSettingsChanged")
    static let disableBackgroundRefresh = Notification.Name("disableBackgroundRefresh")
}

// MARK: - View Modifier

struct NewsFocusFilterModifier: ViewModifier {
    @ObservedObject var focusManager = NewsFocusManager.shared
    let category: String
    let isBreaking: Bool

    func body(content: Content) -> some View {
        if focusManager.shouldShowArticle(category: category, isBreaking: isBreaking) {
            content
        }
    }
}

extension View {
    func newsFocusFiltered(category: String, isBreaking: Bool = false) -> some View {
        modifier(NewsFocusFilterModifier(category: category, isBreaking: isBreaking))
    }
}
