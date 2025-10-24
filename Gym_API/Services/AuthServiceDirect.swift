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
import OneSignalFramework

// MARK: - Auth Mode
enum AuthMode {
    case signin
    case signup
}

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
    @Published var isRefreshingToken = false
    @Published var errorMessage: String?
    @Published var biometricAuthAvailable = false
    @Published var biometricAuthEnabled = false
    
    // Control de refresh de primer login (para permisos de Auth0)
    private let firstLoginRefreshKey = "auth0_first_login_refreshed"
    
    // Detección de loops de renovación
    private var tokenRefreshAttempts: Int = 0
    private var lastTokenRefreshTime: Date?
    private let maxRefreshAttemptsInWindow = 3
    private let refreshWindowMinutes: TimeInterval = 5 * 60 // 5 minutos
    private let offlineAccessGrantedKey = "auth0_offline_access_granted"
    
    // Auth0 Credentials Manager para manejo automático de tokens
    private var credentialsManager: CredentialsManager?
    
    // Authorization Code y State para reintentos
    private var lastAuthorizationCode: String?
    private var lastAuthorizationState: String?
    private var lastCodeVerifier: String?
    private let authCodeKey = "auth0_last_auth_code"
    private let authStateKey = "auth0_last_auth_state"
    private let codeVerifierKey = "auth0_last_code_verifier"
    
    // Métricas de autenticación
    private var refreshTokenSuccessCount = 0
    private var refreshTokenFailureCount = 0
    private var codeExchangeRetryCount = 0
    
    // Biometric authentication context - temporarily disabled
    // private let biometricContext = LAContext()
    
    init() {
        // Initialize Credentials Manager with custom storage
        setupCredentialsManager()
        
        // Migrate tokens if needed
        if !KeychainService.shared.hasMigratedToKeychain {
            KeychainService.shared.migrateFromUserDefaults()
        }
        
        // Load any saved authorization data
        loadSavedAuthorizationData()
        
        // Temporarily disabled: checkBiometricAvailability()
        checkAuthStatus()
    }
    
    private func syncExistingTokensToCredentialsManager() {
        print("\n🔄 SINCRONIZACIÓN INICIAL DE TOKENS")
        print("================================")
        
        guard let accessToken = KeychainService.shared.getToken(type: .accessToken),
              !accessToken.isEmpty else {
            print("ℹ️ No hay tokens existentes en Keychain para sincronizar")
            print("================================\n")
            return
        }
        
        print("🔍 Tokens encontrados en Keychain:")
        print("   - Access Token: \(String(accessToken.prefix(20)))...")
        
        let refreshToken = KeychainService.shared.getToken(type: .refreshToken)
        let idToken = KeychainService.shared.getToken(type: .idToken)
        
        // Crear objeto Credentials con los tokens existentes
        let credentials = Credentials(
            accessToken: accessToken,
            tokenType: "Bearer",
            idToken: idToken ?? "",
            refreshToken: refreshToken,
            expiresIn: Date(timeIntervalSinceNow: 3600), // 1 hora por defecto
            scope: "openid profile email offline_access"
        )
        
        // Guardar en Credentials Manager
        if let credentialsManager = credentialsManager {
            let stored = credentialsManager.store(credentials: credentials)
            if stored {
                print("✅ Tokens guardados en Credentials Manager")
                
                // Verificar que se pueden recuperar
                credentialsManager.credentials { result in
                    switch result {
                    case .success(let creds):
                        print("✅ VERIFICACIÓN EXITOSA")
                        print("   - Credentials Manager puede recuperar los tokens")
                        print("   - Access Token válido: \(String(creds.accessToken.prefix(20)))...")
                        print("   - Refresh Token presente: \(creds.refreshToken != nil ? "✅" : "❌")")
                        print("================================\n")
                    case .failure(let error):
                        print("❌ VERIFICACIÓN FALLIDA")
                        print("   - Error: \(error.localizedDescription)")
                        print("   - Los tokens permanecen en Keychain como respaldo")
                        print("================================\n")
                    }
                }
            } else {
                print("⚠️ No se pudieron guardar en Credentials Manager")
                print("   - Los tokens permanecen solo en Keychain")
                print("================================\n")
            }
        }
    }
    
    private func setupCredentialsManager() {
        credentialsManager = CredentialsManager(
            authentication: Auth0.authentication()
        )
        
        // Enable biometric authentication for credentials access if available
        // credentialsManager?.enableBiometrics(withTitle: "Access your gym account")
        
        print("✅ Credentials Manager configurado")
        print("🔧 Configuración:")
        print("   - Dominio: \(Auth0Config.domain)")
        print("   - Cliente ID: \(Auth0Config.clientId)")
        print("   - Almacenamiento: iOS Keychain (predeterminado)")
        
        // Sincronizar tokens existentes del Keychain con Credentials Manager
        syncExistingTokensToCredentialsManager()
    }
    
    private func loadSavedAuthorizationData() {
        lastAuthorizationCode = KeychainService.shared.getToken(type: .accessToken) != nil ? 
            UserDefaults.standard.string(forKey: authCodeKey) : nil
        lastAuthorizationState = UserDefaults.standard.string(forKey: authStateKey)
        lastCodeVerifier = UserDefaults.standard.string(forKey: codeVerifierKey)
        
        if lastAuthorizationCode != nil {
            print("📦 Authorization code guardado encontrado")
        }
    }
    
    func login(mode: AuthMode = .signin) async {
        isLoading = true
        errorMessage = nil
        
        // Validar configuración antes de intentar login
        guard validateAuth0Configuration() else {
            errorMessage = "Configuración de Auth0 inválida. Contacta al soporte."
            isLoading = false
            return
        }
        
        do {
            print("🔧 Iniciando autenticación con Auth0...")
            print("🔹 Modo: \(mode == .signup ? "Registro" : "Inicio de sesión")")
            print("🔹 Dominio: \(Auth0Config.domain)")
            print("🔹 Cliente ID: \(Auth0Config.clientId)")
            print("🔹 Audiencia: \(Auth0Config.audience)")
            print("🔹 Refresh Token Rotation: Habilitado (recomendado)")
            print("🔹 PKCE: Habilitado (obligatorio para apps móviles)")
            
            // Configurar Auth0 con esquema personalizado y audiencia
            // Solo forzar consentimiento si NUNCA hemos concedido offline_access
            let neverGrantedOffline = !UserDefaults.standard.bool(forKey: offlineAccessGrantedKey)
            let needsRefreshToken = KeychainService.shared.getToken(type: .refreshToken) == nil
            
            // Log del callback URL esperado
            let bundleId = Bundle.main.bundleIdentifier ?? "com.alexmontesino.gymapi"
            let redirectUri = "\(bundleId)://\(Auth0Config.domain)/ios/\(bundleId)/callback"
            print("🔗 Bundle ID: \(bundleId)")
            print("🔗 Client ID: \(Auth0Config.clientId)")
            print("🔗 Redirect URI configurado: \(redirectUri)")
            
            var webAuth = Auth0
                .webAuth()
                .audience(Auth0Config.audience)
                .scope("openid profile email offline_access")
                .redirectURL(URL(string: redirectUri)!)
            
            // Añadir screen_hint según el modo
            var parameters: [String: String] = [:]
            parameters["screen_hint"] = mode == .signup ? "signup" : "login"
            
            if needsRefreshToken && neverGrantedOffline {
                parameters["prompt"] = "consent" // Forzar consentimiento solo la primera vez
            }
            
            // Habilitar PKCE explícitamente (aunque es default en Auth0 SDK)
            webAuth = webAuth
                .parameters(parameters)
                .useEphemeralSession() // Usar sesión efímera para mayor seguridad
            
            print("🔐 Iniciando flujo de autenticación con PKCE...")
            let credentials = try await webAuth.start()
            
            // Guardar las credenciales usando Credentials Manager
            let stored = credentialsManager?.store(credentials: credentials) ?? false
            print("📦 Credenciales guardadas en Credentials Manager: \(stored)")
            // Debug: Log presence of refresh token from Auth0 response (no secrets)
            #if DEBUG
            if let rt = credentials.refreshToken {
                print("🔁 Auth0 login: refresh_token received (length=\(rt.count), head=\(rt.prefix(6))…)")
                UserDefaults.standard.set(true, forKey: offlineAccessGrantedKey)
            } else {
                print("⚠️ Auth0 login: refresh_token NOT present in credentials response")
            }
            #endif
            
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
            
            // Log detallado del error para debugging de Auth0
            print("🔴 Tipo de error: \(type(of: error))")
            print("🔴 Descripción del error: \(error.localizedDescription)")
            
            // Verificar si es un error de cancelación
            let errorString = "\(error)"
            if errorString.contains("cancelled") || errorString.contains("a0.session.user_cancelled") || 
               errorString.contains("userCancelled") || error.localizedDescription.contains("cancelled") {
                print("ℹ️ Usuario canceló el login")
                errorMessage = nil // No mostrar error si el usuario canceló
                isLoading = false
                return
            }
            
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
        
        Task {
            await checkAuthStatusAsync()
        }
    }
    
    private func checkAuthStatusAsync() async {
        print("\n🔐 VERIFICACIÓN DE ESTADO DE AUTENTICACIÓN")
        print("==========================================")
        
        // Primero intentar con Credentials Manager
        if let credentialsManager = credentialsManager {
            print("📱 Paso 1: Intentando Credentials Manager...")
            
            let semaphore = DispatchSemaphore(value: 0)
            var retrievedToken: String?
            
            credentialsManager.credentials { result in
                defer { semaphore.signal() }
                
                switch result {
                case .success(let credentials):
                    print("✅ Credenciales recuperadas de Credentials Manager")
                    print("   - Access Token: \(String(credentials.accessToken.prefix(20)))...")
                    print("   - Token válido hasta: \(credentials.expiresIn)")
                    // Sincronizar con Keychain si es necesario
                    Task { @MainActor in
                        self.syncCredentialsToKeychain(credentials)
                    }
                    retrievedToken = credentials.accessToken
                    
                case .failure(let error):
                    print("⚠️ Credentials Manager no tiene credenciales")
                    print("   - Razón: \(error.localizedDescription)")
                    print("   - Continuando con Keychain fallback...")
                }
            }
            
            _ = semaphore.wait(timeout: .now() + 2.0) // Timeout de 2 segundos
            
            if let token = retrievedToken {
                // Verificar si el token está expirado
                if !isTokenExpired(token: token) {
                    print("✅ Token válido encontrado en Credentials Manager")
                    print("==========================================\n")
                    await setUserFromToken()
                    return
                } else {
                    print("⚠️ Token de Credentials Manager está expirado")
                }
            }
        }
        
        // Fallback: Verificar si hay credenciales almacenadas en Keychain
        print("🔑 Paso 2: Verificando Keychain...")
        guard let accessToken = getStoredCredentials() else {
            print("❌ No hay tokens almacenados en ningún sistema")
            print("   - Credentials Manager: Sin credenciales")
            print("   - Keychain: Sin tokens")
            print("   - Estado: Usuario debe iniciar sesión")
            print("==========================================\n")
            await MainActor.run {
                isAuthenticated = false
                user = nil
            }
            return
        }
        
        print("✅ Token encontrado en Keychain")
        print("   - Access Token: \(String(accessToken.prefix(20)))...")
        print("==========================================\n")
        
        // Si el token está expirado, NO intentar renovación automática al inicio
        // Solo limpiar las credenciales y requerir login manual
        if isTokenExpired(token: accessToken) {
            print("⚠️ Token expirado detectado en checkAuthStatus")
            print("🔄 Limpiando credenciales expiradas...")
            
            // Limpiar tokens expirados
            clearCredentials()
            
            await MainActor.run {
                isAuthenticated = false
                user = nil
                isRefreshingToken = false
            }
            
            print("ℹ️ Usuario debe iniciar sesión nuevamente")
            return
        } else {
            // Token válido, establecer usuario
            await setUserFromToken()
        }
        
        #if DEBUG
        KeychainService.shared.debugPrintTokens()
        #endif
    }
    
    private func setUserFromToken() async {
        // Intentar obtener información del usuario del ID token
        if let idToken = KeychainService.shared.getToken(type: .idToken),
           let jwt = try? decode(jwt: idToken) {
            // Extraer datos del JWT
            let userId = jwt.subject ?? "unknown_user"
            let userEmail = jwt["email"].string ?? "unknown@example.com"
            let userName = jwt["name"].string ?? "Usuario"
            let userPicture = jwt["picture"].string
            
            let authUser = AuthUser(
                id: userId,
                email: userEmail,
                name: userName,
                picture: userPicture,
                isCoach: false
            )
            
            await MainActor.run {
                self.user = authUser
                self.isAuthenticated = true
            }
            
            print("✅ Usuario autenticado desde ID token: \(userName)")
        } else {
            // Fallback: intentar cargar de UserDefaults (compatibilidad)
            guard let savedUserId = UserDefaults.standard.string(forKey: "saved_user_id"),
                  let savedUserEmail = UserDefaults.standard.string(forKey: "saved_user_email"),
                  let savedUserName = UserDefaults.standard.string(forKey: "saved_user_name") else {
                print("❌ No hay información de usuario disponible")
                await MainActor.run {
                    isAuthenticated = false
                    user = nil
                }
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
            
            await MainActor.run {
                self.user = savedUser
                self.isAuthenticated = true
            }
            
            print("✅ Usuario autenticado desde UserDefaults (compatibilidad)")
        }
        
        print("✅ Usuario autenticado: \(user?.name ?? "Usuario")")
        print("🔹 Token válido hasta: \(getTokenExpirationDate())")
    }
    
    // MARK: - Gestión de Credenciales
    
    private func saveCredentials(_ credentials: Credentials) {
        // Guardar tokens de forma segura en Keychain
        KeychainService.shared.saveToken(credentials.accessToken, type: .accessToken)
        KeychainService.shared.saveToken(credentials.idToken, type: .idToken)
        if let refreshToken = credentials.refreshToken {
            KeychainService.shared.saveToken(refreshToken, type: .refreshToken)
        }
        
        // Sincronizar con Credentials Manager de Auth0
        if let credentialsManager = credentialsManager {
            let stored = credentialsManager.store(credentials: credentials)
            print("🔄 Sincronización con Credentials Manager: \(stored ? "✅ Exitosa" : "❌ Falló")")
            
            #if DEBUG
            // Verificar que las credenciales se guardaron correctamente
            if stored {
                Task {
                    do {
                        _ = try await credentialsManager.credentials()
                        print("✅ Verificación: Credentials Manager puede recuperar las credenciales")
                    } catch {
                        print("⚠️ Verificación: Credentials Manager no puede recuperar las credenciales: \(error)")
                    }
                }
            }
            #endif
        } else {
            print("⚠️ Credentials Manager no está inicializado - usando solo Keychain")
        }
        
        // Mantener fecha de login en UserDefaults (no es sensible)
        UserDefaults.standard.set(Date(), forKey: "auth0_login_date")
    }
    
    private func syncCredentialsToKeychain(_ credentials: Credentials) {
        print("🔄 Sincronizando credenciales de Credentials Manager a Keychain...")
        
        // Guardar en Keychain si no existen o son diferentes
        let existingAccessToken = KeychainService.shared.getToken(type: .accessToken)
        
        if existingAccessToken != credentials.accessToken {
            KeychainService.shared.saveToken(credentials.accessToken, type: .accessToken)
            print("✅ Access token sincronizado a Keychain")
        }
        
        if !credentials.idToken.isEmpty {
            let existingIdToken = KeychainService.shared.getToken(type: .idToken)
            if existingIdToken != credentials.idToken {
                KeychainService.shared.saveToken(credentials.idToken, type: .idToken)
                print("✅ ID token sincronizado a Keychain")
            }
        }
        
        if let refreshToken = credentials.refreshToken, !refreshToken.isEmpty {
            let existingRefreshToken = KeychainService.shared.getToken(type: .refreshToken)
            if existingRefreshToken != refreshToken {
                KeychainService.shared.saveToken(refreshToken, type: .refreshToken)
                print("✅ Refresh token sincronizado a Keychain")
            }
        }
        
        print("✅ Sincronización Credentials Manager → Keychain completada")
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
        
        // Primero intentar con Credentials Manager (maneja renovación automática)
        if let credentialsManager = credentialsManager {
            do {
                let credentials = try await credentialsManager.credentials()
                print("✅ Token obtenido de Credentials Manager")
                
                // Guardar tokens actualizados en Keychain
                saveCredentials(credentials)
                
                // Actualizar métricas
                refreshTokenSuccessCount += 1
                logAuthMetrics()
                
                return credentials.accessToken
            } catch {
                print("⚠️ Credentials Manager falló: \(error.localizedDescription)")
                refreshTokenFailureCount += 1
                
                // Si falla, continuar con el flujo manual
            }
        }
        
        // Fallback al flujo manual existente
        guard let token = getStoredCredentials() else {
            print("❌ No hay token almacenado")
            return nil
        }
        
        // Si el token está realmente expirado, intentar renovación
        if isTokenExpired(token: token) {
            print("🔄 Token expirado, intentando renovar con múltiples estrategias...")
            
            // Estrategia 1: Renovar con refresh token
            if let renewedToken = await renewTokenIfNeeded() {
                print("✅ Token renovado exitosamente con refresh token")
                refreshTokenSuccessCount += 1
                logAuthMetrics()
                return renewedToken
            }
            
            // Estrategia 2: Intentar con authorization code guardado si existe
            if let renewedToken = await retryWithAuthorizationCode() {
                print("✅ Token renovado exitosamente con authorization code")
                codeExchangeRetryCount += 1
                logAuthMetrics()
                return renewedToken
            }
            
            print("❌ Todas las estrategias de renovación fallaron")
            return nil
        }
        
        // Si el token expira pronto, renovar proactivamente pero devolver el actual si falla
        if isTokenExpiringSoon(token: token) {
            print("🔄 Token expira pronto, renovando proactivamente...")
            if let renewedToken = await renewTokenIfNeeded() {
                print("✅ Token renovado proactivamente")
                refreshTokenSuccessCount += 1
                logAuthMetrics()
                return renewedToken
            } else {
                print("⚠️ Falló renovación proactiva, usando token actual")
                return token // Usar token actual si la renovación proactiva falla
            }
        }
        
        // Token válido y no expira pronto
        print("✅ Token válido encontrado")
        return token
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
        
        // Token realmente expirado (sin buffer para evitar falsos positivos)
        let isExpired = now >= expirationDate
        
        if isExpired {
            print("❌ Token realmente expirado (expiró: \(expirationDate))")
        } else {
            let timeRemaining = expirationDate.timeIntervalSince(now)
            let minutes = Int(timeRemaining / 60)
            let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
            print("✅ Token válido por \(minutes)m \(seconds)s más")
        }
        
        return isExpired
    }
    
    private func isTokenExpiringSoon(token: String) -> Bool {
        // Decodificar el JWT para obtener la expiración real
        guard let jwt = try? decode(jwt: token) else {
            print("⚠️ No se pudo decodificar el JWT para verificar renovación")
            return true
        }
        
        // Obtener el claim 'exp' del JWT
        guard let exp = jwt["exp"].double else {
            print("⚠️ No se encontró el claim 'exp' en el JWT")
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let now = Date()
        
        // Necesita renovación si queda menos de 2 minutos (buffer más conservador)
        let renewalBufferTime: TimeInterval = 2 * 60 // 2 minutos
        let needsRenewal = now.addingTimeInterval(renewalBufferTime) > expirationDate
        
        if needsRenewal {
            let timeRemaining = expirationDate.timeIntervalSince(now)
            let minutes = Int(timeRemaining / 60)
            let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
            print("🔄 Token necesita renovación (expira en \(minutes)m \(seconds)s)")
        }
        
        return needsRenewal
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
        // Verificar si estamos en un loop de renovación
        if await isInTokenRefreshLoop() {
            print("🔴 Detectado loop de renovación de token - aplicando fallback")
            await handleTokenRefreshLoop()
            return nil
        }
        
        guard let refreshToken = KeychainService.shared.getToken(type: .refreshToken) else {
            print("❌ No hay refresh token disponible en Keychain")
            // Si no hay refresh token, necesitamos re-autenticar
            await logout()
            return nil
        }
        
        // Registrar intento de renovación
        await recordTokenRefreshAttempt()
        
        // Marcar que estamos renovando (si no está ya marcado)
        await MainActor.run {
            if !isRefreshingToken {
                isRefreshingToken = true
            }
        }
        
        print("🔄 Intentando renovar token con retry logic... (intento \(tokenRefreshAttempts))")
        
        do {
            let credentials = try await NetworkRetryService.shared.executeTokenRefresh(refreshToken: refreshToken)
            
            // Guardar las nuevas credenciales
            saveCredentials(credentials)
            
            // Reset loop detection en caso de éxito
            await resetTokenRefreshLoop()
            
            await MainActor.run {
                isRefreshingToken = false
            }
            
            print("✅ Token renovado exitosamente con retry logic")
            print("🔹 Nuevo token (primeros 50 chars): \(credentials.accessToken.prefix(50))...")
            #if DEBUG
            if let newRT = credentials.refreshToken {
                print("🔁 Auth0 refresh: new refresh_token received (length=\(newRT.count), head=\(newRT.prefix(6))…)")
            } else {
                print("ℹ️ Auth0 refresh: response did not include a new refresh_token (rotation may be disabled or unchanged)")
            }
            #endif
            
            return credentials.accessToken
            
        } catch NetworkRetryService.RetryError.maxRetriesExceeded {
            print("❌ Falló renovación después de múltiples intentos")
            await MainActor.run {
                isRefreshingToken = false
                errorMessage = "Error de conexión. Intenta más tarde."
            }
        } catch NetworkRetryService.RetryError.nonRetryableError(let underlyingError) {
            print("❌ Error no recuperable al renovar token: \(underlyingError)")
            
            // Manejar errores específicos de Auth0
            let errorType = categorizeAuth0Error(underlyingError)
            
            await MainActor.run {
                isRefreshingToken = false
                
                switch errorType {
                case .invalidGrant:
                    print("❌ Refresh token inválido o expirado")
                    errorMessage = "Tu sesión ha expirado completamente. Por favor, inicia sesión nuevamente."
                    refreshTokenFailureCount += 1
                    
                case .consentRequired:
                    print("⚠️ Se requiere consentimiento del usuario")
                    errorMessage = "Necesitas autorizar nuevamente los permisos de la aplicación."
                    
                case .networkError:
                    print("🌐 Error de red al renovar token")
                    errorMessage = "Error de conexión. Verifica tu internet e intenta nuevamente."
                    
                case .rateLimited:
                    print("⏳ Rate limit alcanzado")
                    errorMessage = "Demasiados intentos. Espera un momento antes de intentar nuevamente."
                    
                case .serverError:
                    print("🔴 Error del servidor Auth0")
                    errorMessage = "El servicio de autenticación está temporalmente no disponible."
                    
                case .unknown:
                    errorMessage = "Error de autenticación: \(underlyingError.localizedDescription)"
                }
            }
        } catch {
            print("❌ Error inesperado al renovar token: \(error)")
            await MainActor.run {
                isRefreshingToken = false
                errorMessage = "Error inesperado: \(error.localizedDescription)"
                refreshTokenFailureCount += 1
            }
        }
        
        // Si falla la renovación, cerrar sesión
        await logout()
        return nil
    }
    
    // MARK: - Loop Detection and Fallback
    
    private func isInTokenRefreshLoop() async -> Bool {
        let now = Date()
        
        // Si no hay registro previo, no hay loop
        guard let lastRefresh = lastTokenRefreshTime else {
            return false
        }
        
        // Si han pasado más de X minutos desde el último intento, reset
        if now.timeIntervalSince(lastRefresh) > refreshWindowMinutes {
            await resetTokenRefreshLoop()
            return false
        }
        
        // Si hemos hecho demasiados intentos en poco tiempo, es un loop
        return tokenRefreshAttempts >= maxRefreshAttemptsInWindow
    }
    
    private func recordTokenRefreshAttempt() async {
        await MainActor.run {
            tokenRefreshAttempts += 1
            lastTokenRefreshTime = Date()
            print("🔄 Registrando intento de renovación #\(tokenRefreshAttempts)")
        }
    }
    
    private func resetTokenRefreshLoop() async {
        await MainActor.run {
            tokenRefreshAttempts = 0
            lastTokenRefreshTime = nil
            print("✅ Reset loop detection de renovación de tokens")
        }
    }
    
    private func handleTokenRefreshLoop() async {
        print("🔴 Manejando loop de renovación - limpiando tokens y forzando re-login")
        
        // Limpiar todos los tokens
        KeychainService.shared.deleteAllTokens()
        
        // Reset de variables de estado
        await MainActor.run {
            isAuthenticated = false
            user = nil
            isRefreshingToken = false
            errorMessage = "Se detectó un problema con la sesión. Por favor, inicia sesión nuevamente."
        }
        
        // Reset loop detection
        await resetTokenRefreshLoop()
        
        // Limpiar UserDefaults de usuario
        UserDefaults.standard.removeObject(forKey: "saved_user_id")
        UserDefaults.standard.removeObject(forKey: "saved_user_email")
        UserDefaults.standard.removeObject(forKey: "saved_user_name")
        UserDefaults.standard.removeObject(forKey: "saved_user_picture")
        UserDefaults.standard.removeObject(forKey: "saved_user_is_coach")
        
        // Limpiar authorization code guardado
        UserDefaults.standard.removeObject(forKey: authCodeKey)
        UserDefaults.standard.removeObject(forKey: authStateKey)
        UserDefaults.standard.removeObject(forKey: codeVerifierKey)
        
        print("🔄 Limpieza completa realizada - usuario debe re-autenticarse")
    }
    
    // MARK: - Authorization Code Retry
    
    private func retryWithAuthorizationCode() async -> String? {
        guard let code = lastAuthorizationCode,
              let verifier = lastCodeVerifier else {
            print("❌ No hay authorization code guardado para reintentar")
            return nil
        }
        
        print("🔄 Reintentando con authorization code guardado...")
        
        do {
            // Intentar intercambiar el código por tokens
            let credentials = try await Auth0
                .authentication()
                .codeExchange(
                    withCode: code,
                    codeVerifier: verifier,
                    redirectURI: "\(Bundle.main.bundleIdentifier ?? "com.alexmontesino.gymapi")://\(Auth0Config.domain)/ios/\(Bundle.main.bundleIdentifier ?? "com.alexmontesino.gymapi")/callback"
                )
                .start()
            
            // Guardar las nuevas credenciales
            saveCredentials(credentials)
            credentialsManager?.store(credentials: credentials)
            
            // Limpiar el código usado
            lastAuthorizationCode = nil
            lastCodeVerifier = nil
            UserDefaults.standard.removeObject(forKey: authCodeKey)
            UserDefaults.standard.removeObject(forKey: codeVerifierKey)
            
            print("✅ Authorization code exchange exitoso")
            return credentials.accessToken
            
        } catch {
            print("❌ Falló el intercambio de authorization code: \(error)")
            
            // Si el código es inválido o expiró, limpiarlo
            if error.localizedDescription.contains("invalid_grant") || 
               error.localizedDescription.contains("expired") {
                lastAuthorizationCode = nil
                lastCodeVerifier = nil
                UserDefaults.standard.removeObject(forKey: authCodeKey)
                UserDefaults.standard.removeObject(forKey: codeVerifierKey)
            }
            
            return nil
        }
    }
    
    // MARK: - Authentication Metrics
    
    private func logAuthMetrics() {
        #if DEBUG
        print("\n📊 Métricas de Autenticación:")
        print("================================")
        print("✅ Refresh Token Exitosos: \(refreshTokenSuccessCount)")
        print("❌ Refresh Token Fallidos: \(refreshTokenFailureCount)")
        print("🔄 Code Exchange Reintentos: \(codeExchangeRetryCount)")
        print("📈 Tasa de éxito: \(calculateSuccessRate())%")
        print("================================\n")
        #endif
    }
    
    private func calculateSuccessRate() -> String {
        let total = refreshTokenSuccessCount + refreshTokenFailureCount
        guard total > 0 else { return "N/A" }
        let rate = (Double(refreshTokenSuccessCount) / Double(total)) * 100
        return String(format: "%.1f", rate)
    }
    
    // MARK: - Auth0 Configuration Validation
    
    private func validateAuth0Configuration() -> Bool {
        // Validar que los valores de configuración no estén vacíos
        guard !Auth0Config.domain.isEmpty,
              !Auth0Config.clientId.isEmpty,
              !Auth0Config.audience.isEmpty else {
            print("❌ Configuración de Auth0 incompleta")
            return false
        }
        
        // Validar formato del dominio
        guard Auth0Config.domain.contains(".auth0.com") || 
              Auth0Config.domain.contains(".us.auth0.com") ||
              Auth0Config.domain.contains(".eu.auth0.com") ||
              Auth0Config.domain.contains(".au.auth0.com") else {
            print("❌ Dominio de Auth0 inválido: \(Auth0Config.domain)")
            return false
        }
        
        // Validar formato de la audiencia (debe ser una URL)
        if !Auth0Config.audience.hasPrefix("https://") && 
           !Auth0Config.audience.hasPrefix("http://") {
            print("⚠️ Audiencia no parece ser una URL válida: \(Auth0Config.audience)")
            // No fallar aquí porque algunas APIs usan identificadores custom
        }
        
        print("✅ Configuración de Auth0 validada correctamente")
        return true
    }
    
    // MARK: - Error Categorization
    
    enum Auth0ErrorType {
        case invalidGrant
        case consentRequired
        case networkError
        case rateLimited
        case serverError
        case unknown
    }
    
    private func categorizeAuth0Error(_ error: Error) -> Auth0ErrorType {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("invalid_grant") ||
           errorDescription.contains("refresh token") && errorDescription.contains("expired") {
            return .invalidGrant
        }
        
        if errorDescription.contains("consent_required") ||
           errorDescription.contains("consent required") {
            return .consentRequired
        }
        
        if errorDescription.contains("rate") && errorDescription.contains("limit") ||
           errorDescription.contains("too many requests") {
            return .rateLimited
        }
        
        if errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("internet") {
            return .networkError
        }
        
        if errorDescription.contains("500") ||
           errorDescription.contains("502") ||
           errorDescription.contains("503") ||
           errorDescription.contains("server error") {
            return .serverError
        }
        
        return .unknown
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
            // Esperar más tiempo para evitar conflictos con la autenticación principal
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s (aumentado de 2s)
            
            // Solo ejecutar si el usuario sigue autenticado y no estamos renovando
            guard let self = self else { return }
            
            await MainActor.run {
                // No ejecutar si ya estamos renovando tokens o no estamos autenticados
                if self.isRefreshingToken || !self.isAuthenticated {
                    print("⏭️ Saltando firstLoginRefresh - token en renovación o no autenticado")
                    return
                }
            }
            
            await self.performFirstLoginForcedRefreshIfNeeded()
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
    func loginWithRetry(mode: AuthMode = .signin) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // NO usar NetworkRetryService para Auth0 - evita reintentos cuando el usuario cancela
            let neverGrantedOffline = !UserDefaults.standard.bool(forKey: self.offlineAccessGrantedKey)
            let needsRefreshToken = KeychainService.shared.getToken(type: .refreshToken) == nil
            var webAuth = Auth0
                .webAuth()
                .audience(Auth0Config.audience)
                .scope("openid profile email offline_access")
            
            // Añadir screen_hint según el modo
            var parameters: [String: String] = [:]
            parameters["screen_hint"] = mode == .signup ? "signup" : "login"
            
            if needsRefreshToken && neverGrantedOffline {
                parameters["prompt"] = "consent" // Forzar consentimiento solo la primera vez
            }
            
            webAuth = webAuth.parameters(parameters)
            let credentials = try await webAuth.start()
            
            // Process successful login
            await processSuccessfulLogin(credentials)
            
        } catch {
            // Verificar si el usuario canceló
            let errorString = "\(error)"
            if errorString.contains("cancelled") || errorString.contains("a0.session.user_cancelled") || 
               errorString.contains("userCancelled") || error.localizedDescription.contains("cancelled") {
                print("ℹ️ Usuario canceló el login")
                errorMessage = nil // No mostrar error si el usuario canceló
            } else {
                print("❌ Error inesperado en login: \(error)")
                errorMessage = "Error de inicio de sesión: \(error.localizedDescription)"
            }
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
            #if DEBUG
            if let rt = credentials.refreshToken {
                print("🔁 Auth0 login (retry): refresh_token received (length=\(rt.count), head=\(rt.prefix(6))…)")
            } else {
                print("⚠️ Auth0 login (retry): refresh_token NOT present in credentials response")
            }
            #endif
            
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

    deinit {
        #if DEBUG
        print("🗑️ AuthServiceDirect deinitialized")
        #endif
        // Los tokens y datos se limpiarán automáticamente con ARC
        // No podemos modificar propiedades desde deinit en una clase @MainActor
    }
}

// MARK: - Errores de Autenticación
// AuthError ya está definido en AuthService.swift 
 
