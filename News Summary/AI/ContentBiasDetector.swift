import Foundation

//
//  ContentBiasDetector.swift
//  News Summary
//
//  AI-powered content bias detection
//  Analyzes article text for loaded language, framing, and manipulation
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class ContentBiasDetector: ObservableObject {

    static let shared = ContentBiasDetector()

    @Published var isAnalyzing = false

    private init() {}

    func analyzeBias(article: NewsArticle) async throws -> ContentBiasAnalysis {

        isAnalyzing = true
        defer { isAnalyzing = false }

        let text = (article.title ?? "") + "\n\n" + (article.content ?? article.articleDescription ?? "")

        let prompt = """
        Analyze this article for content-level bias.

        Article:
        \(text)

        Provide analysis in this format:

        OVERALL_BIAS: [Left/Center/Right]
        CONFIDENCE: [0.0-1.0]

        BIAS_INDICATORS:
        - [Type]: [Example]
        - [Type]: [Example]

        LOADED_LANGUAGE:
        - [Word/phrase]: [Why it's loaded]

        OMISSIONS:
        - [What perspective/fact is missing]

        FRAMING:
        [How the story is framed and what that reveals]

        OBJECTIVITY_SCORE: [0-100]
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are a media bias analyst. Identify bias objectively without inserting your own bias.",
            temperature: 0.3,
            maxTokens: 800
        )

        return parseBiasAnalysis(response)
    }

    private func parseBiasAnalysis(_ response: String) -> ContentBiasAnalysis {

        var overallBias: BiasRating = .center
        var confidence: Double = 0.5
        var indicators: [BiasIndicator] = []
        var loadedWords: [String] = []
        var omissions: [String] = []
        var framing: String = ""
        var objectivityScore: Double = 50.0

        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "OVERALL_BIAS:") {
                let biasString = trimmed.replacingOccurrences(of: "OVERALL_BIAS:", with: "").trimmingCharacters(in: .whitespaces)
                if biasString.lowercased().contains("left") {
                    overallBias = .left
                } else if biasString.lowercased().contains("right") {
                    overallBias = .right
                } else {
                    overallBias = .center
                }
            } else if trimmed.starts(with: "CONFIDENCE:") {
                let confString = trimmed.replacingOccurrences(of: "CONFIDENCE:", with: "").trimmingCharacters(in: .whitespaces)
                confidence = Double(confString) ?? 0.5
            } else if trimmed.starts(with: "OBJECTIVITY_SCORE:") {
                let scoreString = trimmed.replacingOccurrences(of: "OBJECTIVITY_SCORE:", with: "").trimmingCharacters(in: .whitespaces)
                objectivityScore = Double(scoreString) ?? 50.0
            } else if trimmed == "BIAS_INDICATORS:" {
                currentSection = "indicators"
            } else if trimmed == "LOADED_LANGUAGE:" {
                currentSection = "loaded"
            } else if trimmed == "OMISSIONS:" {
                currentSection = "omissions"
            } else if trimmed.starts(with: "FRAMING:") {
                currentSection = "framing"
                framing = trimmed.replacingOccurrences(of: "FRAMING:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)

                switch currentSection {
                case "indicators":
                    if let colonIndex = content.firstIndex(of: ":") {
                        let type = String(content[..<colonIndex])
                        let example = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        indicators.append(BiasIndicator(
                            type: BiasType(rawValue: type) ?? .loadedLanguage,
                            examples: [example],
                            severity: .medium
                        ))
                    }
                case "loaded":
                    loadedWords.append(content)
                case "omissions":
                    omissions.append(content)
                case "framing":
                    framing += " " + content
                default:
                    break
                }
            }
        }

        return ContentBiasAnalysis(
            overallBias: overallBias,
            confidence: confidence,
            biasIndicators: indicators,
            emotionallyChargedWords: loadedWords,
            omittedPerspectives: omissions,
            frameAnalysis: framing,
            objectivityScore: objectivityScore
        )
    }
}

// MARK: - Models

struct ContentBiasAnalysis: Codable {
    let overallBias: BiasRating
    let confidence: Double
    let biasIndicators: [BiasIndicator]
    let emotionallyChargedWords: [String]
    let omittedPerspectives: [String]
    let frameAnalysis: String
    let objectivityScore: Double

    var biasLevel: BiasLevel {
        if objectivityScore >= 80 {
            return .minimal
        } else if objectivityScore >= 60 {
            return .slight
        } else if objectivityScore >= 40 {
            return .moderate
        } else if objectivityScore >= 20 {
            return .significant
        } else {
            return .extreme
        }
    }
}

struct BiasIndicator: Codable, Identifiable {
    let id = UUID()
    let type: BiasType
    let examples: [String]
    let severity: SeverityLevel
}

enum BiasType: String, Codable {
    case selectiveSourcing = "Selective Sourcing"
    case loadedLanguage = "Loaded Language"
    case omissionBias = "Omission Bias"
    case frameControl = "Frame Control"
    case falseDichotomy = "False Dichotomy"
    case strawman = "Strawman"
    case emotionalAppeal = "Emotional Appeal"
    case cherryPicking = "Cherry Picking"

    var description: String {
        switch self {
        case .selectiveSourcing:
            return "Only quotes sources from one perspective"
        case .loadedLanguage:
            return "Uses emotionally charged or biased words"
        case .omissionBias:
            return "Leaves out important facts or perspectives"
        case .frameControl:
            return "Frames the story to favor one interpretation"
        case .falseDichotomy:
            return "Presents only two options when more exist"
        case .strawman:
            return "Misrepresents opposing views"
        case .emotionalAppeal:
            return "Appeals to emotion rather than reason"
        case .cherryPicking:
            return "Selects only data that supports one view"
        }
    }
}

enum SeverityLevel: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

enum BiasLevel: String {
    case minimal = "Minimal Bias"
    case slight = "Slight Bias"
    case moderate = "Moderate Bias"
    case significant = "Significant Bias"
    case extreme = "Extreme Bias"

    var color: String {
        switch self {
        case .minimal: return "green"
        case .slight: return "yellow"
        case .moderate: return "orange"
        case .significant: return "red"
        case .extreme: return "purple"
        }
    }
}
