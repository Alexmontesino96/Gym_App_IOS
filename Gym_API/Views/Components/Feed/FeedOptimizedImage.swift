//
//  FeedOptimizedImage.swift
//  Gym_API
//
//  Componente optimizado para imágenes del feed con soporte para thumbnails,
//  downscaling automático, y caché integrado para máxima performance.
//  Diseñado específicamente para posts con thumbnails generados por el backend.
//
//  EJEMPLO DE USO:
//
//  ```swift
//  // En PostCardView o cualquier vista del feed:
//  let media = post.media.first
//
//  FeedOptimizedImage(
//      thumbnailUrl: media?.thumbnailUrl,  // Thumbnail generado por backend
//      fullUrl: media?.mediaUrl ?? "",     // Fallback a imagen completa
//      displaySize: CGSize(width: screenWidth, height: 300),
//      contentMode: .fill,
//      cornerRadius: 12
//  )
//  ```
//
//  PERFORMANCE NOTES:
//  - Usa thumbnail automáticamente si está disponible (carga ~10x más rápida)
//  - Downscaling reduce memoria hasta 75% comparado con imagen completa
//  - Caché previene descargas duplicadas en scroll
//  - Task cancellation evita memory leaks al hacer scroll rápido
//

import SwiftUI
import UIKit
import CommonCrypto

// MARK: - Feed Optimized Image

/// Componente de imagen optimizado para el feed social
/// Features:
/// - Selección inteligente thumbnail/full URL
/// - Downscaling automático basado en displaySize
/// - Caché en memoria y disco integrado
/// - Cancelación de tareas en disappear
/// - Estados visuales claros (loading/error/success)
struct FeedOptimizedImage: View {
    // MARK: - Properties

    /// URL del thumbnail (opcional, priorizado para carga rápida)
    let thumbnailUrl: String?

    /// URL completa de la imagen (fallback si no hay thumbnail)
    let fullUrl: String

    /// Tamaño de display para calcular el downscaling óptimo
    let displaySize: CGSize

    /// Modo de contenido (fill o fit)
    var contentMode: ContentMode = .fill

    /// Radio de esquinas para el contenedor
    var cornerRadius: CGFloat = 0

    // MARK: - State

    @StateObject private var loader = FeedImageLoader()
    @State private var hasAppeared = false

    // MARK: - Body

    var body: some View {
        ZStack {
            if let image = loader.image {
                // Success: Mostrar imagen con fade-in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else if loader.isLoading {
                // Loading: Shimmer placeholder
                ShimmerPlaceholder()
                    .frame(width: displaySize.width, height: displaySize.height)
            } else if loader.hasError {
                // Error: Mostrar icono con boton de retry
                FeedErrorStateView(displaySize: displaySize) {
                    Task {
                        await loader.loadOptimizedImage(
                            thumbnailUrl: thumbnailUrl,
                            fullUrl: fullUrl,
                            targetSize: displaySize
                        )
                    }
                }
            } else {
                // Initial: Placeholder gris
                Color.gray.opacity(0.15)
                    .frame(width: displaySize.width, height: displaySize.height)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .cornerRadius(cornerRadius)
        .onAppear {
            // Solo cargar una vez cuando aparece
            if !hasAppeared {
                hasAppeared = true
                Task {
                    await loader.loadOptimizedImage(
                        thumbnailUrl: thumbnailUrl,
                        fullUrl: fullUrl,
                        targetSize: displaySize
                    )
                }
            }
        }
        .onDisappear {
            // Cancelar descarga si la vista desaparece
            loader.cancelLoading()
        }
    }
}

// MARK: - Feed Image Loader

/// Loader especializado para imágenes del feed con thumbnail support
@MainActor
final class FeedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var hasError = false

    private var loadingTask: Task<Void, Never>?
    private let cacheManager = ImageCacheManager.shared

    /// Carga imagen optimizada con selección inteligente de URL
    func loadOptimizedImage(
        thumbnailUrl: String?,
        fullUrl: String,
        targetSize: CGSize
    ) async {
        // Cancelar cualquier tarea existente
        loadingTask?.cancel()

        // Reset estados
        hasError = false

        // Seleccionar URL óptima (thumbnail preferido)
        let selectedUrl = thumbnailUrl ?? fullUrl

        // Generar cache key único que incluye tamaño
        let cacheKey = generateCacheKey(url: selectedUrl, size: targetSize)

        // Verificar caché primero (memoria + disco)
        if let cached = cacheManager.cachedImage(for: cacheKey) {
            self.image = cached
            return
        }

        // Iniciar carga
        isLoading = true

        loadingTask = Task {
            do {
                // Descargar y optimizar imagen
                let optimizedImage = try await downloadAndOptimize(
                    url: selectedUrl,
                    targetSize: targetSize
                )

                // Verificar si la tarea fue cancelada
                guard !Task.isCancelled else { return }

                // Guardar en caché y mostrar
                cacheManager.cacheImage(optimizedImage, for: cacheKey)

                await MainActor.run {
                    self.image = optimizedImage
                    self.isLoading = false
                    self.hasError = false
                }
            } catch {
                // Verificar si la tarea fue cancelada
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                    print("❌ FeedOptimizedImage: Error cargando imagen - \(error.localizedDescription)")
                }
            }
        }

        await loadingTask?.value
    }

