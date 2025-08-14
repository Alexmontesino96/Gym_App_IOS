//
//  GymService.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import Foundation
import SwiftUI

@MainActor
class GymService: ObservableObject {
    static let shared = GymService()
    
    private init() {
        print("🏋️ GymService singleton initialized")
        print("🏋️ Antes de loadSelectedGymFromStorage() - hasSelectedGym: \(hasSelectedGym), hasCompletedGymSelection: \(hasCompletedGymSelection)")
        loadSelectedGymFromStorage()
        print("🏋️ Después de loadSelectedGymFromStorage() - hasSelectedGym: \(hasSelectedGym), hasCompletedGymSelection: \(hasCompletedGymSelection)")
        print("🏋️ GymService init complete - currentGym: \(currentGym?.name ?? "ninguno")")
    }
    
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceProtocol?
    
    // MARK: - Published Properties
    @Published var myGyms: [GymInfo] = []
    @Published var allGyms: [Gym] = []
    @Published var currentGym: GymInfo?
    @Published var isLoadingGyms = false
    @Published var isLoadingAllGyms = false
    @Published var errorMessage: String?
    @Published var gymHours: [GymHours] = []
    @Published var isLoadingHours = false
    @Published var hasSelectedGym: Bool = false
    @Published var hasCompletedGymSelection: Bool = false // Flag para esta sesión
    
