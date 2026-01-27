import Foundation
import UserNotifications

//
//  SmartNotificationManager.swift
//  News Summary
//
//  Intelligent notification system for breaking news
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class SmartNotificationManager: ObservableObject {

    static let shared = SmartNotificationManager()

    @Published var notificationsEnabled = false
    @Published var notificationPreferences = NotificationPreferences()

    private init() {
        loadPreferences()
        requestAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            Task { @MainActor in
                self.notificationsEnabled = granted
                if let error = error {
                    print("❌ Notification authorization error: \(error)")
                }
            }
        }
    }

    // MARK: - Send Notifications

    func notifyBreakingNews(_ article: NewsArticle) async {
        guard notificationsEnabled else { return }
        guard notificationPreferences.breakingNewsEnabled else { return }

        // Check priority
        let priority = calculatePriority(article)
        guard priority >= notificationPreferences.minimumPriority else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚨 Breaking News"
        content.subtitle = article.source?.name ?? "News Update"
        content.body = article.title ?? "New development"
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadCount())
        content.categoryIdentifier = "breaking_news"
        content.userInfo = [
            "articleURL": article.link ?? "",
            "category": article.category?.rawValue ?? "",
            "priority": priority.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: article.id.uuidString,
            content: content,
            trigger: nil // Immediate
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func notifyDailyDigest(_ articles: [NewsArticle]) async {
        guard notificationsEnabled else { return }
        guard notificationPreferences.dailyDigestEnabled else { return }

        let topStories = articles.prefix(5)
        let headlines = topStories.compactMap { $0.title }.joined(separator: "\n• ")

        let content = UNMutableNotificationContent()
        content.title = "📰 Your Daily News Digest"
        content.subtitle = "\(topStories.count) top stories"
        content.body = "• " + headlines
        content.sound = .default
        content.categoryIdentifier = "daily_digest"

        // Schedule for preference time
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: notificationPreferences.digestTime,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "daily_digest",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Priority Calculation

    private func calculatePriority(_ article: NewsArticle) -> NotificationPriority {
        var score = 0.0

        // Source credibility (higher = more priority)
        if let credibility = article.source?.credibilityScore {
            score += credibility / 100.0 * 30.0
        }

        // Recency (newer = higher priority)
        if let published = article.publishedDate {
            let age = Date().timeIntervalSince(published) / 3600.0 // Hours
            if age < 1 {
                score += 30.0
            } else if age < 6 {
                score += 20.0
            } else if age < 24 {
                score += 10.0
            }
        }

        // Category importance
        switch article.category {
        case .us, .world:
            score += 20.0
        case .business, .technology:
            score += 10.0
        default:
            score += 5.0
        }

        // Determine priority level
        if score >= 70 {
            return .critical
        } else if score >= 50 {
            return .high
        } else if score >= 30 {
            return .medium
        } else {
            return .low
        }
    }

    private func getUnreadCount() async -> Int {
        // Count unread articles from NewsEngine
        let newsEngine = await NewsEngine.shared
        let allArticles = await newsEngine.articles.values.flatMap { $0 }
        let unreadArticles = allArticles.filter { article in
            // Articles are unread if not in read history
            !UserDefaults.standard.bool(forKey: "article_read_\(article.id.uuidString)")
        }
        return unreadArticles.count
    }

    // MARK: - Preferences

    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "NotificationPreferences"),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            notificationPreferences = prefs
        }
    }

    func savePreferences() {
        if let data = try? JSONEncoder().encode(notificationPreferences) {
            UserDefaults.standard.set(data, forKey: "NotificationPreferences")
        }
    }
}

// MARK: - Models

enum NotificationPriority: String, Codable, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        let order: [NotificationPriority] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

struct NotificationPreferences: Codable {
    var breakingNewsEnabled = true
    var dailyDigestEnabled = true
    var minimumPriority: NotificationPriority = .high
    var digestTime = DateComponents(hour: 7, minute: 0) // 7am
    var doNotDisturbStart = DateComponents(hour: 22, minute: 0) // 10pm
    var doNotDisturbEnd = DateComponents(hour: 7, minute: 0) // 7am
    var categories: Set<String> = [] // Empty = all categories
    var mutedSources: Set<String> = []

    func isInDoNotDisturb() -> Bool {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        guard let currentHour = now.hour, let startHour = doNotDisturbStart.hour, let endHour = doNotDisturbEnd.hour else {
            return false
        }

        if startHour < endHour {
            return currentHour >= startHour && currentHour < endHour
        } else {
            return currentHour >= startHour || currentHour < endHour
        }
    }
}
