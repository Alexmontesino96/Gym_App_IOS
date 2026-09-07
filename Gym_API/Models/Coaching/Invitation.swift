//
//  Invitation.swift
//  Gym_API
//
//  Invitaciones a un espacio de trabajo.
//
//  Es la única vía de alta de un cliente: el entrenador genera el enlace y lo comparte por
//  donde ya habla con él. No hay directorio ni búsqueda, porque la relación entre entrenador
//  y cliente existe fuera del producto.
//

import Foundation

/// Lo que ve quien recibe el enlace, antes de aceptar.
struct InvitationPreview: Codable, Equatable {
    let gymId: Int
    let gymName: String
    let gymLogoURL: String?
    let isPersonalTrainer: Bool
    let inviterName: String?
    let role: String
    let expiresAt: Date
    let isRedeemable: Bool
    let alreadyMember: Bool

    enum CodingKeys: String, CodingKey {
        case role
        case gymId = "gym_id"
        case gymName = "gym_name"
        case gymLogoURL = "gym_logo_url"
        case isPersonalTrainer = "is_personal_trainer"
        case inviterName = "inviter_name"
        case expiresAt = "expires_at"
        case isRedeemable = "is_redeemable"
        case alreadyMember = "already_member"
    }

    /// Frase que describe a qué se está uniendo, adaptada al tipo de espacio.
    var joiningDescription: String {
        if isPersonalTrainer {
            if let inviterName, !inviterName.isEmpty {
                return "Vas a unirte al espacio de \(inviterName) como cliente."
            }
            return "Vas a unirte a este espacio de entrenamiento como cliente."
        }
        return "Vas a unirte a \(gymName)."
    }
}

/// Resultado de canjear.
struct InvitationAcceptResult: Codable, Equatable {
    let gymId: Int
    let gymName: String
    let role: String
    let alreadyMember: Bool

    enum CodingKeys: String, CodingKey {
        case role
        case gymId = "gym_id"
        case gymName = "gym_name"
        case alreadyMember = "already_member"
    }
}

/// Invitación tal y como la ve el entrenador que la creó.
struct WorkspaceInvitation: Codable, Identifiable, Equatable {
    let id: Int
    let gymId: Int
    let token: String
    let role: String
    let email: String?
    let status: String
    let maxUses: Int
    let usedCount: Int
    let expiresAt: Date
    let createdAt: Date
    let notes: String?
    let isRedeemable: Bool

    enum CodingKeys: String, CodingKey {
        case id, token, role, email, status, notes
        case gymId = "gym_id"
        case maxUses = "max_uses"
        case usedCount = "used_count"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case isRedeemable = "is_redeemable"
    }

    /// Texto que el entrenador comparte con su cliente.
    func shareText(gymName: String?) -> String {
        let destino = gymName.map { " a \($0)" } ?? ""
        return """
        Te invito\(destino) en GymFlow.

        Descarga la app, crea tu cuenta y usa este código para unirte:

        \(token)
        """
    }
}

struct CreateInvitationRequest: Codable {
    let email: String?
    let role: String
    let expiresInDays: Int
    let maxUses: Int

    enum CodingKeys: String, CodingKey {
        case email, role
        case expiresInDays = "expires_in_days"
        case maxUses = "max_uses"
    }

    init(email: String? = nil, role: String = "MEMBER", expiresInDays: Int = 14, maxUses: Int = 1) {
        self.email = email
        self.role = role
        self.expiresInDays = expiresInDays
        self.maxUses = maxUses
    }
}
