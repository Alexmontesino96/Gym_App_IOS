# Sistema de Caché de Mensajes - Plan de Implementación

## Objetivo
Implementar un sistema de caché que guarde los últimos 50 mensajes de cada conversación para mostrar contenido instantáneamente mientras se cargan los datos frescos de GetStream en background.

## 1. Estructura de Datos

### 1.1 Modelos de Caché
```swift
// Archivo: Gym_API/Models/MessageCacheModels.swift

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
    
    // Convertir desde ChatMessage
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
    
    // Convertir a ChatMessage
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

struct CachedAttachment: Codable {
    let id: String
    let type: String
    let url: String?
    let title: String?
    let previewURL: String?
    
    init(from attachment: ChatAttachment) {
        self.id = attachment.id
        self.type = attachment.type.rawValue
        self.url = attachment.url
        self.title = attachment.title
        self.previewURL = attachment.previewURL
    }
    
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

struct ConversationMessageCache: Codable {
    let conversationId: String
    let messages: [CachedMessage]
    let lastUpdated: Date
    let oldestMessageId: String?
    let newestMessageId: String?
    let totalMessages: Int
    
    init(conversationId: String, messages: [CachedMessage]) {
        self.conversationId = conversationId
        self.messages = messages
        self.lastUpdated = Date()
        self.oldestMessageId = messages.last?.id
        self.newestMessageId = messages.first?.id
        self.totalMessages = messages.count
    }
}

struct MessageCacheMetadata: Codable {
    let version: String
    let createdAt: Date
    let lastCleanup: Date
    let totalConversations: Int
    let totalMessages: Int
    let totalSizeBytes: Int64
    
    static let currentVersion = "1.0"
}
```

## 2. MessageCacheManager - Gestor Principal

### 2.1 Interfaz Principal
```swift
// Archivo: Gym_API/Services/MessageCacheManager.swift

@MainActor
class MessageCacheManager: ObservableObject {
    static let shared = MessageCacheManager()
    
    // MARK: - Constants
    private let maxMessagesPerConversation = 50
    private let maxCachedConversations = 100
    private let maxCacheSizeBytes: Int64 = 50 * 1024 * 1024 // 50MB
    private let cacheDirectoryName = "MessageCache"
    private let metadataFileName = "cache_metadata.json"
    
    // MARK: - Properties
    @Published var isLoading = false
    @Published var cacheStats = CacheStats()
    
    private let fileManager = FileManager.default
    private let cacheQueue = DispatchQueue(label: "message.cache.queue", qos: .userInitiated)
    private var cacheDirectory: URL?
    
    // MARK: - Cache Stats
    struct CacheStats {
        var totalConversations = 0
        var totalMessages = 0
        var totalSizeBytes: Int64 = 0
        var lastUpdated = Date()
    }
    
    private init() {
        setupCacheDirectory()
        loadCacheStats()
    }
}
```

### 2.2 Métodos Principales
```swift
extension MessageCacheManager {
    
    // MARK: - Public Methods
    
    /// Obtiene mensajes desde caché para una conversación
    func getCachedMessages(for conversationId: String) -> [ChatMessage] {
        return cacheQueue.sync {
            do {
                guard let cacheData = loadConversationCache(conversationId: conversationId) else {
                    print("📦 No hay caché para conversación: \(conversationId)")
                    return []
                }
                
                print("📦 Cargados \(cacheData.messages.count) mensajes desde caché para: \(conversationId)")
                return cacheData.messages.map { $0.toChatMessage() }
            } catch {
                print("❌ Error cargando mensajes desde caché: \(error)")
                return []
            }
        }
    }
    
    /// Guarda mensajes en caché para una conversación
    func saveMessages(_ messages: [ChatMessage], for conversationId: String) {
        cacheQueue.async { [weak self] in
            self?.performSaveMessages(messages, for: conversationId)
        }
    }
    
    /// Agrega un mensaje individual al caché
    func addMessage(_ message: ChatMessage, to conversationId: String) {
        cacheQueue.async { [weak self] in
            self?.performAddMessage(message, to: conversationId)
        }
    }
    
    /// Elimina caché de una conversación específica
    func clearCache(for conversationId: String) {
        cacheQueue.async { [weak self] in
            self?.performClearCache(for: conversationId)
        }
    }
    
    /// Elimina todo el caché
    func clearAllCache() {
        cacheQueue.async { [weak self] in
            self?.performClearAllCache()
        }
    }
    
    /// Limpia el caché basado en límites y antigüedad
    func performMaintenance() {
        cacheQueue.async { [weak self] in
            self?.performCacheMaintenance()
        }
    }
}
```

