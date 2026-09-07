//
//  TrainingProgram.swift
//  TrainingCore
//
//  Programa, bloque, día y ejercicio del día con su prescripción (plan §4.4 y §5).
//

import Foundation

// MARK: - Programa

public struct TrainingProgram: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let gymId: Int?
    public let creatorId: Int?
    public let name: String
    public let description: String?
    public let goal: String?
    public let durationWeeks: Int
    public let status: TrainingProgramStatus
    public let visibility: TrainingProgramVisibility
    public let isTemplate: Bool
    public let sourceProgramId: Int?
    /// Hasta tres claves de ejercicio que alimentan la tarjeta de fuerza (W6).
    public let focusExerciseKeys: [String]
    /// Solo en la lista del entrenador.
    public let assignedCount: Int?

    public enum CodingKeys: String, CodingKey {
        case id, name, description, goal, status, visibility
        case gymId = "gym_id"
        case creatorId = "creator_id"
        case durationWeeks = "duration_weeks"
        case isTemplate = "is_template"
        case sourceProgramId = "source_program_id"
        case focusExerciseKeys = "focus_exercise_keys"
        case assignedCount = "assigned_count"
    }

    public init(
        id: Int,
        gymId: Int? = nil,
        creatorId: Int? = nil,
        name: String,
        description: String? = nil,
        goal: String? = nil,
        durationWeeks: Int,
        status: TrainingProgramStatus = .draft,
        visibility: TrainingProgramVisibility = .private,
        isTemplate: Bool = true,
        sourceProgramId: Int? = nil,
        focusExerciseKeys: [String] = [],
        assignedCount: Int? = nil
    ) {
        self.id = id
        self.gymId = gymId
        self.creatorId = creatorId
        self.name = name
        self.description = description
        self.goal = goal
        self.durationWeeks = durationWeeks
        self.status = status
        self.visibility = visibility
        self.isTemplate = isTemplate
        self.sourceProgramId = sourceProgramId
        self.focusExerciseKeys = focusExerciseKeys
        self.assignedCount = assignedCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        gymId = try container.decodeIfPresent(Int.self, forKey: .gymId)
        creatorId = try container.decodeIfPresent(Int.self, forKey: .creatorId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
        durationWeeks = try container.decodeIfPresent(Int.self, forKey: .durationWeeks) ?? 1
        status = try container.decodeIfPresent(TrainingProgramStatus.self, forKey: .status) ?? .draft
        visibility = try container.decodeIfPresent(TrainingProgramVisibility.self, forKey: .visibility) ?? .private
        isTemplate = try container.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? true
        sourceProgramId = try container.decodeIfPresent(Int.self, forKey: .sourceProgramId)
        focusExerciseKeys = try container.decodeIfPresent([String].self, forKey: .focusExerciseKeys) ?? []
        assignedCount = try container.decodeIfPresent(Int.self, forKey: .assignedCount)
    }

    /// Días posibles del programa: `duration_weeks × 7` (plan §4.2).
    public var totalDays: Int { WeekMath.totalDays(durationWeeks: durationWeeks) }

    /// Un programa compartido con visibilidad de grupo es el único que enseña comunidad.
    public var showsGroupFeatures: Bool { visibility == .group }
}

// MARK: - Bloque

public struct TrainingBlock: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let programId: Int?
    public let name: String
    public let focus: String?
    public let weekStart: Int
    public let weekEnd: Int
    public let orderIndex: Int
    public let notes: String?

    public enum CodingKeys: String, CodingKey {
        case id, name, focus, notes
        case programId = "program_id"
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case orderIndex = "order_index"
    }

    public init(
        id: Int,
        programId: Int? = nil,
        name: String,
        focus: String? = nil,
        weekStart: Int,
        weekEnd: Int,
        orderIndex: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.programId = programId
        self.name = name
        self.focus = focus
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.orderIndex = orderIndex
        self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        programId = try container.decodeIfPresent(Int.self, forKey: .programId)
        name = try container.decode(String.self, forKey: .name)
        focus = try container.decodeIfPresent(String.self, forKey: .focus)
        weekStart = try container.decodeIfPresent(Int.self, forKey: .weekStart) ?? 1
        weekEnd = try container.decodeIfPresent(Int.self, forKey: .weekEnd) ?? 1
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    public func contains(week: Int) -> Bool { (weekStart...max(weekStart, weekEnd)).contains(week) }

    public var weekCount: Int { max(0, weekEnd - weekStart + 1) }
}

