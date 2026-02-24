//
//  ArticleBiasShareCardView.swift
//  News Summary
//
//  Single-article bias share card
//  1200x630 social-media-optimized image card
//  Created by Jordan Koch on 2026-02-24
//

import SwiftUI

struct ArticleBiasShareCardView: View {
    let article: NewsArticle

    var body: some View {
        ZStack {
            // Static gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.18),
                    Color(red: 0.10, green: 0.15, blue: 0.28),
                    Color(red: 0.08, green: 0.12, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative accents
            Circle()
                .fill(article.category.color.opacity(0.08))
                .frame(width: 350, height: 350)
                .offset(x: -400, y: -180)
                .blur(radius: 60)

            Circle()
                .fill(article.source.bias.color.opacity(0.06))
                .frame(width: 280, height: 280)
                .offset(x: 420, y: 160)
                .blur(radius: 50)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                cardHeader
                    .padding(.horizontal, 40)
                    .padding(.top, 32)

                // Bias spectrum
                biasSection
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                // Key points or summary
                contentSection
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                Spacer()

                // Footer
                cardFooter
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 1200, height: 630)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEWS SUMMARY")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .tracking(2)

                Spacer()

                // Category
                HStack(spacing: 4) {
                    Image(systemName: article.category.icon)
                        .font(.system(size: 10))
                    Text(article.category.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(article.category.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(article.category.color.opacity(0.15))
                .cornerRadius(6)
            }

            Text(article.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                // Source
                HStack(spacing: 4) {
                    Circle()
                        .fill(article.source.bias.color)
                        .frame(width: 10, height: 10)
                    Text(article.source.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Bias label
                Text(article.source.bias.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(article.source.bias.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(article.source.bias.color.opacity(0.15))
                    .cornerRadius(4)

                // Credibility
                Text("Credibility: \(article.source.credibility)%")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Text(article.publishedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Bias Section

    private var biasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Labels
            HStack {
                Text("FAR LEFT")
                    .foregroundColor(.blue)
                Spacer()
                Text("CENTER")
                    .foregroundColor(.gray)
                Spacer()
                Text("FAR RIGHT")
                    .foregroundColor(.red)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))

            // Spectrum bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 10)

                    // Gradient
                    LinearGradient(
                        colors: [.blue, .purple.opacity(0.5), .gray, .purple.opacity(0.5), .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 10)
                    .cornerRadius(5)
                    .opacity(0.4)

                    // Source indicator
                    let position = (article.source.bias.value + 2.0) / 4.0
                    Circle()
                        .fill(article.source.bias.color)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: article.source.bias.color.opacity(0.8), radius: 6)
                        .offset(x: geometry.size.width * position - 11, y: -6)
                }
            }
            .frame(height: 22)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let keyPoints = article.keyPoints, !keyPoints.isEmpty {
                Text("KEY POINTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)

                ForEach(keyPoints.prefix(4), id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)

                        Text(point)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if let summary = article.fullSummary ?? article.summary {
                Text("AI SUMMARY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)

                Text(summary)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let description = article.rssDescription {
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var cardFooter: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                Text("News Summary")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.cyan)
            }

            Spacer()

            Text("See the full picture. Read beyond the headline.")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .italic()
        }
    }
}
