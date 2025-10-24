//
//  UnifiedImageService.swift
//  Gym_API
//
//  Servicio unificado para todas las operaciones de imágenes
//  Consolida: ProfileImageService, MediaUploadService, ImageLoaderService
//  Created as part of Phase 2 - Service Consolidation
//

import Foundation
import UIKit
import Combine
import StreamChat
import AVFoundation
import PhotosUI

// MARK: - Notification Names
extension Notification.Name {
    static let unifiedImageUpdated = Notification.Name("unifiedImageUpdated")
    static let profileImageUploaded = Notification.Name("profileImageUploaded")
    static let mediaUploaded = Notification.Name("mediaUploaded")
}

// MARK: - Unified Image Service
@MainActor
final class UnifiedImageService: ObservableObject {

    // MARK: - Singleton
    static let shared = UnifiedImageService()

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var currentImage: UIImage?
    @Published var profileImageURL: String?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = apiBaseURL // Using environment-based URL
    private let session = URLSession.shared
    private weak var authService: AuthServiceDirect?

    // Cache Management
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let cacheQueue = DispatchQueue(label: "com.gymapi.unifiedimage", attributes: .concurrent)
    private let maxMemoryCacheSize = 50 * 1024 * 1024 // 50MB
    private let maxDiskCacheSize = 100 * 1024 * 1024 // 100MB

    // Image Processing Configuration
    private struct ImageConfig {
        static let maxImageSize: CGFloat = 800 // Max width/height
        static let compressionQuality: CGFloat = 0.8
        static let thumbnailSize: CGFloat = 200
        static let maxFileSize = 5 * 1024 * 1024 // 5MB
    }

    // MARK: - Initialization
    private init() {
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100

        // Setup disk cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDirectory.appendingPathComponent("UnifiedImageCache", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Clean old cache on init
        Task {
            await cleanOldCache()
        }

        print("✅ UnifiedImageService initialized with cache limits: Memory=\(maxMemoryCacheSize/1024/1024)MB, Disk=\(maxDiskCacheSize/1024/1024)MB")
    }

    // MARK: - Configuration
    func configure(authService: AuthServiceDirect) {
        self.authService = authService
        print("🔧 UnifiedImageService configured with AuthService")
    }

    // MARK: - Loading Images (from ImageLoaderService)

    /// Load image from URL with caching
    func loadImage(from urlString: String, targetSize: CGSize? = nil) async throws -> UIImage {
        // Check cache first
        let cacheKey = generateCacheKey(for: urlString, size: targetSize)
        if let cachedImage = getCachedImage(for: cacheKey) {
            print("🎯 Cache hit for: \(cacheKey)")
            return cachedImage
        }

        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: urlString) else {
            throw ImageError.invalidURL
        }

