//
//  BiasExposureWidget.swift
//  News Summary Widgets
//
//  Bias exposure score widget showing reading diversity metrics
//  Displays diversity gauge, L/C/R distribution, and echo chamber status
//  Created by Jordan Koch on 2026-02-24
//

import WidgetKit
import SwiftUI

// MARK: - Bias Exposure Data (shared with main app)

struct BiasExposureData: Codable {
    let diversityScore: Double        // 0.0-1.0
    let echoStatus: String            // "Low Risk", "Moderate Risk", "High Risk"
    let leftPercentage: Double
    let centerPercentage: Double
    let rightPercentage: Double
    let averageBias: Double           // -1.0 to +1.0
    let articlesAnalyzed: Int
    let recommendation: String
}

// MARK: - Timeline Entry

struct BiasExposureEntry: TimelineEntry {
    let date: Date
    let data: BiasExposureData?
}

// MARK: - Timeline Provider

struct BiasExposureProvider: TimelineProvider {
    typealias Entry = BiasExposureEntry

    func placeholder(in context: Context) -> BiasExposureEntry {
        BiasExposureEntry(
            date: Date(),
            data: BiasExposureData(
                diversityScore: 0.72,
                echoStatus: "Low Risk",
                leftPercentage: 0.35,
                centerPercentage: 0.33,
                rightPercentage: 0.32,
                averageBias: -0.1,
                articlesAnalyzed: 87,
                recommendation: "Good balance. Keep exploring different perspectives."
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BiasExposureEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BiasExposureEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> BiasExposureEntry {
        guard let userDefaults = UserDefaults(suiteName: "group.com.jordankoch.NewsSummary"),
              let data = userDefaults.data(forKey: "biasExposureData"),
              let biasData = try? JSONDecoder().decode(BiasExposureData.self, from: data) else {
            return BiasExposureEntry(date: Date(), data: nil)
        }
        return BiasExposureEntry(date: Date(), data: biasData)
    }
}

// MARK: - Widget Views

struct BiasExposureWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BiasExposureEntry

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
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                Text("Bias")
                    .font(.headline)
                Spacer()
            }

            if let data = entry.data {
                Spacer()

                // Circular gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 64, height: 64)

                    Circle()
                        .trim(from: 0, to: data.diversityScore)
                        .stroke(
                            gaugeColor(data.diversityScore),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(data.diversityScore * 100))")
                            .font(.system(size: 20, weight: .bold))
                        Text("/ 100")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }

                Text(data.echoStatus)
                    .font(.caption2.bold())
                    .foregroundColor(echoStatusColor(data.echoStatus))

                Spacer()
            } else {
                Spacer()
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                Text("Bias Balance")
                    .font(.headline)
                Spacer()
                if let data = entry.data {
                    Text(data.echoStatus)
                        .font(.caption.bold())
                        .foregroundColor(echoStatusColor(data.echoStatus))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(echoStatusColor(data.echoStatus).opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let data = entry.data {
                Divider()

                HStack(spacing: 16) {
                    // Gauge
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                            .frame(width: 50, height: 50)

                        Circle()
                            .trim(from: 0, to: data.diversityScore)
                            .stroke(
                                gaugeColor(data.diversityScore),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(data.diversityScore * 100))")
                            .font(.system(size: 16, weight: .bold))
                    }

                    // L/C/R bars
                    VStack(alignment: .leading, spacing: 4) {
                        biasBar(label: "L", percentage: data.leftPercentage, color: .blue)
                        biasBar(label: "C", percentage: data.centerPercentage, color: .gray)
                        biasBar(label: "R", percentage: data.rightPercentage, color: .red)
                    }

                    // Info
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(data.articlesAnalyzed)")
                            .font(.system(size: 14, weight: .bold))
                        Text("articles")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Spacer()
                Text("Read some articles to see your bias balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
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
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)

                VStack(alignment: .leading) {
                    Text("Bias Balance")
                        .font(.headline)
                    Text("Reading Diversity Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let data = entry.data {
                    VStack {
                        Text("\(Int(data.diversityScore * 100))")
                            .font(.title2.bold())
                            .foregroundColor(gaugeColor(data.diversityScore))
                        Text(data.echoStatus)
                            .font(.caption2.bold())
                            .foregroundColor(echoStatusColor(data.echoStatus))
                    }
                }
            }

            Divider()

            if let data = entry.data {
                // Gauge and bars
                HStack(spacing: 20) {
                    // Circular gauge
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: data.diversityScore)
                            .stroke(
                                gaugeColor(data.diversityScore),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(Int(data.diversityScore * 100))")
                                .font(.system(size: 24, weight: .bold))
                            Text("of 100")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }

                    // L/C/R breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        biasBar(label: "Left", percentage: data.leftPercentage, color: .blue)
                        biasBar(label: "Center", percentage: data.centerPercentage, color: .gray)
                        biasBar(label: "Right", percentage: data.rightPercentage, color: .red)
                    }
                }

                Divider()

                // Recommendation
                Text(data.recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Spacer()

                // Footer
                HStack {
                    Text("Based on \(data.articlesAnalyzed) articles")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Updated \(entry.date, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("Read articles to see your bias balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Shared Components

    private func biasBar(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: label.count > 1 ? 40 : 12, alignment: .trailing)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func gaugeColor(_ score: Double) -> Color {
        if score >= 0.7 { return .green }
        if score >= 0.4 { return .yellow }
        return .red
    }

    private func echoStatusColor(_ status: String) -> Color {
        switch status {
        case "Low Risk": return .green
        case "Moderate Risk": return .yellow
        case "High Risk": return .red
        default: return .secondary
        }
    }
}

// MARK: - Widget Definition

struct BiasExposureWidget: Widget {
    let kind: String = "BiasExposureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiasExposureProvider()) { entry in
            BiasExposureWidgetView(entry: entry)
        }
        .configurationDisplayName("Bias Balance")
        .description("Track your reading diversity and echo chamber risk")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
