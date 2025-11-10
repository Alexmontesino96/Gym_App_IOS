import Foundation

// MARK: - Like Item

/// Item de la lista de likes de un post o comentario
/// Representa un like con información del usuario que lo dio
struct LikeItem: Codable, Identifiable {
    let id: Int
    let postId: Int?
    let commentId: Int?
    let userId: Int
    let createdAt: Date
    let user: UserPreview

    /// Fecha formateada relativa (ej: "hace 2 horas")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Identificador del objeto al que pertenece el like
    var targetId: Int {
        postId ?? commentId ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case commentId = "comment_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case user
    }
}

// MARK: - Like Summary

/// Resumen de likes para mostrar en UI (ej: "A Juan, María y 24 más les gusta esto")
struct LikeSummary {
    let totalLikes: Int
    let firstUsers: [UserPreview]
    let remainingCount: Int

    /// Texto formateado para mostrar en UI
    var displayText: String {
        guard totalLikes > 0 else {
            return "Sin likes"
        }

        if totalLikes == 1, let first = firstUsers.first {
            return "Le gusta a \(first.fullName)"
        }

        if totalLikes == 2, firstUsers.count == 2 {
            return "Les gusta a \(firstUsers[0].fullName) y \(firstUsers[1].fullName)"
        }

        if let first = firstUsers.first {
            if remainingCount > 0 {
                return "Les gusta a \(first.fullName) y \(remainingCount) más"
            }
            return "Les gusta a \(first.fullName)"
        }

        return "\(totalLikes) likes"
    }

    /// Inicializa desde una respuesta de likes paginada
    static func from(response: PagedResponse<LikeItem>) -> LikeSummary {
        let total = response.effectiveTotal
        let users = response.items.prefix(3).map { $0.user }
        let remaining = max(0, total - users.count)

        return LikeSummary(
            totalLikes: total,
            firstUsers: Array(users),
            remainingCount: remaining
        )
    }
}
