//
//  AuthServiceAPI_Safe.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//
//  VERSIÓN SEGURA para evitar crashes SIGTERM
//  Usar esta versión si hay problemas con AuthServiceAPI.swift

import Foundation
import SwiftUI

@MainActor
class AuthServiceAPI_Safe: ObservableObject, AuthServiceProtocol {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // URLs simplificadas
    private let backendBaseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let isDevelopmentMode = true
    
    init() {
        print("🔧 AuthServiceAPI_Safe inicializado")
    }
    
    func login() async {
        print("🔧 Iniciando login seguro...")
        
        isLoading = true
        errorMessage = nil
        
        // Simular delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 segundos
        
        // Simular usuario autenticado exitoso
        let mockUser = User(
            id: "safe_user_123",
            email: "alex@gymapi.com",
            name: "Alex Montesino (Safe Mode)",
            picture: nil,
            isCoach: true
        )
        
        self.user = mockUser
        self.isAuthenticated = true
        
        // Guardar token simple
        UserDefaults.standard.set("safe_token_123", forKey: "access_token")
        
        print("✅ Login seguro completado")
        isLoading = false
    }
    
    func logout() async {
        print("🔧 Logout seguro...")
        
        isAuthenticated = false
        user = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
        
        print("✅ Logout seguro completado")
    }
    
    func checkAuthStatus() {
        print("🔧 Verificando estado de autenticación...")
        
        if let _ = UserDefaults.standard.string(forKey: "access_token") {
            print("✅ Token encontrado, usuario autenticado")
            isAuthenticated = true
        } else {
            print("❌ No hay token, usuario no autenticado")
            isAuthenticated = false
        }
    }
    
    // MARK: - AuthServiceProtocol Implementation
    func getValidAccessToken() async -> String? {
        // En modo seguro, devolver el token guardado
        if let token = UserDefaults.standard.string(forKey: "access_token") {
            print("🎫 Token obtenido desde AuthServiceAPI_Safe: \(token)")
            return token
        }
        
        print("⚠️ No se encontró token en AuthServiceAPI_Safe")
        return nil
    }
    
    // Métodos de debug simplificados
    func testConnectivity() async {
        print("🔍 Test de conectividad (modo seguro)...")
        print("✅ Conectividad simulada OK")
    }
    
    func testAPIEndpoint() async {
        print("🔍 Test de API (modo seguro)...")
        print("✅ API simulada OK")
    }
    
    func simulateLogin() async {
        print("🔧 Simulación de login (modo seguro)...")
        await login()
    }
} 