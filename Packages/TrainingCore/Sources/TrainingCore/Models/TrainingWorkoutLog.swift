//
//  TrainingWorkoutLog.swift
//  TrainingCore
//
//  Registro de sesión y serie ejecutada (plan §5 y §6.4).
//
//  Regla de oro del módulo: `is_pr` y `pr_kind` los decide el SERVIDOR cuando el registro se
//  sincroniza con `status = completed`. Hasta entonces la app enseña «Best set so far» y nunca
//  «Personal record» (plan §4.5).
//

import Foundation

// MARK: - Serie registrada

public struct TrainingSetLog: Codable, Hashable, Identifiable, Sendable {

    /// Id de servidor. Nulo mientras la serie solo existe en el teléfono.
    public let id: Int?
    /// Idempotencia: el servidor hace upsert por esta clave (plan §4.7).
    public let clientUUID: UUID
    public let workoutLogId: Int?
    public let dayExerciseId: Int?
    public let exerciseId: Int?
    public let exerciseKey: String
    public let exerciseName: String
    public let orderIndex: Int
    public let setNumber: Int
    public let reps: Int
    public let weightKg: Double?
    public let rpe: Double?
    public let isWarmup: Bool
    public let completedAt: Date?
    /// Calculado por el servidor. Nulo si la serie no es elegible (plan §4.5).
    public let e1rmKg: Double?
    public let isPR: Bool
    public let prKind: PersonalRecordKind?

    public enum CodingKeys: String, CodingKey {
        case id, reps, rpe
        case clientUUID = "client_uuid"
        case workoutLogId = "workout_log_id"
        case dayExerciseId = "day_exercise_id"
        case exerciseId = "exercise_id"
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case orderIndex = "order_index"
        case setNumber = "set_number"
        case weightKg = "weight_kg"
        case isWarmup = "is_warmup"
        case completedAt = "completed_at"
        case e1rmKg = "e1rm_kg"
        case isPR = "is_pr"
        case prKind = "pr_kind"
    }

    public init(
        id: Int? = nil,
        clientUUID: UUID,
        workoutLogId: Int? = nil,
        dayExerciseId: Int? = nil,
        exerciseId: Int? = nil,
        exerciseKey: String,
        exerciseName: String,
        orderIndex: Int = 0,
        setNumber: Int,
        reps: Int,
        weightKg: Double? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        completedAt: Date? = nil,
        e1rmKg: Double? = nil,
        isPR: Bool = false,
        prKind: PersonalRecordKind? = nil
    ) {
        self.id = id
        self.clientUUID = clientUUID
        self.workoutLogId = workoutLogId
        self.dayExerciseId = dayExerciseId
        self.exerciseId = exerciseId
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = completedAt
        self.e1rmKg = e1rmKg
        self.isPR = isPR
        self.prKind = prKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        clientUUID = try container.decodeIfPresent(UUID.self, forKey: .clientUUID) ?? UUID()
        workoutLogId = try container.decodeIfPresent(Int.self, forKey: .workoutLogId)
        dayExerciseId = try container.decodeIfPresent(Int.self, forKey: .dayExerciseId)
        exerciseId = try container.decodeIfPresent(Int.self, forKey: .exerciseId)
        exerciseKey = try container.decodeIfPresent(String.self, forKey: .exerciseKey) ?? ""
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? ""
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        setNumber = try container.decodeIfPresent(Int.self, forKey: .setNumber) ?? 1
        reps = try container.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        e1rmKg = try container.decodeIfPresent(Double.self, forKey: .e1rmKg)
        isPR = try container.decodeIfPresent(Bool.self, forKey: .isPR) ?? false
        prKind = try container.decodeIfPresent(PersonalRecordKind.self, forKey: .prKind)
    }

    /// Volumen de la serie. Las de calentamiento no cuentan.
    public var volumeKg: Double {
        guard !isWarmup, let weightKg else { return 0 }
        return weightKg * Double(reps)
    }
}

// MARK: - Registro de sesión

