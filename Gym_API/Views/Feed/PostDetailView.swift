import SwiftUI

/// Vista de detalle de un post con lista de comentarios
struct PostDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthServiceDirect

    @State private var post: Post
    @State private var comments: [Comment] = []
    @State private var paginationState = PaginationState()
    @State private var isLoadingComments = true
    @State private var errorMessage: String?
    @State private var commentText = ""
    @FocusState private var isCommentInputFocused: Bool
    @State private var showLikesSheet = false

    @Environment(\.dismiss) var dismiss

    let postId: Int

    init(post: Post) {
        self._post = State(initialValue: post)
        self.postId = post.id
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ScrollView con post y comentarios
                ScrollView {
                    VStack(spacing: 0) {
                        // Post completo (sin navegación)
                        postDetailCard

                        Divider()
                            .padding(.vertical, 8)

                        // Sección de comentarios
                        commentsSection
                    }
                }

                // Input bar fijo en bottom
                CommentInputView(
                    commentText: $commentText,
                    isFocused: $isCommentInputFocused,
                    postId: postId
                ) { newComment in
                    addCommentOptimistically(newComment)
                }
                .environmentObject(themeManager)
                .environmentObject(postService)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadComments()
        }
        .refreshable {
            await refreshData()
        }
        .sheet(isPresented: $showLikesSheet) {
            PostLikesListView(postId: post.id, initialLikeCount: post.likeCount)
                .environmentObject(themeManager)
                .environmentObject(postService)
        }
    }

    // MARK: - Post Detail Card

    private var postDetailCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Avatar con caché
                CachedAsyncImage(url: post.user.profilePictureUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    if let location = post.location {
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Media gallery optimizada con caché
            if !post.media.isEmpty {
                TabView {
                    ForEach(post.media.sorted(by: { $0.displayOrder < $1.displayOrder })) { media in
                        FeedOptimizedImage(
                            thumbnailUrl: media.thumbnailUrl,
                            fullUrl: media.mediaUrl,
                            displaySize: CGSize(width: UIScreen.main.bounds.width, height: 375),
                            contentMode: .fill,
                            cornerRadius: 0
                        )
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: post.media.count > 1 ? .always : .never))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                .frame(height: 375)
            }

            // Action buttons
            HStack(spacing: 16) {
                // Like button
                Button(action: {
                    Task {
                        await toggleLike()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: post.hasLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(post.hasLiked ? .red : Color.dynamicText(theme: themeManager.currentTheme))
                            .symbolEffect(.bounce, value: post.hasLiked)
                    }
                }

                // Comment button - scroll to comments
                Button(action: {
                    isCommentInputFocused = true
                }) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 24))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                // Share button
                Button(action: {
                    // TODO: Implementar compartir
                }) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 24))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                // Gallery indicator
                if post.media.count > 1 {
                    Text("1/\(post.media.count)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Likes count
            if post.likeCount > 0 {
                Button(action: {
                    showLikesSheet = true
                }) {
                    Text("\(post.likeCount) me gusta")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Caption
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // Time
            Text(post.relativeTime.uppercased())
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(spacing: 0) {
            // Header de comentarios
            HStack {
                Text("Comentarios")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                if post.commentCount > 0 {
                    Text("\(post.commentCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Lista de comentarios
            if isLoadingComments && comments.isEmpty {
                loadingCommentsView
            } else if !isLoadingComments && comments.isEmpty {
                emptyCommentsView
            } else {
                commentsListView
            }
        }
    }

    // MARK: - Loading Comments View

    private var loadingCommentsView: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
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
                            .frame(height: 32)
                    }
                }
                .padding(.horizontal, 16)
                .shimmer()
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Empty Comments View

    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("Aún no hay comentarios")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Sé el primero en comentar")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Comments List View

    private var commentsListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(comments) { comment in
                CommentRow(
                    comment: comment,
                    currentUserId: authService.user?.id != nil ? Int(authService.user!.id) : nil,
                    onDelete: {
                        Task {
                            await deleteComment(comment)
                        }
                    },
                    onEdit: { updatedComment in
                        if let index = comments.firstIndex(where: { $0.id == updatedComment.id }) {
                            comments[index] = updatedComment
                        }
                    }
                )
                .environmentObject(themeManager)
                .environmentObject(postService)

                Divider()
                    .padding(.leading, 60)

                // Cargar más comentarios al final
                if comment.id == comments.last?.id {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                await loadMoreComments()
                            }
                        }
                }
            }

            // Loading indicator al final
            if paginationState.isLoading && !isLoadingComments {
                ProgressView()
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Actions

    /// Cargar comentarios iniciales
    private func loadComments() async {
        guard !paginationState.isLoading else { return }

        paginationState.startLoading()
        isLoadingComments = true

        do {
            let response = try await postService.getComments(
                postId: postId,
                limit: paginationState.limit,
                offset: 0
            )

            await MainActor.run {
                comments = response.items
                paginationState.update(with: response)
                isLoadingComments = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                paginationState.stopLoading()
                isLoadingComments = false
            }
        }
    }

    /// Cargar más comentarios (paginación)
    private func loadMoreComments() async {
        guard paginationState.canLoadMore else { return }

        paginationState.startLoading()

        do {
            let response = try await postService.getComments(
                postId: postId,
                limit: paginationState.limit,
                offset: paginationState.offset
            )

            await MainActor.run {
                comments.append(contentsOf: response.items)
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

    /// Refrescar post y comentarios
    private func refreshData() async {
        paginationState.reset()
        await loadComments()

        // También refrescar el post
        do {
            let updatedPost = try await postService.getPost(id: postId)
            await MainActor.run {
                post = updatedPost
            }
        } catch {
            print("Error refrescando post: \(error)")
        }
    }

    /// Agregar comentario optimistamente
    private func addCommentOptimistically(_ comment: Comment) {
        comments.insert(comment, at: 0)
        post.commentCount += 1
    }

    /// Eliminar comentario
    private func deleteComment(_ comment: Comment) async {
        do {
            try await postService.deleteComment(commentId: comment.id)

            await MainActor.run {
                comments.removeAll { $0.id == comment.id }
                post.commentCount = max(0, post.commentCount - 1)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error al eliminar comentario: \(error.localizedDescription)"
            }
        }
    }

    /// Toggle like en el post
    private func toggleLike() async {
        let previousHasLiked = post.hasLiked
        let previousLikeCount = post.likeCount

        post.hasLiked.toggle()
        post.likeCount += post.hasLiked ? 1 : -1

        do {
            let result = try await postService.toggleLike(postId: post.id)

            await MainActor.run {
                post.hasLiked = result.liked
                post.likeCount = result.totalLikes
            }
        } catch {
            await MainActor.run {
                post.hasLiked = previousHasLiked
                post.likeCount = previousLikeCount
                errorMessage = "Error al dar like: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePost = Post(
        id: 1,
        userId: 1,
        gymId: 1,
        caption: "¡Gran entrenamiento hoy! 💪 Sentí que superé mis límites.",
        postType: .gallery,
        privacy: .public,
        location: "Gym Principal - Zona CrossFit",
        likeCount: 42,
        commentCount: 8,
        viewCount: 150,
        shareCount: 3,
        isEdited: false,
        isDeleted: false,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: Date(),
        editedAt: nil,
        workoutData: nil,
        media: [
            PostMedia(
                id: 1,
                postId: 1,
                mediaType: .image,
                mediaUrl: "https://picsum.photos/400/400",
                thumbnailUrl: "https://picsum.photos/200/200",
                displayOrder: 0,
                width: 400,
                height: 400,
                fileSize: 102400,
                durationSeconds: nil
            )
        ],
        tags: [],
        user: UserPreview(
            id: 1,
            fullName: "María García",
            profilePictureUrl: "https://picsum.photos/100/100",
            role: "member"
        ),
        hasLiked: false,
        isOwnPost: false
    )

    return NavigationStack {
        PostDetailView(post: samplePost)
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
            .environmentObject(AuthServiceDirect())
    }
}
