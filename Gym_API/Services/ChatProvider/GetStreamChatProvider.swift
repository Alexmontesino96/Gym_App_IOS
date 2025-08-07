import Foundation
import Combine
import StreamChat

// MARK: - GetStream Chat Provider Implementation
class GetStreamChatProvider: ChatProvider {
    
    // MARK: - Published Properties
    @Published private var _connectionState: ChatConnectionState = .disconnected
    @Published private var _messageUpdates = PassthroughSubject<MessageUpdate, Never>()
    @Published private var _conversationUpdates = PassthroughSubject<ConversationUpdate, Never>()
    @Published private var _typingUpdates = PassthroughSubject<TypingUpdate, Never>()
    
    // MARK: - Protocol Properties
    var connectionState: ChatConnectionState { _connectionState }
    var connectionStatePublisher: AnyPublisher<ChatConnectionState, Never> { $_connectionState.eraseToAnyPublisher() }
    var messageUpdatesPublisher: AnyPublisher<MessageUpdate, Never> { _messageUpdates.eraseToAnyPublisher() }
    var conversationUpdatesPublisher: AnyPublisher<ConversationUpdate, Never> { _conversationUpdates.eraseToAnyPublisher() }
    var typingUpdatesPublisher: AnyPublisher<TypingUpdate, Never> { _typingUpdates.eraseToAnyPublisher() }
    
    // MARK: - Private Properties
    private var chatClient: ChatClient?
    private var currentUser: ChatUser?
    private var channelControllers: [String: ChatChannelController] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var authService: AuthServiceProtocol?
    
    init() {
        print("🎮 GetStreamChatProvider inicializado")
    }
    
    /// Configura el servicio de autenticación
    func setAuthService(_ authService: AuthServiceProtocol) {
        self.authService = authService
        print("✅ AuthService configurado en GetStreamChatProvider")
    }
    
    // MARK: - Connection Management
    
    func connect(credentials: ChatCredentials) async throws {
        print("🔌 Conectando a GetStream...")
        print("📋 Credenciales:")
        print("   - API Key: \(credentials.apiKey)")
        print("   - User ID: \(credentials.userId)")
        print("   - Token: \(String(credentials.token.prefix(20)))...")
        print("   - User Name: \(credentials.userInfo?.name ?? "N/A")")
        
        _connectionState = .connecting
        
        // Configurar cliente
        let config = ChatClientConfig(apiKey: APIKey(credentials.apiKey))
        print("🔧 Configurando ChatClient con API Key: \(credentials.apiKey)")
        chatClient = ChatClient(config: config)
        
        // Crear token provider
        let tokenProvider: TokenProvider = { completion in
            print("🎫 Token provider llamado")
            print("🎫 Token recibido: \(credentials.token)")
            print("🎫 UserId esperado: \(credentials.userId)")
            
            do {
                let token = try Token(rawValue: credentials.token)
                print("✅ Token creado exitosamente")
                print("✅ Token userId: \(token.userId)")
                completion(.success(token))
            } catch {
                print("❌ Error creando token: \(error)")
                print("❌ Error localizedDescription: \(error.localizedDescription)")
                
                // Intentar decodificar el token manualmente para ver qué contiene
                let parts = credentials.token.split(separator: ".")
                if parts.count == 3 {
                    print("🔍 Token tiene 3 partes correctas")
                    
                    // Decodificar payload
                    let payloadPart = String(parts[1])
                    var base64 = payloadPart
                        .replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")
                    
                    // Agregar padding
                    let remainder = base64.count % 4
                    if remainder > 0 {
                        base64 += String(repeating: "=", count: 4 - remainder)
                    }
                    
                    if let data = Data(base64Encoded: base64),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("🔍 Payload del token:")
                        for (key, value) in json {
                            print("   \(key): \(value)")
                        }
                    } else {
                        print("❌ No se pudo decodificar el payload del token")
                    }
                } else {
                    print("❌ Token no tiene el formato correcto (3 partes)")
                }
                
                completion(.failure(error))
            }
        }
        
