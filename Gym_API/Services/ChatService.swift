import Foundation
import Combine

// MARK: - Chat Room Model
struct ChatRoom: Codable, Identifiable {
    let id: Int
    let name: String?
    let isDirect: Bool
    let eventId: Int?
    let streamChannelId: String
    let streamChannelType: String
    let createdAt: Date
    let lastMessageAt: Date?
    let lastMessageText: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case isDirect = "is_direct"
        case eventId = "event_id"
        case streamChannelId = "stream_channel_id"
        case streamChannelType = "stream_channel_type"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case lastMessageText = "last_message_text"
    }
    
    // MARK: - Computed Properties
    var chatType: ChatType {
        if isDirect {
            return .direct
        } else if eventId != nil {
            return .event
        } else {
            return .general
        }
    }
    
    var displayName: String {
        let safeName = name ?? "Direct chat"
        switch chatType {
        case .direct:
            let cleanName = safeName.replacingOccurrences(of: "Chat with ", with: "")
                                    .replacingOccurrences(of: "Chat ", with: "")
            // Si el nombre empieza con "auth0", usar placeholder por ahora
            // La resolución se maneja en la vista para evitar problemas de concurrencia
            if cleanName.hasPrefix("auth0") {
                return "Direct Message" // Placeholder que se actualizará desde la vista
            }
            return cleanName
        case .event:
            return safeName.replacingOccurrences(of: "Event ", with: "")
        case .general:
            return safeName
        }
    }
    
    var iconName: String {
        switch chatType {
        case .direct:
            return "person.circle.fill"
        case .event:
            return "calendar.circle.fill"
        case .general:
            return "bubble.left.and.bubble.right.fill"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    // Fecha efectiva para ordenamiento (último mensaje o creación)
    var effectiveDate: Date {
        return lastMessageAt ?? createdAt
    }
    
    // Formato de fecha del último mensaje para UI
    var lastMessageFormattedDate: String {
        let date = effectiveDate
        let formatter = DateFormatter()
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            formatter.dateFormat = "EEEE" // Día de la semana
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // Texto del último mensaje truncado
    var truncatedLastMessage: String {
        guard let text = lastMessageText, !text.isEmpty else {
            return "New chat"
        }
        return text.count > 50 ? String(text.prefix(50)) + "..." : text
    }
    
    // Iniciales para el avatar
    var displayInitials: String {
        let name = displayName
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].first ?? "?") + String(words[1].first ?? "?")
        } else if let firstChar = name.first {
            return String(firstChar).uppercased()
        } else {
            return "?"
        }
    }
    
    // Último mensaje para mostrar en la UI
    var lastMessage: String? {
        return lastMessageText
    }
}

// MARK: - Chat Type Enum
enum ChatType: String, CaseIterable {
    case direct = "direct"
    case event = "event"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .direct: return "Direct"
        case .event: return "Events"
        case .general: return "General"
        }
    }
}

// MARK: - Protocolo común para servicios de autenticación
protocol AuthServiceProtocol: AnyObject {
    func getValidAccessToken() async -> String?
}

