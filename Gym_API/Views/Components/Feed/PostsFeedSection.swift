import SwiftUI

/// Sección de posts del feed social con paginación infinita
struct PostsFeedSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthServiceDirect

    @State private var posts: [Post] = []
    @State private var paginationState = PaginationState()
    @State private var isInitialLoad = true
    @State private var errorMessage: String?
    @State private var isShowingCreatePost = false

    var body: some View {
        VStack(spacing: 0) {
            // Header de la sección
            sectionHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Lista de posts
            if isInitialLoad && posts.isEmpty {
                loadingView
            } else if !isInitialLoad && posts.isEmpty {
                emptyStateView
            } else {
                postsListView
            }
        }
        .task {
            Logger.shared.debug("PostsFeedSection appeared - triggering initial load if needed", category: .ui)
            // Cargar posts automáticamente cuando la vista aparece
            if posts.isEmpty && !paginationState.isLoading {
                Logger.shared.info("Initial posts are empty. Starting loadInitialPosts()", category: .service)
                await loadInitialPosts()
            }
        }
        .sheet(isPresented: $isShowingCreatePost) {
            CreatePostView()
                .environmentObject(themeManager)
                .environmentObject(postService)
                .environmentObject(authService)
                .onDisappear {
                    // Recargar posts después de crear uno nuevo
                    Task {
                        Logger.shared.info("CreatePostView dismissed. Refreshing posts.", category: .service)
                        await refreshPosts()
                    }
                }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))

            Text("Posts del Gym")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()

            // Botón de crear post
            Button(action: {
                isShowingCreatePost = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
            }

            // Botón de refresh
            Button(action: {
                Task {
                    await refreshPosts()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .disabled(paginationState.isLoading)
        }
    }

    // MARK: - Posts List View

    private var postsListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(posts) { post in
                PostCard(post: post)
                    .environmentObject(themeManager)
                    .environmentObject(postService)
                    .onAppear {
                        // Cargar más posts cuando llegamos al final
                        if post.id == posts.last?.id {
                            Task {
                                await loadMorePosts()
                            }
                        }
                    }
            }

            // Loading indicator al final
            if paginationState.isLoading && !isInitialLoad {
                loadingIndicator
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                shimmerPostCard
            }
        }
    }

    private var shimmerPostCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header shimmer
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 10)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Image shimmer
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 375)

            // Actions shimmer
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .padding(.bottom, 8)
        .shimmer()
    }

    private var loadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("Aún no hay posts")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Sé el primero en compartir algo")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Button(action: {
                isShowingCreatePost = true
            }) {
                Text("Crear Post")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.85, green: 0.2, blue: 0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    /// Carga inicial de posts
    private func loadInitialPosts() async {
        guard !paginationState.isLoading else {
            Logger.shared.debug("loadInitialPosts() ignored - already loading", category: .service)
            return
        }

        paginationState.startLoading()
        Logger.shared.info("Loading initial posts", category: .service, metadata: [
            "limit": "\(paginationState.limit)",
            "offset": "0"
        ])

        do {
            let response = try await postService.getTimeline(
                limit: paginationState.limit,
                offset: 0
            )

            await MainActor.run {
                posts = response.items
                paginationState.update(with: response)
                isInitialLoad = false
                errorMessage = nil
            }

            Logger.shared.info("Initial posts loaded", category: .service, metadata: [
                "items": "\(response.items.count)",
                "hasMore": "\(response.hasMore)",
                "nextOffset": "\(response.nextOffset ?? -1)"
            ])
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                paginationState.stopLoading()
                isInitialLoad = false
            }

            Logger.shared.error("Failed to load initial posts: \(error.localizedDescription)", category: .service)
        }
    }

    /// Carga más posts (paginación)
    private func loadMorePosts() async {
        guard paginationState.canLoadMore else {
            Logger.shared.debug("loadMorePosts() ignored - cannot load more", category: .service, metadata: [
                "hasMore": "\(paginationState.hasMore.description)",
                "isLoading": "\(paginationState.isLoading.description)"
            ])
            return
        }

        paginationState.startLoading()
        Logger.shared.info("Loading more posts", category: .service, metadata: [
            "limit": "\(paginationState.limit)",
            "offset": "\(paginationState.offset)"
        ])

        do {
            let response = try await postService.getTimeline(
                limit: paginationState.limit,
                offset: paginationState.offset
            )

            await MainActor.run {
                posts.append(contentsOf: response.items)
                paginationState.update(with: response)
                errorMessage = nil
            }

            Logger.shared.info("More posts loaded", category: .service, metadata: [
                "added": "\(response.items.count)",
                "total": "\(posts.count)",
                "hasMore": "\(response.hasMore)",
                "nextOffset": "\(response.nextOffset ?? -1)"
            ])
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                paginationState.stopLoading()
            }

            Logger.shared.error("Failed to load more posts: \(error.localizedDescription)", category: .service)
        }
    }

    /// Refresca la lista completa
    private func refreshPosts() async {
        Logger.shared.info("Refreshing posts - resetting pagination", category: .service)
        paginationState.reset()
        await loadInitialPosts()
    }
}

// MARK: - View Extension for Lifecycle

extension PostsFeedSection {
    /// Inicializa la carga de posts al aparecer la vista
    func onAppearAction() {
        if posts.isEmpty && !paginationState.isLoading {
            Task {
                await loadInitialPosts()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        PostsFeedSection()
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
            .onAppear {
                // Simular carga de datos en preview
            }
    }
}
