import Foundation
import SwiftUI
import Combine

/// ViewModel para el feed social con paginación y gestión de estados
@MainActor
class SocialFeedViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMore = true

    // MARK: - Private Properties

    private let postService: PostService
    private var currentOffset = 0
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Feed Type

    enum FeedType {
        case timeline
        case explore
        case location(String)
        case userPosts(Int)
    }

    private let feedType: FeedType

    // MARK: - Initialization

    init(feedType: FeedType = .timeline, postService: PostService = .shared) {
        self.feedType = feedType
        self.postService = postService
    }

    // MARK: - Public Methods

    /// Carga la página inicial de posts
    func loadInitial() async {
        print("🔄 [SocialFeedViewModel] loadInitial() llamado")
        print("📊 [SocialFeedViewModel] Feed type: \(feedType)")

        guard !isLoading else {
            print("⚠️ [SocialFeedViewModel] Ya está cargando, saliendo...")
            return
        }

        isLoading = true
        errorMessage = nil
        currentOffset = 0
        posts = []

        print("🚀 [SocialFeedViewModel] Iniciando carga de posts...")
        await loadPosts()
        print("✅ [SocialFeedViewModel] Carga completada - Posts: \(posts.count)")

        isLoading = false
    }

    /// Carga más posts (paginación)
    func loadMore() async {
        guard !isLoadingMore, hasMore, !isLoading else { return }

        isLoadingMore = true
        await loadPosts()
        isLoadingMore = false
    }

    /// Refresca el feed completo
    func refresh() async {
        await loadInitial()
    }

    /// Actualiza un post específico en la lista
    /// - Parameter post: Post actualizado
    func updatePost(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }

    /// Elimina un post de la lista
    /// - Parameter postId: ID del post a eliminar
    func removePost(_ postId: Int) {
        posts.removeAll { $0.id == postId }
    }

    /// Agrega un post nuevo al principio de la lista
    /// - Parameter post: Post nuevo
    func prependPost(_ post: Post) {
        posts.insert(post, at: 0)
    }

    // MARK: - Private Methods

    private func loadPosts() async {
        print("🔍 [SocialFeedViewModel] loadPosts() - Offset: \(currentOffset), PageSize: \(pageSize)")

        do {
            let response: PagedResponse<Post>

            switch feedType {
            case .timeline:
                print("📰 [SocialFeedViewModel] Cargando Timeline...")
                response = try await postService.getTimeline(limit: pageSize, offset: currentOffset)

            case .explore:
                print("🔍 [SocialFeedViewModel] Cargando Explore...")
                response = try await postService.getExplore(limit: pageSize, offset: currentOffset)

            case .location(let location):
                print("📍 [SocialFeedViewModel] Cargando Location: \(location)")
                response = try await postService.getByLocation(location, limit: pageSize, offset: currentOffset)

            case .userPosts(let userId):
                print("👤 [SocialFeedViewModel] Cargando posts de usuario: \(userId)")
                response = try await postService.getUserPosts(userId: userId, limit: pageSize, offset: currentOffset)
            }

            print("📦 [SocialFeedViewModel] Respuesta recibida:")
            print("   - Posts: \(response.posts?.count ?? 0)")
            print("   - HasMore: \(response.hasMore)")
            print("   - NextOffset: \(response.nextOffset ?? -1)")

            if let newPosts = response.posts {
                print("✅ [SocialFeedViewModel] Procesando \(newPosts.count) posts nuevos")

                if currentOffset == 0 {
                    print("   - Reemplazando posts existentes")
                    posts = newPosts
                } else {
                    print("   - Agregando a posts existentes (\(posts.count))")
                    posts.append(contentsOf: newPosts)
                }

                hasMore = response.hasMore ?? false
                currentOffset = response.nextOffset ?? (currentOffset + newPosts.count)

                print("📊 [SocialFeedViewModel] Estado final:")
                print("   - Total posts: \(posts.count)")
                print("   - HasMore: \(hasMore)")
                print("   - CurrentOffset: \(currentOffset)")

                // Log de cada post
                for (index, post) in newPosts.enumerated() {
                    print("   📄 Post \(index + 1): ID=\(post.id), User=\(post.userId), Media=\(post.media.count)")
                }
            } else {
                print("⚠️ [SocialFeedViewModel] Response.posts es nil")
            }

            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
            print("❌ [SocialFeedViewModel] Error cargando posts: \(error)")
            print("❌ [SocialFeedViewModel] Error localizado: \(error.localizedDescription)")
        }
    }

    // MARK: - State Helpers

    var isEmpty: Bool {
        posts.isEmpty && !isLoading
    }

    var shouldShowEmptyState: Bool {
        isEmpty && errorMessage == nil
    }

    var shouldShowError: Bool {
        errorMessage != nil && posts.isEmpty
    }
}