@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()
    
    // Hacer el init privado para forzar el uso del singleton
    private init() {
        print("🔧 ChatService singleton inicializado")
    }
    
    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    weak var authService: AuthServiceProtocol?
    
    // Gym ID dinámico - se puede configurar desde la app
    var currentGymId: Int {
        return GymService.shared.currentGymId ?? 4 // Fallback to 4 if no gym selected
    }
    
    // MARK: - Stream.io Configuration
    private let streamAPIKey = StreamConfig.apiKey
    // NOTA: API secret no se usa en frontend - el backend maneja la autenticación
    
    // MARK: - Published Properties
    @Published var streamToken: StreamTokenResponse?
    @Published var isLoadingToken = false
    @Published var isLoadingRoom = false
    @Published var errorMessage: String?
    @Published var connectedChannels: [String: Any] = [:]
    @Published var isConnectedToStream = false
    @Published var isTestingConnection = false
    @Published var connectionTestResult: String?
    
    // MARK: - Chat Rooms Properties
    @Published var chatRooms: [ChatRoom] = []
    @Published var isLoadingRooms = false
    @Published var roomsErrorMessage: String?
    
    // MARK: - Request Management
    private var currentMyRoomsTask: Task<Void, Never>?
    private var currentTokenTask: Task<StreamTokenResponse?, Never>?
    
    // MARK: - User Name Resolution
    // MIGRADO A UserDataCacheService - caché centralizado de usuarios
    private let userCache = UserDataCacheService.shared
    @Published var isLoadingGymMembers = false
    
    // MARK: - Current User ID (dinámico desde AuthService)
    private var currentUserId: Int? // Se configura dinámicamente desde el AuthService
    
    // MARK: - Last Messages Cache Properties
    @Published var isRefreshingMessages = false
    @Published var isUsingPersistedData = false // Para mostrar indicador en UI
    private var lastMessagesRefresh: Date?
    private let refreshInterval: TimeInterval = 300 // 5 minutos
    private var lastMessagesCache: [String: ChannelLastMessage] = [:]
    
    // MARK: - Persistence Properties
    private let userDefaults = UserDefaults.standard
    private let persistenceKey = "ChatService_LastMessages"
    private let lastRefreshKey = "ChatService_LastRefresh"
    
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
    
    // MARK: - Configure Current User
    func setCurrentUserId(_ userId: Int) {
        print("👤 ChatService: Configurando currentUserId: \(userId)")
        self.currentUserId = userId
    }
    
    func setCurrentUserIdFromString(_ userIdString: String?) {
        guard let userIdString = userIdString,
              let userId = Int(userIdString) else {
            print("❌ ChatService: No se pudo convertir userIdString a Int: \(userIdString ?? "nil")")
            return
        }
        setCurrentUserId(userId)
    }
    
    // MARK: - Helper for Authenticated Requests
    private func createAuthenticatedRequest(url: URL, method: String = "GET") async -> URLRequest? {
        guard let authService = authService else {
            print("❌ No authService configured")
            return nil
        }
        
        guard let token = await authService.getValidAccessToken() else {
            print("❌ No valid access token")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID") // Dinámico
        
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    // MARK: - Get Stream Token
    func getStreamToken() async -> StreamTokenResponse? {
        // Cancelar tarea anterior si existe
        currentTokenTask?.cancel()
        
        // Crear nueva tarea
        currentTokenTask = Task {
            return await performGetStreamToken()
        }
        
        return await currentTokenTask?.value
    }
    
    private func performGetStreamToken() async -> StreamTokenResponse? {
        updateOnMainThread {
            self.isLoadingToken = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/chat/token") else {
            updateOnMainThread {
                self.errorMessage = "URL inválida"
                self.isLoadingToken = false
            }
            return nil
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            updateOnMainThread {
                self.errorMessage = "No se pudo crear request autenticado"
                self.isLoadingToken = false
            }
            return nil
        }
        
        do {
            // Usar timeout más corto para evitar acumulación
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for stream token: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let streamTokenResponse = try decoder.decode(StreamTokenResponse.self, from: data)
                    
                    updateOnMainThread {
                        self.streamToken = streamTokenResponse
                        self.isLoadingToken = false
                    }
                    
                    print("🎫 Stream token obtenido exitosamente")
                    return streamTokenResponse
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error getting stream token: \(errorString)")
                    
                    updateOnMainThread {
                        self.errorMessage = "Error al obtener token: \(httpResponse.statusCode)"
                        self.isLoadingToken = false
                    }
                }
            }
        } catch {
            print("❌ Error fetching stream token: \(error)")
            
            updateOnMainThread {
                self.errorMessage = "Error de red: \(error.localizedDescription)"
                self.isLoadingToken = false
            }
        }
        
        return nil
    }
    
    // MARK: - Test GetStream Connection
    func testGetStreamConnection() async {
        updateOnMainThread {
            self.isTestingConnection = true
            self.connectionTestResult = nil
            self.errorMessage = nil
        }
        
        print("🧪 Iniciando prueba de conexión a GetStream...")
        
        // Paso 1: Obtener token
        guard let tokenResponse = await getStreamToken() else {
            updateOnMainThread {
                self.connectionTestResult = "❌ Error: No se pudo obtener el token de GetStream"
                self.isTestingConnection = false
            }
            return
        }
        
        print("✅ Token obtenido: \(tokenResponse.token.prefix(20))...")
        print("🔑 API Key: \(tokenResponse.apiKey)")
        print("👤 Internal User ID: \(tokenResponse.internalUserId)")
        
        // Decodificar el JWT para ver su contenido
        await decodeAndLogJWT(tokenResponse.token)
        
        // Almacenar el token para comparación posterior
        print("🔍 Token que se pasará al provider: \(tokenResponse.token)")
        
        // Paso 2: Intentar conectar usando el GetStreamChatProvider
        do {
            let provider = GetStreamChatProvider()
            
            // Crear credenciales de prueba
            // IMPORTANTE: El userId debe coincidir con el user_id del token JWT
            let userId = "user_\(tokenResponse.internalUserId)"
            
            let credentials = ChatCredentials(
                token: tokenResponse.token,
                apiKey: tokenResponse.apiKey,
                userId: userId,
                userInfo: ChatUser(
                    id: userId,
                    name: "Test User",
                    avatarURL: nil
                )
            )
            
            print("🔍 Usando userId: \(userId) para coincidir con el token")
            
            print("🔌 Intentando conectar a GetStream...")
            try await provider.connect(credentials: credentials)
            
            updateOnMainThread {
                self.isConnectedToStream = true
                self.connectionTestResult = "✅ Conexión exitosa a GetStream!"
                self.isTestingConnection = false
            }
            
            print("🎉 ¡Conexión exitosa a GetStream!")
            
            // Sincronizar con rooms de la API
            print("🔄 Sincronizando con rooms de la API...")
            await syncApiRoomsWithGetStream(provider: provider)
            
            // Desconectar después de la prueba
            await provider.disconnect()
            
            updateOnMainThread {
                self.isConnectedToStream = false
            }
            
        } catch {
            print("❌ Error conectando a GetStream: \(error)")
            updateOnMainThread {
                self.connectionTestResult = "❌ Error de conexión: \(error.localizedDescription)"
                self.isTestingConnection = false
                self.isConnectedToStream = false
            }
        }
    }
    
    // MARK: - JWT Debugging
    private func decodeAndLogJWT(_ token: String) async {
        print("🔍 Decodificando JWT...")
        
        // Dividir el JWT en sus partes
        let parts = token.split(separator: ".")
        if parts.count != 3 {
            print("❌ JWT inválido: no tiene 3 partes")
            return
        }
        
        // Decodificar el header
        if let headerData = base64UrlDecode(String(parts[0])),
           let headerJson = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] {
            print("📋 JWT Header:")
            for (key, value) in headerJson {
                print("   \(key): \(value)")
            }
        }
        
        // Decodificar el payload
        if let payloadData = base64UrlDecode(String(parts[1])),
           let payloadJson = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            print("📋 JWT Payload:")
            for (key, value) in payloadJson {
                print("   \(key): \(value)")
            }
            
            // Verificar campos importantes para GetStream
            if payloadJson["user_id"] != nil {
                print("✅ Campo 'user_id' encontrado en el token")
            } else {
                print("❌ Campo 'user_id' NO encontrado en el token")
                print("🔍 Campos disponibles: \(Array(payloadJson.keys).joined(separator: ", "))")
            }
            
            // Verificar otros campos relevantes
            if let sub = payloadJson["sub"] {
                print("📋 Subject (sub): \(sub)")
            }
            if let iss = payloadJson["iss"] {
                print("📋 Issuer (iss): \(iss)")
            }
            if let aud = payloadJson["aud"] {
                print("📋 Audience (aud): \(aud)")
            }
            if let exp = payloadJson["exp"] {
                print("📋 Expires (exp): \(exp)")
            }
        }
    }
    
    private func base64UrlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Agregar padding si es necesario
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        return Data(base64Encoded: base64)
    }
    
    // MARK: - Sync API Rooms with GetStream
    private func syncApiRoomsWithGetStream(provider: GetStreamChatProvider) async {
        print("🔄 Iniciando sincronización de rooms API con GetStream...")
        
        // Obtener rooms de la API
        await getMyRooms()
        
        print("📋 Rooms obtenidos de la API: \(chatRooms.count)")
        
        // Para each room, intentar crear/unirse al canal correspondiente en GetStream
        for room in chatRooms {
            print("🏠 Procesando room: \(room.name ?? "Sin nombre") - \(room.streamChannelId)")
            
            do {
                // Intentar unirse al canal en GetStream
                try await provider.joinConversation(room.streamChannelId)
                print("✅ Unido al canal: \(room.streamChannelId)")
                
                // Actualizar el nombre del canal si está disponible
                if let roomName = room.name, !roomName.isEmpty {
                    do {
                        try await provider.updateChannelName(room.streamChannelId, name: roomName)
                        print("🏷️ Nombre actualizado para \(room.streamChannelId): \(roomName)")
                    } catch {
                        print("⚠️ No se pudo actualizar el nombre del canal \(room.streamChannelId): \(error)")
                    }
                }
            } catch {
                print("❌ Error uniéndose al canal \(room.streamChannelId): \(error)")
                
                // Si no existe, intentar crearlo
                print("🛠️ Intentando crear canal: \(room.streamChannelId)")
                
                let conversationType: ChatConversation.ConversationType
                switch room.chatType {
                case .direct:
                    conversationType = .direct
                case .event:
                    conversationType = .group
                case .general:
                    conversationType = .channel
                }
                
                let createRequest = CreateConversationRequest(
                    id: room.streamChannelId, // Usar el ID específico de la API
                    name: room.name,
                    type: conversationType,
                    members: [], // Se agregarán los miembros posteriormente
                    metadata: [
                        "room_id": room.id,
                        "event_id": room.eventId as Any,
                        "is_direct": room.isDirect
                    ]
                )
                
                do {
                    let createdConversation = try await provider.createConversation(createRequest)
                    print("✅ Canal creado: \(createdConversation.id)")
                    
                    // Actualizar el nombre del canal recién creado
                    if let roomName = room.name, !roomName.isEmpty {
                        do {
                            try await provider.updateChannelName(room.streamChannelId, name: roomName)
                            print("🏷️ Nombre actualizado para canal creado \(room.streamChannelId): \(roomName)")
                        } catch {
                            print("⚠️ No se pudo actualizar el nombre del canal creado \(room.streamChannelId): \(error)")
                        }
                    }
                } catch {
                    print("❌ Error creando canal: \(error)")
                }
            }
        }
        
        // Después de sincronizar, obtener conversaciones actualizadas
        print("🔍 Obteniendo conversaciones actualizadas después de sincronización...")
        do {
            let conversations = try await provider.getConversations()
            print("💬 Conversaciones finales: \(conversations.count)")
            for (index, conversation) in conversations.enumerated() {
                print("   \(index + 1). ID: \(conversation.id), Name: \(conversation.name ?? "Sin nombre"), Members: \(conversation.members.count)")
            }
        } catch {
            print("❌ Error obteniendo conversaciones finales: \(error)")
        }
    }
    
    // MARK: - Get Event Chat Room
    func getEventChatRoom(eventId: Int) async -> ChatRoomSchema? {
        updateOnMainThread {
            self.isLoadingRoom = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/chat/rooms/event/\(eventId)") else {
            updateOnMainThread {
                self.errorMessage = "URL inválida"
                self.isLoadingRoom = false
            }
            return nil
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            updateOnMainThread {
                self.errorMessage = "No se pudo crear request autenticado"
                self.isLoadingRoom = false
            }
            return nil
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for event chat room: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let chatRoom = try decoder.decode(ChatRoomSchema.self, from: data)
                    
                    updateOnMainThread {
                        self.isLoadingRoom = false
                    }
                    
                    print("💬 Chat room obtenido exitosamente: \(chatRoom.streamChannelId)")
                    return chatRoom
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error getting event chat room: \(errorString)")
                    
                    updateOnMainThread {
                        self.errorMessage = "Error al obtener chat room: \(httpResponse.statusCode)"
                        self.isLoadingRoom = false
                    }
                }
            }
        } catch {
            print("❌ Error fetching event chat room: \(error)")
            
            updateOnMainThread {
                self.errorMessage = "Error de red: \(error.localizedDescription)"
                self.isLoadingRoom = false
            }
        }
        
        return nil
    }
    
    // MARK: - Get Chat Data for Event
    func getChatDataForEvent(eventId: Int) async -> (token: StreamTokenResponse, room: ChatRoomSchema)? {
        // Ejecutar ambas llamadas simultáneamente
        async let tokenResult = getStreamToken()
        async let roomResult = getEventChatRoom(eventId: eventId)
        
        // Esperar a que ambas terminen
        let (token, room) = await (tokenResult, roomResult)
        
        if let token = token, let room = room {
            return (token: token, room: room)
        }
        
        return nil
    }
    
    // MARK: - Get My Rooms (usando nuevo endpoint)
    func getMyRoomsFromAPI() async -> [ChatRoomResponse]? {
        guard let url = URL(string: "\(baseURL)/chat/my-rooms") else {
            print("❌ URL inválida para my-rooms")
            return nil
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            print("❌ No se pudo crear request autenticado")
            return nil
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for my-rooms: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let rooms = try decoder.decode([ChatRoomResponse].self, from: data)
                    print("✅ Salas cargadas desde API: \(rooms.count)")
                    return rooms
                } else {
                    print("❌ Error HTTP: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Error detail: \(errorString)")
                    }
                }
            }
        } catch {
            print("❌ Error obteniendo salas: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Get My Rooms (método original)
    func getMyRooms() async {
        // Cancelar tarea anterior si existe
        currentMyRoomsTask?.cancel()
        
        // Crear nueva tarea
        currentMyRoomsTask = Task {
            await performGetMyRooms()
        }
        
        await currentMyRoomsTask?.value
    }
    
    private func performGetMyRooms() async {
        updateOnMainThread {
            self.isLoadingRooms = true
            self.roomsErrorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/chat/my-rooms") else {
            updateOnMainThread {
                self.roomsErrorMessage = "URL inválida"
                self.isLoadingRooms = false
            }
            return
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            updateOnMainThread {
                self.roomsErrorMessage = "No se pudo crear request autenticado"
                self.isLoadingRooms = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for my rooms: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        let dateFormats = [
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS"
                        ]
                        
                        for format in dateFormats {
                            formatter.dateFormat = format
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'")
                    }
                    
                    let rooms = try decoder.decode([ChatRoom].self, from: data)
                    
                    updateOnMainThread {
                        // Ordenar por fecha efectiva al cargar inicialmente
                        self.chatRooms = rooms.sorted { $0.effectiveDate > $1.effectiveDate }
                        self.isLoadingRooms = false
                    }
                    
                    print("💬 Salas de chat cargadas exitosamente: \(rooms.count)")
                    
                    // Cargar mensajes guardados inmediatamente después de cargar rooms
                    loadLastMessagesFromStorage()
                    
                    // Resolver nombres en background
                    Task {
                        await resolveUserNames()
                        await resolveUserNamesFromChannelIds()
                    }
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error getting my rooms: \(errorString)")
                    
                    updateOnMainThread {
                        self.roomsErrorMessage = "Error al obtener salas de chat: \(httpResponse.statusCode)"
                        self.isLoadingRooms = false
                    }
                }
            }
        } catch {
            print("❌ Error fetching my rooms: \(error)")
            
            updateOnMainThread {
                self.roomsErrorMessage = "Error de red: \(error.localizedDescription)"
                self.isLoadingRooms = false
            }
        }
    }
    
    // MARK: - Get All Gym Members
    func loadGymMembers() async {
        guard !isLoadingGymMembers else {
            print("⚠️ Ya hay una carga de miembros en progreso")
            return
        }
        
        updateOnMainThread {
            self.isLoadingGymMembers = true
        }
        
        guard let url = URL(string: "\(baseURL)/users/p/gym-participants?skip=0&limit=200") else {
            print("❌ URL inválida para obtener miembros del gym")
            updateOnMainThread {
                self.isLoadingGymMembers = false
            }
            return
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            print("❌ No se pudo crear request autenticado para miembros")
            updateOnMainThread {
                self.isLoadingGymMembers = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for gym members: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)
                    
                    let participants = try decoder.decode([GymParticipant].self, from: data)
                    
                    print("🏃‍♂️ Participantes cargados: \(participants.count)")
                    
                    // Convertir participantes a UserProfile y actualizar cache
                    var validMembers: [UserProfile] = []
                    var coachCount = 0
                    var memberCount = 0
                    
                    for participant in participants {
                        let roleText = participant.role ?? "member"
                        let gymRoleText = participant.gymRole ?? ""
                        
                        // Determinar si es coach
                        let isCoach = roleText.lowercased().contains("coach") ||
                                     gymRoleText.lowercased().contains("coach") ||
                                     roleText.lowercased().contains("trainer") ||
                                     gymRoleText.lowercased().contains("trainer")
                        
                        if isCoach {
                            coachCount += 1
                            print("🏃‍♂️ Coach encontrado: \(participant.fullName) - Role: \(roleText) - Gym Role: \(gymRoleText)")
                        } else {
                            memberCount += 1
                        }
                        
                        print("👤 Participante: \(participant.fullName) - Role: \(roleText) - Gym Role: \(gymRoleText) - ID: \(participant.id)")
                        
                        // Si no podemos convertir a UserProfile, al menos guardar el nombre
                        if let userProfile = participant.toUserProfile() {
                            validMembers.append(userProfile)
                            // Guardar en caché centralizado
                            self.userCache.updateUserProfile(participant.id, profile: userProfile)
                        }
                    }
                    
                    updateOnMainThread {
                        // Actualizar cache de miembros con los que pudimos convertir
                        // Actualizar caché centralizado
                        self.userCache.updateUserProfiles(validMembers)
                        self.isLoadingGymMembers = false
                    }
                    
                    print("✅ Cargados \(participants.count) participantes del gym")
                    print("   - 🏃‍♂️ Coaches/Trainers: \(coachCount)")
                    print("   - 👤 Miembros regulares: \(memberCount)")
                    print("✅ Convertidos \(validMembers.count) a UserProfile")
                    print("👤 Miembros cargados: \(validMembers.count)")
                    
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error getting gym members: \(errorString)")
                    
                    updateOnMainThread {
                        self.isLoadingGymMembers = false
                    }
                }
            }
        } catch {
            print("❌ Error fetching gym members: \(error)")
            
            updateOnMainThread {
                self.isLoadingGymMembers = false
            }
        }
    }

    // MARK: - Get User By ID
    func getUserById(_ userId: Int) async -> UserProfile? {
        // Usar caché centralizado
        if let profile = await userCache.getUserProfile(userId) {
            print("📋 Usuario encontrado: \(userId) -> \(profile.fullName)")
            return profile
        }

        // Si no está en caché y no hemos cargado miembros, cargar
        if !isLoadingGymMembers {
            print("🔄 Cargando todos los miembros del gym...")
            await loadGymMembers()

            // Verificar de nuevo después de cargar
            if let profile = await userCache.getUserProfile(userId) {
                print("📋 Usuario encontrado después de cargar: \(userId) -> \(profile.fullName)")
                return profile
            }
        }

        print("❌ Usuario \(userId) no encontrado")
        return nil
    }

    // MARK: - Resolve User Names
    func resolveUserNames() async {
        print("🔍 Iniciando resolución de nombres de usuarios...")
        
        // Cargar todos los miembros del gym si es necesario
        await loadGymMembers()

        print("✅ Resolución de nombres completada")
    }
    
    // MARK: - Resolve User Names from Channel IDs
    func resolveUserNamesFromChannelIds() async {
        print("🔍 Iniciando resolución de nombres desde channel IDs...")
        
        // Cargar todos los miembros del gym si es necesario
        await loadGymMembers()
        
        // Extraer todos los IDs únicos de usuarios mencionados en los channel IDs
        var userIds: Set<Int> = []
        
        for room in chatRooms {
            if room.chatType == .direct {
                let pattern = "direct_user_(\\d+)_user_(\\d+)"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: room.streamChannelId, range: NSRange(room.streamChannelId.startIndex..., in: room.streamChannelId)) {
                    
                    if let range1 = Range(match.range(at: 1), in: room.streamChannelId),
                       let range2 = Range(match.range(at: 2), in: room.streamChannelId) {
                        
                        let userId1String = String(room.streamChannelId[range1])
                        let userId2String = String(room.streamChannelId[range2])
                        
                        if let userId1 = Int(userId1String) {
                            userIds.insert(userId1)
                        }
                        if let userId2 = Int(userId2String) {
                            userIds.insert(userId2)
                        }
                    }
                }
            }
        }
        
        print("🔍 IDs de usuarios encontrados en channels: \(Array(userIds).sorted())")
        print("✅ Resolución de nombres desde channel IDs completada")
    }
    
    // MARK: - Cache for resolved display names
    private var resolvedDisplayNameCache: [String: String] = [:]
    private var pendingResolutions: Set<String> = []
    
    // MARK: - Get Resolved Display Name
    func getResolvedDisplayName(for chatRoom: ChatRoom) -> String {
        // Para chats no directos, siempre usar displayName
        guard chatRoom.chatType == .direct else {
            return chatRoom.displayName
        }
        
        // Usar cache de nombres resueltos para evitar recálculos
        if let cachedDisplayName = resolvedDisplayNameCache[chatRoom.streamChannelId] {
            return cachedDisplayName
        }
        
        // Si ya hay una resolución pendiente para este chat, no iniciar otra
        if pendingResolutions.contains(chatRoom.streamChannelId) {
            return "Loading..."
        }
        
        // Marcar como pendiente para evitar múltiples resoluciones
        pendingResolutions.insert(chatRoom.streamChannelId)
        
        // Para chats directos, extraer los IDs del streamChannelId
        let pattern = "direct_user_(\\d+)_user_(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: chatRoom.streamChannelId, range: NSRange(chatRoom.streamChannelId.startIndex..., in: chatRoom.streamChannelId)) {
            
            if let range1 = Range(match.range(at: 1), in: chatRoom.streamChannelId),
               let range2 = Range(match.range(at: 2), in: chatRoom.streamChannelId) {
                
                let userId1String = String(chatRoom.streamChannelId[range1])
                let userId2String = String(chatRoom.streamChannelId[range2])
                
                if let userId1 = Int(userId1String),
                   let userId2 = Int(userId2String),
                   let currentUserId = currentUserId {
                    
                    // Determinar cuál es el otro usuario
                    let otherUserId = (userId1 == currentUserId) ? userId2 : userId1
                    
                    // Buscar en caché centralizado (acceso sync para evitar async en esta función)
                    if let cachedName = userCache.userNames[otherUserId],
                       !cachedName.starts(with: "Usuario") {
                        let resolvedName = cachedName
                        resolvedDisplayNameCache[chatRoom.streamChannelId] = resolvedName
                        pendingResolutions.remove(chatRoom.streamChannelId)
                        return resolvedName
                    }
                    
                    // Si no está en cache, iniciar carga en background una sola vez
                    Task {
                        await loadGymMembersForResolution(chatRoomId: chatRoom.streamChannelId, otherUserId: otherUserId)
                    }
                    
                    return "Loading..."
                }
                
                // Fallback cuando no hay currentUserId configurado o IDs no válidos
                let fallbackName: String
                if currentUserId == nil {
                    fallbackName = "Direct Message (Login required)"
                } else {
                    fallbackName = "Chat \(userId1String)-\(userId2String)"
                }
                resolvedDisplayNameCache[chatRoom.streamChannelId] = fallbackName
                pendingResolutions.remove(chatRoom.streamChannelId)
                return fallbackName
            }
        }
        
        // Fallback final
        let fallbackName = "Direct Message"
        resolvedDisplayNameCache[chatRoom.streamChannelId] = fallbackName
        pendingResolutions.remove(chatRoom.streamChannelId)
        return fallbackName
    }
    
    // MARK: - Load Gym Members for Name Resolution
    private func loadGymMembersForResolution(chatRoomId: String, otherUserId: Int) async {
        // Resolver directamente desde caché centralizado
        await resolveNameFromCache(chatRoomId: chatRoomId, otherUserId: otherUserId)
        
        // Si ya hay una carga en progreso, esperar
        if isLoadingGymMembers {
            // Esperar un poco y volver a intentar
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
            await resolveNameFromCache(chatRoomId: chatRoomId, otherUserId: otherUserId)
            return
        }
        
        // Cargar miembros
        await loadGymMembers()
        await resolveNameFromCache(chatRoomId: chatRoomId, otherUserId: otherUserId)
    }
    
    // MARK: - Resolve Name from Cache
    private func resolveNameFromCache(chatRoomId: String, otherUserId: Int) async {
        let resolvedName: String
        
        let cachedName = await userCache.getUserName(otherUserId)
        if !cachedName.starts(with: "Usuario") {
            resolvedName = cachedName
        } else {
            resolvedName = "User \(otherUserId)"
        }
        
        updateOnMainThread {
            self.resolvedDisplayNameCache[chatRoomId] = resolvedName
            self.pendingResolutions.remove(chatRoomId)
            // Forzar actualización de la UI
            self.objectWillChange.send()
        }
    }

    // MARK: - Get Direct Chat (1:1) - Para miembros y coaches
    func getDirectChat(withUserId userId: Int) async -> ChatRoom? {
        print("🔗 ChatService: Iniciando getDirectChat con userId: \(userId)")
        print("🔗 ChatService: BaseURL: \(baseURL)")
        
        updateOnMainThread {
            self.isLoadingRooms = true
            self.roomsErrorMessage = nil
        }
        
        let urlString = "\(baseURL)/chat/rooms/direct/\(userId)"
        print("🌐 ChatService: URL completa: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ChatService: URL inválida: \(urlString)")
            updateOnMainThread {
                self.roomsErrorMessage = "URL inválida para chat directo"
                self.isLoadingRooms = false
            }
            return nil
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            print("❌ ChatService: No se pudo crear request autenticado")
            updateOnMainThread {
                self.roomsErrorMessage = "No se pudo crear request autenticado"
                self.isLoadingRooms = false
            }
            return nil
        }
        
        print("🔄 ChatService: Enviando request a: \(request.url?.absoluteString ?? "URL desconocida")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for direct chat: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        let dateFormats = [
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                        ]
                        
                        for format in dateFormats {
                            formatter.dateFormat = format
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'")
                    }
                    
                    let directChatRoom = try decoder.decode(ChatRoom.self, from: data)
                    
                    updateOnMainThread {
                        self.isLoadingRooms = false
                    }
                    
                    print("💬 Chat directo obtenido exitosamente: \(directChatRoom.streamChannelId)")
                    
                    // Actualizar la lista de chat rooms si el nuevo chat no existe
                    await refreshChatRoomsIfNeeded(with: directChatRoom)
                    
                    return directChatRoom
                    
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error getting direct chat: \(errorString)")
                    
                    updateOnMainThread {
                        self.roomsErrorMessage = "Error al obtener chat directo: \(httpResponse.statusCode)"
                        self.isLoadingRooms = false
                    }
                }
            }
        } catch {
            print("❌ Error fetching direct chat: \(error)")
            
            updateOnMainThread {
                self.roomsErrorMessage = "Error de red: \(error.localizedDescription)"
                self.isLoadingRooms = false
            }
        }
        
        return nil
    }
    
    // MARK: - Get Direct Chat with Coach (convenience method)
    func getDirectChatWithCoach(_ coach: UserProfile) async -> ChatRoom? {
        print("🏃‍♂️ Iniciando chat directo con coach: \(coach.fullName)")
        return await getDirectChat(withUserId: coach.id)
    }
    
    // MARK: - Get Available Coaches
    func getAvailableCoaches() async -> [UserProfile] {
        print("🔍 Obteniendo coaches disponibles...")

        // Cargar miembros del gym si es necesario
        await loadGymMembers()

        // Obtener todos los miembros del caché centralizado
        let allMembers = await userCache.getUsers(Array(1...1000)) // Obtener todos los usuarios disponibles
        let coaches = allMembers.filter { member in
            let isCoach = member.role.lowercased().contains("coach") ||
                         member.gymRole?.lowercased().contains("coach") == true ||
                         member.role.lowercased().contains("trainer") ||
                         member.gymRole?.lowercased().contains("trainer") == true

            return isCoach && member.isActive
        }.sorted { $0.fullName < $1.fullName }

        print("✅ Coaches encontrados: \(coaches.count)")
        return coaches
    }

    /// Obtiene TODOS los miembros activos del gimnasio (no solo coaches)
    /// Usado cuando un TRAINER/ADMIN/OWNER quiere chatear con cualquier usuario
    func getAllGymMembers() async -> [UserProfile] {
        print("🔍 Obteniendo todos los miembros del gimnasio...")

        // Cargar miembros del gym si es necesario
        await loadGymMembers()

        // Obtener todos los miembros del caché centralizado
        let allMembers = await userCache.getUsers(Array(1...1000))
        let activeMembers = allMembers.filter { member in
            return member.isActive
        }.sorted { $0.fullName < $1.fullName }

        print("✅ Miembros activos encontrados: \(activeMembers.count)")
        return activeMembers
    }
    
    // MARK: - Helper: Refresh Chat Rooms if Needed
    private func refreshChatRoomsIfNeeded(with newChatRoom: ChatRoom) async {
        updateOnMainThread {
            // Verificar si ya existe en la lista
            if !self.chatRooms.contains(where: { $0.id == newChatRoom.id }) {
                // Agregar el nuevo chat room al principio de la lista
                self.chatRooms.insert(newChatRoom, at: 0)
                print("➕ Nuevo chat room agregado a la lista: \(newChatRoom.displayName)")
            } else {
                print("✅ Chat room ya existe en la lista")
            }
        }
    }
    
    // MARK: - Join General Channel - Para miembros  
    func joinGeneralChannel() async -> ChatRoom? {
        updateOnMainThread {
            self.isLoadingRooms = true
            self.roomsErrorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/chat/general-channel/join") else {
            updateOnMainThread {
                self.roomsErrorMessage = "URL inválida para unirse al canal general"
                self.isLoadingRooms = false
            }
            return nil
        }
        
        guard let request = await createAuthenticatedRequest(url: url, method: "POST") else {
            updateOnMainThread {
                self.roomsErrorMessage = "No se pudo crear request autenticado"
                self.isLoadingRooms = false
            }
            return nil
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for join general channel: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        let dateFormats = [
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                        ]
                        
                        for format in dateFormats {
                            formatter.dateFormat = format
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'")
                    }
                    
                    let generalChannel = try decoder.decode(ChatRoom.self, from: data)
                    
                    updateOnMainThread {
                        self.isLoadingRooms = false
                    }
                    
                    print("💬 Se unió al canal general exitosamente: \(generalChannel.streamChannelId)")
                    return generalChannel
                    
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error joining general channel: \(errorString)")
                    
                    updateOnMainThread {
                        self.roomsErrorMessage = "Error al unirse al canal general: \(httpResponse.statusCode)"
                        self.isLoadingRooms = false
                    }
                }
            }
        } catch {
            print("❌ Error joining general channel: \(error)")
            
            updateOnMainThread {
                self.roomsErrorMessage = "Error de red: \(error.localizedDescription)"
                self.isLoadingRooms = false
            }
        }
        
        return nil
    }
    
    // MARK: - Last Messages Management
    
    /// Verifica si es necesario refrescar los últimos mensajes
    private func shouldRefreshMessages() -> Bool {
        guard let lastRefresh = lastMessagesRefresh else { return true }
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceLastRefresh > refreshInterval
    }
    
    /// Refresca los últimos mensajes de todos los canales desde Stream.io
    func refreshLastMessages(force: Bool = false) async {
        // Solo refrescar si es necesario o si se fuerza
        guard force || shouldRefreshMessages() else {
            print("🕐 Últimos mensajes ya están actualizados, saltando refresh")
            return
        }
        
        // Evitar múltiples refreshes simultáneos
        guard !isRefreshingMessages else {
            print("🔄 Ya hay un refresh en progreso, saltando")
            return
        }
        
        updateOnMainThread {
            self.isRefreshingMessages = true
        }
        
        print("🔍 Iniciando refresh de últimos mensajes para \(chatRooms.count) canales...")
        
        // TODO: Implementar obtención de últimos mensajes desde el nuevo sistema
        let lastMessages: [ChannelLastMessage] = []
        
        // Actualizar cache local
        for lastMessage in lastMessages {
            lastMessagesCache[lastMessage.channelId] = lastMessage
        }
        
        // Actualizar chat rooms con nuevos datos
        await updateChatRoomsWithLastMessages(lastMessages)
        
        // Guardar en storage para persistencia
        saveLastMessagesToStorage()
        
        updateOnMainThread {
            self.isRefreshingMessages = false
            self.isUsingPersistedData = false // Ya tenemos datos frescos
            self.lastMessagesRefresh = Date()
        }
        
        print("✅ Refresh de últimos mensajes completado y guardado")
    }
    
    /// Actualiza los ChatRooms con los datos de últimos mensajes obtenidos
    private func updateChatRoomsWithLastMessages(_ lastMessages: [ChannelLastMessage]) async {
        updateOnMainThread {
            var updatedRooms: [ChatRoom] = []
            
            for chatRoom in self.chatRooms {
                // Buscar datos actualizados para este canal
                if let lastMessageData = lastMessages.first(where: { $0.channelId == chatRoom.streamChannelId }) {
                    // Crear nuevo ChatRoom con datos actualizados
                    let updatedRoom = ChatRoom(
                        id: chatRoom.id,
                        name: chatRoom.name,
                        isDirect: chatRoom.isDirect,
                        eventId: chatRoom.eventId,
                        streamChannelId: chatRoom.streamChannelId,
                        streamChannelType: chatRoom.streamChannelType,
                        createdAt: chatRoom.createdAt,
                        lastMessageAt: lastMessageData.lastMessageAt,
                        lastMessageText: lastMessageData.lastMessageText
                    )
                    updatedRooms.append(updatedRoom)
                    
                    print("🔄 Actualizado canal \(chatRoom.streamChannelId): \(lastMessageData.hasMessages ? "con mensaje" : "sin mensajes")")
                } else {
                    // Mantener el ChatRoom original si no hay datos nuevos
                    updatedRooms.append(chatRoom)
                }
            }
            
            // Asignar y ordenar por fecha efectiva (más recientes primero)
            self.chatRooms = updatedRooms.sorted { $0.effectiveDate > $1.effectiveDate }
            print("✅ ChatRooms actualizados y ordenados: \(updatedRooms.count) canales")
        }
    }
    
    /// Obtiene un último mensaje desde el cache local
    func getCachedLastMessage(for channelId: String) -> ChannelLastMessage? {
        return lastMessagesCache[channelId]
    }
    
    /// Limpia el cache de últimos mensajes
    func clearLastMessagesCache() {
        lastMessagesCache.removeAll()
        lastMessagesRefresh = nil
        clearPersistedMessages()
        print("🗑️ Cache de últimos mensajes limpiado")
    }
    
    // MARK: - Persistence Methods
    
    /// Guarda los últimos mensajes en UserDefaults para persistencia
    private func saveLastMessagesToStorage() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let messagesArray = Array(lastMessagesCache.values)
            let data = try encoder.encode(messagesArray)
            
            userDefaults.set(data, forKey: persistenceKey)
            userDefaults.set(Date(), forKey: lastRefreshKey)
            
            print("💾 Guardados \(messagesArray.count) últimos mensajes en storage")
        } catch {
            print("❌ Error guardando últimos mensajes: \(error.localizedDescription)")
        }
    }
    
    /// Carga los últimos mensajes desde UserDefaults
    private func loadLastMessagesFromStorage() {
        guard let data = userDefaults.data(forKey: persistenceKey) else {
            print("📱 No hay mensajes guardados en storage")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let messagesArray = try decoder.decode([ChannelLastMessage].self, from: data)
            
            // Convertir array a dictionary
            for message in messagesArray {
                lastMessagesCache[message.channelId] = message
            }
            
            // Cargar fecha de último refresh
            if let savedRefreshDate = userDefaults.object(forKey: lastRefreshKey) as? Date {
                lastMessagesRefresh = savedRefreshDate
            }
            
            print("📱 Cargados \(messagesArray.count) últimos mensajes desde storage")
            
            // Marcar que estamos usando datos guardados
            updateOnMainThread {
                self.isUsingPersistedData = true
            }
            
            // Aplicar los datos guardados a los ChatRooms actuales
            applyPersistedMessagesToChatRooms()
            
        } catch {
            print("❌ Error cargando últimos mensajes: \(error.localizedDescription)")
        }
    }
    
    /// Aplica los mensajes guardados a los ChatRooms actuales
    private func applyPersistedMessagesToChatRooms() {
        guard !chatRooms.isEmpty && !lastMessagesCache.isEmpty else { return }
        
        let persistedMessages = Array(lastMessagesCache.values)
        
        // Aplicar en background para no bloquear UI
        Task { @MainActor in
            await updateChatRoomsWithLastMessages(persistedMessages)
            print("📱 Aplicados mensajes guardados a \(chatRooms.count) chat rooms")
        }
    }
    
    /// Limpia los mensajes guardados en storage
    private func clearPersistedMessages() {
        userDefaults.removeObject(forKey: persistenceKey)
        userDefaults.removeObject(forKey: lastRefreshKey)
        print("🗑️ Mensajes guardados eliminados del storage")
    }
    
    // MARK: - Real-time Updates
    
    /// Actualiza un mensaje específico cuando se envía/recibe en tiempo real
    func updateLastMessageForChannel(_ channelId: String, messageText: String, messageDate: Date = Date()) {
        print("📨 Actualizando último mensaje para canal: \(channelId)")
        print("💬 Mensaje: \(messageText)")
        print("📅 Fecha: \(messageDate)")
        
        // Actualizar cache local
        let updatedMessage = ChannelLastMessage(
            channelId: channelId,
            lastMessageAt: messageDate,
            lastMessageText: messageText
        )
        lastMessagesCache[channelId] = updatedMessage
        
        // Actualizar ChatRoom correspondiente
        updateOnMainThread {
            if let index = self.chatRooms.firstIndex(where: { $0.streamChannelId == channelId }) {
                print("🔍 Encontrado ChatRoom en índice \(index): \(self.chatRooms[index].name ?? "Sin nombre")")
                
                let currentRoom = self.chatRooms[index]
                let oldDate = currentRoom.effectiveDate
                print("📅 Fecha anterior: \(oldDate)")
                
                let updatedRoom = ChatRoom(
                    id: currentRoom.id,
                    name: currentRoom.name,
                    isDirect: currentRoom.isDirect,
                    eventId: currentRoom.eventId,
                    streamChannelId: currentRoom.streamChannelId,
                    streamChannelType: currentRoom.streamChannelType,
                    createdAt: currentRoom.createdAt,
                    lastMessageAt: messageDate,
                    lastMessageText: messageText
                )
                self.chatRooms[index] = updatedRoom
                
                let newDate = updatedRoom.effectiveDate
                print("📅 Nueva fecha efectiva: \(newDate)")
                
                // Log del estado antes del ordenamiento
                print("🔄 Estado antes del ordenamiento:")
                for (i, room) in self.chatRooms.enumerated() {
                    print("   \(i): \(room.name ?? "Sin nombre") - \(room.effectiveDate)")
                }
                
                // Re-ordenar por fecha efectiva
                self.chatRooms.sort { $0.effectiveDate > $1.effectiveDate }
                
                // Log del estado después del ordenamiento
                print("✅ Estado después del ordenamiento:")
                for (i, room) in self.chatRooms.enumerated() {
                    print("   \(i): \(room.name ?? "Sin nombre") - \(room.effectiveDate)")
                }
                
                print("🔄 Actualizado mensaje en tiempo real para canal \(channelId): \"\(messageText)\"")
            } else {
                print("⚠️ No se encontró ChatRoom con channelId: \(channelId)")
                print("🔍 ChatRooms disponibles:")
                for room in self.chatRooms {
                    print("   - \(room.streamChannelId): \(room.name ?? "Sin nombre")")
                }
            }
        }
        
        // Guardar inmediatamente para persistencia
        saveLastMessagesToStorage()
    }
    
    /// Método conveniente para llamar cuando se envía un mensaje
    func notifyMessageSent(in channelId: String, messageText: String) {
        updateLastMessageForChannel(channelId, messageText: messageText)
    }
    
    /// Inicializa los datos guardados al abrir la app (debe llamarse desde MainTabView)
    func initializePersistedData() {
        print("🚀 Inicializando datos guardados de últimos mensajes...")
        loadLastMessagesFromStorage()
    }
    
    // MARK: - Clear All Data
    
    /// Cancela todas las tareas en progreso
    func cancelAllTasks() {
        print("🚫 Cancelando todas las tareas de ChatService en progreso...")
        currentMyRoomsTask?.cancel()
        currentTokenTask?.cancel()
        currentMyRoomsTask = nil
        currentTokenTask = nil
    }
    
    /// Limpia todos los datos del chat
    func clearAllData() {
        print("🧹 Limpiando todos los datos de chat...")
        
        // Cancelar tareas en progreso
        cancelAllTasks()
        
        // Limpiar arrays y cache
        chatRooms = []
        // Caché de usuarios manejado por UserDataCacheService
        lastMessagesCache = [:]
        
        // Limpiar persistencia
        clearPersistedMessages()
        
        // Resetear estados
        isLoadingRooms = false
        isLoadingGymMembers = false
        isRefreshingMessages = false
        errorMessage = nil
        
        // TODO: Desconectar del nuevo sistema de chat si es necesario

        print("✅ Datos de chat limpiados")
    }

    deinit {
        #if DEBUG
        print("🗑️ ChatService deinitialized")
        #endif
        // Los datos de chat se limpiarán automáticamente con ARC
        // No podemos modificar propiedades @Published desde deinit en una clase @MainActor
    }
} 