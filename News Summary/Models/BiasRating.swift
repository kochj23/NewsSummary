//
//  BiasRating.swift
//  News Summary
//
//  Bias spectrum and credibility rating models
//  Based on Ad Fontes Media and AllSides methodology
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

/// Political bias spectrum from far-left to far-right
enum BiasSpectrum: String, Codable, CaseIterable {
    case farLeft = "Far Left"
    case left = "Left"
    case centerLeft = "Center-Left"
    case center = "Center"
    case centerRight = "Center-Right"
    case right = "Right"
    case farRight = "Far Right"

    /// Numeric value for calculations (-2.0 to +2.0)
    var value: Double {
        switch self {
        case .farLeft: return -2.0
        case .left: return -1.5
        case .centerLeft: return -0.7
        case .center: return 0.0
        case .centerRight: return 0.7
        case .right: return 1.5
        case .farRight: return 2.0
        }
    }

    /// Color representation for UI
    var color: Color {
        switch self {
        case .farLeft, .left: return .blue
        case .centerLeft: return Color(red: 0.6, green: 0.5, blue: 0.9)  // Light purple
        case .center: return .gray
        case .centerRight: return Color(red: 0.9, green: 0.5, blue: 0.6)  // Light red
        case .right, .farRight: return .red
        }
    }

    /// Short label for compact display
    var shortLabel: String {
        switch self {
        case .farLeft: return "FL"
        case .left: return "L"
        case .centerLeft: return "CL"
        case .center: return "C"
        case .centerRight: return "CR"
        case .right: return "R"
        case .farRight: return "FR"
        }
    }

    /// Create BiasSpectrum from numeric value
    static func from(value: Double) -> BiasSpectrum {
        switch value {
        case ..<(-1.75): return .farLeft
        case -1.75..<(-1.0): return .left
        case -1.0..<(-0.3): return .centerLeft
        case -0.3...0.3: return .center
        case 0.3..<1.0: return .centerRight
        case 1.0..<1.75: return .right
        default: return .farRight
        }
    }
}

/// Complete bias rating for an article
struct BiasRating: Codable {
    let spectrum: BiasSpectrum        // Overall bias classification
    let confidence: Double             // 0.0-1.0 confidence in rating
    let sourceBias: Double             // -2.0 to +2.0 from source database
    let contentBias: Double?           // -2.0 to +2.0 from AI analysis (optional)
    let emotionalLanguageScore: Double? // 0.0-1.0 (higher = more emotional)
    let balanceScore: Double?          // 0.0-1.0 (higher = more balanced)
    let reasoning: String?             // AI explanation

    /// Is this a high-confidence rating?
    var isHighConfidence: Bool {
        confidence >= 0.8
    }

    /// Human-readable confidence description
    var confidenceLabel: String {
        if confidence >= 0.8 { return "High" }
        if confidence >= 0.6 { return "Medium" }
        return "Low"
    }
}

/// Source credibility information
struct SourceCredibility: Codable {
    let credibility: Int               // 0-100 score
    let factuality: Double             // 0.0-1.0 fact accuracy
    let source: String                 // Where rating came from (Ad Fontes, AllSides, etc.)

    /// Color based on credibility
    var color: Color {
        if credibility >= 90 { return .green }
        if credibility >= 75 { return .yellow }
        if credibility >= 60 { return .orange }
        return .red
    }

    /// Label for credibility level
    var label: String {
        if credibility >= 90 { return "High" }
        if credibility >= 75 { return "Good" }
        if credibility >= 60 { return "Fair" }
        return "Low"
    }
}
