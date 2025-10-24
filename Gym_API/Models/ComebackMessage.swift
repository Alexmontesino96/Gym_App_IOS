import Foundation

// MARK: - Comeback Message Model
/// Modelo para mensajes de re-engagement cuando la racha del usuario está en 0
struct ComebackMessage {
    let emoji: String
    let title: String
    let message: String
    let tone: MessageTone
    let urgency: UrgencyLevel

    enum MessageTone {
        case encouraging    // Días 0-3: Tono ligero y positivo
        case friendly       // Días 2-3: Tono amigable
        case motivational   // Días 4-7: Tono más directo
        case challenging    // Días 8-14: Tono de desafío
        case supportive     // Días 15-30: Tono empático
        case warm           // Días 30+: Tono cálido y acogedor
    }

    enum UrgencyLevel {
        case low
        case medium
        case high
        case critical

        var color: String {
            switch self {
            case .low, .medium: return "#D93333"  // Accent normal
            case .high: return "#FF6B6B"           // Accent más brillante
            case .critical: return "#FF8C42"       // Naranja cálido
            }
        }
    }
}

// MARK: - User Activity Model
/// Modelo para rastrear la última actividad del usuario
struct UserActivity: Codable {
    let lastAttendedClass: String?
    let lastAttendanceDate: Date?
    let daysInactive: Int
    let bestStreak: Int

    enum CodingKeys: String, CodingKey {
        case lastAttendedClass = "last_attended_class"
        case lastAttendanceDate = "last_attendance_date"
        case daysInactive = "days_inactive"
        case bestStreak = "best_streak"
    }

    // Computed property para mostrar "hace X días"
    var daysAgoText: String {
        if daysInactive == 0 {
            return "Hoy"
        } else if daysInactive == 1 {
            return "Ayer"
        } else {
            return "Hace \(daysInactive) días"
        }
    }

    static let empty = UserActivity(
        lastAttendedClass: nil,
        lastAttendanceDate: nil,
        daysInactive: 0,
        bestStreak: 0
    )
}
