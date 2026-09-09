//
//  WorkspaceContextService.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import Foundation
import SwiftUI
import Combine

@MainActor
class WorkspaceContextService: ObservableObject {
    static let shared = WorkspaceContextService()

    private init() {
        print("🏢 WorkspaceContextService singleton initialized")
        loadContextFromCache()
    }

    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    weak var authService: AuthServiceProtocol?

    // MARK: - Published Properties
    @Published var context: WorkspaceContext?
    @Published var stats: WorkspaceStatsResponse?
    @Published var isLoading = false
    @Published var isLoadingStats = false
    @Published var errorMessage: String?
    @Published private(set) var isSavingEvents = false
    @Published var eventsSettingsError: String?
    private var eventsRequestVersion = UUID()
    #if DEBUG
    @Published var galleryPTEvents: PTEventsState?
    #endif

    // MARK: - Cache Properties
    private var lastContextRefresh: Date?
    private var lastStatsRefresh: Date?
    /// Gym al que pertenece el contexto en memoria. El contexto es por gimnasio, así que la
    /// caché no vale si el usuario ha cambiado de gym desde que se cargó.
    private var loadedContextGymId: Int?
    private let contextCacheExpiration: TimeInterval = 300 // 5 minutos
    private let statsCacheExpiration: TimeInterval = 300 // 5 minutos

    // MARK: - Computed Properties

    var isPersonalTrainer: Bool {
        context?.workspace.isPersonalTrainer ?? false
    }

    var ptEvents: PTEventsState? {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { return galleryPTEvents }
        #endif
        guard let gymId = GymService.shared.currentGymId,
              context?.workspace.id == gymId, context?.ptEvents?.gymId == gymId else { return nil }
        return context?.ptEvents
    }

    var showsPTEvents: Bool {
        ptEvents?.available == true && ptEvents?.enabled == true
    }

    var workspaceType: String {
        context?.workspace.type ?? "gym"
    }

    var terminology: [String: String] {
        context?.terminology ?? TerminologyHelper.defaultTerminology
    }

    var features: WorkspaceFeatures? {
        context?.features
    }

    var navigation: [NavigationItem] {
        context?.navigation ?? []
    }

    var quickActions: [QuickAction] {
        context?.quickActions ?? []
    }

    var branding: BrandingConfig? {
        context?.branding
    }

    // MARK: - Fetch Context

    /// Obtiene el contexto del workspace actual desde la API
    func fetchContext(forceRefresh: Bool = false) async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { return }
        #endif
        // Check cache
        let currentGymId = GymService.shared.currentGymId
        let requestVersion = eventsRequestVersion