        // Crear UserInfo
        let userInfo = StreamChat.UserInfo(
            id: credentials.userId,
            name: credentials.userInfo?.name ?? "Usuario",
            imageURL: credentials.userInfo?.avatarURL.flatMap(URL.init)
        )
        print("👤 UserInfo creado: ID=\(userInfo.id), Name=\(userInfo.name ?? "N/A")")
        
        // Conectar usuario
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            print("📡 Iniciando conexión del usuario...")
            chatClient?.connectUser(userInfo: userInfo, tokenProvider: tokenProvider) { error in
                if let error = error {
                    print("❌ Error conectando usuario: \(error)")
                    print("❌ Error localizedDescription: \(error.localizedDescription)")
                    self._connectionState = .failed(error)
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Usuario conectado exitosamente")
                    self._connectionState = .connected
                    self.currentUser = credentials.userInfo
                    continuation.resume()
                }
            }
        }
        
        setupRealtimeListeners()
        print("✅ Conectado a GetStream exitosamente")
        
        // Intentar obtener conversaciones para debugging
        print("🔍 Intentando obtener conversaciones para debugging...")
        do {
            let conversations = try await getConversations()
            print("💬 Conversaciones obtenidas: \(conversations.count)")
            for (index, conversation) in conversations.enumerated() {
                print("   \(index + 1). ID: \(conversation.id), Name: \(conversation.name ?? "Sin nombre"), Members: \(conversation.members.count)")
            }
        } catch {
            print("❌ Error obteniendo conversaciones: \(error)")
        }
    }
    
    func disconnect() async {
        print("🔌 Desconectando de GetStream...")
        
        _connectionState = .disconnected
        
        // Limpiar controladores
        channelControllers.removeAll()
        cancellables.removeAll()
        
        // Desconectar cliente
        if let client = chatClient {
            await client.disconnect()
        }
        
        chatClient = nil
        currentUser = nil
        
        print("✅ Desconectado de GetStream")
    }
    
    // MARK: - Message Operations
    
    /// Envía mensaje con soporte para caché optimista
    func sendMessage(_ message: ChatMessage, to conversationId: String) async throws -> String {
        print("📤 Enviando mensaje con caché optimista: \(message.text.prefix(50))...")
        
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            throw ChatProviderError.conversationNotFound
        }
        
        // 1. Agregar mensaje al caché optimistamente
        var optimisticMessage = message
        optimisticMessage.syncStatus = .sending
        
        await MainActor.run {
            MessageCacheManager.shared.addMessage(optimisticMessage, to: conversationId)
            
            // Notificar UI inmediatamente
            let update = MessageUpdate(type: .new, message: optimisticMessage, conversationId: conversationId)
            self._messageUpdates.send(update)
        }
        
        do {
            // 2. Enviar a GetStream
            let messageId = try await withCheckedThrowingContinuation { continuation in
                channelController.createNewMessage(text: message.text) { result in
                    switch result {
                    case .success(let messageId):
                        continuation.resume(returning: messageId)
                    case .failure(let error):
                        continuation.resume(throwing: ChatProviderError.networkError(error))
                    }
                }
            }
            
            // 3. Actualizar mensaje como enviado exitosamente
            var sentMessage = optimisticMessage
            sentMessage.syncStatus = .synced
            
            await MainActor.run {
                MessageCacheManager.shared.updateMessage(sentMessage, in: conversationId)
            }
            
            print("✅ Mensaje enviado exitosamente con ID: \(messageId)")
            return messageId
            
        } catch {
            // 4. Marcar mensaje como fallido
            var failedMessage = optimisticMessage
            failedMessage.syncStatus = .failed
            
            await MainActor.run {
                MessageCacheManager.shared.updateMessage(failedMessage, in: conversationId)
                
                // Notificar UI del fallo
                let update = MessageUpdate(type: .updated, message: failedMessage, conversationId: conversationId)
                self._messageUpdates.send(update)
            }
            
            print("❌ Error enviando mensaje: \(error)")
            throw error
        }
    }
    
    /// Obtiene mensajes usando estrategia cache-first
    func getMessagesWithCache(for conversationId: String, limit: Int = 50, before messageId: String? = nil) async throws -> [ChatMessage] {
        print("📦 getMessagesWithCache iniciado para: \(conversationId)")
        
        // 1. Cargar desde caché primero
        let cachedMessages = await MainActor.run {
            MessageCacheManager.shared.getCachedMessages(for: conversationId)
        }
        
        // 2. Si hay caché, devolverlo inmediatamente y cargar frescos en background
        if !cachedMessages.isEmpty {
            print("📦 Devolviendo \(cachedMessages.count) mensajes desde caché para: \(conversationId)")
            
            // Cargar mensajes frescos en background
            Task {
                do {
                    let freshMessages = try await self.getMessagesFromStream(for: conversationId, limit: limit, before: messageId)
                    
                    // Solo actualizar caché si hay diferencias
                    if !self.messagesAreEqual(cachedMessages, freshMessages) {
                        await MainActor.run {
                            MessageCacheManager.shared.saveMessages(freshMessages, for: conversationId)
                            
                            // Notificar que hay nuevos mensajes
                            NotificationCenter.default.post(
                                name: .messagesUpdatedFromServer,
                                object: nil,
                                userInfo: [
                                    "conversationId": conversationId,
                                    "messages": freshMessages
                                ]
                            )
                        }
                        print("🔄 Mensajes actualizados desde servidor en background")
                    } else {
                        print("✅ Mensajes en caché están actualizados")
                    }
                } catch {
                    print("❌ Error cargando mensajes frescos en background: \(error)")
                }
            }
            
            return cachedMessages
        }
        
        // 3. Si no hay caché, cargar de GetStream normalmente
        print("🔄 No hay caché, cargando desde GetStream para: \(conversationId)")
        let messages = try await getMessagesFromStream(for: conversationId, limit: limit, before: messageId)
        
        // Guardar en caché
        await MainActor.run {
            MessageCacheManager.shared.saveMessages(messages, for: conversationId)
        }
        
        return messages
    }
    
    /// Método original para cargar mensajes directamente desde GetStream
    func getMessages(for conversationId: String, limit: Int, before messageId: String?) async throws -> [ChatMessage] {
        return try await getMessagesFromStream(for: conversationId, limit: limit, before: messageId)
    }
    
    /// Implementación interna para cargar mensajes desde GetStream
    private func getMessagesFromStream(for conversationId: String, limit: Int, before messageId: String?) async throws -> [ChatMessage] {
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            throw ChatProviderError.conversationNotFound
        }
        
        // Sincronizar canal primero
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            channelController.synchronize { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Convertir mensajes de Stream a nuestro modelo
        let streamMessages = Array(channelController.messages.prefix(limit))
        return streamMessages.map { convertStreamMessage($0, conversationId: conversationId) }
    }
    
    func markAsRead(messagesUpTo messageId: String, in conversationId: String) async throws {
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            throw ChatProviderError.conversationNotFound
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            channelController.markRead { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteMessage(_ messageId: String, in conversationId: String) async throws {
        // TODO: Implementar eliminación de mensajes con la API correcta de StreamChat
        throw ChatProviderError.unknown(NSError(domain: "GetStreamProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete message not implemented yet"]))
    }
    
    func editMessage(_ messageId: String, newText: String, in conversationId: String) async throws {
        // TODO: Implementar edición de mensajes con la API correcta de StreamChat
        throw ChatProviderError.unknown(NSError(domain: "GetStreamProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Edit message not implemented yet"]))
    }
    
    // MARK: - Conversation Management
    
    /// Obtiene las salas desde la API para enriquecer los nombres
    @MainActor
    private func fetchRoomNamesFromAPI() async -> [String: String] {
        var roomNameMap: [String: String] = [:]
        
        print("🔍 fetchRoomNamesFromAPI iniciado")
        
        let chatService = ChatService.shared
        
        // Configurar authService si está disponible
        if let authService = self.authService as? AuthServiceDirect {
            chatService.authService = authService
            print("✅ AuthService configurado en ChatService")
        } else {
            print("⚠️ AuthService no disponible en GetStreamChatProvider")
            
            // Intentar cargar desde caché si no hay authService
            if let data = UserDefaults.standard.data(forKey: "ChatRoomNamesCache"),
               let cachedNames = try? JSONDecoder().decode([String: String].self, from: data) {
                print("📦 Usando nombres desde caché (no auth): \(cachedNames.count)")
                return cachedNames
            }
            return roomNameMap
        }
        
        // Obtener rooms de la API
        if let rooms = await chatService.getMyRoomsFromAPI() {
            print("📋 Salas obtenidas de la API: \(rooms.count)")
            for room in rooms {
                // Los IDs de la API vienen sin prefijo "messaging:", pero Stream los usa con prefijo
                // Mapear el ID base (como viene de la API)
                roomNameMap[room.streamChannelId] = room.name
                print("   - \(room.streamChannelId) → \(room.name)")
            }
            print("✅ Mapa de nombres cargado: \(roomNameMap.count) entradas")
            
            // Guardar en caché para uso futuro
            do {
                let data = try JSONEncoder().encode(roomNameMap)
                UserDefaults.standard.set(data, forKey: "ChatRoomNamesCache")
                print("💾 Nombres guardados en caché")
            } catch {
                print("❌ Error guardando en caché: \(error)")
            }
        } else {
            print("⚠️ No se pudieron cargar los nombres desde la API")
            
            // Intentar cargar desde caché
            if let data = UserDefaults.standard.data(forKey: "ChatRoomNamesCache"),
               let cachedNames = try? JSONDecoder().decode([String: String].self, from: data) {
                print("📦 Usando nombres desde caché: \(cachedNames.count)")
                roomNameMap = cachedNames
            }
        }
        
        return roomNameMap
    }
    
    
    func getConversations() async throws -> [ChatConversation] {
        print("📋 getConversations() iniciado")
        
        guard let chatClient = chatClient else {
            print("❌ ChatClient no inicializado")
            throw ChatProviderError.notInitialized
        }
        
        print("✅ ChatClient disponible")
        
        // Crear query para obtener canales
        let userId = currentUser?.id ?? ""
        print("👤 Buscando canales para usuario: \(userId)")
        
        // Cambiar query para mostrar TODOS los canales donde el usuario es miembro
        // Eliminar sort restrictivo por lastMessageAt que puede ocultar canales sin mensajes
        let query = ChannelListQuery(filter: .containMembers(userIds: [userId]))
        print("🔍 Query sin sort restrictivo creado para obtener TODOS los canales del usuario: \(query)")
        print("🔍 Esto debería incluir canales donde es miembro pero no ha escrito mensajes")
        
        let channelListController = chatClient.channelListController(query: query)
        print("🎮 ChannelListController creado")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            print("📡 Sincronizando channelListController...")
            channelListController.synchronize { error in
                if let error = error {
                    print("❌ Error sincronizando channels: \(error)")
                    print("❌ Error localizedDescription: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Sincronización de channels exitosa")
                    continuation.resume()
                }
            }
        }
        
        print("📊 Número de canales encontrados con query SIN sort restrictivo: \(channelListController.channels.count)")
        print("🔍 COMPARACIÓN: Antes teníamos 9 canales, ahora tenemos: \(channelListController.channels.count)")
        
        // Obtener nombres desde la API
        let roomNameMap: [String: String]
        if await MainActor.run(resultType: Bool.self, body: { true }) {
            roomNameMap = await fetchRoomNamesFromAPI()
        } else {
            roomNameMap = [:]
        }
        
        // Log de canales raw con análisis detallado
        print("🔍 ANÁLISIS DETALLADO DE CANALES ENCONTRADOS:")
        for (index, channel) in channelListController.channels.enumerated() {
            print("🔍 Canal \(index + 1):")
            print("   - ID: \(channel.cid)")
            print("   - Name: \(channel.name ?? "Sin nombre")")
            print("   - API Name: \(roomNameMap[channel.cid.id] ?? "❌ NO EN API")")
            print("   - Type: \(channel.type)")
            print("   - Members: \(channel.memberCount)")
            print("   - Created: \(channel.createdAt)")
            print("   - Last Message: \(channel.lastMessageAt?.description ?? "⚠️ SIN MENSAJES")")
            print("   - Latest Messages Count: \(channel.latestMessages.count)")
            
            // Verificar si existe en la API
            if roomNameMap[channel.cid.id] != nil {
                print("   ✅ Canal existe en API")
            } else {
                print("   ❌ Canal NO existe en API - puede ser canal directo o creado manualmente")
            }
        }
        
        // Análisis de canales faltantes de la API (normalizar IDs para comparación)
        // Stream IDs: messaging:event_615_d3d94468 -> event_615_d3d94468
        // API IDs: event_615_d3d94468 (ya sin prefijo)
        let foundChannelIds = Set(channelListController.channels.map { channel in
            let fullId = channel.cid.id
            // Remover prefijo "messaging:" si existe
            return fullId.hasPrefix("messaging:") ? String(fullId.dropFirst("messaging:".count)) : fullId
        })
        
        let apiChannelIds = Set(roomNameMap.keys.map { apiId in
            // Los IDs de la API ya vienen sin prefijo, pero por si acaso
            return apiId.hasPrefix("messaging:") ? String(apiId.dropFirst("messaging:".count)) : apiId
        })
        
        let missingFromStream = apiChannelIds.subtracting(foundChannelIds)
        
        print("📊 ANÁLISIS DE COBERTURA:")
        print("   - Canales en API: \(apiChannelIds.count)")
        print("   - Canales encontrados en Stream: \(foundChannelIds.count)")
        print("   - Canales faltantes en Stream: \(missingFromStream.count)")
        
        if !missingFromStream.isEmpty {
            print("🔍 CANALES DE LA API QUE NO APARECEN EN STREAM:")
            for missingId in missingFromStream {
                print("   - \(missingId) → \(roomNameMap[missingId] ?? "N/A")")
            }
        }
        
        // Convertir canales a nuestro modelo con nombres enriquecidos
        let conversations = channelListController.channels.map { channel in
            var conversation = convertStreamChannel(channel)
            
            // Usar el nombre de la API si está disponible
            // Normalizar el ID del canal para buscar en roomNameMap
            let normalizedChannelId = channel.cid.id.hasPrefix("messaging:") ? 
                String(channel.cid.id.dropFirst("messaging:".count)) : channel.cid.id
            
            // Buscar en roomNameMap tanto con el ID normalizado como sin normalizar
            let apiName = roomNameMap[normalizedChannelId] ?? roomNameMap[channel.cid.id]
            
            if let name = apiName {
                conversation = ChatConversation(
                    id: conversation.id,
                    name: name, // Usar el nombre de la API
                    type: conversation.type,
                    members: conversation.members,
                    lastMessage: conversation.lastMessage,
                    lastActivity: conversation.lastActivity,
                    unreadCount: conversation.unreadCount,
                    metadata: conversation.metadata
                )
            }
            
            return conversation
        }
        
        print("✅ Conversaciones convertidas con nombres enriquecidos: \(conversations.count)")
        
        return conversations
    }
    
    func createConversation(_ request: CreateConversationRequest) async throws -> ChatConversation {
        print("🛠️ createConversation iniciado")
        print("   - Name: \(request.name ?? "N/A")")
        print("   - Type: \(request.type)")
        print("   - Members: \(request.members)")
        
        guard let chatClient = chatClient else {
            print("❌ ChatClient no inicializado")
            throw ChatProviderError.notInitialized
        }
        
        // Crear ID único para el canal
        let channelId = generateChannelId(for: request)
        print("🆔 Canal ID generado: \(channelId)")
        
        let streamChannelId = ChannelId(type: .messaging, id: channelId)
        print("🆔 StreamChannelId: \(streamChannelId)")
        
        // Crear controlador de canal
        let channelController = chatClient.channelController(for: streamChannelId)
        print("🎮 ChannelController creado")
        
        // Configurar miembros
        let memberIds = Set(request.members + [currentUser?.id ?? ""])
        print("👥 Miembros configurados: \(memberIds)")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            print("📡 Sincronizando canal...")
            channelController.synchronize { error in
                if let error = error {
                    print("❌ Error sincronizando canal: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Canal sincronizado exitosamente")
                    continuation.resume()
                }
            }
        }
        
        // Retornar conversación creada
        guard let channel = channelController.channel else {
            print("❌ No se pudo obtener el canal después de sincronizar")
            throw ChatProviderError.conversationNotFound
        }
        
        print("✅ Canal creado exitosamente: \(channel.cid)")
        let conversation = convertStreamChannel(channel)
        print("✅ Conversación convertida: \(conversation.id)")
        
        return conversation
    }
    
    func joinConversation(_ conversationId: String) async throws {
        print("🏠 joinConversation iniciado para: \(conversationId)")
        
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            print("❌ No se pudo crear channelController para: \(conversationId)")
            throw ChatProviderError.conversationNotFound
        }
        
        print("🎮 ChannelController obtenido para: \(conversationId)")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            print("📡 Sincronizando para unirse al canal: \(conversationId)")
            channelController.synchronize { error in
                if let error = error {
                    print("❌ Error uniéndose al canal \(conversationId): \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Unido exitosamente al canal: \(conversationId)")
                    continuation.resume()
                }
            }
        }
        
        // Configurar delegate para actualizaciones en tiempo real
        channelController.delegate = self
        print("🔄 Delegate configurado para: \(conversationId)")
    }
    
    // MARK: - Update Channel Name
    func updateChannelName(_ conversationId: String, name: String) async throws {
        print("🏷️ Actualizando nombre del canal \(conversationId) a: \(name)")
        
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            print("❌ No se pudo obtener channelController para: \(conversationId)")
            throw ChatProviderError.conversationNotFound
        }
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                channelController.updateChannel(name: name, imageURL: nil, team: nil, extraData: [:]) { error in
                    if let error = error {
                        print("❌ Error actualizando nombre del canal \(conversationId): \(error)")
                        continuation.resume(throwing: error)
                    } else {
                        print("✅ Nombre del canal \(conversationId) actualizado a: \(name)")
                        continuation.resume()
                    }
                }
            }
        } catch {
            print("❌ Error en updateChannelName: \(error)")
            throw error
        }
    }
    
    func leaveConversation(_ conversationId: String) async throws {
        if let channelController = channelControllers[conversationId] {
            channelController.delegate = nil
            channelControllers.removeValue(forKey: conversationId)
        }
    }
    
    // MARK: - User Management
    
    func setCurrentUser(_ user: ChatUser) async throws {
        currentUser = user
    }
    
    func getUsers(in conversationId: String) async throws -> [ChatUser] {
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            throw ChatProviderError.conversationNotFound
        }
        
        guard let channel = channelController.channel else {
            throw ChatProviderError.conversationNotFound
        }
        
        return channel.lastActiveMembers.map { member in
            ChatUser(
                id: member.id,
                name: member.name ?? "Usuario",
                avatarURL: member.imageURL?.absoluteString
            )
        }
    }
    
    // MARK: - Typing Indicators
    
    func startTyping(in conversationId: String) async throws {
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            throw ChatProviderError.conversationNotFound
        }
        
        channelController.sendKeystrokeEvent()
    }
    
    func stopTyping(in conversationId: String) async throws {
        guard let channelController = getOrCreateChannelController(for: conversationId) else {
            throw ChatProviderError.conversationNotFound
        }
        
        channelController.sendStopTypingEvent()
    }
    
    // MARK: - Push Notifications
    
    func registerForPushNotifications(token: String) async throws {
        guard let chatClient = chatClient else {
            throw ChatProviderError.notInitialized
        }
        
        // Convertir token string a Data
        guard let tokenData = Data(base64Encoded: token) else {
            throw ChatProviderError.invalidCredentials
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            chatClient.currentUserController().addDevice(.apn(token: tokenData)) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func unregisterFromPushNotifications() async throws {
        guard let chatClient = chatClient else {
            throw ChatProviderError.notInitialized
        }
        
        // GetStream maneja esto automáticamente al desconectar
        print("📱 Push notifications desregistradas")
    }
    
    // MARK: - Private Helpers
    
    private func getOrCreateChannelController(for conversationId: String) -> ChatChannelController? {
        print("🎮 getOrCreateChannelController para: \(conversationId)")
        
        if let existing = channelControllers[conversationId] {
            print("✅ Usando controller existente para: \(conversationId)")
            return existing
        }
        
        guard let chatClient = chatClient else { 
            print("❌ ChatClient no disponible")
            return nil 
        }
        
        print("🆔 Creando ChannelId para: \(conversationId)")
        let channelId = ChannelId(type: .messaging, id: conversationId)
        print("🆔 ChannelId creado: \(channelId)")
        
        let controller = chatClient.channelController(for: channelId)
        controller.delegate = self
        print("🎮 Controller creado y delegate asignado")
        
        channelControllers[conversationId] = controller
        print("💾 Controller guardado en cache para: \(conversationId)")
        
        return controller
    }
    
    private func setupRealtimeListeners() {
        // Los listeners se configuran a través del delegate pattern
        // cuando se unen a conversaciones específicas
    }
    
    private func convertStreamMessage(_ streamMessage: StreamChat.ChatMessage, conversationId: String) -> ChatMessage {
        return ChatMessage(
            id: streamMessage.id,
            conversationId: conversationId,
            text: streamMessage.text,
            authorId: streamMessage.author.id,
            authorName: streamMessage.author.name ?? "Usuario",
            timestamp: streamMessage.createdAt,
            isFromCurrentUser: streamMessage.isSentByCurrentUser,
            syncStatus: MessageSyncStatus.synced,
            isRead: true, // GetStream maneja esto automáticamente
            attachments: [] // TODO: Convertir attachments si es necesario
        )
    }
    
    private func convertStreamChannel(_ streamChannel: StreamChat.ChatChannel) -> ChatConversation {
        let members = streamChannel.lastActiveMembers.map { member in
            ChatUser(
                id: member.id,
                name: member.name ?? "Usuario",
                avatarURL: member.imageURL?.absoluteString
            )
        }
        
        let lastMessage = streamChannel.latestMessages.first.map { 
            convertStreamMessage($0, conversationId: streamChannel.cid.id)
        }
        
        return ChatConversation(
            id: streamChannel.cid.id,
            name: streamChannel.name,
            type: determineConversationType(from: streamChannel),
            members: members,
            lastMessage: lastMessage,
            lastActivity: streamChannel.lastMessageAt ?? streamChannel.createdAt,
            unreadCount: streamChannel.unreadCount.messages,
            metadata: [:]
        )
    }
    
    private func determineConversationType(from channel: StreamChat.ChatChannel) -> ChatConversation.ConversationType {
        // Determinar tipo basado en el ID del canal
        let channelId = channel.cid.id
        
        if channelId.hasPrefix("direct_") {
            return .direct
        } else if channelId.hasPrefix("event_") {
            return .channel
        } else if channelId.hasPrefix("room_") {
            return .general
        } else if channel.memberCount == 2 {
            return .direct
        } else {
            return .group
        }
    }
    
    private func generateChannelId(for request: CreateConversationRequest) -> String {
        // Si se proporciona un ID específico, usarlo
        if let specificId = request.id {
            print("🆔 Usando ID específico: \(specificId)")
            return specificId
        }
        
        // Si no, generar según el tipo
        print("🆔 Generando ID para tipo: \(request.type)")
        switch request.type {
        case .direct:
            // Para chats directos, usar patrón estándar
            let sortedMembers = request.members.sorted()
            return "direct_\(sortedMembers.joined(separator: "_"))"
        case .group:
            // Para grupos, generar ID único
            return "group_\(UUID().uuidString)"
        case .channel:
            // Para canales, usar nombre si está disponible
            return request.name?.lowercased().replacingOccurrences(of: " ", with: "_") ?? "channel_\(UUID().uuidString)"
        case .general:
            // Para salas generales
            return "room_\(request.name?.lowercased().replacingOccurrences(of: " ", with: "_") ?? "general")_\(UUID().uuidString.prefix(8))"
        }
    }
    
    /// Compara dos arrays de mensajes para detectar diferencias
    private func messagesAreEqual(_ messages1: [ChatMessage], _ messages2: [ChatMessage]) -> Bool {
        guard messages1.count == messages2.count else { return false }
        
        for i in 0..<messages1.count {
            if messages1[i].id != messages2[i].id || 
               messages1[i].text != messages2[i].text ||
               messages1[i].timestamp != messages2[i].timestamp ||
               messages1[i].syncStatus != messages2[i].syncStatus {
                return false
            }
        }
        
        return true
    }
}

// MARK: - ChatChannelControllerDelegate

extension GetStreamChatProvider: ChatChannelControllerDelegate {
    
    nonisolated func channelController(_ channelController: ChatChannelController, didUpdateMessages changes: [ListChange<StreamChat.ChatMessage>]) {
        Task { @MainActor in
            for change in changes {
                switch change {
                case .insert(let message, _):
                    let chatMessage = convertStreamMessage(message, conversationId: channelController.cid?.id ?? "")
                    let update = MessageUpdate(type: .new, message: chatMessage, conversationId: chatMessage.conversationId)
                    _messageUpdates.send(update)
                    
                case .update(let message, _):
                    let chatMessage = convertStreamMessage(message, conversationId: channelController.cid?.id ?? "")
                    let update = MessageUpdate(type: .updated, message: chatMessage, conversationId: chatMessage.conversationId)
                    _messageUpdates.send(update)
                    
                case .remove(let message, _):
                    let chatMessage = convertStreamMessage(message, conversationId: channelController.cid?.id ?? "")
                    let update = MessageUpdate(type: .deleted, message: chatMessage, conversationId: chatMessage.conversationId)
                    _messageUpdates.send(update)
                    
                case .move:
                    // No necesario manejar por ahora
                    break
                }
            }
        }
    }
    
    nonisolated func channelController(_ channelController: ChatChannelController, didChangeTypingUsers typingUsers: Set<StreamChat.ChatUser>) {
        Task { @MainActor in
            guard let conversationId = channelController.cid?.id else { return }
            
            for user in typingUsers {
                let chatUser = ChatUser(
                    id: user.id,
                    name: user.name ?? "Usuario",
                    avatarURL: user.imageURL?.absoluteString
                )
                
                let update = TypingUpdate(
                    conversationId: conversationId,
                    user: chatUser,
                    isTyping: true
                )
                
                _typingUpdates.send(update)
            }
        }
    }
    
    nonisolated func channelController(_ channelController: ChatChannelController, didUpdateChannel channel: EntityChange<StreamChat.ChatChannel>) {
        Task { @MainActor in
            let conversation = convertStreamChannel(channel.item)
            let update = ConversationUpdate(type: .updated, conversation: conversation)
            _conversationUpdates.send(update)
        }
    }
}