//
//  TrainingStaff.swift
//  TrainingCore
//
//  El contrato del ENTRENADOR (plan §6.2, WP2-informe §4).
//
//  Los tipos del cliente ya viven en los otros ficheros de `Models/`; aquí solo entra lo que
//  únicamente ve quien escribe programas: el programa con sus bloques, la ficha de un cliente,
//  los sobres de respuesta que el backend usa en las escrituras y los cuerpos de petición.
//
//  Dos reglas que se repiten y conviene no perder de vista:
//
//  1. **Las escrituras vienen envueltas.** `POST /assign` devuelve `{assignments: [..]}` y las
//     duplicaciones `{copied_days, target_day_numbers}`. Se modelan tal cual: desenvolverlas en
//     el servicio esconde el contrato donde nadie lo lee.
//  2. **`PUT /days/{n}` es un reemplazo completo.** El cuerpo lleva TODOS los ejercicios del día;
//     lo que no viaje deja de existir. Por eso el tipo de entrada es propio (`DayExerciseInput`)
//     y no el modelo de lectura: son cosas distintas y confundirlas borra ejercicios.
//

import Foundation

// MARK: - Programa con bloques

/// `GET /training/programs/{id}`: el programa con sus bloques embebidos y **sin** días.
public struct TrainingProgramDetail: Codable, Hashable, Identifiable, Sendable {

    public let program: TrainingProgram
    public let blocks: [TrainingBlock]

    public var id: Int { program.id }

    public init(program: TrainingProgram, blocks: [TrainingBlock] = []) {
        self.program = program
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case blocks
    }

    public init(from decoder: Decoder) throws {
        // El programa vive en el MISMO objeto que los bloques, no anidado: se decodifica dos
        // veces sobre el mismo contenedor.
        program = try TrainingProgram(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks = (try container.decodeIfPresent([TrainingBlock].self, forKey: .blocks) ?? [])
            .sorted { ($0.orderIndex, $0.weekStart) < ($1.orderIndex, $1.weekStart) }
    }

    public func encode(to encoder: Encoder) throws {
        try program.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blocks, forKey: .blocks)
    }

    /// El bloque que contiene una semana, si hay alguno.
    public func block(forWeek week: Int) -> TrainingBlock? {
        blocks.first { $0.contains(week: week) }
    }
}

// MARK: - Ficha del cliente

/// Un programa desde el punto de vista del entrenador: `GET /clients/{id}/programs`.
public struct ClientProgramSummary: Codable, Hashable, Identifiable, Sendable {

    public let assignment: TrainingAssignment
    public let program: TrainingProgram
    public let currentWeek: Int?
    public let currentDayNumber: Int?
    public let currentBlock: TrainingBlock?
    /// Los siete días de la semana en curso. Nulo en un programa que ya terminó.
    public let week: TrainingWeek?
    /// Registros completados ÷ días de entreno transcurridos. Nulo si aún no ha pasado ninguno.
    public let adherencePct: Double?
    /// Días de entreno del bloque actual ya pasados sin registro. Nulo si no hay bloques.
    public let missedInBlock: Int?

    public var id: Int { assignment.id }

    public enum CodingKeys: String, CodingKey {
        case assignment, program, week
        case currentWeek = "current_week"
        case currentDayNumber = "current_day_number"
        case currentBlock = "current_block"
        case adherencePct = "adherence_pct"
        case missedInBlock = "missed_in_block"
    }

