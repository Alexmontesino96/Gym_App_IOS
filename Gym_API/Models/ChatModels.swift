import Foundation

// MARK: - Chat Channel Data
/// Modelo agnóstico de proveedor para representar un canal de chat
struct ChatChannelData: Identifiable, Codable {
    let id: String
    let name: String?
    let type: ChatChannelType
    let participants: [String] // User IDs
    let lastMessage: ChatMessageData?
    let lastMessageAt: Date?
    let createdAt: Date
    let unreadCount: Int
    let isActive: Bool
    
    /// Fecha efectiva para ordenamiento (último mensaje o creación)
    var effectiveDate: Date {
        return lastMessageAt ?? createdAt
    }
    
    /// Nombre de visualización
    var displayName: String {
        return name ?? "Chat \(id)"
    }
}

// MARK: - Chat Message Data
/// Modelo agnóstico de proveedor para representar un mensaje
struct ChatMessageData: Identifiable, Codable {
    let id: String
    let text: String
    let authorId: String
    let authorName: String?
    let authorAvatarURL: String?
    let timestamp: Date
    let channelId: String
    let isFromCurrentUser: Bool
    let attachments: [ChatAttachmentData]
    
    enum CodingKeys: String, CodingKey {
        case id, text, authorId, authorName, authorAvatarURL, timestamp, channelId, isFromCurrentUser, attachments
    }
}

// MARK: - Chat Attachment Data
/// Modelo agnóstico para archivos adjuntos
struct ChatAttachmentData: Codable {
    let id: String
    let type: AttachmentType
    let url: String?
    let title: String?
    let previewURL: String?
    
    enum AttachmentType: String, Codable {
        case image = "image"
        case file = "file"
        case video = "video"
        case audio = "audio"
        case link = "link"
    }
}

// MARK: - Chat Channel Type
/// Tipos de canales soportados
enum ChatChannelType: String, Codable, CaseIterable {
    case direct = "direct"
    case event = "event"
    case general = "general"
    case group = "group"
    
    var displayName: String {
        switch self {
        case .direct:
            return "Direct"
        case .event:
            return "Events"
        case .general:
            return "General"
        case .group:
            return "Group"
        }
    }
    
    var iconName: String {
        switch self {
        case .direct:
            return "person.circle.fill"
        case .event:
            return "calendar.circle.fill"
        case .general:
            return "bubble.left.and.bubble.right.fill"
        case .group:
            return "person.3.fill"
        }
    }
}

// MARK: - Chat Provider Status
/// Estado del proveedor de chat (usando el error del sistema principal)
enum ChatProviderStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - Legacy StreamChat Compatibility
/// Modelo de mensaje compatible con StreamChat (para compatibilidad)
struct StreamChatMessage: Identifiable {
    let id: String
    let text: String
    let user: MessageUser
    let timestamp: Date
    let isFromCurrentUser: Bool
    
    init(id: String, text: String, user: MessageUser, timestamp: Date, isFromCurrentUser: Bool) {
        self.id = id
        self.text = text
        self.user = user
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
    }
}

// MARK: - Message User
struct MessageUser {
    let id: String
    let name: String
    let avatarURL: URL?
    
    init(id: String, name: String, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
    }
}

// MARK: - Channel Last Message Model
struct ChannelLastMessage: Codable {
    let channelId: String
    let lastMessageAt: Date?
    let lastMessageText: String?
    let hasMessages: Bool
    let fetchedAt: Date
    
    init(channelId: String, lastMessageAt: Date? = nil, lastMessageText: String? = nil) {
        self.channelId = channelId
        self.lastMessageAt = lastMessageAt
        self.lastMessageText = lastMessageText
        self.hasMessages = lastMessageAt != nil && lastMessageText != nil && !lastMessageText!.isEmpty
        self.fetchedAt = Date()
    }
}

// MARK: - Message Sync Status
enum MessageSyncStatus: String, CaseIterable {
    case pending = "pending"
    case sending = "sending"
    case synced = "synced"
    case failed = "failed"
}