    /// Cancela la carga en progreso
    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        isLoading = false
    }

    // MARK: - Private Methods

    /// Descarga y optimiza la imagen con downscaling
    private func downloadAndOptimize(url: String, targetSize: CGSize) async throws -> UIImage {
        guard let imageUrl = URL(string: url) else {
            throw FeedImageError.invalidURL
        }

        // Descargar datos
        let (data, response) = try await URLSession.shared.data(from: imageUrl)

        // Validar respuesta HTTP
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FeedImageError.invalidResponse
        }

        // Optimizar imagen con downscaling en background
        guard let optimized = await downscaleImage(data: data, targetSize: targetSize) else {
            throw FeedImageError.invalidImageData
        }

        return optimized
    }

    /// Downscale imagen usando ImageIO para máxima eficiencia
    private func downscaleImage(data: Data, targetSize: CGSize) async -> UIImage? {
        return try? await BackgroundTaskManager.shared.compute {
            // Crear image source desde datos
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }

            // Calcular dimensión máxima en píxeles (considerando escala de pantalla)
            let scale = UIScreen.main.scale
            let maxDimensionInPixels = max(targetSize.width, targetSize.height) * scale

            // Opciones de downsampling
            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
            ]

            // Crear thumbnail optimizado
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

    /// Genera una cache key única basada en URL y tamaño
    private func generateCacheKey(url: String, size: CGSize) -> String {
        let sizeString = "\(Int(size.width))x\(Int(size.height))"
        return "\(url)_\(sizeString)"
    }

    deinit {
        loadingTask?.cancel()
    }
}

// MARK: - Shimmer Placeholder

/// Placeholder animado con efecto shimmer para estado loading
private struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.25),
                        Color.gray.opacity(0.15)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: phase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 200
                }
            }
    }
}

// MARK: - Feed Error State View

/// Vista de error con boton de retry (especifica para FeedOptimizedImage)
private struct FeedErrorStateView: View {
    let displaySize: CGSize
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red.opacity(0.7))

            Text("Error al cargar")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onRetry) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text("Reintentar")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .background(Color.gray.opacity(0.15))
    }
}

// MARK: - Feed Image Error

/// Errores específicos del loader de imágenes del feed
enum FeedImageError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidImageData
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de imagen inválida"
        case .invalidResponse:
            return "Respuesta del servidor inválida"
        case .invalidImageData:
            return "No se pudo procesar la imagen"
        case .downloadFailed:
            return "Error al descargar la imagen"
        }
    }
}

// MARK: - Preview Provider

struct FeedOptimizedImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Caso 1: Con thumbnail
            FeedOptimizedImage(
                thumbnailUrl: "https://picsum.photos/200/200",
                fullUrl: "https://picsum.photos/800/800",
                displaySize: CGSize(width: 150, height: 150),
                contentMode: .fill,
                cornerRadius: 12
            )

            // Caso 2: Sin thumbnail (solo full URL)
            FeedOptimizedImage(
                thumbnailUrl: nil,
                fullUrl: "https://picsum.photos/800/600",
                displaySize: CGSize(width: UIScreen.main.bounds.width - 32, height: 250),
                contentMode: .fill,
                cornerRadius: 8
            )

            // Caso 3: Cuadrada para grid
            FeedOptimizedImage(
                thumbnailUrl: "https://picsum.photos/300/300",
                fullUrl: "https://picsum.photos/1200/1200",
                displaySize: CGSize(width: 100, height: 100),
                contentMode: .fill,
                cornerRadius: 4
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
