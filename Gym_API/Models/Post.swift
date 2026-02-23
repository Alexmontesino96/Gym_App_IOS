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

    enum CodingKeys: String, CodingKey {
        case id, role
        case fullName  // Puede venir como fullName o full_name (convertFromSnakeCase lo maneja)
        case profilePictureUrl  // Puede venir como profilePictureUrl o profile_picture_url
        case firstName  // first_name será convertido automáticamente a firstName
        case lastName   // last_name será convertido automáticamente a lastName
        case picture    // Alternativa para profilePictureUrl
        case name       // Alternativa para fullName (usado en user_info de comentarios)
        case avatar     // Alternativa para profilePictureUrl (usado en user_info de comentarios)
    }

    init(id: Int, fullName: String, profilePictureUrl: String?, role: String) {
        self.id = id
        self.fullName = fullName
        self.profilePictureUrl = profilePictureUrl
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)

        print("      🔍 DEBUG UserPreview - Decodificando nombre para user ID: \(self.id)")
        print("      📋 Todas las keys disponibles: \(container.allKeys.map { $0.stringValue })")

        // Try multiple sources for fullName (in order of priority)
        // 1. fullName (or full_name via convertFromSnakeCase)
        // 2. name (usado en user_info de comentarios)
        // 3. firstName + lastName (o first_name + last_name via convertFromSnakeCase)
        let explicitFullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        let name = try container.decodeIfPresent(String.self, forKey: .name)

        print("      🔍 explicitFullName: \(explicitFullName ?? "nil")")
        print("      🔍 name: \(name ?? "nil")")

        if let explicitFullName, !explicitFullName.trimmingCharacters(in: .whitespaces).isEmpty {
            self.fullName = explicitFullName
            print("      ✅ Usando explicitFullName: '\(explicitFullName)'")
        } else if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            self.fullName = name
            print("      ✅ Usando name: '\(name)'")
        } else {
            // first_name and last_name will be auto-converted to firstName/lastName by convertFromSnakeCase
            let first = try container.decodeIfPresent(String.self, forKey: .firstName)
            let last = try container.decodeIfPresent(String.self, forKey: .lastName)
            print("      🔍 firstName: \(first ?? "nil"), lastName: \(last ?? "nil")")

            let combined = [first, last].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            self.fullName = combined.isEmpty ? "Usuario" : combined
            print("      ✅ Nombre combinado final: '\(self.fullName)'")
        }

        // Profile picture: try multiple sources (in order of priority)
        // 1. picture
        // 2. avatar (usado en user_info de comentarios)
        // 3. profilePictureUrl (o profile_picture_url via convertFromSnakeCase)
        self.profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .picture)
            ?? container.decodeIfPresent(String.self, forKey: .avatar)
            ?? container.decodeIfPresent(String.self, forKey: .profilePictureUrl)

        print("      🖼️ profilePictureUrl: \(self.profilePictureUrl ?? "nil")")

        // Default role when missing
        self.role = try container.decodeIfPresent(String.self, forKey: .role) ?? "member"
        print("      👔 role: \(self.role)")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encodeIfPresent(profilePictureUrl, forKey: .profilePictureUrl)
        try container.encode(role, forKey: .role)
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

    // No necesitamos CodingKeys porque .convertFromSnakeCase hace el trabajo automáticamente
}

// MARK: - Post Tag

/// Etiqueta de un post (mención de usuario, evento o sesión)
struct PostTag: Codable, Identifiable {
    let id: Int
    let postId: Int?  // Opcional porque no siempre viene del backend
    let tagType: TagType
    let tagId: Int  // Se decodificará desde tag_value

    // Información del tag según tipo (opcional, viene en algunos endpoints)
    let taggedUser: UserPreview?
    let taggedEvent: TaggedEvent?
    let taggedSession: TaggedSession?

    enum CodingKeys: String, CodingKey {
        case id
        case postId  // convertFromSnakeCase lo convierte automáticamente
        case tagType  // convertFromSnakeCase convierte tag_type → tagType
        case tagValue  // convertFromSnakeCase convierte tag_value → tagValue
        case taggedUser
        case taggedEvent
        case taggedSession
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        postId = try container.decodeIfPresent(Int.self, forKey: .postId)
        tagType = try container.decode(TagType.self, forKey: .tagType)

        // Decodificar tag_value como String y convertir a Int
        if let tagValueString = try container.decodeIfPresent(String.self, forKey: .tagValue) {
            tagId = Int(tagValueString) ?? 0
            print("   📌 [PostTag] Decodificado tag_value: '\(tagValueString)' → tagId: \(tagId)")
        } else {
            tagId = 0
            print("   ⚠️ [PostTag] No hay tag_value, usando tagId: 0")
        }

        taggedUser = try container.decodeIfPresent(UserPreview.self, forKey: .taggedUser)
        taggedEvent = try container.decodeIfPresent(TaggedEvent.self, forKey: .taggedEvent)
        taggedSession = try container.decodeIfPresent(TaggedSession.self, forKey: .taggedSession)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(postId, forKey: .postId)
        try container.encode(tagType, forKey: .tagType)
        try container.encode(String(tagId), forKey: .tagValue)  // Encode as String
        try container.encodeIfPresent(taggedUser, forKey: .taggedUser)
        try container.encodeIfPresent(taggedEvent, forKey: .taggedEvent)
        try container.encodeIfPresent(taggedSession, forKey: .taggedSession)
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

    // CodingKeys mínimo solo para custom decoding
    private enum CodingKeys: String, CodingKey {
        case id, userId, gymId, caption, postType, privacy, location
        case likeCount, commentCount, viewCount, shareCount
        case isEdited, isDeleted, createdAt, updatedAt, editedAt
        case workoutData, media, tags, hasLiked, isOwnPost
        case user
        case userInfo  // .convertFromSnakeCase lo mapeará a user_info
    }