// MARK: - Prescripción por serie

/// Ajuste de una serie concreta dentro de la prescripción (`set_overrides`, plan §4.4).
public struct TrainingSetOverride: Codable, Hashable, Sendable {

    public let setNumber: Int
    public let reps: String?
    public let loadValue: Double?
    public let rpeTarget: Double?
    public let restSeconds: Int?

    public enum CodingKeys: String, CodingKey {
        case reps
        case setNumber = "set_number"
        case loadValue = "load_value"
        case rpeTarget = "rpe_target"
        case restSeconds = "rest_seconds"
    }

    public init(
        setNumber: Int,
        reps: String? = nil,
        loadValue: Double? = nil,
        rpeTarget: Double? = nil,
        restSeconds: Int? = nil
    ) {
        self.setNumber = setNumber
        self.reps = reps
        self.loadValue = loadValue
        self.rpeTarget = rpeTarget
        self.restSeconds = restSeconds
    }
}

// MARK: - Ejercicio del día

public struct TrainingDayExercise: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let dayId: Int?
    public let exerciseId: Int?
    public let exerciseKey: String
    public let exerciseName: String
    public let orderIndex: Int
    public let supersetGroup: String?
    public let setsCount: Int
    /// Texto libre del contrato: "5", "8-10", "AMRAP".
    public let reps: String
    public let loadMode: TrainingLoadMode
    /// Kilos si `load_mode == .weight`, porcentaje si `.percent1RM`, nulo en el resto.
    public let loadValue: Double?
    public let rpeTarget: Double?
    public let restSeconds: Int
    public let notes: String?
    public let setOverrides: [TrainingSetOverride]?
    /// Solo en `GET /me/days/{id}`: la última serie superior y la sugerencia del servidor.
    public let lastPerformance: TrainingLastPerformance?

    public enum CodingKeys: String, CodingKey {
        case id, reps, notes
        case dayId = "day_id"
        case exerciseId = "exercise_id"
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case orderIndex = "order_index"
        case supersetGroup = "superset_group"
        case setsCount = "sets_count"
        case loadMode = "load_mode"
        case loadValue = "load_value"
        case rpeTarget = "rpe_target"
        case restSeconds = "rest_seconds"
        case setOverrides = "set_overrides"
        case lastPerformance = "last_performance"
    }

    public init(
        id: Int,
        dayId: Int? = nil,
        exerciseId: Int? = nil,
        exerciseKey: String,
        exerciseName: String,
        orderIndex: Int = 0,
        supersetGroup: String? = nil,
        setsCount: Int,
        reps: String,
        loadMode: TrainingLoadMode = .weight,
        loadValue: Double? = nil,
        rpeTarget: Double? = nil,
        restSeconds: Int = 90,
        notes: String? = nil,
        setOverrides: [TrainingSetOverride]? = nil,
        lastPerformance: TrainingLastPerformance? = nil
    ) {
        self.id = id
        self.dayId = dayId
        self.exerciseId = exerciseId
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.supersetGroup = supersetGroup
        self.setsCount = setsCount
        self.reps = reps
        self.loadMode = loadMode
        self.loadValue = loadValue
        self.rpeTarget = rpeTarget
        self.restSeconds = restSeconds
        self.notes = notes
        self.setOverrides = setOverrides
        self.lastPerformance = lastPerformance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        dayId = try container.decodeIfPresent(Int.self, forKey: .dayId)
        exerciseId = try container.decodeIfPresent(Int.self, forKey: .exerciseId)
        exerciseKey = try container.decode(String.self, forKey: .exerciseKey)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        supersetGroup = try container.decodeIfPresent(String.self, forKey: .supersetGroup)
        setsCount = try container.decodeIfPresent(Int.self, forKey: .setsCount) ?? 1
        reps = try container.decodeIfPresent(String.self, forKey: .reps) ?? ""
        loadMode = try container.decodeIfPresent(TrainingLoadMode.self, forKey: .loadMode) ?? .weight
        loadValue = try container.decodeIfPresent(Double.self, forKey: .loadValue)
        rpeTarget = try container.decodeIfPresent(Double.self, forKey: .rpeTarget)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        setOverrides = try container.decodeIfPresent([TrainingSetOverride].self, forKey: .setOverrides)
        lastPerformance = try container.decodeIfPresent(TrainingLastPerformance.self, forKey: .lastPerformance)
    }

    /// Ajuste declarado para una serie (1-based), si lo hay.
    public func override(forSet setNumber: Int) -> TrainingSetOverride? {
        setOverrides?.first { $0.setNumber == setNumber }
    }

    /// Descanso efectivo de una serie: el override manda sobre la prescripción del ejercicio.
    public func restSeconds(forSet setNumber: Int) -> Int {
        override(forSet: setNumber)?.restSeconds ?? restSeconds
    }

    /// Reps prescritas de una serie, ya resuelto el override.
    public func reps(forSet setNumber: Int) -> String {
        override(forSet: setNumber)?.reps ?? reps
    }

    /// Carga prescrita de una serie, ya resuelto el override. En kilos solo si `loadMode == .weight`.
    public func loadValue(forSet setNumber: Int) -> Double? {
        override(forSet: setNumber)?.loadValue ?? loadValue
    }

    public func rpeTarget(forSet setNumber: Int) -> Double? {
        override(forSet: setNumber)?.rpeTarget ?? rpeTarget
    }

    /// `true` cuando las reps no son un número: "AMRAP", "8-10"…
    public var isAMRAP: Bool { reps.uppercased().contains("AMRAP") }

    /// Primer número de las reps prescritas, para poder precargar la fila de la serie.
    /// "8-10" → 8, "AMRAP" → nil, "5" → 5.
    public var targetReps: Int? {
        let digits = reps.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }
}

