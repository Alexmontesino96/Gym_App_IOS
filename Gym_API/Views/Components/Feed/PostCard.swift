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
    @State private var showOptionsMenu = false     // Options menu
    @State private var showDeleteConfirmation = false  // Delete confirmation
    @State private var showReportSheet = false     // Report sheet
    @State private var isDeleting = false          // Delete loading state

    /// Callback para notificar cuando un post ha sido eliminado
    var onPostDeleted: ((Int) -> Void)?

    init(post: Post, onPostDeleted: ((Int) -> Void)? = nil) {
        self._post = State(initialValue: post)
        self.onPostDeleted = onPostDeleted
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

                // Media gallery (imágenes/videos) - altura dinámica basada en aspect ratio
                if !post.media.isEmpty {
                    PostMediaGallery(mediaItems: post.media, theme: themeManager.currentTheme)
                        .onTapGesture(count: 2) {
                            handleDoubleTapLike()
                        }
                        .overlay(
                            // Double-tap like heart animation (Instagram style)
                            Group {
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
                        )
                }

                // Activity Cards (sesión/evento etiquetado) - contexto del contenido, edge-to-edge
                if let sessionTag = post.tags.first(where: { $0.tagType == .session }) {
                    SessionPillContainer(sessionTag: sessionTag)
                        .environmentObject(themeManager)
                        .padding(.top, 10)
                }

                if let eventTag = post.tags.first(where: { $0.tagType == .event }) {
                    EventPillContainer(eventTag: eventTag)
                        .environmentObject(themeManager)
                        .padding(.top, hasTags(session: true) ? 0 : 10)
                }

                // Botones de acción (like, comment, share)
                actionButtonsView
                    .padding(.horizontal, 16)
                    .padding(.top, hasAnyTag ? 10 : 14)

                // Contador de likes
                if post.likeCount > 0 {
                    likesCountView
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
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
        .sheet(isPresented: $showReportSheet) {
            ReportPostSheet(postId: post.id)
                .environmentObject(themeManager)
                .environmentObject(postService)
        }
        .alert("Eliminar post", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task {
                    await deletePost()
                }
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar este post? Esta acción no se puede deshacer.")
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    )
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Avatar del usuario con caché
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

            // Botón de opciones
            Button(action: {
                showOptionsMenu = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(width: 24, height: 24)
            }
            .confirmationDialog("Opciones", isPresented: $showOptionsMenu, titleVisibility: .hidden) {
                if post.isOwnPost {
                    Button("Eliminar post", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } else {
                    Button("Reportar", role: .destructive) {
                        showReportSheet = true
                    }
                }
                Button("Cancelar", role: .cancel) {}
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

    // MARK: - Tag Helpers

    private var hasAnyTag: Bool {
        post.tags.contains(where: { $0.tagType == .session || $0.tagType == .event })
    }

    private func hasTags(session: Bool) -> Bool {
        post.tags.contains(where: { $0.tagType == .session })
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

    /// Eliminar post
    private func deletePost() async {
        guard !isDeleting else { return }

        isDeleting = true

        do {
            try await postService.deletePost(id: post.id)

            // Haptic feedback de éxito
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Notificar al parent que el post fue eliminado
            onPostDeleted?(post.id)

            print("✅ [PostCard] Post \(post.id) eliminado exitosamente")

        } catch PostServiceError.forbidden {
            postService.errorMessage = "No tienes permiso para eliminar este post"
            print("❌ [PostCard] Sin permiso para eliminar post \(post.id)")
        } catch PostServiceError.postNotFound {
            // El post ya no existe, tratarlo como éxito
            onPostDeleted?(post.id)
            print("⚠️ [PostCard] Post \(post.id) no encontrado (ya eliminado)")
        } catch {
            postService.errorMessage = "Error al eliminar el post: \(error.localizedDescription)"
            print("❌ [PostCard] Error eliminando post \(post.id): \(error)")
        }

        isDeleting = false
    }
}

// MARK: - Report Post Sheet

/// Vista modal para reportar un post
struct ReportPostSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService

    let postId: Int

    @State private var selectedReason: ReportReason?
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    enum ReportReason: String, CaseIterable {
        case spam = "spam"
        case harassment = "harassment"
        case hateSpeech = "hate_speech"
        case violence = "violence"
        case nudity = "nudity"
        case falseInfo = "false_information"
        case other = "other"

        var displayName: String {
            switch self {
            case .spam: return "Es spam"
            case .harassment: return "Acoso o bullying"
            case .hateSpeech: return "Discurso de odio"
            case .violence: return "Violencia"
            case .nudity: return "Desnudez o actividad sexual"
            case .falseInfo: return "Información falsa"
            case .other: return "Otro"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                if showSuccess {
                    successView
                } else {
                    reportFormView
                }
            }
            .navigationTitle("Reportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
    }

    private var reportFormView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("¿Por qué reportas este post?")
                .font(.headline)
                .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

            // Opciones de reporte
            VStack(spacing: 0) {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    Button(action: {
                        selectedReason = reason
                    }) {
                        HStack {
                            Text(reason.displayName)
                                .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                            Spacer()

                            if selectedReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.dynamicAccent(theme: themeManager.currentTheme))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    if reason != ReportReason.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicCard(theme: themeManager.currentTheme))
            )

            // Detalles adicionales
            if selectedReason == .other {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe el problema")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Detalles adicionales...", text: $additionalDetails, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                        )
                        .lineLimit(3...6)
                }
            }

            Spacer()

            // Botón de enviar
            Button(action: {
                Task {
                    await submitReport()
                }
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Enviar reporte")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedReason != nil ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.gray)
                )
            }
            .disabled(selectedReason == nil || isSubmitting)
        }
        .padding()
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Reporte enviado")
                    .font(.title2.bold())
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                Text("Gracias por ayudarnos a mantener la comunidad segura.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Cerrar") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
            )
        }
        .padding()
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }

        isSubmitting = true

        do {
            try await postService.reportPost(
                postId: postId,
                reason: reason.rawValue,
                description: additionalDetails.isEmpty ? nil : additionalDetails
            )

            // Haptic feedback de éxito
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            withAnimation {
                showSuccess = true
            }

            // Auto-cerrar después de 2 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }

        } catch {
            postService.errorMessage = "Error al enviar el reporte: \(error.localizedDescription)"
        }

        isSubmitting = false
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
