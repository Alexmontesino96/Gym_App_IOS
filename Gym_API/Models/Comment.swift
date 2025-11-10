import Foundation

// MARK: - Comment

/// Comentario en un post del feed social
struct Comment: Codable, Identifiable {
    let id: Int
    let postId: Int
    let userId: Int
    var text: String
    var likeCount: Int
    var isEdited: Bool
    let isDeleted: Bool
    let createdAt: Date
    let updatedAt: Date?
    let editedAt: Date?
    var user: UserPreview
    var hasLiked: Bool

    /// Indica si el comentario pertenece al usuario actual
    var isOwnComment: Bool {
        // Esto se determinará en el ViewModel comparando con el userId del usuario logueado
        false
    }

    /// Fecha formateada relativa (ej: "hace 2 horas")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Indica si el comentario fue editado
    var editLabel: String? {
        isEdited ? "(editado)" : nil
    }
}

// MARK: - Create Comment Form

/// Formulario para crear un nuevo comentario
struct CreateCommentForm {
    var text: String
    var mentionedUserIds: [Int]?

    init(text: String, mentionedUserIds: [Int]? = nil) {
        self.text = text
        self.mentionedUserIds = mentionedUserIds
    }

    /// Valida que el comentario sea válido
    func validate() throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedText.isEmpty {
            throw CommentError.emptyText
        }

        if trimmedText.count > 2200 {
            throw CommentError.textTooLong
        }
    }
}

// MARK: - Comment Responses

/// Respuesta del endpoint de crear comentario
struct CreateCommentResponse: Codable {
    let success: Bool
    let comment: Comment
}

/// Respuesta del endpoint de toggle like en comentario
struct ToggleCommentLikeResponse: Codable {
    let success: Bool
    let action: String // "liked" o "unliked"
    let totalLikes: Int
    let message: String?
}

// MARK: - Comment Errors

enum CommentError: LocalizedError {
    case emptyText
    case textTooLong
    case notFound
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "El texto del comentario no puede estar vacío"
        case .textTooLong:
            return "El comentario excede el límite de 2200 caracteres"
        case .notFound:
            return "Comentario no encontrado"
        case .unauthorized:
            return "No tienes permiso para editar este comentario"
        }
    }
}
