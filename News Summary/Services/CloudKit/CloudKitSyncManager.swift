//
//  CloudKitSyncManager.swift
//  News Summary
//
//  CloudKit sync for multi-device synchronization
//  Syncs read articles, favorites, custom sources, and preferences
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import CloudKit
import Combine
import Foundation

// MARK: - CloudKit Sync Manager

@MainActor
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()

    // MARK: - Published Properties

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var iCloudAvailable: Bool = false
    @Published private(set) var syncError: String?

    // MARK: - Private Properties

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordZone: CKRecordZone
    private var subscriptions: Set<AnyCancellable> = []

    // Record types
    private enum RecordType {
        static let readArticle = "ReadArticle"
        static let favorite = "Favorite"
        static let customSource = "CustomSource"
        static let preference = "Preference"
    }

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case uploading(Int)
        case downloading(Int)
        case error(String)
        case complete
    }

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: "iCloud.com.jordankoch.NewsSummary")
        privateDatabase = container.privateCloudDatabase
        recordZone = CKRecordZone(zoneName: "NewsSummaryZone")

        setupCloudKit()
    }

    // MARK: - Setup

    private func setupCloudKit() {
        // Check iCloud availability
        container.accountStatus { [weak self] status, error in
            Task { @MainActor in
                self?.iCloudAvailable = (status == .available)
                if status == .available {
                    await self?.createZoneIfNeeded()
                    await self?.setupSubscriptions()
                }
            }
        }
    }

    private func createZoneIfNeeded() async {
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [recordZone],
            recordZoneIDsToDelete: nil
        )

        operation.modifyRecordZonesResultBlock = { result in
            switch result {
            case .success:
                print("CloudKit zone created/verified")
            case .failure(let error):
                print("Failed to create zone: \(error)")
            }
        }

        privateDatabase.add(operation)
    }

    private func setupSubscriptions() async {
        // Subscribe to changes for all record types
        let recordTypes = [RecordType.readArticle, RecordType.favorite, RecordType.customSource, RecordType.preference]

        for recordType in recordTypes {
            let subscription = CKDatabaseSubscription(subscriptionID: "\(recordType)Changes")
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo

            do {
                try await privateDatabase.save(subscription)
            } catch {
                // Subscription might already exist, which is fine
                print("Subscription setup: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sync Operations

    /// Perform a full sync (upload and download)
    func performFullSync() async {
        guard iCloudAvailable else {
            syncError = "iCloud not available"
            return
        }

        syncStatus = .syncing
        syncError = nil

        do {
            // Upload local changes
            await uploadChanges()

            // Download remote changes
            await downloadChanges()

            syncStatus = .complete
            lastSyncDate = Date()
            saveLastSyncDate()

            // Reset to idle after a delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
            syncError = error.localizedDescription
        }
    }

    // MARK: - Upload

    private func uploadChanges() async {
        // Get local changes since last sync
        let localReadArticles = getLocalReadArticles()
        let localFavorites = getLocalFavorites()
        let localSources = getLocalCustomSources()
        let localPreferences = getLocalPreferences()

        let totalItems = localReadArticles.count + localFavorites.count + localSources.count + localPreferences.count

        if totalItems > 0 {
            syncStatus = .uploading(totalItems)
        }

        // Upload read articles
        for article in localReadArticles {
            await uploadReadArticle(article)
        }

        // Upload favorites
        for favorite in localFavorites {
            await uploadFavorite(favorite)
        }

        // Upload custom sources
        for source in localSources {
            await uploadCustomSource(source)
        }

        // Upload preferences
        for pref in localPreferences {
            await uploadPreference(pref)
        }
    }

    private func uploadReadArticle(_ article: SyncReadArticle) async {
        let recordID = CKRecord.ID(recordName: article.articleId, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.readArticle, recordID: recordID)

        record["articleId"] = article.articleId as CKRecordValue
        record["title"] = article.title as CKRecordValue
        record["source"] = article.source as CKRecordValue
        record["readDate"] = article.readDate as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            print("Failed to upload read article: \(error)")
        }
    }

    private func uploadFavorite(_ favorite: SyncFavorite) async {
        let recordID = CKRecord.ID(recordName: favorite.articleId, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.favorite, recordID: recordID)

        record["articleId"] = favorite.articleId as CKRecordValue
        record["title"] = favorite.title as CKRecordValue
        record["source"] = favorite.source as CKRecordValue
        record["category"] = favorite.category as CKRecordValue
        record["savedDate"] = favorite.savedDate as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            print("Failed to upload favorite: \(error)")
        }
    }

    private func uploadCustomSource(_ source: SyncCustomSource) async {
        let recordID = CKRecord.ID(recordName: source.id, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.customSource, recordID: recordID)

        record["sourceId"] = source.id as CKRecordValue
        record["name"] = source.name as CKRecordValue
        record["url"] = source.url as CKRecordValue
        record["category"] = source.category as CKRecordValue
        record["isEnabled"] = source.isEnabled as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            print("Failed to upload custom source: \(error)")
        }
    }

    private func uploadPreference(_ pref: SyncPreference) async {
        let recordID = CKRecord.ID(recordName: pref.key, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.preference, recordID: recordID)

        record["key"] = pref.key as CKRecordValue
        record["value"] = pref.value as CKRecordValue
        record["modifiedDate"] = pref.modifiedDate as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            print("Failed to upload preference: \(error)")
        }
    }

    // MARK: - Download

    private func downloadChanges() async {
        syncStatus = .downloading(0)

        // Download read articles
        await downloadReadArticles()

        // Download favorites
        await downloadFavorites()

        // Download custom sources
        await downloadCustomSources()

        // Download preferences
        await downloadPreferences()
    }

    private func downloadReadArticles() async {
        let query = CKQuery(recordType: RecordType.readArticle, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: recordZone.zoneID)

            for (_, result) in results {
                if case .success(let record) = result {
                    if let articleId = record["articleId"] as? String,
                       let title = record["title"] as? String,
                       let source = record["source"] as? String,
                       let readDate = record["readDate"] as? Date {
                        saveLocalReadArticle(SyncReadArticle(
                            articleId: articleId,
                            title: title,
                            source: source,
                            readDate: readDate
                        ))
                    }
                }
            }
        } catch {
            print("Failed to download read articles: \(error)")
        }
    }

    private func downloadFavorites() async {
        let query = CKQuery(recordType: RecordType.favorite, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: recordZone.zoneID)

            for (_, result) in results {
                if case .success(let record) = result {
                    if let articleId = record["articleId"] as? String,
                       let title = record["title"] as? String,
                       let source = record["source"] as? String,
                       let category = record["category"] as? String,
                       let savedDate = record["savedDate"] as? Date {
                        saveLocalFavorite(SyncFavorite(
                            articleId: articleId,
                            title: title,
                            source: source,
                            category: category,
                            savedDate: savedDate
                        ))
                    }
                }
            }
        } catch {
            print("Failed to download favorites: \(error)")
        }
    }

    private func downloadCustomSources() async {
        let query = CKQuery(recordType: RecordType.customSource, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: recordZone.zoneID)

            for (_, result) in results {
                if case .success(let record) = result {
                    if let id = record["sourceId"] as? String,
                       let name = record["name"] as? String,
                       let url = record["url"] as? String,
                       let category = record["category"] as? String,
                       let isEnabled = record["isEnabled"] as? Bool {
                        saveLocalCustomSource(SyncCustomSource(
                            id: id,
                            name: name,
                            url: url,
                            category: category,
                            isEnabled: isEnabled
                        ))
                    }
                }
            }
        } catch {
            print("Failed to download custom sources: \(error)")
        }
    }

    private func downloadPreferences() async {
        let query = CKQuery(recordType: RecordType.preference, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: recordZone.zoneID)

            for (_, result) in results {
                if case .success(let record) = result {
                    if let key = record["key"] as? String,
                       let value = record["value"] as? String,
                       let modifiedDate = record["modifiedDate"] as? Date {
                        saveLocalPreference(SyncPreference(
                            key: key,
                            value: value,
                            modifiedDate: modifiedDate
                        ))
                    }
                }
            }
        } catch {
            print("Failed to download preferences: \(error)")
        }
    }

    // MARK: - Local Data Access

    private func getLocalReadArticles() -> [SyncReadArticle] {
        guard let data = UserDefaults.standard.data(forKey: "syncReadArticles"),
              let articles = try? JSONDecoder().decode([SyncReadArticle].self, from: data) else {
            return []
        }
        return articles.filter { $0.readDate > (lastSyncDate ?? .distantPast) }
    }

    private func getLocalFavorites() -> [SyncFavorite] {
        guard let data = UserDefaults.standard.data(forKey: "syncFavorites"),
              let favorites = try? JSONDecoder().decode([SyncFavorite].self, from: data) else {
            return []
        }
        return favorites.filter { $0.savedDate > (lastSyncDate ?? .distantPast) }
    }

    private func getLocalCustomSources() -> [SyncCustomSource] {
        guard let data = UserDefaults.standard.data(forKey: "syncCustomSources"),
              let sources = try? JSONDecoder().decode([SyncCustomSource].self, from: data) else {
            return []
        }
        return sources
    }

    private func getLocalPreferences() -> [SyncPreference] {
        guard let data = UserDefaults.standard.data(forKey: "syncPreferences"),
              let prefs = try? JSONDecoder().decode([SyncPreference].self, from: data) else {
            return []
        }
        return prefs.filter { $0.modifiedDate > (lastSyncDate ?? .distantPast) }
    }

    // MARK: - Save Local Data

    private func saveLocalReadArticle(_ article: SyncReadArticle) {
        var articles = getLocalReadArticles()
        if !articles.contains(where: { $0.articleId == article.articleId }) {
            articles.append(article)
            if let data = try? JSONEncoder().encode(articles) {
                UserDefaults.standard.set(data, forKey: "syncReadArticles")
            }
        }
    }

    private func saveLocalFavorite(_ favorite: SyncFavorite) {
        var favorites = getLocalFavorites()
        if !favorites.contains(where: { $0.articleId == favorite.articleId }) {
            favorites.append(favorite)
            if let data = try? JSONEncoder().encode(favorites) {
                UserDefaults.standard.set(data, forKey: "syncFavorites")
            }
        }

        // Notify app of new favorite
        NotificationCenter.default.post(
            name: .favoritesSyncedFromCloud,
            object: nil,
            userInfo: ["favorite": favorite]
        )
    }

    private func saveLocalCustomSource(_ source: SyncCustomSource) {
        var sources = getLocalCustomSources()
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
        } else {
            sources.append(source)
        }
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: "syncCustomSources")
        }

        // Notify app of new source
        NotificationCenter.default.post(
            name: .customSourcesSyncedFromCloud,
            object: nil,
            userInfo: ["source": source]
        )
    }

    private func saveLocalPreference(_ pref: SyncPreference) {
        var prefs = getLocalPreferences()
        if let index = prefs.firstIndex(where: { $0.key == pref.key }) {
            // Only update if cloud version is newer
            if pref.modifiedDate > prefs[index].modifiedDate {
                prefs[index] = pref
            }
        } else {
            prefs.append(pref)
        }
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "syncPreferences")
        }

        // Apply preference
        NotificationCenter.default.post(
            name: .preferenceSyncedFromCloud,
            object: nil,
            userInfo: ["preference": pref]
        )
    }

    // MARK: - Sync Date Persistence

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastCloudKitSyncDate")
    }

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date
    }

    // MARK: - Public API for App

    /// Mark an article as read and sync
    func markArticleRead(articleId: String, title: String, source: String) async {
        let article = SyncReadArticle(
            articleId: articleId,
            title: title,
            source: source,
            readDate: Date()
        )

        saveLocalReadArticle(article)

        if iCloudAvailable {
            await uploadReadArticle(article)
        }
    }

    /// Add a favorite and sync
    func addFavorite(articleId: String, title: String, source: String, category: String) async {
        let favorite = SyncFavorite(
            articleId: articleId,
            title: title,
            source: source,
            category: category,
            savedDate: Date()
        )

        saveLocalFavorite(favorite)

        if iCloudAvailable {
            await uploadFavorite(favorite)
        }
    }

    /// Add a custom source and sync
    func addCustomSource(name: String, url: String, category: String) async {
        let source = SyncCustomSource(
            id: UUID().uuidString,
            name: name,
            url: url,
            category: category,
            isEnabled: true
        )

        saveLocalCustomSource(source)

        if iCloudAvailable {
            await uploadCustomSource(source)
        }
    }

    /// Update a preference and sync
    func updatePreference(key: String, value: String) async {
        let pref = SyncPreference(
            key: key,
            value: value,
            modifiedDate: Date()
        )

        saveLocalPreference(pref)

        if iCloudAvailable {
            await uploadPreference(pref)
        }
    }
}

// MARK: - Sync Data Models

struct SyncReadArticle: Codable {
    let articleId: String
    let title: String
    let source: String
    let readDate: Date
}

struct SyncFavorite: Codable {
    let articleId: String
    let title: String
    let source: String
    let category: String
    let savedDate: Date
}

struct SyncCustomSource: Codable {
    let id: String
    let name: String
    let url: String
    let category: String
    let isEnabled: Bool
}

struct SyncPreference: Codable {
    let key: String
    let value: String
    let modifiedDate: Date
}

// MARK: - Notification Names

extension Notification.Name {
    static let favoritesSyncedFromCloud = Notification.Name("favoritesSyncedFromCloud")
    static let customSourcesSyncedFromCloud = Notification.Name("customSourcesSyncedFromCloud")
    static let preferenceSyncedFromCloud = Notification.Name("preferenceSyncedFromCloud")
}
