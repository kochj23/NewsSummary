//
//  ContentView.swift
//  News Summary
//
//  Main dashboard with category tabs and article feed
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var newsEngine: NewsEngine
    @State private var selectedArticle: NewsArticle?

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

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

                Divider()
                    .background(Color.cyan)

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
    }

    private var headerView: some View {
        HStack {
            Text("📰 NEWS SUMMARY")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)

            Spacer()

            // AI indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)

                Text("AI Ready")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)

            if newsEngine.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            }

            Button("Refresh") {
                Task {
                    await newsEngine.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding()
        .background(Color.black)
    }
}

/// Loading view
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(2.0)

            Text(message)
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(NewsEngine())
}
