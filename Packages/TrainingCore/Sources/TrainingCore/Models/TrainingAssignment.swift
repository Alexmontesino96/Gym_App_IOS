//
//  TrainingAssignment.swift
//  TrainingCore
//
//  Asignación cliente ↔ programa (plan §4.2, §4.3 y §5).
//

import Foundation

public struct TrainingAssignment: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let gymId: Int?
    public let programId: Int
    public let userId: Int?
    public let assignedBy: Int?
    /// Siempre un lunes en la zona horaria del espacio (plan §4.2).
    public let startDate: CalendarDate
    public let endDate: CalendarDate?
    public let mode: TrainingAssignmentMode
    public let status: TrainingAssignmentStatus
    /// Solo en la lista del entrenador: registros completados ÷ días de entreno hasta hoy.
    public let adherencePct: Double?
    public let missedInBlock: Int?

    public enum CodingKeys: String, CodingKey {
        case id, mode, status
        case gymId = "gym_id"
        case programId = "program_id"
        case userId = "user_id"
        case assignedBy = "assigned_by"
        case startDate = "start_date"
        case endDate = "end_date"
        case adherencePct = "adherence_pct"
        case missedInBlock = "missed_in_block"
    }

    public init(
        id: Int,
        gymId: Int? = nil,
        programId: Int,
        userId: Int? = nil,
        assignedBy: Int? = nil,
        startDate: CalendarDate,
        endDate: CalendarDate? = nil,
        mode: TrainingAssignmentMode = .copy,
        status: TrainingAssignmentStatus = .active,
        adherencePct: Double? = nil,
        missedInBlock: Int? = nil
    ) {
        self.id = id
        self.gymId = gymId
        self.programId = programId
        self.userId = userId
        self.assignedBy = assignedBy
        self.startDate = startDate
        self.endDate = endDate
        self.mode = mode
        self.status = status
        self.adherencePct = adherencePct
        self.missedInBlock = missedInBlock
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        gymId = try container.decodeIfPresent(Int.self, forKey: .gymId)
        programId = try container.decode(Int.self, forKey: .programId)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        assignedBy = try container.decodeIfPresent(Int.self, forKey: .assignedBy)
        startDate = try container.decode(CalendarDate.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(CalendarDate.self, forKey: .endDate)
        mode = try container.decodeIfPresent(TrainingAssignmentMode.self, forKey: .mode) ?? .copy
        status = try container.decodeIfPresent(TrainingAssignmentStatus.self, forKey: .status) ?? .active
        adherencePct = try container.decodeIfPresent(Double.self, forKey: .adherencePct)
        missedInBlock = try container.decodeIfPresent(Int.self, forKey: .missedInBlock)
    }

    public var isActive: Bool { status == .active }
}

// MARK: - Opciones de fecha de inicio (AssignProgramSheet, WP5)

/// Las dos únicas fechas de inicio que ofrece el entrenador al asignar (plan §4.2).
public struct AssignmentStartOptions: Hashable, Sendable {

    /// El lunes de la semana en curso. Los días anteriores a hoy se muestran como descanso.
    public let thisWeek: CalendarDate
    /// El lunes siguiente. Es el valor por defecto.
    public let nextMonday: CalendarDate

    public init(thisWeek: CalendarDate, nextMonday: CalendarDate) {
        self.thisWeek = thisWeek
        self.nextMonday = nextMonday
    }

    public var defaultChoice: CalendarDate { nextMonday }
}
