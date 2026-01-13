//
//  CachedAsyncImage.swift
//  Gym_API
//
//  SwiftUI component for loading images with advanced caching
//  Uses ImageCacheManager for memory + disk caching
//

import SwiftUI

/// SwiftUI view that loads images with caching support
/// Drop-in replacement for AsyncImage with better performance
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = ImageLoader()
    @Environment(\.imageScale) private var scale

    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task {
            await loader.load(url: url)
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    /// Simple initializer with default placeholder
    init(url: String?) {
        self.init(
            url: url,
            content: { image in image },
            placeholder: { Color.gray }
        )
    }
}

extension CachedAsyncImage where Placeholder == Color {
    /// Initializer with custom content builder
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            content: content,
            placeholder: { Color.gray }
        )
    }
}

extension CachedAsyncImage where Content == Image {
    /// Initializer with custom placeholder
    init(
        url: String?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            content: { image in image },
            placeholder: placeholder
        )
    }
}

// MARK: - Image Loader

@MainActor
private class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?

    private let cacheManager = ImageCacheManager.shared
    private var currentTask: Task<Void, Never>?

    func load(url: String?) async {
        guard let url = url, !url.isEmpty else {
            print("DEBUG: ❌ CachedAsyncImage: Invalid or empty URL")
            return
        }

        // Cancel any existing task
        currentTask?.cancel()

        // Check cache first (synchronous)
        if let cached = cacheManager.cachedImage(for: url) {
            print("DEBUG: ⚡ CachedAsyncImage: Using cached image")
            self.image = cached
            return
        }

        // Download if not cached
        currentTask = Task {
            isLoading = true

            if let downloaded = await cacheManager.downloadImage(from: url) {
                if !Task.isCancelled {
                    self.image = downloaded
                    self.error = nil
                    print("DEBUG: ✅ CachedAsyncImage: Image loaded and cached")
                }
            } else {
                if !Task.isCancelled {
                    print("DEBUG: ❌ CachedAsyncImage: Failed to download image")
                }
            }

            isLoading = false
        }

        await currentTask?.value
    }

    deinit {
        currentTask?.cancel()
    }
}

// MARK: - Story-Specific Variants

/// Specialized version for Story images with enhanced loading UI
struct StoryImageView: View {
    let url: String?

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFit() // Cambiado para mostrar imagen completa sin recortes
        } placeholder: {
            ZStack {
                Color.gray

                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text("Cargando...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

/// Story image with error handling
struct StoryImageWithError: View {
    let url: String?
    @StateObject private var loader = EnhancedImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit() // Cambiado para mostrar imagen completa sin recortes
            } else if loader.isLoading {
                ZStack {
                    Color.gray

                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Cargando...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else if loader.error != nil {
                ZStack {
                    Color.gray

                    VStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))

                        Text("Error al cargar imagen")
                            .font(.caption)
                            .foregroundColor(.white)

                        if let error = loader.error {
                            Text(error.localizedDescription)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        Button {
                            Task {
                                await loader.load(url: url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Reintentar")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                        }
                    }
                }
            } else {
                ZStack {
                    Color.gray

                    Image(systemName: "photo.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .task {
            await loader.load(url: url)
        }
    }
}

// MARK: - Enhanced Loader with Error Tracking

@MainActor
private class EnhancedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?

    private let cacheManager = ImageCacheManager.shared
    private var currentTask: Task<Void, Never>?

    func load(url: String?) async {
        guard let url = url, !url.isEmpty else {
            print("DEBUG: ❌ EnhancedImageLoader: Invalid or empty URL")
            return
        }

        print("DEBUG: 🔄 EnhancedImageLoader: Loading URL: \(url)")

        // Cancel any existing task
        currentTask?.cancel()

        // Reset state
        error = nil

        // Check cache first
        if let cached = cacheManager.cachedImage(for: url) {
            print("DEBUG: ⚡ EnhancedImageLoader: Using cached image for \(url.suffix(50))")
            self.image = cached
            return
        }

        // Download
        currentTask = Task {
            isLoading = true

            if let downloaded = await cacheManager.downloadImage(from: url) {
                if !Task.isCancelled {
                    self.image = downloaded
                    self.error = nil
                }
            } else {
                if !Task.isCancelled {
                    self.error = NSError(
                        domain: "ImageLoader",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No se pudo cargar la imagen"]
                    )
                }
            }

            isLoading = false
        }

        await currentTask?.value
    }

    deinit {
        currentTask?.cancel()
    }
}

// MARK: - Preview

struct CachedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Simple usage
            CachedAsyncImage(url: "https://via.placeholder.com/300")
                .frame(width: 300, height: 300)

            // Custom content
            CachedAsyncImage(url: "https://via.placeholder.com/300") { image in
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            }
            .frame(width: 100, height: 100)

            // Story variant
            StoryImageView(url: "https://via.placeholder.com/400x600")
                .frame(height: 400)

            // With error handling
            StoryImageWithError(url: "https://invalid-url.com/image.jpg")
                .frame(height: 400)
        }
    }
}
