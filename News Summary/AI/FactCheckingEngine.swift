import Foundation

//
//  FactCheckingEngine.swift
//  News Summary
//
//  AI-powered fact checking system
//  Extracts claims from articles and verifies them using AI analysis
//  Returns structured fact check results with verdicts and sources
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class FactCheckingEngine: ObservableObject {

    static let shared = FactCheckingEngine()

    @Published var isProcessing = false
    @Published var cachedFactChecks: [String: [FactCheck]] = [:]

    private init() {}

    // MARK: - Extract Claims

    /// Extract verifiable claims from an article
    func extractClaims(from article: NewsArticle, limit: Int = 10) async throws -> [Claim] {

        let fullText = extractFullText(from: article)

        let prompt = """
        Extract verifiable factual claims from this article.
        Focus on claims that can be fact-checked (numbers, dates, events, statements).
        Ignore opinions, predictions, and subjective statements.

        Article:
        \(fullText)

        List claims in this format (one per paragraph):
        CLAIM: [The factual claim]
        TYPE: [Statistic/Event/Statement/Quote]
        IMPORTANCE: [High/Medium/Low]
        CONTEXT: [Brief context]

        Extract up to \(limit) most important claims.
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are a fact-checking analyst. Extract only verifiable factual claims from articles.",
            temperature: 0.2,
            maxTokens: 1000
        )

        return parseClaims(response, articleId: article.id.uuidString)
    }

    // MARK: - Verify Single Claim

    /// Verify a single claim using AI analysis
    func verifyClaim(_ claim: Claim) async throws -> FactCheck {

        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        Fact-check this claim using your knowledge and reasoning:

        CLAIM: \(claim.claimText)
        CONTEXT: \(claim.context ?? "No additional context")

        Provide analysis in this format:

        VERDICT: [True/False/Misleading/Unverifiable/Partially True]
        CONFIDENCE: [0.0-1.0]

        EXPLANATION:
        [Detailed explanation of why this verdict was reached]

        EVIDENCE:
        - [Supporting or contradicting evidence point 1]
        - [Supporting or contradicting evidence point 2]
        - [Supporting or contradicting evidence point 3]

        SOURCES:
        - [Reliable source 1]
        - [Reliable source 2]

        CONTEXT:
        [Important context or nuance]

        SEVERITY: [Critical/High/Medium/Low] (if false or misleading)
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are a professional fact-checker. Be thorough, objective, and cite your reasoning. Admit uncertainty when appropriate.",
            temperature: 0.3,
            maxTokens: 1200
        )

        return parseFactCheck(response, claim: claim)
    }

    // MARK: - Batch Fact Check

    /// Fact-check multiple claims from an article
    func batchFactCheck(article: NewsArticle) async throws -> [FactCheck] {

        // Check cache
        if let cached = cachedFactChecks[article.id.uuidString] {
            return cached
        }

        isProcessing = true
        defer { isProcessing = false }

        // Extract claims
        let claims = try await extractClaims(from: article, limit: 8)

        // Verify each claim
        var factChecks: [FactCheck] = []

        for claim in claims {
            do {
                let check = try await verifyClaim(claim)
                factChecks.append(check)
            } catch {
                print("⚠️ Failed to verify claim: \(claim.claimText) - \(error)")
                // Continue with other claims
                continue
            }
        }

        // Cache results
        cachedFactChecks[article.id.uuidString] = factChecks

        return factChecks
    }

    // MARK: - Quick Verdict

    /// Get quick fact-check verdict for a single claim without full analysis
    func quickVerdict(claimText: String) async throws -> FactCheckVerdict {

        let prompt = """
        Quick fact-check: Is this claim accurate?

        CLAIM: \(claimText)

        Respond with one word: True, False, Misleading, or Unverifiable
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are a fact-checker. Provide quick verdicts.",
            temperature: 0.1,
            maxTokens: 50
        )

        return parseVerdict(response.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Cross-Article Verification

    /// Verify claims across multiple articles about the same story
    func crossArticleVerification(articles: [NewsArticle]) async throws -> [ConsensusFactCheck] {

        guard articles.count >= 2 else {
            throw FactCheckError.insufficientArticles
        }

        isProcessing = true
        defer { isProcessing = false }

        // Extract claims from all articles
        var allClaims: [Claim] = []
        for article in articles {
            let claims = try await extractClaims(from: article, limit: 5)
            allClaims.append(contentsOf: claims)
        }

        // Group similar claims
        let groupedClaims = groupSimilarClaims(allClaims)

        // Analyze consensus for each group
        var consensusChecks: [ConsensusFactCheck] = []

        for group in groupedClaims {
            let consensus = try await analyzeConsensus(claims: group)
            consensusChecks.append(consensus)
        }

        return consensusChecks
    }

    // MARK: - Helper Methods

    private func extractFullText(from article: NewsArticle) -> String {
        var text = ""

        if let title = article.title {
            text += title + "\n\n"
        }

        if let content = article.scrapedContent {
            text += content
        } else if let description = article.rssDescription {
            text += description
        }

        return text
    }

    private func parseClaims(_ response: String, articleId: String) -> [Claim] {
        var claims: [Claim] = []

        let paragraphs = response.components(separatedBy: "\n\n")

        for paragraph in paragraphs {
            let lines = paragraph.components(separatedBy: "\n")
            var claimText = ""
            var type: ClaimType = .statement
            var importance: ClaimImportance = .medium
            var context: String?

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.starts(with: "CLAIM:") {
                    claimText = trimmed.replacingOccurrences(of: "CLAIM:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.starts(with: "TYPE:") {
                    let typeString = trimmed.replacingOccurrences(of: "TYPE:", with: "").trimmingCharacters(in: .whitespaces)
                    type = ClaimType.from(string: typeString)
                } else if trimmed.starts(with: "IMPORTANCE:") {
                    let importanceString = trimmed.replacingOccurrences(of: "IMPORTANCE:", with: "").trimmingCharacters(in: .whitespaces)
                    importance = ClaimImportance.from(string: importanceString)
                } else if trimmed.starts(with: "CONTEXT:") {
                    context = trimmed.replacingOccurrences(of: "CONTEXT:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }

            if !claimText.isEmpty {
                claims.append(Claim(
                    claimText: claimText,
                    type: type,
                    importance: importance,
                    context: context,
                    sourceArticleId: articleId
                ))
            }
        }

        return claims
    }

    private func parseFactCheck(_ response: String, claim: Claim) -> FactCheck {
        var verdict: FactCheckVerdict = .unverifiable
        var confidence: Double = 0.5
        var explanation = ""
        var evidence: [String] = []
        var sources: [String] = []
        var additionalContext = ""
        var severity: FactCheckSeverity = .low

        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "VERDICT:") {
                let verdictString = trimmed.replacingOccurrences(of: "VERDICT:", with: "").trimmingCharacters(in: .whitespaces)
                verdict = parseVerdict(verdictString)
            } else if trimmed.starts(with: "CONFIDENCE:") {
                let confString = trimmed.replacingOccurrences(of: "CONFIDENCE:", with: "").trimmingCharacters(in: .whitespaces)
                confidence = Double(confString) ?? 0.5
            } else if trimmed == "EXPLANATION:" {
                currentSection = "explanation"
            } else if trimmed == "EVIDENCE:" {
                currentSection = "evidence"
            } else if trimmed == "SOURCES:" {
                currentSection = "sources"
            } else if trimmed.starts(with: "CONTEXT:") {
                currentSection = "context"
                additionalContext = trimmed.replacingOccurrences(of: "CONTEXT:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "SEVERITY:") {
                let severityString = trimmed.replacingOccurrences(of: "SEVERITY:", with: "").trimmingCharacters(in: .whitespaces)
                severity = FactCheckSeverity.from(string: severityString)
            } else if !trimmed.isEmpty {
                switch currentSection {
                case "explanation":
                    explanation += trimmed + " "
                case "evidence":
                    if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                        evidence.append(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                    }
                case "sources":
                    if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                        sources.append(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                    }
                case "context":
                    additionalContext += " " + trimmed
                default:
                    break
                }
            }
        }

        return FactCheck(
            claim: claim,
            verdict: verdict,
            confidence: confidence,
            explanation: explanation.trimmingCharacters(in: .whitespaces),
            evidence: evidence,
            sources: sources,
            context: additionalContext.trimmingCharacters(in: .whitespaces),
            severity: severity,
            checkedAt: Date()
        )
    }

    private func parseVerdict(_ string: String) -> FactCheckVerdict {
        let lower = string.lowercased()

        if lower.contains("true") && !lower.contains("partially") {
            return .true
        } else if lower.contains("false") {
            return .false
        } else if lower.contains("misleading") {
            return .misleading
        } else if lower.contains("partially") {
            return .partiallyTrue
        } else {
            return .unverifiable
        }
    }

    private func groupSimilarClaims(_ claims: [Claim]) -> [[Claim]] {
        var groups: [[Claim]] = []
        var processed: Set<UUID> = []

        for claim in claims {
            if processed.contains(claim.id) {
                continue
            }

            var group: [Claim] = [claim]
            processed.insert(claim.id)

            for otherClaim in claims {
                if processed.contains(otherClaim.id) {
                    continue
                }

                if claimsSimilar(claim, otherClaim) {
                    group.append(otherClaim)
                    processed.insert(otherClaim.id)
                }
            }

            if group.count >= 2 {
                groups.append(group)
            }
        }

        return groups
    }

    private func claimsSimilar(_ claim1: Claim, _ claim2: Claim) -> Bool {
        let words1 = Set(claim1.claimText.lowercased().components(separatedBy: .whitespaces))
        let words2 = Set(claim2.claimText.lowercased().components(separatedBy: .whitespaces))

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        let similarity = union > 0 ? Double(intersection) / Double(union) : 0.0
        return similarity > 0.6
    }

    private func analyzeConsensus(claims: [Claim]) async throws -> ConsensusFactCheck {
        let claimTexts = claims.map { $0.claimText }.joined(separator: "\n- ")

        let prompt = """
        Multiple sources made similar claims. Analyze the consensus:

        Claims:
        - \(claimTexts)

        CONSENSUS: [What all sources agree on]
        VERDICT: [True/False/Misleading/Unverifiable]
        AGREEMENT_LEVEL: [High/Medium/Low] (how much sources agree)
        EXPLANATION: [Why this is the consensus verdict]
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You analyze consensus across multiple sources.",
            temperature: 0.3,
            maxTokens: 600
        )

        return parseConsensusFactCheck(response, claims: claims)
    }

    private func parseConsensusFactCheck(_ response: String, claims: [Claim]) -> ConsensusFactCheck {
        var consensus = ""
        var verdict: FactCheckVerdict = .unverifiable
        var agreement: ConsensusLevel = .medium
        var explanation = ""

        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "CONSENSUS:") {
                consensus = trimmed.replacingOccurrences(of: "CONSENSUS:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "VERDICT:") {
                let verdictString = trimmed.replacingOccurrences(of: "VERDICT:", with: "").trimmingCharacters(in: .whitespaces)
                verdict = parseVerdict(verdictString)
            } else if trimmed.starts(with: "AGREEMENT_LEVEL:") {
                let levelString = trimmed.replacingOccurrences(of: "AGREEMENT_LEVEL:", with: "").trimmingCharacters(in: .whitespaces)
                agreement = ConsensusLevel.from(string: levelString)
            } else if trimmed.starts(with: "EXPLANATION:") {
                explanation = trimmed.replacingOccurrences(of: "EXPLANATION:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        return ConsensusFactCheck(
            claims: claims,
            consensus: consensus,
            verdict: verdict,
            agreementLevel: agreement,
            explanation: explanation,
            sourceCount: claims.count
        )
    }
}

// MARK: - Models

/// A verifiable claim extracted from an article
struct Claim: Identifiable, Codable {
    let id = UUID()
    let claimText: String
    let type: ClaimType
    let importance: ClaimImportance
    let context: String?
    let sourceArticleId: String
}

/// Types of factual claims
enum ClaimType: String, Codable {
    case statistic = "Statistic"
    case event = "Event"
    case statement = "Statement"
    case quote = "Quote"

    static func from(string: String) -> ClaimType {
        let lower = string.lowercased()
        if lower.contains("statistic") || lower.contains("number") {
            return .statistic
        } else if lower.contains("event") {
            return .event
        } else if lower.contains("quote") {
            return .quote
        } else {
            return .statement
        }
    }
}

/// Importance level of a claim
enum ClaimImportance: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    static func from(string: String) -> ClaimImportance {
        let lower = string.lowercased()
        if lower.contains("high") {
            return .high
        } else if lower.contains("low") {
            return .low
        } else {
            return .medium
        }
    }
}

/// Complete fact-check result
struct FactCheck: Identifiable, Codable {
    let id = UUID()
    let claim: Claim
    let verdict: FactCheckVerdict
    let confidence: Double           // 0.0-1.0
    let explanation: String
    let evidence: [String]
    let sources: [String]
    let context: String
    let severity: FactCheckSeverity  // Only relevant if false/misleading
    let checkedAt: Date

    var isAccurate: Bool {
        verdict == .true || verdict == .partiallyTrue
    }

    var requiresCorrection: Bool {
        verdict == .false || verdict == .misleading
    }
}

/// Fact-check verdict
enum FactCheckVerdict: String, Codable {
    case `true` = "True"
    case `false` = "False"
    case misleading = "Misleading"
    case partiallyTrue = "Partially True"
    case unverifiable = "Unverifiable"

    var color: String {
        switch self {
        case .true: return "green"
        case .false: return "red"
        case .misleading: return "orange"
        case .partiallyTrue: return "yellow"
        case .unverifiable: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .true: return "checkmark.circle.fill"
        case .false: return "xmark.circle.fill"
        case .misleading: return "exclamationmark.triangle.fill"
        case .partiallyTrue: return "minus.circle.fill"
        case .unverifiable: return "questionmark.circle.fill"
        }
    }
}

/// Severity of false/misleading claims
enum FactCheckSeverity: String, Codable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    static func from(string: String) -> FactCheckSeverity {
        let lower = string.lowercased()
        if lower.contains("critical") {
            return .critical
        } else if lower.contains("high") {
            return .high
        } else if lower.contains("low") {
            return .low
        } else {
            return .medium
        }
    }

    var color: String {
        switch self {
        case .critical: return "purple"
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "yellow"
        }
    }
}

/// Consensus fact-check across multiple sources
struct ConsensusFactCheck: Identifiable, Codable {
    let id = UUID()
    let claims: [Claim]
    let consensus: String
    let verdict: FactCheckVerdict
    let agreementLevel: ConsensusLevel
    let explanation: String
    let sourceCount: Int
}

/// Level of agreement across sources
enum ConsensusLevel: String, Codable {
    case high = "High Agreement"
    case medium = "Medium Agreement"
    case low = "Low Agreement"
    case conflicting = "Conflicting"

    static func from(string: String) -> ConsensusLevel {
        let lower = string.lowercased()
        if lower.contains("high") {
            return .high
        } else if lower.contains("low") {
            return .low
        } else if lower.contains("conflict") {
            return .conflicting
        } else {
            return .medium
        }
    }

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "orange"
        case .conflicting: return "red"
        }
    }
}

// MARK: - Errors

enum FactCheckError: LocalizedError {
    case insufficientArticles
    case noClaims
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .insufficientArticles:
            return "Need at least 2 articles for cross-verification"
        case .noClaims:
            return "No verifiable claims found in article"
        case .verificationFailed:
            return "Fact verification failed"
        }
    }
}
