//
//  RSSParser.swift
//  News Summary
//
//  XMLParser-based RSS feed parsing for multiple formats
//  Supports standard RSS, Google News, Yahoo News variations
//  Created by Jordan Koch on 2026-01-23
//

import Foundation

class RSSParser: NSObject, XMLParserDelegate {

    // MARK: - Public API

    /// Parse RSS feed from URL
    func parseFeed(from url: URL, source: NewsSource) async -> [NewsArticle] {
        print("📡 Fetching RSS from \(source.name)...")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error for \(source.name)")
                return []
            }

            return parseFeedData(data, source: source)

        } catch {
            print("❌ Fetch error for \(source.name): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - XML Parsing

    private func parseFeedData(_ data: Data, source: NewsSource) -> [NewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self

        // Reset state
        currentElement = ""
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentPubDate = ""
        currentImageURL = ""
        articles = []
        isInItem = false
        self.currentSource = source

        parser.parse()

        print("✅ Parsed \(articles.count) articles from \(source.name)")
        return articles
    }

    // MARK: - XMLParserDelegate

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentImageURL = ""
    private var isInItem = false
    private var articles: [NewsArticle] = []
    private var currentSource: NewsSource?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {

        currentElement = elementName

        if elementName == "item" || elementName == "entry" {
            isInItem = true
            // Reset item data
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            currentImageURL = ""
        }

        // Extract image URL from media:content or enclosure
        if elementName == "media:content" || elementName == "enclosure" {
            if let url = attributeDict["url"], url.contains("http") {
                currentImageURL = url
            }
        }

        // Handle thumbnail tags
        if elementName == "media:thumbnail" {
            if let url = attributeDict["url"] {
                currentImageURL = url
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, isInItem else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link", "guid":
            if !currentLink.isEmpty { return }  // Keep first link
            currentLink += trimmed
        case "description", "summary", "content:encoded":
            currentDescription += trimmed
        case "pubDate", "published", "dc:date":
            currentPubDate += trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        if elementName == "item" || elementName == "entry" {
            isInItem = false

            // Create article from collected data
            guard !currentTitle.isEmpty, !currentLink.isEmpty,
                  let source = currentSource else {
                return
            }

            // Parse URL
            guard let articleURL = URL(string: currentLink) else {
                print("⚠️ Invalid URL: \(currentLink)")
                return
            }

            // Parse date
            let publishedDate = parseDate(currentPubDate) ?? Date()

            // Parse image URL
            var imageURL: URL? = nil
            if !currentImageURL.isEmpty {
                imageURL = URL(string: currentImageURL)
            }

            // Clean HTML from description
            let cleanDescription = stripHTML(currentDescription)

            let article = NewsArticle(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                url: articleURL,
                publishedDate: publishedDate,
                category: source.category,
                rssDescription: cleanDescription,
                imageURL: imageURL
            )

            articles.append(article)
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        print("📰 Finished parsing RSS document")
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("❌ XML parse error: \(parseError.localizedDescription)")
    }

    // MARK: - Utilities

    /// Parse various date formats from RSS feeds
    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            // RFC 822 (most common RSS format)
            createFormatter(format: "EEE, dd MMM yyyy HH:mm:ss Z"),
            // ISO 8601
            createFormatter(format: "yyyy-MM-dd'T'HH:mm:ssZ"),
            // Atom format
            createFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
            // Simple date
            createFormatter(format: "yyyy-MM-dd")
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private func createFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    /// Strip HTML tags from text
    private func stripHTML(_ html: String) -> String {
        var text = html

        // Remove scripts and styles
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove all HTML tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")

        // Clean up whitespace
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
