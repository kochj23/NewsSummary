import Foundation
import SwiftUI

//
//  ReadingAnalytics.swift
//  News Summary
//
//  Reading habits analytics with bias exposure tracking and echo chamber detection
//  Tracks reading patterns, generates insights, and promotes diverse news consumption
//  Author: Jordan Koch
//  Date: 2026-01-26
//

/// Comprehensive reading analytics and habit tracking service
@MainActor
class ReadingAnalytics: ObservableObject {

    // MARK: - Singleton

    static let shared = ReadingAnalytics()

    // MARK: - Published Properties

    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalArticlesRead: Int = 0
    @Published var totalReadingTime: TimeInterval = 0
    @Published var readingHistory: [ReadingRecord] = []
    @Published var biasExposureMetrics: BiasExposureMetrics?
    @Published var weeklyReport: WeeklyReport?
    @Published var monthlyReport: MonthlyReport?

    // MARK: - Private Properties

    private let analyticsFileURL: URL
    private let historyFileURL: URL
    private var lastReadDate: Date?

    // MARK: - Initialization

    private init() {
        // Setup file URLs for persistence
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("News Summary", isDirectory: true)

        // Create app directory if it doesn't exist
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        analyticsFileURL = appDirectory.appendingPathComponent("analytics.json")
        historyFileURL = appDirectory.appendingPathComponent("reading_history.json")

        // Load existing data
        loadAnalytics()
        loadHistory()
        updateStreaks()
        calculateBiasExposure()
    }

    // MARK: - Recording Reading Activity

    /// Record an article read event
    func recordRead(article: NewsArticle, timeSpent: TimeInterval) {
        let record = ReadingRecord(
            article: article,
            timeSpent: timeSpent,
            timestamp: Date()
        )

        readingHistory.insert(record, at: 0)
        totalArticlesRead += 1
        totalReadingTime += timeSpent

        // Keep only last 1000 records
        if readingHistory.count > 1000 {
            readingHistory.removeLast()
        }

        updateStreaks()
        calculateBiasExposure()
        saveHistory()
        saveAnalytics()

        // Check if we need to generate weekly/monthly reports
        checkForReportGeneration()
    }

    /// Record time spent reading (for tracking active reading sessions)
    func recordReadingTime(_ duration: TimeInterval) {
        totalReadingTime += duration
        saveAnalytics()
    }

    // MARK: - Streak Tracking

    private func updateStreaks() {
        let today = Calendar.current.startOfDay(for: Date())

        // Get unique days with reading activity
        let readingDays = Set(readingHistory.map { record in
            Calendar.current.startOfDay(for: record.timestamp)
        })

        // Calculate current streak
        var streak = 0
        var checkDate = today

        while readingDays.contains(checkDate) {
            streak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
        }

        currentStreak = streak

        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastReadDate = readingHistory.first?.timestamp
    }

    /// Check if the user read today
    var readToday: Bool {
        guard let lastRead = lastReadDate else { return false }
        return Calendar.current.isDateInToday(lastRead)
    }

    // MARK: - Bias Exposure Analysis

