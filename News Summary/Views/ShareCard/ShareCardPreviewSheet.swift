//
//  ShareCardPreviewSheet.swift
//  News Summary
//
//  Preview and export modal for share card images
//  Supports copy-to-clipboard and save-as-PNG
//  Created by Jordan Koch on 2026-02-24
//

import SwiftUI

struct ShareCardPreviewSheet: View {
    let article: NewsArticle?
    let storyGroup: StoryGroup?
    let perspective: ShareCardPerspective?
    @Environment(\.dismiss) var dismiss

    @State private var generatedImage: NSImage?
    @State private var isGenerating = true
    @State private var isCopied = false

    private let generator = ShareCardGenerator()

    init(article: NewsArticle) {
        self.article = article
        self.storyGroup = nil
        self.perspective = nil
    }

    init(storyGroup: StoryGroup, perspective: ShareCardPerspective? = nil) {
        self.article = nil
        self.storyGroup = storyGroup
        self.perspective = perspective
    }

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                sheetHeader

                Rectangle()
                    .fill(ModernColors.glassBorder)
                    .frame(height: 1)

                // Card preview
                if isGenerating {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ModernColors.cyan))
                            .scaleEffect(1.5)
                        Text("Generating share card...")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(ModernColors.textSecondary)
                        Spacer()
                    }
                } else if let image = generatedImage {
                    ScrollView {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(20)
                            .shadow(color: .black.opacity(0.4), radius: 20)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("Failed to generate share card")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(ModernColors.textSecondary)
                        Spacer()
                    }
                }

                Rectangle()
                    .fill(ModernColors.glassBorder)
                    .frame(height: 1)

                // Action buttons
                actionBar
            }
        }
        .frame(width: 700, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ModernColors.purple.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: ModernColors.purple.opacity(0.15), radius: 20)
        .onAppear(perform: generateCard)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHARE BIAS CARD")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.purple)

                Text("1200 x 630 — optimized for social media")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ModernColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button("Close") { dismiss() }
                .buttonStyle(ModernButtonStyle(color: ModernColors.textSecondary, style: .glass))

            Spacer()

            Button(action: copyCard) {
                Label(
                    isCopied ? "Copied" : "Copy to Clipboard",
                    systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }
            .buttonStyle(ModernButtonStyle(
                color: isCopied ? ModernColors.accentGreen : ModernColors.cyan,
                style: isCopied ? .filled : .outlined
            ))
            .disabled(generatedImage == nil)

            Button(action: saveCard) {
                Label("Save as PNG", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.purple, style: .filled))
            .disabled(generatedImage == nil)
        }
        .padding()
    }

    // MARK: - Logic

    private func generateCard() {
        Task {
            if let storyGroup = storyGroup {
                generatedImage = generator.generateStoryCard(
                    storyGroup: storyGroup,
                    perspective: perspective
                )
            } else if let article = article {
                generatedImage = generator.generateArticleCard(article: article)
            }
            isGenerating = false
        }
    }

    private func copyCard() {
        guard let image = generatedImage else { return }
        generator.copyToClipboard(image)
        isCopied = true

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }

    private func saveCard() {
        guard let image = generatedImage else { return }
        let name: String
        if let article = article {
            name = "bias-card-\(article.title.prefix(30).replacingOccurrences(of: " ", with: "-").lowercased())"
        } else {
            name = "bias-card-story-\(Date().formatted(.iso8601.year().month().day()))"
        }
        generator.saveToFile(image, defaultName: name)
    }
}
