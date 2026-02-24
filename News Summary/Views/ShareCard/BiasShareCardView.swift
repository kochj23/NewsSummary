//
//  BiasShareCardView.swift
//  News Summary
//
//  Multi-perspective share card for story groups
//  1200x630 social-media-optimized image card with bias analysis
//  Created by Jordan Koch on 2026-02-24
//

import SwiftUI

struct BiasShareCardView: View {
    let storyGroup: StoryGroup
    let perspective: ShareCardPerspective?

    private var article: NewsArticle { storyGroup.representativeArticle }

    var body: some View {
        ZStack {
            // Static gradient background (no blur materials — ImageRenderer can't render them)
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.18),
                    Color(red: 0.10, green: 0.15, blue: 0.28),
                    Color(red: 0.08, green: 0.12, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative gradient circles
            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 300, height: 300)
                .offset(x: -450, y: -200)
                .blur(radius: 60)

            Circle()
                .fill(Color.purple.opacity(0.06))
                .frame(width: 250, height: 250)
                .offset(x: 400, y: 150)
                .blur(radius: 50)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                biasSpectrumSection
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                if let perspective = perspective {
                    perspectiveColumns(perspective)
                        .padding(.horizontal, 32)
                        .padding(.top, 14)
                } else {
                    sourceBreakdown
                        .padding(.horizontal, 32)
                        .padding(.top, 14)
                }

                Spacer()

                cardFooter
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 1200, height: 630)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NEWS SUMMARY")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .tracking(2)

                Spacer()

                // Category badge
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

                // Source count badge
                Text("\(storyGroup.articles.count) sources")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }

            Text(article.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(article.publishedDate.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Bias Spectrum

    private var biasSpectrumSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Spectrum labels
            HStack {
                Text("LEFT")
                    .foregroundColor(.blue)
                Spacer()
                Text("CENTER")
                    .foregroundColor(.gray)
                Spacer()
                Text("RIGHT")
                    .foregroundColor(.red)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))

            // Spectrum bar with source dots
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Gradient
                    LinearGradient(
                        colors: [.blue, .purple.opacity(0.5), .gray, .purple.opacity(0.5), .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 8)
                    .cornerRadius(4)
                    .opacity(0.4)

                    // Source dots
                    ForEach(storyGroup.articles, id: \.id) { art in
                        let biasValue = art.source.bias.value
                        let position = (biasValue + 2.0) / 4.0
                        Circle()
                            .fill(art.source.bias.color)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 1.5)
                            )
                            .shadow(color: art.source.bias.color.opacity(0.6), radius: 3)
                            .offset(x: geometry.size.width * position - 7, y: -3)
                    }
                }
            }
            .frame(height: 14)

            // Source names below spectrum
            HStack(spacing: 8) {
                ForEach(storyGroup.articles.prefix(6), id: \.id) { art in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(art.source.bias.color)
                            .frame(width: 6, height: 6)
                        Text(art.source.name)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                if storyGroup.articles.count > 6 {
                    Text("+\(storyGroup.articles.count - 6) more")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Perspective Columns (when AI analysis available)

    private func perspectiveColumns(_ perspective: ShareCardPerspective) -> some View {
        HStack(alignment: .top, spacing: 10) {
            perspectiveBox(
                label: "LEFT",
                color: .blue,
                text: perspective.leftPerspective,
                sources: storyGroup.articles.filter { $0.source.bias.value < -0.3 }
            )

            perspectiveBox(
                label: "CENTER",
                color: .gray,
                text: perspective.centerPerspective,
                sources: storyGroup.articles.filter { abs($0.source.bias.value) <= 0.3 }
            )

            perspectiveBox(
                label: "RIGHT",
                color: .red,
                text: perspective.rightPerspective,
                sources: storyGroup.articles.filter { $0.source.bias.value > 0.3 }
            )
        }
    }

    private func perspectiveBox(label: String, color: Color, text: String, sources: [NewsArticle]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .tracking(1)
            }

            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            if !sources.isEmpty {
                Text(sources.map { $0.source.name }.prefix(3).joined(separator: ", "))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Source Breakdown (fallback when no AI analysis)

    private var sourceBreakdown: some View {
        let left = storyGroup.articles.filter { $0.source.bias.value < -0.3 }
        let center = storyGroup.articles.filter { abs($0.source.bias.value) <= 0.3 }
        let right = storyGroup.articles.filter { $0.source.bias.value > 0.3 }

        return VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE COVERAGE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)

            HStack(spacing: 16) {
                coverageColumn("Left", count: left.count, color: .blue, sources: left)
                coverageColumn("Center", count: center.count, color: .gray, sources: center)
                coverageColumn("Right", count: right.count, color: .red, sources: right)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func coverageColumn(_ label: String, count: Int, color: Color, sources: [NewsArticle]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("\(label) (\(count))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }

            ForEach(sources.prefix(3), id: \.id) { art in
                Text(art.source.name)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
