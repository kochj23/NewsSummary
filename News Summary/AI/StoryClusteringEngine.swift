import Foundation

//
//  StoryClusteringEngine.swift
//  News Summary
//
//  Automatically cluster related articles and track story evolution
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class StoryClusteringEngine: ObservableObject {

    static let shared = StoryClusteringEngine()

    @Published var isProcessing = false
    @Published var clusters: [StoryCluster] = []

    private init() {}

    // MARK: - Cluster Articles

    func clusterArticles(_ articles: [NewsArticle]) async throws -> [StoryCluster] {

        isProcessing = true
        defer { isProcessing = false }

        // Use AI to identify unique stories
        let storyIdentification = try await identifyUniqueStories(articles)

        var clusters: [StoryCluster] = []

        for storyId in storyIdentification.keys {
            let storyArticles = storyIdentification[storyId] ?? []

            guard !storyArticles.isEmpty else { continue }

            // Generate story summary
            let mainEvent = try await generateStoryTitle(articles: storyArticles)

            // Build timeline
            let timeline = try await buildTimeline(articles: storyArticles)

            // Extract entities
            let keyPlayers = try await EntityTrackingEngine.shared.extractEntities(from: storyArticles.first!)

            // Extract locations
            let locations = keyPlayers.filter { $0.type == .location }

            let cluster = StoryCluster(
                id: UUID(),
                mainEvent: mainEvent,
                articles: storyArticles,
                timeline: timeline,
                keyPlayers: keyPlayers,
                locations: locations.map { Location(name: $0.name, country: "") },
                impact: ImpactAnalysis(
                    affectedGroups: [],
                    economicImpact: nil,
                    politicalImpact: nil,
                    timeframe: .days(7)
                ),
                predictions: [],
                createdAt: Date()
            )

            clusters.append(cluster)
        }

        self.clusters = clusters
        return clusters
    }

    // MARK: - Story Identification

    private func identifyUniqueStories(_ articles: [NewsArticle]) async throws -> [String: [NewsArticle]] {

        let titles = articles.compactMap { $0.title }.joined(separator: "\n")

        let prompt = """
        Group these article headlines by story topic.
        Assign each article a story ID (Story_1, Story_2, etc.).
        Articles about the same event get the same ID.

        Headlines:
        \(titles)

        Format response as:
        Story_1: [Headline 1], [Headline 2]
        Story_2: [Headline 3]
        ...
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Group news articles by story topic. Be conservative - only group truly related articles.",
            temperature: 0.2,
            maxTokens: 1000
        )

        // Parse response and match back to articles
        var clusters: [String: [NewsArticle]] = [:]

        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            if let colonIndex = line.firstIndex(of: ":") {
                let storyId = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let headlinesText = String(line[line.index(after: colonIndex)...])

                for article in articles {
                    if let title = article.title, headlinesText.contains(title.prefix(20)) {
                        if clusters[storyId] == nil {
                            clusters[storyId] = []
                        }
                        clusters[storyId]?.append(article)
                    }
                }
            }
        }

        return clusters
    }

    private func generateStoryTitle(articles: [NewsArticle]) async throws -> String {

        let titles = articles.compactMap { $0.title }.joined(separator: "\n")

        let prompt = """
        Create a single neutral headline that summarizes this story based on these headlines:

        \(titles)

        Return only the headline (10-15 words):
        """

        return try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Create neutral, informative headlines.",
            temperature: 0.3,
            maxTokens: 50
        )
    }

    // MARK: - Timeline Construction

    func buildTimeline(articles: [NewsArticle]) async throws -> [TimelineEvent] {

        let sortedArticles = articles.sorted { ($0.publishedDate ?? Date.distantPast) < ($1.publishedDate ?? Date.distantPast) }

        var events: [TimelineEvent] = []

        for article in sortedArticles {
            guard let published = article.publishedDate else { continue }

            let description = article.aiSummary ?? article.title ?? "Update"
            let significance = determineSignificance(article: article, position: events.count, total: sortedArticles.count)

            events.append(TimelineEvent(
                id: UUID(),
                timestamp: published,
                description: description,
                source: article.source!,
                significance: significance,
                article: article
            ))
        }

        return events
    }

    private func determineSignificance(article: NewsArticle, position: Int, total: Int) -> SignificanceLevel {
        // First and last articles are typically most significant
        if position == 0 {
            return .major // Story breaks
        } else if position == total - 1 {
            return .major // Latest development
        } else {
            return .update // Mid-story update
        }
    }

    // MARK: - Predictions

    func predictNextDevelopments(cluster: StoryCluster) async throws -> [String] {

        let recentArticles = cluster.articles
            .sorted { ($0.publishedDate ?? Date.distantPast) > ($1.publishedDate ?? Date.distantPast) }
            .prefix(5)

        let summaries = recentArticles.compactMap { $0.aiSummary ?? $0.articleDescription }.joined(separator: "\n\n")

        let prompt = """
        Based on these recent developments in this story, predict what might happen next.
        Provide 3-5 likely developments with reasoning.

        Story: \(cluster.mainEvent)

        Recent Developments:
        \(summaries)

        Predictions (bullet format with brief reasoning):
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Predict likely news developments based on current trends. Be realistic and data-driven.",
            temperature: 0.4,
            maxTokens: 600
        )

        return response
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).starts(with: "•") || $0.trimmingCharacters(in: .whitespaces).starts(with: "-") }
            .map { $0.trimmingCharacters(in: .whitespaces).dropFirst().trimmingCharacters(in: .whitespaces) }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Models

struct StoryCluster: Identifiable, Codable {
    let id: UUID
    let mainEvent: String
    let articles: [NewsArticle]
    let timeline: [TimelineEvent]
    let keyPlayers: [Entity]
    let locations: [Location]
    let impact: ImpactAnalysis
    let predictions: [String]
    let createdAt: Date

    var articleCount: Int { articles.count }
    var latestUpdate: Date? { articles.compactMap { $0.publishedDate }.max() }
}

struct TimelineEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let description: String
    let source: NewsSource
    let significance: SignificanceLevel
    let article: NewsArticle
}

enum SignificanceLevel: String, Codable {
    case major = "Major"
    case update = "Update"
    case minor = "Minor"

    var icon: String {
        switch self {
        case .major: return "exclamationmark.circle.fill"
        case .update: return "arrow.up.circle"
        case .minor: return "circle"
        }
    }

    var color: String {
        switch self {
        case .major: return "red"
        case .update: return "orange"
        case .minor: return "gray"
        }
    }
}

struct Location: Codable {
    let name: String
    let country: String
}

struct ImpactAnalysis: Codable {
    let affectedGroups: [String]
    let economicImpact: String?
    let politicalImpact: String?
    let timeframe: ImpactTimeframe
}

enum ImpactTimeframe: Codable {
    case hours(Int)
    case days(Int)
    case weeks(Int)
    case months(Int)

    var description: String {
        switch self {
        case .hours(let h): return "\(h) hours"
        case .days(let d): return "\(d) days"
        case .weeks(let w): return "\(w) weeks"
        case .months(let m): return "\(m) months"
        }
    }
}
