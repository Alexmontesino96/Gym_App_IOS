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

// MARK: - Auth Error
enum AuthError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case networkError(Error)
    case tokenExpired
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Respuesta inválida del servidor de autenticación"
        case .invalidCredentials:
            return "Credenciales inválidas"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .tokenExpired:
            return "El token de acceso ha expirado"
        case .unknown(let error):
            return "Error desconocido: \(error.localizedDescription)"
        }
    }
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
}

@MainActor
class AuthServiceDirect: ObservableObject, AuthServiceProtocol {
    @Published var isAuthenticated = false
    @Published var user: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var biometricAuthAvailable = false
    @Published var biometricAuthEnabled = false
    
    // Control de refresh de primer login (para permisos de Auth0)
    private let firstLoginRefreshKey = "auth0_first_login_refreshed"
    
    // Biometric authentication context - temporarily disabled
    // private let biometricContext = LAContext()
    
    init() {
        // Migrate tokens if needed
        if !KeychainService.shared.hasMigratedToKeychain {
            KeychainService.shared.migrateFromUserDefaults()
        }
        // Temporarily disabled: checkBiometricAvailability()
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
                
                let user = AuthUser(
                    id: userId,
                    email: userEmail,
                    name: userName,
                    picture: userPicture,
                    isCoach: false // Esto se puede configurar en Auth0
                )
                
                self.user = user
                self.isAuthenticated = true
                
                // Guardar tokens de forma segura en Keychain
                saveCredentials(credentials)
                saveUserInfo(user)
                
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
        let offlineUser = AuthUser(
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
            
            // Limpiar todos los datos del usuario anterior
            await clearAllUserData()
            
            print("✅ Logout exitoso")
            
            // Notificar a otros servicios sobre el logout
            NotificationCenter.default.post(name: .userDidLogout, object: nil)
            
        } catch {
            print("🚨 Error en logout: \(error)")
        }
        
        isLoading = false
    }
    
    func checkAuthStatus() {
        print("🔍 Verificando estado de autenticación...")
        
        // Verificar si hay credenciales válidas en Keychain
        guard let accessToken = getStoredCredentials(),
              !isTokenExpired(token: accessToken) else {
            print("❌ No hay token válido o ha expirado")
            isAuthenticated = false
            user = nil
            return
        }
        
        // Intentar obtener información del usuario del ID token
        if let idToken = KeychainService.shared.getToken(type: .idToken),
           let jwt = try? decode(jwt: idToken) {
            // Extraer datos del JWT
            let userId = jwt.subject ?? "unknown_user"
            let userEmail = jwt["email"].string ?? "unknown@example.com"
            let userName = jwt["name"].string ?? "Usuario"
            let userPicture = jwt["picture"].string
            
            let user = AuthUser(
                id: userId,
                email: userEmail,
                name: userName,
                picture: userPicture,
                isCoach: false
            )
            
            self.user = user
            self.isAuthenticated = true
            print("✅ Usuario autenticado desde ID token")
        } else {
            // Fallback: intentar cargar de UserDefaults (compatibilidad)
            guard let savedUserId = UserDefaults.standard.string(forKey: "saved_user_id"),
                  let savedUserEmail = UserDefaults.standard.string(forKey: "saved_user_email"),
                  let savedUserName = UserDefaults.standard.string(forKey: "saved_user_name") else {
                print("❌ No hay información de usuario disponible")
                isAuthenticated = false
                user = nil
                return
            }
            
            let savedUserPicture = UserDefaults.standard.string(forKey: "saved_user_picture")
            let savedUserIsCoach = UserDefaults.standard.bool(forKey: "saved_user_is_coach")
            
            let savedUser = AuthUser(
                id: savedUserId,
                email: savedUserEmail,
                name: savedUserName,
                picture: savedUserPicture,
                isCoach: savedUserIsCoach
            )
            
            self.user = savedUser
            self.isAuthenticated = true
            print("✅ Usuario autenticado desde UserDefaults (compatibilidad)")
        }
        
        print("✅ Usuario autenticado desde sesión guardada: \(user?.name ?? "Usuario")")
        print("🔹 Token válido hasta: \(getTokenExpirationDate())")
        
        #if DEBUG
        KeychainService.shared.debugPrintTokens()
        #endif
    }
    