        if !forceRefresh,
           let lastRefresh = lastContextRefresh,
           Date().timeIntervalSince(lastRefresh) < contextCacheExpiration,
           context != nil,
           loadedContextGymId == currentGymId {
            print("📱 Using cached workspace context")
            return
        }

        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(baseURL)/context/workspace") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        guard let request = await HTTPClient.shared.makeRequest(
            url: url, method: "GET", includeGymHeader: true, gymId: currentGymId
        ) else {
            errorMessage = "Failed to create authenticated request"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard requestVersion == eventsRequestVersion, currentGymId == GymService.shared.currentGymId else {
                isLoading = false
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for workspace context: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let fetched = try decoder.decode(WorkspaceContext.self, from: data)
                    guard currentGymId == GymService.shared.currentGymId,
                          fetched.workspace.id == currentGymId else {
                        isLoading = false
                        return
                    }
                    self.context = fetched
                    self.lastContextRefresh = Date()
                    self.loadedContextGymId = currentGymId

                    print("✅ Workspace context loaded")
                    print("   - Type: \(context?.workspace.type ?? "unknown")")
                    print("   - Is Personal Trainer: \(isPersonalTrainer)")
                    print("   - Navigation items: \(navigation.count)")

                    // Guardar en cache
                    saveContextToCache()

                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Error getting workspace context: \(errorString)")
                    errorMessage = "Error loading workspace: \(httpResponse.statusCode)"

                    // Try to load from cache
                    loadContextFromCache()
                }
            }
        } catch {
            guard requestVersion == eventsRequestVersion, currentGymId == GymService.shared.currentGymId else {
                isLoading = false
                return
            }
            print("❌ Error fetching workspace context: \(error)")
            errorMessage = "Network error: \(error.localizedDescription)"

            // Try to load from cache
            loadContextFromCache()
        }

        isLoading = false
    }

    // MARK: - Fetch Stats

    /// Persist the workspace-wide choice. A failed write leaves the switch in its saved state.
    func setPTEventsEnabled(_ enabled: Bool) async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive, let state = galleryPTEvents {
            galleryPTEvents = PTEventsState(gymId: state.gymId, available: state.available, enabled: enabled,
                                           canManage: state.canManage, canSellTickets: state.canSellTickets,
                                           currency: state.currency)
            return
        }
        #endif
        guard !isSavingEvents, ptEvents?.canManage == true,
              let gymId = GymService.shared.currentGymId,
              let url = URL(string: "\(baseURL)/context/workspace/events") else { return }
        let version = UUID()
        eventsRequestVersion = version
        isSavingEvents = true
        eventsSettingsError = nil
        defer {
            if eventsRequestVersion == version { isSavingEvents = false }
        }
        guard var request = await HTTPClient.shared.makeRequest(url: url, method: "PUT", includeGymHeader: true),
              GymService.shared.currentGymId == gymId else {
            if eventsRequestVersion == version {
                eventsSettingsError = "Couldn't save your changes. Please sign in again and retry."
            }
            return
        }
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["enabled": enabled])
        do {
            let (data, response) = try await session.data(for: request)
            guard eventsRequestVersion == version, GymService.shared.currentGymId == gymId else { return }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let error = try? JSONDecoder().decode(PTEventsAPIError.self, from: data)
                eventsSettingsError = error?.detail ?? "Couldn't save your changes. Please try again."
                return
            }
            let saved = try JSONDecoder().decode(PTEventsState.self, from: data)
            guard saved.gymId == gymId, context?.workspace.id == gymId else { return }
            context?.ptEvents = saved
            saveContextToCache()
        } catch {
            guard eventsRequestVersion == version, GymService.shared.currentGymId == gymId else { return }
            eventsSettingsError = "Couldn't save your changes. Check your connection and try again."
        }
    }

    private struct PTEventsAPIError: Decodable { let detail: String }

    /// Obtiene las estadísticas del workspace actual
    func fetchStats(forceRefresh: Bool = false) async {
        // Check cache
        if !forceRefresh,
           let lastRefresh = lastStatsRefresh,
           Date().timeIntervalSince(lastRefresh) < statsCacheExpiration,
           stats != nil {
            print("📱 Using cached workspace stats")
            return
        }

        isLoadingStats = true

        guard let url = URL(string: "\(baseURL)/context/workspace/stats") else {
            isLoadingStats = false
            return
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
            isLoadingStats = false
            return
        }

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for workspace stats: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()

                    self.stats = try decoder.decode(WorkspaceStatsResponse.self, from: data)
                    self.lastStatsRefresh = Date()

                    print("✅ Workspace stats loaded: \(stats?.type ?? "unknown")")

                    // Guardar en cache
                    saveStatsToCache()
                }
            }
        } catch {
            print("❌ Error fetching workspace stats: \(error)")
            // Try to load from cache
            loadStatsFromCache()
        }

        isLoadingStats = false
    }

    // MARK: - Cache Management

    /// Claves versionadas. La v1 se escribio con JSONEncoder plano y se leia con
    /// .convertFromSnakeCase sobre CodingKeys que ya eran snake_case, asi que nunca
    /// decodificaba. Al versionar, los dispositivos ya instalados descartan esa cache
    /// muerta en vez de seguir fallando.
    private static let contextCacheKey = "WorkspaceContext_v2"
    private static let statsCacheKey = "WorkspaceStats_v2"

    private func saveContextToCache() {
        guard let context = context else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(context)
            UserDefaults.standard.set(data, forKey: Self.contextCacheKey)
            print("💾 Workspace context saved to cache")
        } catch {
            print("❌ Error saving context: \(error)")
        }
    }

    private func loadContextFromCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.contextCacheKey) else {
            print("📱 No cached workspace context")
            return
        }

        do {
            let decoder = JSONDecoder()
            self.context = try decoder.decode(WorkspaceContext.self, from: data)
            print("📱 Loaded workspace context from cache")
            print("   - Type: \(context?.workspace.type ?? "unknown")")
        } catch {
            print("❌ Error loading context from cache: \(error)")
        }
    }

    private func saveStatsToCache() {
        guard let stats = stats else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(stats)
            UserDefaults.standard.set(data, forKey: Self.statsCacheKey)
            print("💾 Workspace stats saved to cache")
        } catch {
            print("❌ Error saving stats: \(error)")
        }
    }

    private func loadStatsFromCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.statsCacheKey) else {
            print("📱 No cached workspace stats")
            return
        }

        do {
            let decoder = JSONDecoder()
            self.stats = try decoder.decode(WorkspaceStatsResponse.self, from: data)
            print("📱 Loaded workspace stats from cache")
        } catch {
            print("❌ Error loading stats from cache: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Obtiene un término de la terminología del workspace
    func getTerm(_ key: String) -> String {
        return TerminologyHelper.getTerm(key, from: terminology)
    }

    /// Obtiene un término capitalizado
    func getCapitalizedTerm(_ key: String) -> String {
        return TerminologyHelper.getCapitalizedTerm(key, from: terminology)
    }

    /// Limpia el contexto y cache
    func clearContext() {
        eventsRequestVersion = UUID()
        isSavingEvents = false
        eventsSettingsError = nil
        context = nil
        stats = nil
        lastContextRefresh = nil
        lastStatsRefresh = nil
        loadedContextGymId = nil
        UserDefaults.standard.removeObject(forKey: Self.contextCacheKey)
        UserDefaults.standard.removeObject(forKey: Self.statsCacheKey)
        print("🗑️ Workspace context cleared")
    }

    /// Valida si una feature está habilitada
    func isFeatureEnabled(_ feature: KeyPath<WorkspaceFeatures, Bool>) -> Bool {
        guard let features = features else {
            // Falla CERRADO. Antes devolvía true sin contexto, así que un fallo de red encendía
            // pantallas que no tienen backend detrás (la agenda del entrenador, por ejemplo).
            // Es preferible esconder algo que existe a mostrar algo que no funciona.
            return false
        }
        return features[keyPath: feature]
    }

    deinit {
        #if DEBUG
        print("🗑️ WorkspaceContextService deinitialized")
        #endif
    }
}
