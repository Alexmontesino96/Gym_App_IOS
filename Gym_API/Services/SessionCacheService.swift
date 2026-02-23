//
//  SessionCacheService.swift
//  Gym_API
//
//  Servicio de caché para sesiones etiquetadas en posts
//

import Foundation
import Combine
import SwiftUI

// MARK: - Cache Wrapper

/// Wrapper class para poder usar AttendedClass con NSCache
private class AttendedClassWrapper {
    let attendedClass: AttendedClass

    init(_ attendedClass: AttendedClass) {
        self.attendedClass = attendedClass
    }
}

/// Servicio para gestionar el caché de sesiones etiquetadas
@MainActor
class SessionCacheService: ObservableObject {
    static let shared = SessionCacheService()

    // MARK: - Properties

    private var cache = NSCache<NSNumber, AttendedClassWrapper>()
    private var loadingTasks: [Int: Task<AttendedClass?, Error>] = [:]
    private var _attendanceService: AttendanceService?
    private let httpClient = HTTPClient.shared

    // Lazy access to attendance service to avoid initialization issues
    private var attendanceService: AttendanceService {
        if _attendanceService == nil {
            // Get authService from ServiceContainer
            let authService = ServiceContainer.shared.authService

            // ClassService.shared is optional, so we need to handle it
            if let classService = ClassService.shared {
                _attendanceService = AttendanceService(
                    authService: authService,  // ✅ Pass authService
                    classService: classService
                )
            } else {
                // Create a new ClassService instance if shared is not available
                let classService = ClassService(authService: authService)
                _attendanceService = AttendanceService(
                    authService: authService,  // ✅ Pass authService
                    classService: classService
                )
            }
        }
        return _attendanceService!
    }

    // MARK: - Initialization

    private init() {
        // Configurar límites del caché
        cache.countLimit = 50  // Máximo 50 sesiones en caché
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB máximo

        Logger.shared.info("🎯 SessionCacheService initialized", category: .cache)
    }

    deinit {
        #if DEBUG
        print("🗑️ SessionCacheService deinitialized")
        #endif
    }

    // MARK: - Public Methods

    /// Obtiene una sesión por su ID, usando caché si está disponible
    /// - Parameter sessionId: ID de la sesión a obtener
    /// - Returns: AttendedClass si se encuentra, nil si no existe
    func getSession(id sessionId: Int) async -> AttendedClass? {
        print("🔍 [SessionCacheService] Getting session with ID: \(sessionId)")

        // 1. Verificar caché
        if let cached = cache.object(forKey: NSNumber(value: sessionId)) {
            print("✅ [SessionCacheService] Session \(sessionId) found in cache: \(cached.attendedClass.className)")
            Logger.shared.debug("✅ Session \(sessionId) loaded from cache", category: .cache)
            return cached.attendedClass
        }

        print("🌐 [SessionCacheService] Session \(sessionId) not in cache, checking for existing task...")

        // 2. Verificar si ya hay una tarea de carga en progreso para evitar duplicados
        if let existingTask = loadingTasks[sessionId] {
            print("⏳ [SessionCacheService] Waiting for existing load task for session \(sessionId)")
            Logger.shared.debug("⏳ Waiting for existing load task for session \(sessionId)", category: .cache)
            do {
                return try await existingTask.value
            } catch {
                print("❌ [SessionCacheService] Error in existing task for session \(sessionId): \(error)")
                Logger.shared.error("Error in existing task for session \(sessionId): \(error)", category: .cache)
                return nil
            }
        }

        // 3. Crear nueva tarea de carga
        print("🚀 [SessionCacheService] Creating new load task for session \(sessionId)")
        let loadTask = Task<AttendedClass?, Error> { [weak self] in
            guard let self = self else { return nil }

            do {
                // Intentar obtener desde el historial reciente primero (más eficiente)
                print("📥 [SessionCacheService] Fetching recent attended classes from API...")
                let recentClasses = try await self.attendanceService.getRecentAttendedClasses()
                print("📊 [SessionCacheService] Fetched \(recentClasses.count) recent classes")

                if let session = recentClasses.first(where: { $0.id == sessionId }) {
                    // Guardar en caché
                    self.cache.setObject(AttendedClassWrapper(session), forKey: NSNumber(value: sessionId))

                    print("✅ [SessionCacheService] Found session \(sessionId) in API response: \(session.className)")
                    Logger.shared.info("✅ Session \(sessionId) fetched and cached", category: .cache)

                    // Limpiar tarea de carga
                    self.loadingTasks.removeValue(forKey: sessionId)

                    return session
                }

                // Si no está en el historial reciente, intentar cargar individualmente
                // (esto requeriría un endpoint específico que actualmente no existe)
                print("❌ [SessionCacheService] Session \(sessionId) NOT FOUND in recent history")
                Logger.shared.warning("⚠️ Session \(sessionId) not found in recent history", category: .cache)

                // Por ahora, crear una sesión mock si no se encuentra
                // TODO: Implementar endpoint GET /attended-classes/{id} cuando esté disponible
                let mockSession = createMockSession(id: sessionId)

                // Guardar en caché incluso el mock para evitar múltiples intentos
                self.cache.setObject(AttendedClassWrapper(mockSession), forKey: NSNumber(value: sessionId))

                // Limpiar tarea de carga
                self.loadingTasks.removeValue(forKey: sessionId)

                return mockSession

            } catch {
                Logger.shared.error("❌ Error fetching session \(sessionId): \(error)", category: .cache)

                // Limpiar tarea de carga
                self.loadingTasks.removeValue(forKey: sessionId)

                return nil
            }
        }

        // Guardar referencia a la tarea
        loadingTasks[sessionId] = loadTask

        // Esperar resultado
        do {
            return try await loadTask.value
        } catch {
            Logger.shared.error("Failed to load session \(sessionId): \(error)", category: .cache)
            return nil
        }
    }