### 2.3 Implementación Interna
```swift
private extension MessageCacheManager {
    
    func setupCacheDirectory() {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ No se pudo obtener documents directory")
            return
        }
        
        cacheDirectory = documentsDirectory.appendingPathComponent(cacheDirectoryName)
        
        if let cacheDir = cacheDirectory {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                print("✅ Directorio de caché configurado: \(cacheDir.path)")
            } catch {
                print("❌ Error creando directorio de caché: \(error)")
            }
        }
    }
    
    func performSaveMessages(_ messages: [ChatMessage], for conversationId: String) {
        // Limitar a los últimos 50 mensajes
        let limitedMessages = Array(messages.prefix(maxMessagesPerConversation))
        let cachedMessages = limitedMessages.map { CachedMessage(from: $0) }
        
        let cacheData = ConversationMessageCache(
            conversationId: conversationId,
            messages: cachedMessages
        )
        
        do {
            let data = try JSONEncoder().encode(cacheData)
            let fileURL = getCacheFileURL(for: conversationId)
            try data.write(to: fileURL)
            
            print("💾 Guardados \(cachedMessages.count) mensajes en caché para: \(conversationId)")
            updateCacheStats()
        } catch {
            print("❌ Error guardando mensajes en caché: \(error)")
        }
    }
    
    func performAddMessage(_ message: ChatMessage, to conversationId: String) {
        // Cargar caché existente
        var existingCache = loadConversationCache(conversationId: conversationId)
        
        if existingCache == nil {
            // Si no existe caché, crear uno nuevo
            existingCache = ConversationMessageCache(
                conversationId: conversationId,
                messages: []
            )
        }
        
        guard var cache = existingCache else { return }
        
        // Agregar nuevo mensaje al principio
        var updatedMessages = cache.messages
        let newCachedMessage = CachedMessage(from: message)
        
        // Verificar si el mensaje ya existe
        if !updatedMessages.contains(where: { $0.id == message.id }) {
            updatedMessages.insert(newCachedMessage, at: 0)
            
            // Mantener límite de 50 mensajes
            if updatedMessages.count > maxMessagesPerConversation {
                updatedMessages = Array(updatedMessages.prefix(maxMessagesPerConversation))
            }
        }
        
        // Crear nuevo caché actualizado
        let updatedCache = ConversationMessageCache(
            conversationId: conversationId,
            messages: updatedMessages
        )
        
        // Guardar
        do {
            let data = try JSONEncoder().encode(updatedCache)
            let fileURL = getCacheFileURL(for: conversationId)
            try data.write(to: fileURL)
            
            print("📝 Mensaje agregado al caché para: \(conversationId)")
        } catch {
            print("❌ Error agregando mensaje al caché: \(error)")
        }
    }
    
    func loadConversationCache(conversationId: String) -> ConversationMessageCache? {
        let fileURL = getCacheFileURL(for: conversationId)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cache = try JSONDecoder().decode(ConversationMessageCache.self, from: data)
            return cache
        } catch {
            print("❌ Error cargando caché para \(conversationId): \(error)")
            return nil
        }
    }
    
    func getCacheFileURL(for conversationId: String) -> URL {
        let fileName = "\(conversationId).json"
        return cacheDirectory!.appendingPathComponent(fileName)
    }
    
    func performCacheMaintenance() {
        print("🧹 Iniciando mantenimiento de caché...")
        
        // Verificar tamaño total
        let totalSize = calculateTotalCacheSize()
        
        if totalSize > maxCacheSizeBytes {
            print("⚠️ Caché excede el tamaño máximo (\(totalSize) bytes), limpiando...")
            cleanupOldestConversations()
        }
        
        // Limpiar conversaciones no accedidas en 30 días
        cleanupOldConversations()
        
        updateCacheStats()
        print("✅ Mantenimiento de caché completado")
    }
    
    func calculateTotalCacheSize() -> Int64 {
        guard let cacheDir = cacheDirectory else { return 0 }
        
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(attributes.fileSize ?? 0)
            }
        } catch {
            print("❌ Error calculando tamaño de caché: \(error)")
        }
        
        return totalSize
    }
    
    func updateCacheStats() {
        Task { @MainActor in
            cacheStats.totalSizeBytes = calculateTotalCacheSize()
            cacheStats.lastUpdated = Date()
            // Actualizar otros stats...
        }
    }
}
```

## 3. Integración con GetStreamChatProvider