    /// Calculate bias exposure metrics from reading history
    func calculateBiasExposure() {
        let recentRecords = readingHistory.prefix(100) // Last 100 articles

        guard !recentRecords.isEmpty else {
            biasExposureMetrics = nil
            return
        }

        // Calculate bias distribution
        var leftCount = 0
        var centerCount = 0
        var rightCount = 0
        var unknownCount = 0

        var biasSum: Double = 0.0
        var biasValues: [Double] = []

        for record in recentRecords {
            if let bias = record.article.bias {
                let value = bias.spectrum.value
                biasValues.append(value)
                biasSum += value

                if value < -0.3 {
                    leftCount += 1
                } else if value > 0.3 {
                    rightCount += 1
                } else {
                    centerCount += 1
                }
            } else {
                unknownCount += 1
            }
        }

        let total = recentRecords.count
        let averageBias = biasValues.isEmpty ? 0.0 : biasSum / Double(biasValues.count)

        // Calculate standard deviation for diversity score
        let variance = biasValues.isEmpty ? 0.0 : biasValues.reduce(0.0) { sum, value in
            sum + pow(value - averageBias, 2)
        } / Double(biasValues.count)
        let standardDeviation = sqrt(variance)

        // Diversity score (0-1, higher is more diverse)
        let diversityScore = min(standardDeviation / 0.5, 1.0)

        // Echo chamber detection
        let echoScore = calculateEchoChamberScore(
            leftCount: leftCount,
            centerCount: centerCount,
            rightCount: rightCount
        )

        biasExposureMetrics = BiasExposureMetrics(
            leftPercentage: Double(leftCount) / Double(total) * 100,
            centerPercentage: Double(centerCount) / Double(total) * 100,
            rightPercentage: Double(rightCount) / Double(total) * 100,
            unknownPercentage: Double(unknownCount) / Double(total) * 100,
            averageBias: averageBias,
            diversityScore: diversityScore,
            echoScore: echoScore,
            sampleSize: total
        )
    }

    /// Detect echo chamber tendencies
    func detectEchoChamber() -> EchoChamberStatus {
        guard let metrics = biasExposureMetrics, metrics.sampleSize >= 20 else {
            return .insufficient
        }

        if metrics.echoScore > 0.7 {
            return .high
        } else if metrics.echoScore > 0.4 {
            return .moderate
        } else {
            return .low
        }
    }

    /// Calculate echo chamber score (0-1, higher means stronger echo chamber)
    private func calculateEchoChamberScore(leftCount: Int, centerCount: Int, rightCount: Int) -> Double {
        let total = Double(leftCount + centerCount + rightCount)
        guard total > 0 else { return 0.0 }

        let leftPct = Double(leftCount) / total
        let centerPct = Double(centerCount) / total
        let rightPct = Double(rightCount) / total

        // Echo chamber if >70% comes from one side
        let maxSidePct = max(leftPct, rightPct)

        if maxSidePct > 0.7 {
            return maxSidePct
        } else if maxSidePct > 0.5 {
            return maxSidePct * 0.7
        } else {
            return 0.0
        }
    }

    // MARK: - Report Generation

    /// Generate weekly reading report
    func generateWeeklyReport() -> WeeklyReport {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weekRecords = readingHistory.filter { $0.timestamp >= weekAgo }

        let totalRead = weekRecords.count
        let totalTime = weekRecords.reduce(0.0) { $0 + $1.timeSpent }
        let averagePerDay = Double(totalRead) / 7.0

        // Category breakdown
        let categoryBreakdown = Dictionary(grouping: weekRecords) { $0.article.category }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .map { CategoryCount(category: $0.key, count: $0.value) }

        // Source breakdown
        let sourceBreakdown = Dictionary(grouping: weekRecords) { $0.article.source.name }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { SourceCount(source: $0.key, count: $0.value) }

        // Reading patterns by time of day
        let hourlyBreakdown = Dictionary(grouping: weekRecords) { record in
            Calendar.current.component(.hour, from: record.timestamp)
        }
        .mapValues { $0.count }

        let peakReadingHour = hourlyBreakdown.max { $0.value < $1.value }?.key ?? 12

        // Bias exposure for the week
        let weekBiasMetrics = calculateBiasMetrics(for: weekRecords)

        let report = WeeklyReport(
            startDate: weekAgo,
            endDate: Date(),
            articlesRead: totalRead,
            totalReadingTime: totalTime,
            averageArticlesPerDay: averagePerDay,
            categoryBreakdown: categoryBreakdown,
            topSources: Array(sourceBreakdown),
            peakReadingHour: peakReadingHour,
            biasMetrics: weekBiasMetrics,
            streakDays: currentStreak
        )

        weeklyReport = report
        return report
    }

