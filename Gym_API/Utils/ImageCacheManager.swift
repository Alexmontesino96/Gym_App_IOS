//
//  ImageCacheManager.swift
//  Gym_API
//
//  Inspired by drawRect/Instagram_Stories cache implementation
//  Optimized for Story image caching with NSCache
//

import UIKit
import SwiftUI
import CryptoKit

/// Robust image cache manager using NSCache for memory efficiency
/// Based on Instagram Stories best practices
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    // MARK: - Cache Storage
    private let imageCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL

    // MARK: - Configuration
    private let maxMemoryCost = 100 * 1024 * 1024 // 100 MB
    private let maxCacheAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days

    // MARK: - Tracking
    @Published var downloadTasks: [String: Task<UIImage?, Never>] = [:]

    init() {
        // Configure NSCache
        imageCache.totalCostLimit = maxMemoryCost
        imageCache.countLimit = 100 // Max 100 images in memory

        // Setup disk cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("StoryImageCache")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        print("DEBUG: 💾 ImageCacheManager initialized - Disk cache at: \(diskCacheURL.path)")
    }

    // MARK: - Cache Operations

    /// Get image from cache (memory first, then disk)
    func cachedImage(for url: String) -> UIImage? {
        let key = url as NSString

        print("DEBUG: 🔍 Looking for cached image - Full URL: \(url)")
        print("DEBUG: 🔍 Cache key (NSString): \(key)")

        // Check memory cache first
        if let image = imageCache.object(forKey: key) {
            print("DEBUG: ✅ Memory cache HIT for: \(url.suffix(50))")
            return image
        }

        // Check disk cache
        if let image = loadFromDisk(url: url) {
            print("DEBUG: 💾 Disk cache HIT for: \(url.suffix(50))")
            // Store in memory for faster access
            cacheImage(image, for: url)
            return image
        }

        print("DEBUG: ❌ Cache MISS for: \(url.suffix(50))")
        return nil
    }

    /// Cache image in both memory and disk
    func cacheImage(_ image: UIImage, for url: String) {
        let key = url as NSString

        print("DEBUG: 💾 Caching image - Full URL: \(url)")
        print("DEBUG: 💾 Cache key: \(key)")
        print("DEBUG: 💾 Image size: \(image.size)")

        // Calculate cost (approximate bytes)
        let cost = Int(image.size.width * image.size.height * 4) // RGBA
        imageCache.setObject(image, forKey: key, cost: cost)

        // Save to disk asynchronously
        Task.detached {
            await self.saveToDisk(image: image, url: url)
        }
    }

    /// Download and cache image with retry logic
    func downloadImage(from urlString: String, retries: Int = 3) async -> UIImage? {
        // Check cache first
        if let cached = cachedImage(for: urlString) {
            return cached
        }

        // Check if already downloading
        if let existingTask = downloadTasks[urlString] {
            return await existingTask.value
        }

        // Create download task
        let task = Task { () -> UIImage? in
            guard let url = URL(string: urlString) else {
                print("DEBUG: ❌ Invalid URL: \(urlString)")
                return nil
            }

            // Retry logic
            for attempt in 1...retries {
                do {
                    print("DEBUG: 📥 Downloading image (attempt \(attempt)/\(retries)): \(urlString.suffix(50))")
                    let (data, response) = try await URLSession.shared.data(from: url)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        print("DEBUG: ❌ HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                        if attempt < retries {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) // Exponential backoff
                            continue
                        }
                        return nil
                    }

                    guard let image = UIImage(data: data) else {
                        print("DEBUG: ❌ Invalid image data")
                        return nil
                    }

                    print("DEBUG: ✅ Image downloaded successfully: \(urlString.suffix(50))")

                    // Cache the image
                    await self.cacheImage(image, for: urlString)

                    return image

                } catch {
                    print("DEBUG: ❌ Download error (attempt \(attempt)/\(retries)): \(error.localizedDescription)")
                    if attempt < retries {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                        continue
                    }
                    return nil
                }
            }

            return nil
        }

        downloadTasks[urlString] = task
        let image = await task.value
        downloadTasks.removeValue(forKey: urlString)

        return image
    }

    /// Preload next images for smooth experience
    func preloadImages(_ urls: [String]) {
        Task {
            for url in urls {
                guard cachedImage(for: url) == nil else { continue }
                _ = await downloadImage(from: url)
            }
        }
    }

    // MARK: - Disk Operations

    private func diskCacheFilePath(for url: String) -> URL {
        // Use SHA256 hash to create unique, filesystem-safe filename
        // This ensures URLs with query params get different cache files
        let hash = SHA256.hash(data: Data(url.utf8))
        let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
        let filePath = diskCacheURL.appendingPathComponent(filename + ".jpg")

        print("DEBUG: 🔑 SHA256 Hash for URL: \(url.suffix(60))")
        print("DEBUG: 🔑 Filename: \(filename.prefix(16))...")
        print("DEBUG: 🔑 Full path: \(filePath.lastPathComponent)")

        return filePath
    }

    private func saveToDisk(image: UIImage, url: String) {
        let filePath = diskCacheFilePath(for: url)

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        do {
            try data.write(to: filePath)
            print("DEBUG: 💾 Saved to disk: \(url.suffix(50))")
        } catch {
            print("DEBUG: ❌ Disk save error: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk(url: String) -> UIImage? {
        let filePath = diskCacheFilePath(for: url)

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return nil
        }

        // Check if file is too old
        if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > maxCacheAge {
            try? FileManager.default.removeItem(at: filePath)
            return nil
        }

        return UIImage(contentsOfFile: filePath.path)
    }

    // MARK: - Cache Management

    /// Clear all caches (memory + disk)
    func clearAllCaches() {
        // Clear memory
        imageCache.removeAllObjects()

        // Clear disk
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        print("DEBUG: 🧹 All image caches cleared")
    }

    /// Clear only memory cache
    func clearMemoryCache() {
        imageCache.removeAllObjects()
        print("DEBUG: 🧹 Memory cache cleared")
    }

    /// Get cache statistics
    func cacheStats() -> (memoryCount: Int, diskSize: Int64) {
        let diskSize = try? FileManager.default
            .contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(Int64(0)) { total, url in
                let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                return total + Int64(size ?? 0)
            }

        return (0, diskSize ?? 0) // NSCache doesn't expose count
    }
}
