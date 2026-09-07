//
//  TrainingRecords.swift
//  TrainingCore
//
//  Marcas personales, resumen de fuerza e historial por ejercicio
//  (`/me/records`, `/me/strength-summary`, `/me/exercises/{key}/history`).
//

import Foundation

// MARK: - Marca personal

public struct TrainingPersonalRecord: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let gymId: Int?
    public let userId: Int?
    public let exerciseKey: String
    public let exerciseName: String?
    public let bestE1RMKg: Double?
    public let bestE1RMSetId: Int?
    public let bestWeightKg: Double?
    public let bestWeightSetId: Int?
    public let bestReps: Int?
    public let bestRepsSetId: Int?
    public let achievedAt: Date?
    /// Mejora respecto a la marca anterior, en kilos. Nulo en la primera marca del ejercicio.
    public let deltaKg: Double?
    /// La serie que produjo la marca, cuando el endpoint la adjunta.
    public let set: TrainingSetLog?
    public let coachCongratulated: Bool

    public enum CodingKeys: String, CodingKey {
        case id, set
        case gymId = "gym_id"
        case userId = "user_id"
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case bestE1RMKg = "best_e1rm_kg"
        case bestE1RMSetId = "best_e1rm_set_id"
        case bestWeightKg = "best_weight_kg"
        case bestWeightSetId = "best_weight_set_id"
        case bestReps = "best_reps"
        case bestRepsSetId = "best_reps_set_id"
        case achievedAt = "achieved_at"
        case deltaKg = "delta_kg"
        case coachCongratulated = "coach_congratulated"
    }

    public init(
        id: Int,
        gymId: Int? = nil,
        userId: Int? = nil,
        exerciseKey: String,
        exerciseName: String? = nil,
        bestE1RMKg: Double? = nil,
        bestE1RMSetId: Int? = nil,
        bestWeightKg: Double? = nil,
        bestWeightSetId: Int? = nil,
        bestReps: Int? = nil,
        bestRepsSetId: Int? = nil,
        achievedAt: Date? = nil,
        deltaKg: Double? = nil,
        set: TrainingSetLog? = nil,
        coachCongratulated: Bool = false
    ) {
        self.id = id
        self.gymId = gymId
        self.userId = userId
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.bestE1RMKg = bestE1RMKg
        self.bestE1RMSetId = bestE1RMSetId
        self.bestWeightKg = bestWeightKg
        self.bestWeightSetId = bestWeightSetId
        self.bestReps = bestReps
        self.bestRepsSetId = bestRepsSetId
        self.achievedAt = achievedAt
        self.deltaKg = deltaKg
        self.set = set
        self.coachCongratulated = coachCongratulated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        gymId = try container.decodeIfPresent(Int.self, forKey: .gymId)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        exerciseKey = try container.decodeIfPresent(String.self, forKey: .exerciseKey) ?? ""
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName)
        bestE1RMKg = try container.decodeIfPresent(Double.self, forKey: .bestE1RMKg)
        bestE1RMSetId = try container.decodeIfPresent(Int.self, forKey: .bestE1RMSetId)
        bestWeightKg = try container.decodeIfPresent(Double.self, forKey: .bestWeightKg)
        bestWeightSetId = try container.decodeIfPresent(Int.self, forKey: .bestWeightSetId)
        bestReps = try container.decodeIfPresent(Int.self, forKey: .bestReps)
        bestRepsSetId = try container.decodeIfPresent(Int.self, forKey: .bestRepsSetId)
        achievedAt = try container.decodeIfPresent(Date.self, forKey: .achievedAt)
        deltaKg = try container.decodeIfPresent(Double.self, forKey: .deltaKg)
        set = try container.decodeIfPresent(TrainingSetLog.self, forKey: .set)
        coachCongratulated = try container.decodeIfPresent(Bool.self, forKey: .coachCongratulated) ?? false
    }

    /// Primera marca del ejercicio: no hay delta que enseñar, se lee «first record».
    public var isFirstRecord: Bool { deltaKg == nil }

    public var displayName: String { exerciseName ?? exerciseKey }
}

// MARK: - Resumen de fuerza (W6)

public struct StrengthSummaryPoint: Codable, Hashable, Sendable {

    public let date: CalendarDate?
    public let e1rmKg: Double
    public let logId: Int?

    public enum CodingKeys: String, CodingKey {
        case date
        case e1rmKg = "e1rm_kg"
        case logId = "log_id"
    }

    public init(date: CalendarDate? = nil, e1rmKg: Double, logId: Int? = nil) {
        self.date = date
        self.e1rmKg = e1rmKg
        self.logId = logId
    }
}