    /// Generate monthly reading report
    func generateMonthlyReport() -> MonthlyReport {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let monthRecords = readingHistory.filter { $0.timestamp >= monthAgo }

        let totalRead = monthRecords.count
        let totalTime = monthRecords.reduce(0.0) { $0 + $1.timeSpent }
        let averagePerDay = Double(totalRead) / 30.0

        // Category breakdown
        let categoryBreakdown = Dictionary(grouping: monthRecords) { $0.article.category }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .map { CategoryCount(category: $0.key, count: $0.value) }

        // Source breakdown
        let sourceBreakdown = Dictionary(grouping: monthRecords) { $0.article.source.name }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { SourceCount(source: $0.key, count: $0.value) }

        // Reading trends (week by week)
        let weeksInMonth = 4
        var weeklyTrends: [Int] = []
        for week in 0..<weeksInMonth {
            let weekStart = Calendar.current.date(byAdding: .day, value: -7 * week, to: Date())!
            let weekEnd = Calendar.current.date(byAdding: .day, value: -7 * (week + 1), to: Date())!
            let weekCount = monthRecords.filter { $0.timestamp >= weekEnd && $0.timestamp < weekStart }.count
            weeklyTrends.insert(weekCount, at: 0)
        }

        // Bias exposure for the month
        let monthBiasMetrics = calculateBiasMetrics(for: monthRecords)

        let report = MonthlyReport(
            startDate: monthAgo,
            endDate: Date(),
            articlesRead: totalRead,
            totalReadingTime: totalTime,
            averageArticlesPerDay: averagePerDay,
            categoryBreakdown: categoryBreakdown,
            topSources: Array(sourceBreakdown),
            weeklyTrends: weeklyTrends,
            biasMetrics: monthBiasMetrics,
            longestStreak: longestStreak
        )

        monthlyReport = report
        return report
    }

    /// Calculate bias metrics for a set of records
    private func calculateBiasMetrics(for records: [ReadingRecord]) -> BiasExposureMetrics? {
        guard !records.isEmpty else { return nil }

        var leftCount = 0
        var centerCount = 0
        var rightCount = 0
        var unknownCount = 0
        var biasSum: Double = 0.0
        var biasValues: [Double] = []

        for record in records {
            if let bias = record.article.bias {
                let value = bias.spectrum.value
                biasValues.append(value)
                biasSum += value

                if value < -0.3 {
                    leftCount += 1
                } else if value > 0.3 {
                    rightCount += 1
                } else {
                    centerCount += 1
                }
            } else {
                unknownCount += 1
            }
        }

        let total = records.count
        let averageBias = biasValues.isEmpty ? 0.0 : biasSum / Double(biasValues.count)

        let variance = biasValues.isEmpty ? 0.0 : biasValues.reduce(0.0) { sum, value in
            sum + pow(value - averageBias, 2)
        } / Double(biasValues.count)
        let standardDeviation = sqrt(variance)
        let diversityScore = min(standardDeviation / 0.5, 1.0)

        let echoScore = calculateEchoChamberScore(
            leftCount: leftCount,
            centerCount: centerCount,
            rightCount: rightCount
        )

        return BiasExposureMetrics(
            leftPercentage: Double(leftCount) / Double(total) * 100,
            centerPercentage: Double(centerCount) / Double(total) * 100,
            rightPercentage: Double(rightCount) / Double(total) * 100,
            unknownPercentage: Double(unknownCount) / Double(total) * 100,
            averageBias: averageBias,
            diversityScore: diversityScore,
            echoScore: echoScore,
            sampleSize: total
        )
    }

    /// Check if it's time to generate reports
    private func checkForReportGeneration() {
        // Generate weekly report on Sundays
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())

        if weekday == 1 && weeklyReport == nil { // Sunday
            _ = generateWeeklyReport()
        }

