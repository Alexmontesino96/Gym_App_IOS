import Foundation
import Combine
import UIKit

// MARK: - Message Cache Manager

/// Gestor centralizado del sistema de caché de mensajes
/// Utiliza una estrategia cache-first para proporcionar experiencia instantánea
@MainActor
class MessageCacheManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MessageCacheManager()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var cacheStats = MessageCacheStats()
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var cacheDirectory: URL?
    private var metadata = MessageCacheMetadata()
    
    // MARK: - Configuration
    private let config = MessageCacheConfig.self
    
    // MARK: - Initialization
    
    private init() {
        setupCacheDirectory()
        loadCacheMetadata()
        updateCacheStats()
        
        // Configurar limpieza automática de memoria
        setupMemoryPressureHandling()
        
        print("📦 MessageCacheManager inicializado")
    }
    
    // MARK: - Public Methods
    
    /// Obtiene mensajes desde caché para una conversación (ASYNC - Background decoding)
    /// Retorna array vacío si no hay caché disponible
    /// ✅ OPTIMIZADO: JSON decoding en background thread para no bloquear UI
    func getCachedMessagesAsync(for conversationId: String) async -> [ChatMessage] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                let fileURL = self.getCacheFileURL(for: conversationId)

                guard self.fileManager.fileExists(atPath: fileURL.path) else {
                    print("📦 No hay caché para conversación: \(conversationId)")
                    continuation.resume(returning: [])
                    return
                }

                do {
                    // Lectura y decodificación en background thread
                    let data = try Data(contentsOf: fileURL)
                    let cache = try JSONDecoder().decode(ConversationMessageCache.self, from: data)
                    let messages = cache.messages.map { $0.toChatMessage() }
                    print("📦 [Background] Cargados \(messages.count) mensajes desde caché para: \(conversationId)")
                    continuation.resume(returning: messages)
                } catch {
                    print("❌ Error cargando caché para \(conversationId): \(error)")
                    // Eliminar archivo corrupto
                    try? self.fileManager.removeItem(at: fileURL)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Obtiene mensajes desde caché para una conversación (SYNC - Para compatibilidad)
    /// ⚠️ DEPRECATED: Usa getCachedMessagesAsync() para mejor performance
    /// Retorna array vacío si no hay caché disponible
    func getCachedMessages(for conversationId: String) -> [ChatMessage] {
        guard let cacheData = loadConversationCache(conversationId: conversationId) else {
            print("📦 No hay caché para conversación: \(conversationId)")
            return []
        }

        let messages = cacheData.messages.map { $0.toChatMessage() }
        print("📦 Cargados \(messages.count) mensajes desde caché para: \(conversationId)")
        return messages
    }
    
    /// Guarda mensajes en caché para una conversación
    /// Limita automáticamente a los últimos 50 mensajes
    func saveMessages(_ messages: [ChatMessage], for conversationId: String) {
        Task { @MainActor in
            await performSaveMessages(messages, for: conversationId)
        }
    }
    
    /// Agrega un mensaje individual al caché
    /// Útil para mensajes enviados optimistamente
    func addMessage(_ message: ChatMessage, to conversationId: String) {
        Task { @MainActor in
            await performAddMessage(message, to: conversationId)
        }
    }
    
    /// Actualiza un mensaje existente en el caché
    /// Útil para cambiar estado de sincronización
    func updateMessage(_ message: ChatMessage, in conversationId: String) {
        Task { @MainActor in
            await performUpdateMessage(message, in: conversationId)
        }
    }
    
    /// Elimina caché de una conversación específica
    func clearCache(for conversationId: String) {
        Task { @MainActor in
            await performClearCache(for: conversationId)
        }
    }
    
    /// Elimina todo el caché
    func clearAllCache() {
        Task { @MainActor in
            await performClearAllCache()
        }
    }
    
    /// Realiza mantenimiento del caché
    /// Limpia conversaciones antiguas y controla límites de tamaño
    func performMaintenance() {
        Task { @MainActor in
            await performCacheMaintenance()
        }
    }
    
    /// Verifica si una conversación tiene caché disponible
    func hasCachedMessages(for conversationId: String) -> Bool {
        let fileURL = getCacheFileURL(for: conversationId)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Obtiene estadísticas detalladas del caché
    func getCacheStats() -> MessageCacheStats {
        return calculateCacheStats()
    }
}

// MARK: - Private Implementation

private extension MessageCacheManager {
    
    // MARK: - Setup and Configuration
    
    func setupCacheDirectory() {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ No se pudo obtener documents directory")
            return
        }
        
        cacheDirectory = documentsDirectory.appendingPathComponent(config.cacheDirectoryName)
        
        if let cacheDir = cacheDirectory {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                print("✅ Directorio de caché configurado: \(cacheDir.path)")
            } catch {
                print("❌ Error creando directorio de caché: \(error)")
                self.errorMessage = "Error configurando caché: \(error.localizedDescription)"
            }
        }
    }
    
    func loadCacheMetadata() {
        guard let metadataURL = getMetadataFileURL() else { return }
        
        if fileManager.fileExists(atPath: metadataURL.path) {
            do {
                let data = try Data(contentsOf: metadataURL)
                metadata = try JSONDecoder().decode(MessageCacheMetadata.self, from: data)
                print("📋 Metadata de caché cargado: \(metadata.totalConversations) conversaciones")
            } catch {
                print("⚠️ Error cargando metadata, usando valores por defecto: \(error)")
                metadata = MessageCacheMetadata()
            }
        } else {
            metadata = MessageCacheMetadata()
            saveCacheMetadata()
        }
    }
    
    func saveCacheMetadata() {
        guard let metadataURL = getMetadataFileURL() else { return }
        
        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            print("❌ Error guardando metadata: \(error)")
        }
    }
    
    // MARK: - Core Cache Operations
    
    func performSaveMessages(_ messages: [ChatMessage], for conversationId: String) async {
        // Ordenar mensajes por timestamp y limitar a los más recientes
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        let limitedMessages = Array(sortedMessages.suffix(config.maxMessagesPerConversation))
        let cachedMessages = limitedMessages.map { CachedMessage(from: $0) }
        
        let cacheData = ConversationMessageCache(
            conversationId: conversationId,
            messages: cachedMessages
        )
        
        do {
            let data = try JSONEncoder().encode(cacheData)
            let fileURL = getCacheFileURL(for: conversationId)
            try await writeData(data, to: fileURL)
            print("💾 Guardados \(cachedMessages.count) mensajes en caché para: \(conversationId)")
            updateCacheStats()
        } catch {
            print("❌ Error guardando mensajes en caché: \(error)")
            self.errorMessage = "Error guardando caché: \(error.localizedDescription)"
        }
    }
    
    func performAddMessage(_ message: ChatMessage, to conversationId: String) async {
        // Cargar caché existente
        var existingCache = loadConversationCache(conversationId: conversationId)
        
        if existingCache == nil {
            // Si no existe caché, crear uno nuevo
            existingCache = ConversationMessageCache(
                conversationId: conversationId,
                messages: []
            )
        }
        
        guard let cache = existingCache else { return }
        
        // Agregar nuevo mensaje al principio
        var updatedMessages = cache.messages
        let newCachedMessage = CachedMessage(from: message)
        
        // Verificar si el mensaje ya existe (para evitar duplicados)
        if let existingIndex = updatedMessages.firstIndex(where: { $0.id == message.id }) {
            // Actualizar mensaje existente
            updatedMessages[existingIndex] = newCachedMessage
            print("🔄 Mensaje actualizado en caché: \(message.id)")
        } else {
            // Agregar nuevo mensaje manteniendo orden cronológico
            // Buscar la posición correcta basada en timestamp
            let insertIndex = updatedMessages.firstIndex { cachedMsg in
                cachedMsg.timestamp > newCachedMessage.timestamp
            } ?? updatedMessages.count
            
            updatedMessages.insert(newCachedMessage, at: insertIndex)
            print("➕ Nuevo mensaje agregado al caché en posición \(insertIndex): \(message.id)")
        }
        
        // Mantener límite de mensajes (eliminar los más antiguos)
        if updatedMessages.count > config.maxMessagesPerConversation {
            // Ordenar por timestamp y mantener los más recientes
            updatedMessages.sort { $0.timestamp < $1.timestamp }
            updatedMessages = Array(updatedMessages.suffix(config.maxMessagesPerConversation))
            print("✂️ Caché recortado a \(config.maxMessagesPerConversation) mensajes más recientes")
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
            try await writeData(data, to: fileURL)
            print("💾 Caché actualizado para: \(conversationId)")
            updateCacheStats()
        } catch {
            print("❌ Error agregando mensaje al caché: \(error)")
        }
    }
    
    func performUpdateMessage(_ message: ChatMessage, in conversationId: String) async {
        guard let cache = loadConversationCache(conversationId: conversationId) else {
            print("⚠️ No se encontró caché para actualizar mensaje en: \(conversationId)")
            return
        }
        
        var updatedMessages = cache.messages
        
        // Buscar y actualizar el mensaje
        if let index = updatedMessages.firstIndex(where: { $0.id == message.id }) {
            updatedMessages[index] = CachedMessage(from: message)
            
            let updatedCache = ConversationMessageCache(
                conversationId: conversationId,
                messages: updatedMessages
            )
            
            do {
                let data = try JSONEncoder().encode(updatedCache)
                let fileURL = getCacheFileURL(for: conversationId)
                try await writeData(data, to: fileURL)
                print("🔄 Mensaje actualizado en caché: \(message.id)")
            } catch {
                print("❌ Error actualizando mensaje en caché: \(error)")
            }
        } else {
            print("⚠️ Mensaje no encontrado para actualizar: \(message.id)")
        }
    }
    
    func performClearCache(for conversationId: String) async {
        let fileURL = getCacheFileURL(for: conversationId)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try await removeItem(at: fileURL)
                print("🗑️ Caché eliminado para: \(conversationId)")
                updateCacheStats()
            }
        } catch {
            print("❌ Error eliminando caché para \(conversationId): \(error)")
        }
    }
    
    func performClearAllCache() async {
        guard let cacheDir = cacheDirectory else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            
            for file in files {
                try await removeItem(at: file)
            }
            
            print("🗑️ Todo el caché eliminado: \(files.count) archivos")
            
            // Resetear metadata
            metadata = MessageCacheMetadata()
            saveCacheMetadata()
            updateCacheStats()
            
        } catch {
            print("❌ Error eliminando todo el caché: \(error)")
        }
    }
    
    func performCacheMaintenance() async {
        print("🧹 Iniciando mantenimiento de caché...")
        
        // Verificar tamaño total
        let totalSize = calculateTotalCacheSize()
        let stats = calculateCacheStats()
        
        print("📊 Estadísticas actuales:")
        print("   - Conversaciones: \(stats.totalConversations)")
        print("   - Mensajes: \(stats.totalMessages)")
        print("   - Tamaño: \(stats.formattedSize)")
        
        var cleanupPerformed = false
        
        // Limpiar si excede el tamaño máximo
        if totalSize > config.maxCacheSizeBytes {
            print("⚠️ Caché excede el tamaño máximo (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))), limpiando...")
            await cleanupOldestConversations()
            cleanupPerformed = true
        }
        
        // Limpiar si excede el número máximo de conversaciones
        if stats.totalConversations > config.maxCachedConversations {
            print("⚠️ Número de conversaciones excede el máximo (\(stats.totalConversations)), limpiando...")
            await cleanupOldestConversations()
            cleanupPerformed = true
        }
        
        // Limpiar conversaciones muy antiguas
        await cleanupOldestConversations()
        cleanupPerformed = true
        
        if cleanupPerformed {
            // Actualizar metadata
            let updatedStats = calculateCacheStats()
            metadata = MessageCacheMetadata(
                lastCleanup: Date(),
                totalConversations: updatedStats.totalConversations,
                totalMessages: updatedStats.totalMessages,
                totalSizeBytes: calculateTotalCacheSize()
            )
            saveCacheMetadata()
        }
        
        updateCacheStats()
        print("✅ Mantenimiento de caché completado")
    }
    
    func cleanupOldestConversations() async {
        guard let cacheDir = cacheDirectory else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            // Filtrar archivos de conversaciones (excluir metadata)
            let conversationFiles = files.filter { !$0.lastPathComponent.contains("metadata") }
            
            // Ordenar por fecha de modificación (más antiguos primero)
            let sortedFiles = conversationFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // Calcular cuántos archivos eliminar
            let maxFiles = config.maxCachedConversations
            let filesToDelete = max(0, sortedFiles.count - maxFiles)
            
            if filesToDelete > 0 {
                print("🗑️ Eliminando \(filesToDelete) conversaciones más antiguas...")
                
                for i in 0..<filesToDelete {
                    try fileManager.removeItem(at: sortedFiles[i])
                    print("   - Eliminado: \(sortedFiles[i].lastPathComponent)")
                }
            }
            
            // También eliminar archivos muy antiguos
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -config.maxCacheAgeDays, to: Date()) ?? Date.distantPast
            
            for file in sortedFiles {
                if let modificationDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                    print("🗑️ Eliminado archivo antiguo: \(file.lastPathComponent)")
                }
            }
            
        } catch {
            print("❌ Error durante limpieza: \(error)")
        }
    }
    
    // MARK: - File Management
    
    func loadConversationCache(conversationId: String) -> ConversationMessageCache? {
        let fileURL = getCacheFileURL(for: conversationId)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            // Lectura síncrona: esta ruta se usa en UI para obtener caché inmediato
            let data = try Data(contentsOf: fileURL)
            let cache = try JSONDecoder().decode(ConversationMessageCache.self, from: data)
            return cache
        } catch {
            print("❌ Error cargando caché para \(conversationId): \(error)")
            // Eliminar archivo corrupto
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    func getCacheFileURL(for conversationId: String) -> URL {
        let fileName = MessageCacheConfig.FileName.conversation(conversationId)
        return cacheDirectory!.appendingPathComponent(fileName)
    }
    
    func getMetadataFileURL() -> URL? {
        return cacheDirectory?.appendingPathComponent(config.metadataFileName)
    }
    
    // MARK: - Memory Management
    
    /// Configura el sistema de manejo de presión de memoria
    private func setupMemoryPressureHandling() {
        // Registrar para notificaciones de memoria baja en iOS
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        print("🧠 Sistema de manejo de presión de memoria configurado")
    }
    
    /// Maneja advertencias de memoria baja del sistema
    @objc private func handleMemoryWarning() {
        print("⚠️ Advertencia de memoria baja detectada - iniciando limpieza agresiva")
        
        Task { @MainActor in
            await performAggressiveCacheCleanup()
        }
    }
    
    /// Realiza limpieza agresiva del caché para liberar memoria crítica
    private func performAggressiveCacheCleanup() async {
        print("🧹 Iniciando limpieza agresiva de caché por presión de memoria")
        
        guard let cacheDir = cacheDirectory else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            // Filtrar archivos de conversaciones
            let conversationFiles = files.filter { !$0.lastPathComponent.contains("metadata") }
            
            // Ordenar por fecha de modificación (más antiguos primero)
            let sortedFiles = conversationFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            let currentCount = sortedFiles.count
            
            // Eliminar agresivamente: mantener solo 25% de las conversaciones más recientes
            let targetCount = max(5, currentCount / 4) // Mínimo 5 conversaciones
            let filesToDelete = max(0, currentCount - targetCount)
            
            print("🗑️ Eliminando \\(filesToDelete) conversaciones (manteniendo \\(targetCount) de \\(currentCount))")
            
            for i in 0..<filesToDelete {
                try fileManager.removeItem(at: sortedFiles[i])
                print("   - Eliminado: \\(sortedFiles[i].lastPathComponent)")
            }
            
            // También recortar mensajes en las conversaciones restantes
            await reduceMessagesInRemainingConversations(files: Array(sortedFiles.suffix(targetCount)))
            
            // Actualizar metadata después de la limpieza
            let updatedStats = calculateCacheStats()
            metadata = MessageCacheMetadata(
                lastCleanup: Date(),
                totalConversations: updatedStats.totalConversations,
                totalMessages: updatedStats.totalMessages,
                totalSizeBytes: calculateTotalCacheSize()
            )
            saveCacheMetadata()
            updateCacheStats()
            
            print("✅ Limpieza agresiva completada")
            print("📊 Nueva estadística: \\(updatedStats.totalConversations) conversaciones, \\(updatedStats.formattedSize)")
            
        } catch {
            print("❌ Error durante limpieza agresiva: \\(error)")
        }
    }
    
    /// Reduce el número de mensajes en las conversaciones restantes para liberar más memoria
    private func reduceMessagesInRemainingConversations(files: [URL]) async {
        let emergencyLimit = 10 // Solo mantener 10 mensajes por conversación en emergencia
        
        for file in files {
            do {
                let data = try Data(contentsOf: file)
                let cache = try JSONDecoder().decode(ConversationMessageCache.self, from: data)
                
                if cache.messages.count > emergencyLimit {
                    // Mantener solo los mensajes más recientes
                    let sortedMessages = cache.messages.sorted { $0.timestamp < $1.timestamp }
                    let reducedMessages = Array(sortedMessages.suffix(emergencyLimit))
                    
                    let updatedCache = ConversationMessageCache(
                        conversationId: cache.conversationId,
                        messages: reducedMessages
                    )
                    
                    let updatedData = try JSONEncoder().encode(updatedCache)
                    try updatedData.write(to: file)
                    
                    print("✂️ Conversación \\(cache.conversationId): \\(cache.messages.count) → \\(emergencyLimit) mensajes")
                }
            } catch {
                print("❌ Error reduciendo mensajes en \\(file.lastPathComponent): \\(error)")
            }
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    func calculateTotalCacheSize() -> Int64 {
        guard let cacheDir = cacheDirectory else { return 0 }
        
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(attributes.fileSize ?? 0)
            }
        } catch {
            print("❌ Error calculando tamaño de caché: \(error)")
        }
        
        return totalSize
    }
    
    func calculateCacheStats() -> MessageCacheStats {
        guard let cacheDir = cacheDirectory else {
            return MessageCacheStats()
        }
        
        var stats = MessageCacheStats()
        stats.totalSizeBytes = calculateTotalCacheSize()
        stats.lastUpdated = Date()
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
            
            // Contar solo archivos de conversaciones
            let conversationFiles = files.filter { !$0.lastPathComponent.contains("metadata") }
            stats.totalConversations = conversationFiles.count
            
            // Contar mensajes totales y fechas
            var totalMessages = 0
            var oldestDate: Date?
            var newestDate: Date?
            
            for file in conversationFiles {
                if let cache = loadCacheFromFile(file) {
                    totalMessages += cache.totalMessages
                    
                    if let oldest = oldestDate {
                        oldestDate = min(oldest, cache.lastUpdated)
                    } else {
                        oldestDate = cache.lastUpdated
                    }
                    
                    if let newest = newestDate {
                        newestDate = max(newest, cache.lastUpdated)
                    } else {
                        newestDate = cache.lastUpdated
                    }
                }
            }
            
            stats.totalMessages = totalMessages
            stats.oldestCacheDate = oldestDate
            stats.newestCacheDate = newestDate
            
        } catch {
            print("❌ Error calculando estadísticas: \(error)")
        }
        
        return stats
    }
    
    func loadCacheFromFile(_ fileURL: URL) -> ConversationMessageCache? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ConversationMessageCache.self, from: data)
        } catch {
            return nil
        }
    }
    
    func updateCacheStats() {
        cacheStats = calculateCacheStats()
        print("📊 Estadísticas actualizadas: \(cacheStats.totalConversations) conversaciones, \(cacheStats.totalMessages) mensajes")
    }
    
    // MARK: - Error Handling
    
    func handleCacheError(_ error: Error, for conversationId: String?) {
        print("❌ Error de caché: \(error)")
        
        if let conversationId = conversationId {
            // Intentar limpiar caché corrupto
            Task { @MainActor in
                await performClearCache(for: conversationId)
            }
        }
        
        self.errorMessage = "Error de caché: \(error.localizedDescription)"
    }
}

// MARK: - Background IO helpers (non-blocking)
extension MessageCacheManager {
    private func writeData(_ data: Data, to url: URL) async throws {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try data.write(to: url)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    private func readData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let data = try Data(contentsOf: url)
                    cont.resume(returning: data)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    private func removeItem(at url: URL) async throws {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try FileManager.default.removeItem(at: url)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
