//
//  NewsSummaryApp.swift
//  News Summary
//
//  Main app entry point
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

@main
struct NewsSummaryApp: App {
    @StateObject private var newsEngine = NewsEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(newsEngine)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
