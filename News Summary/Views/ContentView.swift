//
//  ContentView.swift
//  News Summary
//
//  Main dashboard with category tabs and article feed
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var newsEngine: NewsEngine
    @State private var selectedArticle: NewsArticle?
    @State private var showCustomSources = false

    var body: some View {
        ZStack {
            // Glassmorphic background
            GlassmorphicBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                // Breaking news banner
                if !newsEngine.breakingNews.isEmpty {
                    BreakingNewsBanner(articles: newsEngine.breakingNews)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Category tabs
                CategoryTabView(
                    selectedCategory: $newsEngine.selectedCategory,
                    articleCounts: newsEngine.articles.mapValues { $0.count },
                    onSelectCategory: { category in
                        newsEngine.selectCategory(category)
                    }
                )
                .padding(.top, 8)

                // Subtle divider
                Rectangle()
                    .fill(ModernColors.glassBorder)
                    .frame(height: 1)

                // Article feed
                if newsEngine.isLoading {
                    LoadingView(message: newsEngine.loadingProgress)
                } else {
                    ArticleFeedView(
                        articles: newsEngine.currentArticles,
                        storyGroups: newsEngine.storyGroups,
                        onSelectArticle: { article in
                            selectedArticle = article
                        }
                    )
                }
            }
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article, newsEngine: newsEngine)
        }
        .sheet(isPresented: $showCustomSources) {
            CustomSourcesView()
        }
    }

    private var headerView: some View {
        HStack {
            Text("NEWS SUMMARY")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.cyan)

            Spacer()

            // AI indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(ModernColors.accentGreen)
                    .frame(width: 10, height: 10)
                    .shadow(color: ModernColors.accentGreen.opacity(0.6), radius: 4)

                Text("AI Ready")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.accentGreen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .compactGlassCard(cornerRadius: 8)

            if newsEngine.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ModernColors.cyan))
            }

            Button(action: { showCustomSources = true }) {
                Label("Sources", systemImage: "plus.circle")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.purple, style: .glass))

            Button("Refresh") {
                Task {
                    await newsEngine.refresh()
                }
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .filled))
        }
        .padding()
    }
}

/// Loading view with glassmorphic styling
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ModernColors.cyan))
                .scaleEffect(2.0)

            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(NewsEngine())
}
