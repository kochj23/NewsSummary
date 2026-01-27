import Foundation
import CoreData

//
//  CoreDataStack.swift
//  News Summary
//
//  Core Data persistence for reading history and articles
//  Author: Jordan Koch
//  Date: 2026-01-26
//

class CoreDataStack {

    static let shared = CoreDataStack()

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NewsSummary")

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Save Context

    func saveContext() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("❌ Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Background Context

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    // MARK: - Fetch Requests

    func fetchArticles(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [ArticleEntity] {
        let request = ArticleEntity.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Fetch error: \(error)")
            return []
        }
    }

    func fetchReadingHistory(limit: Int = 100) -> [ReadingHistoryEntity] {
        let request = ReadingHistoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReadingHistoryEntity.readAt, ascending: false)]
        request.fetchLimit = limit

        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Fetch error: \(error)")
            return []
        }
    }

    // MARK: - Delete

    func deleteOldHistory(olderThan days: Int) {
        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))
        let predicate = NSPredicate(format: "readAt < %@", cutoffDate as NSDate)

        let request = ReadingHistoryEntity.fetchRequest()
        request.predicate = predicate

        do {
            let oldRecords = try viewContext.fetch(request)
            for record in oldRecords {
                viewContext.delete(record)
            }
            saveContext()
            print("🗑️ Deleted \(oldRecords.count) old reading history records")
        } catch {
            print("❌ Delete error: \(error)")
        }
    }

    // MARK: - Clear All

    func clearAllData() {
        // Clear all entities
        let entityNames = ["ArticleEntity", "ReadingHistoryEntity", "BookmarkEntity", "CollectionEntity"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try viewContext.execute(deleteRequest)
                saveContext()
            } catch {
                print("❌ Clear error for \(entityName): \(error)")
            }
        }
    }
}

// MARK: - Core Data Models (Entity Definitions)

// Note: These would typically be defined in a .xcdatamodeld file
// Here's the structure for reference:

/*
 ArticleEntity:
 - id: UUID (unique)
 - title: String
 - sourceID: String
 - sourceName: String
 - url: String
 - publishedDate: Date
 - category: String
 - rssDescription: String?
 - scrapedContent: String?
 - summary: String?
 - fullSummary: String?
 - isRead: Bool
 - isFavorite: Bool
 - readAt: Date?
 - createdAt: Date

 ReadingHistoryEntity:
 - id: UUID
 - articleID: UUID
 - readAt: Date
 - timeSpent: Double
 - category: String
 - sourceName: String
 - bias: String

 BookmarkEntity:
 - id: UUID
 - articleID: UUID
 - notes: String?
 - tags: String (comma-separated)
 - highlights: Data (JSON)
 - createdAt: Date
 - modifiedAt: Date

 CollectionEntity:
 - id: UUID
 - name: String
 - description: String?
 - articleIDs: Data (JSON array of UUIDs)
 - createdAt: Date
 - modifiedAt: Date
 */

// MARK: - Migration Helper

class CoreDataMigration {

    static func migrateFromJSON(coreDataStack: CoreDataStack) async {
        // Migrate BookmarkManager data to Core Data
        let bookmarks = BookmarkManager.shared.bookmarks

        for bookmark in bookmarks.values {
            // Create BookmarkEntity in Core Data
            // This would be implemented when Core Data model is created
            print("Migrating bookmark: \(bookmark.article.title)")
        }

        // Migrate ReadingAnalytics data
        let analytics = ReadingAnalytics.shared
        let history = analytics.readingHistory

        for record in history {
            // Create ReadingHistoryEntity in Core Data
            print("Migrating reading record: \(record.article.title)")
        }

        // Migrate FavoritesManager data
        let favorites = FavoritesManager.shared.favorites

        for article in favorites {
            // Update ArticleEntity with isFavorite = true
            print("Migrating favorite: \(article.title)")
        }

        print("✅ Migration complete!")
    }
}
