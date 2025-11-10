import SwiftUI

/// Componente de fila para mostrar un comentario individual
struct CommentRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService

    @State private var comment: Comment
    @State private var isLiking = false
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    let currentUserId: Int?
    let onDelete: (() -> Void)?
    let onEdit: ((Comment) -> Void)?

    init(
        comment: Comment,
        currentUserId: Int? = nil,
        onDelete: (() -> Void)? = nil,
        onEdit: ((Comment) -> Void)? = nil
    ) {
        self._comment = State(initialValue: comment)
        self.currentUserId = currentUserId
        self.onDelete = onDelete
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            avatarView

            // Contenido del comentario
            VStack(alignment: .leading, spacing: 4) {
                // Nombre y tiempo
                HStack(spacing: 8) {
                    Text(comment.user.fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    if isOwnComment {
                        Text("Tú")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }

                    Spacer()

                    Text(comment.relativeTime)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                // Texto del comentario
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .fixedSize(horizontal: false, vertical: true)

                if comment.isEdited {
                    Text("Editado")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .opacity(0.7)
                }

                // Botón de like
                likeButton
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            if isOwnComment {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        }
        .alert("Eliminar comentario", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar este comentario?")
        }
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        Group {
            if let profilePictureURL = comment.user.profilePictureURL {
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
                                .font(.system(size: 14))
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
                            .font(.system(size: 14))
                    )
            }
        }
    }

    // MARK: - Like Button

    private var likeButton: some View {
        Button(action: {
            Task {
                await toggleLike()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: comment.hasLiked ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(comment.hasLiked ? .red : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .symbolEffect(.bounce, value: comment.hasLiked)

                if comment.likeCount > 0 {
                    Text("\(comment.likeCount)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLiking)
    }

    // MARK: - Computed Properties

    private var isOwnComment: Bool {
        guard let currentUserId = currentUserId else { return false }
        return comment.userId == currentUserId
    }

    // MARK: - Actions

    /// Toggle like en comentario con UI optimista
    private func toggleLike() async {
        guard !isLiking else { return }

        isLiking = true

        // Guardar estado previo para rollback
        let previousHasLiked = comment.hasLiked
        let previousLikeCount = comment.likeCount

        // Actualizar UI optimistamente
        comment.hasLiked.toggle()
        comment.likeCount += comment.hasLiked ? 1 : -1

        do {
            // Realizar request al servidor
            let result = try await postService.toggleCommentLike(commentId: comment.id)

            // Actualizar con respuesta del servidor
            await MainActor.run {
                comment.hasLiked = result.liked
                comment.likeCount = result.totalLikes
                isLiking = false
            }
        } catch {
            // Revertir cambios en caso de error
            await MainActor.run {
                comment.hasLiked = previousHasLiked
                comment.likeCount = previousLikeCount
                isLiking = false
                postService.errorMessage = "Error al dar like: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleComment = Comment(
        id: 1,
        postId: 1,
        userId: 1,
        text: "¡Excelente entrenamiento! Me encantó la rutina de hoy 💪",
        likeCount: 5,
        isEdited: false,
        isDeleted: false,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: nil,
        editedAt: nil,
        user: UserPreview(
            id: 1,
            fullName: "María García",
            profilePictureUrl: "https://picsum.photos/100/100",
            role: "member"
        ),
        hasLiked: false
    )

    ScrollView {
        VStack(spacing: 0) {
            CommentRow(comment: sampleComment, currentUserId: 2)
                .environmentObject(ThemeManager())
                .environmentObject(PostService.shared)

            Divider()

            CommentRow(
                comment: Comment(
                    id: 2,
                    postId: 1,
                    userId: 2,
                    text: "Totalmente de acuerdo, fue un día increíble",
                    likeCount: 12,
                    isEdited: true,
                    isDeleted: false,
                    createdAt: Date().addingTimeInterval(-7200),
                    updatedAt: Date().addingTimeInterval(-3600),
                    editedAt: Date().addingTimeInterval(-3600),
                    user: UserPreview(
                        id: 2,
                        fullName: "Juan Pérez",
                        profilePictureUrl: nil,
                        role: "member"
                    ),
                    hasLiked: true
                ),
                currentUserId: 2
            )
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
        }
    }
}