// MARK: - Última ejecución

/// `GET /me/days/{id}` y `GET /clients/{id}/exercises/{key}/last-performance`.
public struct TrainingLastPerformance: Codable, Hashable, Sendable {

    public let exerciseKey: String?
    public let weightKg: Double?
    public let reps: Int?
    public let e1rmKg: Double?
    public let performedAt: Date?
    /// Sugerencia del servidor, ya redondeada al paso de la unidad del cliente.
    public let suggestedWeightKg: Double?

    public enum CodingKeys: String, CodingKey {
        case reps
        case exerciseKey = "exercise_key"
        case weightKg = "weight_kg"
        case e1rmKg = "e1rm_kg"
        case performedAt = "performed_at"
        case suggestedWeightKg = "suggested_weight_kg"
    }

    public init(
        exerciseKey: String? = nil,
        weightKg: Double? = nil,
        reps: Int? = nil,
        e1rmKg: Double? = nil,
        performedAt: Date? = nil,
        suggestedWeightKg: Double? = nil
    ) {
        self.exerciseKey = exerciseKey
        self.weightKg = weightKg
        self.reps = reps
        self.e1rmKg = e1rmKg
        self.performedAt = performedAt
        self.suggestedWeightKg = suggestedWeightKg
    }
}

// MARK: - Día

public struct TrainingDay: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let programId: Int?
    public let dayNumber: Int
    /// El servidor la manda derivada; si falta se calcula con `WeekMath`.
    public let weekNumber: Int
    public let name: String?
    public let isRest: Bool
    public let focus: String?
    public let notes: String?
    public let isPublished: Bool
    public let exercises: [TrainingDayExercise]
    /// Nota del coach de esa fecha, cuando el endpoint la incluye.
    public let coachNote: TrainingClientDayNote?

    public enum CodingKeys: String, CodingKey {
        case id, name, focus, notes, exercises
        case programId = "program_id"
        case dayNumber = "day_number"
        case weekNumber = "week_number"
        case isRest = "is_rest"
        case isPublished = "is_published"
        case coachNote = "coach_note"
    }

    public init(
        id: Int,
        programId: Int? = nil,
        dayNumber: Int,
        weekNumber: Int? = nil,
        name: String? = nil,
        isRest: Bool = false,
        focus: String? = nil,
        notes: String? = nil,
        isPublished: Bool = true,
        exercises: [TrainingDayExercise] = [],
        coachNote: TrainingClientDayNote? = nil
    ) {
        self.id = id
        self.programId = programId
        self.dayNumber = dayNumber
        self.weekNumber = weekNumber ?? WeekMath.weekNumber(forDayNumber: dayNumber)
        self.name = name
        self.isRest = isRest
        self.focus = focus
        self.notes = notes
        self.isPublished = isPublished
        self.exercises = exercises
        self.coachNote = coachNote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        programId = try container.decodeIfPresent(Int.self, forKey: .programId)
        let number = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1
        dayNumber = number
        weekNumber = try container.decodeIfPresent(Int.self, forKey: .weekNumber)
            ?? WeekMath.weekNumber(forDayNumber: number)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        isRest = try container.decodeIfPresent(Bool.self, forKey: .isRest) ?? false
        focus = try container.decodeIfPresent(String.self, forKey: .focus)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isPublished = try container.decodeIfPresent(Bool.self, forKey: .isPublished) ?? true
        exercises = try container.decodeIfPresent([TrainingDayExercise].self, forKey: .exercises) ?? []
        coachNote = try container.decodeIfPresent(TrainingClientDayNote.self, forKey: .coachNote)
    }

    /// Título que se enseña arriba de la sesión. Sin nombre, el día se llama por su número.
    public var displayName: String {
        if let name, !name.isEmpty { return name }
        return isRest ? "Rest day" : "Day \(dayNumber)"
    }

    /// Series prescritas del día, que es el denominador de «6 of 18 sets».
    public var plannedSetCount: Int {
        exercises.reduce(0) { $0 + $1.setsCount }
    }

    public var exercisesInOrder: [TrainingDayExercise] {
        exercises.sorted { ($0.orderIndex, $0.id) < ($1.orderIndex, $1.id) }
    }
}

