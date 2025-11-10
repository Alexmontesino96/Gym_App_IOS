import SwiftUI

/// Vista para mostrar la lista de usuarios que dieron like a un post
struct PostLikesListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService

    @State private var likes: [LikeItem] = []
    @State private var paginationState = PaginationState()
    @State private var isInitialLoad = true
    @State private var errorMessage: String?

    @Environment(\.dismiss) var dismiss

    let postId: Int
    let initialLikeCount: Int?

    init(postId: Int, initialLikeCount: Int? = nil) {
        self.postId = postId
        self.initialLikeCount = initialLikeCount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isInitialLoad && likes.isEmpty {
                        loadingView
                    } else if !isInitialLoad && likes.isEmpty {
                        emptyStateView
                    } else {
                        likesListView
                    }
                }
            }
            .navigationTitle("Me gusta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
            .task {
                await loadLikes()
            }
            .refreshable {
                await refreshLikes()
            }
        }
    }

    // MARK: - Likes List View

    private var likesListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header con contador
                if let count = initialLikeCount {
                    headerView(count: count)
                }

                // Lista de likes
                ForEach(likes) { like in
                    UserLikeRow(likeItem: like)
                        .environmentObject(themeManager)
                        .onAppear {
                            // Cargar más al llegar al final
                            if like.id == likes.last?.id {
                                Task {
                                    await loadMoreLikes()
                                }
                            }
                        }

                    Divider()
                        .padding(.leading, 68)
                }

                // Loading indicator al final
                if paginationState.isLoading && !isInitialLoad {
                    ProgressView()
                        .padding(.vertical, 20)
                }
            }
        }
    }

    // MARK: - Header View

    private func headerView(count: Int) -> some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)

            Text("\(count) me gusta")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { _ in
                shimmerLikeRow
            }
        }
        .padding(.top, 16)
    }

    private var shimmerLikeRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
            }

            Spacer()

            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .shimmer()
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("Aún no hay likes")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Sé el primero en dar like")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    /// Carga inicial de likes
    private func loadLikes() async {
        guard !paginationState.isLoading else { return }

        paginationState.startLoading()

        do {
            let response = try await postService.getLikes(
                postId: postId,
                limit: paginationState.limit,
                offset: 0
            )

            await MainActor.run {
                likes = response.items
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

    /// Carga más likes (paginación)
    private func loadMoreLikes() async {
        guard paginationState.canLoadMore else { return }

        paginationState.startLoading()

        do {
            let response = try await postService.getLikes(
                postId: postId,
                limit: paginationState.limit,
                offset: paginationState.offset
            )

            await MainActor.run {
                likes.append(contentsOf: response.items)
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

    /// Refresca la lista completa
    private func refreshLikes() async {
        paginationState.reset()
        await loadLikes()
    }
}

// MARK: - Preview

#Preview {
    PostLikesListView(postId: 1, initialLikeCount: 42)
        .environmentObject(ThemeManager())
        .environmentObject(PostService.shared)
}
