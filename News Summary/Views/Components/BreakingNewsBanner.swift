//
//  BreakingNewsBanner.swift
//  News Summary
//
//  Alert banner for breaking news with glassmorphic design
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
//

import SwiftUI

struct BreakingNewsBanner: View {
    let articles: [NewsArticle]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernColors.accentRed)
                    .shadow(color: ModernColors.accentRed.opacity(0.5), radius: 4)

                Text("BREAKING NEWS")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Spacer()

                Text("\(articles.count) \(articles.count == 1 ? "story" : "stories")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }

            ForEach(articles.prefix(3)) { article in
                HStack(spacing: 8) {
                    Circle()
                        .fill(ModernColors.accentRed)
                        .frame(width: 6, height: 6)
                        .shadow(color: ModernColors.accentRed.opacity(0.5), radius: 2)

                    Text(article.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)
                        .lineLimit(1)

                    Spacer()
                }
            }

            if articles.count > 3 {
                Text("+\(articles.count - 3) more breaking stories")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
        .padding()
        .compactGlassCard(cornerRadius: 16, borderColor: ModernColors.accentRed.opacity(0.4))
    }
}