// MARK: - Resumen de un día de la semana (W4 y S12)

public struct TrainingWeekDay: Codable, Hashable, Identifiable, Sendable {

    public let dayNumber: Int
    public let date: CalendarDate?
    public let dayId: Int?
    public let name: String?
    public let isRest: Bool
    public let status: TrainingDayStatus
    public let exerciseCount: Int
    public let logId: Int?
    /// Tres nombres de ejercicio para la vista de semana (S12).
    public let exercisePreview: [String]

    public var id: Int { dayNumber }

    public enum CodingKeys: String, CodingKey {
        case name, status, date
        case dayNumber = "day_number"
        case dayId = "day_id"
        case isRest = "is_rest"
        case exerciseCount = "exercise_count"
        case logId = "log_id"
        case exercisePreview = "exercise_preview"
    }

    public init(
        dayNumber: Int,
        date: CalendarDate? = nil,
        dayId: Int? = nil,
        name: String? = nil,
        isRest: Bool = false,
        status: TrainingDayStatus = .pending,
        exerciseCount: Int = 0,
        logId: Int? = nil,
        exercisePreview: [String] = []
    ) {
        self.dayNumber = dayNumber
        self.date = date
        self.dayId = dayId
        self.name = name
        self.isRest = isRest
        self.status = status
        self.exerciseCount = exerciseCount
        self.logId = logId
        self.exercisePreview = exercisePreview
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayNumber = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1
        date = try container.decodeIfPresent(CalendarDate.self, forKey: .date)
        dayId = try container.decodeIfPresent(Int.self, forKey: .dayId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        isRest = try container.decodeIfPresent(Bool.self, forKey: .isRest) ?? false
        status = try container.decodeIfPresent(TrainingDayStatus.self, forKey: .status) ?? .pending
        exerciseCount = try container.decodeIfPresent(Int.self, forKey: .exerciseCount) ?? 0
        logId = try container.decodeIfPresent(Int.self, forKey: .logId)
        exercisePreview = try container.decodeIfPresent([String].self, forKey: .exercisePreview) ?? []
    }

    public var weekNumber: Int { WeekMath.weekNumber(forDayNumber: dayNumber) }
}

// MARK: - Semana

public struct TrainingWeek: Codable, Hashable, Sendable {

    public let weekNumber: Int
    public let doneCount: Int
    public let plannedCount: Int
    public let days: [TrainingWeekDay]

    public enum CodingKeys: String, CodingKey {
        case days
        case weekNumber = "week_number"
        case doneCount = "done_count"
        case plannedCount = "planned_count"
    }

    public init(weekNumber: Int, doneCount: Int = 0, plannedCount: Int = 0, days: [TrainingWeekDay] = []) {
        self.weekNumber = weekNumber
        self.doneCount = doneCount
        self.plannedCount = plannedCount
        self.days = days
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekNumber = try container.decodeIfPresent(Int.self, forKey: .weekNumber) ?? 1
        doneCount = try container.decodeIfPresent(Int.self, forKey: .doneCount) ?? 0
        plannedCount = try container.decodeIfPresent(Int.self, forKey: .plannedCount) ?? 0
        days = try container.decodeIfPresent([TrainingWeekDay].self, forKey: .days) ?? []
    }

    /// «2 of 5» de la cabecera de W4. Sin días planificados no se enseña progreso.
    public var progressText: String? {
        guard plannedCount > 0 else { return nil }
        return "\(doneCount) of \(plannedCount)"
    }
}