    public init(
        assignment: TrainingAssignment,
        program: TrainingProgram,
        currentWeek: Int? = nil,
        currentDayNumber: Int? = nil,
        currentBlock: TrainingBlock? = nil,
        week: TrainingWeek? = nil,
        adherencePct: Double? = nil,
        missedInBlock: Int? = nil
    ) {
        self.assignment = assignment
        self.program = program
        self.currentWeek = currentWeek
        self.currentDayNumber = currentDayNumber
        self.currentBlock = currentBlock
        self.week = week
        self.adherencePct = adherencePct
        self.missedInBlock = missedInBlock
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assignment = try container.decode(TrainingAssignment.self, forKey: .assignment)
        program = try container.decode(TrainingProgram.self, forKey: .program)
        currentWeek = try container.decodeIfPresent(Int.self, forKey: .currentWeek)
        currentDayNumber = try container.decodeIfPresent(Int.self, forKey: .currentDayNumber)
        currentBlock = try container.decodeIfPresent(TrainingBlock.self, forKey: .currentBlock)
        week = try container.decodeIfPresent(TrainingWeek.self, forKey: .week)
        adherencePct = try container.decodeIfPresent(Double.self, forKey: .adherencePct)
        missedInBlock = try container.decodeIfPresent(Int.self, forKey: .missedInBlock)
    }

    /// La adherencia se pinta en `warn` por debajo de este valor (UX §6, S20). Es un dato, no
    /// una alarma: el número cambia de color, el texto sigue diciendo hechos.
    public static let lowAdherenceThreshold: Double = 50

    public var isAdherenceLow: Bool {
        guard let adherencePct else { return false }
        return adherencePct < Self.lowAdherenceThreshold
    }

    /// «3 sessions missed this block». Nulo cuando no hay bloques o no falta ninguna.
    public var missedText: String? {
        guard let missedInBlock, missedInBlock > 0 else { return nil }
        return "\(missedInBlock) session\(missedInBlock == 1 ? "" : "s") missed this block"
    }

    /// Semanas seleccionables en el carrusel de S20: todas las del programa.
    public var weekRange: ClosedRange<Int> { 1...max(1, program.durationWeeks) }
}

/// `GET /training/clients/{user_id}/programs` → `{active, past}`.
public struct ClientProgramsResponse: Codable, Hashable, Sendable {

    public let active: ClientProgramSummary?
    public let past: [ClientProgramSummary]

    public enum CodingKeys: String, CodingKey {
        case active, past
    }

    public init(active: ClientProgramSummary? = nil, past: [ClientProgramSummary] = []) {
        self.active = active
        self.past = past
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decodeIfPresent(ClientProgramSummary.self, forKey: .active)
        past = try container.decodeIfPresent([ClientProgramSummary].self, forKey: .past) ?? []
    }

    public var hasAnyProgram: Bool { active != nil || !past.isEmpty }
}

/// `GET /training/clients/{id}/exercises/{key}/last-performance`.
///
/// Es `TrainingLastPerformance` más la serie completa. Se modela aparte porque el endpoint del
/// cliente no manda `last_set` y mezclar los dos deja un opcional que nadie sabe cuándo llega.
public struct ClientLastPerformance: Codable, Hashable, Sendable {

    public let exerciseKey: String?
    public let performedAt: Date?
    public let reps: Int?
    public let weightKg: Double?
    public let e1rmKg: Double?
    /// Carga anterior + 2,5 kg. El redondeo al paso de la unidad lo hace la interfaz.
    public let suggestedWeightKg: Double?
    public let lastSet: TrainingSetLog?

    public enum CodingKeys: String, CodingKey {
        case reps
        case exerciseKey = "exercise_key"
        case performedAt = "performed_at"
        case weightKg = "weight_kg"
        case e1rmKg = "e1rm_kg"
        case suggestedWeightKg = "suggested_weight_kg"
        case lastSet = "last_set"
    }

    public init(
        exerciseKey: String? = nil,
        performedAt: Date? = nil,
        reps: Int? = nil,
        weightKg: Double? = nil,
        e1rmKg: Double? = nil,
        suggestedWeightKg: Double? = nil,
        lastSet: TrainingSetLog? = nil
    ) {
        self.exerciseKey = exerciseKey
        self.performedAt = performedAt
        self.reps = reps
        self.weightKg = weightKg
        self.e1rmKg = e1rmKg
        self.suggestedWeightKg = suggestedWeightKg
        self.lastSet = lastSet
    }

    public var hasData: Bool { weightKg != nil || reps != nil }
}

