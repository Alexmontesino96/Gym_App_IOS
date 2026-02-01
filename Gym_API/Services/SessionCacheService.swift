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
    private let attendanceService: AttendanceService
    private let httpClient = HTTPClient.shared

    // MARK: - Initialization

    private init() {
        // Configurar límites del caché
        cache.countLimit = 50  // Máximo 50 sesiones en caché
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB máximo

        // Inicializar servicio de attendance
        self.attendanceService = AttendanceService(
            authService: ServiceContainer.shared.authService,
            classService: ServiceContainer.shared.classService
        )

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
        // 1. Verificar caché
        if let cached = cache.object(forKey: NSNumber(value: sessionId)) {
            Logger.shared.debug("✅ Session \(sessionId) loaded from cache", category: .cache)
            return cached.attendedClass
        }

        // 2. Verificar si ya hay una tarea de carga en progreso para evitar duplicados
        if let existingTask = loadingTasks[sessionId] {
            Logger.shared.debug("⏳ Waiting for existing load task for session \(sessionId)", category: .cache)
            do {
                return try await existingTask.value
            } catch {
                Logger.shared.error("Error in existing task for session \(sessionId): \(error)", category: .cache)
                return nil
            }
        }

        // 3. Crear nueva tarea de carga
        let loadTask = Task<AttendedClass?, Error> { [weak self] in
            guard let self = self else { return nil }

            do {
                // Intentar obtener desde el historial reciente primero (más eficiente)
                let recentClasses = try await self.attendanceService.getRecentAttendedClasses()

                if let session = recentClasses.first(where: { $0.id == sessionId }) {
                    // Guardar en caché
                    self.cache.setObject(AttendedClassWrapper(session), forKey: NSNumber(value: sessionId))

                    Logger.shared.info("✅ Session \(sessionId) fetched and cached", category: .cache)

                    // Limpiar tarea de carga
                    self.loadingTasks.removeValue(forKey: sessionId)

                    return session
                }

                // Si no está en el historial reciente, intentar cargar individualmente
                // (esto requeriría un endpoint específico que actualmente no existe)
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

        return AttendedClass(
            id: id,
            classId: 100 + id,
            className: "Clase de Entrenamiento",
            instructor: "Coach",
            startTime: startTime,
            endTime: endTime,
            checkinTime: startTime,
            checkoutTime: endTime
        )
    }
}

// MARK: - SessionPillContainer

/// Container view que carga y muestra una sesión etiquetada
struct SessionPillContainer: View {
    @StateObject private var cacheService = SessionCacheService.shared
    @EnvironmentObject var themeManager: ThemeManager

    let sessionTag: PostTag
    @State private var session: AttendedClass?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                // Placeholder mientras carga
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cargando sesión...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.1))
                )
                .sessionShimmering()
            } else if let session = session {
                // Mostrar el pill con la sesión cargada
                SessionPill(session: session)
                    .environmentObject(themeManager)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .task {
            await loadSession()
        }
    }

    private func loadSession() async {
        isLoading = true

        // Obtener la sesión del caché o API
        if let loadedSession = await cacheService.getSession(id: sessionTag.tagId) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.session = loadedSession
                self.isLoading = false
            }
        } else {
            // Si no se puede cargar, ocultar el componente
            withAnimation {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func sessionShimmering() -> some View {
        self.modifier(SessionShimmerModifier())
    }
}

struct SessionShimmerModifier: ViewModifier {
    @State private var phase = 0.0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 200 - 100)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}