    // MARK: - Gestión de Credenciales
    
    private func saveCredentials(_ credentials: Credentials) {
        // Guardar tokens de forma segura en Keychain
        KeychainService.shared.saveToken(credentials.accessToken, type: .accessToken)
        KeychainService.shared.saveToken(credentials.idToken, type: .idToken)
        if let refreshToken = credentials.refreshToken {
            KeychainService.shared.saveToken(refreshToken, type: .refreshToken)
        }
        // Mantener fecha de login en UserDefaults (no es sensible)
        UserDefaults.standard.set(Date(), forKey: "auth0_login_date")
    }
    
    private func getStoredCredentials() -> String? {
        // Obtener accessToken de Keychain - contiene la audiencia correcta
        return KeychainService.shared.getToken(type: .accessToken)
    }
    
    private func saveUserInfo(_ user: AuthUser) {
        UserDefaults.standard.set(user.id, forKey: "saved_user_id")
        UserDefaults.standard.set(user.email, forKey: "saved_user_email")
        UserDefaults.standard.set(user.name, forKey: "saved_user_name")
        UserDefaults.standard.set(user.picture, forKey: "saved_user_picture")
        UserDefaults.standard.set(user.isCoach, forKey: "saved_user_is_coach")
    }
    
    private func clearCredentials() {
        // Limpiar tokens de Keychain
        KeychainService.shared.deleteAllTokens()
        
        // Limpiar datos no sensibles de UserDefaults
        UserDefaults.standard.removeObject(forKey: "auth0_login_date")
        UserDefaults.standard.removeObject(forKey: "saved_user_id")
        UserDefaults.standard.removeObject(forKey: "saved_user_email")
        UserDefaults.standard.removeObject(forKey: "saved_user_name")
        UserDefaults.standard.removeObject(forKey: "saved_user_picture")
        UserDefaults.standard.removeObject(forKey: "saved_user_is_coach")
    }
    
    // MARK: - Token Management
    
    func getValidAccessToken() async -> String? {
        print("🔍 Solicitando token de acceso válido...")
        
        // Verificar si hay un token válido
        if let token = getStoredCredentials() {
            // Verificar si el token ha expirado decodificando el JWT
            if !isTokenExpired(token: token) {
                print("✅ Token válido encontrado")
                return token
            } else {
                print("🔄 Token expirado, intentando renovar...")
                // Intentar renovar el token
                if let renewedToken = await renewTokenIfNeeded() {
                    print("✅ Token renovado exitosamente")
                    return renewedToken
                } else {
                    print("❌ Falló la renovación del token")
                    return nil
                }
            }
        }
        
        print("❌ No hay token almacenado")
        return nil
    }
    
    private func isTokenExpired(token: String) -> Bool {
        // Decodificar el JWT para obtener la expiración real
        guard let jwt = try? decode(jwt: token) else {
            print("⚠️ No se pudo decodificar el JWT, asumiendo expirado")
            return true
        }
        
        // Obtener el claim 'exp' del JWT
        guard let exp = jwt["exp"].double else {
            print("⚠️ No se encontró el claim 'exp' en el JWT")
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let now = Date()
        
        // Considerar expirado si queda menos de 5 minutos
        let bufferTime: TimeInterval = 5 * 60 // 5 minutos
        let isExpired = now.addingTimeInterval(bufferTime) > expirationDate
        
        if isExpired {
            print("❌ Token expirado (expira: \(expirationDate))")
        } else {
            let timeRemaining = expirationDate.timeIntervalSince(now)
            let minutes = Int(timeRemaining / 60)
            print("✅ Token válido por \(minutes) minutos más")
        }
        
        return isExpired
    }
    
    private func getTokenExpirationDate() -> String {
        guard let loginDate = UserDefaults.standard.object(forKey: "auth0_login_date") as? Date else {
            return "Desconocida"
        }
        
        let expirationTime = loginDate.addingTimeInterval(24 * 60 * 60) // 24 horas
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expirationTime)
    }
    
