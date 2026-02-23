//
//  EventCacheService.swift
//  Gym_API
//
//  Servicio de caché para eventos etiquetados en posts
//

import Foundation
import Combine
import SwiftUI

// MARK: - Cache Wrapper

/// Wrapper class para poder usar Event con NSCache
private class EventWrapper {
    let event: Event

    init(_ event: Event) {
        self.event = event
    }
}

/// Servicio para gestionar el caché de eventos etiquetados
@MainActor
class EventCacheService: ObservableObject {
    static let shared = EventCacheService()

    // MARK: - Properties

    private var cache = NSCache<NSNumber, EventWrapper>()
    private var loadingTasks: [Int: Task<Event?, Error>] = [:]
    private let httpClient = HTTPClient.shared

    // MARK: - Initialization

    private init() {
        // Configurar límites del caché
        cache.countLimit = 50  // Máximo 50 eventos en caché
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB máximo

        Logger.shared.info("🎫 EventCacheService initialized", category: .cache)
    }

    deinit {
        #if DEBUG
        print("🗑️ EventCacheService deinitialized")
        #endif
    }

    // MARK: - Public Methods

    /// Obtiene un evento por su ID, usando caché si está disponible
    /// - Parameter eventId: ID del evento a obtener
    /// - Returns: Event si se encuentra, nil si no existe
    func getEvent(id eventId: Int) async -> Event? {
        print("🔍 [EventCacheService] Getting event with ID: \(eventId)")

        // 1. Verificar caché
        if let cached = cache.object(forKey: NSNumber(value: eventId)) {
            print("✅ [EventCacheService] Event \(eventId) found in cache: \(cached.event.title)")
            Logger.shared.debug("✅ Event \(eventId) loaded from cache", category: .cache)
            return cached.event
        }

        print("🌐 [EventCacheService] Event \(eventId) not in cache, checking for existing task...")

        // 2. Verificar si ya hay una tarea de carga en progreso para evitar duplicados
        if let existingTask = loadingTasks[eventId] {
            print("⏳ [EventCacheService] Waiting for existing load task for event \(eventId)")
            Logger.shared.debug("⏳ Waiting for existing load task for event \(eventId)", category: .cache)
            do {
                return try await existingTask.value
            } catch {
                print("❌ [EventCacheService] Error in existing task for event \(eventId): \(error)")
                Logger.shared.error("Error in existing task for event \(eventId): \(error)", category: .cache)
                return nil
            }
        }

        // 3. Crear nueva tarea de carga
        print("🚀 [EventCacheService] Creating new load task for event \(eventId)")
        let loadTask = Task<Event?, Error> { [weak self] in
            guard let self = self else { return nil }

            do {
                // Obtener evento desde la API
                print("📥 [EventCacheService] Fetching event \(eventId) from API...")
                let event = try await self.fetchEventFromAPI(id: eventId)

                if let event = event {
                    // Guardar en caché
                    self.cache.setObject(EventWrapper(event), forKey: NSNumber(value: eventId))

                    print("✅ [EventCacheService] Event \(eventId) fetched and cached: \(event.title)")
                    Logger.shared.info("✅ Event \(eventId) fetched and cached", category: .cache)
                } else {
                    print("⚠️ [EventCacheService] Event \(eventId) not found in API")
                    Logger.shared.warning("⚠️ Event \(eventId) not found in API", category: .cache)
                }

                // Limpiar tarea de carga
                self.loadingTasks.removeValue(forKey: eventId)

                return event

            } catch {
                Logger.shared.error("❌ Error fetching event \(eventId): \(error)", category: .cache)

                // Limpiar tarea de carga
                self.loadingTasks.removeValue(forKey: eventId)

                return nil
            }
        }

        // Guardar referencia a la tarea
        loadingTasks[eventId] = loadTask

        // Esperar resultado
        do {
            return try await loadTask.value
        } catch {
            Logger.shared.error("Failed to load event \(eventId): \(error)", category: .cache)
            return nil
        }
    }

