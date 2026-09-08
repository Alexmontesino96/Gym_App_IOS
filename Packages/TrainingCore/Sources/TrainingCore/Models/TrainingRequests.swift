//
//  TrainingRequests.swift
//  TrainingCore
//
//  Cuerpos de petición del módulo. El importante es `WorkoutLogSyncRequest`, que es el
//  literal de la sección §6.4 del plan y la unidad que viaja en el outbox.
//

import Foundation

// MARK: - POST /training/logs/sync

public struct SetLogSyncRequest: Codable, Hashable, Sendable {

    /// Idempotencia por serie: reenviar el mismo cuerpo produce el mismo estado (plan §4.7).
    public let clientUUID: UUID
    public let exerciseKey: String
    public let exerciseName: String?
    public let dayExerciseId: Int?
    public let exerciseId: Int?
    public let orderIndex: Int
    public let setNumber: Int
    public let reps: Int
    public let weightKg: Double?
    public let rpe: Double?
    public let isWarmup: Bool
    public let completedAt: Date

    public enum CodingKeys: String, CodingKey {
        case reps, rpe
        case clientUUID = "client_uuid"
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case dayExerciseId = "day_exercise_id"
        case exerciseId = "exercise_id"
        case orderIndex = "order_index"
        case setNumber = "set_number"
        case weightKg = "weight_kg"
        case isWarmup = "is_warmup"
        case completedAt = "completed_at"
    }

    public init(
        clientUUID: UUID,
        exerciseKey: String,
        exerciseName: String? = nil,
        dayExerciseId: Int? = nil,
        exerciseId: Int? = nil,
        orderIndex: Int,
        setNumber: Int,
        reps: Int,
        weightKg: Double? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        completedAt: Date
    ) {
        self.clientUUID = clientUUID
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.dayExerciseId = dayExerciseId
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = completedAt
    }
}

public struct WorkoutLogSyncRequest: Codable, Hashable, Sendable {

    public let clientUUID: UUID
    public let dayId: Int?
    public let programId: Int?
    public let scheduledDate: CalendarDate?
    public let title: String
    public let status: WorkoutLogStatus
    public let startedAt: Date
    public let completedAt: Date?
    public let sessionRPE: Double?
    public let feeling: Int?
    public let notes: String?
    public let sets: [SetLogSyncRequest]

    public enum CodingKeys: String, CodingKey {
        case title, status, notes, feeling, sets
        case clientUUID = "client_uuid"
        case dayId = "day_id"
        case programId = "program_id"
        case scheduledDate = "scheduled_date"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case sessionRPE = "session_rpe"
    }

    public init(
        clientUUID: UUID,
        dayId: Int? = nil,
        programId: Int? = nil,
        scheduledDate: CalendarDate? = nil,
        title: String,
        status: WorkoutLogStatus,
        startedAt: Date,
        completedAt: Date? = nil,
        sessionRPE: Double? = nil,
        feeling: Int? = nil,
        notes: String? = nil,
        sets: [SetLogSyncRequest]
    ) {
        self.clientUUID = clientUUID
        self.dayId = dayId
        self.programId = programId
        self.scheduledDate = scheduledDate
        self.title = title
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sessionRPE = sessionRPE
        self.feeling = feeling
        self.notes = notes
        self.sets = sets
    }

    public var isFinal: Bool { status == .completed }
}

// MARK: - Escrituras cortas

/// `POST /training/logs/{id}/review`.
public struct LogReviewRequest: Codable, Hashable, Sendable {

    public let comment: String?
    public let congratulate: Bool?

    public init(comment: String? = nil, congratulate: Bool? = nil) {
        self.comment = comment
        self.congratulate = congratulate
    }
}

/// `PUT /training/clients/{id}/day-notes/{date}`.
public struct DayNoteRequest: Codable, Hashable, Sendable {

    public let text: String

    public init(text: String) {
        self.text = String(text.prefix(TrainingClientDayNote.maxLength))
    }
}

/// `POST /training/programs/{id}/assign`.
public struct AssignProgramRequest: Codable, Hashable, Sendable {

    public let userIds: [Int]
    public let startDate: CalendarDate
    public let mode: TrainingAssignmentMode
    public let replace: Bool

    public enum CodingKeys: String, CodingKey {
        case mode, replace
        case userIds = "user_ids"
        case startDate = "start_date"
    }

    public init(userIds: [Int], startDate: CalendarDate, mode: TrainingAssignmentMode, replace: Bool = false) {
        self.userIds = userIds
        self.startDate = startDate
        self.mode = mode
        self.replace = replace
    }
}
