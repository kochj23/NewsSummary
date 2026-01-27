import Foundation

//
//  CompareCoverageTool.swift
//  News Summary
//
//  Side-by-side coverage comparison across multiple sources
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class CompareCoverageTool: ObservableObject {

    static let shared = CompareCoverageTool()

    @Published var isComparing = false

    private init() {}

    func compareArticles(_ articles: [NewsArticle]) async throws -> CoverageComparison {

        guard articles.count >= 2 else {
            throw ComparisonError.insufficientArticles
        }

        isComparing = true
        defer { isComparing = false }

        // Group by bias
        let leftArticles = articles.filter { $0.source?.bias == .left }
        let centerArticles = articles.filter { $0.source?.bias == .center }
        let rightArticles = articles.filter { $0.source?.bias == .right }

        // Analyze each group
        async let leftCoverage = analyzeCoverage(leftArticles, bias: "Left")
        async let centerCoverage = analyzeCoverage(centerArticles, bias: "Center")
        async let rightCoverage = analyzeCoverage(rightArticles, bias: "Right")

        let coverages = try await (leftCoverage, centerCoverage, rightCoverage)

        // Find differences
        let differences = try await identifyDifferences(
            left: coverages.0,
            center: coverages.1,
            right: coverages.2
        )

        return CoverageComparison(
            story: articles.first?.title ?? "Comparison",
            leftCoverage: coverages.0,
            centerCoverage: coverages.1,
            rightCoverage: coverages.2,
            differences: differences,
            analyzedAt: Date()
        )
    }

    private func analyzeCoverage(_ articles: [NewsArticle], bias: String) async throws -> ArticleCoverage {

        guard !articles.isEmpty else {
            return ArticleCoverage(
                articles: [],
                keyPoints: [],
                tone: .neutral,
                headlines: [],
                emphasis: [],
                quotedSources: []
            )
        }

        let texts = articles.compactMap { ($0.title ?? "") + "\n" + ($0.content ?? $0.articleDescription ?? "") }
        let combined = texts.joined(separator: "\n\n---\n\n")

        let prompt = """
        Analyze \(bias) source coverage of this story:

        \(combined)

        Provide:
        KEY_POINTS: (bullet list)
        TONE: [Alarmist/Measured/Optimistic/Pessimistic/Neutral]
        EMPHASIS: (What they focus on - bullet list)
        QUOTED_SOURCES: (Who they quote - comma-separated)

        Be objective. Describe HOW they cover it.
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Analyze news coverage objectively.",
            temperature: 0.3,
            maxTokens: 500
        )

        return parseCoverageAnalysis(response, articles: articles)
    }

    private func parseCoverageAnalysis(_ response: String, articles: [NewsArticle]) -> ArticleCoverage {

        var keyPoints: [String] = []
        var tone: CoverageTone = .neutral
        var emphasis: [String] = []
        var quotedSources: [String] = []

        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "KEY_POINTS:") {
                currentSection = "points"
            } else if trimmed.starts(with: "TONE:") {
                let toneString = trimmed.replacingOccurrences(of: "TONE:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                tone = CoverageTone(rawValue: toneString.components(separatedBy: "/").first ?? "neutral") ?? .neutral
            } else if trimmed.starts(with: "EMPHASIS:") {
                currentSection = "emphasis"
            } else if trimmed.starts(with: "QUOTED_SOURCES:") {
                let sources = trimmed.replacingOccurrences(of: "QUOTED_SOURCES:", with: "")
                quotedSources = sources.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                currentSection = ""
            } else if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                switch currentSection {
                case "points":
                    keyPoints.append(String(content))
                case "emphasis":
                    emphasis.append(String(content))
                default:
                    break
                }
            }
        }

        return ArticleCoverage(
            articles: articles,
            keyPoints: keyPoints,
            tone: tone,
            headlines: articles.compactMap { $0.title },
            emphasis: emphasis,
            quotedSources: quotedSources
        )
    }

    private func identifyDifferences(left: ArticleCoverage, center: ArticleCoverage, right: ArticleCoverage) async throws -> CoverageDifferences {

        let prompt = """
        Compare these three coverage analyses and identify:
        1. What's UNIQUE to each perspective
        2. What ALL agree on
        3. Direct CONFLICTS between them

        Left Coverage:
        Points: \(left.keyPoints.joined(separator: ", "))
        Emphasis: \(left.emphasis.joined(separator: ", "))

        Center Coverage:
        Points: \(center.keyPoints.joined(separator: ", "))
        Emphasis: \(center.emphasis.joined(separator: ", "))

        Right Coverage:
        Points: \(right.keyPoints.joined(separator: ", "))
        Emphasis: \(right.emphasis.joined(separator: ", "))

        Format:
        UNIQUE_LEFT: (bullet list)
        UNIQUE_CENTER: (bullet list)
        UNIQUE_RIGHT: (bullet list)
        SHARED: (bullet list)
        CONFLICTS: (bullet list of direct contradictions)
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "Identify coverage differences objectively.",
            temperature: 0.2,
            maxTokens: 600
        )

        return parseDifferences(response)
    }

    private func parseDifferences(_ response: String) -> CoverageDifferences {

        var uniqueLeft: [String] = []
        var uniqueCenter: [String] = []
        var uniqueRight: [String] = []
        var shared: [String] = []
        var conflicts: [String] = []

        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "UNIQUE_LEFT:") {
                currentSection = "left"
            } else if trimmed.starts(with: "UNIQUE_CENTER:") {
                currentSection = "center"
            } else if trimmed.starts(with: "UNIQUE_RIGHT:") {
                currentSection = "right"
            } else if trimmed.starts(with: "SHARED:") {
                currentSection = "shared"
            } else if trimmed.starts(with: "CONFLICTS:") {
                currentSection = "conflicts"
            } else if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                let content = String(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                switch currentSection {
                case "left": uniqueLeft.append(content)
                case "center": uniqueCenter.append(content)
                case "right": uniqueRight.append(content)
                case "shared": shared.append(content)
                case "conflicts": conflicts.append(content)
                default: break
                }
            }
        }

        return CoverageDifferences(
            uniqueToLeft: uniqueLeft,
            uniqueToCenter: uniqueCenter,
            uniqueToRight: uniqueRight,
            sharedFacts: shared,
            conflictingClaims: conflicts
        )
    }
}

