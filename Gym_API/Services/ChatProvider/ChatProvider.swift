import Foundation
import Combine

// MARK: - Chat Provider Protocol
/// Protocolo principal que define la interfaz para cualquier proveedor de chat
/// Esta abstracción permite cambiar fácilmente de GetStream a Firebase/Supabase
protocol ChatProvider: AnyObject {
    // MARK: - Connection Management
    func connect(credentials: ChatCredentials) async throws
    func disconnect() async
    var connectionState: ChatConnectionState { get }
    var connectionStatePublisher: AnyPublisher<ChatConnectionState, Never> { get }
    
    // MARK: - Message Operations
    func sendMessage(_ message: ChatMessage, to conversationId: String) async throws -> String
    func getMessages(for conversationId: String, limit: Int, before messageId: String?) async throws -> [ChatMessage]
    func markAsRead(messagesUpTo messageId: String, in conversationId: String) async throws
    func deleteMessage(_ messageId: String, in conversationId: String) async throws
    func editMessage(_ messageId: String, newText: String, in conversationId: String) async throws
    
    // MARK: - Conversation Management
    func getConversations() async throws -> [ChatConversation]
    func createConversation(_ conversation: CreateConversationRequest) async throws -> ChatConversation
    func joinConversation(_ conversationId: String) async throws
    func leaveConversation(_ conversationId: String) async throws
    
    // MARK: - Real-time Updates
    var messageUpdatesPublisher: AnyPublisher<MessageUpdate, Never> { get }
    var conversationUpdatesPublisher: AnyPublisher<ConversationUpdate, Never> { get }
    var typingUpdatesPublisher: AnyPublisher<TypingUpdate, Never> { get }
    
    // MARK: - User Management
    func setCurrentUser(_ user: ChatUser) async throws
    func getUsers(in conversationId: String) async throws -> [ChatUser]
    
    // MARK: - Typing Indicators
    func startTyping(in conversationId: String) async throws
    func stopTyping(in conversationId: String) async throws
    
    // MARK: - Push Notifications
    func registerForPushNotifications(token: String) async throws
    func unregisterFromPushNotifications() async throws
}

// MARK: - Chat Provider Manager
/// Gestor centralizado que maneja el proveedor de chat actual y proporciona una interfaz unificada
@MainActor
class ChatProviderManager: ObservableObject {
    static let shared = ChatProviderManager()
    
    // MARK: - Published Properties
    @Published var currentProvider: ChatProvider?
    @Published var isInitialized = false
    @Published var initializationError: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let providerType: ChatProviderType
    
    private init() {
        // Por defecto usa GetStream, pero se puede cambiar fácilmente
        self.providerType = .getStream
        print("💬 ChatProviderManager inicializado con proveedor: \(providerType)")
    }
    
    // MARK: - Provider Management
    
    /// Inicializa el proveedor de chat con authService opcional
    func initializeProvider(authService: AuthServiceProtocol? = nil) async {
        guard !isInitialized else { return }
        
        do {
            let provider = try createProvider(type: providerType)
            
            // Configurar authService si es GetStreamChatProvider
            if let streamProvider = provider as? GetStreamChatProvider,
               let authService = authService {
                streamProvider.setAuthService(authService)
                print("✅ AuthService configurado en el provider")
            }
            
            currentProvider = provider
            isInitialized = true
            initializationError = nil
            
            setupProviderObservers(provider)
            
            print("✅ Proveedor de chat inicializado: \(providerType)")
        } catch {
            initializationError = error.localizedDescription
            print("❌ Error inicializando proveedor: \(error)")
        }
    }
    
    /// Cambia el proveedor de chat (para migración)
    func switchProvider(to newType: ChatProviderType) async throws {
        print("🔄 Cambiando proveedor de \(providerType) a \(newType)")
        
        // Desconectar proveedor actual
        await currentProvider?.disconnect()
        
        // Crear nuevo proveedor
        let newProvider = try createProvider(type: newType)
        
        // TODO: Migrar datos si es necesario
        await migrateDataIfNeeded(from: currentProvider, to: newProvider)
        
        currentProvider = newProvider
        setupProviderObservers(newProvider)
        
        print("✅ Proveedor cambiado exitosamente a \(newType)")
    }
    
    // MARK: - Provider Factory
    
    private func createProvider(type: ChatProviderType) throws -> ChatProvider {
        switch type {
        case .getStream:
            return GetStreamChatProvider()
        case .firebase:
            return FirebaseChatProvider()
        case .supabase:
            fatalError("Supabase provider no está implementado")
        }
    }
    
    // MARK: - Data Migration
    
    private func migrateDataIfNeeded(from oldProvider: ChatProvider?, to newProvider: ChatProvider) async {
        guard let oldProvider = oldProvider else { return }
        
        print("📦 Iniciando migración de datos...")
        
        // Aquí implementarías la lógica de migración específica
        // Por ejemplo: exportar mensajes del cache local e importarlos al nuevo proveedor
        
        do {
            // 1. Exportar conversaciones
            let conversations = try await oldProvider.getConversations()
            
            // 2. Para cada conversación, exportar mensajes
            for conversation in conversations {
                let _ = try await oldProvider.getMessages(
                    for: conversation.id,
                    limit: 1000, // Ajustar según necesidades
                    before: nil
                )
                
                // 3. Importar a nuevo proveedor (esto dependería de la implementación)
                // await importMessages(messages, to: newProvider, conversation: conversation)
            }
            
            print("✅ Migración de datos completada")
        } catch {
            print("❌ Error durante migración: \(error)")
        }
    }
    
    // MARK: - Observer Setup
    
