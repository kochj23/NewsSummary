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
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
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

// MARK: - Settings View (Placeholder)

struct SettingsView: View {
    @EnvironmentObject var newsEngine: NewsEngine
    @AppStorage("RunInMenuBarOnly") private var runInMenuBarOnly = false

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Keep running in menu bar when window closes", isOn: $runInMenuBarOnly)

                Text("Access breaking news and top headlines from your menu bar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
