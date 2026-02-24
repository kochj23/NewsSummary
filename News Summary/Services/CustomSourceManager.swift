//
//  CustomSourceManager.swift
//  News Summary
//
//  User-configurable RSS sources with manual bias assignment
//  Persists to JSON, integrates with NewsAggregator at fetch time
//  Created by Jordan Koch on 2026-02-24
//

import Foundation

// MARK: - Custom News Source Model

struct CustomNewsSource: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var rssURL: URL
    var category: NewsCategory
    var bias: BiasSpectrum
    var credibility: Int          // 0-100
    var factuality: Double        // 0.0-1.0
    var isEnabled: Bool
    let addedDate: Date
    var lastFetched: Date?
    var articleCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        rssURL: URL,
        category: NewsCategory,
        bias: BiasSpectrum = .center,
        credibility: Int = 70,
        factuality: Double = 0.75,
        isEnabled: Bool = true,
        addedDate: Date = Date(),
        lastFetched: Date? = nil,
        articleCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.rssURL = rssURL
        self.category = category
        self.bias = bias
        self.credibility = credibility
        self.factuality = factuality
        self.isEnabled = isEnabled
        self.addedDate = addedDate
        self.lastFetched = lastFetched
        self.articleCount = articleCount
    }

    /// Convert to the standard NewsSource model for the aggregator pipeline
    func toNewsSource() -> NewsSource {
        NewsSource(
            id: "custom-\(id.uuidString)",
            name: name,
            rssURL: rssURL,
            category: category,
            bias: bias,
            credibility: credibility,
            factuality: factuality
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CustomNewsSource, rhs: CustomNewsSource) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Custom Source Manager

@MainActor
class CustomSourceManager: ObservableObject {

    static let shared = CustomSourceManager()

    @Published var customSources: [CustomNewsSource] = []

    private let fileURL: URL

    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("News Summary", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        fileURL = appDirectory.appendingPathComponent("custom_sources.json")
        load()
    }

    // MARK: - CRUD Operations

    @discardableResult
    func addSource(
        name: String,
        rssURL: URL,
        category: NewsCategory,
        bias: BiasSpectrum = .center,
        credibility: Int = 70,
        factuality: Double = 0.75
    ) -> CustomNewsSource {
        let source = CustomNewsSource(
            name: name,
            rssURL: rssURL,
            category: category,
            bias: bias,
            credibility: credibility,
            factuality: factuality
        )
        customSources.append(source)
        save()
        print("📡 Added custom source: \(name) (\(category.rawValue), \(bias.rawValue))")
        return source
    }

    func removeSource(_ source: CustomNewsSource) {
        customSources.removeAll { $0.id == source.id }
        save()
        print("🗑️ Removed custom source: \(source.name)")
    }

    func removeSource(at offsets: IndexSet) {
        let names = offsets.map { customSources[$0].name }
        customSources.remove(atOffsets: offsets)
        save()
        print("🗑️ Removed custom sources: \(names.joined(separator: ", "))")
    }

    func updateSource(_ source: CustomNewsSource) {
        if let index = customSources.firstIndex(where: { $0.id == source.id }) {
            customSources[index] = source
            save()
        }
    }

    func toggleEnabled(_ source: CustomNewsSource) {
        if let index = customSources.firstIndex(where: { $0.id == source.id }) {
            customSources[index].isEnabled.toggle()
            save()
        }
    }

    /// Record fetch results for a custom source
    func recordFetch(sourceID: UUID, articleCount: Int) {
        if let index = customSources.firstIndex(where: { $0.id == sourceID }) {
            customSources[index].lastFetched = Date()
            customSources[index].articleCount = articleCount
            save()
        }
    }

    // MARK: - Source Retrieval

    /// Get enabled custom sources for a specific category, converted to NewsSource
    func sources(for category: NewsCategory) -> [NewsSource] {
        customSources
            .filter { $0.isEnabled && $0.category == category }
            .map { $0.toNewsSource() }
    }

    /// Get all enabled custom sources converted to NewsSource
    var allEnabledSources: [NewsSource] {
        customSources
            .filter { $0.isEnabled }
            .map { $0.toNewsSource() }
    }

    // MARK: - Validation

    /// Check if a URL is already registered (built-in or custom)
    func isDuplicateURL(_ url: URL) -> Bool {
        let normalizedURL = url.absoluteString.lowercased()

        // Check custom sources
        if customSources.contains(where: { $0.rssURL.absoluteString.lowercased() == normalizedURL }) {
            return true
        }

        // Check built-in sources
        if NewsSourceDatabase.allSources.contains(where: { $0.rssURL.absoluteString.lowercased() == normalizedURL }) {
            return true
        }

        return false
    }

    /// Validate an RSS feed URL by attempting to parse it
    /// Returns (success, articleCount) tuple
    func validateFeed(url: URL) async -> (success: Bool, articleCount: Int) {
        let parser = RSSParser()
        let testSource = NewsSource(
            id: "validation-test",
            name: "Feed Validation",
            rssURL: url,
            category: .us,
            bias: .center,
            credibility: 50,
            factuality: 0.5
        )

        let articles = await parser.parseFeed(from: url, source: testSource)
        return (success: !articles.isEmpty, articleCount: articles.count)
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(customSources)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to save custom sources: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            customSources = try JSONDecoder().decode([CustomNewsSource].self, from: data)
            print("📡 Loaded \(customSources.count) custom sources")
        } catch {
            print("❌ Failed to load custom sources: \(error.localizedDescription)")
        }
    }
}