    private func setupProviderObservers(_ provider: ChatProvider) {
        cancellables.removeAll()
        
        // Observar actualizaciones de mensajes
        provider.messageUpdatesPublisher
            .sink { update in
                NotificationCenter.default.post(
                    name: .chatMessageUpdate,
                    object: nil,
                    userInfo: ["update": update]
                )
            }
            .store(in: &cancellables)
        
        // Observar actualizaciones de conversaciones
        provider.conversationUpdatesPublisher
            .sink { update in
                NotificationCenter.default.post(
                    name: .chatConversationUpdate,
                    object: nil,
                    userInfo: ["update": update]
                )
            }
            .store(in: &cancellables)
        
        // Observar cambios de estado de conexión
        provider.connectionStatePublisher
            .sink { state in
                NotificationCenter.default.post(
                    name: .chatConnectionStateChanged,
                    object: nil,
                    userInfo: ["state": state]
                )
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Convenience Methods
    
    /// Método conveniente para enviar mensaje
    func sendMessage(_ message: ChatMessage, to conversationId: String) async throws -> String {
        guard let provider = currentProvider else {
            throw ChatProviderError.notInitialized
        }
        
        return try await provider.sendMessage(message, to: conversationId)
    }
    
    /// Método conveniente para obtener mensajes
    func getMessages(for conversationId: String, limit: Int = 50, before messageId: String? = nil) async throws -> [ChatMessage] {
        guard let provider = currentProvider else {
            throw ChatProviderError.notInitialized
        }
        
        return try await provider.getMessages(for: conversationId, limit: limit, before: messageId)
    }
    
    /// Método conveniente para obtener conversaciones
    func getConversations() async throws -> [ChatConversation] {
        guard let provider = currentProvider else {
            throw ChatProviderError.notInitialized
        }
        
        return try await provider.getConversations()
    }
    
    /// Método conveniente para conectar
    func connect(credentials: ChatCredentials) async throws {
        guard let provider = currentProvider else {
            throw ChatProviderError.notInitialized
        }
        
        try await provider.connect(credentials: credentials)
    }

    /// Resetea el estado del chat provider (para logout/cambio de usuario)
    func reset() async {
        print("🧹 ChatProviderManager.reset() - limpiando estado del proveedor de chat")
        // Desconectar proveedor actual
        await currentProvider?.disconnect()
        // Limpiar observadores y estado
        cancellables.removeAll()
        currentProvider = nil
        isInitialized = false
        initializationError = nil
        print("✅ ChatProviderManager reseteado")
    }
}

// MARK: - Provider Types

enum ChatProviderType: String, CaseIterable {
    case getStream = "getstream"
    case firebase = "firebase"
    case supabase = "supabase"
    
    var displayName: String {
        switch self {
        case .getStream: return "GetStream"
        case .firebase: return "Firebase"
        case .supabase: return "Supabase"
        }
    }
}

// MARK: - Chat Provider Errors

enum ChatProviderError: LocalizedError {
    case notInitialized
    case invalidCredentials
    case connectionFailed
    case messageNotFound
    case conversationNotFound
    case unauthorized
    case networkError(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Chat provider not initialized"
        case .invalidCredentials:
            return "Invalid chat credentials"
        case .connectionFailed:
            return "Failed to connect to chat service"
        case .messageNotFound:
            return "Message not found"
        case .conversationNotFound:
            return "Conversation not found"
        case .unauthorized:
            return "Unauthorized access"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Models

struct ChatCredentials {
    let token: String
    let apiKey: String
    let userId: String
    let userInfo: ChatUser?
    
    init(token: String, apiKey: String, userId: String, userInfo: ChatUser? = nil) {
        self.token = token
        self.apiKey = apiKey
        self.userId = userId
        self.userInfo = userInfo
    }
}

struct ChatUser: Hashable {
    let id: String
    let name: String
    let avatarURL: String?
    let metadata: [String: Any]
    
    init(id: String, name: String, avatarURL: String? = nil, metadata: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.metadata = metadata
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(avatarURL)
    }
    
    static func == (lhs: ChatUser, rhs: ChatUser) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.avatarURL == rhs.avatarURL
    }
}

struct ChatConversation: Identifiable {
    let id: String
    let name: String?
    let type: ConversationType
    let members: [ChatUser]
    let lastMessage: ChatMessage?
    let lastActivity: Date
    let unreadCount: Int
    let metadata: [String: Any]
    
    enum ConversationType: String {
        case direct
        case group
        case channel
        case general
    }
}

struct CreateConversationRequest {
    let id: String? // ID específico del canal (opcional)
    let name: String?
    let type: ChatConversation.ConversationType
    let members: [String] // User IDs
    let metadata: [String: Any]
    
    init(id: String? = nil, name: String? = nil, type: ChatConversation.ConversationType, members: [String], metadata: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.type = type
        self.members = members
        self.metadata = metadata
    }
}

enum ChatConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(Error)
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - Update Models

struct MessageUpdate {
    let type: MessageUpdateType
    let message: ChatMessage
    let conversationId: String
    
    enum MessageUpdateType {
        case new
        case updated
        case deleted
    }
}

struct ConversationUpdate {
    let type: ConversationUpdateType
    let conversation: ChatConversation
    
    enum ConversationUpdateType {
        case new
        case updated
        case deleted
        case memberAdded(ChatUser)
        case memberRemoved(ChatUser)
    }
}

struct TypingUpdate {
    let conversationId: String
    let user: ChatUser
    let isTyping: Bool
}

// MARK: - Notification Names

extension Notification.Name {
    static let chatMessageUpdate = Notification.Name("chatMessageUpdate")
    static let chatConversationUpdate = Notification.Name("chatConversationUpdate")
    static let chatConnectionStateChanged = Notification.Name("chatConnectionStateChanged")
    static let messagesUpdatedFromServer = Notification.Name("messagesUpdatedFromServer")
}
