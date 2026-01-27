import Foundation
import AppKit
import SwiftUI

//
//  ImageCacheManager.swift
//  News Summary
//
//  Intelligent image caching with LRU eviction
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class ImageCacheManager: ObservableObject {

    static let shared = ImageCacheManager()

    // MARK: - Properties

    private var memoryCache: NSCache<NSString, NSImage>
    private var diskCache: DiskCache
    private let maxDiskCacheSize: Int64 = 500_000_000 // 500 MB
    private let maxMemoryCacheSize: Int = 100_000_000 // 100 MB

    @Published var currentCacheSize: Int64 = 0
    @Published var cachedImageCount: Int = 0

    // MARK: - Initialization

    private init() {
        self.memoryCache = NSCache<NSString, NSImage>()
        self.memoryCache.totalCostLimit = maxMemoryCacheSize
        self.memoryCache.countLimit = 500 // Max 500 images in memory

        self.diskCache = DiskCache(maxSize: maxDiskCacheSize)

        // Calculate initial cache size
        Task {
            await updateCacheStatistics()
        }
    }

    // MARK: - Get Image

    func getImage(from url: URL) async -> NSImage? {
        let cacheKey = url.absoluteString

        // Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        // Check disk cache
        if let diskImage = diskCache.getImage(forKey: cacheKey) {
            // Store in memory cache for next time
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }

        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else {
                return nil
            }

            // Cache in memory and disk
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            diskCache.setImage(image, forKey: cacheKey)

            await updateCacheStatistics()

            return image
        } catch {
            print("❌ Failed to download image: \(error)")
            return nil
        }
    }

    // MARK: - Prefetch Images

    func prefetchImages(urls: [URL]) async {
        for url in urls {
            _ = await getImage(from: url)
        }
    }

    // MARK: - Clear Cache

    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        print("🗑️ Memory cache cleared")
    }

    func clearDiskCache() {
        diskCache.clearAll()
        Task {
            await updateCacheStatistics()
        }
        print("🗑️ Disk cache cleared")
    }

    func clearAllCaches() {
        clearMemoryCache()
        clearDiskCache()
    }

    // MARK: - Cache Management

    func removeImage(forURL url: URL) {
        let cacheKey = url.absoluteString
        memoryCache.removeObject(forKey: cacheKey as NSString)
        diskCache.removeImage(forKey: cacheKey)

        Task {
            await updateCacheStatistics()
        }
    }

    private func updateCacheStatistics() async {
        currentCacheSize = diskCache.currentSize
        cachedImageCount = diskCache.imageCount
    }

    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            memoryCacheCount: memoryCache.countLimit,
            diskCacheSize: currentCacheSize,
            diskCacheCount: cachedImageCount,
            maxDiskSize: maxDiskCacheSize
        )
    }
}

// MARK: - Disk Cache

class DiskCache {

    private let cacheDirectory: URL
    private let maxSize: Int64
    private let fileManager = FileManager.default

    var currentSize: Int64 = 0
    var imageCount: Int = 0

    init(maxSize: Int64) {
        self.maxSize = maxSize

        // Get cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("NewsSummary/Images", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Calculate current size
        calculateCacheSize()
    }

    // MARK: - Get/Set

    func getImage(forKey key: String) -> NSImage? {
        let fileURL = cacheURL(forKey: key)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // Update access time for LRU
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        guard let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            return nil
        }

        return image
    }

    func setImage(_ image: NSImage, forKey key: String) {
        let fileURL = cacheURL(forKey: key)

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }

        do {
            try jpegData.write(to: fileURL)
            currentSize += Int64(jpegData.count)
            imageCount += 1

            // Evict old images if cache is full
            if currentSize > maxSize {
                evictOldImages()
            }
        } catch {
            print("❌ Failed to cache image: \(error)")
        }
    }

    func removeImage(forKey key: String) {
        let fileURL = cacheURL(forKey: key)

        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? Int64 {
            try? fileManager.removeItem(at: fileURL)
            currentSize -= fileSize
            imageCount -= 1
        }
    }

    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        currentSize = 0
        imageCount = 0
    }

    // MARK: - LRU Eviction

    private func evictOldImages() {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }

        var files: [(url: URL, date: Date, size: Int64)] = []

        for case let fileURL as URL in enumerator {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let modifiedDate = attributes[.modificationDate] as? Date,
               let size = attributes[.size] as? Int64 {
                files.append((fileURL, modifiedDate, size))
            }
        }

        // Sort by date (oldest first)
        files.sort { $0.date < $1.date }

        // Remove oldest files until under limit
        for file in files {
            if currentSize <= maxSize * 90 / 100 { // Keep at 90% of max
                break
            }

            try? fileManager.removeItem(at: file.url)
            currentSize -= file.size
            imageCount -= 1
        }
    }

    private func calculateCacheSize() {
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

    private func cacheURL(forKey key: String) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key.hash.description
        return cacheDirectory.appendingPathComponent(filename).appendingPathExtension("jpg")
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

// MARK: - SwiftUI Extension

extension View {
    func cachedAsyncImage(url: URL?, placeholder: Image = Image(systemName: "photo")) -> some View {
        CachedAsyncImage(url: url, placeholder: placeholder)
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
                    .resizable()
            }
        }
        .task {
            guard let url = url else { return }
            isLoading = true
            image = await ImageCacheManager.shared.getImage(from: url)
            isLoading = false
        }
    }
}
