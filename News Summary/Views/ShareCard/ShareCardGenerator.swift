//
//  ShareCardGenerator.swift
//  News Summary
//
//  Renders SwiftUI share card views to images using ImageRenderer
//  Supports clipboard copy and file save
//  Created by Jordan Koch on 2026-02-24
//

import SwiftUI
import AppKit

// MARK: - Share Card Perspective Data

/// Lightweight perspective data for share cards
/// Independent of the AI engine's PerspectiveAnalysis to avoid compile dependencies
struct ShareCardPerspective {
    let leftPerspective: String
    let centerPerspective: String
    let rightPerspective: String
    let sharedFacts: [String]
    let keyDifferences: [String]
}

// MARK: - Share Card Generator

@MainActor
class ShareCardGenerator {

    /// Generate a share card image for a multi-source story group
    func generateStoryCard(storyGroup: StoryGroup, perspective: ShareCardPerspective?) -> NSImage? {
        let cardView = BiasShareCardView(storyGroup: storyGroup, perspective: perspective)
        return renderToImage(cardView, width: 1200, height: 630)
    }

    /// Generate a share card image for a single article
    func generateArticleCard(article: NewsArticle) -> NSImage? {
        let cardView = ArticleBiasShareCardView(article: article)
        return renderToImage(cardView, width: 1200, height: 630)
    }

    /// Render any SwiftUI view to an NSImage at 2x scale
    private func renderToImage<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else {
            print("❌ ShareCardGenerator: Failed to render image")
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    /// Copy image to system clipboard
    func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        print("📋 Share card copied to clipboard")
    }

    /// Save image to file via NSSavePanel
    func saveToFile(_ image: NSImage, defaultName: String = "news-bias-card") {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("❌ ShareCardGenerator: Failed to convert image to PNG")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(defaultName).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try pngData.write(to: url)
                    print("💾 Share card saved to \(url.path)")
                } catch {
                    print("❌ ShareCardGenerator: Failed to save - \(error.localizedDescription)")
                }
            }
        }
    }
}
