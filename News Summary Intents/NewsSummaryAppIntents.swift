//
//  NewsSummaryAppIntents.swift
//  News Summary
//
//  App Intents for Siri Shortcuts integration
//  "Hey Siri, read me the headlines" / "Hey Siri, any breaking news?"
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import AppIntents
import SwiftUI

// MARK: - Get Headlines Intent

struct GetHeadlinesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get News Headlines"
    static var description = IntentDescription("Get the latest news headlines")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Category", default: nil)
    var category: NewsCategoryEntity?

    @Parameter(title: "Number of Headlines", default: 5)
    var count: Int

    static var parameterSummary: some ParameterSummary {
        When(\.$category, .hasAnyValue) {
            Summary("Get \(\.$count) \(\.$category) headlines")
        } otherwise: {
            Summary("Get \(\.$count) top headlines")
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let headlines = await NewsIntentHandler.shared.getHeadlines(
            category: category?.name,
            count: count
        )

        if headlines.isEmpty {
            return .result(dialog: "No headlines available right now.")
        }

        // Format headlines for speech
        let headlineText = headlines.enumerated().map { index, headline in
            "\(index + 1). \(headline.title) from \(headline.source)"
        }.joined(separator: ". ")

        return .result(dialog: "Here are the top \(headlines.count) headlines: \(headlineText)")
    }
}

// MARK: - Get Breaking News Intent

struct GetBreakingNewsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Breaking News"
    static var description = IntentDescription("Check for breaking news stories")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let breakingNews = await NewsIntentHandler.shared.getBreakingNews()

        if breakingNews.isEmpty {
            return .result(dialog: "No breaking news at this time.")
        }

        if breakingNews.count == 1 {
            return .result(dialog: "Breaking news: \(breakingNews[0].title) from \(breakingNews[0].source)")
        }

        let headlines = breakingNews.prefix(3).map { $0.title }.joined(separator: ". ")
        return .result(dialog: "There are \(breakingNews.count) breaking news stories. \(headlines)")
    }
}

// MARK: - Search News Intent

struct SearchNewsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search News"
    static var description = IntentDescription("Search for news about a specific topic")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search Query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search news for \(\.$query)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to open search in app
        NotificationCenter.default.post(
            name: .searchNewsFromIntent,
            object: nil,
            userInfo: ["query": query]
        )
        return .result(dialog: "Searching for news about \(query)")
    }
}

// MARK: - Get News Summary Intent

struct GetNewsSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get News Summary"
    static var description = IntentDescription("Get a summary of today's news")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await NewsIntentHandler.shared.getNewsSummary()

        return .result(dialog: """
            Today's news summary: \
            \(summary.totalArticles) articles across \(summary.categoryCount) categories. \
            \(summary.breakingCount) breaking stories. \
            Top category: \(summary.topCategory) with \(summary.topCategoryCount) articles.
            """)
    }
}

// MARK: - Refresh News Intent

struct RefreshNewsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh News"
    static var description = IntentDescription("Refresh all news feeds")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let success = await NewsIntentHandler.shared.refreshNews()

        if success {
            return .result(dialog: "News feeds refreshed successfully.")
        } else {
            throw NewsIntentError.refreshFailed
        }
    }
}

// MARK: - News Category Entity

struct NewsCategoryEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Category")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: iconForCategory(name)))
    }

    static var defaultQuery = NewsCategoryEntityQuery()

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

struct NewsCategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [NewsCategoryEntity] {
        let allCategories = await NewsIntentHandler.shared.getAllCategories()
        return allCategories.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [NewsCategoryEntity] {
        await NewsIntentHandler.shared.getAllCategories()
    }
}

// MARK: - Headline Entity

struct HeadlineEntity: AppEntity {
    var id: String
    var title: String
    var source: String
    var category: String
    var isBreaking: Bool

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Headline")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(source)",
            image: .init(systemName: isBreaking ? "exclamationmark.triangle.fill" : "newspaper")
        )
    }

    static var defaultQuery = HeadlineEntityQuery()
}

struct HeadlineEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HeadlineEntity] {
        let allHeadlines = await NewsIntentHandler.shared.getAllHeadlines()
        return allHeadlines.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HeadlineEntity] {
        await NewsIntentHandler.shared.getTopHeadlines()
    }
}

// MARK: - Intent Handler

@MainActor
class NewsIntentHandler {
    static let shared = NewsIntentHandler()

    private init() {}

    struct IntentHeadline {
        let id: String
        let title: String
        let source: String
        let category: String
        let isBreaking: Bool
    }

    struct NewsSummaryData {
        let totalArticles: Int
        let breakingCount: Int
        let categoryCount: Int
        let topCategory: String
        let topCategoryCount: Int
    }

