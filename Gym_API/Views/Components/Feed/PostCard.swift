import SwiftUI

/// Card de post para el feed social (estilo Instagram)
struct PostCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService

    @State private var post: Post
    @State private var isLiking = false
    @State private var showLikesSheet = false
    @State private var showDoubleTapHeart = false  // For double-tap animation
    @State private var heartScale: CGFloat = 0.5   // Heart animation scale

    init(post: Post) {
        self._post = State(initialValue: post)
    }

    var body: some View {
        NavigationLink(destination: PostDetailView(post: post)
            .environmentObject(themeManager)
            .environmentObject(postService)) {
            VStack(alignment: .leading, spacing: 0) {

                // Header (usuario + ubicación + opciones)
                headerView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Media gallery (imágenes/videos)
                if !post.media.isEmpty {
                    mediaGalleryView
                        .frame(height: 375) // Aspecto cuadrado para mantener consistencia
                }

                // Botones de acción (like, comment, share)
                actionButtonsView
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // Contador de likes
                if post.likeCount > 0 {
                    likesCountView
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Caption
                if let caption = post.caption, !caption.isEmpty {
                    captionView
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Botón "ver comentarios" si hay comentarios
                if post.commentCount > 0 {
                    viewCommentsButton
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }

                // Ubicación
                if let location = post.location, !location.isEmpty {
                    locationView
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Tiempo transcurrido
                timeView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Divider inferior
                Divider()
                    .background(Color.gray.opacity(0.3))
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .cornerRadius(0) // Sin bordes redondeados para mantener estilo Instagram
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .sheet(isPresented: $showLikesSheet) {
            PostLikesListView(postId: post.id, initialLikeCount: post.likeCount)
                .environmentObject(themeManager)
                .environmentObject(postService)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Avatar del usuario
            if let profilePictureURL = post.user.profilePictureURL {
                AsyncImage(url: profilePictureURL) { image in
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
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }

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

            // Botón de opciones
            Button(action: {
                // TODO: Mostrar menú de opciones (editar, eliminar, reportar)
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - Media Gallery View

    private var mediaGalleryView: some View {
        ZStack {
            TabView {
                ForEach(post.media.sorted(by: { $0.displayOrder < $1.displayOrder })) { media in
                    if let mediaURL = media.mediaURL {
                        AsyncImage(url: mediaURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .clipped()
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: post.media.count > 1 ? .always : .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

            // Double-tap like heart animation (Instagram style)
            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 0)
                    .scaleEffect(heartScale)
                    .opacity(showDoubleTapHeart ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: heartScale)
            }
        }
        .onTapGesture(count: 2) {
            // Double-tap to like
            handleDoubleTapLike()
        }
    }

    // MARK: - Action Buttons View

    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            // Botón de like
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
            .disabled(isLiking)

            // Botón de comentar (navegación al detalle)
            Image(systemName: "bubble.right")
                .font(.system(size: 24))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Botón de compartir
            Button(action: {
                // TODO: Implementar compartir
            }) {
                Image(systemName: "paperplane")
                    .font(.system(size: 24))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()

            // Indicador de galería
            if post.media.count > 1 {
                Text("1/\(post.media.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Likes Count View

    private var likesCountView: some View {
        Button(action: {
            showLikesSheet = true
        }) {
            Text(likesText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
    }

    /// Texto de likes con pluralización correcta en español
    private var likesText: String {
        if post.likeCount == 1 {
            return "1 me gusta"
        } else {
            return "\(post.likeCount) me gusta"
        }
    }

    // MARK: - Caption View

    private var captionView: some View {
        HStack(alignment: .top, spacing: 4) {
            // Username en negrita
            Text(post.user.fullName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Caption texto
            Text(post.caption ?? "")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(3)

            Spacer()
        }
    }

    // MARK: - Location View

    private var locationView: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
            Text(post.location ?? "")
                .font(.system(size: 12))
        }
        .foregroundColor(.gray)
    }

    // MARK: - View Comments Button

    private var viewCommentsButton: some View {
        Text(commentsText)
            .font(.system(size: 14))
            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
    }

    /// Texto de comentarios con pluralización correcta en español (estilo Instagram)
    private var commentsText: String {
        if post.commentCount == 1 {
            return "Ver el comentario"
        } else {
            return "Ver los \(post.commentCount) comentarios"
        }
    }

    // MARK: - Time View

    private var timeView: some View {
        Text(post.relativeTime.uppercased())
            .font(.system(size: 10))
            .foregroundColor(.gray)
    }

    // MARK: - Actions

    /// Toggle like con UI optimista
    private func toggleLike() async {
        guard !isLiking else { return }

        isLiking = true

        // Guardar estado previo para rollback
        let previousHasLiked = post.hasLiked
        let previousLikeCount = post.likeCount

        // Actualizar UI optimistamente con animación suave
        withAnimation(.easeInOut(duration: 0.2)) {
            post.hasLiked.toggle()
            post.likeCount += post.hasLiked ? 1 : -1
        }

        do {
            // Realizar request al servidor
            let result = try await postService.toggleLike(postId: post.id)

            // Solo actualizar si los valores del servidor son diferentes
            await MainActor.run {
                if post.hasLiked != result.liked || post.likeCount != result.totalLikes {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        post.hasLiked = result.liked
                        post.likeCount = result.totalLikes
                    }
                }
                isLiking = false
            }
        } catch {
            // Revertir cambios en caso de error con animación
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    post.hasLiked = previousHasLiked
                    post.likeCount = previousLikeCount
                }
                isLiking = false
                postService.errorMessage = "Error al dar like: \(error.localizedDescription)"
            }
        }
    }

    /// Handle double-tap to like (Instagram style)
    private func handleDoubleTapLike() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Only like if not already liked
        guard !post.hasLiked else {
            // Show animation even if already liked
            showHeartAnimation()
            return
        }

        // Show heart animation
        showHeartAnimation()

        // Perform like action
        Task {
            await toggleLike()
        }
    }

    /// Show double-tap heart animation
    private func showHeartAnimation() {
        showDoubleTapHeart = true
        heartScale = 0.5

        // Animate heart growing
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            heartScale = 1.3
        }

        // Fade out after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) {
                heartScale = 1.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showDoubleTapHeart = false
                heartScale = 0.5
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
        caption: "¡Gran entrenamiento hoy! 💪 Sentí que superé mis límites y logré mi objetivo.",
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
            ),
            PostMedia(
                id: 2,
                postId: 1,
                mediaType: .image,
                mediaUrl: "https://picsum.photos/400/401",
                thumbnailUrl: "https://picsum.photos/200/201",
                displayOrder: 1,
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

    return ScrollView {
        PostCard(post: samplePost)
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
    }
}
