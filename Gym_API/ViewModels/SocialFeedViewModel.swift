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
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        currentOffset = 0
        posts = []

        await loadPosts()

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
        do {
            let response: PagedResponse<Post>

            switch feedType {
            case .timeline:
                response = try await postService.getTimeline(limit: pageSize, offset: currentOffset)

            case .explore:
                response = try await postService.getExplore(limit: pageSize, offset: currentOffset)

            case .location(let location):
                response = try await postService.getByLocation(location, limit: pageSize, offset: currentOffset)

            case .userPosts(let userId):
                response = try await postService.getUserPosts(userId: userId, limit: pageSize, offset: currentOffset)
            }

            if let newPosts = response.posts {
                if currentOffset == 0 {
                    posts = newPosts
                } else {
                    posts.append(contentsOf: newPosts)
                }

                hasMore = response.hasMore
                currentOffset = response.nextOffset ?? (currentOffset + newPosts.count)
            }

            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error cargando posts: \(error)")
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

// MARK: - Pagination State

struct PaginationState {
    var isLoading = false
    var hasMore = true
    var offset = 0
    var error: String?

    mutating func reset() {
        offset = 0
        hasMore = true
        error = nil
    }
}
