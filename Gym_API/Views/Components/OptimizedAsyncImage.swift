//
//  OptimizedAsyncImage.swift
//  Gym_API
//
//  Optimized async image loader with downscaling and smart caching
//  Now uses unified ImageCacheManager for single source of truth
//
//  Created as part of performance optimization phase
//  Updated: Consolidated to use ImageCacheManager.shared
//

import SwiftUI
import UIKit

// MARK: - Optimized Async Image View

/// Async image view with automatic downscaling and unified caching
/// Uses ImageCacheManager.shared for all caching operations
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

/// Image loader that uses unified ImageCacheManager for caching
/// Supports cancellation and automatic downscaling
@MainActor
class OptimizedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?

    private var loadingTask: Task<Void, Never>?

    /// Loads an optimized image from URL using unified cache
    /// - Parameters:
    ///   - urlString: The image URL
    ///   - targetSize: Target display size for downscaling
    func loadOptimizedImage(from urlString: String, targetSize: CGSize) {
        // Cancel any existing task
        loadingTask?.cancel()

        // Reset error state
        error = nil

        // Check unified cache first (synchronous check)
        if let cached = ImageCacheManager.shared.cachedImage(for: urlString, targetSize: targetSize) {
            self.image = cached
            return
        }

        // Start loading
        isLoading = true

        loadingTask = Task {
            do {
                // Use unified cache manager for download and optimization
                let optimizedImage = await ImageCacheManager.shared.downloadAndOptimize(
                    url: urlString,
                    targetSize: targetSize
                )

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                if let optimizedImage = optimizedImage {
                    await MainActor.run {
                        self.image = optimizedImage
                        self.isLoading = false
                    }
                } else {
                    // Download failed
                    await MainActor.run {
                        self.error = ImageLoadingError.invalidImageData
                        self.isLoading = false
                        print("DEBUG: OptimizedAsyncImage failed to load: \(urlString.suffix(50))")
                    }
                }
            }
        }
    }

    /// Cancels any in-progress loading task
    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        isLoading = false
    }

    deinit {
        #if DEBUG
        print("DEBUG: OptimizedImageLoader deinit")
        #endif
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
            return "URL invalida"
        case .invalidResponse:
            return "Respuesta del servidor invalida"
        case .invalidImageData:
            return "No se pudo procesar la imagen"
        }
    }
}

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
