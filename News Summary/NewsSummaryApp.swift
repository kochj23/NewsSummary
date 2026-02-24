//
//  NewsSummaryApp.swift
//  News Summary
//
//  Main app entry point with Menu Bar Agent integration
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-01-31 - Added Menu Bar Agent
//

import SwiftUI
import UserNotifications
import WidgetKit

@main
struct NewsSummaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var newsEngine = NewsEngine()
    @StateObject private var menuBarAgent = NewsMenuBarAgent.shared
    @AppStorage("RunInMenuBarOnly") private var runInMenuBarOnly = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(newsEngine)
                .frame(minWidth: 1200, minHeight: 800)
                .onReceive(NotificationCenter.default.publisher(for: .newsMenuBarShowWindow)) { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onReceive(NotificationCenter.default.publisher(for: .newsMenuBarRefresh)) { _ in
                    Task {
                        await newsEngine.refresh()
                    }
                }
                .onChange(of: newsEngine.breakingNews) { _, newValue in
                    updateMenuBarStatus()
                }
                .onChange(of: newsEngine.articles) { _, _ in
                    updateMenuBarStatus()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .appSettings) {
                Toggle("Keep in Menu Bar When Closed", isOn: $runInMenuBarOnly)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(newsEngine)
        }
    }

    private func updateMenuBarStatus() {
        let breakingCount = newsEngine.breakingNews.count
        let unreadCount = newsEngine.articles.values.flatMap { $0 }.filter { !$0.isRead }.count
        let headlines = newsEngine.breakingNews.prefix(5).map { article in
            (title: article.title, source: article.source.name, url: article.url)
        }

        menuBarAgent.updateStatus(
            breaking: breakingCount,
            unread: unreadCount,
            headlines: Array(headlines)
        )
        menuBarAgent.lastRefreshTime = Date()

        // Push data to widgets
        updateWidgetData()
    }

    private func updateWidgetData() {
        let suiteName = "group.com.jordankoch.NewsSummary"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }

        // Push bias exposure data for BiasExposureWidget
        if let metrics = ReadingAnalytics.shared.biasExposureMetrics {
            let echoStatus = ReadingAnalytics.shared.detectEchoChamber()
            let biasData = BiasExposureWidgetData(
                diversityScore: metrics.diversityScore,
                echoStatus: echoStatus.description,
                leftPercentage: metrics.leftPercentage,
                centerPercentage: metrics.centerPercentage,
                rightPercentage: metrics.rightPercentage,
                averageBias: metrics.averageBias,
                articlesAnalyzed: metrics.sampleSize,
                recommendation: metrics.recommendation
            )
            if let encoded = try? JSONEncoder().encode(biasData) {
                userDefaults.set(encoded, forKey: "biasExposureData")
            }
        }

        // Push enhanced headline data with bias labels
        let widgetHeadlines = newsEngine.breakingNews.prefix(10).map { article in
            WidgetHeadlineData(
                id: article.id.uuidString,
                title: article.title,
                source: article.source.name,
                category: article.category.rawValue,
                publishedAt: article.publishedDate,
                imageURL: article.imageURL?.absoluteString,
                isBreaking: article.isBreakingNews,
                biasLabel: article.source.bias.shortLabel,
                biasColorHex: article.source.bias.hexColor
            )
        }

        let widgetData = WidgetBundleData(
            breakingNewsCount: newsEngine.breakingNews.count,
            topHeadlines: Array(widgetHeadlines),
            categoryCounts: newsEngine.articles.reduce(into: [String: Int]()) { $0[$1.key.rawValue] = $1.value.count },
            lastUpdated: Date()
        )

        if let encoded = try? JSONEncoder().encode(widgetData) {
            userDefaults.set(encoded, forKey: "widgetData")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Widget Data Models (main app side)

private struct BiasExposureWidgetData: Codable {
    let diversityScore: Double
    let echoStatus: String
    let leftPercentage: Double
    let centerPercentage: Double
    let rightPercentage: Double
    let averageBias: Double
    let articlesAnalyzed: Int
    let recommendation: String
}

private struct WidgetHeadlineData: Codable {
    let id: String
    let title: String
    let source: String
    let category: String
    let publishedAt: Date
    let imageURL: String?
    let isBreaking: Bool
    let biasLabel: String?
    let biasColorHex: String?
}

private struct WidgetBundleData: Codable {
    let breakingNewsCount: Int
    let topHeadlines: [WidgetHeadlineData]
    let categoryCounts: [String: Int]
    let lastUpdated: Date?
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force dark appearance for glassmorphic design
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Initialize menu bar agent
        Task { @MainActor in
            NewsMenuBarAgent.shared.setup()
        }

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("📬 Notification permissions granted")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            NewsMenuBarAgent.shared.teardown()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed (if enabled)
        return !UserDefaults.standard.bool(forKey: "RunInMenuBarOnly")
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap - open article if URL provided
        if let urlString = response.notification.request.content.userInfo["articleURL"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        completionHandler()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var newsEngine: NewsEngine
    @AppStorage("RunInMenuBarOnly") private var runInMenuBarOnly = false
    @ObservedObject private var sourceManager = CustomSourceManager.shared
    @State private var showCustomSources = false

    var body: some View {
        ZStack {
            ModernColors.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                // Menu Bar
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Keep running in menu bar when window closes", isOn: $runInMenuBarOnly)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)

                    Text("Access breaking news and top headlines from your menu bar")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)
                }
                .padding()
                .compactGlassCard(cornerRadius: 16)

                // Custom RSS Sources
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom RSS Sources")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(ModernColors.textPrimary)

                            Text("\(sourceManager.customSources.count) custom sources configured")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()

                        Button(action: { showCustomSources = true }) {
                            Label("Manage", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .outlined))
                    }
                }
                .padding()
                .compactGlassCard(cornerRadius: 16)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .sheet(isPresented: $showCustomSources) {
            CustomSourcesView()
        }
    }
}