public struct TrainingWorkoutLog: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let gymId: Int?
    public let userId: Int?
    public let programId: Int?
    public let dayId: Int?
    public let scheduledDate: CalendarDate?
    public let clientUUID: UUID?
    public let status: WorkoutLogStatus
    public let title: String
    public let startedAt: Date?
    public let completedAt: Date?
    /// Hora de servidor: el orden no depende del reloj del teléfono (plan §15).
    public let receivedAt: Date?
    public let durationSeconds: Int?
    public let sessionRPE: Double?
    public let feeling: Int?
    public let notes: String?
    public let totalSets: Int
    public let totalVolumeKg: Double
    public let prCount: Int
    public let isPartial: Bool
    public let reviewedAt: Date?
    public let reviewedBy: Int?
    public let coachComment: String?
    public let coachCongratulated: Bool
    public let clientThanked: Bool
    /// Solo en `GET /logs/{id}`.
    public let sets: [TrainingSetLog]

    public enum CodingKeys: String, CodingKey {
        case id, status, title, notes, feeling, sets
        case gymId = "gym_id"
        case userId = "user_id"
        case programId = "program_id"
        case dayId = "day_id"
        case scheduledDate = "scheduled_date"
        case clientUUID = "client_uuid"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case receivedAt = "received_at"
        case durationSeconds = "duration_seconds"
        case sessionRPE = "session_rpe"
        case totalSets = "total_sets"
        case totalVolumeKg = "total_volume_kg"
        case prCount = "pr_count"
        case isPartial = "is_partial"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
        case coachComment = "coach_comment"
        case coachCongratulated = "coach_congratulated"
        case clientThanked = "client_thanked"
    }

    public init(
        id: Int,
        gymId: Int? = nil,
        userId: Int? = nil,
        programId: Int? = nil,
        dayId: Int? = nil,
        scheduledDate: CalendarDate? = nil,
        clientUUID: UUID? = nil,
        status: WorkoutLogStatus = .completed,
        title: String,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        receivedAt: Date? = nil,
        durationSeconds: Int? = nil,
        sessionRPE: Double? = nil,
        feeling: Int? = nil,
        notes: String? = nil,
        totalSets: Int = 0,
        totalVolumeKg: Double = 0,
        prCount: Int = 0,
        isPartial: Bool = false,
        reviewedAt: Date? = nil,
        reviewedBy: Int? = nil,
        coachComment: String? = nil,
        coachCongratulated: Bool = false,
        clientThanked: Bool = false,
        sets: [TrainingSetLog] = []
    ) {
        self.id = id
        self.gymId = gymId
        self.userId = userId
        self.programId = programId
        self.dayId = dayId
        self.scheduledDate = scheduledDate
        self.clientUUID = clientUUID
        self.status = status
        self.title = title
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.receivedAt = receivedAt
        self.durationSeconds = durationSeconds
        self.sessionRPE = sessionRPE
        self.feeling = feeling
        self.notes = notes
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.prCount = prCount
        self.isPartial = isPartial
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.coachComment = coachComment
        self.coachCongratulated = coachCongratulated
        self.clientThanked = clientThanked
        self.sets = sets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        gymId = try container.decodeIfPresent(Int.self, forKey: .gymId)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        programId = try container.decodeIfPresent(Int.self, forKey: .programId)
        dayId = try container.decodeIfPresent(Int.self, forKey: .dayId)
        scheduledDate = try container.decodeIfPresent(CalendarDate.self, forKey: .scheduledDate)
        clientUUID = try container.decodeIfPresent(UUID.self, forKey: .clientUUID)
        status = try container.decodeIfPresent(WorkoutLogStatus.self, forKey: .status) ?? .completed
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Workout"
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        sessionRPE = try container.decodeIfPresent(Double.self, forKey: .sessionRPE)
        feeling = try container.decodeIfPresent(Int.self, forKey: .feeling)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        totalSets = try container.decodeIfPresent(Int.self, forKey: .totalSets) ?? 0
        totalVolumeKg = try container.decodeIfPresent(Double.self, forKey: .totalVolumeKg) ?? 0
        prCount = try container.decodeIfPresent(Int.self, forKey: .prCount) ?? 0
        isPartial = try container.decodeIfPresent(Bool.self, forKey: .isPartial) ?? false
        reviewedAt = try container.decodeIfPresent(Date.self, forKey: .reviewedAt)
        reviewedBy = try container.decodeIfPresent(Int.self, forKey: .reviewedBy)
        coachComment = try container.decodeIfPresent(String.self, forKey: .coachComment)
        coachCongratulated = try container.decodeIfPresent(Bool.self, forKey: .coachCongratulated) ?? false
        clientThanked = try container.decodeIfPresent(Bool.self, forKey: .clientThanked) ?? false
        sets = try container.decodeIfPresent([TrainingSetLog].self, forKey: .sets) ?? []
    }

    public var isReviewed: Bool { reviewedAt != nil }

    /// Series marcadas como marca por el servidor. Antes de sincronizar esta lista está vacía,
    /// que es exactamente lo que queremos: sin confirmación no se dice «Personal record».
    public var personalRecordSets: [TrainingSetLog] { sets.filter { $0.isPR } }

    /// La marca más destacable de la sesión, para la tarjeta de S18.
    public var topPersonalRecord: TrainingSetLog? {
        personalRecordSets.max { ($0.e1rmKg ?? $0.weightKg ?? 0) < ($1.e1rmKg ?? $1.weightKg ?? 0) }
    }
}

