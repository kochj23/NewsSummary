//
//  ArticleCard.swift
//  News Summary
//
//  Individual article card with image, headline, summary, bias indicator
//  Created by Jordan Koch on 2026-01-23
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
                            .cornerRadius(8)
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
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // AI Summary or RSS description
                if let summary = article.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.8))
                        .lineLimit(2)
                } else if let description = article.rssDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                // Footer: source, bias, time
                HStack(spacing: 12) {
                    // Bias indicator
                    BiasIndicatorView(bias: article.source.bias)

                    // Source name
                    Text(article.source.name)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))

                    // Credibility
                    Text("●")
                        .foregroundColor(credibilityColor)
                    Text("\(article.source.credibility)")
                        .font(.caption2)
                        .foregroundColor(credibilityColor)

                    Spacer()

                    // Time ago
                    Text(article.timeAgoString)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                // Read status
                if article.isRead {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("Read")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(article.isRead ? Color.white.opacity(0.03) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(article.category.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 150, height: 100)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }

    private var credibilityColor: Color {
        let cred = article.source.credibility
        if cred >= 90 { return .green }
        if cred >= 75 { return .yellow }
        if cred >= 60 { return .orange }
        return .red
    }
}
