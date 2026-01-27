import Foundation

//
//  EntityTrackingEngine.swift
//  News Summary
//
//  AI-powered entity extraction and tracking system
//  Identifies people, organizations, locations, events, and concepts
//  Tracks entity mentions, sentiment, and relationships over time
//  Builds relationship graphs for visualization
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class EntityTrackingEngine: ObservableObject {

    static let shared = EntityTrackingEngine()

    @Published var isProcessing = false
    @Published var trackedEntities: [String: EntityProfile] = [:]
    @Published var relationshipGraph: EntityGraph?

    private init() {}

    // MARK: - Extract Entities

    /// Extract all entities from an article
    func extractEntities(from article: NewsArticle) async throws -> [Entity] {

        isProcessing = true
        defer { isProcessing = false }

        let fullText = extractFullText(from: article)

        let prompt = """
        Extract all important entities from this article.
        Include people, organizations, locations, events, and key concepts.

        Article:
        \(fullText)

        List entities in this format (one per paragraph):
        NAME: [Entity name]
        TYPE: [Person/Organization/Location/Event/Concept]
        ROLE: [Brief description of their role in the story]
        MENTIONS: [Approximate number of mentions]
        SENTIMENT: [Positive/Negative/Neutral/Mixed]
        RELEVANCE: [High/Medium/Low]

        Extract all significant entities.
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You are an entity extraction specialist. Identify all important entities from news articles.",
            temperature: 0.2,
            maxTokens: 1500
        )

        let entities = parseEntities(response, articleId: article.id.uuidString)

        // Update tracked entities
        for entity in entities {
            updateEntityProfile(entity: entity, article: article)
        }

        return entities
    }

    // MARK: - Track Entity

    /// Track a specific entity across multiple articles
    func trackEntity(name: String, across articles: [NewsArticle]) async throws -> EntityProfile {

        isProcessing = true
        defer { isProcessing = false }

        // Check if we already have a profile
        if let existing = trackedEntities[name.lowercased()] {
            // Update with new articles
            return try await updateEntityTracking(profile: existing, articles: articles)
        }

        // Extract entity from all articles
        var mentions: [EntityMention] = []
        var sentiments: [EntitySentiment] = []

        for article in articles {
            let entities = try await extractEntities(from: article)

            // Find mentions of this entity
            if let entity = entities.first(where: { $0.name.lowercased().contains(name.lowercased()) }) {
                mentions.append(EntityMention(
                    article: article,
                    entity: entity,
                    position: .unknown,
                    context: entity.role ?? ""
                ))

                if let sentiment = entity.sentiment {
                    sentiments.append(EntitySentiment(
                        date: article.publishedDate,
                        sentiment: sentiment,
                        articleId: article.id.uuidString
                    ))
                }
            }
        }

        // Analyze entity's story arc
        let narrative = try await analyzeEntityNarrative(name: name, mentions: mentions)

        let profile = EntityProfile(
            name: name,
            type: mentions.first?.entity.type ?? .person,
            firstMention: mentions.min(by: { $0.article.publishedDate < $1.article.publishedDate })?.article.publishedDate ?? Date(),
            totalMentions: mentions.count,
            mentions: mentions,
            sentimentHistory: sentiments,
            narrative: narrative,
            relatedEntities: []
        )

        trackedEntities[name.lowercased()] = profile

        return profile
    }

    // MARK: - Build Relationship Graph

    /// Build relationship graph from a set of articles
    func buildRelationshipGraph(from articles: [NewsArticle]) async throws -> EntityGraph {

        isProcessing = true
        defer { isProcessing = false }

        // Extract all entities from all articles
        var allEntities: [Entity] = []

        for article in articles {
            let entities = try await extractEntities(from: article)
            allEntities.append(contentsOf: entities)
        }

        // Group entities by name
        let entityGroups = Dictionary(grouping: allEntities, by: { $0.name.lowercased() })

        // Create nodes
        var nodes: [EntityNode] = []

        for (name, entities) in entityGroups {
            let type = entities.first?.type ?? .concept
            let mentionCount = entities.count
            let relevance = entities.map { $0.relevance.value }.reduce(0, +) / Double(entities.count)

            nodes.append(EntityNode(
                name: name.capitalized,
                type: type,
                mentionCount: mentionCount,
                relevance: relevance
            ))
        }

        // Extract relationships
        let edges = try await extractRelationships(articles: articles, entities: nodes)

        let graph = EntityGraph(
            nodes: nodes,
            edges: edges,
            generatedAt: Date()
        )

        relationshipGraph = graph

        return graph
    }

    // MARK: - Entity Sentiment Analysis

    /// Analyze sentiment towards an entity across articles
    func analyzeSentiment(entity: String, in articles: [NewsArticle]) async throws -> SentimentAnalysis {

        let mentions = articles.compactMap { article -> String? in
            let text = extractFullText(from: article)
            return text.contains(entity) ? text : nil
        }

        guard !mentions.isEmpty else {
            throw EntityTrackingError.entityNotFound
        }

        let combinedText = mentions.prefix(5).joined(separator: "\n\n---\n\n")

        let prompt = """
        Analyze how the media portrays this entity:

        Entity: \(entity)

        Articles:
        \(combinedText)

        OVERALL_SENTIMENT: [Positive/Negative/Neutral/Mixed]
        CONFIDENCE: [0.0-1.0]
        TONE: [Describe the overall tone]
        FRAMING: [How is this entity framed?]

        POSITIVE_ASPECTS:
        - [Aspect 1]
        - [Aspect 2]

        NEGATIVE_ASPECTS:
        - [Aspect 1]
        - [Aspect 2]

        NEUTRAL_ASPECTS:
        - [Aspect 1]
        - [Aspect 2]

        CHANGES_OVER_TIME: [Has sentiment changed? How?]
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You analyze media sentiment towards entities. Be objective and specific.",
            temperature: 0.3,
            maxTokens: 1000
        )

        return parseSentimentAnalysis(response, entity: entity)
    }

    // MARK: - Find Related Entities

    /// Find entities related to a given entity
    func findRelatedEntities(to entity: String, limit: Int = 10) async -> [RelatedEntity] {

        guard let graph = relationshipGraph else {
            return []
        }

        // Find the node
        guard let node = graph.nodes.first(where: { $0.name.lowercased().contains(entity.lowercased()) }) else {
            return []
        }

        // Find all edges connected to this node
        let connectedEdges = graph.edges.filter {
            $0.source == node.name || $0.target == node.name
        }

        // Build related entities list
        var relatedEntities: [RelatedEntity] = []

        for edge in connectedEdges {
            let relatedName = edge.source == node.name ? edge.target : edge.source

            if let relatedNode = graph.nodes.first(where: { $0.name == relatedName }) {
                relatedEntities.append(RelatedEntity(
                    name: relatedName,
                    type: relatedNode.type,
                    relationship: edge.relationship,
                    strength: edge.strength
                ))
            }
        }

        // Sort by strength and limit
        return relatedEntities
            .sorted { $0.strength > $1.strength }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Entity Timeline

    /// Create timeline of entity mentions
    func createTimeline(for entity: String) -> EntityTimeline? {

        guard let profile = trackedEntities[entity.lowercased()] else {
            return nil
        }

        let events = profile.mentions
            .sorted { $0.article.publishedDate < $1.article.publishedDate }
            .map { mention in
                TimelineEvent(
                    date: mention.article.publishedDate,
                    title: mention.article.title,
                    description: mention.context,
                    sentiment: mention.entity.sentiment ?? .neutral,
                    articleId: mention.article.id.uuidString
                )
            }

        return EntityTimeline(
            entity: entity,
            events: events,
            startDate: profile.firstMention,
            endDate: profile.mentions.last?.article.publishedDate ?? Date()
        )
    }

    // MARK: - Helper Methods

    private func extractFullText(from article: NewsArticle) -> String {
        var text = ""

        if let title = article.title {
            text += title + "\n\n"
        }

        if let content = article.scrapedContent {
            text += content
        } else if let description = article.rssDescription {
            text += description
        }

        return text
    }

    private func parseEntities(_ response: String, articleId: String) -> [Entity] {
        var entities: [Entity] = []

        let paragraphs = response.components(separatedBy: "\n\n")

        for paragraph in paragraphs {
            let lines = paragraph.components(separatedBy: "\n")
            var name = ""
            var type: EntityType = .concept
            var role: String?
            var mentions = 1
            var sentiment: Sentiment = .neutral
            var relevance: EntityRelevance = .medium

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.starts(with: "NAME:") {
                    name = trimmed.replacingOccurrences(of: "NAME:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.starts(with: "TYPE:") {
                    let typeString = trimmed.replacingOccurrences(of: "TYPE:", with: "").trimmingCharacters(in: .whitespaces)
                    type = EntityType.from(string: typeString)
                } else if trimmed.starts(with: "ROLE:") {
                    role = trimmed.replacingOccurrences(of: "ROLE:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.starts(with: "MENTIONS:") {
                    let mentionString = trimmed.replacingOccurrences(of: "MENTIONS:", with: "").trimmingCharacters(in: .whitespaces)
                    mentions = Int(mentionString.components(separatedBy: .decimalDigits.inverted).joined()) ?? 1
                } else if trimmed.starts(with: "SENTIMENT:") {
                    let sentimentString = trimmed.replacingOccurrences(of: "SENTIMENT:", with: "").trimmingCharacters(in: .whitespaces)
                    sentiment = Sentiment.from(string: sentimentString)
                } else if trimmed.starts(with: "RELEVANCE:") {
                    let relevanceString = trimmed.replacingOccurrences(of: "RELEVANCE:", with: "").trimmingCharacters(in: .whitespaces)
                    relevance = EntityRelevance.from(string: relevanceString)
                }
            }

            if !name.isEmpty {
                entities.append(Entity(
                    name: name,
                    type: type,
                    role: role,
                    mentionCount: mentions,
                    sentiment: sentiment,
                    relevance: relevance,
                    sourceArticleId: articleId
                ))
            }
        }

        return entities
    }

    private func updateEntityProfile(entity: Entity, article: NewsArticle) {
        let key = entity.name.lowercased()

        if var profile = trackedEntities[key] {
            // Update existing profile
            profile.totalMentions += entity.mentionCount

            let mention = EntityMention(
                article: article,
                entity: entity,
                position: .unknown,
                context: entity.role ?? ""
            )
            profile.mentions.append(mention)

            if let sentiment = entity.sentiment {
                profile.sentimentHistory.append(EntitySentiment(
                    date: article.publishedDate,
                    sentiment: sentiment,
                    articleId: article.id.uuidString
                ))
            }

            trackedEntities[key] = profile
        } else {
            // Create new profile
            let mention = EntityMention(
                article: article,
                entity: entity,
                position: .unknown,
                context: entity.role ?? ""
            )

            var sentiments: [EntitySentiment] = []
            if let sentiment = entity.sentiment {
                sentiments.append(EntitySentiment(
                    date: article.publishedDate,
                    sentiment: sentiment,
                    articleId: article.id.uuidString
                ))
            }

            let profile = EntityProfile(
                name: entity.name,
                type: entity.type,
                firstMention: article.publishedDate,
                totalMentions: entity.mentionCount,
                mentions: [mention],
                sentimentHistory: sentiments,
                narrative: nil,
                relatedEntities: []
            )

            trackedEntities[key] = profile
        }
    }

    private func updateEntityTracking(profile: EntityProfile, articles: [NewsArticle]) async throws -> EntityProfile {
        var updatedProfile = profile

        for article in articles {
            let entities = try await extractEntities(from: article)

            if let entity = entities.first(where: { $0.name.lowercased() == profile.name.lowercased() }) {
                let mention = EntityMention(
                    article: article,
                    entity: entity,
                    position: .unknown,
                    context: entity.role ?? ""
                )
                updatedProfile.mentions.append(mention)
                updatedProfile.totalMentions += entity.mentionCount

                if let sentiment = entity.sentiment {
                    updatedProfile.sentimentHistory.append(EntitySentiment(
                        date: article.publishedDate,
                        sentiment: sentiment,
                        articleId: article.id.uuidString
                    ))
                }
            }
        }

        trackedEntities[profile.name.lowercased()] = updatedProfile

        return updatedProfile
    }

    private func analyzeEntityNarrative(name: String, mentions: [EntityMention]) async throws -> String {

        let contexts = mentions.map { "\($0.article.publishedDate.formatted()): \($0.context)" }.joined(separator: "\n")

        let prompt = """
        Analyze the narrative arc for this entity across multiple articles:

        Entity: \(name)

        Mentions over time:
        \(contexts)

        Provide a narrative summary (2-3 paragraphs):
        - How has their story evolved?
        - What role do they play?
        - Any significant changes or developments?
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You create narrative summaries of how entities appear in news coverage over time.",
            temperature: 0.4,
            maxTokens: 500
        )

        return response
    }

    private func extractRelationships(articles: [NewsArticle], entities: [EntityNode]) async throws -> [EntityEdge] {

        let entityNames = entities.map { $0.name }.joined(separator: ", ")
        let articleTexts = articles.prefix(5).map { extractFullText(from: $0) }.joined(separator: "\n\n===\n\n")

        let prompt = """
        Identify relationships between these entities based on the articles:

        Entities: \(entityNames)

        Articles:
        \(articleTexts)

        List relationships in this format (one per line):
        [Entity1] -> [Entity2]: [Relationship type] (Strength: 0.0-1.0)

        Example:
        Apple -> Tim Cook: CEO of (Strength: 0.9)
        USA -> China: Trade conflict with (Strength: 0.7)

        Focus on the most important relationships.
        """

        let response = try await AIBackendManager.shared.generate(
            prompt: prompt,
            systemPrompt: "You identify relationships between entities in news articles.",
            temperature: 0.3,
            maxTokens: 1000
        )

        return parseRelationships(response)
    }

    private func parseRelationships(_ response: String) -> [EntityEdge] {
        var edges: [EntityEdge] = []

        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Parse format: Entity1 -> Entity2: Relationship (Strength: X)
            if trimmed.contains("->") && trimmed.contains(":") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let entityPart = parts[0]
                    let relationshipPart = parts[1]

                    let entityComponents = entityPart.components(separatedBy: "->")
                    if entityComponents.count == 2 {
                        let source = entityComponents[0].trimmingCharacters(in: .whitespaces)
                        let target = entityComponents[1].trimmingCharacters(in: .whitespaces)

                        var relationship = relationshipPart.trimmingCharacters(in: .whitespaces)
                        var strength = 0.5

                        // Extract strength if present
                        if relationship.contains("(Strength:") {
                            let strengthComponents = relationship.components(separatedBy: "(Strength:")
                            relationship = strengthComponents[0].trimmingCharacters(in: .whitespaces)

                            if strengthComponents.count > 1 {
                                let strengthString = strengthComponents[1]
                                    .replacingOccurrences(of: ")", with: "")
                                    .trimmingCharacters(in: .whitespaces)
                                strength = Double(strengthString) ?? 0.5
                            }
                        }

                        edges.append(EntityEdge(
                            source: source,
                            target: target,
                            relationship: relationship,
                            strength: strength
                        ))
                    }
                }
            }
        }

        return edges
    }

    private func parseSentimentAnalysis(_ response: String, entity: String) -> SentimentAnalysis {
        var overallSentiment: Sentiment = .neutral
        var confidence: Double = 0.5
        var tone = ""
        var framing = ""
        var positiveAspects: [String] = []
        var negativeAspects: [String] = []
        var neutralAspects: [String] = []
        var changes = ""

        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "OVERALL_SENTIMENT:") {
                let sentimentString = trimmed.replacingOccurrences(of: "OVERALL_SENTIMENT:", with: "").trimmingCharacters(in: .whitespaces)
                overallSentiment = Sentiment.from(string: sentimentString)
            } else if trimmed.starts(with: "CONFIDENCE:") {
                let confString = trimmed.replacingOccurrences(of: "CONFIDENCE:", with: "").trimmingCharacters(in: .whitespaces)
                confidence = Double(confString) ?? 0.5
            } else if trimmed.starts(with: "TONE:") {
                tone = trimmed.replacingOccurrences(of: "TONE:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "FRAMING:") {
                framing = trimmed.replacingOccurrences(of: "FRAMING:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed == "POSITIVE_ASPECTS:" {
                currentSection = "positive"
            } else if trimmed == "NEGATIVE_ASPECTS:" {
                currentSection = "negative"
            } else if trimmed == "NEUTRAL_ASPECTS:" {
                currentSection = "neutral"
            } else if trimmed.starts(with: "CHANGES_OVER_TIME:") {
                changes = trimmed.replacingOccurrences(of: "CHANGES_OVER_TIME:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)

                switch currentSection {
                case "positive":
                    positiveAspects.append(content)
                case "negative":
                    negativeAspects.append(content)
                case "neutral":
                    neutralAspects.append(content)
                default:
                    break
                }
            }
        }

        return SentimentAnalysis(
            entity: entity,
            overallSentiment: overallSentiment,
            confidence: confidence,
            tone: tone,
            framing: framing,
            positiveAspects: positiveAspects,
            negativeAspects: negativeAspects,
            neutralAspects: neutralAspects,
            sentimentChanges: changes
        )
    }
}

// MARK: - Models

/// Entity extracted from an article
struct Entity: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: EntityType
    let role: String?
    let mentionCount: Int
    let sentiment: Sentiment?
    let relevance: EntityRelevance
    let sourceArticleId: String
}

/// Types of entities
enum EntityType: String, Codable {
    case person = "Person"
    case organization = "Organization"
    case location = "Location"
    case event = "Event"
    case concept = "Concept"

    static func from(string: String) -> EntityType {
        let lower = string.lowercased()
        if lower.contains("person") || lower.contains("people") {
            return .person
        } else if lower.contains("organization") || lower.contains("company") {
            return .organization
        } else if lower.contains("location") || lower.contains("place") {
            return .location
        } else if lower.contains("event") {
            return .event
        } else {
            return .concept
        }
    }

    var icon: String {
        switch self {
        case .person: return "person.fill"
        case .organization: return "building.2.fill"
        case .location: return "map.fill"
        case .event: return "calendar"
        case .concept: return "lightbulb.fill"
        }
    }
}

/// Sentiment towards entity
enum Sentiment: String, Codable {
    case positive = "Positive"
    case negative = "Negative"
    case neutral = "Neutral"
    case mixed = "Mixed"

    static func from(string: String) -> Sentiment {
        let lower = string.lowercased()
        if lower.contains("positive") {
            return .positive
        } else if lower.contains("negative") {
            return .negative
        } else if lower.contains("mixed") {
            return .mixed
        } else {
            return .neutral
        }
    }

    var color: String {
        switch self {
        case .positive: return "green"
        case .negative: return "red"
        case .neutral: return "gray"
        case .mixed: return "orange"
        }
    }
}

/// Relevance level of entity
enum EntityRelevance: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    static func from(string: String) -> EntityRelevance {
        let lower = string.lowercased()
        if lower.contains("high") {
            return .high
        } else if lower.contains("low") {
            return .low
        } else {
            return .medium
        }
    }

    var value: Double {
        switch self {
        case .high: return 1.0
        case .medium: return 0.5
        case .low: return 0.2
        }
    }
}

/// Complete entity profile tracked over time
struct EntityProfile: Codable {
    let name: String
    let type: EntityType
    let firstMention: Date
    var totalMentions: Int
    var mentions: [EntityMention]
    var sentimentHistory: [EntitySentiment]
    var narrative: String?
    var relatedEntities: [RelatedEntity]

    var averageSentiment: Sentiment {
        let sentiments = sentimentHistory.map { $0.sentiment }
        let positiveCount = sentiments.filter { $0 == .positive }.count
        let negativeCount = sentiments.filter { $0 == .negative }.count

        if positiveCount > negativeCount * 2 {
            return .positive
        } else if negativeCount > positiveCount * 2 {
            return .negative
        } else if positiveCount > 0 && negativeCount > 0 {
            return .mixed
        } else {
            return .neutral
        }
    }
}

/// Single mention of an entity in an article
struct EntityMention: Codable {
    let article: NewsArticle
    let entity: Entity
    let position: MentionPosition
    let context: String
}

/// Position of entity mention in article
enum MentionPosition: String, Codable {
    case headline = "Headline"
    case leadParagraph = "Lead Paragraph"
    case body = "Body"
    case conclusion = "Conclusion"
    case unknown = "Unknown"
}

/// Sentiment at a point in time
struct EntitySentiment: Codable {
    let date: Date
    let sentiment: Sentiment
    let articleId: String
}

/// Entity relationship graph
struct EntityGraph: Codable {
    let nodes: [EntityNode]
    let edges: [EntityEdge]
    let generatedAt: Date

    var entityCount: Int {
        nodes.count
    }

    var relationshipCount: Int {
        edges.count
    }
}

/// Node in entity graph
struct EntityNode: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: EntityType
    let mentionCount: Int
    let relevance: Double
}

/// Edge (relationship) in entity graph
struct EntityEdge: Identifiable, Codable {
    let id = UUID()
    let source: String          // Source entity name
    let target: String          // Target entity name
    let relationship: String    // Type of relationship
    let strength: Double        // 0.0-1.0
}

/// Related entity
struct RelatedEntity: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: EntityType
    let relationship: String
    let strength: Double
}

/// Sentiment analysis result
struct SentimentAnalysis: Codable {
    let entity: String
    let overallSentiment: Sentiment
    let confidence: Double
    let tone: String
    let framing: String
    let positiveAspects: [String]
    let negativeAspects: [String]
    let neutralAspects: [String]
    let sentimentChanges: String
}

/// Entity timeline
struct EntityTimeline: Identifiable {
    let id = UUID()
    let entity: String
    let events: [TimelineEvent]
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

/// Timeline event
struct TimelineEvent: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let title: String
    let description: String
    let sentiment: Sentiment
    let articleId: String
}

// MARK: - Errors

enum EntityTrackingError: LocalizedError {
    case entityNotFound
    case insufficientData
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "Entity not found in articles"
        case .insufficientData:
            return "Insufficient data to track entity"
        case .extractionFailed:
            return "Entity extraction failed"
        }
    }
}
