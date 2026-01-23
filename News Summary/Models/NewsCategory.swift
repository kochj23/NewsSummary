//
//  NewsCategory.swift
//  News Summary
//
//  News category definitions (9 categories)
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

enum NewsCategory: String, Codable, CaseIterable {
    case us = "US"
    case world = "World"
    case local = "Local"
    case business = "Business"
    case technology = "Technology"
    case entertainment = "Entertainment"
    case sports = "Sports"
    case science = "Science"
    case health = "Health"

    var icon: String {
        switch self {
        case .us: return "flag.fill"
        case .world: return "globe.americas.fill"
        case .local: return "mappin.circle.fill"
        case .business: return "dollarsign.circle.fill"
        case .technology: return "laptopcomputer"
        case .entertainment: return "tv.fill"
        case .sports: return "sportscourt.fill"
        case .science: return "atom"
        case .health: return "cross.case.fill"
        }
    }

    var color: Color {
        switch self {
        case .us: return .red
        case .world: return .blue
        case .local: return .green
        case .business: return .orange
        case .technology: return .cyan
        case .entertainment: return .pink
        case .sports: return .purple
        case .science: return .indigo
        case .health: return .mint
        }
    }

    var displayName: String {
        return self.rawValue
    }
}
