import SwiftUI

/// Input bar para escribir y enviar comentarios
struct CommentInputView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService

    @Binding var commentText: String
    @FocusState.Binding var isFocused: Bool

    let postId: Int
    let onCommentAdded: (Comment) -> Void

    @State private var isSending = false
    @State private var errorMessage: String?

    private let maxCharacters = 2200

    var body: some View {
        VStack(spacing: 0) {
            // Mensaje de error si existe
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.orange)

                    Spacer()

                    Button(action: { errorMessage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            Divider()

            // Input bar
            HStack(spacing: 12) {
                // TextField
                TextField("Escribe un comentario...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .disabled(isSending)
                    .onChange(of: commentText) { _, newValue in
                        // Limitar caracteres
                        if newValue.count > maxCharacters {
                            commentText = String(newValue.prefix(maxCharacters))
                        }
                    }

                // Contador de caracteres (solo visible si se acerca al límite)
                if commentText.count > maxCharacters - 100 {
                    Text("\(commentText.count)/\(maxCharacters)")
                        .font(.system(size: 11))
                        .foregroundColor(
                            commentText.count >= maxCharacters
                                ? .red
                                : Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                        )
                }

                // Botón de enviar
                Button(action: {
                    Task {
                        await sendComment()
                    }
                }) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(isCommentValid ? Color(red: 0.85, green: 0.2, blue: 0.2) : .gray)
                    }
                }
                .disabled(!isCommentValid || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        }
    }

    // MARK: - Computed Properties

    private var isCommentValid: Bool {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxCharacters
    }

    // MARK: - Actions

    /// Enviar comentario al servidor
    private func sendComment() async {
        guard isCommentValid else { return }

        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)

        isSending = true
        errorMessage = nil

        // Guardar texto para limpiar input optimistamente
        let textToSend = trimmedText

        // Limpiar input inmediatamente (UI optimista)
        await MainActor.run {
            commentText = ""
        }

        do {
            // Enviar comentario al servidor
            let newComment = try await postService.addComment(
                postId: postId,
                text: textToSend,
                mentionedUserIds: nil
            )

            await MainActor.run {
                isSending = false
                onCommentAdded(newComment)

                // Ocultar teclado
                isFocused = false

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch let error as CommentError {
            await MainActor.run {
                // Restaurar texto en caso de error
                commentText = textToSend

                switch error {
                case .emptyText:
                    errorMessage = "El comentario no puede estar vacío"
                case .textTooLong:
                    errorMessage = "El comentario es demasiado largo (máx. \(maxCharacters) caracteres)"
                case .notFound:
                    errorMessage = "Post no encontrado"
                case .unauthorized:
                    errorMessage = "No autorizado para comentar"
                }

                isSending = false

                // Haptic feedback de error
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        } catch {
            await MainActor.run {
                // Restaurar texto en caso de error genérico
                commentText = textToSend
                errorMessage = "Error al enviar comentario: \(error.localizedDescription)"
                isSending = false

                // Haptic feedback de error
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var commentText = ""
        @FocusState private var isFocused: Bool
        @State private var comments: [Comment] = []

        var body: some View {
            VStack {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment, currentUserId: 1)
                                .environmentObject(ThemeManager())
                                .environmentObject(PostService.shared)
                        }
                    }
                }

                CommentInputView(
                    commentText: $commentText,
                    isFocused: $isFocused,
                    postId: 1
                ) { newComment in
                    comments.append(newComment)
                }
                .environmentObject(ThemeManager())
                .environmentObject(PostService.shared)
            }
        }
    }

    return PreviewWrapper()
}