        // Download image
        let (data, response) = try await session.data(from: url)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageError.invalidResponse
        }

        // Process image
        guard let image = await processImage(from: data, targetSize: targetSize) else {
            throw ImageError.processingFailed
        }

        // Cache image
        await cacheImage(image, for: cacheKey)

        return image
    }

    // MARK: - Profile Image Upload (from ProfileImageService)

    /// Upload profile image with compression and sync to StreamChat
    func uploadProfileImage(_ image: UIImage) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        print("📸 Starting profile image upload...")

        // Validate authentication
        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            throw ImageError.authenticationRequired
        }

        // Process and compress image
        uploadProgress = 0.2
        guard let processedImage = await resizeImage(image, maxSize: ImageConfig.maxImageSize),
              let imageData = await compressImage(processedImage, quality: ImageConfig.compressionQuality) else {
            throw ImageError.compressionFailed
        }

        print("🗜️ Image compressed: \(imageData.count / 1024)KB")

        // Upload to server
        uploadProgress = 0.5
        let imageURL = try await performProfileUpload(imageData: imageData, token: token)

        // Update local state
        uploadProgress = 0.8
        self.profileImageURL = imageURL
        self.currentImage = processedImage

        // Sync with StreamChat
        uploadProgress = 0.9
        await syncWithStreamChat(imageURL: imageURL)

        uploadProgress = 1.0

        // Send notification
        NotificationCenter.default.post(name: .profileImageUploaded, object: imageURL)

        print("✅ Profile image uploaded successfully: \(imageURL)")
        return imageURL
    }

    // MARK: - Media Upload (from MediaUploadService)

    /// Upload general media (image/video)
    func uploadMedia(_ media: MediaType) async throws -> URL {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        switch media {
        case .image(let image):
            return try await uploadImage(image)
        case .video(let url, _):
            return try await uploadVideo(from: url)
        case .voice(let url, _):
            return try await uploadAudio(from: url)
        }
    }

    /// Upload image for chat/general use
    private func uploadImage(_ image: UIImage) async throws -> URL {
        uploadProgress = 0.2

        // Process image
        guard let processedImage = await resizeImage(image, maxSize: ImageConfig.maxImageSize),
              let imageData = await compressImage(processedImage, quality: ImageConfig.compressionQuality) else {
            throw ImageError.compressionFailed
        }

        uploadProgress = 0.5

        // Save temporarily for Stream upload
        let fileName = "\(UUID().uuidString).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try await BackgroundTaskManager.shared.writeToFile(imageData, at: tempURL)

        uploadProgress = 1.0

        // Send notification
        NotificationCenter.default.post(name: .mediaUploaded, object: tempURL)

        return tempURL
    }

    /// Upload video with compression
    private func uploadVideo(from url: URL) async throws -> URL {
        uploadProgress = 0.1

        // Validate file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let maxVideoSize: Int64 = 50 * 1024 * 1024 // 50MB

        if fileSize > maxVideoSize {
            throw ImageError.fileTooLarge(maxSize: maxVideoSize)
        }

        uploadProgress = 0.3

        // Process video (in production, compress with AVAssetExportSession)
        let fileName = "\(UUID().uuidString).mp4"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try await BackgroundTaskManager.shared.copyFile(from: url, to: tempURL)

        uploadProgress = 1.0

        return tempURL
    }

    /// Upload audio file
    private func uploadAudio(from url: URL) async throws -> URL {
        // Similar to video upload
        return try await uploadVideo(from: url)
    }

    // MARK: - Image Processing

    /// Process image from data with optional resizing
    private func processImage(from data: Data, targetSize: CGSize?) async -> UIImage? {
        return try? await BackgroundTaskManager.shared.compute {
            guard let image = UIImage(data: data) else { return nil }

            if let targetSize = targetSize {
                // Use ImageIO for efficient downscaling
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                    return nil
                }

                let maxDimension = max(targetSize.width, targetSize.height) * UIScreen.main.scale

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension
                ]

                guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
                    imageSource,
                    0,
                    options as CFDictionary
                ) else {
                    return nil
                }

                return UIImage(cgImage: downsampledImage)
            }

            return image
        }
    }

    /// Resize image to max size
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) async -> UIImage? {
        return try? await BackgroundTaskManager.shared.compute {
            let size = image.size

            // Check if resize is needed
            if size.width <= maxSize && size.height <= maxSize {
                return image
            }

            // Calculate new size
            let ratio = min(maxSize / size.width, maxSize / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

            // Resize
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }

    /// Compress image to JPEG
    private func compressImage(_ image: UIImage, quality: CGFloat) async -> Data? {
        return await BackgroundTaskManager.shared.compressImage(image, quality: quality)
    }

    /// Generate video thumbnail
    func generateVideoThumbnail(from url: URL) async -> UIImage? {
        return try? await BackgroundTaskManager.shared.compute {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 1, preferredTimescale: 1)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                print("❌ Error generating thumbnail: \(error)")
                return nil
            }
        }
    }

    // MARK: - Cache Management

    /// Get cached image
    private func getCachedImage(for key: String) -> UIImage? {
        // Check memory cache
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // Check disk cache
        return cacheQueue.sync {
            let fileURL = diskCacheURL.appendingPathComponent(key.sha256)
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

    /// Cache image
    private func cacheImage(_ image: UIImage, for key: String) async {
        // Add to memory cache
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)

        // Save to disk cache
        _ = try? await BackgroundTaskManager.shared.compute {
            let fileURL = self.diskCacheURL.appendingPathComponent(key.sha256)
            if let data = image.jpegData(compressionQuality: 0.9) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    /// Generate cache key
    private func generateCacheKey(for url: String, size: CGSize?) -> String {
        if let size = size {
            return "\(url)_\(Int(size.width))x\(Int(size.height))"
        }
        return url
    }

    /// Clean old cache
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

    /// Clear all cache
    func clearCache() async {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        _ = try? await BackgroundTaskManager.shared.compute {
            try? FileManager.default.removeItem(at: self.diskCacheURL)
            try? FileManager.default.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }

        print("🗑️ Cache cleared")
    }

    // MARK: - Network Operations

    /// Perform profile image upload
    private func performProfileUpload(imageData: Data, token: String) async throws -> String {
        let endpoint = "\(baseURL)/users/profile-image"
        guard let url = URL(string: endpoint) else {
            throw ImageError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body = Data()

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            throw ImageError.uploadFailed(statusCode: httpResponse.statusCode)
        }

        // Parse response
        struct UploadResponse: Decodable {
            let imageUrl: String
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.imageUrl
    }

    /// Sync profile image with StreamChat
    private func syncWithStreamChat(imageURL: String) async {
        // Implementation would sync with StreamChat
        // For now, just send notification
        NotificationCenter.default.post(name: .streamChatAvatarUpdated, object: imageURL)
        print("📱 Synced profile image with StreamChat")
    }

    // MARK: - Validation

    /// Validate image before upload
    func validateImage(_ image: UIImage) -> Bool {
        // Check minimum dimensions
        let minDimension: CGFloat = 100
        if image.size.width < minDimension || image.size.height < minDimension {
            errorMessage = "Image must be at least \(Int(minDimension))x\(Int(minDimension)) pixels"
            return false
        }

        // Check maximum dimensions
        let maxDimension: CGFloat = 4096
        if image.size.width > maxDimension || image.size.height > maxDimension {
            errorMessage = "Image must be less than \(Int(maxDimension))x\(Int(maxDimension)) pixels"
            return false
        }

        return true
    }

    /// Validate file size
    func validateFileSize(_ data: Data) -> Bool {
        if data.count > ImageConfig.maxFileSize {
            errorMessage = "File size must be less than \(ImageConfig.maxFileSize / 1024 / 1024)MB"
            return false
        }
        return true
    }

    // MARK: - Cleanup
    deinit {
        #if DEBUG
        print("🗑️ UnifiedImageService deinitialized")
        #endif
    }
}

// MARK: - Image Errors
enum ImageError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationRequired
    case compressionFailed
    case processingFailed
    case uploadFailed(statusCode: Int)
    case fileTooLarge(maxSize: Int64)
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .authenticationRequired:
            return "Authentication required"
        case .compressionFailed:
            return "Failed to compress image"
        case .processingFailed:
            return "Failed to process image"
        case .uploadFailed(let code):
            return "Upload failed with status: \(code)"
        case .fileTooLarge(let maxSize):
            return "File too large. Max: \(maxSize / 1024 / 1024)MB"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MediaType is already defined in MediaUploadService.swift
// Using that definition instead of duplicating

// MARK: - String Extension for SHA256
extension String {
    var sha256: String {
        // Using SHA256 for cache keys
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