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
    
    // Función utilitaria para configurar JSONDecoder con formato de fecha correcto
    private func configuredJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Solución para iOS 18.6+ usando Date.ISO8601FormatStyle
            if #available(iOS 15.0, *) {
                // Intentar con diferentes configuraciones de ISO8601FormatStyle
                let formatStyles: [Date.ISO8601FormatStyle] = [
                    // Formato con fracciones de segundo
                    Date.ISO8601FormatStyle(includingFractionalSeconds: true),
                    // Formato estándar sin fracciones
                    Date.ISO8601FormatStyle(includingFractionalSeconds: false),
                    // Formato con zona horaria UTC
                    Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 0)!),
                ]
                
                for formatStyle in formatStyles {
                    do {
                        let date = try formatStyle.parse(dateString)
                        return date
                    } catch {
                        continue
                    }
                }
                
                // Intentar agregando 'Z' al final si no la tiene
                if !dateString.hasSuffix("Z") && !dateString.contains("+") && !dateString.dropFirst(10).contains("-") {
                    let dateStringWithZ = dateString + "Z"
                    for formatStyle in formatStyles {
                        do {
                            let date = try formatStyle.parse(dateStringWithZ)
                            return date
                        } catch {
                            continue
                        }
                    }
                }
            }
            
            // Fallback para versiones anteriores de iOS o si ISO8601FormatStyle falla
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // Las fechas del servidor vienen en UTC
            
            let dateFormats = [
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS"
            ]
            
            for format in dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Último intento: agregar Z si no existe
            if !dateString.hasSuffix("Z") && !dateString.contains("+") && !dateString.dropFirst(10).contains("-") {
                let dateStringWithZ = dateString + "Z"
                for format in dateFormats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateStringWithZ) {
                        return date
                    }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'. This appears to be an iOS 18.6 date decoding issue. Tried multiple formats including ISO8601FormatStyle.")
        }
        
        return decoder
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
        
        // Obtener token de autorización
        guard let token = await getAuthToken() else {
            await MainActor.run {
                self.error = UserProfileError.noAuthToken
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📱 [UserProfileService] HTTP Status: \(httpResponse.statusCode)")
                
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
                        
                        print("✅ [UserProfileService] Profile loaded successfully")
                        print("👤 [UserProfileService] User: \(profile.fullName)")
                        print("📊 [UserProfileService] Weight: \(profile.weight ?? -1)")
                        print("📊 [UserProfileService] Height: \(profile.height ?? -1)")
                        print("📊 [UserProfileService] Age: \(profile.age ?? -1)")
                        print("📝 [UserProfileService] Bio: '\(profile.bio ?? "nil")'")
                        print("🎂 [UserProfileService] Birth Date: \(profile.birthDate?.description ?? "nil")")
                        
                    } catch {
                        print("❌ [UserProfileService] Decoding error: \(error)")
                        await MainActor.run {
                            self.error = UserProfileError.decodingError(error)
                            self.isLoading = false
                        }
                    }
                } else {
                    print("❌ [UserProfileService] HTTP Error: \(httpResponse.statusCode)")
                    await MainActor.run {
                        self.error = UserProfileError.httpError(httpResponse.statusCode)
                        self.isLoading = false
                    }
                }
            }
        } catch {
            print("❌ [UserProfileService] Network error: \(error)")
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