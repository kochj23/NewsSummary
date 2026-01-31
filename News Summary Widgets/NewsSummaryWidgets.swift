//
//  NewsSummaryWidgets.swift
//  News Summary Widgets
//
//  WidgetKit widgets for macOS - Breaking news ticker, headlines
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct NewsWidgetEntry: TimelineEntry {
    let date: Date
    let breakingNewsCount: Int
    let topHeadlines: [WidgetHeadline]
    let categoryCounts: [String: Int]
    let lastUpdated: Date?
}

struct WidgetHeadline: Identifiable, Codable {
    let id: String
    let title: String
    let source: String
    let category: String
    let publishedAt: Date
    let imageURL: String?
    let isBreaking: Bool
}

// MARK: - Timeline Provider

struct NewsWidgetProvider: TimelineProvider {
    typealias Entry = NewsWidgetEntry

    func placeholder(in context: Context) -> NewsWidgetEntry {
        NewsWidgetEntry(
            date: Date(),
            breakingNewsCount: 3,
            topHeadlines: [
                WidgetHeadline(id: "1", title: "Breaking: Major Tech Announcement", source: "TechNews", category: "Technology", publishedAt: Date(), imageURL: nil, isBreaking: true),
                WidgetHeadline(id: "2", title: "Markets Rally on Economic Data", source: "Finance Daily", category: "Business", publishedAt: Date(), imageURL: nil, isBreaking: false),
                WidgetHeadline(id: "3", title: "New Climate Agreement Reached", source: "World News", category: "World", publishedAt: Date(), imageURL: nil, isBreaking: false)
            ],
            categoryCounts: ["Technology": 15, "Business": 12, "World": 10, "Politics": 8],
            lastUpdated: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsWidgetEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> NewsWidgetEntry {
        let data = NewsWidgetDataStore.shared.loadData()
        return NewsWidgetEntry(
            date: Date(),
            breakingNewsCount: data.breakingNewsCount,
            topHeadlines: data.topHeadlines,
            categoryCounts: data.categoryCounts,
            lastUpdated: data.lastUpdated
        )
    }
}

// MARK: - Widget Data Store

class NewsWidgetDataStore {
    static let shared = NewsWidgetDataStore()

    private let suiteName = "group.com.jordankoch.NewsSummary"
    private let dataKey = "widgetData"

    struct WidgetData: Codable {
        let breakingNewsCount: Int
        let topHeadlines: [WidgetHeadline]
        let categoryCounts: [String: Int]
        let lastUpdated: Date?
    }

    func loadData() -> WidgetData {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: dataKey),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return WidgetData(breakingNewsCount: 0, topHeadlines: [], categoryCounts: [:], lastUpdated: nil)
        }
        return widgetData
    }

    func saveData(_ data: WidgetData) {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data) else { return }
        userDefaults.set(encoded, forKey: dataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Breaking News Widget View

struct BreakingNewsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: NewsWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.cyan)
                Text("News")
                    .font(.headline)
                Spacer()
                if entry.breakingNewsCount > 0 {
                    Text("\(entry.breakingNewsCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Top headline
            if let headline = entry.topHeadlines.first {
                VStack(alignment: .leading, spacing: 4) {
                    if headline.isBreaking {
                        Text("BREAKING")
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                    }

                    Text(headline.title)
                        .font(.subheadline.bold())
                        .lineLimit(3)

                    Text(headline.source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No headlines")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Last updated
            if let lastUpdated = entry.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.cyan)
                Text("News Summary")
                    .font(.headline)
                Spacer()
                if entry.breakingNewsCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("\(entry.breakingNewsCount) Breaking")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                }
            }

            Divider()

            // Headlines list
            if entry.topHeadlines.isEmpty {
                Spacer()
                Text("No headlines available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.topHeadlines.prefix(3)) { headline in
                    HeadlineRow(headline: headline)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Large Widget

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "newspaper.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)

                VStack(alignment: .leading) {
                    Text("News Summary")
                        .font(.headline)
                    if let lastUpdated = entry.lastUpdated {
                        Text("Updated \(lastUpdated, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if entry.breakingNewsCount > 0 {
                    VStack {
                        Text("\(entry.breakingNewsCount)")
                            .font(.title2.bold())
                            .foregroundColor(.red)
                        Text("Breaking")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }

            Divider()

            // Category badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entry.categoryCounts.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { category, count in
                        CategoryBadge(name: category, count: count)
                    }
                }
            }

            Divider()

            // Headlines
            Text("Top Headlines")
                .font(.subheadline.bold())

            ForEach(entry.topHeadlines.prefix(5)) { headline in
                HeadlineRow(headline: headline, showCategory: true)
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Headline Row

struct HeadlineRow: View {
    let headline: WidgetHeadline
    var showCategory: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if headline.isBreaking {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(y: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(headline.title)
                    .font(.caption.bold())
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(headline.source)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if showCategory {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(headline.category)
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }

                    Text("•")
                        .foregroundColor(.secondary)
                    Text(headline.publishedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption2)
            Text("\(count)")
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.cyan.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Widget Bundle

@main
struct NewsSummaryWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreakingNewsWidget()
        HeadlinesWidget()
    }
}

// MARK: - Breaking News Widget

struct BreakingNewsWidget: Widget {
    let kind: String = "BreakingNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsWidgetProvider()) { entry in
            BreakingNewsWidgetView(entry: entry)
        }
        .configurationDisplayName("Breaking News")
        .description("Stay updated with breaking news")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Headlines Widget View

struct HeadlinesWidgetView: View {
    let entry: NewsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.purple)
                Text("Headlines")
                    .font(.headline)
                Spacer()
                Text("\(entry.topHeadlines.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if entry.topHeadlines.isEmpty {
                Spacer()
                Text("No headlines")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.topHeadlines.prefix(4)) { headline in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text("\(headline.source) • \(headline.category)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Headlines Widget

struct HeadlinesWidget: Widget {
    let kind: String = "HeadlinesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsWidgetProvider()) { entry in
            HeadlinesWidgetView(entry: entry)
        }
        .configurationDisplayName("Top Headlines")
        .description("Quick view of top headlines")
        .supportedFamilies([.systemMedium])
    }
}