public struct StrengthSummaryItem: Codable, Hashable, Identifiable, Sendable {

    public let exerciseKey: String
    public let exerciseName: String
    public let currentE1RMKg: Double?
    public let deltaKg: Double?
    public let deltaWeeks: Int?
    /// Los últimos 8 puntos de la serie que pinta la sparkline.
    public let points: [StrengthSummaryPoint]
    public let lastPR: TrainingTopRecord?

    public var id: String { exerciseKey }

    public enum CodingKeys: String, CodingKey {
        case points
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case currentE1RMKg = "current_e1rm"
        case deltaKg = "delta_kg"
        case deltaWeeks = "delta_weeks"
        case lastPR = "last_pr"
    }

    public init(
        exerciseKey: String,
        exerciseName: String,
        currentE1RMKg: Double? = nil,
        deltaKg: Double? = nil,
        deltaWeeks: Int? = nil,
        points: [StrengthSummaryPoint] = [],
        lastPR: TrainingTopRecord? = nil
    ) {
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.currentE1RMKg = currentE1RMKg
        self.deltaKg = deltaKg
        self.deltaWeeks = deltaWeeks
        self.points = points
        self.lastPR = lastPR
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseKey = try container.decodeIfPresent(String.self, forKey: .exerciseKey) ?? ""
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? ""
        currentE1RMKg = try container.decodeIfPresent(Double.self, forKey: .currentE1RMKg)
        deltaKg = try container.decodeIfPresent(Double.self, forKey: .deltaKg)
        deltaWeeks = try container.decodeIfPresent(Int.self, forKey: .deltaWeeks)
        points = try container.decodeIfPresent([StrengthSummaryPoint].self, forKey: .points) ?? []
        lastPR = try container.decodeIfPresent(TrainingTopRecord.self, forKey: .lastPR)
    }

    /// La tarjeta de fuerza solo se enseña con serie real; con menos de dos puntos se conserva
    /// la tarjeta de objetivo que ya existe (plan §8.2).
    public var hasEnoughDataForChart: Bool { points.count >= 2 }
}

// MARK: - Historial por ejercicio (S15)

public struct ExerciseHistorySession: Codable, Hashable, Identifiable, Sendable {

    public let logId: Int
    public let date: CalendarDate?
    public let completedAt: Date?
    public let title: String?
    public let bestE1RMKg: Double?
    public let sets: [TrainingSetLog]

    public var id: Int { logId }

    public enum CodingKeys: String, CodingKey {
        case date, title, sets
        case logId = "log_id"
        case completedAt = "completed_at"
        case bestE1RMKg = "best_e1rm_kg"
    }

    public init(
        logId: Int,
        date: CalendarDate? = nil,
        completedAt: Date? = nil,
        title: String? = nil,
        bestE1RMKg: Double? = nil,
        sets: [TrainingSetLog] = []
    ) {
        self.logId = logId
        self.date = date
        self.completedAt = completedAt
        self.title = title
        self.bestE1RMKg = bestE1RMKg
        self.sets = sets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logId = try container.decode(Int.self, forKey: .logId)
        date = try container.decodeIfPresent(CalendarDate.self, forKey: .date)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        bestE1RMKg = try container.decodeIfPresent(Double.self, forKey: .bestE1RMKg)
        sets = try container.decodeIfPresent([TrainingSetLog].self, forKey: .sets) ?? []
    }
}

public struct ExerciseHistory: Codable, Hashable, Sendable {

    public let exerciseKey: String
    public let exerciseName: String
    /// `8w`, `6m` o `all`.
    public let range: String?
    public let points: [StrengthSummaryPoint]
    public let bestSets: [TrainingSetLog]
    public let sessions: [ExerciseHistorySession]

    public enum CodingKeys: String, CodingKey {
        case range, points, sessions
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case bestSets = "best_sets"
    }

    public init(
        exerciseKey: String,
        exerciseName: String,
        range: String? = nil,
        points: [StrengthSummaryPoint] = [],
        bestSets: [TrainingSetLog] = [],
        sessions: [ExerciseHistorySession] = []
    ) {
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.range = range
        self.points = points
        self.bestSets = bestSets
        self.sessions = sessions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseKey = try container.decodeIfPresent(String.self, forKey: .exerciseKey) ?? ""
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? ""
        range = try container.decodeIfPresent(String.self, forKey: .range)
        points = try container.decodeIfPresent([StrengthSummaryPoint].self, forKey: .points) ?? []
        bestSets = try container.decodeIfPresent([TrainingSetLog].self, forKey: .bestSets) ?? []
        sessions = try container.decodeIfPresent([ExerciseHistorySession].self, forKey: .sessions) ?? []
    }
}
