//
//  AuthUser.swift
//  Gym_API
//
//  Created by Assistant on current date.
//
//  Modelo simple para usuario autenticado que no requiere SwiftData

import Foundation

/// Modelo simple para representar un usuario autenticado
/// No usa SwiftData para evitar problemas de ModelContext
struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let picture: String?
    let isCoach: Bool
    
    init(id: String, email: String, name: String, picture: String? = nil, isCoach: Bool = false) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.isCoach = isCoach
    }
}

// MARK: - Extension para convertir a User de SwiftData cuando sea necesario
extension AuthUser {
    /// Convierte AuthUser a User de SwiftData
    /// Requiere un ModelContext activo
    func toSwiftDataUser() -> User {
        return User(
            id: id,
            email: email,
            name: name,
            picture: picture,
            isCoach: isCoach
        )
    }
}

// MARK: - Extension para User de SwiftData
extension User {
    /// Convierte User de SwiftData a AuthUser
    func toAuthUser() -> AuthUser {
        return AuthUser(
            id: id,
            email: email,
            name: name,
            picture: picture,
            isCoach: isCoach
        )
    }
}