// MARK: - Media Content Type
enum MediaContentType {
    case image(url: URL)
    case video(url: URL)
    case file(url: URL, name: String)
}

// MARK: - Chat Message
/// Modelo unificado de mensaje para el sistema de chat
struct ChatMessage: Identifiable {
    let id: String
    let conversationId: String
    let text: String
    let authorId: String
    let authorName: String
    let authorAvatarURL: String?
    let timestamp: Date
    let isFromCurrentUser: Bool
    var syncStatus: MessageSyncStatus
    let isRead: Bool
    let attachments: [ChatAttachment]
    
    init(id: String, conversationId: String, text: String, authorId: String, authorName: String, authorAvatarURL: String? = nil, timestamp: Date, isFromCurrentUser: Bool, syncStatus: MessageSyncStatus = .synced, isRead: Bool = false, attachments: [ChatAttachment] = []) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
        self.syncStatus = syncStatus
        self.isRead = isRead
        self.attachments = attachments
    }
}

// MARK: - Chat Attachment
struct ChatAttachment: Identifiable {
    let id: String
    let type: AttachmentType
    let url: String?
    let title: String?
    let previewURL: String?
    
    enum AttachmentType: String, CaseIterable {
        case image = "image"
        case file = "file"
        case video = "video"
        case audio = "audio"
        case link = "link"
    }
}

// MARK: - Message Fingerprint
/// Huella digital de mensaje para deduplicación de mensajes optimistas
/// Compara contenido, autor, conversación y timestamp (truncado a segundos)
struct MessageFingerprint: Hashable {
    let text: String
    let authorId: String
    let conversationId: String
    let timestamp: TimeInterval  // Truncado a segundos

    init(from message: ChatMessage) {
        self.text = message.text
        self.authorId = message.authorId
        self.conversationId = message.conversationId
        // Truncar a segundos para tolerar delays de red
        self.timestamp = floor(message.timestamp.timeIntervalSince1970)
    }
}

// MARK: - Channel ID Parsing Extension
extension String {
    
    /// Extrae información legible del stream_channel_id
    func parseStreamChannelId() -> (type: ChatChannelType, displayName: String, metadata: [String: String]) {
        var metadata: [String: String] = [:]
        
        // Patrón para salas generales: room_{nombre}_{gym_id}
        if self.hasPrefix("room_") {
            let components = self.split(separator: "_")
            if components.count >= 3 {
                let roomName = String(components[1])
                let gymId = String(components[2])
                metadata["gymId"] = gymId
                metadata["roomName"] = roomName
                return (.general, roomName, metadata)
            }
        }
        
        // Patrón para eventos: event_{event_id}_{user_id_hash}
        if self.hasPrefix("event_") {
            let components = self.split(separator: "_")
            if components.count >= 3 {
                let eventId = String(components[1])
                let userHash = String(components[2])
                metadata["eventId"] = eventId
                metadata["userHash"] = userHash
                // El nombre real del evento viene del campo 'name' de la API
                return (.event, "Evento", metadata)
            }
        }
        
        // Patrón para chats directos: direct_user_{user_id_1}_user_{user_id_2}
        if self.hasPrefix("direct_") {
            let components = self.split(separator: "_")
            if components.count >= 5 {
                let userId1 = String(components[2])
                let userId2 = String(components[4])
                metadata["userId1"] = userId1
                metadata["userId2"] = userId2
                // El nombre real viene del campo 'name' de la API
                return (.direct, "Chat Directo", metadata)
            }
        }
        
        // Si no coincide con ningún patrón, devuelve el ID original
        return (.general, self, metadata)
    }
    
    /// Determina el tipo de canal basado en el stream_channel_id
    func getChannelType() -> ChatChannelType {
        if self.hasPrefix("room_") {
            return .general
        } else if self.hasPrefix("event_") {
            return .event
        } else if self.hasPrefix("direct_") {
            return .direct
        } else {
            return .group
        }
    }
}

