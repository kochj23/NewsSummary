//
//  NewsEngine.swift
//  News Summary
//
//  Main orchestrator for news aggregation, AI summarization, and bias detection
//  Created by Jordan Koch on 2026-01-23
//

import Foundation
import Combine

@MainActor
class NewsEngine: ObservableObject {
    @Published var articles: [NewsCategory: [NewsArticle]] = [:]
    @Published var selectedCategory: NewsCategory = .us
    @Published var isLoading = false
    @Published var loadingProgress: String = ""
    @Published var breakingNews: [NewsArticle] = []
    @Published var storyGroups: [StoryGroup] = []

    // User preferences
    @Published var userLocation: (city: String, state: String)? = nil

    private let aggregator = NewsAggregator()
    let ai = AIBackendManager.shared  // Public for ContentView AI indicator

    init() {
        // Load initial news
        Task {
            await refresh()
        }
    }

    /// Refresh news for all categories
    func refresh() async {
        isLoading = true
        loadingProgress = "Fetching news from 40+ sources..."

        // Fetch all categories
        let allArticles = await aggregator.fetchAllCategories(userLocation: userLocation)

        await MainActor.run {
            self.articles = allArticles
            self.loadingProgress = "Processing articles..."
        }

        // Find breaking news (from US category)
        if let usArticles = allArticles[.us] {
            let breaking = usArticles.filter { $0.isRecent }.prefix(5)
            await MainActor.run {
                self.breakingNews = Array(breaking)
            }
        }

        // Group similar stories (for current category)
        if let categoryArticles = allArticles[selectedCategory] {
            let groups = aggregator.groupSimilarStories(categoryArticles)
            await MainActor.run {
                self.storyGroups = groups
            }
        }

        await MainActor.run {
            self.isLoading = false
            self.loadingProgress = ""
        }

        print("✅ Refresh complete: \(allArticles.values.flatMap { $0 }.count) total articles")
    }

    /// Refresh single category
    func refreshCategory(_ category: NewsCategory) async {
        isLoading = true

        let categoryArticles = await aggregator.fetchArticles(for: category, userLocation: userLocation)

        await MainActor.run {
            self.articles[category] = categoryArticles
            self.isLoading = false
        }

        // Group stories for this category
        let groups = aggregator.groupSimilarStories(categoryArticles)
        await MainActor.run {
            self.storyGroups = groups
        }
    }

    /// Switch to different category
    func selectCategory(_ category: NewsCategory) {
        selectedCategory = category

        // Fetch if not cached
        if articles[category] == nil || articles[category]?.isEmpty == true {
            Task {
                await refreshCategory(category)
            }
        } else {
            // Update story groups for this category
            if let categoryArticles = articles[category] {
                storyGroups = aggregator.groupSimilarStories(categoryArticles)
            }
        }
    }

    /// Get articles for current category
    var currentArticles: [NewsArticle] {
        articles[selectedCategory] ?? []
    }

    /// Mark article as read
    func markAsRead(articleId: UUID) {
        for category in articles.keys {
            if let index = articles[category]?.firstIndex(where: { $0.id == articleId }) {
                articles[category]?[index].isRead = true
                articles[category]?[index].readAt = Date()
            }
        }
    }

    /// Toggle favorite
    func toggleFavorite(articleId: UUID) {
        for category in articles.keys {
            if let index = articles[category]?.firstIndex(where: { $0.id == articleId }) {
                articles[category]?[index].isFavorite.toggle()
            }
        }
    }

    /// Get article count for category
    func articleCount(for category: NewsCategory) -> Int {
        articles[category]?.count ?? 0
    }

    /// Get unread count for category
    func unreadCount(for category: NewsCategory) -> Int {
        articles[category]?.filter { !$0.isRead }.count ?? 0
    }
}
