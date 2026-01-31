//
//  NewsMenuBarAgent.swift
//  News Summary
//
//  Menu Bar Agent for quick access to breaking news and top headlines
//  Author: Jordan Koch
//  Date: 2026-01-31
//

import SwiftUI
import AppKit
import UserNotifications

// MARK: - Menu Bar Agent

@MainActor
class NewsMenuBarAgent: ObservableObject {
    static let shared = NewsMenuBarAgent()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var refreshTimer: Timer?

    @Published var breakingNewsCount: Int = 0
    @Published var topHeadlines: [(title: String, source: String, url: URL)] = []
    @Published var unreadCount: Int = 0
    @Published var lastRefreshTime: Date?
    @Published var isRefreshing: Bool = false

    private init() {}

    // MARK: - Setup

    /// Initialize menu bar item
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set icon
        button.image = NSImage(systemSymbolName: "newspaper.fill", accessibilityDescription: "News Summary")
        button.imagePosition = .imageLeading

        // Create menu
        menu = NSMenu()
        statusItem?.menu = menu

        updateMenu()

        // Start periodic refresh (every 15 minutes)
        startPeriodicRefresh()

        print("📰 News menu bar agent initialized")
    }

    /// Update status based on current news data
    func updateStatus(breaking: Int, unread: Int, headlines: [(title: String, source: String, url: URL)]) {
        self.breakingNewsCount = breaking
        self.unreadCount = unread
        self.topHeadlines = Array(headlines.prefix(5))

        // Update button title
        if breaking > 0 {
            statusItem?.button?.title = "\(breaking)"
            statusItem?.button?.image = NSImage(systemSymbolName: "newspaper.fill", accessibilityDescription: "Breaking News")
        } else {
            statusItem?.button?.title = ""
            statusItem?.button?.image = NSImage(systemSymbolName: "newspaper", accessibilityDescription: "News Summary")
        }

        updateMenu()
    }

    // MARK: - Menu Management

    private func updateMenu() {
        guard let menu = menu else { return }

        menu.removeAllItems()

        // Header
        let headerItem = NSMenuItem()
        headerItem.title = "News Summary"
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Breaking news badge
        if breakingNewsCount > 0 {
            let breakingItem = NSMenuItem()
            breakingItem.title = "🚨 \(breakingNewsCount) Breaking \(breakingNewsCount == 1 ? "Story" : "Stories")"
            breakingItem.isEnabled = false
            menu.addItem(breakingItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Top headlines
        if !topHeadlines.isEmpty {
            let headlinesLabel = NSMenuItem()
            headlinesLabel.title = "Top Headlines"
            headlinesLabel.isEnabled = false
            menu.addItem(headlinesLabel)

            for (index, headline) in topHeadlines.enumerated() {
                let item = NSMenuItem(
                    title: truncate(headline.title, maxLength: 60),
                    action: #selector(openHeadline(_:)),
                    keyEquivalent: String(index + 1)
                )
                item.target = self
                item.representedObject = headline.url
                item.toolTip = "\(headline.source): \(headline.title)"

                // Add submenu with source info
                let sourceItem = NSMenuItem()
                sourceItem.title = "  📰 \(headline.source)"
                sourceItem.isEnabled = false

                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        } else {
            let noNewsItem = NSMenuItem()
            noNewsItem.title = "No headlines available"
            noNewsItem.isEnabled = false
            menu.addItem(noNewsItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Unread count
        if unreadCount > 0 {
            let unreadItem = NSMenuItem()
            unreadItem.title = "📬 \(unreadCount) unread articles"
            unreadItem.isEnabled = false
            menu.addItem(unreadItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Actions
        let refreshItem = NSMenuItem(title: "Refresh News", action: #selector(triggerRefresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing
        menu.addItem(refreshItem)

        if isRefreshing {
            let refreshingItem = NSMenuItem()
            refreshingItem.title = "  ↻ Refreshing..."
            refreshingItem.isEnabled = false
            menu.addItem(refreshingItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Open main app
        let openAppItem = NSMenuItem(title: "Open News Summary", action: #selector(showMainWindow), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(NSMenuItem.separator())

        // Last refresh time
        if let lastRefresh = lastRefreshTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let timeAgo = formatter.localizedString(for: lastRefresh, relativeTo: Date())

            let lastRefreshItem = NSMenuItem()
            lastRefreshItem.title = "Updated \(timeAgo)"
            lastRefreshItem.isEnabled = false
            menu.addItem(lastRefreshItem)

            menu.addItem(NSMenuItem.separator())
        }

        // Quit
        let quitItem = NSMenuItem(title: "Quit News Summary", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func openHeadline(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func triggerRefresh() {
        NotificationCenter.default.post(name: .newsMenuBarRefresh, object: nil)
    }

    @objc private func showMainWindow() {
        NotificationCenter.default.post(name: .newsMenuBarShowWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Periodic Refresh

    private func startPeriodicRefresh() {
        stopPeriodicRefresh()

        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerRefresh()
            }
        }
    }

    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Notifications

    /// Show breaking news notification
    func notifyBreakingNews(title: String, source: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Breaking News"
        content.subtitle = source
        content.body = title
        content.sound = .default
        content.categoryIdentifier = "breaking_news"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            }
        }

        // Flash the menu bar icon
        flashIcon()
    }

    private func flashIcon() {
        guard let button = statusItem?.button else { return }
        let originalImage = button.image

        // Flash with alert icon
        button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Alert")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            button.image = originalImage
        }
    }

    // MARK: - Helpers

    private func truncate(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        }
        return String(string.prefix(maxLength - 3)) + "..."
    }

    /// Remove menu bar item
    func teardown() {
        stopPeriodicRefresh()

        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menu = nil

        print("📰 News menu bar agent removed")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newsMenuBarRefresh = Notification.Name("newsMenuBarRefresh")
    static let newsMenuBarShowWindow = Notification.Name("newsMenuBarShowWindow")
}
