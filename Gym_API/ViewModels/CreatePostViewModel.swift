import Foundation
import SwiftUI
import UIKit
import Combine

/// ViewModel para crear un nuevo post con validaciones y progreso
@MainActor
class CreatePostViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedImages: [UIImage] = []
    @Published var caption: String = ""
    @Published var location: String = ""
    @Published var privacy: Privacy = .public
    @Published var isPosting = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Private Properties

    private let postService: PostService
    private let maxImages = 10
    private let maxCaptionLength = 2200
    private let maxImageSizeBytes = 10 * 1024 * 1024 // 10 MB
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(postService: PostService = .shared) {
        self.postService = postService
    }

    // MARK: - Public Methods

    /// Crea el post
    func createPost() async -> Post? {
        guard validate() else { return nil }

        isPosting = true
        errorMessage = nil
        uploadProgress = 0.0

        do {
            // Comprimir imágenes
            uploadProgress = 0.1
            let compressedImages = await compressImages()

            uploadProgress = 0.3

            // Crear post
            let post = try await postService.createPost(
                caption: caption.isEmpty ? nil : caption,
                location: location.isEmpty ? nil : location,
                images: compressedImages
            )

            uploadProgress = 1.0
            successMessage = "Post creado exitosamente"

            #if DEBUG
            print("✅ Post creado: \(post.id)")
            #endif

            // Limpiar formulario
            reset()

            return post

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error creando post: \(error)")
            return nil
        }

        isPosting = false
    }

    /// Agrega una imagen
    /// - Parameter image: Imagen a agregar
    func addImage(_ image: UIImage) {
        guard selectedImages.count < maxImages else {
            errorMessage = "Máximo \(maxImages) imágenes permitidas"
            return
        }

        selectedImages.append(image)
        errorMessage = nil
    }

    /// Agrega múltiples imágenes
    /// - Parameter images: Array de imágenes
    func addImages(_ images: [UIImage]) {
        let availableSlots = maxImages - selectedImages.count
        let imagesToAdd = Array(images.prefix(availableSlots))

        selectedImages.append(contentsOf: imagesToAdd)

        if images.count > availableSlots {
            errorMessage = "Solo se agregaron \(imagesToAdd.count) de \(images.count) imágenes (máximo \(maxImages))"
        }
    }

    /// Elimina una imagen
    /// - Parameter index: Índice de la imagen
    func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }

    /// Reordena las imágenes
    /// - Parameters:
    ///   - source: Índice origen
    ///   - destination: Índice destino
    func moveImage(from source: IndexSet, to destination: Int) {
        selectedImages.move(fromOffsets: source, toOffset: destination)
    }

    /// Limpia el formulario
    func reset() {
        selectedImages = []
        caption = ""
        location = ""
        privacy = .public
        uploadProgress = 0.0
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Validation

    private func validate() -> Bool {
        errorMessage = nil

        if selectedImages.isEmpty {
            errorMessage = "Selecciona al menos una imagen"
            return false
        }

        if selectedImages.count > maxImages {
            errorMessage = "Máximo \(maxImages) imágenes permitidas"
            return false
        }

        if caption.count > maxCaptionLength {
            errorMessage = "El caption excede el límite de \(maxCaptionLength) caracteres"
            return false
        }

        if location.count > 255 {
            errorMessage = "La ubicación es demasiado larga"
            return false
        }

        return true
    }

    // MARK: - Image Compression

    private func compressImages() async -> [UIImage] {
        let config = ImageCompressor.CompressionConfig.medium
        return await ImageCompressor.compressBatchAsync(selectedImages, config: config) { progress in
            // Progreso de compresión: 0.1 a 0.3 (20% del total)
            self.uploadProgress = 0.1 + (progress * 0.2)
        }
    }

    // MARK: - Computed Properties

    var canPost: Bool {
        !selectedImages.isEmpty && !isPosting
    }

    var imageCountText: String {
        "\(selectedImages.count)/\(maxImages)"
    }

    var captionCountText: String {
        "\(caption.count)/\(maxCaptionLength)"
    }

    var isCaptionLimitReached: Bool {
        caption.count >= maxCaptionLength
    }

    var estimatedTotalSize: String {
        let totalBytes = selectedImages.reduce(0) { sum, image in
            sum + ImageCompressor.getCompressedSize(image, quality: 0.8)
        }
        return ImageCompressor.formatFileSize(totalBytes)
    }

    var postType: String {
        switch selectedImages.count {
        case 0:
            return "text"
        case 1:
            return "single_image"
        default:
            return "gallery"
        }
    }
}
