import Foundation

// MARK: - Cached Message Models

/// Modelo de mensaje optimizado para almacenamiento en caché
struct CachedMessage: Codable {
    let id: String
    let conversationId: String
    let text: String
    let authorId: String
    let authorName: String
    let timestamp: Date
    let isFromCurrentUser: Bool
    let syncStatus: String
    let attachments: [CachedAttachment]
    
    // MARK: - Initialization
    
    /// Crea un CachedMessage a partir de un ChatMessage
    init(from chatMessage: ChatMessage) {
        self.id = chatMessage.id
        self.conversationId = chatMessage.conversationId
        self.text = chatMessage.text
        self.authorId = chatMessage.authorId
        self.authorName = chatMessage.authorName
        self.timestamp = chatMessage.timestamp
        self.isFromCurrentUser = chatMessage.isFromCurrentUser
        self.syncStatus = chatMessage.syncStatus.rawValue
        self.attachments = chatMessage.attachments.map { CachedAttachment(from: $0) }
    }
    
    /// Convierte el CachedMessage a ChatMessage
    func toChatMessage() -> ChatMessage {
        return ChatMessage(
            id: id,
            conversationId: conversationId,
            text: text,
            authorId: authorId,
            authorName: authorName,
            timestamp: timestamp,
            isFromCurrentUser: isFromCurrentUser,
            syncStatus: MessageSyncStatus(rawValue: syncStatus) ?? .synced,
            isRead: true,
            attachments: attachments.map { $0.toChatAttachment() }
        )
    }
}

/// Modelo de attachment optimizado para caché
struct CachedAttachment: Codable {
    let id: String
    let type: String
    let url: String?
    let title: String?
    let previewURL: String?
    
    /// Crea un CachedAttachment a partir de un ChatAttachment
    init(from attachment: ChatAttachment) {
        self.id = attachment.id
        self.type = attachment.type.rawValue
        self.url = attachment.url
        self.title = attachment.title
        self.previewURL = attachment.previewURL
    }
    
    /// Convierte el CachedAttachment a ChatAttachment
    func toChatAttachment() -> ChatAttachment {
        return ChatAttachment(
            id: id,
            type: ChatAttachment.AttachmentType(rawValue: type) ?? .file,
            url: url,
            title: title,
            previewURL: previewURL
        )
    }
}

// MARK: - Conversation Message Cache

/// Contenedor para los mensajes cacheados de una conversación
struct ConversationMessageCache: Codable {
    let conversationId: String
    let messages: [CachedMessage]
    let lastUpdated: Date
    let oldestMessageId: String?
    let newestMessageId: String?
    let totalMessages: Int
    
    /// Inicializa un caché de conversación
    init(conversationId: String, messages: [CachedMessage]) {
        self.conversationId = conversationId
        self.messages = messages
        self.lastUpdated = Date()
        self.oldestMessageId = messages.last?.id
        self.newestMessageId = messages.first?.id
        self.totalMessages = messages.count
    }
}

// MARK: - Cache Metadata

/// Metadata del sistema de caché para gestión y estadísticas
struct MessageCacheMetadata: Codable {
    let version: String
    let createdAt: Date
    let lastCleanup: Date
    let totalConversations: Int
    let totalMessages: Int
    let totalSizeBytes: Int64
    
    static let currentVersion = "1.0"
    
    /// Inicializa metadata con valores por defecto
    init() {
        self.version = Self.currentVersion
        self.createdAt = Date()
        self.lastCleanup = Date()
        self.totalConversations = 0
        self.totalMessages = 0
        self.totalSizeBytes = 0
    }
    
    /// Actualiza las estadísticas del caché
    init(version: String = currentVersion, createdAt: Date = Date(), lastCleanup: Date, totalConversations: Int, totalMessages: Int, totalSizeBytes: Int64) {
        self.version = version
        self.createdAt = createdAt
        self.lastCleanup = lastCleanup
        self.totalConversations = totalConversations
        self.totalMessages = totalMessages
        self.totalSizeBytes = totalSizeBytes
    }
}

// MARK: - Cache Statistics

/// Estadísticas del caché para mostrar en la UI
struct MessageCacheStats {
    var totalConversations = 0
    var totalMessages = 0
    var totalSizeBytes: Int64 = 0
    var lastUpdated = Date()
    var oldestCacheDate: Date?
    var newestCacheDate: Date?
    
    /// Formatea el tamaño en bytes a string legible
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
    
    /// Indica si el caché está vacío
    var isEmpty: Bool {
        return totalConversations == 0 && totalMessages == 0
    }
}

// MARK: - Cache Configuration

/// Configuración del sistema de caché
struct MessageCacheConfig {
    static let maxMessagesPerConversation = 15 // Reducido aún más para evitar SIGKILL
    static let maxCachedConversations = 30 // Reducido aún más para evitar SIGKILL  
    static let maxCacheSizeBytes: Int64 = 10 * 1024 * 1024 // Reducido a 10MB para emergencia
    static let cacheDirectoryName = "MessageCache"
    static let metadataFileName = "cache_metadata.json"
    static let maxCacheAgeDays = 10 // Reducido para limpieza más frecuente
    
    /// Nombres de archivos especiales
    enum FileName {
        static let metadata = "cache_metadata.json"
        static let conversationIndex = "conversation_index.json"
        
        /// Genera nombre de archivo para una conversación
        static func conversation(_ id: String) -> String {
            // Sanitizar el ID para uso como nombre de archivo
            let sanitized = id.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
            return "\(sanitized).json"
        }
    }
}

// MARK: - Cache Errors

/// Errores específicos del sistema de caché
enum MessageCacheError: LocalizedError {
    case directoryCreationFailed
    case fileNotFound(String)
    case corruptedData(String)
    case diskSpaceInsufficient
    case encodingFailed
    case decodingFailed(Error)
    case conversationNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "No se pudo crear el directorio de caché"
        case .fileNotFound(let filename):
            return "Archivo de caché no encontrado: \(filename)"
        case .corruptedData(let details):
            return "Datos de caché corruptos: \(details)"
        case .diskSpaceInsufficient:
            return "Espacio en disco insuficiente para el caché"
        case .encodingFailed:
            return "Error codificando datos para caché"
        case .decodingFailed(let error):
            return "Error decodificando datos de caché: \(error.localizedDescription)"
        case .conversationNotFound(let id):
            return "Conversación no encontrada en caché: \(id)"
        }
    }
}