### 3.1 Método con Caché
```swift
// Modificar GetStreamChatProvider.swift

extension GetStreamChatProvider {
    
    /// Obtiene mensajes con estrategia cache-first
    func getMessagesWithCache(for conversationId: String, limit: Int = 50, before messageId: String? = nil) async throws -> [ChatMessage] {
        
        // 1. Cargar desde caché primero
        let cachedMessages = MessageCacheManager.shared.getCachedMessages(for: conversationId)
        
        // 2. Si hay caché, devolverlo inmediatamente y cargar frescos en background
        if !cachedMessages.isEmpty {
            print("📦 Devolviendo \(cachedMessages.count) mensajes desde caché para: \(conversationId)")
            
            // Cargar mensajes frescos en background
            Task {
                do {
                    let freshMessages = try await self.getMessages(for: conversationId, limit: limit, before: messageId)
                    
                    // Solo actualizar caché si hay diferencias
                    if !messagesAreEqual(cachedMessages, freshMessages) {
                        MessageCacheManager.shared.saveMessages(freshMessages, for: conversationId)
                        
                        // Notificar que hay nuevos mensajes
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .messagesUpdatedFromServer,
                                object: nil,
                                userInfo: [
                                    "conversationId": conversationId,
                                    "messages": freshMessages
                                ]
                            )
                        }
                    }
                } catch {
                    print("❌ Error cargando mensajes frescos en background: \(error)")
                }
            }
            
            return cachedMessages
        }
        
        // 3. Si no hay caché, cargar de GetStream normalmente
        print("🔄 No hay caché, cargando desde GetStream para: \(conversationId)")
        let messages = try await getMessages(for: conversationId, limit: limit, before: messageId)
        
        // Guardar en caché
        MessageCacheManager.shared.saveMessages(messages, for: conversationId)
        
        return messages
    }
    
    /// Envía mensaje y lo agrega al caché optimistamente
    override func sendMessage(_ message: ChatMessage, to conversationId: String) async throws -> String {
        
        // 1. Agregar mensaje al caché optimistamente
        var optimisticMessage = message
        optimisticMessage.syncStatus = .sending
        MessageCacheManager.shared.addMessage(optimisticMessage, to: conversationId)
        
        // 2. Notificar UI inmediatamente
        await MainActor.run {
            let update = MessageUpdate(type: .new, message: optimisticMessage, conversationId: conversationId)
            self._messageUpdates.send(update)
        }
        
        do {
            // 3. Enviar a GetStream
            let messageId = try await super.sendMessage(message, to: conversationId)
            
            // 4. Actualizar mensaje como enviado exitosamente
            var sentMessage = message
            sentMessage.syncStatus = .synced
            MessageCacheManager.shared.addMessage(sentMessage, to: conversationId)
            
            return messageId
            
        } catch {
            // 5. Marcar mensaje como fallido
            var failedMessage = message
            failedMessage.syncStatus = .failed
            MessageCacheManager.shared.addMessage(failedMessage, to: conversationId)
            
            throw error
        }
    }
    
    private func messagesAreEqual(_ messages1: [ChatMessage], _ messages2: [ChatMessage]) -> Bool {
        guard messages1.count == messages2.count else { return false }
        
        for i in 0..<messages1.count {
            if messages1[i].id != messages2[i].id || 
               messages1[i].text != messages2[i].text ||
               messages1[i].timestamp != messages2[i].timestamp {
                return false
            }
        }
        
        return true
    }
}

// Notificación para actualizaciones desde servidor
extension Notification.Name {
    static let messagesUpdatedFromServer = Notification.Name("messagesUpdatedFromServer")
}
```

## 4. Actualización de OptimizedChatView

