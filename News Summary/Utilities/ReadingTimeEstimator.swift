import Foundation

//
//  ReadingTimeEstimator.swift
//  News Summary
//
//  Reading time calculation and difficulty estimation
//  Author: Jordan Koch
//  Date: 2026-01-26
//

class ReadingTimeEstimator {

    // Average reading speeds (words per minute)
    static let slowReader: Double = 200
    static let averageReader: Double = 250
    static let fastReader: Double = 300

    /// Calculate estimated reading time for text
    /// - Parameters:
    ///   - text: The text to analyze
    ///   - speed: Reading speed in WPM (default: average)
    /// - Returns: Reading time in seconds
    static func estimateReadingTime(for text: String, speed: Double = averageReader) -> TimeInterval {
        let wordCount = countWords(in: text)
        let minutes = Double(wordCount) / speed
        return minutes * 60.0 // Convert to seconds
    }

    /// Count words in text
    static func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    /// Format reading time for display
    /// - Parameter seconds: Time in seconds
    /// - Returns: Formatted string like "5 min" or "< 1 min"
    static func formatReadingTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(ceil(seconds / 60.0))

        if minutes < 1 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }

    /// Estimate reading difficulty based on text complexity
    static func estimateDifficulty(for text: String) -> ReadingDifficulty {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let sentences = text.components(separatedBy: .punctuationCharacters).filter { !$0.isEmpty }

        guard !words.isEmpty, !sentences.isEmpty else { return .easy }

        // Calculate average word length
        let avgWordLength = words.map { $0.count }.reduce(0, +) / words.count

        // Calculate average sentence length
        let avgSentenceLength = words.count / sentences.count

        // Flesch Reading Ease approximation
        let score = calculateComplexityScore(avgWordLength: avgWordLength, avgSentenceLength: avgSentenceLength)

        switch score {
        case 0..<30:
            return .expert
        case 30..<50:
            return .advanced
        case 50..<70:
            return .moderate
        default:
            return .easy
        }
    }

    private static func calculateComplexityScore(avgWordLength: Int, avgSentenceLength: Int) -> Double {
        // Simplified complexity calculation
        // Longer words and longer sentences = harder to read
        let wordComplexity = Double(avgWordLength) * 10.0
        let sentenceComplexity = Double(avgSentenceLength) * 2.0

        return 100.0 - (wordComplexity + sentenceComplexity)
    }
}

// MARK: - Reading Difficulty

enum ReadingDifficulty: String, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case advanced = "Advanced"
    case expert = "Expert"

    var icon: String {
        switch self {
        case .easy: return "🟢"
        case .moderate: return "🟡"
        case .advanced: return "🟠"
        case .expert: return "🔴"
        }
    }

    var description: String {
        switch self {
        case .easy:
            return "Grade 8 reading level - Easy to understand"
        case .moderate:
            return "Grade 12 reading level - Standard news article"
        case .advanced:
            return "College level - Some background knowledge helpful"
        case .expert:
            return "Domain expertise helpful - Technical content"
        }
    }

    var color: String {
        switch self {
        case .easy: return "green"
        case .moderate: return "yellow"
        case .advanced: return "orange"
        case .expert: return "red"
        }
    }
}

// MARK: - Article Extension

extension NewsArticle {

    var estimatedReadingTime: TimeInterval {
        let fullText = (title ?? "") + " " + (articleDescription ?? "") + " " + (content ?? "")
        return ReadingTimeEstimator.estimateReadingTime(for: fullText)
    }

    var formattedReadingTime: String {
        return ReadingTimeEstimator.formatReadingTime(estimatedReadingTime)
    }

    var readingDifficulty: ReadingDifficulty {
        let fullText = (title ?? "") + " " + (articleDescription ?? "") + " " + (content ?? "")
        return ReadingTimeEstimator.estimateDifficulty(for: fullText)
    }
}
