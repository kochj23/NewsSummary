//
//  ArticleDetailView.swift
//  News Summary
//
//  Full article viewer with AI summary and bias information
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    @ObservedObject var newsEngine: NewsEngine
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(article.category.color)
                .frame(height: 2)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // AI Summary
                    if let summary = article.fullSummary {
                        summarySection(summary)
                    } else if let description = article.rssDescription {
                        descriptionSection(description)
                    }

                    // Key points
                    if let keyPoints = article.keyPoints {
                        keyPointsSection(keyPoints)
                    }

                    // Full article content (if scraped)
                    if let content = article.scrapedContent {
                        fullContentSection(content)
                    }

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .background(Color.black)
        }
        .frame(width: 900, height: 700)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(article.category.color, lineWidth: 3)
        )
        .onAppear {
            // Mark as read
            newsEngine.markAsRead(articleId: article.id)
        }
    }

    // MARK: - Sub Views

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row
            HStack {
                // Source info
                HStack(spacing: 8) {
                    BiasIndicatorView(bias: article.source.bias)

                    Text(article.source.name)
                        .font(.body)
                        .foregroundColor(.cyan)

                    Text("●")
                        .foregroundColor(credibilityColor)

                    Text("\(article.source.credibility)")
                        .font(.caption)
                        .foregroundColor(credibilityColor)
                }

                Spacer()

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            // Title
            Text(article.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Date and category
            HStack {
                Text(formatFullDate(article.publishedDate))
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("●")
                    .foregroundColor(.gray.opacity(0.5))

                HStack(spacing: 4) {
                    Image(systemName: article.category.icon)
                        .font(.caption2)
                    Text(article.category.displayName)
                        .font(.caption)
                }
                .foregroundColor(article.category.color)

                Spacer()
            }

            // Bias spectrum bar (if bias detected)
            if let bias = article.bias {
                BiasSpectrumBar(
                    bias: bias.spectrum,
                    confidence: bias.confidence
                )
            }
        }
        .padding()
        .background(Color.black)
    }

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cyan)

                Text("AI SUMMARY")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(summary)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan, lineWidth: 1)
                )
        )
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESCRIPTION")
                .font(.headline)
                .foregroundColor(.white)

            Text(description)
                .font(.body)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func keyPointsSection(_ keyPoints: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.orange)

                Text("KEY POINTS")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ForEach(keyPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(point)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 1)
                )
        )
    }

    private func fullContentSection(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FULL ARTICLE")
                .font(.headline)
                .foregroundColor(.white)

            Text(content.prefix(2000))
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            if content.count > 2000 {
                Text("[Article truncated for display]")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                openURL(article.url)
            }) {
                Label("Read Full Article", systemImage: "safari")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.cyan)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: {
                newsEngine.toggleFavorite(articleId: article.id)
            }) {
                Label(article.isFavorite ? "Favorited" : "Favorite",
                      systemImage: article.isFavorite ? "star.fill" : "star")
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(article.isFavorite ? .yellow : .white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Utilities

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var credibilityColor: Color {
        let cred = article.source.credibility
        if cred >= 90 { return .green }
        if cred >= 75 { return .yellow }
        if cred >= 60 { return .orange }
        return .red
    }
}

/// Simple bias spectrum bar
struct BiasSpectrumBar: View {
    let bias: BiasSpectrum
    let confidence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Political Bias: \(bias.rawValue) (\(Int(confidence * 100))% confidence)")
                .font(.caption)
                .foregroundColor(.white)

            // Visual spectrum
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)

                    // Gradient overlay
                    LinearGradient(
                        colors: [.blue, .purple, .gray, .purple, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 8)
                    .cornerRadius(4)
                    .opacity(0.5)

                    // Indicator
                    let position = (bias.value + 2.0) / 4.0  // Normalize -2 to +2 → 0 to 1
                    Circle()
                        .fill(bias.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: geometry.size.width * position - 10, y: -6)
                }
            }
            .frame(height: 20)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