// MARK: - Sobres de las escrituras

/// `POST /training/programs/{id}/assign` → `{assignments: [..]}`.
public struct AssignmentsResponse: Codable, Hashable, Sendable {

    public let assignments: [TrainingAssignment]

    public enum CodingKeys: String, CodingKey {
        case assignments
    }

    public init(assignments: [TrainingAssignment]) {
        self.assignments = assignments
    }

    public init(from decoder: Decoder) throws {
        // También se acepta el array desnudo, que es como lo describía el plan antes de WP2.
        if let list = try? decoder.singleValueContainer().decode([TrainingAssignment].self) {
            self.init(assignments: list)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(assignments: try container.decodeIfPresent([TrainingAssignment].self, forKey: .assignments) ?? [])
    }
}

/// Respuesta de duplicar una semana o un día: `{copied_days, target_day_numbers}`.
public struct DuplicateResult: Codable, Hashable, Sendable {

    public let copiedDays: Int
    public let targetDayNumbers: [Int]

    public enum CodingKeys: String, CodingKey {
        case copiedDays = "copied_days"
        case targetDayNumbers = "target_day_numbers"
    }

    public init(copiedDays: Int, targetDayNumbers: [Int] = []) {
        self.copiedDays = copiedDays
        self.targetDayNumbers = targetDayNumbers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        copiedDays = try container.decodeIfPresent(Int.self, forKey: .copiedDays) ?? 0
        targetDayNumbers = try container.decodeIfPresent([Int].self, forKey: .targetDayNumbers) ?? []
    }
}

// MARK: - Cuerpos de petición

/// `POST /training/programs`.
public struct ProgramCreateRequest: Codable, Hashable, Sendable {

    public let name: String
    public let description: String?
    public let goal: String?
    public let durationWeeks: Int
    public let visibility: TrainingProgramVisibility
    public let focusExerciseKeys: [String]?

    public enum CodingKeys: String, CodingKey {
        case name, description, goal, visibility
        case durationWeeks = "duration_weeks"
        case focusExerciseKeys = "focus_exercise_keys"
    }

    public init(
        name: String,
        description: String? = nil,
        goal: String? = nil,
        durationWeeks: Int,
        visibility: TrainingProgramVisibility = .private,
        focusExerciseKeys: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.goal = goal
        self.durationWeeks = durationWeeks
        self.visibility = visibility
        self.focusExerciseKeys = focusExerciseKeys
    }
}

/// `POST`/`PUT /training/programs/{id}/blocks[/{block_id}]`.
public struct BlockRequest: Codable, Hashable, Sendable {

    public let name: String
    public let focus: String?
    public let weekStart: Int
    public let weekEnd: Int
    public let orderIndex: Int?
    public let notes: String?

    public enum CodingKeys: String, CodingKey {
        case name, focus, notes
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case orderIndex = "order_index"
    }

    public init(
        name: String,
        focus: String? = nil,
        weekStart: Int,
        weekEnd: Int,
        orderIndex: Int? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.focus = focus
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.orderIndex = orderIndex
        self.notes = notes
    }
}

/// Un ejercicio dentro del cuerpo de `PUT /programs/{id}/days/{day_number}`.
///
/// No es el modelo de lectura: no lleva `id` ni `day_id` porque el reemplazo los recrea, y el
/// `exercise_name` es opcional porque el servidor lo resuelve del catálogo si conoce la clave.
public struct DayExerciseInput: Codable, Hashable, Identifiable, Sendable {

    /// Identidad **local**, para que la lista de S21 pueda reordenarse y editarse sin ids de
    /// servidor. Nunca se envía.
    public let localId: UUID
    public var exerciseKey: String
    public var exerciseName: String?
    public var exerciseId: Int?
    public var orderIndex: Int
    public var supersetGroup: String?
    public var setsCount: Int
    public var reps: String
    /// Con qué se mide (contrato §8.1). Por defecto `reps`, como todo lo que ya estaba escrito.
    public var measure: TrainingMeasure
    public var durationSeconds: Int?
    public var distanceMeters: Double?
    public var loadMode: TrainingLoadMode
    public var loadValue: Double?
    public var rpeTarget: Double?
    public var restSeconds: Int
    public var notes: String?
    public var setOverrides: [TrainingSetOverride]?

