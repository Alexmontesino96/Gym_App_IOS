import UIKit
import CoreImage

/// Utilidad para comprimir y redimensionar imágenes antes de subirlas
final class ImageCompressor {

    // MARK: - Configuration

    struct CompressionConfig {
        /// Calidad de compresión JPEG (0.0 a 1.0)
        let quality: CGFloat

        /// Ancho máximo en píxeles (nil = sin límite)
        let maxWidth: CGFloat?

        /// Alto máximo en píxeles (nil = sin límite)
        let maxHeight: CGFloat?

        /// Tamaño máximo del archivo en bytes (nil = sin límite)
        let maxFileSizeBytes: Int?

        static let high = CompressionConfig(
            quality: 0.9,
            maxWidth: 2048,
            maxHeight: 2048,
            maxFileSizeBytes: 5 * 1024 * 1024 // 5 MB
        )

        static let medium = CompressionConfig(
            quality: 0.8,
            maxWidth: 1920,
            maxHeight: 1920,
            maxFileSizeBytes: 3 * 1024 * 1024 // 3 MB
        )

        static let low = CompressionConfig(
            quality: 0.6,
            maxWidth: 1280,
            maxHeight: 1280,
            maxFileSizeBytes: 1 * 1024 * 1024 // 1 MB
        )

        static let thumbnail = CompressionConfig(
            quality: 0.7,
            maxWidth: 300,
            maxHeight: 300,
            maxFileSizeBytes: 200 * 1024 // 200 KB
        )
    }

    // MARK: - Compression Methods

    /// Comprime una imagen según la configuración especificada
    /// - Parameters:
    ///   - image: Imagen original
    ///   - config: Configuración de compresión
    /// - Returns: Imagen comprimida o nil si falla
    static func compress(_ image: UIImage, config: CompressionConfig = .medium) -> UIImage? {
        var processedImage = image

        // 1. Redimensionar si es necesario
        if let maxWidth = config.maxWidth, let maxHeight = config.maxHeight {
            processedImage = resize(processedImage, maxWidth: maxWidth, maxHeight: maxHeight)
        }

        // 2. Comprimir con calidad especificada
        guard var imageData = processedImage.jpegData(compressionQuality: config.quality) else {
            return nil
        }

        // 3. Ajustar calidad si excede el tamaño máximo
        if let maxSize = config.maxFileSizeBytes, imageData.count > maxSize {
            var quality = config.quality
            let step: CGFloat = 0.1

            while imageData.count > maxSize && quality > 0.1 {
                quality -= step
                if let compressedData = processedImage.jpegData(compressionQuality: quality) {
                    imageData = compressedData
                } else {
                    break
                }
            }

            #if DEBUG
            print("📸 ImageCompressor: Ajustada calidad a \(quality) para cumplir límite de tamaño")
            #endif
        }

        return UIImage(data: imageData)
    }

