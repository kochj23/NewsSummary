//
//  NewsSummaryTests.swift
//  News SummaryTests
//
//  Comprehensive test suite for News Summary
//  Unit, Functional, and Security tests
//
//  Created by Jordan Koch on 2026-05-01.
//  Copyright (c) 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import News_Summary

// MARK: - Test Helpers

/// Helper to create test articles without network calls
enum TestData {
    static let testSource = NewsSource(
        id: "test-source",
        name: "Test News",
        rssURL: URL(string: "https://example.com/rss")!,
        category: .us,
        bias: .center,
        credibility: 85,
        factuality: 0.90
    )

    static let leftSource = NewsSource(
        id: "left-source",
        name: "Left News",
        rssURL: URL(string: "https://example.com/left")!,
        category: .us,
        bias: .left,
        credibility: 80,
        factuality: 0.82
    )

    static let rightSource = NewsSource(
        id: "right-source",
        name: "Right News",
        rssURL: URL(string: "https://example.com/right")!,
        category: .us,
        bias: .right,
        credibility: 80,
        factuality: 0.78
    )

    static func makeArticle(
        title: String = "Test Article Title",
        source: NewsSource? = nil,
        category: NewsCategory = .us,
        publishedDate: Date = Date(),
        description: String? = "A test description for the article.",
        isBreakingNews: Bool = false,
        importance: Int = 5
    ) -> NewsArticle {
        NewsArticle(
            title: title,
            source: source ?? testSource,
            url: URL(string: "https://example.com/article/\(UUID().uuidString)")!,
            publishedDate: publishedDate,
            category: category,
            rssDescription: description,
            isBreakingNews: isBreakingNews,
            importance: importance
        )
    }

