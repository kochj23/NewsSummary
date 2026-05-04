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
    private let maxCacheArticlesPerCategory = 500

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

        // Get sources for category (built-in + user custom sources)
        var sources = NewsSourceDatabase.sources(for: category)
        sources.append(contentsOf: CustomSourceManager.shared.sources(for: category))

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

        // Update cache with size enforcement
        cache[category] = limited
        cacheTimestamp[category] = Date()
        enforceCacheLimit()

        print("Fetched \(limited.count) articles for \(category.rawValue) (from \(sources.count) sources)")
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

    /// Enforce maximum cache size per category. When exceeded, evict oldest articles first.
    private func enforceCacheLimit() {
        for category in cache.keys {
            guard var articles = cache[category],
                  articles.count > maxCacheArticlesPerCategory else { continue }

            // Sort by publishedDate ascending (oldest first), keep newest
            articles.sort { $0.publishedDate < $1.publishedDate }
            let excess = articles.count - maxCacheArticlesPerCategory
            articles.removeFirst(excess)
            // Re-sort newest first for display
            cache[category] = articles.sorted { $0.publishedDate > $1.publishedDate }
        }
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

    /// Remove duplicate articles using normalized title hashing — O(n) instead of O(n^2).
    /// Normalizes titles (lowercase, strip punctuation, sort words) and hashes them.
    /// Articles with identical normalized hashes are considered duplicates.
    private func deduplicateArticles(_ articles: [NewsArticle]) -> [NewsArticle] {
        var unique: [NewsArticle] = []
        var seenHashes: Set<String> = []

        for article in articles {
            let hash = normalizedTitleHash(article.title)

            if !seenHashes.contains(hash) {
                unique.append(article)
                seenHashes.insert(hash)
            }
        }

        print("Deduplication: \(articles.count) -> \(unique.count) unique articles")
        return unique
    }

    /// Produce a canonical hash string from a title:
    /// lowercase, strip all non-alphanumeric/space chars, split into words,
    /// remove common stop words, sort alphabetically, and join.
    /// This catches reordered or slightly rephrased duplicate headlines.
    private func normalizedTitleHash(_ title: String) -> String {
        let stopWords: Set<String> = ["the", "a", "an", "is", "are", "was", "were", "in", "on",
                                       "at", "to", "for", "of", "with", "by", "from", "and", "or",
                                       "but", "not", "this", "that", "it", "its", "as"]

        let lowered = title.lowercased()
        let stripped = lowered.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespaces.contains($0)
        }
        let words = String(stripped)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
            .sorted()

        return words.joined(separator: " ")
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