    public var id: UUID { localId }

    public enum CodingKeys: String, CodingKey {
        case reps, notes, measure
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_m"
        case exerciseKey = "exercise_key"
        case exerciseName = "exercise_name"
        case exerciseId = "exercise_id"
        case orderIndex = "order_index"
        case supersetGroup = "superset_group"
        case setsCount = "sets_count"
        case loadMode = "load_mode"
        case loadValue = "load_value"
        case rpeTarget = "rpe_target"
        case restSeconds = "rest_seconds"
        case setOverrides = "set_overrides"
    }

    public init(
        localId: UUID = UUID(),
        exerciseKey: String,
        exerciseName: String? = nil,
        exerciseId: Int? = nil,
        orderIndex: Int = 0,
        supersetGroup: String? = nil,
        setsCount: Int = 3,
        reps: String = "5",
        measure: TrainingMeasure = .reps,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        loadMode: TrainingLoadMode = .weight,
        loadValue: Double? = nil,
        rpeTarget: Double? = nil,
        restSeconds: Int = 90,
        notes: String? = nil,
        setOverrides: [TrainingSetOverride]? = nil
    ) {
        self.localId = localId
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.supersetGroup = supersetGroup
        self.setsCount = setsCount
        self.reps = reps
        self.measure = measure
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.loadMode = loadMode
        self.loadValue = loadValue
        self.rpeTarget = rpeTarget
        self.restSeconds = restSeconds
        self.notes = notes
        self.setOverrides = setOverrides
    }

    /// De lo que se leyó a lo que se va a editar. La identidad local es nueva: el `id` de
    /// servidor no sobrevive al reemplazo.
    public init(from exercise: TrainingDayExercise) {
        self.init(
            exerciseKey: exercise.exerciseKey,
            exerciseName: exercise.exerciseName,
            exerciseId: exercise.exerciseId,
            orderIndex: exercise.orderIndex,
            supersetGroup: exercise.supersetGroup,
            setsCount: exercise.setsCount,
            reps: exercise.reps,
            measure: exercise.measure,
            durationSeconds: exercise.durationSeconds,
            distanceMeters: exercise.distanceMeters,
            loadMode: exercise.loadMode,
            loadValue: exercise.loadValue,
            rpeTarget: exercise.rpeTarget,
            restSeconds: exercise.restSeconds,
            notes: exercise.notes,
            setOverrides: exercise.setOverrides
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localId = UUID()
        exerciseKey = try container.decode(String.self, forKey: .exerciseKey)
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName)
        exerciseId = try container.decodeIfPresent(Int.self, forKey: .exerciseId)
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        supersetGroup = try container.decodeIfPresent(String.self, forKey: .supersetGroup)
        setsCount = try container.decodeIfPresent(Int.self, forKey: .setsCount) ?? 1
        reps = try container.decodeIfPresent(String.self, forKey: .reps) ?? ""
        measure = try container.decodeIfPresent(TrainingMeasure.self, forKey: .measure) ?? .reps
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        loadMode = try container.decodeIfPresent(TrainingLoadMode.self, forKey: .loadMode) ?? .weight
        loadValue = try container.decodeIfPresent(Double.self, forKey: .loadValue)
        rpeTarget = try container.decodeIfPresent(Double.self, forKey: .rpeTarget)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        setOverrides = try container.decodeIfPresent([TrainingSetOverride].self, forKey: .setOverrides)
    }

