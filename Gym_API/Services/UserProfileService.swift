import Foundation
import Combine

// MARK: - User Profile Service
class UserProfileService: ObservableObject {
    // MARK: - Published Properties
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private let baseURL = apiBaseURL
    private var cancellables = Set<AnyCancellable>()
    private var lastFetchedAt: Date?
    var minRefreshInterval: TimeInterval = 300 // 5 minutos por defecto
    
    // MARK: - Dependency Injection
    weak var authService: AuthServiceDirect?
    
    // MARK: - Singleton
    static let shared = UserProfileService()
    
    private init() {}
    
    // Shared decoder
    private func configuredJSONDecoder() -> JSONDecoder { DateDecoding.serverDecoder() }
    
    // MARK: - Clear cached profile
    func clear() {
        userProfile = nil
        error = nil
        isLoading = false
    }
    
    // MARK: - Get Auth Token
    private func getAuthToken() async -> String? {
        guard let authService = authService else {
            print("⚠️ AuthService no disponible en UserProfileService")
            return nil
        }
        
        return await authService.getValidAccessToken()
    }
    
    // MARK: - Public Methods
    
    /// Obtiene el perfil completo del usuario autenticado
    func fetchUserProfile() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        guard let url = URL(string: "\(baseURL)/users/profile") else {
            await MainActor.run {
                self.error = UserProfileError.invalidURL
                self.isLoading = false
            }
            return
        }
        