    // Get headlines with optional category filter
    func getHeadlines(category: String?, count: Int) async -> [IntentHeadline] {
        let data = loadSharedData()
        var headlines = data.headlines

        if let category = category {
            headlines = headlines.filter { $0.category.lowercased() == category.lowercased() }
        }

        return Array(headlines.prefix(count))
    }

    // Get breaking news only
    func getBreakingNews() async -> [IntentHeadline] {
        let data = loadSharedData()
        return data.headlines.filter { $0.isBreaking }
    }

    // Get all headlines
    func getAllHeadlines() async -> [HeadlineEntity] {
        let data = loadSharedData()
        return data.headlines.map {
            HeadlineEntity(id: $0.id, title: $0.title, source: $0.source, category: $0.category, isBreaking: $0.isBreaking)
        }
    }

    // Get top headlines for suggestions
    func getTopHeadlines() async -> [HeadlineEntity] {
        let data = loadSharedData()
        return data.headlines.prefix(10).map {
            HeadlineEntity(id: $0.id, title: $0.title, source: $0.source, category: $0.category, isBreaking: $0.isBreaking)
        }
    }

    // Get news summary
    func getNewsSummary() async -> NewsSummaryData {
        let data = loadSharedData()

        let categoryCounts = Dictionary(grouping: data.headlines, by: { $0.category })
            .mapValues { $0.count }
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })

        return NewsSummaryData(
            totalArticles: data.headlines.count,
            breakingCount: data.headlines.filter { $0.isBreaking }.count,
            categoryCount: categoryCounts.count,
            topCategory: topCategory?.key ?? "None",
            topCategoryCount: topCategory?.value ?? 0
        )
    }

    // Get all categories
    func getAllCategories() async -> [NewsCategoryEntity] {
        let categories = ["Technology", "Business", "World", "Politics", "Science", "Health", "Entertainment", "Sports"]
        return categories.map { NewsCategoryEntity(id: $0.lowercased(), name: $0) }
    }

    // Refresh news feeds
    func refreshNews() async -> Bool {
        NotificationCenter.default.post(
            name: .refreshNewsFromIntent,
            object: nil
        )
        return true
    }

    // MARK: - Shared Data Loading

    private struct SharedData {
        let headlines: [IntentHeadline]
    }

    private func loadSharedData() -> SharedData {
        guard let userDefaults = UserDefaults(suiteName: "group.com.jordankoch.NewsSummary"),
              let data = userDefaults.data(forKey: "intentData"),
              let decoded = try? JSONDecoder().decode(IntentSharedData.self, from: data) else {
            return SharedData(headlines: [])
        }

        return SharedData(
            headlines: decoded.headlines.map {
                IntentHeadline(id: $0.id, title: $0.title, source: $0.source, category: $0.category, isBreaking: $0.isBreaking)
            }
        )
    }
}

// MARK: - Codable Data for Sharing

struct IntentSharedData: Codable {
    let headlines: [IntentHeadlineData]
}

struct IntentHeadlineData: Codable {
    let id: String
    let title: String
    let source: String
    let category: String
    let isBreaking: Bool
}

// MARK: - Errors

enum NewsIntentError: Error, CustomLocalizedStringResourceConvertible {
    case refreshFailed
    case noHeadlinesAvailable
    case categoryNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .refreshFailed:
            return "Failed to refresh news feeds"
        case .noHeadlinesAvailable:
            return "No headlines available"
        case .categoryNotFound:
            return "Category not found"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let refreshNewsFromIntent = Notification.Name("refreshNewsFromIntent")
    static let searchNewsFromIntent = Notification.Name("searchNewsFromIntent")
}

// MARK: - App Shortcuts Provider

struct NewsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetHeadlinesIntent(),
            phrases: [
                "Read me the headlines in \(.applicationName)",
                "What's the news in \(.applicationName)",
                "Get news headlines",
                "Read the news"
            ],
            shortTitle: "Get Headlines",
            systemImageName: "newspaper"
        )

        AppShortcut(
            intent: GetBreakingNewsIntent(),
            phrases: [
                "Any breaking news in \(.applicationName)",
                "What's breaking in \(.applicationName)",
                "Breaking news",
                "Is there any breaking news"
            ],
            shortTitle: "Breaking News",
            systemImageName: "exclamationmark.triangle"
        )

        AppShortcut(
            intent: GetNewsSummaryIntent(),
            phrases: [
                "Give me a news summary in \(.applicationName)",
                "News summary",
                "Summarize the news"
            ],
            shortTitle: "News Summary",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: RefreshNewsIntent(),
            phrases: [
                "Refresh the news in \(.applicationName)",
                "Update news feeds",
                "Get latest news"
            ],
            shortTitle: "Refresh News",
            systemImageName: "arrow.clockwise"
        )
    }
}