    /// Precarga un batch de eventos para optimizar el rendimiento del feed
    /// - Parameter eventIds: Array de IDs de evento para precargar
    func preloadEvents(ids eventIds: [Int]) async {
        // Filtrar solo los eventos que no están en caché
        let missingIds = eventIds.filter { eventId in
            cache.object(forKey: NSNumber(value: eventId)) == nil
        }

        guard !missingIds.isEmpty else {
            Logger.shared.debug("All events already cached", category: .cache)
            return
        }

        Logger.shared.info("📦 Preloading \(missingIds.count) events", category: .cache)

        // Cargar en paralelo con TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for eventId in missingIds {
                group.addTask { [weak self] in
                    _ = await self?.getEvent(id: eventId)
                }
            }
        }

        Logger.shared.info("✅ Event preloading complete", category: .cache)
    }

    /// Precarga eventos desde una lista de posts
    /// - Parameter posts: Array de posts que pueden contener eventos etiquetados
    func preloadEventsFromPosts(_ posts: [Post]) async {
        let eventIds = posts.compactMap { post in
            post.tags.first(where: { $0.tagType == .event })?.tagId
        }

        if !eventIds.isEmpty {
            await preloadEvents(ids: eventIds)
        }
    }

    /// Limpia todo el caché
    func clearCache() {
        cache.removeAllObjects()
        loadingTasks.removeAll()
        Logger.shared.info("🧹 Event cache cleared", category: .cache)
    }

    /// Invalida un evento específico en el caché
    /// - Parameter eventId: ID del evento a invalidar
    func invalidateEvent(id eventId: Int) {
        cache.removeObject(forKey: NSNumber(value: eventId))
        loadingTasks.removeValue(forKey: eventId)
        Logger.shared.info("🗑️ Event \(eventId) removed from cache", category: .cache)
    }

    // MARK: - Private Methods

    /// Obtiene un evento desde la API
    private func fetchEventFromAPI(id eventId: Int) async throws -> Event? {
        // Construir URL para GET /events/{event_id}
        let urlString = "\(apiBaseURL)/events/\(eventId)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        // Usar HTTPClient para crear request autenticada
        guard let request = await httpClient.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
            Logger.shared.error("EventCacheService: Failed to create authenticated request", category: .cache)
            return nil
        }

        // Ejecutar request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Verificar respuesta HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }

        // 404 = evento no encontrado
        if httpResponse.statusCode == 404 {
            return nil
        }

        // Verificar status exitoso
        guard httpResponse.statusCode == 200 else {
            Logger.shared.error("API error for event \(eventId): status \(httpResponse.statusCode)", category: .cache)
            return nil
        }

        // Decodificar respuesta
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Intentar múltiples formatos ISO8601
            let formatter1 = ISO8601DateFormatter()
            formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]

            if let date = formatter1.date(from: string) ?? formatter2.date(from: string) {
                return date
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date format: \(string)")
            )
        }

        // La API retorna EventDetail, convertir a Event
        do {
            let eventDetail = try decoder.decode(EventDetail.self, from: data)

            return Event(
                id: eventDetail.id,
                title: eventDetail.title,
                description: eventDetail.description,
                startTime: eventDetail.startTime,
                endTime: eventDetail.endTime,
                location: eventDetail.location,
                maxParticipants: eventDetail.maxParticipants,
                status: eventDetail.status,
                creatorId: eventDetail.creatorId,
                createdAt: eventDetail.createdAt,
                updatedAt: eventDetail.updatedAt,
                participantsCount: eventDetail.participantsCount,
                isPaid: eventDetail.isPaid,
                priceCents: eventDetail.priceCents,
                currency: eventDetail.currency,
                refundPolicy: eventDetail.refundPolicy,
                refundDeadlineHours: eventDetail.refundDeadlineHours,
                partialRefundPercentage: eventDetail.partialRefundPercentage,
                stripeProductId: eventDetail.stripeProductId,
                stripePriceId: eventDetail.stripePriceId
            )
        } catch {
            Logger.shared.error("Failed to decode event \(eventId): \(error)", category: .cache)
            throw error
        }
    }
}
