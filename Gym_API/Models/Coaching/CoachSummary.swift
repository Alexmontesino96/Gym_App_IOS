//
//  CoachSummary.swift
//  Gym_API
//
//  El entrenador personal del cliente, tal y como se puede resolver hoy.
//
//  No hay un endpoint "mi coach". Se compone de dos fuentes que sí funcionan para
//  cualquier miembro del gimnasio:
//    1. GET /gyms/users?role=OWNER      -> identidad garantizada (id y nombre)
//    2. GET /users/p/gym-participants/{id} -> foto y bio
//
//  Se descarta GET /relationships/my-trainers: exige que el rol GLOBAL del usuario sea MEMBER,
//  lee una tabla que no tiene gym_id y que nadie rellena en ningún alta.
//

import Foundation

struct CoachSummary: Identifiable, Equatable {
    let id: Int
    let fullName: String
    let email: String?
    let pictureURL: String?
    let bio: String?

    var initials: String {
        let parts = fullName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
        return parts.isEmpty ? "?" : parts.joined()
    }

    /// Nombre de pila, para los textos que tutean ("Escribe a Carla").
    var firstName: String {
        String(fullName.split(separator: " ").first ?? Substring(fullName))
    }
}

// MARK: - Respuestas de red

/// Fila de GET /gyms/users. El backend la construye a mano en gym_service.get_gym_users,
/// así que no lleva foto ni bio.
struct GymUserRow: Codable {
    let id: Int
    let email: String?
    let fullName: String?
    let role: String?
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case fullName = "full_name"
        case joinedAt = "joined_at"
    }
}

/// Fila de GET /users/p/gym-participants/{id}. Aquí sí hay foto y bio.
struct PublicProfileRow: Codable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let picture: String?
    let bio: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id, picture, bio, role
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var fullName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}


// MARK: - Nota del entrenador

/// Último mensaje que el entrenador ha escrito en la conversación 1:1.
///
/// El diseño lo llama «nota de hoy» y es la pieza que hace visible la relación: sin ella la
/// tarjeta del coach es una ficha de contacto. No hay endpoint que la devuelva porque el
/// esquema `ChatRoom` del backend no incluye el último mensaje; se lee del canal de Stream.
struct CoachNote: Equatable {
    let text: String
    let sentAt: Date

    /// «40m», «3h», «2d». Corto a propósito: va en la esquina de una tarjeta.
    var relativeAge: String {
        let seconds = max(0, Date().timeIntervalSince(sentAt))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
}

/// Respuesta de GET /chat/rooms/direct/{user_id}. Solo se necesita el canal.
struct DirectChatRoomRef: Decodable {
    let id: Int
    let streamChannelId: String
    let streamChannelType: String

    enum CodingKeys: String, CodingKey {
        case id
        case streamChannelId = "stream_channel_id"
        case streamChannelType = "stream_channel_type"
    }
}
