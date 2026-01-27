//
//  NewsArticle.swift
//  News Summary
//
//  Core news article data model
//  Created by Jordan Koch on 2026-01-23
//

import Foundation

struct NewsArticle: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let source: NewsSource
    let url: URL
    let publishedDate: Date
    let category: NewsCategory
    let rssDescription: String?       // Original RSS description
    let imageURL: URL?
    var summary: String?              // AI-generated one-liner
    var fullSummary: String?          // AI-generated detailed summary
    var keyPoints: [String]?          // AI-extracted bullet points
    var bias: BiasRating?             // AI-detected bias
    var scrapedContent: String?       // Full article text (on-demand)
    var isRead: Bool
    var readAt: Date?
    var isBreakingNews: Bool
    var importance: Int               // 1-10 scale
    var isFavorite: Bool

    // Compatibility aliases for new AI services
    var link: String? { url.absoluteString }
    var articleDescription: String? { rssDescription }
    var content: String? { scrapedContent }
    var aiSummary: String? { summary }

    init(
        id: UUID = UUID(),
        title: String,
        source: NewsSource,
        url: URL,
        publishedDate: Date,
        category: NewsCategory,
        rssDescription: String? = nil,
        imageURL: URL? = nil,
        summary: String? = nil,
        fullSummary: String? = nil,
        keyPoints: [String]? = nil,
        bias: BiasRating? = nil,
        scrapedContent: String? = nil,
        isRead: Bool = false,
        readAt: Date? = nil,
        isBreakingNews: Bool = false,
        importance: Int = 5,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.url = url
        self.publishedDate = publishedDate
        self.category = category
        self.rssDescription = rssDescription
        self.imageURL = imageURL
        self.summary = summary
        self.fullSummary = fullSummary
        self.keyPoints = keyPoints
        self.bias = bias
        self.scrapedContent = scrapedContent
        self.isRead = isRead
        self.readAt = readAt
        self.isBreakingNews = isBreakingNews
        self.importance = importance
        self.isFavorite = isFavorite
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NewsArticle, rhs: NewsArticle) -> Bool {
        lhs.id == rhs.id
    }

    /// Calculate title similarity for story grouping
    func titleSimilarity(to other: NewsArticle) -> Double {
        let words1 = Set(title.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(other.title.lowercased().components(separatedBy: .whitespacesAndNewlines))

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }

    /// Time since publication
    var timeSincePublication: TimeInterval {
        Date().timeIntervalSince(publishedDate)
    }

    /// Is this article recent (< 24 hours old)?
    var isRecent: Bool {
        timeSincePublication < 86400  // 24 hours
    }

    /// Formatted time ago string
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedDate, relativeTo: Date())
    }
}

/// Grouped story with multiple source coverage
struct StoryGroup: Identifiable {
    let id: UUID = UUID()
    let representativeArticle: NewsArticle  // Main article to show
    let articles: [NewsArticle]             // All articles covering this story
    let biasRange: (min: Double, max: Double)
    let averageBias: Double

    var sourceCount: Int {
        articles.count
    }

    var biasDistribution: String {
        let left = articles.filter { ($0.bias?.spectrum.value ?? 0) < -0.3 }.count
        let center = articles.filter { abs($0.bias?.spectrum.value ?? 0) <= 0.3 }.count
        let right = articles.filter { ($0.bias?.spectrum.value ?? 0) > 0.3 }.count

        return "\(left)L / \(center)C / \(right)R"
    }
}
