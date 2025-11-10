import SwiftUI

/// Vista de grid de posts de un usuario (estilo Instagram)
struct UserPostsGridView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService

    let userId: Int

    @State private var posts: [Post] = []
    @State private var paginationState = PaginationState()
    @State private var isInitialLoad = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        Group {
            if isInitialLoad && posts.isEmpty {
                loadingView
            } else if !isInitialLoad && posts.isEmpty {
                emptyStateView
            } else {
                postsGridView
            }
        }
        .task {
            await loadPosts()
        }
    }

    // MARK: - Posts Grid View

    private var postsGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)
                        .environmentObject(themeManager)
                        .environmentObject(postService)) {
                        PostGridCell(post: post)
                            .onAppear {
                                // Cargar más al llegar al final
                                if post.id == posts.last?.id {
                                    Task {
                                        await loadMorePosts()
                                    }
                                }
                            }
                    }
                }

                // Loading indicator al final
                if paginationState.isLoading && !isInitialLoad {
                    VStack {
                        ProgressView()
                            .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(3)
                }
            }
            .padding(.top, 1)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<12, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(1, contentMode: .fill)
                        .shimmer()
                }
            }
            .padding(.top, 1)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("Sin posts aún")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Los posts aparecerán aquí")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    /// Carga inicial de posts
    private func loadPosts() async {
        guard !paginationState.isLoading else { return }

        paginationState.startLoading()

        do {
            let response = try await postService.getUserPosts(
                userId: userId,
                limit: paginationState.limit,
                offset: 0
            )

            await MainActor.run {
                posts = response.items
                paginationState.update(with: response)
                isInitialLoad = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                paginationState.stopLoading()
                isInitialLoad = false
            }
        }
    }

    /// Carga más posts (paginación)
    private func loadMorePosts() async {
        guard paginationState.canLoadMore else { return }

        paginationState.startLoading()

        do {
            let response = try await postService.getUserPosts(
                userId: userId,
                limit: paginationState.limit,
                offset: paginationState.offset
            )

            await MainActor.run {
                posts.append(contentsOf: response.items)
                paginationState.update(with: response)
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                paginationState.stopLoading()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UserPostsGridView(userId: 1)
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
    }
}