    // MARK: - Non-isolated computed property for other services
    nonisolated var currentGymId: Int? {
        // Since we can't access @Published properties from nonisolated context,
        // we'll use UserDefaults directly for this getter
        if let gymData = UserDefaults.standard.data(forKey: selectedGymKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                let gym = try decoder.decode(GymInfo.self, from: gymData)
                return gym.id
            } catch {
                return nil
            }
        }
        return nil
    }
    
    // MARK: - Cache Properties
    private var lastGymsRefresh: Date?
    private var lastHoursRefresh: Date?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Persistence Keys
    private let selectedGymKey = "selectedGym"
    private let hasSelectedGymKey = "hasSelectedGym"
    
    // MARK: - Helper for Authenticated Requests
    private func createAuthenticatedRequest(url: URL, method: String = "GET") async -> URLRequest? {
        await HTTPClient.shared.makeRequest(url: url, method: method, includeGymHeader: true)
    }
    
    // MARK: - Get My Gyms
    func getMyGyms(forceRefresh: Bool = false, autoSelectIfSingle: Bool = false) async {
        // Check cache
        if !forceRefresh,
           let lastRefresh = lastGymsRefresh,
           Date().timeIntervalSince(lastRefresh) < cacheExpirationInterval,
           !myGyms.isEmpty {
            print("📱 Using cached gym data")
            // Still print the cached data for debugging
            for gym in myGyms {
                print("📱 Cached Gym: \(gym.name), Role: \(gym.userRoleInGym)")
            }
            
            // Auto-select if only one gym and flag is set
            // Verificar hasCompletedGymSelection en lugar de hasSelectedGym
            if autoSelectIfSingle && myGyms.count == 1 && !hasCompletedGymSelection {
                print("🎯 Auto-selección desde caché: Solo hay 1 gym disponible")
                await autoSelectSingleGym()
            }
            return
        }
        
        isLoadingGyms = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/gyms/my?skip=0&limit=100") else {
            errorMessage = "Invalid URL"
            isLoadingGyms = false
            return
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            errorMessage = "Failed to create authenticated request"
            isLoadingGyms = false
            return
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for my gyms: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        let dateFormats = [
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
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
                    
                    let gyms = try decoder.decode([GymInfo].self, from: data)
                    
                    self.myGyms = gyms
                    
                    print("⚠️ PROBLEMA ENCONTRADO: getMyGyms() está seleccionando gym automáticamente")
                    print("⚠️ Esto podría estar causando que se salte la página de selección")
                    
                    // NO SELECCIONAR AUTOMATICAMENTE - El usuario debe elegir
                    // Este es el problema principal que impide mostrar la página de selección
                    
                    // Comentamos la selección automática:
                    /*
                    // Select the gym with ID 4 (1Kick) as current, or first gym as fallback
                    if let targetGym = gyms.first(where: { $0.id == 4 }) {
                        self.currentGym = targetGym
                        print("🎯 Selected gym with ID 4: \(targetGym.name)")
                    } else {
                        self.currentGym = gyms.first
                        print("🎯 Selected first gym as fallback")
                    }
                    */
                    
                    print("✅ Gyms cargados SIN selección automática - usuario debe elegir")
                    
                    self.lastGymsRefresh = Date()
                    self.isLoadingGyms = false
                    
                    print("✅ Loaded \(gyms.count) gyms")
                    for gym in gyms {
                        print("🏋️ Gym: \(gym.name) (ID: \(gym.id)), Role: \(gym.userRoleInGym), Email: \(gym.userEmail)")
                    }
                    
                    // Save to UserDefaults for offline access
                    saveGymsToStorage(gyms)
                    
                    // Auto-select if only one gym and flag is set
                    // Verificar hasCompletedGymSelection en lugar de hasSelectedGym para permitir auto-selección
                    // incluso si hay un gym guardado de una sesión anterior
                    if autoSelectIfSingle && gyms.count == 1 && !self.hasCompletedGymSelection {
                        print("🎯 Auto-selección: Solo hay 1 gym disponible y no se ha completado la selección")
                        await self.autoSelectSingleGym()
                    } else {
                        print("📊 Auto-selección evaluada: autoSelectIfSingle=\(autoSelectIfSingle), gyms.count=\(gyms.count), hasCompletedGymSelection=\(self.hasCompletedGymSelection)")
                    }
                    
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Error getting gyms: \(errorString)")
                    errorMessage = "Error loading gyms: \(httpResponse.statusCode)"
                    isLoadingGyms = false
                    
                    // Try to load from storage if request failed
                    loadGymsFromStorage()
                }
            }
        } catch {
            print("❌ Error fetching gyms: \(error)")
            errorMessage = "Network error: \(error.localizedDescription)"
            isLoadingGyms = false
            
            // Try to load from storage if request failed
            loadGymsFromStorage()
        }
    }
    
    // MARK: - Storage Methods
    private func saveGymsToStorage(_ gyms: [GymInfo]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(gyms)
            UserDefaults.standard.set(data, forKey: "CachedGyms")
            print("💾 Saved \(gyms.count) gyms to storage")
        } catch {
            print("❌ Error saving gyms to storage: \(error)")
        }
    }
    
    private func loadGymsFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: "CachedGyms") else {
            print("📱 No cached gyms found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let gyms = try decoder.decode([GymInfo].self, from: data)
            
            self.myGyms = gyms
            
            print("⚠️ loadGymsFromStorage() también seleccionaba gym automáticamente")
            
            // NO SELECCIONAR AUTOMATICAMENTE desde storage tampoco
            /*
            // Select the gym with ID 4 (1Kick) as current, or first gym as fallback
            if let targetGym = gyms.first(where: { $0.id == 4 }) {
                self.currentGym = targetGym
                print("📱 Selected gym with ID 4 from storage: \(targetGym.name)")
            } else {
                self.currentGym = gyms.first
                print("📱 Selected first gym from storage as fallback")
            }
            */
            
            print("✅ Gyms cargados desde storage SIN selección automática")
            
            print("📱 Loaded \(gyms.count) gyms from storage")
        } catch {
            print("❌ Error loading gyms from storage: \(error)")
        }
    }
    
    // MARK: - Get Regular Gym Hours
    func getRegularGymHours(forceRefresh: Bool = false) async {
        guard currentGym != nil else {
            print("❌ No current gym selected")
            errorMessage = "No gym selected"
            return
        }
        
        if !forceRefresh,
           let lastRefresh = lastHoursRefresh,
           Date().timeIntervalSince(lastRefresh) < cacheExpirationInterval,
           !gymHours.isEmpty {
            print("📱 Using cached gym hours data")
            return
        }
        
        isLoadingHours = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/schedule/gym-hours/regular") else {
            errorMessage = "Invalid URL"
            isLoadingHours = false
            return
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            errorMessage = "Failed to create authenticated request"
            isLoadingHours = false
            return
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for gym hours: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        let timeFormats = [
                            "HH:mm:ss.SSS'Z'",
                            "HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                        ]
                        
                        for format in timeFormats {
                            formatter.dateFormat = format
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'")
                    }
                    
                    let hours = try decoder.decode([GymHours].self, from: data)
                    
                    self.gymHours = hours
                    self.lastHoursRefresh = Date()
                    self.isLoadingHours = false
                    
                    print("✅ Loaded \(hours.count) gym hours")
                    saveHoursToStorage(hours)
                    
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Error getting gym hours: \(errorString)")
                    errorMessage = "Error loading gym hours: \(httpResponse.statusCode)"
                    isLoadingHours = false
                    loadHoursFromStorage()
                }
            }
        } catch {
            print("❌ Error fetching gym hours: \(error)")
            errorMessage = "Network error: \(error.localizedDescription)"
            isLoadingHours = false
            loadHoursFromStorage()
        }
    }
    
    private func saveHoursToStorage(_ hours: [GymHours]) {
        guard let gymId = currentGym?.id else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(hours)
            UserDefaults.standard.set(data, forKey: "CachedGymHours_\(gymId)")
            print("💾 Saved \(hours.count) gym hours to storage")
        } catch {
            print("❌ Error saving gym hours to storage: \(error)")
        }
    }
    
    private func loadHoursFromStorage() {
        guard let gymId = currentGym?.id else { return }
        guard let data = UserDefaults.standard.data(forKey: "CachedGymHours_\(gymId)") else {
            print("📱 No cached gym hours found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let hours = try decoder.decode([GymHours].self, from: data)
            
            self.gymHours = hours
            print("📱 Loaded \(hours.count) gym hours from storage")
        } catch {
            print("❌ Error loading gym hours from storage: \(error)")
        }
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        myGyms = []
        currentGym = nil
        gymHours = []
        lastGymsRefresh = nil
        lastHoursRefresh = nil
        UserDefaults.standard.removeObject(forKey: "CachedGyms")
        
        for gym in myGyms {
            UserDefaults.standard.removeObject(forKey: "CachedGymHours_\(gym.id)")
        }
        
        print("🗑️ Gym cache cleared")
    }
    
    // MARK: - Gym Selection Management
    
    /// Selecciona un gym y lo persiste
    func selectGym(_ gym: GymInfo) {
        print("🎯 Seleccionando gym: \(gym.name) (ID: \(gym.id))")
        currentGym = gym
        hasSelectedGym = true
        hasCompletedGymSelection = true // Marca como completada la selección en esta sesión
        saveSelectedGymToStorage()
        
        // Notificar a otros servicios del cambio
        NotificationCenter.default.post(name: .gymChanged, object: gym)
    }
    
    /// Auto-selecciona el gym si solo hay uno disponible
    private func autoSelectSingleGym() async {
        guard myGyms.count == 1, let singleGym = myGyms.first else {
            print("❌ autoSelectSingleGym: No hay exactamente un gym para auto-seleccionar")
            return
        }
        
        print("🚀 Auto-seleccionando el único gym disponible: \(singleGym.name)")
        
        // Si ya hay un gym seleccionado y es el mismo, solo marcar como completado
        if let currentGym = currentGym, currentGym.id == singleGym.id {
            print("✅ El gym ya estaba seleccionado, marcando selección como completada")
            await MainActor.run {
                self.hasCompletedGymSelection = true
            }
        } else {
            // Seleccionar el nuevo gym
            await MainActor.run {
                self.selectGym(singleGym)
            }
        }
        
        print("✅ Gym auto-seleccionado exitosamente - hasCompletedGymSelection: \(hasCompletedGymSelection)")
    }
    
    /// Limpia la selección de gym
    func clearGymSelection() {
        print("🗑️ Limpiando selección de gym")
        currentGym = nil
        hasSelectedGym = false
        hasCompletedGymSelection = false // Resetear flag de sesión
        clearSelectedGymFromStorage()
        
        // Limpiar caché de todos los servicios
        clearCache()
        
        // Notificar del cambio
        NotificationCenter.default.post(name: .gymSelectionCleared, object: nil)
    }
    
    /// Carga el gym seleccionado desde UserDefaults
    private func loadSelectedGymFromStorage() {
        // Primero verificar el flag rápidamente
        hasSelectedGym = UserDefaults.standard.bool(forKey: hasSelectedGymKey)
        // NO marcar como completada la selección - el usuario debe pasar por el flujo
        hasCompletedGymSelection = false
        
        if !hasSelectedGym {
            print("📱 No hay gym seleccionado en storage")
            return
        }
        
        // Si hay gym seleccionado, intentar cargarlo
        if let gymData = UserDefaults.standard.data(forKey: selectedGymKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                currentGym = try decoder.decode(GymInfo.self, from: gymData)
                print("✅ Gym cargado desde storage: \(currentGym?.name ?? "Unknown")")
            } catch {
                print("❌ Error cargando gym desde storage: \(error)")
                // Si hay error, limpiar selección
                hasSelectedGym = false
                UserDefaults.standard.set(false, forKey: hasSelectedGymKey)
            }
        } else {
            // Si no hay datos pero el flag dice que sí, corregir
            hasSelectedGym = false
            UserDefaults.standard.set(false, forKey: hasSelectedGymKey)
        }
    }
    
    /// Guarda el gym seleccionado en UserDefaults
    private func saveSelectedGymToStorage() {
        guard let currentGym = currentGym else {
            clearSelectedGymFromStorage()
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                let dateString = formatter.string(from: date)
                
                var container = encoder.singleValueContainer()
                try container.encode(dateString)
            }
            
            let gymData = try encoder.encode(currentGym)
            UserDefaults.standard.set(gymData, forKey: selectedGymKey)
            UserDefaults.standard.set(true, forKey: hasSelectedGymKey)
            print("💾 Gym guardado en storage: \(currentGym.name)")
        } catch {
            print("❌ Error guardando gym en storage: \(error)")
        }
    }
    
    /// Limpia el gym seleccionado del storage
    private func clearSelectedGymFromStorage() {
        UserDefaults.standard.removeObject(forKey: selectedGymKey)
        UserDefaults.standard.set(false, forKey: hasSelectedGymKey)
        print("🗑️ Gym eliminado del storage")
    }
    
    /// Verifica si el gym actual aún está disponible para el usuario
    func validateCurrentGymMembership() async -> Bool {
        guard let currentGym = currentGym else { return false }
        
        await getMyGyms(forceRefresh: true)
        
        let isStillMember = myGyms.contains { $0.id == currentGym.id }
        if !isStillMember {
            print("⚠️ El usuario ya no es miembro del gym actual")
            clearGymSelection()
            return false
        }
        
        return true
    }
    
    // MARK: - Get All Gyms (PUBLIC - no authentication required)
    func getAllGyms(forceRefresh: Bool = false) async {
        isLoadingAllGyms = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/gyms/?skip=0&limit=100&is_active=true") else {
            errorMessage = "Invalid URL"
            isLoadingAllGyms = false
            return
        }
        
        // Create simple request without authentication (public endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for all gyms (public): \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let gyms = try decoder.decode([Gym].self, from: data)
                    
                    self.allGyms = gyms.filter { $0.isActive }
                    self.isLoadingAllGyms = false
                    
                    print("✅ Loaded \(gyms.count) available gyms (public)")
                    for gym in self.allGyms {
                        print("🏋️ Available Gym: \(gym.name) (ID: \(gym.id))")
                    }
                    
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Error getting all gyms: \(errorString)")
                    errorMessage = "Error loading gyms: \(httpResponse.statusCode)"
                    isLoadingAllGyms = false
                }
            }
        } catch {
            print("❌ Error fetching all gyms: \(error)")
            errorMessage = "Network error: \(error.localizedDescription)"
            isLoadingAllGyms = false
        }
    }
    
    // MARK: - Get Gym Details (PUBLIC - no authentication required)
    func getGymDetails(gymId: Int) async -> GymDetail? {
        guard let url = URL(string: "\(baseURL)/gyms/\(gymId)/details") else {
            print("❌ Invalid URL for gym details")
            return nil
        }
        
        // Create simple request without authentication (public endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for gym details: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let gymDetail = try decoder.decode(GymDetail.self, from: data)
                    
                    print("✅ Loaded gym details for: \(gymDetail.name)")
                    print("   - Hours: \(gymDetail.gymHours.count) entries")
                    print("   - Plans: \(gymDetail.membershipPlans.count) plans")
                    print("   - Modules: \(gymDetail.modules.count) modules")
                    
                    return gymDetail
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Error getting gym details: \(errorString)")
                }
            }
        } catch {
            print("❌ Error fetching gym details: \(error)")
        }
        
        return nil
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gymChanged = Notification.Name("gymChanged")
    static let gymSelectionCleared = Notification.Name("gymSelectionCleared")
}
