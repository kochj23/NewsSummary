import Foundation
import SwiftUI
import Observation

//
//  FavoritesManager.swift
//  News Summary
//
//  Manage favorite articles with persistence
//  Author: Jordan Koch
//  Date: 2026-01-26
//  Updated: 2026-01-31 - Migrated to @Observable (Swift 5.9+)
//

/// Favorites manager using the modern @Observable macro
///
/// **Migration from ObservableObject:**
/// - Replaced `ObservableObject` protocol with `@Observable` macro
/// - Removed `@Published` property wrappers (automatic observation)
/// - Views should use direct reference instead of `@ObservedObject`
///
/// **Requirements:** macOS 14+, iOS 17+, tvOS 17+
@Observable
@MainActor
final class FavoritesManager {

    static let shared = FavoritesManager()

    var favorites: [NewsArticle] = []
    var favoriteIDs: Set<UUID> = []

    private let fileURL: URL

    // MARK: - Initialization

    private init() {
        // Get Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDirectory = appSupport.appendingPathComponent("NewsSummary", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.fileURL = appDirectory.appendingPathComponent("favorites.json")

        loadFavorites()
    }

    // MARK: - Add/Remove

    func addFavorite(_ article: NewsArticle) {
        guard !isFavorite(article) else { return }

        var updatedArticle = article
        updatedArticle.isFavorite = true

        favorites.append(updatedArticle)
        favoriteIDs.insert(article.id)

        saveFavorites()

        // Send notification
        NotificationCenter.default.post(name: .articleFavorited, object: article)
    }

    func removeFavorite(_ article: NewsArticle) {
        favorites.removeAll { $0.id == article.id }
        favoriteIDs.remove(article.id)

        saveFavorites()

        // Send notification
        NotificationCenter.default.post(name: .articleUnfavorited, object: article)
    }

    func toggleFavorite(_ article: NewsArticle) {
        if isFavorite(article) {
            removeFavorite(article)
        } else {
            addFavorite(article)
        }
    }

    func isFavorite(_ article: NewsArticle) -> Bool {
        return favoriteIDs.contains(article.id)
    }

    // MARK: - Query

    func getFavorites(category: NewsCategory? = nil) -> [NewsArticle] {
        if let category = category {
            return favorites.filter { $0.category == category }
        }
        return favorites
    }

    func getFavorites(source: NewsSource) -> [NewsArticle] {
        return favorites.filter { $0.source.id == source.id }
    }

    func getFavorites(bias: BiasRating) -> [NewsArticle] {
        return favorites.filter { $0.source.bias == bias }
    }

    func searchFavorites(query: String) -> [NewsArticle] {
        let lowercaseQuery = query.lowercased()

        return favorites.filter { article in
            let title = article.title.lowercased()
            let description = article.articleDescription?.lowercased() ?? ""
            let source = article.source.name.lowercased()

            return title.contains(lowercaseQuery) ||
                   description.contains(lowercaseQuery) ||
                   source.contains(lowercaseQuery)
        }
    }

    // MARK: - Statistics

    func getFavoritesStatistics() -> FavoritesStatistics {
        var categoryCounts: [NewsCategory: Int] = [:]
        var sourceCounts: [String: Int] = [:]
        var biasCounts: [BiasRating: Int] = [:]

        for article in favorites {
            categoryCounts[article.category, default: 0] += 1
            sourceCounts[article.source.name, default: 0] += 1
            biasCounts[article.source.bias, default: 0] += 1
        }

        let topCategories = categoryCounts.sorted { $0.value > $1.value }.prefix(5)
        let topSources = sourceCounts.sorted { $0.value > $1.value }.prefix(5)

        return FavoritesStatistics(
            totalFavorites: favorites.count,
            categoryCounts: categoryCounts,
            topCategories: Array(topCategories),
            topSources: Array(topSources),
            biasCounts: biasCounts,
            oldestFavorite: favorites.min { $0.publishedDate < $1.publishedDate },
            newestFavorite: favorites.max { $0.publishedDate < $1.publishedDate }
        )
    }

    // MARK: - Bulk Operations

    func addMultipleFavorites(_ articles: [NewsArticle]) {
        for article in articles {
            addFavorite(article)
        }
    }

    func clearAllFavorites() {
        favorites.removeAll()
        favoriteIDs.removeAll()
        saveFavorites()
    }

    func exportFavorites() -> String {
        return ExportManager.shared.exportCollectionToMarkdown(
            articles: favorites,
            collectionName: "Favorite Articles"
        )
    }

    // MARK: - Persistence

    private func loadFavorites() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([NewsArticle].self, from: data)
            favorites = decoded
            favoriteIDs = Set(decoded.map { $0.id })
        } catch {
            print("❌ Failed to load favorites: \(error)")
        }
    }

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save favorites: \(error)")
        }
    }
}

// MARK: - Models

struct FavoritesStatistics {
    let totalFavorites: Int
    let categoryCounts: [NewsCategory: Int]
    let topCategories: [(key: NewsCategory, value: Int)]
    let topSources: [(key: String, value: Int)]
    let biasCounts: [BiasRating: Int]
    let oldestFavorite: NewsArticle?
    let newestFavorite: NewsArticle?

    var favoriteCategory: NewsCategory? {
        topCategories.first?.key
    }

    var favoriteSource: String? {
        topSources.first?.key
    }

    var biasDistribution: String {
        let left = biasCounts[.left] ?? 0
        let center = biasCounts[.center] ?? 0
        let right = biasCounts[.right] ?? 0
        return "\(left)L / \(center)C / \(right)R"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let articleFavorited = Notification.Name("articleFavorited")
    static let articleUnfavorited = Notification.Name("articleUnfavorited")
}
