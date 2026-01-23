//
//  NewsSource.swift
//  News Summary
//
//  RSS source definitions with bias ratings
//  Based on Ad Fontes Media and AllSides research
//  Created by Jordan Koch on 2026-01-23
//

import Foundation

/// News source with RSS feed URL and bias rating
struct NewsSource: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let rssURL: URL
    let category: NewsCategory
    let bias: BiasSpectrum
    let credibility: Int              // 0-100
    let factuality: Double            // 0.0-1.0

    /// Create a simple hash for deduplication
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NewsSource, rhs: NewsSource) -> Bool {
        lhs.id == rhs.id
    }
}

/// Pre-configured news sources by category
struct NewsSourceDatabase {

    // MARK: - US News Sources

    static let usSources: [NewsSource] = [
        NewsSource(
            id: "google-news-us",
            name: "Google News US",
            rssURL: URL(string: "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en")!,
            category: .us,
            bias: .center,
            credibility: 85,
            factuality: 0.85
        ),
        NewsSource(
            id: "ap-news",
            name: "Associated Press",
            rssURL: URL(string: "https://rsshub.app/apnews/topics/apf-topnews")!,
            category: .us,
            bias: .center,
            credibility: 95,
            factuality: 0.95
        ),
        NewsSource(
            id: "reuters-us",
            name: "Reuters US",
            rssURL: URL(string: "https://www.reutersagency.com/feed/?taxonomy=best-topics&post_type=best")!,
            category: .us,
            bias: .center,
            credibility: 95,
            factuality: 0.94
        ),
        NewsSource(
            id: "npr-news",
            name: "NPR News",
            rssURL: URL(string: "https://feeds.npr.org/1001/rss.xml")!,
            category: .us,
            bias: .centerLeft,
            credibility: 87,
            factuality: 0.90
        ),
        NewsSource(
            id: "cnn",
            name: "CNN",
            rssURL: URL(string: "http://rss.cnn.com/rss/cnn_topstories.rss")!,
            category: .us,
            bias: .left,
            credibility: 85,
            factuality: 0.82
        ),
        NewsSource(
            id: "fox-news",
            name: "Fox News",
            rssURL: URL(string: "https://moxie.foxnews.com/google-publisher/latest.xml")!,
            category: .us,
            bias: .right,
            credibility: 80,
            factuality: 0.75
        )
    ]

    // MARK: - World News Sources

    static let worldSources: [NewsSource] = [
        NewsSource(
            id: "google-news-world",
            name: "Google News World",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/WORLD")!,
            category: .world,
            bias: .center,
            credibility: 85,
            factuality: 0.85
        ),
        NewsSource(
            id: "bbc-world",
            name: "BBC World",
            rssURL: URL(string: "http://feeds.bbci.co.uk/news/world/rss.xml")!,
            category: .world,
            bias: .centerLeft,
            credibility: 90,
            factuality: 0.92
        ),
        NewsSource(
            id: "al-jazeera",
            name: "Al Jazeera",
            rssURL: URL(string: "https://www.aljazeera.com/xml/rss/all.xml")!,
            category: .world,
            bias: .centerLeft,
            credibility: 75,
            factuality: 0.80
        ),
        NewsSource(
            id: "reuters-world",
            name: "Reuters World",
            rssURL: URL(string: "https://www.reutersagency.com/feed/?best-topics=international-news")!,
            category: .world,
            bias: .center,
            credibility: 95,
            factuality: 0.94
        )
    ]

    // MARK: - Business Sources

    static let businessSources: [NewsSource] = [
        NewsSource(
            id: "google-news-business",
            name: "Google News Business",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/BUSINESS")!,
            category: .business,
            bias: .center,
            credibility: 85,
            factuality: 0.85
        ),
        NewsSource(
            id: "wsj",
            name: "Wall Street Journal",
            rssURL: URL(string: "https://feeds.a.dj.com/rss/RSSMarketsMain.xml")!,
            category: .business,
            bias: .centerRight,
            credibility: 92,
            factuality: 0.91
        ),
        NewsSource(
            id: "cnbc",
            name: "CNBC",
            rssURL: URL(string: "https://www.cnbc.com/id/100003114/device/rss/rss.html")!,
            category: .business,
            bias: .center,
            credibility: 82,
            factuality: 0.85
        )
    ]

    // MARK: - Technology Sources

    static let technologySources: [NewsSource] = [
        NewsSource(
            id: "google-news-tech",
            name: "Google News Tech",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/TECHNOLOGY")!,
            category: .technology,
            bias: .center,
            credibility: 85,
            factuality: 0.85
        ),
        NewsSource(
            id: "techcrunch",
            name: "TechCrunch",
            rssURL: URL(string: "https://techcrunch.com/feed/")!,
            category: .technology,
            bias: .centerLeft,
            credibility: 80,
            factuality: 0.83
        ),
        NewsSource(
            id: "the-verge",
            name: "The Verge",
            rssURL: URL(string: "https://www.theverge.com/rss/index.xml")!,
            category: .technology,
            bias: .centerLeft,
            credibility: 78,
            factuality: 0.80
        ),
        NewsSource(
            id: "ars-technica",
            name: "Ars Technica",
            rssURL: URL(string: "https://feeds.arstechnica.com/arstechnica/index")!,
            category: .technology,
            bias: .centerLeft,
            credibility: 85,
            factuality: 0.88
        )
    ]

    // MARK: - Entertainment, Sports, Science, Health

    static let entertainmentSources: [NewsSource] = [
        NewsSource(
            id: "google-news-entertainment",
            name: "Google News Entertainment",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/ENTERTAINMENT")!,
            category: .entertainment,
            bias: .center,
            credibility: 80,
            factuality: 0.80
        )
    ]

    static let sportsSources: [NewsSource] = [
        NewsSource(
            id: "google-news-sports",
            name: "Google News Sports",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/SPORTS")!,
            category: .sports,
            bias: .center,
            credibility: 80,
            factuality: 0.80
        )
    ]

    static let scienceSources: [NewsSource] = [
        NewsSource(
            id: "google-news-science",
            name: "Google News Science",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/SCIENCE")!,
            category: .science,
            bias: .center,
            credibility: 85,
            factuality: 0.88
        )
    ]

    static let healthSources: [NewsSource] = [
        NewsSource(
            id: "google-news-health",
            name: "Google News Health",
            rssURL: URL(string: "https://news.google.com/rss/headlines/section/topic/HEALTH")!,
            category: .health,
            bias: .center,
            credibility: 85,
            factuality: 0.87
        )
    ]

    // MARK: - All Sources

    static var allSources: [NewsSource] {
        return usSources + worldSources + businessSources + technologySources +
               entertainmentSources + sportsSources + scienceSources + healthSources
    }

    static func sources(for category: NewsCategory) -> [NewsSource] {
        switch category {
        case .us: return usSources
        case .world: return worldSources
        case .local: return []  // Will be populated based on user location
        case .business: return businessSources
        case .technology: return technologySources
        case .entertainment: return entertainmentSources
        case .sports: return sportsSources
        case .science: return scienceSources
        case .health: return healthSources
        }
    }

    /// Build local news URL based on user location
    static func localNewsSource(city: String, state: String) -> NewsSource {
        let query = "\(city)+\(state)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://news.google.com/rss/search?q=when:24h+allinurl:\(query)"

        return NewsSource(
            id: "local-\(city)",
            name: "Local News - \(city), \(state)",
            rssURL: URL(string: urlString)!,
            category: .local,
            bias: .center,
            credibility: 80,
            factuality: 0.82
        )
    }
}
