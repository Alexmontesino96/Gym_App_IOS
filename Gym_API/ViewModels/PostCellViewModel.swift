import Foundation
import SwiftUI
import Combine

/// ViewModel para una celda individual de post con UI optimista
@MainActor
class PostCellViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var post: Post
    @Published var isTogglingLike = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let postService: PostService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(post: Post, postService: PostService = .shared) {
        self.post = post
        self.postService = postService
    }

    // MARK: - Like Actions

    /// Toggle like con UI optimista y rollback en caso de error
    func toggleLike() async {
        guard !isTogglingLike else { return }

        isTogglingLike = true
        errorMessage = nil

        // Guardar estado previo para rollback
        let previousLiked = post.hasLiked
        let previousCount = post.likeCount

        // Actualizar UI inmediatamente (optimista)
        post.hasLiked.toggle()
        post.likeCount += post.hasLiked ? 1 : -1

        do {
            // Llamar al servidor
            let result = try await postService.toggleLike(postId: post.id)

            // Sincronizar con respuesta del servidor
            post.hasLiked = result.liked
            post.likeCount = result.totalLikes

            #if DEBUG
            print("✅ Like toggled: \(result.liked), total: \(result.totalLikes)")
            #endif

        } catch {
            // Rollback en caso de error
            post.hasLiked = previousLiked
            post.likeCount = previousCount
            errorMessage = "No se pudo actualizar el like"

            print("❌ Error toggling like: \(error)")
        }

        isTogglingLike = false
    }

    // MARK: - Computed Properties

    var likeButtonColor: Color {
        post.hasLiked ? .red : .gray
    }

    var likeButtonIcon: String {
        post.hasLiked ? "heart.fill" : "heart"
    }

    var likeCountText: String {
        if post.likeCount == 0 {
            return ""
        } else if post.likeCount == 1 {
            return "1 like"
        } else {
            return "\(post.likeCount) likes"
        }
    }

    var commentCountText: String {
        if post.commentCount == 0 {
            return "Comentar"
        } else if post.commentCount == 1 {
            return "1 comentario"
        } else {
            return "\(post.commentCount) comentarios"
        }
    }

    var canEdit: Bool {
        post.isOwnPost && !post.isDeleted
    }

    var canDelete: Bool {
        post.isOwnPost && !post.isDeleted
    }

    // MARK: - Post Actions

    /// Elimina el post
    func deletePost() async throws {
        try await postService.deletePost(id: post.id)
    }

    /// Actualiza el caption del post
    /// - Parameter newCaption: Nuevo caption
    func updateCaption(_ newCaption: String) async throws {
        let updated = try await postService.updatePost(id: post.id, caption: newCaption, location: nil)
        post = updated
    }

    /// Actualiza la ubicación del post
    /// - Parameter newLocation: Nueva ubicación
    func updateLocation(_ newLocation: String) async throws {
        let updated = try await postService.updatePost(id: post.id, caption: nil, location: newLocation)
        post = updated
    }
}
