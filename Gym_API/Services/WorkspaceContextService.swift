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

    // MARK: - Cache Properties
    private var lastContextRefresh: Date?
    private var lastStatsRefresh: Date?
    private let contextCacheExpiration: TimeInterval = 300 // 5 minutos
    private let statsCacheExpiration: TimeInterval = 300 // 5 minutos

    // MARK: - Computed Properties

    var isPersonalTrainer: Bool {
        context?.workspace.isPersonalTrainer ?? false
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
        // Check cache
        if !forceRefresh,
           let lastRefresh = lastContextRefresh,
           Date().timeIntervalSince(lastRefresh) < contextCacheExpiration,
           context != nil {
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

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
            errorMessage = "Failed to create authenticated request"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for workspace context: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

                    self.context = try decoder.decode(WorkspaceContext.self, from: data)
                    self.lastContextRefresh = Date()

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
            print("❌ Error fetching workspace context: \(error)")
            errorMessage = "Network error: \(error.localizedDescription)"

            // Try to load from cache
            loadContextFromCache()
        }

        isLoading = false
    }

    // MARK: - Fetch Stats

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
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

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

    private func saveContextToCache() {
        guard let context = context else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(context)
            UserDefaults.standard.set(data, forKey: "WorkspaceContext")
            print("💾 Workspace context saved to cache")
        } catch {
            print("❌ Error saving context: \(error)")
        }
    }

    private func loadContextFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "WorkspaceContext") else {
            print("📱 No cached workspace context")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
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
            UserDefaults.standard.set(data, forKey: "WorkspaceStats")
            print("💾 Workspace stats saved to cache")
        } catch {
            print("❌ Error saving stats: \(error)")
        }
    }

    private func loadStatsFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "WorkspaceStats") else {
            print("📱 No cached workspace stats")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
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
        context = nil
        stats = nil
        lastContextRefresh = nil
        lastStatsRefresh = nil
        UserDefaults.standard.removeObject(forKey: "WorkspaceContext")
        UserDefaults.standard.removeObject(forKey: "WorkspaceStats")
        print("🗑️ Workspace context cleared")
    }

    /// Valida si una feature está habilitada
    func isFeatureEnabled(_ feature: KeyPath<WorkspaceFeatures, Bool>) -> Bool {
        guard let features = features else {
            // Si no hay contexto, asumir que todas las features están habilitadas (gym tradicional)
            return true
        }
        return features[keyPath: feature]
    }

    deinit {
        #if DEBUG
        print("🗑️ WorkspaceContextService deinitialized")
        #endif
    }
}
