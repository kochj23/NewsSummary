//
//  CategoryTabView.swift
//  News Summary
//
//  Horizontal category selector tabs
//  Created by Jordan Koch on 2026-01-23
//

import SwiftUI

struct CategoryTabView: View {
    @Binding var selectedCategory: NewsCategory
    let articleCounts: [NewsCategory: Int]
    let onSelectCategory: (NewsCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NewsCategory.allCases, id: \.self) { category in
                    CategoryTab(
                        category: category,
                        count: articleCounts[category] ?? 0,
                        isSelected: selectedCategory == category,
                        onTap: {
                            selectedCategory = category
                            onSelectCategory(category)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.black)
    }
}

/// Individual category tab
private struct CategoryTab: View {
    let category: NewsCategory
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? category.color : .gray)

                Text(category.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : .gray)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? category.color : .gray.opacity(0.7))
                }
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? category.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
