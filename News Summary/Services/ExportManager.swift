import Foundation
import PDFKit
import AppKit

//
//  ExportManager.swift
//  News Summary
//
//  Export articles and collections to PDF, Markdown, and other formats
//  Author: Jordan Koch
//  Date: 2026-01-26
//

class ExportManager {

    static let shared = ExportManager()

    private init() {}

    // MARK: - Export to PDF

    func exportToPDF(article: NewsArticle) async throws -> Data {
        let html = generateHTML(for: article)
        return try generatePDF(from: html, title: article.title ?? "Article")
    }

    func exportCollectionToPDF(articles: [NewsArticle], collectionName: String) async throws -> Data {
        let html = generateCollectionHTML(articles: articles, title: collectionName)
        return try generatePDF(from: html, title: collectionName)
    }

    private func generatePDF(from html: String, title: String) throws -> Data {
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 612, height: 792) // US Letter
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72

        guard let htmlData = html.data(using: .utf8) else {
            throw ExportError.invalidHTML
        }

        let attributedString = try NSAttributedString(
            data: htmlData,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )

        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData)!

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPDFPage(nil)
        attributedString.draw(in: mediaBox.insetBy(dx: 72, dy: 72))
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return pdfData as Data
    }

    // MARK: - Export to Markdown

    func exportToMarkdown(article: NewsArticle) -> String {
        var markdown = ""

        // Title
        if let title = article.title {
            markdown += "# \(title)\n\n"
        }

        // Metadata
        markdown += "**Source:** \(article.source?.name ?? "Unknown")\n"
        if let bias = article.source?.bias {
            markdown += "**Bias:** \(bias.rawValue)\n"
        }
        if let credibility = article.source?.credibilityScore {
            markdown += "**Credibility:** \(credibility)%\n"
        }
        if let published = article.publishedDate {
            markdown += "**Published:** \(published.formatted())\n"
        }
        if let category = article.category {
            markdown += "**Category:** \(category.displayName)\n"
        }
        markdown += "\n---\n\n"

        // Reading time and difficulty
        markdown += "⏱️ **Reading Time:** \(article.formattedReadingTime)\n"
        markdown += "\(article.readingDifficulty.icon) **Difficulty:** \(article.readingDifficulty.rawValue)\n\n"

        // Summary
        if let summary = article.aiSummary {
            markdown += "## AI Summary\n\n"
            markdown += "\(summary)\n\n"
        }

        // Content
        if let description = article.articleDescription {
            markdown += "## Description\n\n"
            markdown += "\(description)\n\n"
        }

        if let content = article.content {
            markdown += "## Full Article\n\n"
            markdown += "\(content)\n\n"
        }

        // Link
        if let link = article.link {
            markdown += "## Source\n\n"
            markdown += "[\(article.source?.name ?? "Read Full Article")](\(link))\n\n"
        }

        // Footer
        markdown += "---\n\n"
        markdown += "*Exported from News Summary by Jordan Koch*\n"
        markdown += "*\(Date().formatted())*\n"

        return markdown
    }

    func exportCollectionToMarkdown(articles: [NewsArticle], collectionName: String) -> String {
        var markdown = "# \(collectionName)\n\n"
        markdown += "**Exported:** \(Date().formatted())\n"
        markdown += "**Articles:** \(articles.count)\n\n"
        markdown += "---\n\n"

        for (index, article) in articles.enumerated() {
            markdown += "## \(index + 1). \(article.title ?? "Untitled")\n\n"
            markdown += "**Source:** \(article.source?.name ?? "Unknown") "
            markdown += "(\(article.source?.bias.rawValue ?? "Unknown") - \(article.source?.credibilityScore ?? 0)%)\n"
            markdown += "⏱️ \(article.formattedReadingTime) | "
            markdown += "\(article.readingDifficulty.icon) \(article.readingDifficulty.rawValue)\n\n"

            if let summary = article.aiSummary {
                markdown += "\(summary)\n\n"
            } else if let description = article.articleDescription {
                markdown += "\(description)\n\n"
            }

            if let link = article.link {
                markdown += "[Read Full Article](\(link))\n\n"
            }

            markdown += "---\n\n"
        }

        markdown += "*Exported from News Summary by Jordan Koch*\n"
        return markdown
    }

    // MARK: - Export to Plain Text

    func exportToText(article: NewsArticle) -> String {
        var text = ""

        if let title = article.title {
            text += "\(title)\n"
            text += String(repeating: "=", count: title.count) + "\n\n"
        }

        text += "Source: \(article.source?.name ?? "Unknown")\n"
        text += "Reading Time: \(article.formattedReadingTime)\n"
        text += "Difficulty: \(article.readingDifficulty.rawValue)\n\n"

        if let summary = article.aiSummary {
            text += "AI Summary:\n\(summary)\n\n"
        }

        if let content = article.content ?? article.articleDescription {
            text += "\(content)\n\n"
        }

        if let link = article.link {
            text += "Read more: \(link)\n"
        }

        return text
    }

    // MARK: - Save to File

    func saveToFile(_ data: Data, filename: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }

    func saveTextToFile(_ text: String, filename: String) {
        guard let data = text.data(using: .utf8) else { return }
        saveToFile(data, filename: filename)
    }

    // MARK: - HTML Generation

    private func generateHTML(for article: NewsArticle) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(article.title ?? "Article")</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    max-width: 800px;
                    margin: 40px auto;
                    padding: 0 20px;
                    color: #333;
                }
                h1 {
                    font-size: 32px;
                    margin-bottom: 10px;
                    color: #1a1a1a;
                }
                .metadata {
                    color: #666;
                    font-size: 14px;
                    margin-bottom: 30px;
                    padding-bottom: 20px;
                    border-bottom: 1px solid #e0e0e0;
                }
                .summary {
                    background: #e3f2fd;
                    padding: 20px;
                    border-left: 4px solid #2196f3;
                    margin: 30px 0;
                }
                .content {
                    font-size: 16px;
                    line-height: 1.8;
                }
                .footer {
                    margin-top: 40px;
                    padding-top: 20px;
                    border-top: 1px solid #e0e0e0;
                    color: #999;
                    font-size: 12px;
                }
            </style>
        </head>
        <body>
            <h1>\(article.title ?? "Untitled")</h1>

            <div class="metadata">
                <strong>Source:</strong> \(article.source?.name ?? "Unknown")
                (\(article.source?.bias.rawValue ?? "Unknown") - Credibility: \(article.source?.credibilityScore ?? 0)%)<br>
                <strong>Published:</strong> \(article.publishedDate?.formatted() ?? "Unknown")<br>
                <strong>Category:</strong> \(article.category?.displayName ?? "Unknown")<br>
                <strong>Reading Time:</strong> \(article.formattedReadingTime)<br>
                <strong>Difficulty:</strong> \(article.readingDifficulty.rawValue)
            </div>

            \(article.aiSummary.map { """
            <div class="summary">
                <strong>AI Summary:</strong><br>
                \($0)
            </div>
            """ } ?? "")

            <div class="content">
                \(article.content ?? article.articleDescription ?? "No content available")
            </div>

            \(article.link.map { """
            <p><a href="\($0)">Read Full Article</a></p>
            """ } ?? "")

            <div class="footer">
                Exported from News Summary by Jordan Koch<br>
                \(Date().formatted())
            </div>
        </body>
        </html>
        """
    }

    private func generateCollectionHTML(articles: [NewsArticle], title: String) -> String {
        let articlesHTML = articles.enumerated().map { index, article in
            """
            <div class="article">
                <h2>\(index + 1). \(article.title ?? "Untitled")</h2>
                <p class="metadata">
                    <strong>\(article.source?.name ?? "Unknown")</strong>
                    (\(article.source?.bias.rawValue ?? "Unknown") - \(article.source?.credibilityScore ?? 0)%) |
                    \(article.formattedReadingTime) |
                    \(article.readingDifficulty.rawValue)
                </p>
                <p>\(article.aiSummary ?? article.articleDescription ?? "")</p>
                \(article.link.map { "<p><a href=\"\($0)\">Read Full Article</a></p>" } ?? "")
            </div>
            <hr>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(title)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    max-width: 900px;
                    margin: 40px auto;
                    padding: 0 20px;
                }
                h1 {
                    font-size: 36px;
                    margin-bottom: 30px;
                }
                .article {
                    margin-bottom: 40px;
                }
                .metadata {
                    color: #666;
                    font-size: 14px;
                }
                hr {
                    border: none;
                    border-top: 1px solid #e0e0e0;
                    margin: 40px 0;
                }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <p><strong>Articles:</strong> \(articles.count) | <strong>Exported:</strong> \(Date().formatted())</p>
            <hr>
            \(articlesHTML)
            <p style="color: #999; font-size: 12px; margin-top: 60px;">
                Exported from News Summary by Jordan Koch
            </p>
        </body>
        </html>
        """
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case invalidHTML
    case pdfGenerationFailed
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidHTML:
            return "Failed to generate HTML content"
        case .pdfGenerationFailed:
            return "Failed to create PDF document"
        case .noContent:
            return "No content available to export"
        }
    }
}
