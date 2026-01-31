import Foundation
import WebKit
import Observation

//
//  ArticleScraperService.swift
//  News Summary
//
//  Web scraping service to extract full article content
//  Author: Jordan Koch
//  Date: 2026-01-26
//  Updated: 2026-01-31 - Migrated to @Observable (Swift 5.9+)
//

/// Article scraper using the modern @Observable macro
///
/// **Migration from ObservableObject:**
/// - Replaced `ObservableObject` protocol with `@Observable` macro
/// - Removed `@Published` property wrappers
/// - Already uses async/await (modern concurrency)
///
/// **Requirements:** macOS 14+, iOS 17+, tvOS 17+
@Observable
@MainActor
final class ArticleScraperService {

    static let shared = ArticleScraperService()

    var isScraping = false
    private var scrapedContent: [String: String] = [:] // URL -> content cache

    private init() {}

    // MARK: - Scrape Article

    func scrapeArticle(url: URL) async throws -> String {

        // Check cache first
        let cacheKey = url.absoluteString
        if let cached = scrapedContent[cacheKey] {
            return cached
        }

        isScraping = true
        defer { isScraping = false }

        // Download HTML
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.invalidHTML
        }

        // Extract article content using multiple strategies
        let content = extractArticleContent(from: html, url: url)

        // Cache result
        scrapedContent[cacheKey] = content

        return content
    }

    // MARK: - Content Extraction

    private func extractArticleContent(from html: String, url: URL) -> String {

        // Strategy 1: Look for common article content patterns
        if let content = extractFromArticleTag(html) {
            return content
        }

        // Strategy 2: Look for main content div
        if let content = extractFromMainContent(html) {
            return content
        }

        // Strategy 3: Look for common CMS patterns (WordPress, etc.)
        if let content = extractFromCommonCMS(html) {
            return content
        }

        // Strategy 4: Extract all paragraph text (fallback)
        return extractAllParagraphs(html)
    }

    private func extractFromArticleTag(_ html: String) -> String? {
        // Look for <article> tag
        guard let articleRange = html.range(of: "<article[^>]*>", options: .regularExpression),
              let closeRange = html.range(of: "</article>", options: [], range: articleRange.upperBound..<html.endIndex) else {
            return nil
        }

        let articleHTML = String(html[articleRange.upperBound..<closeRange.lowerBound])
        return stripHTMLTags(articleHTML)
    }

    private func extractFromMainContent(_ html: String) -> String? {
        // Look for main content divs
        let patterns = [
            #"<div[^>]*class="[^"]*article-content[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*class="[^"]*content[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*id="article"[^>]*>(.*?)</div>"#,
            #"<main[^>]*>(.*?)</main>"#
        ]

        for pattern in patterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let content = String(html[match])
                return stripHTMLTags(content)
            }
        }

        return nil
    }

    private func extractFromCommonCMS(_ html: String) -> String? {
        // WordPress, Medium, Substack patterns
        let patterns = [
            #"<div[^>]*class="[^"]*entry-content[^"]*"[^>]*>(.*?)</div>"#,
            #"<div[^>]*class="[^"]*post-content[^"]*"[^>]*>(.*?)</div>"#,
            #"<article[^>]*class="[^"]*post[^"]*"[^>]*>(.*?)</article>"#
        ]

        for pattern in patterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let content = String(html[match])
                return stripHTMLTags(content)
            }
        }

        return nil
    }

    private func extractAllParagraphs(_ html: String) -> String {
        // Extract all <p> tags as fallback
        let pattern = #"<p[^>]*>(.*?)</p>"#
        var paragraphs: [String] = []

        var searchRange = html.startIndex..<html.endIndex

        while let match = html.range(of: pattern, options: .regularExpression, range: searchRange) {
            let paragraph = String(html[match])
            let cleaned = stripHTMLTags(paragraph)

            // Filter out navigation, ads, etc. (short paragraphs)
            if cleaned.count > 50 {
                paragraphs.append(cleaned)
            }

            searchRange = match.upperBound..<html.endIndex
        }

        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - HTML Cleaning

    private func stripHTMLTags(_ html: String) -> String {
        var text = html

        // Remove script and style tags entirely
        text = text.replacingOccurrences(of: #"<script[^>]*>.*?</script>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<style[^>]*>.*?</style>"#, with: "", options: .regularExpression)

        // Remove HTML comments
        text = text.replacingOccurrences(of: #"<!--.*?-->"#, with: "", options: .regularExpression)

        // Remove all HTML tags
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Clean up whitespace
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text

        // Common HTML entities
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": """,
            "&ldquo;": """
        ]

        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }

        // Decode numeric entities
        decoded = decoded.replacingOccurrences(of: #"&#(\d+);"#, with: "", options: .regularExpression)

        return decoded
    }

    // MARK: - Clear Cache

    func clearCache(olderThan days: Int) {
        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))

        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        for case let fileURL as URL in enumerator {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let modifiedDate = attributes[.modificationDate] as? Date,
               modifiedDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        // Cache size recalculated
    }
}

// MARK: - Disk Cache Extension

extension DiskCache {

    func cacheURL(forKey key: String) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? String(key.hashValue)
        return cacheDirectory.appendingPathComponent(filename).appendingPathExtension("jpg")
    }

    func calculateCacheSize() {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return
        }

        var totalSize: Int64 = 0
        var count = 0

        for case let fileURL as URL in enumerator {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
                count += 1
            }
        }

        currentSize = totalSize
        imageCount = count
    }
}

// MARK: - Models

struct CacheStatistics {
    let memoryCacheCount: Int
    let diskCacheSize: Int64
    let diskCacheCount: Int
    let maxDiskSize: Int64

    var diskCacheSizeMB: Double {
        Double(diskCacheSize) / 1_000_000.0
    }

    var maxDiskSizeMB: Double {
        Double(maxDiskSize) / 1_000_000.0
    }

    var percentageFull: Double {
        guard maxDiskSize > 0 else { return 0 }
        return Double(diskCacheSize) / Double(maxDiskSize) * 100.0
    }
}

enum ScraperError: LocalizedError {
    case invalidHTML
    case noContentFound
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidHTML:
            return "Failed to parse HTML content"
        case .noContentFound:
            return "No article content found on page"
        case .downloadFailed:
            return "Failed to download article"
        }
    }
}
