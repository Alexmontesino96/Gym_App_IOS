//
//  UnreadCountService.swift
//  Gym_API
//
//  Created by Claude on 3/12/2025.
//

import Foundation
import Combine

/// Servicio centralizado para gestionar conteos de mensajes no leídos en toda la app
/// Proporciona un único punto de verdad para badges y notificaciones de chat
@MainActor
class UnreadCountService: ObservableObject {
    // MARK: - Singleton
    static let shared = UnreadCountService()

    // MARK: - Published Properties

    /// Contador total de mensajes no leídos en todos los canales
    @Published var totalUnreadCount: Int = 0

    /// Contador de mensajes no leídos por canal (channelId -> count)
    @Published var unreadCountPerChannel: [String: Int] = [:]

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var isLoading = false
    private var lastLoadTimestamp: Date?
    private let throttleInterval: TimeInterval = 5.0 // Mínimo 5 segundos entre cargas

    // MARK: - Initialization
    private init() {
        print("📊 UnreadCountService inicializado")
        setupObservers()
    }

    deinit {
        print("🗑️ UnreadCountService deinitialized")
    }

    // MARK: - Configuration

    /// Configura el servicio y carga conteos iniciales
    /// No requiere parámetros ya que usa ChatProviderManager.shared directamente
    func configure() {
        print("⚙️ Configurando UnreadCountService")

        // Cargar conteos iniciales
        Task {
            await loadUnreadCounts()
        }
    }

    // MARK: - Setup Observers

    private func setupObservers() {
        // Observar cuando se actualizan las salas de chat
        // IMPORTANTE: Usamos debounce para evitar rate limiting
        NotificationCenter.default.publisher(for: .chatRoomUpdated)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] notification in
                print("📬 Notificación de chat room actualizada recibida (debounced)")
                Task { @MainActor in
                    await self?.loadUnreadCountsThrottled()
                }
            }
            .store(in: &cancellables)

        // Observar cuando se recibe un nuevo mensaje
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let channelId = notification.userInfo?["channelId"] as? String {
                    print("📨 Nuevo mensaje recibido en canal: \(channelId)")
                    Task { @MainActor in
                        await self?.incrementUnreadCount(for: channelId)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Unread Counts

    /// Carga conteos con throttling para evitar rate limiting
    private func loadUnreadCountsThrottled() async {
        // Verificar si ya estamos cargando
        if isLoading {
            print("⏸️ Ya hay una carga en progreso, ignorando solicitud")
            return
        }

        // Verificar throttle interval
        if let lastLoad = lastLoadTimestamp {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoad)
            if timeSinceLastLoad < throttleInterval {
                print("⏸️ Throttle activo: esperando \(Int(throttleInterval - timeSinceLastLoad))s más")
                return
            }
        }

        await loadUnreadCounts()
    }

    /// Carga todos los conteos de mensajes no leídos desde el proveedor de chat
    func loadUnreadCounts() async {
        guard let provider = ChatProviderManager.shared.currentProvider else {
            print("⚠️ ChatProvider no disponible, no se pueden cargar conteos")
            return
        }

        // Marcar como cargando
        isLoading = true
        defer { isLoading = false }

        print("🔄 Cargando conteos de mensajes no leídos...")

        do {
            // Obtener todas las conversaciones del usuario
            let conversations = try await provider.getConversations()

            var total = 0
            var channelCounts: [String: Int] = [:]

            // Procesar cada conversación
            for conversation in conversations {
                let unreadCount = conversation.unreadCount
                total += unreadCount
                channelCounts[conversation.id] = unreadCount

                if unreadCount > 0 {
                    let displayName = conversation.name ?? "Chat \(conversation.id.prefix(8))"
                    print("  📊 Canal '\(displayName)': \(unreadCount) no leídos")
                }
            }

            // Actualizar en el Main Thread
            await MainActor.run {
                self.totalUnreadCount = total
                self.unreadCountPerChannel = channelCounts
                self.lastLoadTimestamp = Date()

                print("✅ Conteos actualizados: \(total) mensajes no leídos en total")
            }
        } catch {
            print("❌ Error al cargar conteos de mensajes no leídos: \(error)")
        }
    }

    // MARK: - Increment Unread Count

    /// Incrementa el contador de mensajes no leídos para un canal específico
    private func incrementUnreadCount(for channelId: String) async {
        await MainActor.run {
            let currentCount = unreadCountPerChannel[channelId] ?? 0
            let newCount = currentCount + 1

            unreadCountPerChannel[channelId] = newCount
            totalUnreadCount += 1

            print("📈 Incrementado unread count para \(channelId): \(currentCount) -> \(newCount)")
            print("📊 Total unread count: \(totalUnreadCount)")
        }
    }

    // MARK: - Mark as Read

    /// Marca un canal como leído (resetea su contador a 0)
    func markChannelAsRead(_ channelId: String) async {
        await MainActor.run {
            if let count = unreadCountPerChannel[channelId], count > 0 {
                totalUnreadCount -= count
                unreadCountPerChannel[channelId] = 0

                print("✅ Canal \(channelId) marcado como leído (liberados \(count) mensajes)")
                print("📊 Total unread count actualizado: \(totalUnreadCount)")
            }
        }
    }

    // MARK: - Clear

    /// Limpia todos los contadores (usado al cerrar sesión)
    func clearAll() {
        print("🧹 Limpiando todos los contadores de mensajes no leídos")
        totalUnreadCount = 0
        unreadCountPerChannel = [:]
    }

    // MARK: - Debug Info

    /// Imprime información de debug sobre el estado actual
    func printDebugInfo() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 UnreadCountService Debug Info")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total unread: \(totalUnreadCount)")
        print("Channels with unread messages:")
        for (channelId, count) in unreadCountPerChannel where count > 0 {
            print("  - \(channelId): \(count)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    /// Notificación cuando se actualiza una sala de chat
    static let chatRoomUpdated = Notification.Name("chatRoomUpdated")

    /// Notificación cuando se recibe un nuevo mensaje
    static let newMessageReceived = Notification.Name("newMessageReceived")
}
