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
    /// Con `measure ≠ reps` viaja 0 y el servidor guarda 0 (contrato §8.1).
    public let reps: Int
    public let measure: TrainingMeasure
    public let durationSeconds: Int?
    public let distanceMeters: Double?
    public let weightKg: Double?
    public let rpe: Double?
    public let isWarmup: Bool
    public let completedAt: Date

    public enum CodingKeys: String, CodingKey {
        case reps, rpe, measure
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_m"
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
        measure: TrainingMeasure = .reps,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
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
        // El contrato es explícito: fuera de `reps`, las repeticiones viajan a cero.
        self.reps = measure == .reps ? reps : 0
        self.measure = measure
        self.durationSeconds = measure == .duration ? durationSeconds : nil
        self.distanceMeters = measure == .distance ? distanceMeters : nil
        self.weightKg = weightKg
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = completedAt
    }

    /// Decodificación tolerante y **no** la sintetizada.
    ///
    /// Este cuerpo se lee de dos sitios: del fixture del contrato y del OUTBOX EN DISCO. Una
    /// entrada encolada por la versión anterior no lleva `measure`, y con el decodificador
    /// sintetizado (que exige la clave de un campo no opcional) una sesión pendiente se
    /// volvería ilegible al actualizar la app: media hora de la vida de alguien perdida por
    /// un campo nuevo.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientUUID = try container.decode(UUID.self, forKey: .clientUUID)
        exerciseKey = try container.decodeIfPresent(String.self, forKey: .exerciseKey) ?? ""
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName)
        dayExerciseId = try container.decodeIfPresent(Int.self, forKey: .dayExerciseId)
        exerciseId = try container.decodeIfPresent(Int.self, forKey: .exerciseId)
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        setNumber = try container.decodeIfPresent(Int.self, forKey: .setNumber) ?? 1
        reps = try container.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        measure = try container.decodeIfPresent(TrainingMeasure.self, forKey: .measure) ?? .reps
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        completedAt = try container.decode(Date.self, forKey: .completedAt)
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
    /// Conjunto COMPLETO del registro: al sincronizar reemplaza lo que hubiera (contrato §8.2).
    /// Por eso viaja siempre, incluso vacío: vacío significa «el cliente no dijo nada».
    public let exerciseFeedback: [TrainingExerciseFeedback]

    public enum CodingKeys: String, CodingKey {
        case title, status, notes, feeling, sets
        case exerciseFeedback = "exercise_feedback"
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
        sets: [SetLogSyncRequest],
        exerciseFeedback: [TrainingExerciseFeedback] = []
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
        self.exerciseFeedback = exerciseFeedback
    }

    /// Tolerante por la misma razón que `SetLogSyncRequest`: esto se relee del outbox.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientUUID = try container.decode(UUID.self, forKey: .clientUUID)
        dayId = try container.decodeIfPresent(Int.self, forKey: .dayId)
        programId = try container.decodeIfPresent(Int.self, forKey: .programId)
        scheduledDate = try container.decodeIfPresent(CalendarDate.self, forKey: .scheduledDate)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Workout"
        status = try container.decodeIfPresent(WorkoutLogStatus.self, forKey: .status) ?? .inProgress
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        sessionRPE = try container.decodeIfPresent(Double.self, forKey: .sessionRPE)
        feeling = try container.decodeIfPresent(Int.self, forKey: .feeling)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        sets = try container.decodeIfPresent([SetLogSyncRequest].self, forKey: .sets) ?? []
        exerciseFeedback = try container
            .decodeIfPresent([TrainingExerciseFeedback].self, forKey: .exerciseFeedback) ?? []
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
