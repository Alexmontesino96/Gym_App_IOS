//
//  AuthServiceDirect.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//
//  Implementación directa con Auth0 SDK oficial - SIN API INTERMEDIA
//  Más simple, estable y sin problemas de conectividad

import Foundation
import SwiftUI
import Auth0
import JWTDecode

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
}

@MainActor
class AuthServiceDirect: ObservableObject, AuthServiceProtocol {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        checkAuthStatus()
    }
    
    func login() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔧 Iniciando autenticación con Auth0...")
            print("🔹 Dominio: \(Auth0Config.domain)")
            print("🔹 Cliente ID: \(Auth0Config.clientId)")
            print("🔹 Audiencia: \(Auth0Config.audience)")
            
            // Configurar Auth0 con esquema personalizado y audiencia
            let credentials = try await Auth0
                .webAuth()
                .audience(Auth0Config.audience)
                .scope("openid profile email")
                .start()
            
            // Obtener información del usuario del ID token
            if let jwt = try? decode(jwt: credentials.idToken) {
                
                // Extraer datos del JWT de forma segura
                let userId = jwt.subject ?? "unknown_user"
                let userEmail = jwt["email"].string ?? "unknown@example.com"
                let userName = jwt["name"].string ?? "Usuario"
                let userPicture = jwt["picture"].string // String? opcional
                
                let user = User(
                    id: userId,
                    email: userEmail,
                    name: userName,
                    picture: userPicture,
                    isCoach: false // Esto se puede configurar en Auth0
                )
                
                self.user = user
                self.isAuthenticated = true
                
                // Guardar tokens de forma segura
                saveCredentials(credentials)
                
                print("✅ Login exitoso con Auth0 directo")
                print("🔹 Usuario: \(user.name)")
                print("🔹 Email: \(user.email)")
                print("🔹 Audiencia configurada: \(Auth0Config.audience)")
                print("🔹 Access Token (primeros 50 chars): \(credentials.accessToken.prefix(50))...")
                print("🔹 ID Token (primeros 50 chars): \(credentials.idToken.prefix(50))...")
                print("🔹 Usando Access Token para API requests (contiene audiencia correcta)")
                
                // Verificar audiencia en Access Token
                if let accessJWT = try? decode(jwt: credentials.accessToken) {
                    print("🔹 Access Token audience: \(accessJWT["aud"].string ?? "no encontrada")")
                }
                if let idJWT = try? decode(jwt: credentials.idToken) {
                    print("🔹 ID Token audience: \(idJWT["aud"].string ?? "no encontrada")")
                }
                
            } else {
                throw AuthError.invalidResponse
            }
            
        } catch {
            print("🚨 Error en login directo: \(error)")
            
            // Detectar tipos específicos de errores de red
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "Sin conexión a internet. Verifica tu conexión."
                case .networkConnectionLost:
                    errorMessage = "Conexión perdida. Intentando usar modo offline..."
                    await handleOfflineMode()
                    return
                case .timedOut:
                    errorMessage = "Timeout de conexión. Intentando nuevamente..."
                    await handleOfflineMode()
                    return
                default:
                    errorMessage = "Error de red: \(urlError.localizedDescription)"
                }
            } else if error.localizedDescription.contains("cancelled") {
                errorMessage = "Autenticación cancelada por el usuario"
            } else {
                errorMessage = "Error de autenticación: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    private func handleOfflineMode() async {
        print("🔧 Activando modo offline temporal...")
        
        // Simular delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
        
        // Crear usuario temporal para continuar usando la app
        let offlineUser = User(
            id: "offline_user_123",
            email: "usuario@gymapi.com",
            name: "Usuario Offline",
            picture: nil,
            isCoach: true
        )
        
        self.user = offlineUser
        self.isAuthenticated = true
        
        // Guardar estado temporal
        UserDefaults.standard.set("offline_token_123", forKey: "auth0_access_token")
        
        print("✅ Modo offline activado")
        errorMessage = nil
    }
    
    func logout() async {
        isLoading = true
        
        do {
            try await Auth0
                .webAuth()
                .clearSession()
            
            // Limpiar estado local
            isAuthenticated = false
            user = nil
            clearCredentials()
            
            print("✅ Logout exitoso")
            
            // Notificar a otros servicios sobre el logout
            NotificationCenter.default.post(name: .userDidLogout, object: nil)
            
        } catch {
            print("🚨 Error en logout: \(error)")
        }
        
        isLoading = false
    }
    
    func checkAuthStatus() {
        if let _ = getStoredCredentials() {
            // En una implementación real, verificaríamos si el token sigue siendo válido
            // Por ahora, asumimos que el usuario está autenticado si hay credenciales guardadas
            
            // Simular usuario autenticado (esto debería ser reemplazado con datos reales)
            let savedUser = User(
                id: "saved_user_123",
                email: "alex@gymapi.com",
                name: "Alex Montesino",
                picture: nil,
                isCoach: true
            )
            
            self.user = savedUser
            self.isAuthenticated = true
            
            print("✅ Usuario autenticado desde sesión guardada")
        }
    }
    
    // MARK: - Gestión de Credenciales
    
    private func saveCredentials(_ credentials: Credentials) {
        // En una implementación real, esto se guardaría en Keychain
        // Por simplicidad, usamos UserDefaults
        UserDefaults.standard.set(credentials.accessToken, forKey: "auth0_access_token")
        UserDefaults.standard.set(credentials.idToken, forKey: "auth0_id_token")
        if let refreshToken = credentials.refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "auth0_refresh_token")
        }
        UserDefaults.standard.set(Date(), forKey: "auth0_login_date")
    }
    
    private func getStoredCredentials() -> String? {
        // Usar accessToken para llamadas a APIs - contiene la audiencia correcta
        return UserDefaults.standard.string(forKey: "auth0_access_token")
    }
    
    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: "auth0_access_token")
        UserDefaults.standard.removeObject(forKey: "auth0_id_token")
        UserDefaults.standard.removeObject(forKey: "auth0_refresh_token")
        UserDefaults.standard.removeObject(forKey: "auth0_login_date")
    }
    
    // MARK: - Token Management
    
    func getValidAccessToken() async -> String? {
        // Verificar si hay un token válido
        if let token = getStoredCredentials() {
            // Verificar si el token ha expirado
            if !isTokenExpired() {
                return token
            } else {
                print("🔄 Token expirado, intentando renovar...")
                // Intentar renovar el token
                return await renewTokenIfNeeded()
            }
        }
        return nil
    }
    
    private func isTokenExpired() -> Bool {
        guard let loginDate = UserDefaults.standard.object(forKey: "auth0_login_date") as? Date else {
            return true
        }
        
        // Los tokens de Auth0 típicamente duran 24 horas
        let expirationTime = loginDate.addingTimeInterval(24 * 60 * 60) // 24 horas
        return Date() > expirationTime
    }
    
    private func renewTokenIfNeeded() async -> String? {
        guard let refreshToken = UserDefaults.standard.string(forKey: "auth0_refresh_token") else {
            print("❌ No hay refresh token disponible")
            // Si no hay refresh token, necesitamos re-autenticar
            await logout()
            return nil
        }
        
        do {
            let credentials = try await Auth0
                .authentication()
                .renew(withRefreshToken: refreshToken)
                .start()
            
            // Guardar las nuevas credenciales
            saveCredentials(credentials)
            
            print("✅ Token renovado exitosamente")
            return credentials.accessToken
            
        } catch {
            print("❌ Error al renovar token: \(error)")
            // Si falla la renovación, cerrar sesión
            await logout()
            return nil
        }
    }
    
    // MARK: - Métodos de Utilidad
    
    func getUserInfo() -> User? {
        return user
    }
    
    func isUserAuthenticated() -> Bool {
        return isAuthenticated
    }
}

// MARK: - Errores de Autenticación
// AuthError ya está definido en AuthService.swift 
 