//
//  NovaAPIServer.swift
//  NewsSummary
//
//  Nova/Claude API — port 37438
//  Created by Jordan Koch on 2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()
    let port: UInt16 = 37438
    private var listener: NWListener?
    private let startTime = Date()
    private let iso = ISO8601DateFormatter()
    private init() {}

    // MARK: - Lifecycle

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: "127.0.0.1",
                port: NWEndpoint.Port(rawValue: port)!
            )
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.handle(conn) } }
            listener?.stateUpdateHandler = { if case .ready = $0 { print("NovaAPI [NewsSummary]: port \(self.port)") } }
            listener?.start(queue: .main)
        } catch { print("NovaAPI [NewsSummary]: failed — \(error)") }
    }

    func stop() { listener?.cancel(); listener = nil }

    // MARK: - Connection Handling

    private func handle(_ c: NWConnection) { c.start(queue: .main); receive(c, Data()) }

    private func receive(_ c: NWConnection, _ buf: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var b = buf; if let d = data { b.append(d) }
                if let req = NovaRequest(b) {
                    let resp = await self.route(req)
                    c.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in c.cancel() })
                } else if !done { self.receive(c, b) } else { c.cancel() }
            }
        }
    }

    // MARK: - Routing

    private func route(_ req: NovaRequest) async -> String {
        if req.method == "OPTIONS" { return http(200, "") }

        let engine = NewsEngine.shared

        switch (req.method, req.pathOnly) {

        // ── Universal ───────────────────────────────────────────────────────

        case ("GET", "/api/status"):
            let totalArticles = engine.articles.values.flatMap { $0 }.count
            let unread = engine.articles.values.flatMap { $0 }.filter { !$0.isRead }.count
            return json(200, [
                "status": "running",
                "app": "NewsSummary",
                "version": "1.0",
                "port": port,
                "uptimeSeconds": Int(Date().timeIntervalSince(startTime)),
                "isLoading": engine.isLoading,
                "totalArticles": totalArticles,
                "unreadArticles": unread,
                "breakingCount": engine.breakingNews.count
            ] as [String: Any])

        case ("GET", "/api/ping"):
            return json(200, ["pong": true] as [String: Any])

        // ── Categories ──────────────────────────────────────────────────────

        case ("GET", "/api/categories"):
            let cats = NewsCategory.allCases.map { cat -> [String: Any] in
                [
                    "name": cat.rawValue,
                    "count": engine.articles[cat]?.count ?? 0,
                    "unread": engine.articles[cat]?.filter { !$0.isRead }.count ?? 0
                ] as [String: Any]
            }
            return jsonArray(200, cats)

        // ── Breaking News ────────────────────────────────────────────────────

        case ("GET", "/api/breaking"):
            let articles = engine.breakingNews.map { articleDict($0) }
            return jsonArray(200, articles)

        // ── Headlines (top stories across all categories) ────────────────────

        case ("GET", "/api/headlines"):
            // Top 5 from each category, sorted by importance then date
            var headlines: [NewsArticle] = []
            for cat in NewsCategory.allCases {
                let top = (engine.articles[cat] ?? [])
                    .sorted { $0.importance > $1.importance }
                    .prefix(5)
                headlines.append(contentsOf: top)
            }
            let sorted = headlines
                .sorted { $0.importance > $1.importance }
                .prefix(30)
            return jsonArray(200, sorted.map { articleDict($0) })

        // ── Articles by category ─────────────────────────────────────────────
        // GET /api/articles           → top articles from all categories (10 each)
        // GET /api/articles/us        → US articles
        // GET /api/articles/world     → World articles
        // GET /api/articles/technology → Technology articles
        // etc. (us, world, local, business, technology, entertainment, sports, science, health)

        case ("GET", "/api/articles"):
            var all: [[String: Any]] = []
            for cat in NewsCategory.allCases {
                let top = (engine.articles[cat] ?? [])
                    .sorted { $0.importance > $1.importance }
                    .prefix(10)
                all.append(contentsOf: top.map { articleDict($0) })
            }
            return jsonArray(200, all)

        case ("GET", _) where req.pathOnly.hasPrefix("/api/articles/") && !req.pathOnly.dropFirst("/api/articles/".count).contains("/"):
            let slug = req.pathOnly.replacingOccurrences(of: "/api/articles/", with: "").lowercased()

            // Check if it's a category name
            if let cat = NewsCategory.allCases.first(where: { $0.rawValue.lowercased() == slug }) {
                let articles = (engine.articles[cat] ?? [])
                    .sorted { $0.importance > $1.importance }
                    .map { articleDict($0) }
                return jsonArray(200, articles)
            }

            // Otherwise treat as UUID — find article by ID
            if let uuid = UUID(uuidString: slug) {
                for articles in engine.articles.values {
                    if let a = articles.first(where: { $0.id == uuid }) {
                        return json(200, articleDict(a))
                    }
                }
                return json(404, ["error": "Article not found"] as [String: Any])
            }

            return json(400, ["error": "Unknown category or invalid article ID: \(slug)"] as [String: Any])

        // ── Story Clusters ───────────────────────────────────────────────────
        // Returns stories grouped by topic — same event covered by multiple sources

        case ("GET", "/api/stories"):
            let groups = engine.storyGroups.map { group -> [String: Any] in
                [
                    "id": group.id.uuidString,
                    "headline": group.representativeArticle.title,
                    "sourceCount": group.sourceCount,
                    "averageBias": group.averageBias,
                    "biasDistribution": group.biasDistribution,
                    "articles": group.articles.map { articleDict($0) }
                ] as [String: Any]
            }
            return jsonArray(200, groups)

        // ── Refresh ──────────────────────────────────────────────────────────

        case ("POST", "/api/refresh"):
            let body = req.bodyJSON()
            if let catName = body?["category"] as? String,
               let cat = NewsCategory.allCases.first(where: { $0.rawValue.lowercased() == catName.lowercased() }) {
                Task { await engine.refreshCategory(cat) }
                return json(200, ["message": "Refresh triggered for \(cat.rawValue)"] as [String: Any])
            }
            Task { await engine.refresh() }
            return json(200, ["message": "Full refresh triggered"] as [String: Any])

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.pathOnly)"] as [String: Any])
        }
    }

    // MARK: - Article Serialization

    private func articleDict(_ a: NewsArticle) -> [String: Any] {
        var d: [String: Any] = [
            "id": a.id.uuidString,
            "title": a.title,
            "source": a.source.name,
            "url": a.url.absoluteString,
            "publishedDate": iso.string(from: a.publishedDate),
            "timeAgo": a.timeAgoString,
            "category": a.category.rawValue,
            "isBreaking": a.isBreakingNews,
            "importance": a.importance,
            "isRead": a.isRead,
            "isFavorite": a.isFavorite
        ]
        if let v = a.rssDescription    { d["description"] = v }
        if let v = a.summary           { d["summary"] = v }
        if let v = a.fullSummary       { d["fullSummary"] = v }
        if let v = a.keyPoints         { d["keyPoints"] = v }
        if let v = a.imageURL          { d["imageURL"] = v.absoluteString }
        if let bias = a.bias {
            var b: [String: Any] = [
                "spectrum": bias.spectrum.rawValue,
                "spectrumShort": bias.spectrum.shortLabel,
                "confidence": bias.confidence,
                "sourceBias": bias.sourceBias
            ]
            if let v = bias.contentBias          { b["contentBias"] = v }
            if let v = bias.emotionalLanguageScore { b["emotionalLanguage"] = v }
            if let v = bias.balanceScore          { b["balanceScore"] = v }
            if let v = bias.reasoning             { b["reasoning"] = v }
            d["bias"] = b
        }
        return d
    }

    // MARK: - HTTP Primitives

    private struct NovaRequest {
        let method: String
        let pathOnly: String
        let body: String

        func bodyJSON() -> [String: Any]? {
            guard let d = body.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
        }

        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8),
                  raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n")
            let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }
            let tokens = rl.components(separatedBy: " ")
            guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = [:]
            for l in lines.dropFirst() {
                let kv = l.components(separatedBy: ": ")
                if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") }
            }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]
            pathOnly = tokens[1].components(separatedBy: "?").first ?? tokens[1]
            body = rawBody
        }
    }

    private func json(_ s: Int, _ d: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "") }
        return http(s, body, "application/json")
    }

    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "") }
        return http(s, body, "application/json")
    }

    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String {
        let st = [200: "OK", 201: "Created", 400: "Bad Request", 404: "Not Found", 500: "Internal Server Error"][s] ?? "Unknown"
        return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
    }
}