    /// Vista de lectura equivalente, para reutilizar `TrainingPrescription` sin duplicarlo.
    public func previewExercise(id: Int = 0) -> TrainingDayExercise {
        TrainingDayExercise(
            id: id,
            exerciseId: exerciseId,
            exerciseKey: exerciseKey,
            exerciseName: exerciseName ?? exerciseKey,
            orderIndex: orderIndex,
            supersetGroup: supersetGroup,
            setsCount: setsCount,
            reps: reps,
            measure: measure,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            loadMode: loadMode,
            loadValue: loadValue,
            rpeTarget: rpeTarget,
            restSeconds: restSeconds,
            notes: notes,
            setOverrides: setOverrides
        )
    }

    public var displayName: String { exerciseName ?? exerciseKey }
}

/// Cuerpo de `PUT /training/programs/{id}/days/{day_number}`. **Reemplazo completo.**
public struct DayUpsertRequest: Codable, Hashable, Sendable {

    public let name: String?
    public let isRest: Bool
    public let focus: String?
    public let notes: String?
    public let isPublished: Bool?
    public let exercises: [DayExerciseInput]

    public enum CodingKeys: String, CodingKey {
        case name, focus, notes, exercises
        case isRest = "is_rest"
        case isPublished = "is_published"
    }

    public init(
        name: String? = nil,
        isRest: Bool,
        focus: String? = nil,
        notes: String? = nil,
        isPublished: Bool? = nil,
        exercises: [DayExerciseInput]
    ) {
        self.name = name
        self.isRest = isRest
        self.focus = focus
        self.notes = notes
        self.isPublished = isPublished
        // El servidor ordena por `order_index`: se renumera aquí para que la lista que se ve
        // sea la lista que se guarda, pase lo que pase con los arrastres.
        self.exercises = exercises.enumerated().map { index, exercise in
            var copy = exercise
            copy.orderIndex = index
            return copy
        }
    }
}

/// `POST /training/programs/{id}/weeks/{week}/duplicate`.
public struct DuplicateWeekRequest: Codable, Hashable, Sendable {

    public let targetWeeks: [Int]
    /// `false` deja `load_value` nulo **solo** cuando `load_mode` es `weight`: un porcentaje o
    /// un RPE siguen siendo válidos la semana que viene (WP2-informe §4.3).
    public let keepLoads: Bool

    public enum CodingKeys: String, CodingKey {
        case targetWeeks = "target_weeks"
        case keepLoads = "keep_loads"
    }

    public init(targetWeeks: [Int], keepLoads: Bool = true) {
        self.targetWeeks = targetWeeks.sorted()
        self.keepLoads = keepLoads
    }
}

/// `POST /training/programs/{id}/days/{n}/duplicate`.
public struct DuplicateDayRequest: Codable, Hashable, Sendable {

    public let targetDayNumbers: [Int]

    public enum CodingKeys: String, CodingKey {
        case targetDayNumbers = "target_day_numbers"
    }

    public init(targetDayNumbers: [Int]) {
        self.targetDayNumbers = targetDayNumbers.sorted()
    }
}

/// `POST`/`PUT /training/exercises[/{id}]`. La clave la genera el servidor y la ignora del cuerpo.
public struct ExerciseCatalogRequest: Codable, Hashable, Sendable {

    public let name: String
    public let category: ExerciseCategory
    public let primaryMuscles: [String]?
    public let equipment: String?
    public let isUnilateral: Bool?
    public let defaultRestSeconds: Int?
    public let instructions: String?

    public enum CodingKeys: String, CodingKey {
        case name, category, equipment, instructions
        case primaryMuscles = "primary_muscles"
        case isUnilateral = "is_unilateral"
        case defaultRestSeconds = "default_rest_seconds"
    }

    public init(
        name: String,
        category: ExerciseCategory = .strength,
        primaryMuscles: [String]? = nil,
        equipment: String? = nil,
        isUnilateral: Bool? = nil,
        defaultRestSeconds: Int? = nil,
        instructions: String? = nil
    ) {
        self.name = name
        self.category = category
        self.primaryMuscles = primaryMuscles
        self.equipment = equipment
        self.isUnilateral = isUnilateral
        self.defaultRestSeconds = defaultRestSeconds
        self.instructions = instructions
    }
}
