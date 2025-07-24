import Foundation
import StreamChat
import Combine

// MARK: - Stream Chat Service
@MainActor
class StreamChatService: ObservableObject {
    static let shared = StreamChatService()
    
    // MARK: - Published Properties
    @Published var messages: [StreamChatMessage] = []
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var typingUsers: [String] = []
    
    // MARK: - Private Properties
    private var chatClient: ChatClient?
    private var channelController: ChatChannelController?
    private var currentChannel: ChatChannel?
    private var cancellables = Set<AnyCancellable>()
    
    // Token refresh properties
    private var currentToken: String?
    private var currentApiKey: String?
    private var currentUserId: String?
    
    // MARK: - Initialization
    private init() {
        print("🔧 StreamChatService inicializado")
    }
    
    // MARK: - Helper for Main Thread Updates
    private func updateOnMainThread(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async {
                updates()
            }
        }
    }
    
    // MARK: - Token Provider for Stream
    private func createTokenProvider() -> TokenProvider {
        return { completion in
            print("🔄 Stream solicitando renovación de token...")
            
            // Necesitamos obtener un nuevo token desde ChatService
            Task { @MainActor in
                guard let newToken = await ChatService.shared.getStreamToken() else {
                    completion(.failure(NSError(domain: "TokenRefresh", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo renovar el token"])))
                    return
                }
                
                self.currentToken = newToken.token
                
                do {
                    let streamToken = try Token(rawValue: newToken.token)
                    completion(.success(streamToken))
                    print("✅ Token renovado exitosamente")
                } catch {
                    completion(.failure(error))
                    print("❌ Error renovando token: \(error)")
                }
            }
        }
    }
    
    // MARK: - Connect to Stream.io
    func connectToChat(token: String, apiKey: String, userId: String, channelId: String) {
        print("🔗 Conectando a Stream.io...")
        print("🔹 API Key: \(apiKey)")
        print("🔹 User ID: \(userId)")
        print("🔹 Channel ID: \(channelId)")
        
        // Si ya estamos conectados al mismo canal, no hacer nada
        if isConnected && currentChannel?.cid.id == channelId {
            print("✅ Ya conectado al canal \(channelId)")
            return
        }
        
        // Si hay una conexión previa, desconectar primero
        if isConnected {
            print("🔄 Desconectando conexión previa...")
            disconnect()  // Ya no es async
            // Reconectar después de desconectar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performConnection(token: token, apiKey: apiKey, userId: userId, channelId: channelId)
            }
            return
        }
        
        performConnection(token: token, apiKey: apiKey, userId: userId, channelId: channelId)
    }
    
    private func performConnection(token: String, apiKey: String, userId: String, channelId: String) {
        print("🔧 Iniciando performConnection...")
        print("📋 Parametros recibidos:")
        print("   - Token: \(String(token.prefix(20)))...")
        print("   - API Key: \(apiKey)")
        print("   - User ID: \(userId)")
        print("   - Channel ID: \(channelId)")
        
        isLoading = true
        errorMessage = nil
        
        // Guardar información para token refresh
        currentToken = token
        currentApiKey = apiKey
        currentUserId = userId
        
        // Configurar el cliente de Stream  
        let config = ChatClientConfig(apiKey: APIKey(apiKey))
        print("🔧 Config de Stream creado")
        
        chatClient = ChatClient(config: config)
        print("🔧 ChatClient creado")
        
        // Agregar timeout para connectUser
        let timeoutWorkItem = DispatchWorkItem {
            self.updateOnMainThread {
                if self.isLoading {
                    print("⏱️ Timeout en connectUser después de 20 segundos")
                    self.errorMessage = "Timeout al conectar usuario"
                    self.isLoading = false
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeoutWorkItem)
        
        // Conectar usuario con tokenProvider para tokens que expiran
        do {
            let _ = try Token(rawValue: token)
            print("🔧 Token de Stream creado y validado")
            
            print("🔧 Iniciando connectUser con tokenProvider...")
            chatClient?.connectUser(
                userInfo: StreamChat.UserInfo(
                    id: userId,
                    name: "Usuario \(userId.replacingOccurrences(of: "user_", with: ""))",
                    imageURL: nil
                ),
                tokenProvider: createTokenProvider()
            ) { [weak self] (error: Error?) in
                timeoutWorkItem.cancel() // Cancelar timeout si terminamos
                print("🔧 Callback de connectUser ejecutado")
                self?.updateOnMainThread {
                    if let error = error {
                        print("❌ Error conectando usuario: \(error.localizedDescription)")
                        print("❌ Detalles del error: \(error)")
                        self?.errorMessage = "Error conectando usuario: \(error.localizedDescription)"
                        self?.isLoading = false
                    } else {
                        print("✅ Usuario conectado exitosamente")
                        print("🔧 Procediendo a conectar al canal...")
                        self?.connectToChannel(channelId: channelId)
                    }
                }
            }
        } catch {
            timeoutWorkItem.cancel()
            print("❌ Error creando token: \(error.localizedDescription)")
            print("❌ Detalles del error: \(error)")
            updateOnMainThread {
                self.errorMessage = "Error creando token: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Connect to Channel
    private func connectToChannel(channelId: String) {
        guard let chatClient = chatClient else {
            updateOnMainThread {
                self.errorMessage = "Cliente de chat no inicializado"
                self.isLoading = false
            }
            return
        }
        
        print("📺 Conectando al canal: \(channelId)")
        
        // Crear referencia al canal
        let channelId = ChannelId(type: .messaging, id: channelId)
        print("🔧 ChannelId creado: \(channelId)")
        
        channelController = chatClient.channelController(for: channelId)
        print("🔧 ChannelController creado")
        
        // Subscribirse a cambios del canal
        channelController?.delegate = self
        print("🔧 Delegate configurado")
        
        // Agregar timeout para synchronize
        let timeoutWorkItem = DispatchWorkItem {
            self.updateOnMainThread {
                if self.isLoading {
                    print("⏱️ Timeout en synchronize después de 15 segundos")
                    self.errorMessage = "Timeout al conectar al canal"
                    self.isLoading = false
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeoutWorkItem)
        
        // Cargar el canal
        print("🔧 Iniciando synchronize...")
        channelController?.synchronize { [weak self] error in
            timeoutWorkItem.cancel() // Cancelar timeout si terminamos
            print("🔧 Callback de synchronize ejecutado")
            self?.updateOnMainThread {
                if let error = error {
                    print("❌ Error conectando al canal: \(error.localizedDescription)")
                    print("❌ Detalles del error: \(error)")
                    self?.errorMessage = "Error conectando al canal: \(error.localizedDescription)"
                    self?.isLoading = false
                } else {
                    print("✅ Canal conectado exitosamente")
                    self?.currentChannel = self?.channelController?.channel
                    self?.isConnected = true
                    self?.isLoading = false
                    Task {
                        await self?.loadMessages()
                    }
                }
            }
        }
    }
    
    // MARK: - Load Messages
    private func loadMessages() async {
        guard let messages = channelController?.messages else {
            print("⚠️ No hay mensajes disponibles")
            return
        }
        
        print("📨 Cargando \(messages.count) mensajes")
        
        // Convertir mensajes de Stream.io a nuestro modelo
        let convertedMessages = messages.map { streamMessage in
            StreamChatMessage(
                id: streamMessage.id,
                text: streamMessage.text,
                user: MessageUser(
                    id: streamMessage.author.id,
                    name: streamMessage.author.name ?? "Usuario",
                    avatarURL: streamMessage.author.imageURL
                ),
                timestamp: streamMessage.createdAt,
                isFromCurrentUser: streamMessage.isSentByCurrentUser
            )
        }
        
        // Convertir a Array y revertir para mostrar mensajes más recientes al final
        let reversedMessages = Array(convertedMessages.reversed())
        
        updateOnMainThread {
            self.messages = reversedMessages
        }
    }
    
    // MARK: - Send Message
    func sendMessage(_ text: String) {
        guard let channelController = channelController,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ No se puede enviar mensaje vacío")
            return
        }
        
        print("💬 Enviando mensaje: \(text)")
        
        channelController.createNewMessage(text: text) { result in
            self.updateOnMainThread {
                switch result {
                case .success(let messageId):
                    print("✅ Mensaje enviado exitosamente: \(messageId)")
                case .failure(let error):
                    print("❌ Error enviando mensaje: \(error.localizedDescription)")
                    self.errorMessage = "Error enviando mensaje: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Start Typing
    func startTyping() {
        channelController?.sendKeystrokeEvent()
    }
    
    // MARK: - Stop Typing
    func stopTyping() {
        channelController?.sendStopTypingEvent()
    }
    
    // MARK: - Disconnect
    func disconnect() {
        print("🔌 Desconectando de Stream.io")
        
        // Reset UI state primero en main thread
        updateOnMainThread {
            self.isConnected = false
            self.isLoading = false
            self.errorMessage = nil
            self.messages.removeAll()
            self.typingUsers.removeAll()
        }
        
        // Limpiar delegate y controladores
        channelController?.delegate = nil
        channelController = nil
        currentChannel = nil
        
        // Limpiar propiedades de token
        currentToken = nil
        currentApiKey = nil
        currentUserId = nil
        
        // Desconectar sincrónicamente para evitar problemas de concurrencia
        if let client = chatClient {
            Task {
                await client.disconnect()
            }
        }
        chatClient = nil
        
        // Limpiar cancellables
        cancellables.removeAll()
        
        print("✅ Desconexión completada")
    }
    
    // MARK: - Cleanup
    deinit {
        // Limpiar referencias locales sincrónicamente
        channelController?.delegate = nil
        channelController = nil
        currentChannel = nil
        
        // No hacer llamadas async en deinit - el objeto ya se está liberando
        // La desconexión se maneja en disconnect() que se llama explícitamente
        chatClient = nil
    }
}

// MARK: - ChatChannelControllerDelegate
extension StreamChatService: ChatChannelControllerDelegate {
    nonisolated func channelController(_ channelController: ChatChannelController, didUpdateMessages changes: [ListChange<StreamChat.ChatMessage>]) {
        Task { @MainActor in
            print("📨 Mensajes actualizados")
            await self.loadMessages()
        }
    }
    
    nonisolated func channelController(_ channelController: ChatChannelController, didChangeTypingUsers typingUsers: Set<ChatUser>) {
        Task { @MainActor in
            let userNames = typingUsers.compactMap { $0.name }
            self.typingUsers = userNames
            print("⌨️ Usuarios escribiendo: \(userNames)")
        }
    }
    
    nonisolated func channelController(_ channelController: ChatChannelController, didUpdateChannel channel: EntityChange<ChatChannel>) {
        Task { @MainActor in
            print("📺 Canal actualizado")
            self.currentChannel = channel.item
        }
    }
}

// MARK: - Message Models
struct StreamChatMessage: Identifiable {
    let id: String
    let text: String
    let user: MessageUser
    let timestamp: Date
    let isFromCurrentUser: Bool
}

struct MessageUser {
    let id: String
    let name: String
    let avatarURL: URL?
} 