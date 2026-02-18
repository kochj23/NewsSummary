//
//  ArticleCard.swift
//  News Summary
//
//  Individual article card with glassmorphic design
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
//

import SwiftUI

struct ArticleCard: View {
    let article: NewsArticle

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail image
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 100)
                            .clipped()
                            .cornerRadius(12)
                    case .failure, .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(article.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // AI Summary or RSS description
                if let summary = article.summary {
                    Text(summary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(ModernColors.cyan.opacity(0.8))
                        .lineLimit(2)
                } else if let description = article.rssDescription {
                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(ModernColors.textSecondary)
                        .lineLimit(2)
                }

                // Footer: source, bias, time
                HStack(spacing: 12) {
                    // Bias indicator
                    BiasIndicatorView(bias: article.source.bias)

                    // Source name
                    Text(article.source.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.textSecondary)

                    // Credibility
                    Text("\(article.source.credibility)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.credibilityColor(article.source.credibility))

                    Spacer()

                    // Time ago
                    Text(article.timeAgoString)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(ModernColors.textTertiary)
                }

                // Read status
                if article.isRead {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ModernColors.accentGreen)
                        Text("Read")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(ModernColors.accentGreen)
                    }
                }
            }
        }
        .padding()
        .compactGlassCard(
            cornerRadius: 16,
            borderColor: article.isRead
                ? ModernColors.glassBorder
                : article.category.color.opacity(0.3)
        )
        .opacity(article.isRead ? 0.75 : 1.0)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(ModernColors.glassBackground)
            .frame(width: 150, height: 100)
            .overlay(
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(ModernColors.textTertiary)
            )
    }
}
