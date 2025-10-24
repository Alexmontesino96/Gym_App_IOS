//
//  OptimizedAsyncImage.swift
//  Gym_API
//
//  Optimized async image loader with downscaling and smart caching
//  Created as part of performance optimization phase
//

import SwiftUI
import UIKit

// MARK: - Optimized Async Image View
struct OptimizedAsyncImage: View {
    let url: String
    let displaySize: CGSize
    var placeholder: (() -> AnyView)?
    var errorView: (() -> AnyView)?
    var contentMode: ContentMode = .fill

    @StateObject private var loader = OptimizedImageLoader()
    @State private var hasAppeared = false

    init(
        url: String,
        displaySize: CGSize,
        placeholder: (() -> AnyView)? = nil,
        errorView: (() -> AnyView)? = nil,
        contentMode: ContentMode = .fill
    ) {
        self.url = url
        self.displaySize = displaySize
        self.placeholder = placeholder
        self.errorView = errorView
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if loader.isLoading {
                if let placeholder = placeholder {
                    placeholder()
                } else {
                    ProgressView()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .background(Color.gray.opacity(0.1))
                }
            } else if loader.error != nil {
                if let errorView = errorView {
                    errorView()
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .background(Color.gray.opacity(0.1))
                }
            } else {
                if let placeholder = placeholder {
                    placeholder()
                } else {
                    Color.gray.opacity(0.1)
                        .frame(width: displaySize.width, height: displaySize.height)
                }
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                loader.loadOptimizedImage(from: url, targetSize: displaySize)
            }
        }
        .onDisappear {
            // Cancel loading if view disappears
            loader.cancelLoading()
        }
    }
}

// MARK: - Optimized Image Loader
@MainActor
class OptimizedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?

    private var loadingTask: Task<Void, Never>?
    private static let imageCache = ImageCache.shared

    func loadOptimizedImage(from urlString: String, targetSize: CGSize) {
        // Cancel any existing task
        loadingTask?.cancel()

        // Reset state
        error = nil

        // Check cache first
        let cacheKey = "\(urlString)_\(Int(targetSize.width))x\(Int(targetSize.height))"
        if let cached = Self.imageCache.getImage(for: cacheKey) {
            self.image = cached
            return
        }

        // Start loading
        isLoading = true

        loadingTask = Task {
            do {
                // Load and optimize image
                let optimizedImage = try await loadAndOptimizeImage(
                    from: urlString,
                    targetSize: targetSize
                )

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // Cache and display
                Self.imageCache.setImage(optimizedImage, for: cacheKey)

                await MainActor.run {
                    self.image = optimizedImage
                    self.isLoading = false
                }
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    print("❌ OptimizedAsyncImage: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        isLoading = false
    }

    private func loadAndOptimizeImage(from urlString: String, targetSize: CGSize) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw ImageLoadingError.invalidURL
        }

        // Download image data
        let (data, response) = try await URLSession.shared.data(from: url)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageLoadingError.invalidResponse
        }

        // Create image from data with downscaling
        guard let image = await createOptimizedImage(from: data, targetSize: targetSize) else {
            throw ImageLoadingError.invalidImageData
        }

        return image
    }

    private func createOptimizedImage(from data: Data, targetSize: CGSize) async -> UIImage? {
        return try? await BackgroundTaskManager.shared.compute {
            // Use ImageIO for efficient downscaling
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }

            let maxDimensionInPixels = max(targetSize.width, targetSize.height) * UIScreen.main.scale

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
    }
}

// MARK: - Image Cache
class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let cacheQueue = DispatchQueue(label: "com.gymapi.imagecache", attributes: .concurrent)
    private let maxMemoryCacheSize = 50 * 1024 * 1024 // 50MB
    private let maxDiskCacheSize = 100 * 1024 * 1024 // 100MB

    private init() {
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100

        // Setup disk cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDirectory.appendingPathComponent("OptimizedImages", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Clean old cache on init
        Task {
            await cleanOldCache()
        }
    }

    func getImage(for key: String) -> UIImage? {
        // Check memory cache
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // Check disk cache
        return cacheQueue.sync {
            let fileURL = diskCacheURL.appendingPathComponent(key.md5)
            guard let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else {
                return nil
            }

            // Add to memory cache
            let cost = Int(image.size.width * image.size.height * 4)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)

            return image
        }
    }

    func setImage(_ image: UIImage, for key: String) {
        // Add to memory cache
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)

        // Save to disk cache asynchronously
        cacheQueue.async(flags: .barrier) {
            let fileURL = self.diskCacheURL.appendingPathComponent(key.md5)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private func cleanOldCache() async {
        _ = try? await BackgroundTaskManager.shared.compute {
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(
                at: self.diskCacheURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            ) else { return }

            // Calculate total cache size
            var cacheSize = 0
            var fileInfos: [(url: URL, size: Int, date: Date)] = []

            for fileURL in files {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                      let fileSize = resourceValues.fileSize,
                      let creationDate = resourceValues.creationDate else {
                    continue
                }

                cacheSize += fileSize
                fileInfos.append((url: fileURL, size: fileSize, date: creationDate))
            }

            // Remove old files if cache is too large
            if cacheSize > self.maxDiskCacheSize {
                // Sort by date (oldest first)
                fileInfos.sort { $0.date < $1.date }

                var currentSize = cacheSize
                for fileInfo in fileInfos {
                    guard currentSize > self.maxDiskCacheSize else { break }

                    try? fileManager.removeItem(at: fileInfo.url)
                    currentSize -= fileInfo.size
                }
            }

            // Remove files older than 7 days
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            for fileInfo in fileInfos where fileInfo.date < sevenDaysAgo {
                try? fileManager.removeItem(at: fileInfo.url)
            }
        }
    }
}

// MARK: - Errors
enum ImageLoadingError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta del servidor inválida"
        case .invalidImageData:
            return "No se pudo procesar la imagen"
        }
    }
}

// MARK: - String SHA256 Extension
extension String {
    var md5: String {
        // Using SHA256 instead of MD5 for security
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import for SHA256
import CommonCrypto

// MARK: - Preview Provider
struct OptimizedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        OptimizedAsyncImage(
            url: "https://example.com/image.jpg",
            displaySize: CGSize(width: 200, height: 200),
            placeholder: {
                AnyView(
                    ProgressView()
                        .frame(width: 200, height: 200)
                        .background(Color.gray.opacity(0.2))
                )
            }
        )
    }
}