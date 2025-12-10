import Foundation

// MARK: - Comment

/// Comentario en un post del feed social
struct Comment: Codable, Identifiable {
    let id: Int
    let postId: Int
    let userId: Int
    let gymId: Int
    var commentText: String
    var likeCount: Int
    var isEdited: Bool
    let createdAt: Date
    let updatedAt: Date?
    let editedAt: Date?
    var userInfo: UserPreview?
    var hasLiked: Bool

    // NOTA: No se define CodingKeys para que el decoder use .convertFromSnakeCase automáticamente
    // post_id -> postId, user_id -> userId, comment_text -> commentText, etc.

    /// Computed property para acceder al usuario (compatibilidad)
    var user: UserPreview {
        // Si no hay userInfo, crear un placeholder
        userInfo ?? UserPreview(
            id: userId,
            fullName: "Usuario desconocido",
            profilePictureUrl: nil,
            role: "member"
        )
    }

    /// Alias para compatibilidad con el código existente
    var text: String {
        get { commentText }
        set { commentText = newValue }
    }

    // MARK: - Inicializadores

    /// Inicializador custom para compatibilidad con código existente que usa 'text'
    init(
        id: Int,
        postId: Int,
        userId: Int,
        text: String,
        likeCount: Int,
        isEdited: Bool,
        isDeleted: Bool = false, // Parámetro legacy, ignorado
        createdAt: Date,
        updatedAt: Date?,
        editedAt: Date?,
        user: UserPreview,
        hasLiked: Bool,
        gymId: Int = 0
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.gymId = gymId
        self.commentText = text
        self.likeCount = likeCount
        self.isEdited = isEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.editedAt = editedAt
        self.userInfo = user
        self.hasLiked = hasLiked
    }

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
