import Foundation

//
//  MultiPerspectiveAnalyzer.swift
//  News Summary
//
//  THE KILLER FEATURE: Multi-perspective news analysis
//  Shows how Left/Center/Right sources cover the same story
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class MultiPerspectiveAnalyzer: ObservableObject {

    static let shared = MultiPerspectiveAnalyzer()

    @Published var isAnalyzing = false
    @Published var cachedAnalyses: [String: PerspectiveAnalysis] = [:]

    private init() {}

    // MARK: - Main Analysis

    func analyzeStory(articles: [NewsArticle]) async throws -> PerspectiveAnalysis {

        guard !articles.isEmpty else {
            throw AnalysisError.noArticles
        }

        // Check cache
        let cacheKey = articles.map { $0.id.uuidString }.sorted().joined()
        if let cached = cachedAnalyses[cacheKey] {
            return cached
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Separate articles by bias
        let leftArticles = articles.filter { $0.source?.bias == .left }
        let centerArticles = articles.filter { $0.source?.bias == .center }
        let rightArticles = articles.filter { $0.source?.bias == .right }

        // Generate perspectives
        async let leftPerspective = generatePerspective(articles: leftArticles, bias: .left)
        async let centerPerspective = generatePerspective(articles: centerArticles, bias: .center)
        async let rightPerspective = generatePerspective(articles: rightArticles, bias: .right)

        let perspectives = try await (leftPerspective, centerPerspective, rightPerspective)

        // Extract shared facts and contentions
        let allTexts = articles.compactMap { $0.content ?? $0.articleDescription }
        let sharedFacts = try await extractSharedFacts(texts: allTexts)
        let contentions = try await extractContentions(perspectives: perspectives)
        let keyDifferences = try await identifyKeyDifferences(perspectives: perspectives)

        let analysis = PerspectiveAnalysis(
            leftPerspective: perspectives.0,
            centerPerspective: perspectives.1,
            rightPerspective: perspectives.2,
            sharedFacts: sharedFacts,
            contentions: contentions,
            keyDifferences: keyDifferences,
            analyzedAt: Date()
        )

        // Cache result
        cachedAnalyses[cacheKey] = analysis

        return analysis
    }

    // MARK: - Generate Perspective

    private func generatePerspective(articles: [NewsArticle], bias: BiasRating) async throws -> String {

        guard !articles.isEmpty else {
            return "No \(bias.rawValue) sources available for this story."
        }

        let texts = articles.compactMap { ($0.title ?? "") + " " + ($0.content ?? $0.articleDescription ?? "") }
        let combinedText = texts.joined(separator: "\n\n---\n\n")

        let prompt = """
        Analyze how \(bias.rawValue)-leaning sources are covering this story.

        Articles from \(bias.rawValue) sources:
        \(combinedText)

        Provide a summary that captures:
        1. Main narrative/framing
        2. Key points emphasized
        3. Tone and language used
        4. What they focus on
        5. What they downplay or omit

        Be objective in your analysis. Explain HOW they're covering it, not whether they're right or wrong.

        \(bias.rawValue.capitalized) Perspective:
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are a media analyst. Analyze news coverage objectively without taking sides.",
            temperature: 0.4,
            maxTokens: 600
        )

        return response
    }

    // MARK: - Extract Shared Facts

    private func extractSharedFacts(texts: [String]) async throws -> [String] {

        let combinedText = texts.prefix(5).joined(separator: "\n\n===\n\n")

        let prompt = """
        Identify facts that ALL sources agree on (shared across articles).
        Only include statements that are factual, verifiable, and uncontested.

        Articles:
        \(combinedText)

        List shared facts (one per line, bullet format):
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Extract only facts that all sources agree on. Be strict about what qualifies as 'shared'.",
            temperature: 0.2,
            maxTokens: 400
        )

        return response
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).starts(with: "•") || $0.trimmingCharacters(in: .whitespaces).starts(with: "-") }
            .map { $0.trimmingCharacters(in: .whitespaces).dropFirst(1).trimmingCharacters(in: .whitespaces) }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Extract Contentions

    private func extractContentions(perspectives: (String, String, String)) async throws -> [Contention] {

        let prompt = """
        Compare these three perspectives and identify the main points of disagreement or different emphasis.

        Left Perspective:
        \(perspectives.0)

        Center Perspective:
        \(perspectives.1)

        Right Perspective:
        \(perspectives.2)

        List contentions in this format (one per paragraph):
        POINT: [The contention]
        LEFT: [Left view]
        CENTER: [Center view]
        RIGHT: [Right view]
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Identify areas where different political perspectives disagree or emphasize different aspects.",
            temperature: 0.3,
            maxTokens: 800
        )

        // Parse contentions
        let paragraphs = response.components(separatedBy: "\n\n")
        var contentions: [Contention] = []

        for paragraph in paragraphs {
            let lines = paragraph.components(separatedBy: "\n")
            var point = ""
            var leftView = ""
            var centerView = ""
            var rightView = ""

            for line in lines {
                if line.starts(with: "POINT:") {
                    point = line.replacingOccurrences(of: "POINT:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.starts(with: "LEFT:") {
                    leftView = line.replacingOccurrences(of: "LEFT:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.starts(with: "CENTER:") {
                    centerView = line.replacingOccurrences(of: "CENTER:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.starts(with: "RIGHT:") {
                    rightView = line.replacingOccurrences(of: "RIGHT:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }

            if !point.isEmpty {
                contentions.append(Contention(
                    point: point,
                    leftView: leftView,
                    centerView: centerView,
                    rightView: rightView
                ))
            }
        }

        return contentions
    }

    // MARK: - Identify Key Differences

    private func identifyKeyDifferences(perspectives: (String, String, String)) async throws -> [String] {

        let prompt = """
        Compare these three perspectives and list the KEY DIFFERENCES in how they're covering this story.
        Focus on framing, emphasis, and narrative differences.

        Left Perspective:
        \(perspectives.0)

        Center Perspective:
        \(perspectives.1)

        Right Perspective:
        \(perspectives.2)

        List key differences (bullet format, one per line):
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Identify substantive differences in news coverage across political spectrum.",
            temperature: 0.3,
            maxTokens: 400
        )

        return response
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).starts(with: "•") || $0.trimmingCharacters(in: .whitespaces).starts(with: "-") }
            .map { $0.trimmingCharacters(in: .whitespaces).dropFirst(1).trimmingCharacters(in: .whitespaces) }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Models

struct PerspectiveAnalysis: Codable {
    let leftPerspective: String
    let centerPerspective: String
    let rightPerspective: String
    let sharedFacts: [String]
    let contentions: [Contention]
    let keyDifferences: [String]
    let analyzedAt: Date
}

struct Contention: Codable, Identifiable {
    let id = UUID()
    let point: String                  // The contentious issue
    let leftView: String               // How left sees it
    let centerView: String             // How center sees it
    let rightView: String              // How right sees it
}

// MARK: - Errors

enum AnalysisError: LocalizedError {
    case noArticles
    case insufficientData
    case aiGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noArticles:
            return "No articles provided for analysis"
        case .insufficientData:
            return "Insufficient data for multi-perspective analysis"
        case .aiGenerationFailed:
            return "AI analysis failed"
        }
    }
}