    private func renewTokenIfNeeded() async -> String? {
        guard let refreshToken = KeychainService.shared.getToken(type: .refreshToken) else {
            print("❌ No hay refresh token disponible en Keychain")
            // Si no hay refresh token, necesitamos re-autenticar
            await logout()
            return nil
        }
        
        print("🔄 Intentando renovar token con retry logic...")
        
        do {
            let credentials = try await NetworkRetryService.shared.executeTokenRefresh(refreshToken: refreshToken)
            
            // Guardar las nuevas credenciales
            saveCredentials(credentials)
            
            print("✅ Token renovado exitosamente con retry logic")
            print("🔹 Nuevo token (primeros 50 chars): \(credentials.accessToken.prefix(50))...")
            
            return credentials.accessToken
            
        } catch NetworkRetryService.RetryError.maxRetriesExceeded {
            print("❌ Falló renovación después de múltiples intentos")
            errorMessage = "Error de conexión. Intenta más tarde."
        } catch NetworkRetryService.RetryError.nonRetryableError(let underlyingError) {
            print("❌ Error no recuperable al renovar token: \(underlyingError)")
            if underlyingError.localizedDescription.contains("invalid_grant") {
                print("❌ Refresh token inválido, requiere re-login")
                errorMessage = "Sesión expirada. Inicia sesión nuevamente."
            } else {
                errorMessage = "Error de autenticación: \(underlyingError.localizedDescription)"
            }
        } catch {
            print("❌ Error inesperado al renovar token: \(error)")
            errorMessage = "Error inesperado: \(error.localizedDescription)"
        }
        
        // Si falla la renovación, cerrar sesión
        await logout()
        return nil
    }
    
    // MARK: - Métodos de Utilidad
    
    func getUserInfo() -> AuthUser? {
        return user
    }
    
    func isUserAuthenticated() -> Bool {
        return isAuthenticated
    }
    
    // MARK: - Primer login: refresh forzado para permisos
    private func scheduleFirstLoginPermissionsRefresh() {
        // Ejecutar en background para no bloquear el flujo de UI
        Task.detached { [weak self] in
            // Esperar unos segundos para dar tiempo a Actions/Rules en Auth0
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            await self?.performFirstLoginForcedRefreshIfNeeded()
        }
    }
    
    @MainActor
    private func performFirstLoginForcedRefreshIfNeeded() async {
        let alreadyRefreshed = UserDefaults.standard.bool(forKey: firstLoginRefreshKey)
        guard !alreadyRefreshed else { return }
        
        guard let refreshToken = KeychainService.shared.getToken(type: .refreshToken) else {
            print("⚠️ No hay refresh token para realizar forced refresh post-login")
            return
        }
        
        print("🔄 Forced refresh post-login para capturar permisos de Auth0 (issue conocido)")
        do {
            let newCreds = try await NetworkRetryService.shared.executeTokenRefresh(refreshToken: refreshToken)
            saveCredentials(newCreds)
            UserDefaults.standard.set(true, forKey: firstLoginRefreshKey)
            print("✅ Forced refresh post-login completado. Nuevo access token almacenado.")
        } catch {
            print("⚠️ Forced refresh post-login falló: \(error.localizedDescription)")
        }
    }
    
    /// Limpia todos los datos del usuario anterior
    private func clearAllUserData() async {
        print("🧹 Limpiando todos los datos del usuario anterior...")
        
        await MainActor.run {
            // Limpiar selección y cache de gym
            GymService.shared.clearGymSelection()
            GymService.shared.clearCache()
            GymService.shared.myGyms = []
            
            // Limpiar datos de membresía
            MembershipService.shared.clearMembershipData()
            
            // Limpiar datos de chat
            ChatService.shared.clearAllData()

            // Limpiar caché de mensajes local del chat (per-user)
            MessageCacheManager.shared.clearAllCache()

            // Borrar conversaciones cacheadas y nombres de salas en UserDefaults
            UserDefaults.standard.removeObject(forKey: "CachedConversations")
            UserDefaults.standard.removeObject(forKey: "ChatRoomNamesCache")
            
            // Limpiar datos de clases (si existe instancia)
            ClassService.shared?.clearCache()
            
            // Limpiar perfil de usuario cacheado
            UserProfileService.shared.clear()
            
            // Limpiar datos de eventos se hace via NotificationCenter
            // EventService escucha .userDidLogout y limpia automáticamente
            
            // Limpiar OneSignal
            OneSignalService.shared.logout()
            
            // Limpiar UserDefaults específicos de usuario
            clearUserSpecificDefaults()
        }

        // Resetear proveedor de chat (desconecta y elimina estado)
        await ChatProviderManager.shared.reset()
        
        print("✅ Datos del usuario anterior limpiados")
    }
    
