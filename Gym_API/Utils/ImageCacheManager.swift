//
//  ImageCacheManager.swift
//  Gym_API
//
//  Unified image cache manager using NSCache for memory efficiency
//  Consolidates all image caching into a single source of truth
//
//  Performance optimizations:
//  - Memory cache (NSCache) + Disk cache (FileManager)
//  - SHA256 hashing for cache keys
//  - Concurrent download limiting (max 4)
//  - Cache hit/miss metrics for monitoring
//  - Image downscaling support for memory optimization
//

import UIKit
import SwiftUI
import CryptoKit

// MARK: - Unified Image Cache Manager

/// Unified image cache manager - single source of truth for all image caching
/// Replaces multiple cache implementations with one consolidated system
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    // MARK: - Cache Storage
    private let imageCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let diskQueue = DispatchQueue(label: "com.gymapi.imagecache.disk", qos: .utility)

    // MARK: - Configuration
    private let maxMemoryCost = 100 * 1024 * 1024 // 100 MB
    private let maxDiskCacheSize = 100 * 1024 * 1024 // 100 MB
    private let maxCacheAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days

    // MARK: - Concurrency Control
    /// Semaphore to limit concurrent downloads (max 4)
    private let downloadSemaphore = DispatchSemaphore(value: 4)
    private let concurrentDownloadLimit = 4

    // MARK: - Download Task Tracking
    @Published var downloadTasks: [String: Task<UIImage?, Never>] = [:]

    // MARK: - Performance Metrics
    /// Number of cache hits (image found in cache)
    private(set) var cacheHits: Int = 0
    /// Number of cache misses (image not found, had to download)
    private(set) var cacheMisses: Int = 0
    /// Lock for thread-safe metric updates
    private let metricsLock = NSLock()

    // MARK: - Initialization

    init() {
        // Configure NSCache limits
        imageCache.totalCostLimit = maxMemoryCost
        imageCache.countLimit = 150 // Increased for optimized images

        // Setup disk cache directory (unified location)
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("UnifiedImageCache")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Clean old cache on init
        Task {
            await cleanOldCache()
        }

        print("DEBUG: ImageCacheManager initialized - Disk cache at: \(diskCacheURL.path)")
    }

    // MARK: - Performance Metrics API

    /// Returns cache statistics including hit rate
    /// - Returns: Tuple with hits, misses, and hit rate percentage
    func cacheStats() -> (hits: Int, misses: Int, hitRate: Double) {
        metricsLock.lock()
        defer { metricsLock.unlock() }

        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) * 100 : 0
        return (hits: cacheHits, misses: cacheMisses, hitRate: hitRate)
    }

    /// Returns extended cache statistics including disk size
    func extendedCacheStats() -> (hits: Int, misses: Int, hitRate: Double, diskSizeBytes: Int64) {
        let basicStats = cacheStats()
        let diskSize = calculateDiskCacheSize()
        return (
            hits: basicStats.hits,
            misses: basicStats.misses,
            hitRate: basicStats.hitRate,
            diskSizeBytes: diskSize
        )
    }

    /// Resets cache metrics (useful for testing/debugging)
    func resetMetrics() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        cacheHits = 0
        cacheMisses = 0
        print("DEBUG: Cache metrics reset")
    }

    private func recordCacheHit() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        cacheHits += 1
    }

    private func recordCacheMiss() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        cacheMisses += 1
    }

    // MARK: - Cache Key Generation

    /// Generates a cache key for a URL with optional target size
    /// - Parameters:
    ///   - url: The image URL
    ///   - targetSize: Optional target size for optimized images
    /// - Returns: Unique cache key string
    func cacheKey(for url: String, targetSize: CGSize? = nil) -> String {
        let normalized = normalizeImageURLKey(url)
        if let size = targetSize {
            return "\(normalized)_\(Int(size.width))x\(Int(size.height))"
        }
        return normalized
    }

    // MARK: - Basic Cache Operations

    /// Get image from cache (memory first, then disk)
    /// - Parameter url: The image URL
    /// - Returns: Cached UIImage or nil if not found
    func cachedImage(for url: String) -> UIImage? {
        return cachedImage(for: url, targetSize: nil)
    }

    /// Get image from cache with specific target size
    /// - Parameters:
    ///   - url: The image URL
    ///   - targetSize: Optional target size for optimized version
    /// - Returns: Cached UIImage or nil if not found
    func cachedImage(for url: String, targetSize: CGSize?) -> UIImage? {
        let key = cacheKey(for: url, targetSize: targetSize)
        let nsKey = key as NSString

        // Check memory cache first
        if let image = imageCache.object(forKey: nsKey) {
            recordCacheHit()
            print("DEBUG: Memory cache HIT for: \(key.suffix(50))")
            return image
        }

        // Check disk cache
        if let image = loadFromDisk(key: key) {
            recordCacheHit()
            print("DEBUG: Disk cache HIT for: \(key.suffix(50))")
            // Store in memory for faster access (but don't save to disk again)
            cacheImage(image, for: url, targetSize: targetSize, saveToDisk: false)
            return image
        }

        recordCacheMiss()
        print("DEBUG: Cache MISS for: \(key.suffix(50))")
        return nil
    }

    /// Cache image in both memory and disk
    /// - Parameters:
    ///   - image: The UIImage to cache
    ///   - url: The original URL
    ///   - targetSize: Optional target size (for optimized versions)
    ///   - saveToDisk: Whether to persist to disk (default: true)
    func cacheImage(_ image: UIImage, for url: String, targetSize: CGSize? = nil, saveToDisk: Bool = true) {
        let key = cacheKey(for: url, targetSize: targetSize)
        let nsKey = key as NSString

        // Calculate cost (approximate bytes)
        let cost = Int(image.size.width * image.size.height * 4) // RGBA
        imageCache.setObject(image, forKey: nsKey, cost: cost)

        print("DEBUG: Cached image - key: \(key.suffix(50)), size: \(image.size)")

        // Save to disk asynchronously only if needed
        if saveToDisk {
            Task.detached {
                await self.saveToDisk(image: image, key: key)
            }
        }
    }

    // MARK: - Download with Optimization

    /// Downloads and optimizes an image with downscaling
    /// This is the primary method for OptimizedAsyncImage to use
    /// - Parameters:
    ///   - url: The image URL
    ///   - targetSize: The target display size for downscaling
    /// - Returns: Optimized UIImage or nil if failed
    func downloadAndOptimize(url: String, targetSize: CGSize) async -> UIImage? {
        let key = cacheKey(for: url, targetSize: targetSize)

        // Check cache first
        if let cached = cachedImage(for: url, targetSize: targetSize) {
            return cached
        }

        // Check if already downloading this exact key
        if let existingTask = downloadTasks[key] {
            return await existingTask.value
        }

        // Create download task with concurrency limiting
        let task = Task { () -> UIImage? in
            // Wait for semaphore (limits concurrent downloads)
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.downloadSemaphore.wait()
                    continuation.resume()
                }
            }

            defer {
                downloadSemaphore.signal()
            }

            guard let urlObj = URL(string: url) else {
                print("DEBUG: Invalid URL: \(url)")
                return nil
            }

            do {
                print("DEBUG: Downloading image: \(url.suffix(50))")
                let (data, response) = try await URLSession.shared.data(from: urlObj)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("DEBUG: HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    return nil
                }

                // Create optimized image with downscaling
                guard let optimizedImage = await self.createOptimizedImage(
                    from: data,
                    targetSize: targetSize
                ) else {
                    print("DEBUG: Failed to create optimized image")
                    return nil
                }

                print("DEBUG: Image downloaded and optimized: \(url.suffix(50))")

                // Cache the optimized image
                await self.cacheImage(optimizedImage, for: url, targetSize: targetSize)

                return optimizedImage

            } catch {
                print("DEBUG: Download error: \(error.localizedDescription)")
                return nil
            }
        }

        downloadTasks[key] = task
        let image = await task.value
        downloadTasks.removeValue(forKey: key)

        return image
    }

    /// Downloads an image without optimization (original size)
    /// - Parameters:
    ///   - urlString: The image URL
    ///   - retries: Number of retry attempts (default: 3)
    /// - Returns: UIImage or nil if failed
    func downloadImage(from urlString: String, retries: Int = 3) async -> UIImage? {
        let normalized = normalizeImageURLKey(urlString)

        // Check cache first
        if let cached = cachedImage(for: normalized) {
            return cached
        }

        // Check if already downloading
        if let existingTask = downloadTasks[normalized] {
            return await existingTask.value
        }

        // Create download task
        let task = Task { () -> UIImage? in
            // Wait for semaphore (limits concurrent downloads)
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.downloadSemaphore.wait()
                    continuation.resume()
                }
            }

            defer {
                downloadSemaphore.signal()
            }

            guard let url = URL(string: normalized) else {
                print("DEBUG: Invalid URL: \(urlString)")
                return nil
            }

            // Retry logic
            for attempt in 1...retries {
                do {
                    print("DEBUG: Downloading image (attempt \(attempt)/\(retries)): \(normalized.suffix(50))")
                    let (data, response) = try await URLSession.shared.data(from: url)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        print("DEBUG: HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                        if attempt < retries {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) // Exponential backoff
                            continue
                        }
                        return nil
                    }

                    guard let image = UIImage(data: data) else {
                        print("DEBUG: Invalid image data")
                        return nil
                    }

                    print("DEBUG: Image downloaded successfully: \(normalized.suffix(50))")

                    // Cache the image
                    await self.cacheImage(image, for: normalized)

                    return image

                } catch {
                    print("DEBUG: Download error (attempt \(attempt)/\(retries)): \(error.localizedDescription)")
                    if attempt < retries {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                        continue
                    }
                    return nil
                }
            }

            return nil
        }

        downloadTasks[normalized] = task
        let image = await task.value
        downloadTasks.removeValue(forKey: normalized)

        return image
    }

    /// Preload next images for smooth experience
    func preloadImages(_ urls: [String]) {
        Task {
            for url in urls {
                let normalized = normalizeImageURLKey(url)
                guard cachedImage(for: normalized) == nil else { continue }
                _ = await downloadImage(from: normalized)
            }
        }
    }

    // MARK: - Image Optimization

    /// Creates an optimized (downscaled) image from data
    /// Uses ImageIO for memory-efficient downsampling
    private func createOptimizedImage(from data: Data, targetSize: CGSize) async -> UIImage? {
        // Use ImageIO for efficient downscaling without loading full image into memory
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Get screen scale on main actor first
        let screenScale = await MainActor.run { UIScreen.main.scale }
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * screenScale

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            0,
            downsampleOptions as CFDictionary
        ) else {
            return nil
        }

        return UIImage(cgImage: downsampledImage)
    }

    // MARK: - Disk Operations

    private nonisolated func diskCacheFilePath(for key: String) -> URL {
        // Use SHA256 hash to create unique, filesystem-safe filename
        let hash = SHA256.hash(data: Data(key.utf8))
        let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appendingPathComponent(filename + ".jpg")
    }

    private func saveToDisk(image: UIImage, key: String) {
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            let filePath = self.diskCacheFilePath(for: key)

            guard let data = image.jpegData(compressionQuality: 0.8) else { return }

            do {
                try data.write(to: filePath, options: .atomic)
                print("DEBUG: Saved to disk: \(key.suffix(50))")
            } catch {
                print("DEBUG: Disk save error: \(error.localizedDescription)")
            }
        }
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let filePath = diskCacheFilePath(for: key)

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

        // Load data first to avoid memory-mapping issues
        guard let data = try? Data(contentsOf: filePath) else {
            return nil
        }

        return UIImage(data: data)
    }

    // MARK: - Cache Management

    /// Clear all caches (memory + disk)
    func clearAllCaches() {
        // Clear memory
        imageCache.removeAllObjects()

        // Clear disk
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Reset metrics
        resetMetrics()

        print("DEBUG: All image caches cleared")
    }

    /// Clear only memory cache
    func clearMemoryCache() {
        imageCache.removeAllObjects()
        print("DEBUG: Memory cache cleared")
    }

    /// Calculate disk cache size in bytes
    private func calculateDiskCacheSize() -> Int64 {
        let diskSize = try? FileManager.default
            .contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(Int64(0)) { total, url in
                let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                return total + Int64(size ?? 0)
            }
        return diskSize ?? 0
    }

    /// Clean old cache files and enforce size limits
    private func cleanOldCache() async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                let fileManager = FileManager.default
                guard let files = try? fileManager.contentsOfDirectory(
                    at: self.diskCacheURL,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
                ) else {
                    continuation.resume()
                    return
                }

                // Calculate total cache size and collect file info
                var cacheSize = 0
                var fileInfos: [(url: URL, size: Int, date: Date)] = []

                for fileURL in files {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                          let fileSize = resourceValues.fileSize,
                          let modDate = resourceValues.contentModificationDate else {
                        continue
                    }

                    cacheSize += fileSize
                    fileInfos.append((url: fileURL, size: fileSize, date: modDate))
                }

                // Remove files older than maxCacheAge
                let cutoffDate = Date().addingTimeInterval(-self.maxCacheAge)
                for fileInfo in fileInfos where fileInfo.date < cutoffDate {
                    try? fileManager.removeItem(at: fileInfo.url)
                    cacheSize -= fileInfo.size
                }

                // Remove old files if cache is still too large
                if cacheSize > self.maxDiskCacheSize {
                    // Sort by date (oldest first)
                    let sortedFiles = fileInfos.filter { $0.date >= cutoffDate }.sorted { $0.date < $1.date }

                    var currentSize = cacheSize
                    for fileInfo in sortedFiles {
                        guard currentSize > self.maxDiskCacheSize else { break }

                        try? fileManager.removeItem(at: fileInfo.url)
                        currentSize -= fileInfo.size
                    }
                }

                print("DEBUG: Cache cleanup completed. Current disk size: \(cacheSize / 1024 / 1024) MB")
                continuation.resume()
            }
        }
    }

    deinit {
        #if DEBUG
        print("DEBUG: ImageCacheManager deinit")
        #endif
    }
}

// MARK: - Key Normalization Helper

/// Normalizes image URL for consistent cache key generation
fileprivate func normalizeImageURLKey(_ url: String) -> String {
    var s = url.trimmingCharacters(in: .whitespacesAndNewlines)
    // Remove stray trailing '?' when there is no query
    if s.hasSuffix("?") { s.removeLast() }
    // Remove trailing '#'
    if s.hasSuffix("#") { s.removeLast() }
    return s
}