    /// Redimensiona una imagen manteniendo la relación de aspecto
    /// - Parameters:
    ///   - image: Imagen original
    ///   - maxWidth: Ancho máximo
    ///   - maxHeight: Alto máximo
    /// - Returns: Imagen redimensionada
    static func resize(_ image: UIImage, maxWidth: CGFloat, maxHeight: CGFloat) -> UIImage {
        let size = image.size
        let widthRatio = maxWidth / size.width
        let heightRatio = maxHeight / size.height
        let ratio = min(widthRatio, heightRatio, 1.0)

        // Si la imagen ya es más pequeña, no redimensionar
        if ratio >= 1.0 {
            return image
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        #if DEBUG
        print("📸 ImageCompressor: Redimensionando de \(size) a \(newSize)")
        #endif

        return resizeImage(image, to: newSize)
    }

    /// Crea un thumbnail de una imagen
    /// - Parameters:
    ///   - image: Imagen original
    ///   - size: Tamaño del thumbnail (cuadrado)
    /// - Returns: Thumbnail
    static func createThumbnail(_ image: UIImage, size: CGFloat = 300) -> UIImage? {
        let config = CompressionConfig(
            quality: 0.7,
            maxWidth: size,
            maxHeight: size,
            maxFileSizeBytes: 200 * 1024
        )
        return compress(image, config: config)
    }

    // MARK: - Helper Methods

    private static func resizeImage(_ image: UIImage, to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    /// Obtiene el tamaño de la imagen comprimida en bytes
    /// - Parameters:
    ///   - image: Imagen
    ///   - quality: Calidad de compresión
    /// - Returns: Tamaño en bytes
    static func getCompressedSize(_ image: UIImage, quality: CGFloat = 0.8) -> Int {
        return image.jpegData(compressionQuality: quality)?.count ?? 0
    }

    /// Formatea el tamaño en bytes a string legible
    /// - Parameter bytes: Tamaño en bytes
    /// - Returns: String formateado (ej: "2.5 MB")
    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Valida que una imagen cumple con los requisitos
    /// - Parameters:
    ///   - image: Imagen a validar
    ///   - maxSizeBytes: Tamaño máximo en bytes
    ///   - config: Configuración de compresión
    /// - Returns: true si es válida, false si no
    static func validate(_ image: UIImage, maxSizeBytes: Int, config: CompressionConfig = .medium) -> Bool {
        guard let compressedImage = compress(image, config: config) else {
            return false
        }

        let size = getCompressedSize(compressedImage, quality: config.quality)
        return size <= maxSizeBytes
    }
}

// MARK: - Batch Processing

extension ImageCompressor {

    /// Comprime múltiples imágenes de forma eficiente
    /// - Parameters:
    ///   - images: Array de imágenes
    ///   - config: Configuración de compresión
    ///   - progressHandler: Callback con progreso (0.0 a 1.0)
    /// - Returns: Array de imágenes comprimidas
    static func compressBatch(
        _ images: [UIImage],
        config: CompressionConfig = .medium,
        progressHandler: ((Double) -> Void)? = nil
    ) -> [UIImage] {
        var compressedImages: [UIImage] = []

        for (index, image) in images.enumerated() {
            if let compressed = compress(image, config: config) {
                compressedImages.append(compressed)
            }

            let progress = Double(index + 1) / Double(images.count)
            progressHandler?(progress)
        }

        return compressedImages
    }

    /// Comprime múltiples imágenes de forma asíncrona
    /// - Parameters:
    ///   - images: Array de imágenes
    ///   - config: Configuración de compresión
    ///   - progressHandler: Callback con progreso
    /// - Returns: Array de imágenes comprimidas
    static func compressBatchAsync(
        _ images: [UIImage],
        config: CompressionConfig = .medium,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> [UIImage] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let compressed = compressBatch(images, config: config) { progress in
                    DispatchQueue.main.async {
                        progressHandler?(progress)
                    }
                }
                continuation.resume(returning: compressed)
            }
        }
    }
}

// MARK: - Image Info

extension ImageCompressor {

    struct ImageInfo {
        let originalSize: CGSize
        let originalFileSize: Int
        let compressedSize: CGSize
        let compressedFileSize: Int
        let compressionRatio: Double

        var originalSizeFormatted: String {
            ImageCompressor.formatFileSize(originalFileSize)
        }

        var compressedSizeFormatted: String {
            ImageCompressor.formatFileSize(compressedFileSize)
        }

        var saved: String {
            let saved = originalFileSize - compressedFileSize
            return ImageCompressor.formatFileSize(saved)
        }
    }

    /// Obtiene información detallada sobre la compresión
    /// - Parameters:
    ///   - originalImage: Imagen original
    ///   - compressedImage: Imagen comprimida
    ///   - quality: Calidad de compresión usada
    /// - Returns: Información de compresión
    static func getCompressionInfo(
        originalImage: UIImage,
        compressedImage: UIImage,
        quality: CGFloat = 0.8
    ) -> ImageInfo {
        let originalSize = getCompressedSize(originalImage, quality: 1.0)
        let compressedSize = getCompressedSize(compressedImage, quality: quality)
        let ratio = Double(compressedSize) / Double(originalSize)

        return ImageInfo(
            originalSize: originalImage.size,
            originalFileSize: originalSize,
            compressedSize: compressedImage.size,
            compressedFileSize: compressedSize,
            compressionRatio: ratio
        )
    }
}
