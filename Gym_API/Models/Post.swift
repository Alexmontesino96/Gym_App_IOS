import Foundation

// MARK: - Enumerations

/// Tipo de medio en un post
enum PostMediaType: String, Codable {
    case image
    case video
}

/// Tipo de post según contenido
enum PostType: String, Codable {
    case singleImage = "single_image"
    case gallery
    case video
    case workout
}

/// Nivel de privacidad del post
enum Privacy: String, Codable {
    case `public`
    case `private`
}

/// Tipo de etiqueta (menciones, eventos, sesiones)
enum TagType: String, Codable {
    case mention
    case event
    case session
}

// MARK: - User Preview

/// Información básica de usuario para mostrar en posts y comentarios
struct UserPreview: Codable, Identifiable {
    let id: Int
    let fullName: String
    let profilePictureUrl: String?
    let role: String

    var profilePictureURL: URL? {
        guard let urlString = profilePictureUrl else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Post Media

/// Medio (imagen o video) adjunto a un post
struct PostMedia: Codable, Identifiable {
    let id: Int
    let postId: Int
    let mediaType: PostMediaType
    let mediaUrl: String
    let thumbnailUrl: String?
    let displayOrder: Int
    let width: Int?
    let height: Int?
    let fileSize: Int?
    let durationSeconds: Double?

    var mediaURL: URL? {
        URL(string: mediaUrl)
    }

    var thumbnailURL: URL? {
        guard let thumbnailUrl = thumbnailUrl else { return nil }
        return URL(string: thumbnailUrl)
    }

    /// Duración formateada para videos (ej: "2:35")
    var formattedDuration: String? {
        guard let duration = durationSeconds else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Post Tag

/// Etiqueta de un post (mención de usuario, evento o sesión)
struct PostTag: Codable, Identifiable {
    let id: Int
    let postId: Int
    let tagType: TagType
    let tagId: Int

    // Información del tag según tipo (opcional, viene en algunos endpoints)
    let taggedUser: UserPreview?
    let taggedEvent: TaggedEvent?
    let taggedSession: TaggedSession?

    enum CodingKeys: String, CodingKey {
        case id, postId, tagType, tagId
        case taggedUser = "tagged_user"
        case taggedEvent = "tagged_event"
        case taggedSession = "tagged_session"
    }
}

/// Información básica de evento etiquetado
struct TaggedEvent: Codable, Identifiable {
    let id: Int
    let title: String
    let startDate: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case startDate = "start_date"
    }
}

/// Información básica de sesión/clase etiquetada
struct TaggedSession: Codable, Identifiable {
    let id: Int
    let title: String
    let startTime: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case startTime = "start_time"
    }
}

// MARK: - Post

/// Post del feed social con toda su información
struct Post: Codable, Identifiable {
    let id: Int
    let userId: Int
    let gymId: Int
    var caption: String?
    let postType: PostType
    let privacy: Privacy
    var location: String?
    var likeCount: Int
    var commentCount: Int
    var viewCount: Int
    var shareCount: Int
    var isEdited: Bool
    let isDeleted: Bool
    let createdAt: Date
    let updatedAt: Date?
    let editedAt: Date?
    var workoutData: String? // JSON string con datos de workout
    var media: [PostMedia]
    var tags: [PostTag]
    var user: UserPreview
    var hasLiked: Bool
    let isOwnPost: Bool

    /// Menciones extraídas de tags
    var mentions: [UserPreview] {
        tags.compactMap { tag in
            tag.tagType == .mention ? tag.taggedUser : nil
        }
    }

    /// Evento etiquetado (si existe)
    var taggedEvent: TaggedEvent? {
        tags.first(where: { $0.tagType == .event })?.taggedEvent
    }

    /// Sesión etiquetada (si existe)
    var taggedSession: TaggedSession? {
        tags.first(where: { $0.tagType == .session })?.taggedSession
    }

    /// Media principal (primera imagen/video)
    var primaryMedia: PostMedia? {
        media.first
    }

    /// Fecha formateada relativa (ej: "hace 2 horas")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Create Post Form

/// Formulario para crear un nuevo post (usado en PostService)
struct CreatePostForm {
    var caption: String?
    var postType: PostType
    var privacy: Privacy?
    var location: String?
    var files: [URL] // Rutas locales a archivos (imágenes/videos)
    var workoutDataJSON: String?
    var taggedEventId: Int?
    var taggedSessionId: Int?
    var mentionedUserIds: [Int]?

    init(
        caption: String? = nil,
        postType: PostType,
        privacy: Privacy? = .public,
        location: String? = nil,
        files: [URL] = [],
        workoutDataJSON: String? = nil,
        taggedEventId: Int? = nil,
        taggedSessionId: Int? = nil,
        mentionedUserIds: [Int]? = nil
    ) {
        self.caption = caption
        self.postType = postType
        self.privacy = privacy
        self.location = location
        self.files = files
        self.workoutDataJSON = workoutDataJSON
        self.taggedEventId = taggedEventId
        self.taggedSessionId = taggedSessionId
        self.mentionedUserIds = mentionedUserIds
    }
}

// MARK: - Response Wrappers

/// Respuesta del endpoint de creación de post
struct CreatePostResponse: Codable {
    let success: Bool
    let post: Post
}

/// Respuesta del endpoint de toggle like
struct ToggleLikeResponse: Codable {
    let success: Bool
    let action: String // "liked" o "unliked"
    let totalLikes: Int
    let message: String?
}