// MARK: - Models

struct CoverageComparison: Codable {
    let story: String
    let leftCoverage: ArticleCoverage
    let centerCoverage: ArticleCoverage
    let rightCoverage: ArticleCoverage
    let differences: CoverageDifferences
    let analyzedAt: Date
}

struct ArticleCoverage: Codable {
    let articles: [NewsArticle]
    let keyPoints: [String]
    let tone: CoverageTone
    let headlines: [String]
    let emphasis: [String]
    let quotedSources: [String]
}

enum CoverageTone: String, Codable {
    case alarmist = "Alarmist"
    case measured = "Measured"
    case optimistic = "Optimistic"
    case pessimistic = "Pessimistic"
    case neutral = "Neutral"

    var color: String {
        switch self {
        case .alarmist: return "red"
        case .measured: return "green"
        case .optimistic: return "blue"
        case .pessimistic: return "orange"
        case .neutral: return "gray"
        }
    }
}

struct CoverageDifferences: Codable {
    let uniqueToLeft: [String]
    let uniqueToCenter: [String]
    let uniqueToRight: [String]
    let sharedFacts: [String]
    let conflictingClaims: [String]
}

enum ComparisonError: LocalizedError {
    case insufficientArticles
    case analysisFailed

    var errorDescription: String? {
        switch self {
        case .insufficientArticles:
            return "Need at least 2 articles to compare"
        case .analysisFailed:
            return "Failed to analyze coverage"
        }
    }
}