### 4.1 Carga con Caché
```swift
// Modificar OptimizedChatView.swift

extension OptimizedChatView {
    
    private func loadMessages() {
        print("📱 Cargando mensajes para conversación: \(conversationId)")
        
        // 1. Cargar desde caché inmediatamente (sin loading state)
        let cachedMessages = MessageCacheManager.shared.getCachedMessages(for: conversationId)
        
        if !cachedMessages.isEmpty {
            self.messages = cachedMessages
            print("📦 Mostrando \(cachedMessages.count) mensajes desde caché")
        }
        
        // 2. Cargar mensajes frescos
        isLoading = true
        Task {
            do {
                // Usar el nuevo método con caché
                if let streamProvider = chatProviderManager.currentProvider as? GetStreamChatProvider {
                    let freshMessages = try await streamProvider.getMessagesWithCache(for: conversationId)
                    
                    await MainActor.run {
                        // Solo actualizar si hay diferencias o si no había caché
                        if cachedMessages.isEmpty || freshMessages != self.messages {
                            self.messages = freshMessages
                            print("🔄 Mensajes actualizados desde servidor: \(freshMessages.count)")
                        }
                        self.isLoading = false
                    }
                } else {
                    // Fallback al método original
                    let loadedMessages = try await chatProviderManager.getMessages(for: conversationId)
                    await MainActor.run {
                        self.messages = loadedMessages
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        
        let optimisticMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            text: text,
            authorId: "current_user", // TODO: Get actual user ID
            authorName: "Current User", // TODO: Get actual user name
            timestamp: Date(),
            isFromCurrentUser: true,
            syncStatus: .sending // Marcar como enviando
        )
        
        // Agregar inmediatamente a la UI
        messages.insert(optimisticMessage, at: 0)
        
        Task {
            do {
                let _ = try await chatProviderManager.sendMessage(optimisticMessage, to: conversationId)
                // El mensaje se actualizará automáticamente através del caché
            } catch {
                await MainActor.run {
                    // Marcar mensaje como fallido en UI
                    if let index = self.messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                        var failedMessage = optimisticMessage
                        failedMessage.syncStatus = .failed
                        self.messages[index] = failedMessage
                    }
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func setupMessageUpdateListener() {
        // Listener existente para actualizaciones en tiempo real
        messageUpdateObserver = NotificationCenter.default.addObserver(
            forName: .chatMessageUpdate,
            object: nil,
            queue: .main
        ) { [self] notification in
            // Handle real-time updates...
        }
        
        // Nuevo listener para actualizaciones desde servidor
        serverUpdateObserver = NotificationCenter.default.addObserver(
            forName: .messagesUpdatedFromServer,
            object: nil,
            queue: .main
        ) { [self] notification in
            guard let conversationId = notification.userInfo?["conversationId"] as? String,
                  conversationId == self.conversationId,
                  let freshMessages = notification.userInfo?["messages"] as? [ChatMessage] else { return }
            
            print("🔄 Actualizando mensajes desde servidor en background")
            self.messages = freshMessages
        }
    }
}
```

## 5. Gestión Automática del Caché

### 5.1 Limpieza y Mantenimiento
```swift
// En AppDelegate o App.swift

extension App {
    private func setupCacheManagement() {
        // Limpieza automática cada 24 horas
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            MessageCacheManager.shared.performMaintenance()
        }
        
        // Limpieza al entrar en background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            MessageCacheManager.shared.performMaintenance()
        }
    }
}
```

## 6. Configuración y Monitoreo

### 6.1 Settings View Integration
```swift
// Agregar a SettingsView.swift

struct CacheSettingsView: View {
    @StateObject private var cacheManager = MessageCacheManager.shared
    
    var body: some View {
        Section("Cache de Mensajes") {
            HStack {
                Text("Conversaciones cacheadas")
                Spacer()
                Text("\(cacheManager.cacheStats.totalConversations)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Mensajes totales")
                Spacer()
                Text("\(cacheManager.cacheStats.totalMessages)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Tamaño del caché")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: cacheManager.cacheStats.totalSizeBytes, countStyle: .file))
                    .foregroundColor(.secondary)
            }
            
            Button("Limpiar caché de mensajes") {
                cacheManager.clearAllCache()
            }
            .foregroundColor(.red)
        }
    }
}
```

## Beneficios de Esta Implementación

### Performance
- **Carga instantánea**: Mensajes visibles inmediatamente desde caché
- **Menos uso de red**: Solo cargar mensajes nuevos cuando sea necesario
- **Mejor responsividad**: UI no bloquea esperando red

### Experiencia de Usuario
- **Offline básico**: Ver mensajes anteriores sin conexión
- **Envío optimista**: Mensajes aparecen inmediatamente al enviar
- **Sincronización invisible**: Actualizaciones en background

### Robustez
- **Manejo de errores**: Caché corrupto se limpia automáticamente
- **Límites inteligentes**: Gestión automática de espacio
- **Migración**: Versionado para futuras actualizaciones

## Archivos a Crear/Modificar

1. **Nuevos archivos**:
   - `Gym_API/Models/MessageCacheModels.swift`
   - `Gym_API/Services/MessageCacheManager.swift`
   - `MessageCacheImplementation.md` (este archivo)

2. **Archivos a modificar**:
   - `Gym_API/Services/ChatProvider/GetStreamChatProvider.swift`
   - `Gym_API/Views/Chat/OptimizedChatView.swift`
   - `Gym_API/Views/Settings/SettingsView.swift` (opcional)

3. **Testing**:
   - Tests unitarios para MessageCacheManager
   - Tests de integración con GetStreamChatProvider
   - Tests de performance con large datasets

Esta implementación proporciona una base sólida para el caché de mensajes con la flexibilidad para expandir funcionalidades futuras.