import SwiftUI

/// Modal completa para ver y gestionar comentarios de un post con paginación
struct CommentsSheetView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel: CommentsViewModel
    @Environment(\.dismiss) var dismiss

    init(postId: Int) {
        _viewModel = StateObject(wrappedValue: CommentsViewModel(postId: postId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Comments list
                    if viewModel.isLoading && viewModel.comments.isEmpty {
                        loadingView
                    } else if viewModel.comments.isEmpty {
                        emptyStateView
                    } else {
                        commentsList
                    }

                    Divider()

                    // Comment input
                    commentInputSection
                }
            }
            .navigationTitle("Comentarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .task {
                await viewModel.loadInitial()
            }
        }
    }

    // MARK: - Comments List

    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.comments) { comment in
                    CommentRowView(
                        comment: comment,
                        onLike: {
                            Task {
                                await viewModel.toggleCommentLike(commentId: comment.id)
                            }
                        },
                        onEdit: { newText in
                            Task {
                                await viewModel.editComment(commentId: comment.id, newText: newText)
                            }
                        },
                        onDelete: {
                            Task {
                                await viewModel.deleteComment(commentId: comment.id)
                            }
                        }
                    )
                    .environmentObject(themeManager)
                    .onAppear {
                        // Load more when reaching last item
                        if comment.id == viewModel.comments.last?.id {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }

                    Divider()
                        .padding(.leading, 60)
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Cargando comentarios...")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text("No hay comentarios todavía")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Sé el primero en comentar")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Comment Input Section

    private var commentInputSection: some View {
        HStack(spacing: 12) {
            TextField("Agregar comentario...", text: $viewModel.commentText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)

            Button(action: {
                Task {
                    await viewModel.postComment()
                }
            }) {
                if viewModel.isPostingComment {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.canPostComment ? Color.dynamicAccent(theme: themeManager.currentTheme) : .gray)
                }
            }
            .disabled(!viewModel.canPostComment || viewModel.isPostingComment)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State var comment: Comment
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isAnimatingLike = false

    let onLike: () -> Void
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar
            if let avatarURL = comment.user.profilePictureURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                // User name and time
                HStack(spacing: 8) {
                    Text(comment.user.fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(comment.relativeTime)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    if let editLabel = comment.editLabel {
                        Text(editLabel)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .italic()
                    }

                    Spacer()
                }

                // Comment text
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .fixedSize(horizontal: false, vertical: true)

                // Actions
                HStack(spacing: 16) {
                    // Like button
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isAnimatingLike = true
                        }
                        onLike()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAnimatingLike = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.hasLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundColor(comment.hasLiked ? .red : .gray)
                                .scaleEffect(isAnimatingLike ? 1.2 : 1.0)

                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // Edit button (solo si es propio)
                    if comment.isOwnComment {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Text("Editar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }

                    // Delete button (solo si es propio)
                    if comment.isOwnComment {
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Text("Eliminar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingEditSheet) {
            EditCommentSheet(
                currentText: comment.text,
                onSave: { newText in
                    onEdit(newText)
                }
            )
            .environmentObject(themeManager)
        }
        .alert("Eliminar comentario", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar este comentario?")
        }
    }
}

// MARK: - Edit Comment Sheet

struct EditCommentSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State var editedText: String
    let onSave: (String) -> Void

    init(currentText: String, onSave: @escaping (String) -> Void) {
        _editedText = State(initialValue: currentText)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Comentario", text: $editedText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .padding()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .lineLimit(5...15)
                    .padding()

                Spacer()
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("Editar comentario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        onSave(editedText)
                        dismiss()
                    }
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Comments ViewModel

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var commentText: String = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isPostingComment = false
    @Published var errorMessage: String?
    @Published var hasMore = true

    private let postId: Int
    private let postService: PostService
    private var currentOffset = 0
    private let pageSize = 20

    init(postId: Int, postService: PostService = .shared) {
        self.postId = postId
        self.postService = postService
    }

    var canPostComment: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPostingComment
    }

    func loadInitial() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        currentOffset = 0
        comments = []

        await loadComments()
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, !isLoading else { return }

        isLoadingMore = true
        await loadComments()
        isLoadingMore = false
    }

    func refresh() async {
        await loadInitial()
    }

    func postComment() async {
        guard canPostComment else { return }

        isPostingComment = true
        errorMessage = nil

        do {
            let newComment = try await postService.addComment(
                postId: postId,
                text: commentText.trimmingCharacters(in: .whitespacesAndNewlines),
                mentionedUserIds: nil
            )

            comments.insert(newComment, at: 0)
            commentText = ""

        } catch {
            errorMessage = "Error al publicar comentario: \(error.localizedDescription)"
        }

        isPostingComment = false
    }

    func toggleCommentLike(commentId: Int) async {
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return }

        // UI optimista
        let previousLiked = comments[index].hasLiked
        let previousCount = comments[index].likeCount

        comments[index].hasLiked.toggle()
        comments[index].likeCount += comments[index].hasLiked ? 1 : -1

        do {
            _ = try await postService.toggleCommentLike(commentId: commentId)
        } catch {
            // Rollback
            comments[index].hasLiked = previousLiked
            comments[index].likeCount = previousCount
            errorMessage = "Error al dar like"
        }
    }

    func editComment(commentId: Int, newText: String) async {
        do {
            let updated = try await postService.editComment(commentId: commentId, text: newText)

            if let index = comments.firstIndex(where: { $0.id == commentId }) {
                comments[index] = updated
            }
        } catch {
            errorMessage = "Error al editar comentario: \(error.localizedDescription)"
        }
    }

    func deleteComment(commentId: Int) async {
        do {
            try await postService.deleteComment(commentId: commentId)
            comments.removeAll { $0.id == commentId }
        } catch {
            errorMessage = "Error al eliminar comentario: \(error.localizedDescription)"
        }
    }

    private func loadComments() async {
        do {
            let response = try await postService.getComments(
                postId: postId,
                limit: pageSize,
                offset: currentOffset
            )

            if let newComments = response.comments {
                if currentOffset == 0 {
                    comments = newComments
                } else {
                    comments.append(contentsOf: newComments)
                }

                hasMore = response.hasMore
                currentOffset = response.nextOffset ?? (currentOffset + newComments.count)
            }

            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    CommentsSheetView(postId: 1)
        .environmentObject(ThemeManager())
}
