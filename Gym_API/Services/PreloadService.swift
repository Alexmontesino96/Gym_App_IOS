import SwiftUI
import Combine

/// Servicio de precarga inteligente que carga datos en background
/// para mejorar la percepción de velocidad de la app
@MainActor
class PreloadService: ObservableObject {
    static let shared = PreloadService()

    // MARK: - Published Properties

    @Published var isPreloadingTab: Int? = nil
    @Published var preloadedTabs: Set<Int> = []

    // MARK: - Cache

    private var lastPreloadTime: [Int: Date] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutos

    // MARK: - Initialization

    private init() {
        print("🔄 PreloadService inicializado")
    }

    // MARK: - Public Methods

    /// Precarga datos para un tab específico
    /// - Parameters:
    ///   - tab: Índice del tab a precargar
    ///   - force: Forzar recarga aunque ya esté en caché
    func preloadTab(_ tab: Int, force: Bool = false) async {
        // Verificar si necesitamos recargar
        if !force, let lastLoad = lastPreloadTime[tab] {
            let elapsed = Date().timeIntervalSince(lastLoad)
            if elapsed < cacheValidityDuration {
                print("🔄 [Preload] Tab \(tab) ya está precargado (hace \(Int(elapsed))s)")
                return
            }
        }

        print("🔄 [Preload] Iniciando precarga de tab \(tab)")
        isPreloadingTab = tab

        switch tab {
        case 0: await preloadHomeTab()
        case 1: await preloadClassesTab()
        case 2: await preloadEventsTab()
        case 3: await preloadMessagesTab()
        case 4: await preloadProfileTab()
        default:
            print("⚠️ [Preload] Tab desconocido: \(tab)")
        }

        lastPreloadTime[tab] = Date()
        preloadedTabs.insert(tab)
        isPreloadingTab = nil

        print("✅ [Preload] Tab \(tab) precargado exitosamente")
    }

    /// Precarga el siguiente tab probable basado en el tab actual
    /// - Parameter currentTab: Tab actual del usuario
    func preloadNextProbableTab(from currentTab: Int) async {
        let nextTab = predictNextTab(from: currentTab)
        await preloadTab(nextTab)
    }

    /// Precarga todos los tabs principales en orden de prioridad
    func preloadAllTabs() async {
        let priority = [0, 1, 2, 4, 3] // Home, Classes, Events, Profile, Messages

        for tab in priority {
            await preloadTab(tab)
            // Pequeño delay entre tabs para no saturar
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
    }

    /// Invalida el caché de un tab específico
    /// - Parameter tab: Tab a invalidar
    func invalidateCache(for tab: Int) {
        lastPreloadTime.removeValue(forKey: tab)
        preloadedTabs.remove(tab)
        print("🗑️ [Preload] Caché invalidado para tab \(tab)")
    }

    /// Invalida todo el caché
    func invalidateAllCache() {
        lastPreloadTime.removeAll()
        preloadedTabs.removeAll()
        print("🗑️ [Preload] Todo el caché invalidado")
    }

    // MARK: - Private Methods

    private func preloadHomeTab() async {
        print("🏠 [Preload] Precargando HomeView...")

        await withTaskGroup(of: Void.self) { group in
            // User stats
            group.addTask {
                await UserStatsService.shared.fetchComprehensiveStats()
            }

            // Surveys (comentado porque SurveyService se inyecta vía EnvironmentObject)
            // group.addTask {
            //     await SurveyService.shared.getAvailableSurveys()
            // }
        }
    }

    private func preloadClassesTab() async {
        print("💪 [Preload] Precargando ClassesView...")
        // ClassService se inyecta vía EnvironmentObject, no tiene singleton
        print("💪 [Preload] ClassService requiere acceso vía EnvironmentObject")
    }

    private func preloadEventsTab() async {
        print("📅 [Preload] Precargando EventsView...")
        // EventService se inyecta vía EnvironmentObject, no tiene singleton
        print("📅 [Preload] EventService requiere acceso vía EnvironmentObject")
    }

    private func preloadMessagesTab() async {
        print("💬 [Preload] Precargando MessagesView...")

        // Las conversaciones se cargan bajo demanda
        // Aquí podrías precargar la lista de conversaciones
        print("💬 [Preload] Messages tab no requiere precarga")
    }

    private func preloadProfileTab() async {
        print("👤 [Preload] Precargando ProfileView...")

        let userStatsService = UserStatsService.shared
        let profileService = UserProfileService.shared

        await withTaskGroup(of: Void.self) { group in
            // User profile
            group.addTask {
                await profileService.fetchUserProfileIfStale()
            }

            // User stats
            group.addTask {
                await userStatsService.fetchComprehensiveStats()
            }

            // Workout history
            group.addTask {
                await userStatsService.fetchWorkoutHistory()
            }
        }
    }

    /// Predice el siguiente tab probable basado en patrones de uso
    /// - Parameter currentTab: Tab actual
    /// - Returns: Índice del tab probable
    private func predictNextTab(from currentTab: Int) -> Int {
        // Patrones de navegación comunes:
        // Home (0) -> Classes (1) o Events (2)
        // Classes (1) -> Profile (4)
        // Events (2) -> Classes (1)
        // Messages (3) -> Home (0)
        // Profile (4) -> Home (0)

        switch currentTab {
        case 0: return 1 // Home -> Classes (más común)
        case 1: return 4 // Classes -> Profile (ver progreso)
        case 2: return 1 // Events -> Classes
        case 3: return 0 // Messages -> Home
        case 4: return 0 // Profile -> Home
        default: return 0
        }
    }

    // MARK: - Cache Management

    /// Obtiene el estado del caché para un tab
    /// - Parameter tab: Tab a verificar
    /// - Returns: True si está en caché válido
    func isCacheValid(for tab: Int) -> Bool {
        guard let lastLoad = lastPreloadTime[tab] else { return false }
        let elapsed = Date().timeIntervalSince(lastLoad)
        return elapsed < cacheValidityDuration
    }

    /// Obtiene el tiempo desde la última precarga
    /// - Parameter tab: Tab a verificar
    /// - Returns: Segundos desde la última precarga, nil si nunca se precargó
    func timeSinceLastPreload(for tab: Int) -> TimeInterval? {
        guard let lastLoad = lastPreloadTime[tab] else { return nil }
        return Date().timeIntervalSince(lastLoad)
    }
}

// MARK: - PreloadService Extension for SwiftUI

extension View {
    /// Agrega precarga inteligente al cambiar de tab
    /// - Parameter currentTab: Binding del tab actual
    func intelligentPreload(currentTab: Binding<Int>) -> some View {
        self.onChange(of: currentTab.wrappedValue) { oldTab, newTab in
            Task {
                // Precargar el siguiente tab probable en background
                await PreloadService.shared.preloadNextProbableTab(from: newTab)
            }
        }
    }
}

