//
//  ClientSummary.swift
//  Gym_API
//
//  Un cliente del entrenador personal.
//
//  Fuente autoritativa: GET /gyms/users?role=MEMBER, que devuelve la pertenencia real al espacio
//  de trabajo. La foto se enriquece aparte con GET /users/p/gym-participants, que sí trae imagen
//  pero filtra por el rol GLOBAL del usuario, no por el del gimnasio, así que no sirve como lista.
//

import Foundation

struct ClientSummary: Identifiable, Equatable {
    let id: Int
    let fullName: String
    let email: String?
    let pictureURL: String?
    let joinedAt: Date?

    var initials: String {
        let parts = fullName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
        return parts.isEmpty ? "?" : parts.joined()
    }

    var displayName: String {
        let trimmed = fullName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return email ?? "Cliente #\(id)"
    }
}