    init(
        id: Int,
        userId: Int,
        gymId: Int,
        caption: String?,
        postType: PostType,
        privacy: Privacy,
        location: String?,
        likeCount: Int,
        commentCount: Int,
        viewCount: Int,
        shareCount: Int,
        isEdited: Bool,
        isDeleted: Bool,
        createdAt: Date,
        updatedAt: Date?,
        editedAt: Date?,
        workoutData: String?,
        media: [PostMedia],
        tags: [PostTag],
        user: UserPreview,
        hasLiked: Bool,
        isOwnPost: Bool
    ) {
        self.id = id
        self.userId = userId
        self.gymId = gymId
        self.caption = caption
        self.postType = postType
        self.privacy = privacy
        self.location = location
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.viewCount = viewCount
        self.shareCount = shareCount
        self.isEdited = isEdited
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.editedAt = editedAt
        self.workoutData = workoutData
        self.media = media
        self.tags = tags
        self.user = user
        self.hasLiked = hasLiked
        self.isOwnPost = isOwnPost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        print("🔄 [Post.init(from:)] Iniciando decodificación...")

        self.id = try container.decode(Int.self, forKey: .id)
        print("   ✅ id: \(self.id)")

        self.userId = try container.decode(Int.self, forKey: .userId)
        print("   ✅ userId: \(self.userId)")

        self.gymId = try container.decode(Int.self, forKey: .gymId)
        print("   ✅ gymId: \(self.gymId)")
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
        self.postType = try container.decode(PostType.self, forKey: .postType)
        self.privacy = try container.decode(Privacy.self, forKey: .privacy)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        self.commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        self.viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        self.shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0
        self.isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        self.isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false

        func parseDate(_ key: CodingKeys) throws -> Date {
            if let dateStr = try container.decodeIfPresent(String.self, forKey: key) {
                if let date = Post.parseAPIDate(dateStr) {
                    return date
                }
            }
            if let date = try? container.decode(Date.self, forKey: key) {
                return date
            }
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid date format")
        }

        self.createdAt = try parseDate(.createdAt)
        print("   ✅ createdAt: \(self.createdAt)")

        self.updatedAt = try? parseDate(.updatedAt)
        self.editedAt = try? parseDate(.editedAt)

        self.workoutData = try container.decodeIfPresent(String.self, forKey: .workoutData)
        print("   ✅ workoutData parsed")

        print("   🖼️ Decodificando media...")
        self.media = try container.decodeIfPresent([PostMedia].self, forKey: .media) ?? []
        print("   ✅ media: \(self.media.count) items")

        print("   🏷️ Decodificando tags...")
        self.tags = try container.decodeIfPresent([PostTag].self, forKey: .tags) ?? []
        print("   ✅ tags: \(self.tags.count) items")

        print("   👤 Decodificando user/userInfo...")
        print("   🔍 Keys disponibles en container: \(container.allKeys.map { $0.stringValue })")

        // Try decoding from 'user' key first
        var userFromUser: UserPreview? = nil
        do {
            userFromUser = try container.decodeIfPresent(UserPreview.self, forKey: .user)
            if let u = userFromUser {
                print("   ✅ user decodificado desde 'user' key: \(u.fullName)")
            } else {
                print("   ⚠️ 'user' key no presente o null")
            }
        } catch {
            print("   ❌ Error decodificando desde 'user' key: \(error)")
        }

        // Try decoding from 'userInfo' key (maps to "user_info" in JSON) if first attempt failed
        var userFromUserInfo: UserPreview? = nil
        if userFromUser == nil {
            do {
                print("   🔍 Intentando decodificar desde 'userInfo' (que mapea a 'user_info' en JSON)...")
                userFromUserInfo = try container.decodeIfPresent(UserPreview.self, forKey: .userInfo)
                if let u = userFromUserInfo {
                    print("   ✅ user decodificado desde 'userInfo' key: \(u.fullName)")
                } else {
                    print("   ⚠️ 'userInfo' key ('user_info' en JSON) no presente o null")
                }
            } catch {
                print("   ❌ Error decodificando desde 'userInfo' key: \(error)")
                print("   📋 Detalle del error: \(error.localizedDescription)")
            }
        }

        if let user = userFromUser ?? userFromUserInfo {
            self.user = user
            print("   ✅ user final asignado: \(user.fullName)")
        } else {
            self.user = UserPreview(id: self.userId, fullName: "Usuario", profilePictureUrl: nil, role: "member")
            print("   ⚠️ user fallback usado - ninguna decodificación exitosa")
        }

        self.hasLiked = try container.decodeIfPresent(Bool.self, forKey: .hasLiked) ?? false
        self.isOwnPost = try container.decodeIfPresent(Bool.self, forKey: .isOwnPost) ?? false

        print("✅ [Post.init(from:)] Decodificación completa - Post ID: \(self.id)")
    }

    private static func parseAPIDate(_ str: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for fmt in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = fmt
            if let d = df.date(from: str) { return d }
        }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(gymId, forKey: .gymId)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(postType, forKey: .postType)
        try container.encode(privacy, forKey: .privacy)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(shareCount, forKey: .shareCount)
        try container.encode(isEdited, forKey: .isEdited)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(editedAt, forKey: .editedAt)
        try container.encodeIfPresent(workoutData, forKey: .workoutData)
        try container.encode(media, forKey: .media)
        try container.encode(tags, forKey: .tags)
        try container.encode(user, forKey: .user)
        try container.encode(hasLiked, forKey: .hasLiked)
        try container.encode(isOwnPost, forKey: .isOwnPost)
    }

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
