//
//  ArticleFeedView.swift
//  News Summary
//
//  Scrollable feed of news articles with glassmorphic design
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
//

import SwiftUI

struct ArticleFeedView: View {
    let articles: [NewsArticle]
    let storyGroups: [StoryGroup]
    let onSelectArticle: (NewsArticle) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Story groups first (multiple sources for same story)
                ForEach(storyGroups) { group in
                    StoryGroupCard(group: group, onSelectArticle: onSelectArticle)
                }

                // Individual articles
                ForEach(articles.filter { article in
                    // Don't show if already in a group
                    !storyGroups.contains(where: { group in
                        group.articles.contains(where: { $0.id == article.id })
                    })
                }) { article in
                    ArticleCard(article: article)
                        .onTapGesture {
                            onSelectArticle(article)
                        }
                }
            }
            .padding()
        }
    }
}

/// Story group card showing multiple sources
struct StoryGroupCard: View {
    let group: StoryGroup
    let onSelectArticle: (NewsArticle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(ModernColors.orange)
                    .shadow(color: ModernColors.orange.opacity(0.4), radius: 3)

                Text("Same Story - \(group.sourceCount) Sources")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.orange)

                Spacer()

                Text(group.biasDistribution)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }

            // Representative article
            ArticleCard(article: group.representativeArticle)
                .onTapGesture {
                    onSelectArticle(group.representativeArticle)
                }

            // Other sources
            if group.articles.count > 1 {
                HStack(spacing: 8) {
                    Text("Also on:")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)

                    ForEach(group.articles.dropFirst().prefix(3), id: \.id) { article in
                        Button(action: {
                            onSelectArticle(article)
                        }) {
                            HStack(spacing: 4) {
                                BiasIndicatorView(bias: article.source.bias)
                                Text(article.source.name)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(ModernColors.cyan)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .compactGlassCard(cornerRadius: 8)
                        }
                        .buttonStyle(.plain)
                    }

                    if group.articles.count > 4 {
                        Text("+\(group.articles.count - 4) more")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }
            }
        }
        .padding()
        .compactGlassCard(cornerRadius: 20, borderColor: ModernColors.orange.opacity(0.4))
    }
}
