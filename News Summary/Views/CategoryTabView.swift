//
//  CategoryTabView.swift
//  News Summary
//
//  Horizontal category selector tabs with glassmorphic styling
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
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
    }
}

/// Individual category tab with glassmorphic design
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
                    .foregroundColor(isSelected ? category.color : ModernColors.textTertiary)
                    .shadow(color: isSelected ? category.color.opacity(0.5) : .clear, radius: 4)

                Text(category.displayName.uppercased())
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? ModernColors.textPrimary : ModernColors.textTertiary)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? category.color : ModernColors.textTertiary)
                }
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? category.color.opacity(0.15) : ModernColors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(isSelected ? 0.9 : 0.7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? category.color.opacity(0.5) : ModernColors.glassBorder,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: isSelected ? category.color.opacity(0.2) : .clear, radius: 6)
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
