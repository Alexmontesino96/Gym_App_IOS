//
//  AuthService.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://\(Auth0Config.domain)"
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loginResponse = try await performLogin(email: email, password: password)
            
            if let accessToken = loginResponse.accessToken {
                let userInfo = try await fetchUserInfo(accessToken: accessToken)
                
                // Crear o actualizar usuario en la base de datos local
                let user = User(
                    id: userInfo.sub,
                    email: userInfo.email,
                    name: userInfo.name,
                    picture: userInfo.picture
                )
                
                self.user = user
                self.isAuthenticated = true
                
                // Guardar token en Keychain (simulado)
                UserDefaults.standard.set(accessToken, forKey: "access_token")
            }
        } catch {
            errorMessage = "Error de autenticación: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func logout() {
        isAuthenticated = false
        user = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
    }
    
    func checkAuthStatus() {
        if let _ = UserDefaults.standard.string(forKey: "access_token") {
            // En una implementación real, verificaríamos el token
            isAuthenticated = true
        }
    }
    
    private func performLogin(email: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "password",
            "username": email,
            "password": password,
            "client_id": Auth0Config.clientId,
            "client_secret": Auth0Config.clientSecret,
            "audience": Auth0Config.audience,
            "scope": "openid profile email"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(LoginResponse.self, from: data)
        } else {
            let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.loginFailed(errorResponse?.errorDescription ?? "Error desconocido")
        }
    }
    
    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        let url = URL(string: "\(baseURL)/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }
}

// MARK: - Response Models
struct LoginResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let expiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct UserInfo: Codable {
    let sub: String
    let email: String
    let name: String
    let picture: String?
}

struct AuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

enum AuthError: Error, LocalizedError {
    case invalidResponse
    case loginFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .loginFailed(let message):
            return message
        }
    }
} 