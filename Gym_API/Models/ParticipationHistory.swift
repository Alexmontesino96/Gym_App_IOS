import Foundation

// MARK: - Participation History Response Models

/// Representa un registro del historial de participación del usuario
struct ParticipationHistoryItem: Codable {
    let participation: ParticipationRecord
    let session: SessionRecord
    let `class`: ClassRecord

    enum CodingKeys: String, CodingKey {
        case participation
        case session
        case `class` = "class"
    }
}

/// Información de participación del usuario
struct ParticipationRecord: Codable {
    let id: Int
    let status: ParticipationStatus
    let registrationTime: Date?
    let attendanceTime: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case registrationTime = "registration_time"
        case attendanceTime = "attendance_time"
    }
}

/// Estados de participación
enum ParticipationStatus: String, Codable {
    case attended = "attended"
    case registered = "registered"
    case cancelled = "cancelled"
    case noShow = "no_show"
}

/// Información de la sesión
struct SessionRecord: Codable {
    let id: Int
    let startTime: Date
    let startTimeLocal: String?
    let room: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case startTimeLocal = "start_time_local"
        case room
        case timezone
    }
}

/// Información de la clase
struct ClassRecord: Codable {
    let id: Int
    let name: String
    let duration: Int
    let difficultyLevel: String?
    let categoryEnum: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case duration
        case difficultyLevel = "difficulty_level"
        case categoryEnum = "category_enum"
    }
}

// MARK: - Extensions for AttendedClass Conversion

extension ParticipationHistoryItem {
    /// Convierte a AttendedClass para usar en el UI
    func toAttendedClass() -> AttendedClass? {
        // Solo incluir clases a las que realmente asistió
        guard participation.status == .attended else { return nil }

        // Calcular endTime basado en la duración
        let endTime = Calendar.current.date(
            byAdding: .minute,
            value: self.class.duration,
            to: session.startTime
        ) ?? session.startTime

        // Usar attendanceTime si está disponible, sino usar startTime
        let checkinTime = participation.attendanceTime ?? session.startTime

        return AttendedClass(
            id: session.id,
            classId: self.class.id,
            className: self.class.name,
            instructor: "Instructor", // El API no proporciona el nombre del instructor
            startTime: session.startTime,
            endTime: endTime,
            checkinTime: checkinTime,
            checkoutTime: endTime
        )
    }
}