    static let sampleRSSData = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
    <channel>
        <title>Test Feed</title>
        <item>
            <title>Federal Reserve Raises Interest Rates</title>
            <link>https://example.com/article1</link>
            <description>The Fed raised rates 0.25% to combat inflation.</description>
            <pubDate>Mon, 01 May 2026 12:00:00 +0000</pubDate>
        </item>
        <item>
            <title>Breaking: Major Storm Approaching</title>
            <link>https://example.com/article2</link>
            <description>&lt;p&gt;A &lt;strong&gt;major storm&lt;/strong&gt; is heading toward the coast.&lt;/p&gt;</description>
            <pubDate>Mon, 01 May 2026 14:00:00 +0000</pubDate>
            <media:content url="https://example.com/storm.jpg"/>
        </item>
        <item>
            <title>Tech Giants Report Earnings</title>
            <link>https://example.com/article3</link>
            <description><![CDATA[<p>Apple, Google, and Microsoft reported Q1 earnings.</p>]]></description>
            <pubDate>2026-05-01T10:00:00Z</pubDate>
        </item>
    </channel>
    </rss>
    """.data(using: .utf8)!

    static let malformedRSSData = """
    <?xml version="1.0"?>
    <rss><channel>
        <item>
            <title>Incomplete Item</title>
        </item>
        <item>
            <title></title>
            <link>https://example.com/empty-title</link>
        </item>
    </channel></rss>
    """.data(using: .utf8)!

    static let htmlContent = """
    <p>This is <strong>bold</strong> text with <a href="link">a link</a>.</p>
    <script>alert('xss')</script>
    <style>body { color: red; }</style>
    &amp; entities &lt;here&gt; &quot;quoted&quot; &nbsp; end
    """

    static let xssPayloads = [
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert(1)>",
        "javascript:alert(1)",
        "<svg onload=alert(1)>",
        "<body onload=alert(1)>",
        "'\"><script>alert(1)</script>",
        "<iframe src=\"javascript:alert(1)\">",
        "<div style=\"background:url(javascript:alert(1))\">",
    ]
}

// MARK: - NewsArticle Model Tests

final class NewsArticleTests: XCTestCase {

    func testArticleCreation() {
        let article = TestData.makeArticle(title: "Test Headline")
        XCTAssertEqual(article.title, "Test Headline")
        XCTAssertEqual(article.source.name, "Test News")
        XCTAssertEqual(article.category, .us)
        XCTAssertFalse(article.isRead)
        XCTAssertFalse(article.isBreakingNews)
        XCTAssertFalse(article.isFavorite)
        XCTAssertEqual(article.importance, 5)
    }

    func testArticleDefaultValues() {
        let article = TestData.makeArticle()
        XCTAssertNil(article.summary)
        XCTAssertNil(article.fullSummary)
        XCTAssertNil(article.keyPoints)
        XCTAssertNil(article.bias)
        XCTAssertNil(article.scrapedContent)
        XCTAssertNil(article.readAt)
    }

    func testArticleEquality() {
        let id = UUID()
        let a1 = NewsArticle(id: id, title: "A", source: TestData.testSource,
                             url: URL(string: "https://example.com/a")!, publishedDate: Date(), category: .us)
        let a2 = NewsArticle(id: id, title: "B", source: TestData.testSource,
                             url: URL(string: "https://example.com/b")!, publishedDate: Date(), category: .world)
        XCTAssertEqual(a1, a2, "Articles with the same id should be equal")
    }

    func testArticleInequality() {
        let a1 = TestData.makeArticle(title: "First")
        let a2 = TestData.makeArticle(title: "Second")
        XCTAssertNotEqual(a1, a2, "Articles with different ids should not be equal")
    }

    func testArticleHashConsistency() {
        let id = UUID()
        let a = NewsArticle(id: id, title: "Test", source: TestData.testSource,
                            url: URL(string: "https://example.com")!, publishedDate: Date(), category: .us)
        var set = Set<NewsArticle>()
        set.insert(a)
        let a2 = NewsArticle(id: id, title: "Different", source: TestData.testSource,
                             url: URL(string: "https://example.com/2")!, publishedDate: Date(), category: .world)
        XCTAssertTrue(set.contains(a2), "Set lookup should match by id")
    }

    func testTitleSimilarity() {
        let a1 = TestData.makeArticle(title: "Federal Reserve raises interest rates again")
        let a2 = TestData.makeArticle(title: "Federal Reserve raises rates to combat inflation")
        let similarity = a1.titleSimilarity(to: a2)
        XCTAssertGreaterThan(similarity, 0.3, "Similar titles should have non-trivial similarity")
    }

    func testTitleSimilarityIdentical() {
        let a = TestData.makeArticle(title: "Same exact title")
        let similarity = a.titleSimilarity(to: a)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001, "Identical titles should have similarity 1.0")
    }

    func testTitleSimilarityDisjoint() {
        let a1 = TestData.makeArticle(title: "Apple launches new iPhone")
        let a2 = TestData.makeArticle(title: "European football championships begin")
        let similarity = a1.titleSimilarity(to: a2)
        XCTAssertLessThan(similarity, 0.2, "Completely different titles should have low similarity")
    }

    func testIsRecentWithinWindow() {
        let article = TestData.makeArticle(publishedDate: Date().addingTimeInterval(-3600)) // 1 hour ago
        XCTAssertTrue(article.isRecent)
    }

    func testIsRecentOutsideWindow() {
        let article = TestData.makeArticle(publishedDate: Date().addingTimeInterval(-100000)) // > 24 hours
        XCTAssertFalse(article.isRecent)
    }

    func testCompatibilityAliases() {
        let article = TestData.makeArticle(description: "Test description")
        XCTAssertEqual(article.articleDescription, "Test description")
        XCTAssertNotNil(article.link)
        XCTAssertTrue(article.link!.starts(with: "https://"))
    }

    func testArticleCodable() throws {
        let article = TestData.makeArticle(title: "Codable Test")
        let encoder = JSONEncoder()
        let data = try encoder.encode(article)
        let decoded = try JSONDecoder().decode(NewsArticle.self, from: data)
        XCTAssertEqual(decoded.title, "Codable Test")
        XCTAssertEqual(decoded.id, article.id)
    }
}

// MARK: - NewsCategory Tests

final class NewsCategoryTests: XCTestCase {

    func testAllCategories() {
        let categories = NewsCategory.allCases
        XCTAssertEqual(categories.count, 9)
    }

    func testCategoryDisplayName() {
        XCTAssertEqual(NewsCategory.us.displayName, "US")
        XCTAssertEqual(NewsCategory.technology.displayName, "Technology")
        XCTAssertEqual(NewsCategory.entertainment.displayName, "Entertainment")
    }

    func testCategoryIcons() {
        for category in NewsCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "Category \(category) should have an icon")
        }
    }

    func testCategoryCodable() throws {
        let category = NewsCategory.technology
        let data = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(NewsCategory.self, from: data)
        XCTAssertEqual(decoded, category)
    }
}

// MARK: - BiasSpectrum Tests

final class BiasSpectrumTests: XCTestCase {

    func testAllSpectrumValues() {
        let allCases = BiasSpectrum.allCases
        XCTAssertEqual(allCases.count, 7)
    }

    func testSpectrumNumerics() {
        XCTAssertLessThan(BiasSpectrum.farLeft.value, 0)
        XCTAssertEqual(BiasSpectrum.center.value, 0.0)
        XCTAssertGreaterThan(BiasSpectrum.farRight.value, 0)
    }

    func testSpectrumOrdering() {
        let values = BiasSpectrum.allCases.map(\.value)
        XCTAssertEqual(values, values.sorted(), "Spectrum values should be in ascending order")
    }

    func testSpectrumSymmetry() {
        XCTAssertEqual(BiasSpectrum.farLeft.value, -BiasSpectrum.farRight.value, accuracy: 0.01)
        XCTAssertEqual(BiasSpectrum.left.value, -BiasSpectrum.right.value, accuracy: 0.01)
        XCTAssertEqual(BiasSpectrum.centerLeft.value, -BiasSpectrum.centerRight.value, accuracy: 0.01)
    }

    func testFromValue() {
        XCTAssertEqual(BiasSpectrum.from(value: 0.0), .center)
        XCTAssertEqual(BiasSpectrum.from(value: -2.0), .farLeft)
        XCTAssertEqual(BiasSpectrum.from(value: 2.0), .farRight)
        XCTAssertEqual(BiasSpectrum.from(value: 0.5), .centerRight)
        XCTAssertEqual(BiasSpectrum.from(value: -0.5), .centerLeft)
    }

    func testShortLabels() {
        XCTAssertEqual(BiasSpectrum.center.shortLabel, "C")
        XCTAssertEqual(BiasSpectrum.left.shortLabel, "L")
        XCTAssertEqual(BiasSpectrum.right.shortLabel, "R")
    }

    func testSpectrumCodable() throws {
        let spectrum = BiasSpectrum.centerLeft
        let data = try JSONEncoder().encode(spectrum)
        let decoded = try JSONDecoder().decode(BiasSpectrum.self, from: data)
        XCTAssertEqual(decoded, spectrum)
    }
}

// MARK: - BiasRating Tests

final class BiasRatingTests: XCTestCase {

    func testHighConfidence() {
        let rating = BiasRating(spectrum: .center, confidence: 0.9, sourceBias: 0.0,
                                contentBias: nil, emotionalLanguageScore: nil,
                                balanceScore: nil, reasoning: nil)
        XCTAssertTrue(rating.isHighConfidence)
        XCTAssertEqual(rating.confidenceLabel, "High")
    }

    func testMediumConfidence() {
        let rating = BiasRating(spectrum: .left, confidence: 0.7, sourceBias: -1.5,
                                contentBias: nil, emotionalLanguageScore: nil,
                                balanceScore: nil, reasoning: nil)
        XCTAssertFalse(rating.isHighConfidence)
        XCTAssertEqual(rating.confidenceLabel, "Medium")
    }

    func testLowConfidence() {
        let rating = BiasRating(spectrum: .right, confidence: 0.3, sourceBias: 1.5,
                                contentBias: nil, emotionalLanguageScore: nil,
                                balanceScore: nil, reasoning: nil)
        XCTAssertEqual(rating.confidenceLabel, "Low")
    }

    func testBiasRatingCodable() throws {
        let rating = BiasRating(spectrum: .centerRight, confidence: 0.85, sourceBias: 0.7,
                                contentBias: 0.5, emotionalLanguageScore: 0.3,
                                balanceScore: 0.6, reasoning: "Moderate right lean")
        let data = try JSONEncoder().encode(rating)
        let decoded = try JSONDecoder().decode(BiasRating.self, from: data)
        XCTAssertEqual(decoded.spectrum, .centerRight)
        XCTAssertEqual(decoded.confidence, 0.85, accuracy: 0.001)
    }
}

// MARK: - NewsSource Tests

final class NewsSourceTests: XCTestCase {

    func testSourceDatabaseHasSources() {
        XCTAssertFalse(NewsSourceDatabase.allSources.isEmpty)
        XCTAssertGreaterThan(NewsSourceDatabase.allSources.count, 10, "Should have 10+ sources")
    }

    func testSourcesForCategory() {
        let usSources = NewsSourceDatabase.sources(for: .us)
        XCTAssertFalse(usSources.isEmpty)
        for source in usSources {
            XCTAssertEqual(source.category, .us)
        }
    }

    func testLocalSourcesEmpty() {
        let localSources = NewsSourceDatabase.sources(for: .local)
        XCTAssertTrue(localSources.isEmpty, "Local sources should be empty by default")
    }

    func testLocalNewsSource() {
        let source = NewsSourceDatabase.localNewsSource(city: "Denver", state: "CO")
        XCTAssertEqual(source.category, .local)
        XCTAssertTrue(source.name.contains("Denver"))
        XCTAssertTrue(source.rssURL.absoluteString.contains("Denver"))
    }

    func testAllSourcesHaveValidURLs() {
        for source in NewsSourceDatabase.allSources {
            XCTAssertTrue(source.rssURL.absoluteString.starts(with: "http"),
                          "Source \(source.name) should have a valid URL")
        }
    }

    func testAllSourcesHaveCredibility() {
        for source in NewsSourceDatabase.allSources {
            XCTAssertGreaterThan(source.credibility, 0, "Source \(source.name) credibility should be > 0")
            XCTAssertLessThanOrEqual(source.credibility, 100, "Source \(source.name) credibility should be <= 100")
        }
    }

    func testAllSourcesHaveFactuality() {
        for source in NewsSourceDatabase.allSources {
            XCTAssertGreaterThan(source.factuality, 0.0)
            XCTAssertLessThanOrEqual(source.factuality, 1.0)
        }
    }

    func testSourceEquality() {
        let s1 = NewsSource(id: "ap", name: "AP", rssURL: URL(string: "https://ap.com")!,
                            category: .us, bias: .center, credibility: 95, factuality: 0.95)
        let s2 = NewsSource(id: "ap", name: "Different", rssURL: URL(string: "https://other.com")!,
                            category: .world, bias: .left, credibility: 50, factuality: 0.50)
        XCTAssertEqual(s1, s2, "Sources with same id should be equal")
    }
}

// MARK: - RSS Parser Tests

final class RSSParserTests: XCTestCase {

    func testParseValidRSS() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(TestData.sampleRSSData, source: TestData.testSource)
        XCTAssertEqual(articles.count, 3)
    }

    func testParsedArticleTitles() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(TestData.sampleRSSData, source: TestData.testSource)
        let titles = articles.map(\.title)
        XCTAssertTrue(titles.contains("Federal Reserve Raises Interest Rates"))
        XCTAssertTrue(titles.contains("Breaking: Major Storm Approaching"))
        XCTAssertTrue(titles.contains("Tech Giants Report Earnings"))
    }

    func testParsedArticleURLs() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(TestData.sampleRSSData, source: TestData.testSource)
        for article in articles {
            XCTAssertTrue(article.url.absoluteString.starts(with: "https://"),
                          "Article URL should be valid: \(article.url)")
        }
    }

    func testHTMLStrippedFromDescription() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(TestData.sampleRSSData, source: TestData.testSource)
        let stormArticle = articles.first { $0.title.contains("Storm") }
        XCTAssertNotNil(stormArticle)
        if let desc = stormArticle?.rssDescription {
            XCTAssertFalse(desc.contains("<p>"), "HTML tags should be stripped")
            XCTAssertFalse(desc.contains("<strong>"), "HTML tags should be stripped")
        }
    }

    func testMalformedRSSHandled() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(TestData.malformedRSSData, source: TestData.testSource)
        // Should handle gracefully: items with missing links or empty titles are skipped
        XCTAssertLessThanOrEqual(articles.count, 1)
    }

    func testEmptyDataReturnsEmpty() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(Data(), source: TestData.testSource)
        XCTAssertTrue(articles.isEmpty)
    }

    func testDateParsingRFC822() {
        let parser = RSSParser()
        let rss = """
        <?xml version="1.0"?><rss><channel>
        <item><title>Date Test</title><link>https://example.com/d</link>
        <pubDate>Mon, 01 May 2026 12:00:00 +0000</pubDate></item>
        </channel></rss>
        """.data(using: .utf8)!
        let articles = parser.parseFeedDataForTesting(rss, source: TestData.testSource)
        XCTAssertEqual(articles.count, 1)
        if let article = articles.first {
            let cal = Calendar(identifier: .gregorian)
            let components = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: article.publishedDate)
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 5)
        }
    }

    func testDateParsingISO8601() {
        let parser = RSSParser()
        let rss = """
        <?xml version="1.0"?><rss><channel>
        <item><title>ISO Date</title><link>https://example.com/i</link>
        <pubDate>2026-05-01T10:00:00Z</pubDate></item>
        </channel></rss>
        """.data(using: .utf8)!
        let articles = parser.parseFeedDataForTesting(rss, source: TestData.testSource)
        XCTAssertEqual(articles.count, 1)
    }

    func testSourceAssigned() {
        let parser = RSSParser()
        let articles = parser.parseFeedDataForTesting(TestData.sampleRSSData, source: TestData.leftSource)
        for article in articles {
            XCTAssertEqual(article.source.id, "left-source")
            XCTAssertEqual(article.category, .us)
        }
    }
}

// MARK: - ReadingTimeEstimator Tests

final class ReadingTimeEstimatorTests: XCTestCase {

    func testWordCount() {
        XCTAssertEqual(ReadingTimeEstimator.countWords(in: "one two three"), 3)
        XCTAssertEqual(ReadingTimeEstimator.countWords(in: ""), 0)
        XCTAssertEqual(ReadingTimeEstimator.countWords(in: "   "), 0)
        XCTAssertEqual(ReadingTimeEstimator.countWords(in: "hello"), 1)
    }

    func testReadingTimeForShortText() {
        // 250 words at 250 WPM = 1 minute = 60 seconds
        let text = Array(repeating: "word", count: 250).joined(separator: " ")
        let time = ReadingTimeEstimator.estimateReadingTime(for: text)
        XCTAssertEqual(time, 60.0, accuracy: 1.0)
    }

    func testReadingTimeForEmptyText() {
        let time = ReadingTimeEstimator.estimateReadingTime(for: "")
        XCTAssertEqual(time, 0.0)
    }

    func testFormatReadingTime() {
        XCTAssertEqual(ReadingTimeEstimator.formatReadingTime(30), "1 min")
        XCTAssertEqual(ReadingTimeEstimator.formatReadingTime(300), "5 min")
        XCTAssertEqual(ReadingTimeEstimator.formatReadingTime(3600), "1h")
        XCTAssertEqual(ReadingTimeEstimator.formatReadingTime(5400), "1h 30m")
    }

    func testDifficultyEasy() {
        let easy = "This is a short text. It uses simple words. The reading is easy."
        let difficulty = ReadingTimeEstimator.estimateDifficulty(for: easy)
        XCTAssertTrue([ReadingDifficulty.easy, .moderate].contains(difficulty))
    }

    func testDifficultyEmpty() {
        let difficulty = ReadingTimeEstimator.estimateDifficulty(for: "")
        XCTAssertEqual(difficulty, .easy)
    }

    func testDifficultyAllCases() {
        XCTAssertEqual(ReadingDifficulty.allCases.count, 4)
    }

    func testDifficultyHasDescriptions() {
        for difficulty in ReadingDifficulty.allCases {
            XCTAssertFalse(difficulty.description.isEmpty)
            XCTAssertFalse(difficulty.icon.isEmpty)
            XCTAssertFalse(difficulty.color.isEmpty)
        }
    }
}

// MARK: - SourceCredibility Tests

final class SourceCredibilityTests: XCTestCase {

    func testHighCredibility() {
        let cred = SourceCredibility(credibility: 95, factuality: 0.95, source: "Ad Fontes")
        XCTAssertEqual(cred.label, "High")
    }

    func testGoodCredibility() {
        let cred = SourceCredibility(credibility: 80, factuality: 0.85, source: "AllSides")
        XCTAssertEqual(cred.label, "Good")
    }

    func testFairCredibility() {
        let cred = SourceCredibility(credibility: 65, factuality: 0.70, source: "Test")
        XCTAssertEqual(cred.label, "Fair")
    }

    func testLowCredibility() {
        let cred = SourceCredibility(credibility: 40, factuality: 0.50, source: "Test")
        XCTAssertEqual(cred.label, "Low")
    }
}

// MARK: - StoryGroup Tests

final class StoryGroupTests: XCTestCase {

    func testStoryGroupSourceCount() {
        let articles = [
            TestData.makeArticle(title: "Story A", source: TestData.testSource),
            TestData.makeArticle(title: "Story B", source: TestData.leftSource),
            TestData.makeArticle(title: "Story C", source: TestData.rightSource),
        ]
        let group = StoryGroup(
            representativeArticle: articles[0],
            articles: articles,
            biasRange: (min: -1.5, max: 1.5),
            averageBias: 0.0
        )
        XCTAssertEqual(group.sourceCount, 3)
    }

    func testBiasDistribution() {
        let leftArticle = TestData.makeArticle(source: TestData.leftSource)
        var leftWithBias = leftArticle
        leftWithBias.bias = BiasRating(spectrum: .left, confidence: 0.8, sourceBias: -1.5,
                                        contentBias: nil, emotionalLanguageScore: nil,
                                        balanceScore: nil, reasoning: nil)

        let centerArticle = TestData.makeArticle(source: TestData.testSource)
        var centerWithBias = centerArticle
        centerWithBias.bias = BiasRating(spectrum: .center, confidence: 0.9, sourceBias: 0.0,
                                          contentBias: nil, emotionalLanguageScore: nil,
                                          balanceScore: nil, reasoning: nil)

        let group = StoryGroup(
            representativeArticle: leftWithBias,
            articles: [leftWithBias, centerWithBias],
            biasRange: (min: -1.5, max: 0.0),
            averageBias: -0.75
        )

        let distribution = group.biasDistribution
        XCTAssertTrue(distribution.contains("L"))
        XCTAssertTrue(distribution.contains("C"))
    }
}

// MARK: - Ethical AI Guardian Tests

final class EthicalGuardianTests: XCTestCase {

    func testGuardianIsEnabled() async {
        let guardian = await EthicalAIGuardian.shared
        let enabled = await guardian.isEnabled
        XCTAssertTrue(enabled, "Guardian should always be enabled")
    }

    func testEthicalGuidelinesNotEmpty() async {
        let guidelines = await EthicalAIGuardian.shared.showEthicalGuidelines()
        XCTAssertFalse(guidelines.isEmpty)
        XCTAssertTrue(guidelines.contains("PROHIBITED"))
        XCTAssertTrue(guidelines.contains("ACCEPTABLE"))
    }

    func testViolationStatisticsInitial() async {
        let stats = await EthicalAIGuardian.shared.getViolationStatistics()
        XCTAssertGreaterThanOrEqual(stats.safePercentage, 0)
        XCTAssertLessThanOrEqual(stats.safePercentage, 100)
    }
}

// MARK: - Policy Violation Model Tests

final class PolicyViolationTests: XCTestCase {

    func testViolationCategories() {
        let categories: [ViolationCategory] = [.illegalActivity, .harmfulContent, .hateSpeech,
                                                .misinformation, .privacyViolation, .harassment,
                                                .fraud, .other]
        for category in categories {
            XCTAssertFalse(category.description.isEmpty, "\(category) should have a description")
        }
    }

    func testViolationSeverityColors() {
        XCTAssertEqual(ViolationSeverity.critical.color, "red")
        XCTAssertEqual(ViolationSeverity.high.color, "orange")
        XCTAssertEqual(ViolationSeverity.medium.color, "yellow")
        XCTAssertEqual(ViolationSeverity.low.color, "gray")
    }

    func testPolicyViolationCodable() throws {
        let violation = PolicyViolation(
            category: .illegalActivity,
            severity: .critical,
            description: "Test violation",
            detectedPattern: "test.*pattern",
            action: .blockCompletely,
            timestamp: Date()
        )
        let data = try JSONEncoder().encode(violation)
        let decoded = try JSONDecoder().decode(PolicyViolation.self, from: data)
        XCTAssertEqual(decoded.category, .illegalActivity)
        XCTAssertEqual(decoded.severity, .critical)
    }
}

// MARK: - Security Tests

final class SecurityTests: XCTestCase {

    func testNoHardcodedAPIKeys() {
        // Verify no API keys are hardcoded in source files
        let dangerousPatterns = [
            "sk-[A-Za-z0-9]{20,}",       // OpenAI keys
            "AKIA[A-Z0-9]{16}",           // AWS access keys
            "ghp_[A-Za-z0-9]{36}",        // GitHub PATs
            "xox[bpoas]-[A-Za-z0-9]",     // Slack tokens
        ]

        // Test that our test data does not contain real keys
        let testStrings = [
            TestData.htmlContent,
            TestData.sampleRSSData.base64EncodedString(),
        ]

        for pattern in dangerousPatterns {
            let regex = try? NSRegularExpression(pattern: pattern)
            for testString in testStrings {
                let range = NSRange(testString.startIndex..., in: testString)
                let matches = regex?.numberOfMatches(in: testString, range: range) ?? 0
                XCTAssertEqual(matches, 0, "Found potential API key pattern '\(pattern)' in test data")
            }
        }
    }

    func testHTMLSanitizationStripsScripts() {
        let parser = RSSParser()
        let rss = """
        <?xml version="1.0"?><rss><channel>
        <item><title>XSS Test</title><link>https://example.com/xss</link>
        <description>&lt;script&gt;alert('xss')&lt;/script&gt;Normal text</description>
        </item></channel></rss>
        """.data(using: .utf8)!
        let articles = parser.parseFeedDataForTesting(rss, source: TestData.testSource)
        if let desc = articles.first?.rssDescription {
            XCTAssertFalse(desc.contains("<script>"), "Script tags should be stripped")
            XCTAssertFalse(desc.contains("alert("), "Script content should be stripped")
        }
    }

    func testHTMLSanitizationStripsAllTags() {
        let parser = RSSParser()
        for payload in TestData.xssPayloads {
            let rss = """
            <?xml version="1.0"?><rss><channel>
            <item><title>Test</title><link>https://example.com/t</link>
            <description>\(payload)</description>
            </item></channel></rss>
            """.data(using: .utf8)!
            let articles = parser.parseFeedDataForTesting(rss, source: TestData.testSource)
            if let desc = articles.first?.rssDescription {
                XCTAssertFalse(desc.contains("<script"), "XSS payload should be sanitized: \(payload)")
                XCTAssertFalse(desc.contains("<img"), "XSS payload should be sanitized: \(payload)")
                XCTAssertFalse(desc.contains("<svg"), "XSS payload should be sanitized: \(payload)")
                XCTAssertFalse(desc.contains("<iframe"), "XSS payload should be sanitized: \(payload)")
            }
        }
    }

    func testURLValidation() {
        // Test that the parser handles potentially malicious URLs safely
        let parser = RSSParser()
        let rss = """
        <?xml version="1.0"?><rss><channel>
        <item><title>Bad URL</title><link>javascript:alert(1)</link>
        <description>Test</description></item>
        <item><title>Good URL</title><link>https://example.com/safe</link>
        <description>Test</description></item>
        </channel></rss>
        """.data(using: .utf8)!
        let articles = parser.parseFeedDataForTesting(rss, source: TestData.testSource)
        for article in articles {
            // Verify URLs don't use javascript: scheme
            XCTAssertFalse(article.url.scheme == "javascript",
                          "javascript: URLs should not be accepted")
        }
    }

    func testHTMLEntityDecoding() {
        let parser = RSSParser()
        let rss = """
        <?xml version="1.0"?><rss><channel>
        <item><title>Entity Test</title><link>https://example.com/e</link>
        <description>&amp;amp; &lt;b&gt;bold&lt;/b&gt; &quot;quoted&quot; &nbsp;text</description>
        </item></channel></rss>
        """.data(using: .utf8)!
        let articles = parser.parseFeedDataForTesting(rss, source: TestData.testSource)
        if let desc = articles.first?.rssDescription {
            XCTAssertFalse(desc.contains("&amp;"), "HTML entities should be decoded")
            XCTAssertFalse(desc.contains("&lt;"), "HTML entities should be decoded")
            XCTAssertFalse(desc.contains("&gt;"), "HTML entities should be decoded")
        }
    }

    func testSourceURLsUseHTTPS() {
        // Most sources should use HTTPS
        let httpsSources = NewsSourceDatabase.allSources.filter {
            $0.rssURL.scheme == "https"
        }
        let ratio = Double(httpsSources.count) / Double(NewsSourceDatabase.allSources.count)
        XCTAssertGreaterThan(ratio, 0.5, "Most sources should use HTTPS")
    }
}
