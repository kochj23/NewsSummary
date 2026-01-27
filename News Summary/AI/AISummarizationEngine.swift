import Foundation

//
//  AISummarizationEngine.swift
//  News Summary
//
//  Multi-level AI summarization system
//  Generates summaries at different detail levels
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class AISummarizationEngine: ObservableObject {

    static let shared = AISummarizationEngine()

    @Published var isProcessing = false
    @Published var cachedSummaries: [String: [SummaryLevel: String]] = [:]

    private init() {}

    // MARK: - Generate Summaries

    func generateSummary(
        for article: NewsArticle,
        level: SummaryLevel,
        useCache: Bool = true
    ) async throws -> String {

        // Check cache first
        if useCache, let cached = cachedSummaries[article.id.uuidString]?[level] {
            return cached
        }

        isProcessing = true
        defer { isProcessing = false }

        let fullText = extractFullText(from: article)
        let prompt = buildPrompt(text: fullText, level: level)

        let summary = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are a professional news summarizer. Be accurate, concise, and objective.",
            temperature: 0.3, // Low temperature for factual accuracy
            maxTokens: level.maxTokens
        )

        // Cache the result
        if cachedSummaries[article.id.uuidString] == nil {
            cachedSummaries[article.id.uuidString] = [:]
        }
        cachedSummaries[article.id.uuidString]?[level] = summary

        return summary
    }

    func generateKeyTakeaways(for article: NewsArticle, count: Int = 5) async throws -> [String] {
        let fullText = extractFullText(from: article)

        let prompt = """
        Extract the \(count) most important takeaways from this news article.
        Return ONLY a numbered list, one point per line.

        Article:
        \(fullText)

        Format:
        1. First takeaway
        2. Second takeaway
        ...
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You extract key points from news articles. Be concise and factual.",
            temperature: 0.2,
            maxTokens: 300
        )

        // Parse numbered list
        let lines = response.components(separatedBy: .newlines)
        let takeaways = lines
            .filter { $0.matches(#"^\d+\."#) }
            .map { $0.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression) }

        return Array(takeaways.prefix(count))
    }

    // MARK: - Batch Processing

    func generateBatchSummaries(
        for articles: [NewsArticle],
        level: SummaryLevel
    ) async throws -> [String: String] {

        var results: [String: String] = [:]

        for article in articles {
            do {
                let summary = try await generateSummary(for: article, level: level)
                results[article.id.uuidString] = summary
            } catch {
                print("⚠️ Failed to summarize article: \(article.title ?? "unknown") - \(error)")
                continue
            }
        }

        return results
    }

    // MARK: - Helpers

    private func extractFullText(from article: NewsArticle) -> String {
        var text = ""

        if let title = article.title {
            text += title + "\n\n"
        }

        if let content = article.content {
            text += content
        } else if let description = article.articleDescription {
            text += description
        }

        return text
    }

    private func buildPrompt(text: String, level: SummaryLevel) -> String {
        switch level {
        case .headline:
            return """
            Create a single headline (10-15 words) that captures the essence of this article.
            Make it clear and informative.

            Article:
            \(text)

            Headline:
            """

        case .brief:
            return """
            Summarize this article in 2-3 sentences.
            Cover the most important points only.

            Article:
            \(text)

            Summary:
            """

        case .standard:
            return """
            Summarize this article in one paragraph (4-6 sentences).
            Include the main points and key context.

            Article:
            \(text)

            Summary:
            """

        case .detailed:
            return """
            Provide a detailed summary of this article (3-5 paragraphs).
            Include main points, context, implications, and important details.

            Article:
            \(text)

            Summary:
            """

        case .eli5:
            return """
            Explain this article as if I'm 5 years old.
            Use simple language, analogies, and avoid jargon.
            Make it fun and easy to understand.

            Article:
            \(text)

            Explanation:
            """

        case .technical:
            return """
            Provide a technical/expert summary of this article.
            Include domain-specific details, implications, and expert-level analysis.
            Assume the reader has background knowledge.

            Article:
            \(text)

            Technical Summary:
            """
        }
    }
}

// MARK: - Summary Level

enum SummaryLevel: String, CaseIterable, Codable {
    case headline = "Headline"
    case brief = "Brief"
    case standard = "Standard"
    case detailed = "Detailed"
    case eli5 = "ELI5"
    case technical = "Technical"

    var icon: String {
        switch self {
        case .headline: return "text.badge.star"
        case .brief: return "text.quote"
        case .standard: return "text.alignleft"
        case .detailed: return "doc.text"
        case .eli5: return "graduationcap"
        case .technical: return "function"
        }
    }

    var description: String {
        switch self {
        case .headline:
            return "10-15 words - Twitter-length"
        case .brief:
            return "2-3 sentences - Quick scan"
        case .standard:
            return "1 paragraph - Main points"
        case .detailed:
            return "3-5 paragraphs - Full context"
        case .eli5:
            return "Simple language - Anyone can understand"
        case .technical:
            return "Expert-level - Domain knowledge assumed"
        }
    }

    var maxTokens: Int {
        switch self {
        case .headline: return 50
        case .brief: return 150
        case .standard: return 300
        case .detailed: return 800
        case .eli5: return 400
        case .technical: return 600
        }
    }
}

// MARK: - String Extension for Regex

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