        // Crear request autenticada
        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: false) else {
            await MainActor.run {
                self.userProfile = nil
                self.error = UserProfileError.noAuthToken
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                debugLog("📱 [UserProfileService] HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    do {
                        // Usar el decodificador personalizado para manejar fechas
                        let decoder = configuredJSONDecoder()
                        
                        let profile = try decoder.decode(UserProfile.self, from: data)
                        
                        await MainActor.run {
                            self.userProfile = profile
                            self.isLoading = false
                            self.error = nil
                            self.lastFetchedAt = Date()
                        }
                        
                        debugLog("✅ [UserProfileService] Profile loaded successfully")
                        
                    } catch {
                        debugLog("❌ [UserProfileService] Decoding error: \(error)")
                        await MainActor.run {
                            self.userProfile = nil
                            self.error = UserProfileError.decodingError(error)
                            self.isLoading = false
                        }
                    }
                } else {
                    debugLog("❌ [UserProfileService] HTTP Error: \(httpResponse.statusCode)")
                    await MainActor.run {
                        self.userProfile = nil
                        self.error = UserProfileError.httpError(httpResponse.statusCode)
                        self.isLoading = false
                    }
                }
            }
        } catch {
            debugLog("❌ [UserProfileService] Network error: \(error)")
            await MainActor.run {
                self.userProfile = nil
                self.error = UserProfileError.networkError(error)
                self.isLoading = false
            }
        }
    }
    
    /// Refresca el perfil del usuario
    func refreshProfile() async {
        await fetchUserProfile()
    }
    
    /// Obtiene el perfil sólo si no existe o está desactualizado
    func fetchUserProfileIfStale(force: Bool = false) async {
        if !force, let last = lastFetchedAt, userProfile != nil {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minRefreshInterval { return }
        }
        await fetchUserProfile()
    }
    
    /// Actualiza el perfil del usuario con nueva información
    func updateProfile(firstName: String?, lastName: String?, birthDate: Date?, height: Double?, weight: Double?, bio: String?) async -> Bool {
        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            print("❌ [UserProfileService] No valid auth token for profile update")
            return false
        }
        
        guard let url = URL(string: "\(baseURL)/users/profile") else {
            print("❌ [UserProfileService] Invalid URL for profile update")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Crear el cuerpo de la petición con los campos opcionales
        var requestBody: [String: Any] = [:]
        
        if let firstName = firstName {
            requestBody["first_name"] = firstName
        }
        if let lastName = lastName {
            requestBody["last_name"] = lastName
        }
        if let birthDate = birthDate {
            let formatter = ISO8601DateFormatter()
            requestBody["birth_date"] = formatter.string(from: birthDate)
        }
        if let height = height {
            requestBody["height"] = height
        }
        if let weight = weight {
            requestBody["weight"] = weight
        }
        if let bio = bio {
            requestBody["bio"] = bio
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [UserProfileService] Invalid response for profile update")
                return false
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ [UserProfileService] Profile updated successfully")
                
                // Decodificar el perfil actualizado que devuelve el servidor
                do {
                    let decoder = configuredJSONDecoder()
                    let updatedProfile = try decoder.decode(UserProfile.self, from: data)
                    
                    await MainActor.run {
                        self.userProfile = updatedProfile
                    }
                    
                    print("👤 [UserProfileService] Updated profile: \(updatedProfile.fullName)")
                    return true
                    
                } catch {
                    print("❌ [UserProfileService] Error decoding updated profile: \(error)")
                    // Aún así refrescar el perfil desde el servidor
                    await fetchUserProfile()
                    return true
                }
            } else {
                print("❌ [UserProfileService] Profile update failed: \(httpResponse.statusCode)")
                return false
            }
        } catch {
            print("❌ [UserProfileService] Network error during profile update: \(error)")
            return false
        }
    }
    
    /// Verifica si el perfil del usuario tiene los campos básicos completos
    /// Criterios: nombre/apellido no vacíos, altura/peso > 0, edad dentro de un rango razonable
    func isProfileComplete() -> Bool {
        guard let profile = userProfile else { 
            print("🔍 [isProfileComplete] userProfile es nil")
            return false 
        }
        
        print("🔍 [isProfileComplete] Verificando perfil para usuario: \(profile.fullName)")
        print("🔍 [isProfileComplete] firstName: '\(profile.firstName)'")
        print("🔍 [isProfileComplete] lastName: '\(profile.lastName)'")
        print("🔍 [isProfileComplete] height: \(profile.height?.description ?? "nil")")
        print("🔍 [isProfileComplete] weight: \(profile.weight?.description ?? "nil")")
        print("🔍 [isProfileComplete] birthDate: \(profile.birthDate?.description ?? "nil")")
        
        let firstValid = !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lastValid = !profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        print("🔍 [isProfileComplete] firstValid: \(firstValid)")
        print("🔍 [isProfileComplete] lastValid: \(lastValid)")
        
        let heightValid: Bool = {
            if let h = profile.height { 
                let valid = h > 0
                print("🔍 [isProfileComplete] height \(h) > 0: \(valid)")
                return valid
            }
            print("🔍 [isProfileComplete] height es nil")
            return false
        }()
        
        let weightValid: Bool = {
            if let w = profile.weight { 
                let valid = w > 0
                print("🔍 [isProfileComplete] weight \(w) > 0: \(valid)")
                return valid
            }
            print("🔍 [isProfileComplete] weight es nil")
            return false
        }()
        
        let ageValid: Bool = {
            guard let birth = profile.birthDate else { 
                print("🔍 [isProfileComplete] birthDate es nil")
                return false 
            }
            
            let now = Date()
            let calendar = Calendar.current
            
            // Usar un cálculo más robusto de edad que maneja bien las zonas horarias
            let ageComponents = calendar.dateComponents([.year, .month, .day], from: birth, to: now)
            let years = ageComponents.year ?? 0
            
            // También calcular la edad usando solo años para comparar
            let birthYear = calendar.component(.year, from: birth)
            let currentYear = calendar.component(.year, from: now)
            let alternativeAge = currentYear - birthYear
            
            // Usar un rango más amplio y flexible para la validación
            let ageRange = (1...120) // Rango más amplio para evitar falsos negativos
            let valid = ageRange.contains(years) || ageRange.contains(alternativeAge)
            
            print("🔍 [isProfileComplete] birthDate: \(birth)")
            print("🔍 [isProfileComplete] currentDate: \(now)")
            print("🔍 [isProfileComplete] calculatedAge (dateComponents): \(years) años")
            print("🔍 [isProfileComplete] alternativeAge (year difference): \(alternativeAge) años")
            print("🔍 [isProfileComplete] birthYear: \(birthYear)")
            print("🔍 [isProfileComplete] currentYear: \(currentYear)")
            print("🔍 [isProfileComplete] ageRange: \(ageRange)")
            print("🔍 [isProfileComplete] ageValid: \(valid)")
            
            return valid
        }()
        
        let allValid = firstValid && lastValid && heightValid && weightValid && ageValid
        
        print("🔍 [isProfileComplete] Resumen:")
        print("🔍 [isProfileComplete] - firstValid: \(firstValid)")
        print("🔍 [isProfileComplete] - lastValid: \(lastValid)")
        print("🔍 [isProfileComplete] - heightValid: \(heightValid)")
        print("🔍 [isProfileComplete] - weightValid: \(weightValid)")
        print("🔍 [isProfileComplete] - ageValid: \(ageValid)")
        print("🔍 [isProfileComplete] - RESULTADO FINAL: \(allValid)")
        
        return allValid
    }
    
    /// Actualiza el color de fondo del perfil en el servidor
    func updateProfileBackgroundColor(_ colorHex: String) async -> Bool {
        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            print("❌ [UserProfileService] No valid auth token for color update")
            return false
        }
        
        guard let url = URL(string: "\(baseURL)/users/profile/data") else {
            print("❌ [UserProfileService] Invalid URL for color update")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["color": colorHex]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [UserProfileService] Invalid response for background color update")
                return false
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ [UserProfileService] Profile color updated successfully: \(colorHex)")
                
                // El endpoint devuelve el perfil completo actualizado, decodificarlo
                do {
                    let decoder = configuredJSONDecoder()
                    let updatedProfile = try decoder.decode(UserProfile.self, from: data)
                    
                    await MainActor.run {
                        self.userProfile = updatedProfile
                    }
                    
                    print("✅ [UserProfileService] Profile updated with new color: \(updatedProfile.color ?? "nil")")
                } catch {
                    print("❌ [UserProfileService] Error decoding updated profile: \(error)")
                    // Aún consideramos exitoso si el servidor respondió 200
                }
                
                return true
            } else {
                print("❌ [UserProfileService] HTTP Error updating color: \(httpResponse.statusCode)")
                
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [UserProfileService] Error details: \(errorString)")
                }
                
                return false
            }
            
        } catch {
            print("❌ [UserProfileService] Network error updating color: \(error)")
            return false
        }
    }
    
    /// Limpia los datos del perfil
    func clearProfile() {
        userProfile = nil
        error = nil
        isLoading = false
    }

    deinit {
        #if DEBUG
        print("🗑️ UserProfileService deinitialized")
        #endif
        // Limpiar datos de perfil
        userProfile = nil
        error = nil
    }
}

// MARK: - User Profile Errors
enum UserProfileError: LocalizedError {
    case invalidURL
    case noAuthToken
    case networkError(Error)
    case httpError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noAuthToken:
            return "No authentication token available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        }
    }
}