    /// Precarga un batch de sesiones para optimizar el rendimiento del feed
    /// - Parameter sessionIds: Array de IDs de sesión para precargar
    func preloadSessions(ids sessionIds: [Int]) async {
        // Filtrar solo las sesiones que no están en caché
        let missingIds = sessionIds.filter { sessionId in
            cache.object(forKey: NSNumber(value: sessionId)) == nil
        }

        guard !missingIds.isEmpty else {
            Logger.shared.debug("All sessions already cached", category: .cache)
            return
        }

        Logger.shared.info("📦 Preloading \(missingIds.count) sessions", category: .cache)

        // Cargar en paralelo con TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for sessionId in missingIds {
                group.addTask { [weak self] in
                    _ = await self?.getSession(id: sessionId)
                }
            }
        }

        Logger.shared.info("✅ Preloading complete", category: .cache)
    }

    /// Precarga sesiones desde una lista de posts
    /// - Parameter posts: Array de posts que pueden contener sesiones etiquetadas
    func preloadSessionsFromPosts(_ posts: [Post]) async {
        let sessionIds = posts.compactMap { post in
            post.tags.first(where: { $0.tagType == .session })?.tagId
        }

        if !sessionIds.isEmpty {
            await preloadSessions(ids: sessionIds)
        }
    }

    /// Limpia todo el caché
    func clearCache() {
        cache.removeAllObjects()
        loadingTasks.removeAll()
        Logger.shared.info("🧹 Session cache cleared", category: .cache)
    }

    /// Invalida una sesión específica en el caché
    /// - Parameter sessionId: ID de la sesión a invalidar
    func invalidateSession(id sessionId: Int) {
        cache.removeObject(forKey: NSNumber(value: sessionId))
        loadingTasks.removeValue(forKey: sessionId)
        Logger.shared.info("🗑️ Session \(sessionId) removed from cache", category: .cache)
    }

    // MARK: - Private Methods

    /// Crea una sesión mock para desarrollo/testing
    /// TODO: Remover cuando tengamos endpoint real
    private func createMockSession(id: Int) -> AttendedClass {
        let now = Date()
        let startTime = now.addingTimeInterval(-3600) // Hace 1 hora
        let endTime = now

        // Usar nombres más realistas
        let classNames = ["HIIT Cardio", "Yoga Flow", "CrossFit", "Spinning", "Boxing", "Pilates"]
        let instructors = ["Carlos Joan", "Jose Paul Rodriguez", "Maria Garcia", "Ana Martinez", "Luis Fernandez", "Sofia Lopez"]

        let index = id % classNames.count

        return AttendedClass(
            id: id,
            classId: 100 + id,
            className: classNames[index],
            instructor: instructors[index],
            startTime: startTime,
            endTime: endTime,
            checkinTime: startTime,
            checkoutTime: endTime
        )
    }
}