        // Generate monthly report on the 1st of the month
        let day = calendar.component(.day, from: Date())
        if day == 1 && monthlyReport == nil {
            _ = generateMonthlyReport()
        }
    }

    // MARK: - Statistics

    /// Get reading statistics for a time period
    func statistics(for period: TimePeriod) -> ReadingStatistics {
        let startDate = period.startDate
        let records = readingHistory.filter { $0.timestamp >= startDate }

        let totalRead = records.count
        let totalTime = records.reduce(0.0) { $0 + $1.timeSpent }
        let averageTime = totalTime / Double(max(totalRead, 1))

        let categoryCounts = Dictionary(grouping: records) { $0.article.category }
            .mapValues { $0.count }

        let sourceCounts = Dictionary(grouping: records) { $0.article.source.name }
            .mapValues { $0.count }

        let favoriteCategory = categoryCounts.max { $0.value < $1.value }?.key
        let topSource = sourceCounts.max { $0.value < $1.value }?.key

        return ReadingStatistics(
            period: period,
            articlesRead: totalRead,
            totalReadingTime: totalTime,
            averageReadingTime: averageTime,
            categoryCounts: categoryCounts,
            sourceCounts: sourceCounts,
            favoriteCategory: favoriteCategory,
            topSource: topSource
        )
    }

    // MARK: - Persistence

    private func saveAnalytics() {
        let data = AnalyticsData(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalArticlesRead: totalArticlesRead,
            totalReadingTime: totalReadingTime,
            lastReadDate: lastReadDate
        )

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: analyticsFileURL)
        } catch {
            print("Failed to save analytics: \(error)")
        }
    }

    private func loadAnalytics() {
        guard FileManager.default.fileExists(atPath: analyticsFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: analyticsFileURL)
            let analyticsData = try JSONDecoder().decode(AnalyticsData.self, from: data)

            currentStreak = analyticsData.currentStreak
            longestStreak = analyticsData.longestStreak
            totalArticlesRead = analyticsData.totalArticlesRead
            totalReadingTime = analyticsData.totalReadingTime
            lastReadDate = analyticsData.lastReadDate
        } catch {
            print("Failed to load analytics: \(error)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(readingHistory)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save reading history: \(error)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: historyFileURL)
            readingHistory = try JSONDecoder().decode([ReadingRecord].self, from: data)
        } catch {
            print("Failed to load reading history: \(error)")
        }
    }
}

// MARK: - Reading Record

/// Individual reading event record
struct ReadingRecord: Identifiable, Codable {
    let id: UUID
    let article: NewsArticle
    let timeSpent: TimeInterval
    let timestamp: Date

    init(
        id: UUID = UUID(),
        article: NewsArticle,
        timeSpent: TimeInterval,
        timestamp: Date
    ) {
        self.id = id
        self.article = article
        self.timeSpent = timeSpent
        self.timestamp = timestamp
    }
}

// MARK: - Bias Exposure Metrics

/// Metrics showing bias exposure in reading habits
struct BiasExposureMetrics: Codable {
    let leftPercentage: Double
    let centerPercentage: Double
    let rightPercentage: Double
    let unknownPercentage: Double
    let averageBias: Double          // -1.0 (left) to +1.0 (right)
    let diversityScore: Double       // 0.0 (echo chamber) to 1.0 (diverse)
    let echoScore: Double            // 0.0 (diverse) to 1.0 (echo chamber)
    let sampleSize: Int

    var isBalanced: Bool {
        diversityScore > 0.5
    }

    var recommendation: String {
        if echoScore > 0.7 {
            return "Your reading is heavily concentrated on one side. Try exploring different perspectives!"
        } else if echoScore > 0.4 {
            return "Your reading leans toward one perspective. Consider balancing with other viewpoints."
        } else if diversityScore > 0.7 {
            return "Excellent! You're reading from diverse sources across the political spectrum."
        } else {
            return "Good balance. Keep exploring different perspectives to stay informed."
        }
    }
}

// MARK: - Echo Chamber Status

enum EchoChamberStatus {
    case high
    case moderate
    case low
    case insufficient

