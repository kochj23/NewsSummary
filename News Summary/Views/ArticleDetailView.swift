//
//  ArticleDetailView.swift
//  News Summary
//
//  Full article viewer with AI summary and bias information
//  Glassmorphic design matching TopGUI/RsyncGUI
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
//

import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    @ObservedObject var newsEngine: NewsEngine
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var showShareCard = false

    var body: some View {
        ZStack {
            // Glassmorphic background
            GlassmorphicBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                // Category color accent line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [article.category.color, article.category.color.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .shadow(color: article.category.color.opacity(0.5), radius: 4)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
            }
        }
        .frame(width: 900, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(article.category.color.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: article.category.color.opacity(0.2), radius: 20)
        .onAppear {
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
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(ModernColors.cyan)

                    Text("\(article.source.credibility)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.credibilityColor(article.source.credibility))
                }

                Spacer()

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ModernColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Title
            Text(article.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Date and category
            HStack {
                Text(formatFullDate(article.publishedDate))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)

                HStack(spacing: 4) {
                    Image(systemName: article.category.icon)
                        .font(.system(size: 11))
                    Text(article.category.displayName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(article.category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .compactGlassCard(cornerRadius: 6, borderColor: article.category.color.opacity(0.3))

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
    }

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(ModernColors.cyan)
                    .shadow(color: ModernColors.cyan.opacity(0.4), radius: 3)

                Text("AI SUMMARY")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
            }

            Text(summary)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(ModernColors.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .compactGlassCard(cornerRadius: 16, borderColor: ModernColors.cyan.opacity(0.3))
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESCRIPTION")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)

            Text(description)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .compactGlassCard(cornerRadius: 16)
    }

    private func keyPointsSection(_ keyPoints: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(ModernColors.orange)
                    .shadow(color: ModernColors.orange.opacity(0.4), radius: 3)

                Text("KEY POINTS")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
            }

            ForEach(keyPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(ModernColors.orange)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                        .shadow(color: ModernColors.orange.opacity(0.4), radius: 2)

                    Text(point)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .compactGlassCard(cornerRadius: 16, borderColor: ModernColors.orange.opacity(0.3))
    }

    private func fullContentSection(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FULL ARTICLE")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)

            Text(content.prefix(2000))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(ModernColors.textPrimary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            if content.count > 2000 {
                Text("[Article truncated for display]")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
        .padding()
        .compactGlassCard(cornerRadius: 16)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                openURL(article.url)
            }) {
                Label("Read Full Article", systemImage: "safari")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .filled))

            Button(action: {
                newsEngine.toggleFavorite(articleId: article.id)
            }) {
                Label(article.isFavorite ? "Favorited" : "Favorite",
                      systemImage: article.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(ModernButtonStyle(
                color: article.isFavorite ? ModernColors.yellow : ModernColors.textSecondary,
                style: article.isFavorite ? .filled : .glass
            ))

            Button(action: { showShareCard = true }) {
                Label("Share Bias Card", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.purple, style: .glass))
            .sheet(isPresented: $showShareCard) {
                ShareCardPreviewSheet(article: article)
            }
        }
    }

    // MARK: - Utilities

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Bias spectrum bar with glassmorphic design
struct BiasSpectrumBar: View {
    let bias: BiasSpectrum
    let confidence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Political Bias: \(bias.rawValue) (\(Int(confidence * 100))% confidence)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            // Visual spectrum
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ModernColors.glassBackground)
                        .frame(height: 8)

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
                    let position = (bias.value + 2.0) / 4.0  // Normalize -2 to +2 -> 0 to 1
                    Circle()
                        .fill(bias.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: bias.color.opacity(0.5), radius: 4)
                        .offset(x: geometry.size.width * position - 10, y: -6)
                }
            }
            .frame(height: 20)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .compactGlassCard(cornerRadius: 10)
    }
}
