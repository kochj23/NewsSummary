import Foundation
import SwiftUI

//
//  BookmarkManager.swift
//  News Summary
//
//  Smart bookmarks system with notes, tags, collections, and highlighting
//  Supports organization, search, and export of saved articles
//  Author: Jordan Koch
//  Date: 2026-01-26
//

/// Comprehensive bookmark and collection management for saved articles
@MainActor
class BookmarkManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BookmarkManager()

    // MARK: - Published Properties

    @Published var bookmarks: [Bookmark] = []
    @Published var collections: [Collection] = []
    @Published var tags: Set<String> = []
    @Published var recentSearches: [String] = []

    // MARK: - Private Properties

    private let bookmarksFileURL: URL
    private let collectionsFileURL: URL
    private let tagsFileURL: URL

    // MARK: - Initialization

    private init() {
        // Setup file URLs for persistence
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("News Summary", isDirectory: true)

        // Create app directory if it doesn't exist
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        bookmarksFileURL = appDirectory.appendingPathComponent("bookmarks.json")
        collectionsFileURL = appDirectory.appendingPathComponent("collections.json")
        tagsFileURL = appDirectory.appendingPathComponent("tags.json")

        // Load existing data
        loadBookmarks()
        loadCollections()
        loadTags()
    }

    // MARK: - Bookmark Management

    /// Save an article as a bookmark with optional notes and tags
    func saveBookmark(article: NewsArticle, notes: String? = nil, tags: [String] = [], highlights: [Highlight] = []) {
        // Check if already bookmarked
        if let existingIndex = bookmarks.firstIndex(where: { $0.articleID == article.id }) {
            // Update existing bookmark
            var updatedBookmark = bookmarks[existingIndex]
            if let notes = notes {
                updatedBookmark.notes = notes
            }
            updatedBookmark.tags.formUnion(tags)
            updatedBookmark.highlights.append(contentsOf: highlights)
            updatedBookmark.lastModified = Date()
            bookmarks[existingIndex] = updatedBookmark
        } else {
            // Create new bookmark
            let bookmark = Bookmark(
                article: article,
                notes: notes,
                tags: Set(tags),
                highlights: highlights
            )
            bookmarks.insert(bookmark, at: 0)
        }

        // Update global tags
        self.tags.formUnion(tags)

        saveBookmarks()
        saveTags()
    }

    /// Remove a bookmark
    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }

    /// Update bookmark notes
    func updateNotes(for bookmark: Bookmark, notes: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].notes = notes
        bookmarks[index].lastModified = Date()
        saveBookmarks()
    }

    /// Add tags to a bookmark
    func addTags(to bookmark: Bookmark, tags: [String]) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].tags.formUnion(tags)
        bookmarks[index].lastModified = Date()
        self.tags.formUnion(tags)
        saveBookmarks()
        saveTags()
    }

    /// Remove tags from a bookmark
    func removeTags(from bookmark: Bookmark, tags: [String]) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].tags.subtract(tags)
        bookmarks[index].lastModified = Date()
        saveBookmarks()
    }

    /// Add a highlight to a bookmark
    func addHighlight(to bookmark: Bookmark, text: String, color: HighlightColor, note: String? = nil) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        let highlight = Highlight(text: text, color: color, note: note)
        bookmarks[index].highlights.append(highlight)
        bookmarks[index].lastModified = Date()
        saveBookmarks()
    }

    /// Remove a highlight from a bookmark
    func removeHighlight(from bookmark: Bookmark, highlight: Highlight) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index].highlights.removeAll { $0.id == highlight.id }
        bookmarks[index].lastModified = Date()
        saveBookmarks()
    }

    /// Check if an article is bookmarked
    func isBookmarked(_ article: NewsArticle) -> Bool {
        bookmarks.contains { $0.articleID == article.id }
    }

    /// Get bookmark for an article
    func bookmark(for article: NewsArticle) -> Bookmark? {
        bookmarks.first { $0.articleID == article.id }
    }

    // MARK: - Collection Management

    /// Create a new collection
    func createCollection(name: String, description: String? = nil, icon: String? = nil, color: Color? = nil) -> Collection {
        let collection = Collection(name: name, description: description, icon: icon, color: color)
        collections.append(collection)
        saveCollections()
        return collection
    }

    /// Delete a collection
    func deleteCollection(_ collection: Collection) {
        collections.removeAll { $0.id == collection.id }
        saveCollections()
    }

    /// Update collection metadata
    func updateCollection(_ collection: Collection, name: String? = nil, description: String? = nil, icon: String? = nil, color: Color? = nil) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }

        if let name = name {
            collections[index].name = name
        }
        if let description = description {
            collections[index].description = description
        }
        if let icon = icon {
            collections[index].icon = icon
        }
        if let color = color {
            collections[index].color = color
        }
        collections[index].lastModified = Date()
        saveCollections()
    }

    /// Add bookmark to a collection
    func addToCollection(bookmark: Bookmark, collection: Collection) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        if !collections[index].bookmarkIDs.contains(bookmark.id) {
            collections[index].bookmarkIDs.append(bookmark.id)
            collections[index].lastModified = Date()
            saveCollections()
        }
    }

    /// Remove bookmark from a collection
    func removeFromCollection(bookmark: Bookmark, collection: Collection) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        collections[index].bookmarkIDs.removeAll { $0 == bookmark.id }
        collections[index].lastModified = Date()
        saveCollections()
    }

    /// Get all bookmarks in a collection
    func bookmarks(in collection: Collection) -> [Bookmark] {
        let bookmarkIDSet = Set(collection.bookmarkIDs)
        return bookmarks.filter { bookmarkIDSet.contains($0.id) }
    }

    /// Get collections containing a bookmark
    func collections(containing bookmark: Bookmark) -> [Collection] {
        collections.filter { $0.bookmarkIDs.contains(bookmark.id) }
    }

    // MARK: - Search

    /// Search bookmarks by query (searches title, notes, tags)
    func searchBookmarks(query: String) -> [Bookmark] {
        let lowercaseQuery = query.lowercased()

        if !recentSearches.contains(query) {
            recentSearches.insert(query, at: 0)
            if recentSearches.count > 10 {
                recentSearches.removeLast()
            }
        }

        return bookmarks.filter { bookmark in
            bookmark.article.title.lowercased().contains(lowercaseQuery) ||
            (bookmark.notes?.lowercased().contains(lowercaseQuery) ?? false) ||
            bookmark.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
            bookmark.article.source.name.lowercased().contains(lowercaseQuery)
        }
    }

    /// Filter bookmarks by tags
    func filterBookmarks(byTags tags: [String]) -> [Bookmark] {
        let tagSet = Set(tags.map { $0.lowercased() })
        return bookmarks.filter { bookmark in
            !bookmark.tags.intersection(tagSet).isEmpty
        }
    }

    /// Get bookmarks by category
    func bookmarks(inCategory category: NewsCategory) -> [Bookmark] {
        bookmarks.filter { $0.article.category == category }
    }

    /// Get bookmarks by source
    func bookmarks(fromSource source: NewsSource) -> [Bookmark] {
        bookmarks.filter { $0.article.source.id == source.id }
    }

    // MARK: - Export

    /// Export a collection to PDF
    func exportCollectionToPDF(collection: Collection) async throws -> Data {
        let bookmarksInCollection = bookmarks(in: collection)
        let articles = bookmarksInCollection.map { $0.article }
        return try await ExportManager.shared.exportCollectionToPDF(articles: articles, collectionName: collection.name)
    }

    /// Export a collection to Markdown
    func exportCollectionToMarkdown(collection: Collection) -> String {
        let bookmarksInCollection = bookmarks(in: collection)
        var markdown = "# \(collection.name)\n\n"

        if let description = collection.description {
            markdown += "\(description)\n\n"
        }

        markdown += "**Created:** \(collection.createdDate.formatted())\n"
        markdown += "**Bookmarks:** \(bookmarksInCollection.count)\n\n"
        markdown += "---\n\n"

        for (index, bookmark) in bookmarksInCollection.enumerated() {
            markdown += "## \(index + 1). \(bookmark.article.title)\n\n"
            markdown += "**Source:** \(bookmark.article.source.name)\n"
            markdown += "**Published:** \(bookmark.article.publishedDate.formatted())\n"
            markdown += "**Bookmarked:** \(bookmark.createdDate.formatted())\n\n"

            if !bookmark.tags.isEmpty {
                markdown += "**Tags:** \(bookmark.tags.sorted().joined(separator: ", "))\n\n"
            }

            if let notes = bookmark.notes, !notes.isEmpty {
                markdown += "### Notes\n\n"
                markdown += "\(notes)\n\n"
            }

            if !bookmark.highlights.isEmpty {
                markdown += "### Highlights\n\n"
                for highlight in bookmark.highlights {
                    markdown += "- **\(highlight.color.rawValue):** \"\(highlight.text)\"\n"
                    if let note = highlight.note {
                        markdown += "  - *\(note)*\n"
                    }
                }
                markdown += "\n"
            }

            if let summary = bookmark.article.summary {
                markdown += "### Summary\n\n"
                markdown += "\(summary)\n\n"
            }

            if let url = bookmark.article.url {
                markdown += "[Read Full Article](\(url.absoluteString))\n\n"
            }

            markdown += "---\n\n"
        }

        markdown += "*Exported from News Summary by Jordan Koch*\n"
        markdown += "*\(Date().formatted())*\n"

        return markdown
    }

    /// Export bookmarks with specific tags to Markdown
    func exportBookmarksByTags(tags: [String]) -> String {
        let filteredBookmarks = filterBookmarks(byTags: tags)
        let articles = filteredBookmarks.map { $0.article }
        return ExportManager.shared.exportCollectionToMarkdown(
            articles: articles,
            collectionName: "Bookmarks: \(tags.joined(separator: ", "))"
        )
    }

    // MARK: - Statistics

    /// Get bookmark statistics
    var statistics: BookmarkStatistics {
        let totalBookmarks = bookmarks.count
        let totalCollections = collections.count
        let totalTags = tags.count
        let mostUsedTags = mostUsedTags(limit: 5)
        let bookmarksByCategory = Dictionary(grouping: bookmarks) { $0.article.category }
            .mapValues { $0.count }
        let bookmarksBySource = Dictionary(grouping: bookmarks) { $0.article.source.name }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }

        return BookmarkStatistics(
            totalBookmarks: totalBookmarks,
            totalCollections: totalCollections,
            totalTags: totalTags,
            mostUsedTags: mostUsedTags,
            bookmarksByCategory: bookmarksByCategory,
            topSources: bookmarksBySource
        )
    }

    /// Get most used tags
    func mostUsedTags(limit: Int = 10) -> [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for bookmark in bookmarks {
            for tag in bookmark.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Persistence

    private func saveBookmarks() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: bookmarksFileURL)
        } catch {
            print("Failed to save bookmarks: \(error)")
        }
    }

    private func loadBookmarks() {
        guard FileManager.default.fileExists(atPath: bookmarksFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: bookmarksFileURL)
            bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            print("Failed to load bookmarks: \(error)")
        }
    }

    private func saveCollections() {
        do {
            let data = try JSONEncoder().encode(collections)
            try data.write(to: collectionsFileURL)
        } catch {
            print("Failed to save collections: \(error)")
        }
    }

    private func loadCollections() {
        guard FileManager.default.fileExists(atPath: collectionsFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: collectionsFileURL)
            collections = try JSONDecoder().decode([Collection].self, from: data)
        } catch {
            print("Failed to load collections: \(error)")
        }
    }

    private func saveTags() {
        do {
            let tagsArray = Array(tags)
            let data = try JSONEncoder().encode(tagsArray)
            try data.write(to: tagsFileURL)
        } catch {
            print("Failed to save tags: \(error)")
        }
    }

    private func loadTags() {
        guard FileManager.default.fileExists(atPath: tagsFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: tagsFileURL)
            let tagsArray = try JSONDecoder().decode([String].self, from: data)
            tags = Set(tagsArray)
        } catch {
            print("Failed to load tags: \(error)")
        }
    }
}

