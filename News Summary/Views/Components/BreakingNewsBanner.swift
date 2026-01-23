//
//  BreakingNewsBanner.swift
//  News Summary
//
//  Alert banner for breaking news
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct BreakingNewsBanner: View {
    let articles: [NewsArticle]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)

                Text("BREAKING NEWS")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Text("\(articles.count) \(articles.count == 1 ? "story" : "stories")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            ForEach(articles.prefix(3)) { article in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)

                    Text(article.title)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()
                }
            }

            if articles.count > 3 {
                Text("+\(articles.count - 3) more breaking stories")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 2)
                )
        )
    }
}
