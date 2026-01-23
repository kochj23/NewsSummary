//
//  ArticleFeedView.swift
//  News Summary
//
//  Scrollable feed of news articles
//  Created by Jordan Koch on 2026-01-23
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
        .background(Color.black)
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
                    .foregroundColor(.orange)

                Text("Same Story - \(group.sourceCount) Sources")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Spacer()

                Text(group.biasDistribution)
                    .font(.caption2)
                    .foregroundColor(.gray)
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
                        .font(.caption)
                        .foregroundColor(.gray)

                    ForEach(group.articles.dropFirst().prefix(3), id: \.id) { article in
                        Button(action: {
                            onSelectArticle(article)
                        }) {
                            HStack(spacing: 4) {
                                BiasIndicatorView(bias: article.source.bias)
                                Text(article.source.name)
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    if group.articles.count > 4 {
                        Text("+\(group.articles.count - 4) more")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 2)
                )
        )
    }
}
