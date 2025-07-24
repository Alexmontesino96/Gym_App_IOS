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
    
    // MARK: - Get Last Messages for Multiple Channels (Optimized)
    func getLastMessagesForChannels(_ channelIds: [String]) async -> [ChannelLastMessage] {
        // Si no hay cliente, intentar inicializar uno básico
        if chatClient == nil {
            print("🔧 Inicializando cliente básico de Stream para obtener mensajes...")
            await initializeBasicChatClient()
        }
        
        guard let chatClient = chatClient else {
            print("❌ No se pudo inicializar cliente de chat para obtener últimos mensajes")
            return []
        }
        
        print("🔍 Obteniendo últimos mensajes para \(channelIds.count) canales...")
        
        return await withTaskGroup(of: ChannelLastMessage?.self, returning: [ChannelLastMessage].self) { group in
            for channelId in channelIds {
                group.addTask {
                    await self.getLastMessageForChannel(channelId: channelId, chatClient: chatClient)
                }
            }
            
            var results: [ChannelLastMessage] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            print("✅ Obtenidos últimos mensajes para \(results.count)/\(channelIds.count) canales")
            return results
        }
    }
    
    // MARK: - Get Last Message for Single Channel
    private func getLastMessageForChannel(channelId: String, chatClient: ChatClient) async -> ChannelLastMessage? {
        do {
            print("🔍 Procesando canal: \(channelId)")
            
            // Crear referencia al canal
            let streamChannelId = ChannelId(type: .messaging, id: channelId)
            let controller = chatClient.channelController(for: streamChannelId)
            
            // Si ya tiene mensajes cargados, usar esos datos
            if !controller.messages.isEmpty {
                let lastMessage = controller.messages.last
                print("✅ Canal \(channelId): usando datos en cache (\(controller.messages.count) mensajes)")
                
                return ChannelLastMessage(
                    channelId: channelId,
                    lastMessageAt: lastMessage?.createdAt,
                    lastMessageText: lastMessage?.text
                )
            }
            
            // Si no hay datos, hacer query ligero para obtener solo el último mensaje
            print("🔄 Canal \(channelId): haciendo query ligero...")
            
            return await withCheckedContinuation { continuation in
                // Timeout para evitar esperas infinitas
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 segundos
                    continuation.resume(returning: ChannelLastMessage(channelId: channelId))
                }
                
                controller.synchronize { error in
                    timeoutTask.cancel()
                    
                    if let error = error {
                        print("⚠️ Canal \(channelId): error en synchronize - \(error.localizedDescription)")
                        continuation.resume(returning: ChannelLastMessage(channelId: channelId))
                        return
                    }
                    
                    // Obtener último mensaje después de synchronize
                    let lastMessage = controller.messages.last
                    print("✅ Canal \(channelId): query completado (\(controller.messages.count) mensajes)")
                    
                    let result = ChannelLastMessage(
                        channelId: channelId,
                        lastMessageAt: lastMessage?.createdAt,
                        lastMessageText: lastMessage?.text
                    )
                    
                    continuation.resume(returning: result)
                }
            }
            
        } catch {
            print("❌ Error procesando canal \(channelId): \(error.localizedDescription)")
            return ChannelLastMessage(channelId: channelId)
        }
    }
    
    // MARK: - Initialize Basic Chat Client (For Last Messages)
    private func initializeBasicChatClient() async {
        print("🔧 Obteniendo token de Stream para cliente básico...")
        
        // Obtener token desde ChatService
        guard let streamToken = await ChatService.shared.getStreamToken() else {
            print("❌ No se pudo obtener token para cliente básico")
            return
        }
        
        print("✅ Token obtenido, inicializando cliente básico...")
        
        // Configurar cliente básico
        let config = ChatClientConfig(apiKey: APIKey(streamToken.apiKey))
        chatClient = ChatClient(config: config)
        
        // Conectar usuario de forma básica
        do {
            let token = try Token(rawValue: streamToken.token)
            let userId = "user_\(streamToken.internalUserId)"
            
            print("🔧 Conectando usuario \(userId) para obtener mensajes...")
            
            await withCheckedContinuation { continuation in
                chatClient?.connectUser(
                    userInfo: StreamChat.UserInfo(
                        id: userId,
                        name: "Usuario \(streamToken.internalUserId)",
                        imageURL: nil
                    ),
                    token: token
                ) { error in
                    if let error = error {
                        print("⚠️ Error conectando usuario básico: \(error.localizedDescription)")
                    } else {
                        print("✅ Usuario básico conectado exitosamente")
                    }
                    continuation.resume()
                }
            }
        } catch {
            print("❌ Error inicializando cliente básico: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get Channel Controller (Helper)
    func getChannelController(for channelId: String) -> ChatChannelController? {
        guard let chatClient = chatClient else { return nil }
        let streamChannelId = ChannelId(type: .messaging, id: channelId)
        return chatClient.channelController(for: streamChannelId)
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

// MARK: - Channel Last Message Model
struct ChannelLastMessage {
    let channelId: String
    let lastMessageAt: Date?
    let lastMessageText: String?
    let hasMessages: Bool
    
    init(channelId: String, lastMessageAt: Date? = nil, lastMessageText: String? = nil) {
        self.channelId = channelId
        self.lastMessageAt = lastMessageAt
        self.lastMessageText = lastMessageText
        self.hasMessages = lastMessageAt != nil && lastMessageText != nil && !lastMessageText!.isEmpty
    }
} 