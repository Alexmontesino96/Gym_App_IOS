import Foundation

// MARK: - Estructura Real del API de Historial de Asistencia

/// Respuesta real del endpoint /schedule/participation/my-history
struct AttendanceHistoryItem: Codable {
    let id: Int
    let sessionId: Int
    let memberId: Int
    let status: String
    let registrationTime: Date?
    let attendanceTime: Date?
    let cancellationTime: Date?
    let cancellationReason: String?
    let sessionInfo: SessionInfo
    let classInfo: ClassInfoResponse

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case memberId = "member_id"
        case status
        case registrationTime = "registration_time"
        case attendanceTime = "attendance_time"
        case cancellationTime = "cancellation_time"
        case cancellationReason = "cancellation_reason"
        case sessionInfo = "session_info"
        case classInfo = "class_info"
    }
}

/// Información de la sesión en la respuesta
struct SessionInfo: Codable {
    let classId: Int
    let trainerId: Int
    let startTime: String  // Viene como string, no Date
    let endTime: String
    let room: String?
    let isRecurring: Bool
    let recurrencePattern: String?
    let status: String
    let overrideCapacity: Int?
    let notes: String?
    let id: Int
    let gymId: Int
    let currentParticipants: Int
    let createdAt: Date
    let updatedAt: Date?
    let createdBy: Int?
    let timezone: String
    let startTimeLocal: String
    let endTimeLocal: String

    enum CodingKeys: String, CodingKey {
        case classId = "class_id"
        case trainerId = "trainer_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case room
        case isRecurring = "is_recurring"
        case recurrencePattern = "recurrence_pattern"
        case status
        case overrideCapacity = "override_capacity"
        case notes
        case id
        case gymId = "gym_id"
        case currentParticipants = "current_participants"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case timezone
        case startTimeLocal = "start_time_local"
        case endTimeLocal = "end_time_local"
    }
}

/// Información de la clase en la respuesta
struct ClassInfoResponse: Codable {
    let name: String
    let description: String?
    let duration: Int
    let maxCapacity: Int
    let difficultyLevel: String?
    let categoryId: Int?
    let categoryEnum: String?
    let category: String?
    let isActive: Bool
    let gymId: Int
    let id: Int
    let createdAt: Date
    let updatedAt: Date?
    let createdBy: Int?
    let customCategory: String?

    enum CodingKeys: String, CodingKey {
        case name, description, duration
        case maxCapacity = "max_capacity"
        case difficultyLevel = "difficulty_level"
        case categoryId = "category_id"
        case categoryEnum = "category_enum"
        case category
        case isActive = "is_active"
        case gymId = "gym_id"
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case customCategory = "custom_category"
    }
}

// MARK: - Extensions for AttendedClass Conversion

extension AttendanceHistoryItem {
    /// Convierte a AttendedClass para usar en el UI
    func toAttendedClass() -> AttendedClass? {
        // Solo incluir clases con status "attended" o "completed"
        guard status == "attended" || status == "completed" || status == "registered" else {
            return nil
        }

        // Parsear las fechas que vienen como string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: sessionInfo.timezone) ?? TimeZone.current

        let startTime = dateFormatter.date(from: sessionInfo.startTime) ?? Date()
        let endTime = dateFormatter.date(from: sessionInfo.endTime) ?? Date()

        // Usar attendanceTime si está disponible, sino usar startTime
        let checkinTime = attendanceTime ?? startTime

        return AttendedClass(
            id: sessionInfo.id,
            classId: classInfo.id,
            className: classInfo.name,
            instructor: "Coach \(sessionInfo.trainerId)", // No tenemos el nombre del instructor
            startTime: startTime,
            endTime: endTime,
            checkinTime: checkinTime,
            checkoutTime: endTime
        )
    }
}