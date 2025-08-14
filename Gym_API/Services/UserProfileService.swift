import Foundation
import Combine

// MARK: - User Profile Service
class UserProfileService: ObservableObject {
    // MARK: - Published Properties
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependency Injection
    weak var authService: AuthServiceDirect?
    
    // MARK: - Singleton
    static let shared = UserProfileService()
    
    private init() {}
    
    // Shared decoder
    private func configuredJSONDecoder() -> JSONDecoder { DateDecoding.serverDecoder() }
    
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
                        }
                        
                        debugLog("✅ [UserProfileService] Profile loaded successfully")
                        
                    } catch {
                        debugLog("❌ [UserProfileService] Decoding error: \(error)")
                        await MainActor.run {
                            self.error = UserProfileError.decodingError(error)
                            self.isLoading = false
                        }
                    }
                } else {
                    debugLog("❌ [UserProfileService] HTTP Error: \(httpResponse.statusCode)")
                    await MainActor.run {
                        self.error = UserProfileError.httpError(httpResponse.statusCode)
                        self.isLoading = false
                    }
                }
            }
        } catch {
            debugLog("❌ [UserProfileService] Network error: \(error)")
            await MainActor.run {
                self.error = UserProfileError.networkError(error)
                self.isLoading = false
            }
        }
    }
    
    /// Refresca el perfil del usuario
    func refreshProfile() async {
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
    func isProfileComplete() -> Bool {
        guard let profile = userProfile else { return false }
        
        return !profile.firstName.isEmpty &&
               !profile.lastName.isEmpty &&
               profile.height != nil &&
               profile.weight != nil &&
               profile.birthDate != nil
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
