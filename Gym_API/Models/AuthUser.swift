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

