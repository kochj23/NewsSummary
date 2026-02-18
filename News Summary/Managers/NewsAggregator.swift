//
//  NewsAggregator.swift
//  News Summary
//
//  Fetches news from multiple RSS sources in parallel with deduplication
//  Created by Jordan Koch on 2026-01-23
//

import Foundation

@MainActor
class NewsAggregator: ObservableObject {
    private var cache: [NewsCategory: [NewsArticle]] = [:]
    private var cacheTimestamp: [NewsCategory: Date] = [:]
    private let cacheExpiration: TimeInterval = 3600  // 1 hour

    /// Fetch articles for a specific category
    func fetchArticles(for category: NewsCategory, userLocation: (String, String)? = nil) async -> [NewsArticle] {
        print("📰 Fetching articles for \(category.rawValue)...")

        // Check cache first
        if let cached = cache[category],
           let timestamp = cacheTimestamp[category],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            print("✅ Using cached articles for \(category.rawValue) (\(cached.count) articles)")
            return cached
        }

        // Get sources for category
        var sources = NewsSourceDatabase.sources(for: category)

        // Add local news if category is local and location is set
        if category == .local, let location = userLocation {
            sources.append(NewsSourceDatabase.localNewsSource(city: location.0, state: location.1))
        }

        // Fetch from all sources in parallel
        // Each task gets its own RSSParser instance to avoid thread-safety issues
        // (RSSParser has mutable state used by XMLParserDelegate callbacks)
        let articles = await withTaskGroup(of: [NewsArticle].self) { group in
            for source in sources {
                group.addTask {
                    let parser = RSSParser()
                    return await parser.parseFeed(from: source.rssURL, source: source)
                }
            }

            var allArticles: [NewsArticle] = []
            for await sourceArticles in group {
                allArticles.append(contentsOf: sourceArticles)
            }
            return allArticles
        }

        // Deduplicate by title similarity
        let deduplicated = deduplicateArticles(articles)

        // Sort by date (newest first)
        let sorted = deduplicated.sorted { $0.publishedDate > $1.publishedDate }

        // Limit to top 100 per category
        let limited = Array(sorted.prefix(100))

        // Update cache
        cache[category] = limited
        cacheTimestamp[category] = Date()

        print("✅ Fetched \(limited.count) articles for \(category.rawValue) (from \(sources.count) sources)")
        return limited
    }

    /// Fetch articles for all categories
    func fetchAllCategories(userLocation: (String, String)? = nil) async -> [NewsCategory: [NewsArticle]] {
        var results: [NewsCategory: [NewsArticle]] = [:]

        for category in NewsCategory.allCases {
            let articles = await fetchArticles(for: category, userLocation: userLocation)
            results[category] = articles
        }

        return results
    }

    /// Invalidate cache for a category
    func invalidateCache(for category: NewsCategory) {
        cache.removeValue(forKey: category)
        cacheTimestamp.removeValue(forKey: category)
    }

    /// Invalidate all caches
    func invalidateAllCaches() {
        cache.removeAll()
        cacheTimestamp.removeAll()
        print("🗑️ Cleared all article caches")
    }

    // MARK: - Deduplication

    /// Remove duplicate articles based on title similarity
    private func deduplicateArticles(_ articles: [NewsArticle]) -> [NewsArticle] {
        var unique: [NewsArticle] = []
        var seenTitles: Set<String> = []

        for article in articles {
            let normalizedTitle = article.title.lowercased()
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)

            // Check if we've seen a very similar title
            let isDuplicate = seenTitles.contains { existingTitle in
                let similarity = stringSimilarity(normalizedTitle, existingTitle)
                return similarity > 0.85  // 85% similar = duplicate
            }

            if !isDuplicate {
                unique.append(article)
                seenTitles.insert(normalizedTitle)
            }
        }

        print("🔍 Deduplication: \(articles.count) → \(unique.count) unique articles")
        return unique
    }

    /// Calculate string similarity (Jaccard similarity)
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let words1 = Set(str1.components(separatedBy: .whitespaces))
        let words2 = Set(str2.components(separatedBy: .whitespaces))

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }

    // MARK: - Story Grouping

    /// Group articles that cover the same story
    func groupSimilarStories(_ articles: [NewsArticle]) -> [StoryGroup] {
        var groups: [StoryGroup] = []
        var ungrouped = articles

        while !ungrouped.isEmpty {
            let article = ungrouped.removeFirst()
            var group = [article]

            // Find similar articles within 4-hour window
            ungrouped.removeAll { other in
                let similarity = article.titleSimilarity(to: other)
                let timeDiff = abs(article.publishedDate.timeIntervalSince(other.publishedDate))

                if similarity > 0.70 && timeDiff < 14400 {  // 70% similar, <4 hours
                    group.append(other)
                    return true
                }
                return false
            }

            // Only create group if 2+ sources
            if group.count >= 2 {
                let biases = group.compactMap { $0.bias?.spectrum.value }
                let minBias = biases.min() ?? 0
                let maxBias = biases.max() ?? 0
                let avgBias = biases.isEmpty ? 0 : biases.reduce(0, +) / Double(biases.count)

                groups.append(StoryGroup(
                    representativeArticle: group.first!,
                    articles: group,
                    biasRange: (min: minBias, max: maxBias),
                    averageBias: avgBias
                ))
            }
        }

        return groups.sorted { $0.articles.count > $1.articles.count }
    }
}