    // MARK: - User Profile Updates
    
    @MainActor
    func updateUserPicture(_ newPictureURL: String) {
        if let currentUser = user {
            // Crear nueva instancia con picture actualizada
            let updatedUser = AuthUser(
                id: currentUser.id,
                email: currentUser.email,
                name: currentUser.name,
                picture: newPictureURL,
                isCoach: currentUser.isCoach
            )
            self.user = updatedUser
            print("✅ User picture updated locally: \(newPictureURL)")
        }
    }
    
    
    /// Limpia UserDefaults específicos del usuario
    private func clearUserSpecificDefaults() {
        let userDefaultsKeys = [
            "selectedGym",
            "hasSelectedGym",
            "CachedGyms",
            "lastChatMessagesUpdate",
            "lastChatMessagesData",
            "CachedMembershipStatus",
            "CachedMembershipDate",
            // Asegurar que se eliminen claves de chat persistentes
            "CachedConversations",
            "ChatRoomNamesCache"
        ]
        
        for key in userDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Buscar y limpiar claves con patrones específicos
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            if key.contains("CachedGymHours_") || 
               key.contains("CachedEvents_") ||
               key.contains("Chat_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Biometric Authentication (Temporarily Disabled)
    
    /// Check if biometric authentication is available on the device
    private func checkBiometricAvailability() {
        // Temporarily disabled - will be re-enabled after fixing LocalAuthentication imports
        biometricAuthAvailable = false
        biometricAuthEnabled = false
        print("⚠️ Autenticación biométrica temporalmente deshabilitada")
        return
        
        /* // Commented out until LocalAuthentication is properly imported
        var error: NSError?
        
        let isAvailable = biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        biometricAuthAvailable = isAvailable
        
        if isAvailable {
            let biometricType = biometricContext.biometryType
            switch biometricType {
            case .faceID:
                print("🔑 Face ID disponible")
            case .touchID:
                print("🔑 Touch ID disponible")
            case .opticID:
                print("🔑 Optic ID disponible")
            default:
                print("🔑 Autenticación biométrica disponible")
            }
            
            // Check if user has enabled biometric auth
            biometricAuthEnabled = UserDefaults.standard.bool(forKey: "biometric_auth_enabled")
        } else {
            print("❌ Autenticación biométrica no disponible: \(error?.localizedDescription ?? "Desconocido")")
            biometricAuthEnabled = false
        }
    }
    
    /// Enable or disable biometric authentication
    func setBiometricAuthEnabled(_ enabled: Bool) {
        biometricAuthEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "biometric_auth_enabled")
        print("🔑 Autenticación biométrica \(enabled ? "activada" : "desactivada")")
    }
    
    /// Attempt biometric authentication for quick login
    func attemptBiometricLogin() async -> Bool {
        guard biometricAuthAvailable && biometricAuthEnabled else {
            print("⚠️ Autenticación biométrica no disponible o no habilitada")
            return false
        }
        
        // Check if we have stored credentials
        guard KeychainService.shared.getToken(type: .accessToken) != nil else {
            print("⚠️ No hay tokens almacenados para autenticación biométrica")
            return false
        }
        
        do {
            let biometricType = biometricContext.biometryType
            var reason: String
            
            switch biometricType {
            case .faceID:
                reason = "Usa Face ID para acceder rápidamente a tu cuenta"
            case .touchID:
                reason = "Usa Touch ID para acceder rápidamente a tu cuenta"
            case .opticID:
                reason = "Usa Optic ID para acceder rápidamente a tu cuenta"
            default:
                reason = "Usa tu biometría para acceder rápidamente a tu cuenta"
            }
            
            let success = try await biometricContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                print("✅ Autenticación biométrica exitosa")
                // Re-check auth status to validate stored tokens
                checkAuthStatus()
                return isAuthenticated
            } else {
                print("❌ Autenticación biométrica fallida")
                return false
            }
            
        } catch {
            print("❌ Error en autenticación biométrica: \(error.localizedDescription)")
            
            if let laError = error as? LAError {
                switch laError.code {
                case .userCancel:
                    print("🚫 Usuario canceló autenticación biométrica")
                case .userFallback:
                    print("🔄 Usuario eligió fallback (contraseña)")
                case .biometryNotAvailable:
                    print("⚠️ Biometría no disponible")
                    biometricAuthAvailable = false
                case .biometryNotEnrolled:
                    print("⚠️ Biometría no configurada")
                case .biometryLockout:
                    print("🔒 Biometría bloqueada - demasiados intentos")
                default:
                    print("❌ Error biométrico desconocido: \(laError.localizedDescription)")
                }
            }
            
            return false
        }
        */
    }
    
    /// Enable or disable biometric authentication
    func setBiometricAuthEnabled(_ enabled: Bool) {
        // Temporarily disabled
        biometricAuthEnabled = false
        print("⚠️ setBiometricAuthEnabled temporalmente deshabilitado")
    }
    
    /// Attempt biometric authentication for quick login
    func attemptBiometricLogin() async -> Bool {
        // Temporarily disabled
        print("⚠️ attemptBiometricLogin temporalmente deshabilitado")
        return false
    }
    
    /// Get the type of biometric authentication available
    var biometricTypeString: String {
        return "No disponible (temporalmente deshabilitado)"
    }
    
    // MARK: - Enhanced Login with Retry
    
    /// Enhanced login with network retry logic
    func loginWithRetry() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let credentials = try await NetworkRetryService.shared.executeWithRetry {
                try await Auth0
                    .webAuth()
                    .audience(Auth0Config.audience)
                    .scope("openid profile email")
                    .start()
            }
            
            // Process successful login
            await processSuccessfulLogin(credentials)
            
        } catch NetworkRetryService.RetryError.maxRetriesExceeded {
            print("❌ Login falló después de múltiples intentos")
            errorMessage = "Error de conexión. Verifica tu internet e intenta nuevamente."
        } catch NetworkRetryService.RetryError.circuitBreakerOpen {
            print("❌ Circuit breaker abierto - servicio no disponible")
            errorMessage = "Servicio temporalmente no disponible. Intenta en unos minutos."
        } catch {
            print("❌ Error inesperado en login: \(error)")
            errorMessage = "Error de inicio de sesión: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Process successful login credentials
    private func processSuccessfulLogin(_ credentials: Auth0.Credentials) async {
        // Extract user info from ID token
        if let jwt = try? decode(jwt: credentials.idToken) {
            let userId = jwt.subject ?? "unknown_user"
            let userEmail = jwt["email"].string ?? "unknown@example.com"
            let userName = jwt["name"].string ?? "Usuario"
            let userPicture = jwt["picture"].string
            
            let user = AuthUser(
                id: userId,
                email: userEmail,
                name: userName,
                picture: userPicture,
                isCoach: false
            )
            
            self.user = user
            self.isAuthenticated = true
            
            // Save credentials securely
            saveCredentials(credentials)
            saveUserInfo(user)
            
            // Marcar que aún no se hizo el refresh de primer login
            UserDefaults.standard.set(false, forKey: firstLoginRefreshKey)
            
            // Programar un refresh forzado para capturar permisos que llegan tarde (issue conocido de Auth0)
            scheduleFirstLoginPermissionsRefresh()
            
            print("✅ Login exitoso con retry logic")
            print("🔹 Usuario: \(user.name)")
            print("🔹 Email: \(user.email)")
            
        } else {
            errorMessage = "Error: respuesta inválida de Auth0"
            return
        }
    }
}

// MARK: - Errores de Autenticación
// AuthError ya está definido en AuthService.swift 
 