// MARK: - Bookmark Model

/// A saved article with notes, tags, and highlights
struct Bookmark: Identifiable, Codable, Hashable {
    let id: UUID
    let articleID: UUID
    let article: NewsArticle
    var notes: String?
    var tags: Set<String>
    var highlights: [Highlight]
    let createdDate: Date
    var lastModified: Date

    init(
        id: UUID = UUID(),
        article: NewsArticle,
        notes: String? = nil,
        tags: Set<String> = [],
        highlights: [Highlight] = []
    ) {
        self.id = id
        self.articleID = article.id
        self.article = article
        self.notes = notes
        self.tags = tags
        self.highlights = highlights
        self.createdDate = Date()
        self.lastModified = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Highlight Model

/// Text highlight with color and optional note
struct Highlight: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let color: HighlightColor
    var note: String?
    let createdDate: Date

    init(
        id: UUID = UUID(),
        text: String,
        color: HighlightColor,
        note: String? = nil
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.note = note
        self.createdDate = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Available highlight colors
enum HighlightColor: String, Codable, CaseIterable {
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case pink = "Pink"
    case purple = "Purple"

    var swiftUIColor: Color {
        switch self {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        case .purple: return .purple
        }
    }
}

// MARK: - Collection Model

/// A collection of bookmarks organized by topic
struct Collection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var icon: String?
    var color: Color?
    var bookmarkIDs: [UUID]
    let createdDate: Date
    var lastModified: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        icon: String? = nil,
        color: Color? = nil,
        bookmarkIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.bookmarkIDs = bookmarkIDs
        self.createdDate = Date()
        self.lastModified = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Collection, rhs: Collection) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Codable Support for Color

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, bookmarkIDs, createdDate, lastModified
        case colorRed, colorGreen, colorBlue, colorOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        bookmarkIDs = try container.decode([UUID].self, forKey: .bookmarkIDs)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModified = try container.decode(Date.self, forKey: .lastModified)

        if let red = try? container.decode(Double.self, forKey: .colorRed),
           let green = try? container.decode(Double.self, forKey: .colorGreen),
           let blue = try? container.decode(Double.self, forKey: .colorBlue),
           let opacity = try? container.decode(Double.self, forKey: .colorOpacity) {
            color = Color(red: red, green: green, blue: blue, opacity: opacity)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(bookmarkIDs, forKey: .bookmarkIDs)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModified, forKey: .lastModified)

        if let color = color {
            let nsColor = NSColor(color)
            try container.encode(Double(nsColor.redComponent), forKey: .colorRed)
            try container.encode(Double(nsColor.greenComponent), forKey: .colorGreen)
            try container.encode(Double(nsColor.blueComponent), forKey: .colorBlue)
            try container.encode(Double(nsColor.alphaComponent), forKey: .colorOpacity)
        }
    }
}