// MARK: - Resumen para listas (W8, historial, buzón de revisión)

public struct TrainingWorkoutLogSummary: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let title: String
    public let completedAt: Date?
    public let durationSeconds: Int?
    public let totalSets: Int
    public let totalVolumeKg: Double
    public let prCount: Int
    public let isPartial: Bool
    public let reviewedAt: Date?
    public let userId: Int?
    public let userName: String?
    public let userPictureURL: String?
    /// La marca más destacada, cuando el endpoint la adjunta (`last_log.top_pr` en §6.5).
    public let topPR: TrainingTopRecord?

    public enum CodingKeys: String, CodingKey {
        case id, title
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case totalSets = "total_sets"
        case totalVolumeKg = "total_volume_kg"
        case prCount = "pr_count"
        case isPartial = "is_partial"
        case reviewedAt = "reviewed_at"
        case userId = "user_id"
        case userName = "user_name"
        case userPictureURL = "user_picture_url"
        case topPR = "top_pr"
    }

    public init(
        id: Int,
        title: String,
        completedAt: Date? = nil,
        durationSeconds: Int? = nil,
        totalSets: Int = 0,
        totalVolumeKg: Double = 0,
        prCount: Int = 0,
        isPartial: Bool = false,
        reviewedAt: Date? = nil,
        userId: Int? = nil,
        userName: String? = nil,
        userPictureURL: String? = nil,
        topPR: TrainingTopRecord? = nil
    ) {
        self.id = id
        self.title = title
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.prCount = prCount
        self.isPartial = isPartial
        self.reviewedAt = reviewedAt
        self.userId = userId
        self.userName = userName
        self.userPictureURL = userPictureURL
        self.topPR = topPR
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Workout"
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        totalSets = try container.decodeIfPresent(Int.self, forKey: .totalSets) ?? 0
        totalVolumeKg = try container.decodeIfPresent(Double.self, forKey: .totalVolumeKg) ?? 0
        prCount = try container.decodeIfPresent(Int.self, forKey: .prCount) ?? 0
        isPartial = try container.decodeIfPresent(Bool.self, forKey: .isPartial) ?? false
        reviewedAt = try container.decodeIfPresent(Date.self, forKey: .reviewedAt)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        userPictureURL = try container.decodeIfPresent(String.self, forKey: .userPictureURL)
        topPR = try container.decodeIfPresent(TrainingTopRecord.self, forKey: .topPR)
    }

    public var isReviewed: Bool { reviewedAt != nil }
}

/// La marca de una sesión tal y como viaja en `/me/program` (§6.5).
public struct TrainingTopRecord: Codable, Hashable, Sendable {

    public let exerciseName: String
    public let exerciseKey: String?
    public let weightKg: Double?
    public let reps: Int?
    public let e1rmKg: Double?

    public enum CodingKeys: String, CodingKey {
        case reps
        case exerciseName = "exercise_name"
        case exerciseKey = "exercise_key"
        case weightKg = "weight_kg"
        case e1rmKg = "e1rm_kg"
    }

    public init(
        exerciseName: String,
        exerciseKey: String? = nil,
        weightKg: Double? = nil,
        reps: Int? = nil,
        e1rmKg: Double? = nil
    ) {
        self.exerciseName = exerciseName
        self.exerciseKey = exerciseKey
        self.weightKg = weightKg
        self.reps = reps
        self.e1rmKg = e1rmKg
    }
}