    var description: String {
        switch self {
        case .high:
            return "High Risk"
        case .moderate:
            return "Moderate Risk"
        case .low:
            return "Low Risk"
        case .insufficient:
            return "Not Enough Data"
        }
    }

    var color: Color {
        switch self {
        case .high:
            return .red
        case .moderate:
            return .orange
        case .low:
            return .green
        case .insufficient:
            return .gray
        }
    }
}

// MARK: - Weekly Report

/// Weekly reading activity report
struct WeeklyReport: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let articlesRead: Int
    let totalReadingTime: TimeInterval
    let averageArticlesPerDay: Double
    let categoryBreakdown: [CategoryCount]
    let topSources: [SourceCount]
    let peakReadingHour: Int
    let biasMetrics: BiasExposureMetrics?
    let streakDays: Int

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        articlesRead: Int,
        totalReadingTime: TimeInterval,
        averageArticlesPerDay: Double,
        categoryBreakdown: [CategoryCount],
        topSources: [SourceCount],
        peakReadingHour: Int,
        biasMetrics: BiasExposureMetrics?,
        streakDays: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.articlesRead = articlesRead
        self.totalReadingTime = totalReadingTime
        self.averageArticlesPerDay = averageArticlesPerDay
        self.categoryBreakdown = categoryBreakdown
        self.topSources = topSources
        self.peakReadingHour = peakReadingHour
        self.biasMetrics = biasMetrics
        self.streakDays = streakDays
    }

    var formattedReadingTime: String {
        let hours = Int(totalReadingTime / 3600)
        let minutes = Int((totalReadingTime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Monthly Report

/// Monthly reading activity report
struct MonthlyReport: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let articlesRead: Int
    let totalReadingTime: TimeInterval
    let averageArticlesPerDay: Double
    let categoryBreakdown: [CategoryCount]
    let topSources: [SourceCount]
    let weeklyTrends: [Int]
    let biasMetrics: BiasExposureMetrics?
    let longestStreak: Int

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        articlesRead: Int,
        totalReadingTime: TimeInterval,
        averageArticlesPerDay: Double,
        categoryBreakdown: [CategoryCount],
        topSources: [SourceCount],
        weeklyTrends: [Int],
        biasMetrics: BiasExposureMetrics?,
        longestStreak: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.articlesRead = articlesRead
        self.totalReadingTime = totalReadingTime
        self.averageArticlesPerDay = averageArticlesPerDay
        self.categoryBreakdown = categoryBreakdown
        self.topSources = topSources
        self.weeklyTrends = weeklyTrends
        self.biasMetrics = biasMetrics
        self.longestStreak = longestStreak
    }

    var formattedReadingTime: String {
        let hours = Int(totalReadingTime / 3600)
        let minutes = Int((totalReadingTime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Category Count

struct CategoryCount: Codable {
    let category: NewsCategory
    let count: Int
}

// MARK: - Source Count

struct SourceCount: Codable {
    let source: String
    let count: Int
}

// MARK: - Reading Statistics

/// Reading statistics for a time period
struct ReadingStatistics {
    let period: TimePeriod
    let articlesRead: Int
    let totalReadingTime: TimeInterval
    let averageReadingTime: TimeInterval
    let categoryCounts: [NewsCategory: Int]
    let sourceCounts: [String: Int]
    let favoriteCategory: NewsCategory?
    let topSource: String?

    var formattedTotalTime: String {
        let hours = Int(totalReadingTime / 3600)
        let minutes = Int((totalReadingTime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    var formattedAverageTime: String {
        let minutes = Int(averageReadingTime / 60)
        let seconds = Int(averageReadingTime.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Time Period

enum TimePeriod {
    case today
    case week
    case month
    case year
    case all

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)!
        case .all:
            return Date(timeIntervalSince1970: 0)
        }
    }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .all: return "All Time"
        }
    }
}

// MARK: - Analytics Data (for persistence)

private struct AnalyticsData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalArticlesRead: Int
    let totalReadingTime: TimeInterval
    let lastReadDate: Date?
}