// MARK: - Bookmark Statistics

/// Statistics about bookmarks and collections
struct BookmarkStatistics {
    let totalBookmarks: Int
    let totalCollections: Int
    let totalTags: Int
    let mostUsedTags: [(tag: String, count: Int)]
    let bookmarksByCategory: [NewsCategory: Int]
    let topSources: [(source: String, count: Int)]

    var description: String {
        var text = "Bookmark Statistics\n"
        text += "===================\n\n"
        text += "Total Bookmarks: \(totalBookmarks)\n"
        text += "Total Collections: \(totalCollections)\n"
        text += "Total Tags: \(totalTags)\n\n"

        if !mostUsedTags.isEmpty {
            text += "Most Used Tags:\n"
            for (tag, count) in mostUsedTags {
                text += "  - \(tag): \(count)\n"
            }
            text += "\n"
        }

        if !topSources.isEmpty {
            text += "Top Sources:\n"
            for (source, count) in topSources {
                text += "  - \(source): \(count)\n"
            }
            text += "\n"
        }

        return text
    }
}

// MARK: - Errors

enum BookmarkError: LocalizedError {
    case bookmarkNotFound
    case collectionNotFound
    case duplicateBookmark
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .bookmarkNotFound:
            return "Bookmark not found"
        case .collectionNotFound:
            return "Collection not found"
        case .duplicateBookmark:
            return "Article is already bookmarked"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
