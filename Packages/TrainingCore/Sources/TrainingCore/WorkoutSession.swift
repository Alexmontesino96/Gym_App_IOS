//
//  WorkoutSession.swift
//  TrainingCore
//
//  Máquina de estados de una sesión de entrenamiento (UX §5, pantalla S11).
//
//  Es un valor puro: no sabe de red, ni de vistas, ni de relojes. Todo lo que necesita saber la
//  hora lo recibe como parámetro, así que se puede probar entero sin simulador. La pantalla de
//  WP4 lo guarda en un `@Published` y llama a estos métodos.
//
//  Lo que NO hace, a propósito: decidir marcas personales. Calcula «best set so far» con lo que
//  conoce el teléfono, que es una afirmación honesta; «Personal record» solo lo dice el servidor
//  cuando confirma la sincronización (plan §4.5).
//

import Foundation

// MARK: - Serie

public struct SessionSet: Identifiable, Hashable, Sendable {

    /// `client_uuid` de la serie: la clave de idempotencia del contrato (plan §4.7).
    public let id: UUID
    public var setNumber: Int
    public var reps: Int
    public var weightKg: Double?
    public var rpe: Double?
    public var isWarmup: Bool
    public private(set) var isDone: Bool
    public private(set) var completedAt: Date?
    /// Serie añadida por el cliente sobre la prescripción («+ Add set»).
    public var isExtra: Bool
    /// Lo prescrito para esta serie, para poder pintar la desviación en la revisión del coach.
    public var prescribedReps: String?
    public var prescribedLoadKg: Double?
    public var prescribedRPE: Double?
    /// Descanso propio de esta serie cuando el `set_override` lo cambia. Nulo = el del ejercicio.
    public var restSeconds: Int?

    public init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int = 0,
        weightKg: Double? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        isExtra: Bool = false,
        prescribedReps: String? = nil,
        prescribedLoadKg: Double? = nil,
        prescribedRPE: Double? = nil,
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isDone = false
        self.completedAt = nil
        self.isExtra = isExtra
        self.prescribedReps = prescribedReps
        self.prescribedLoadKg = prescribedLoadKg
        self.prescribedRPE = prescribedRPE
        self.restSeconds = restSeconds
    }

    mutating func markDone(at date: Date) {
        isDone = true
        completedAt = date
    }

    mutating func undo() {
        isDone = false
        completedAt = nil
    }

    public var volumeKg: Double {
        guard !isWarmup, let weightKg else { return 0 }
        return weightKg * Double(reps)
    }

    /// 1RM estimado local. Nulo si la serie no es elegible (plan §4.5).
    public var estimatedOneRepMaxKg: Double? {
        OneRepMax.estimate(weightKg: weightKg, reps: reps, isWarmup: isWarmup)
    }
}

// MARK: - Ejercicio dentro de la sesión

public struct SessionExercise: Identifiable, Hashable, Sendable {

    public let id: UUID
    public var dayExerciseId: Int?
    public var exerciseId: Int?
    public var exerciseKey: String
    public var exerciseName: String
    public var orderIndex: Int
    public var supersetGroup: String?
    public var loadMode: TrainingLoadMode
    /// Series prescritas por el entrenador. No cambia al añadir series: es el denominador de
    /// «sesión parcial» (plan §4.2).
    public var prescribedSetCount: Int
    public var prescribedReps: String?
    public var prescribedRPE: Double?
    public var restSeconds: Int
    public var notes: String?
    public var lastPerformance: TrainingLastPerformance?
    /// El cliente lo cambió por otro del catálogo.
    public var isSwapped: Bool
    /// El cliente lo añadió (entreno libre o «+ Add exercise»).
    public var isExtra: Bool
    public var sets: [SessionSet]

    public init(
        id: UUID = UUID(),
        dayExerciseId: Int? = nil,
        exerciseId: Int? = nil,
        exerciseKey: String,
        exerciseName: String,
        orderIndex: Int = 0,
        supersetGroup: String? = nil,
        loadMode: TrainingLoadMode = .weight,
        prescribedSetCount: Int = 0,
        prescribedReps: String? = nil,
        prescribedRPE: Double? = nil,
        restSeconds: Int = RestTimer.defaultSeconds,
        notes: String? = nil,
        lastPerformance: TrainingLastPerformance? = nil,
        isSwapped: Bool = false,
        isExtra: Bool = false,
        sets: [SessionSet] = []
    ) {
        self.id = id
        self.dayExerciseId = dayExerciseId
        self.exerciseId = exerciseId
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.supersetGroup = supersetGroup
        self.loadMode = loadMode
        self.prescribedSetCount = prescribedSetCount
        self.prescribedReps = prescribedReps
        self.prescribedRPE = prescribedRPE
        self.restSeconds = restSeconds
        self.notes = notes
        self.lastPerformance = lastPerformance
        self.isSwapped = isSwapped
        self.isExtra = isExtra
        self.sets = sets
    }

    /// Construye el ejercicio a partir de la prescripción del día, con las series ya precargadas
    /// con lo que se espera que haga el cliente: así marcar una serie es un solo toque.
    public init(dayExercise: TrainingDayExercise) {
        let suggested = dayExercise.lastPerformance?.suggestedWeightKg
            ?? (dayExercise.loadMode == .weight ? dayExercise.loadValue : nil)

        let sets: [SessionSet] = (1...max(1, dayExercise.setsCount)).map { number in
            let reps = Self.firstNumber(in: dayExercise.reps(forSet: number)) ?? 0
            let prescribedLoad = dayExercise.loadMode == .weight ? dayExercise.loadValue(forSet: number) : nil
            return SessionSet(
                setNumber: number,
                reps: reps,
                weightKg: prescribedLoad ?? suggested,
                rpe: nil,
                isWarmup: false,
                isExtra: false,
                prescribedReps: dayExercise.reps(forSet: number),
                prescribedLoadKg: prescribedLoad,
                prescribedRPE: dayExercise.rpeTarget(forSet: number),
                restSeconds: dayExercise.override(forSet: number)?.restSeconds
            )
        }

        self.init(
            dayExerciseId: dayExercise.id,
            exerciseId: dayExercise.exerciseId,
            exerciseKey: dayExercise.exerciseKey,
            exerciseName: dayExercise.exerciseName,
            orderIndex: dayExercise.orderIndex,
            supersetGroup: dayExercise.supersetGroup,
            loadMode: dayExercise.loadMode,
            prescribedSetCount: max(1, dayExercise.setsCount),
            prescribedReps: dayExercise.reps,
            prescribedRPE: dayExercise.rpeTarget,
            restSeconds: dayExercise.restSeconds,
            notes: dayExercise.notes,
            lastPerformance: dayExercise.lastPerformance,
            sets: sets
        )
    }

    /// Ejercicio libre: una serie vacía y nada prescrito.
    public init(catalogItem: ExerciseCatalogItem, orderIndex: Int, initialSetCount: Int = 1) {
        let sets = (1...max(1, initialSetCount)).map { SessionSet(setNumber: $0, isExtra: true) }
        self.init(
            exerciseId: catalogItem.id,
            exerciseKey: catalogItem.exerciseKey,
            exerciseName: catalogItem.name,
            orderIndex: orderIndex,
            loadMode: .weight,
            prescribedSetCount: 0,
            restSeconds: catalogItem.defaultRestSeconds,
            isExtra: true,
            sets: sets
        )
    }

    // MARK: - Derivados

    public var completedSetCount: Int { sets.filter(\.isDone).count }

    public var isComplete: Bool { !sets.isEmpty && sets.allSatisfy(\.isDone) }

    /// La serie activa es la primera sin marcar: es la que la interfaz deja editable y a la que
    /// hace scroll al marcar la anterior.
    public var activeSet: SessionSet? { sets.first { !$0.isDone } }

    public var volumeKg: Double { sets.reduce(0) { $0 + $1.volumeKg } }

    /// «4 × 5 @ RPE 8 · rest 2:00». Sin prescripción (entreno libre) no hay línea que enseñar.
    public var prescriptionText: String? {
        guard prescribedSetCount > 0, let prescribedReps else { return nil }
        var text = "\(prescribedSetCount) × \(prescribedReps)"
        if let prescribedRPE {
            text += " @ RPE \(Self.trimmed(prescribedRPE))"
        }
        if restSeconds > 0 {
            text += " · rest \(RestTimer.clock(TimeInterval(restSeconds)))"
        }
        return text
    }

    /// Descanso de una serie concreta: manda el `set_override` si lo hay, si no el del ejercicio,
    /// y si el ejercicio no prescribe ninguno, los 90 s por defecto de la UX.
    public func restSeconds(forSet setNumber: Int) -> Int {
        if let override = sets.first(where: { $0.setNumber == setNumber })?.restSeconds, override > 0 {
            return override
        }
        return restSeconds > 0 ? restSeconds : RestTimer.defaultSeconds
    }

    // MARK: - Utilidades

    static func firstNumber(in text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Resultado de marcar una serie

public struct MarkSetResult: Hashable, Sendable {

    public let set: SessionSet
    /// Segundos de descanso que hay que arrancar.
    public let restSeconds: Int
    public let exerciseName: String
    /// Número de la serie SIGUIENTE del ejercicio, para el cuerpo de la notificación local.
    public let nextSetNumber: Int?
    public let totalSetsInExercise: Int
    /// La mejor serie del ejercicio en lo que la app conoce. **No** es una marca personal.
    public let isBestSetSoFar: Bool
    public let progressText: String
    /// Anuncio de VoiceOver: «Set 3 done. Rest 2 minutes.» (UX §5 S11).
    public let announcement: String
}

// MARK: - Sesión

public struct WorkoutSession: Identifiable, Hashable, Sendable {

    /// `client_uuid` del registro. Es la clave de idempotencia y el nombre del fichero en el
    /// outbox; no cambia nunca durante la vida de la sesión.
    public let clientUUID: UUID
    public var id: UUID { clientUUID }

    public var title: String
    public var programId: Int?
    public var dayId: Int?
    public var scheduledDate: CalendarDate?
    public let startedAt: Date
    public private(set) var completedAt: Date?
    public private(set) var status: WorkoutLogStatus
    public var exercises: [SessionExercise]
    public var sessionRPE: Double?
    public var feeling: Int?
    public var notes: String?
    /// Índice del ejercicio en foco (los chips de la parte de arriba de S11).
    public var activeExerciseIndex: Int

    public static let freeWorkoutTitle = "Free workout"

    // MARK: - Construcción

    public init(
        clientUUID: UUID = UUID(),
        title: String,
        programId: Int? = nil,
        dayId: Int? = nil,
        scheduledDate: CalendarDate? = nil,
        startedAt: Date,
        exercises: [SessionExercise] = []
    ) {
        self.clientUUID = clientUUID
        self.title = title
        self.programId = programId
        self.dayId = dayId
        self.scheduledDate = scheduledDate
        self.startedAt = startedAt
        self.completedAt = nil
        self.status = .inProgress
        self.exercises = exercises
        self.sessionRPE = nil
        self.feeling = nil
        self.notes = nil
        self.activeExerciseIndex = 0
    }

    /// Sesión a partir de un día del programa.
    public init(
        day: TrainingDay,
        programId: Int?,
        scheduledDate: CalendarDate?,
        startedAt: Date,
        clientUUID: UUID = UUID()
    ) {
        self.init(
            clientUUID: clientUUID,
            title: day.displayName,
            programId: programId,
            dayId: day.id,
            scheduledDate: scheduledDate,
            startedAt: startedAt,
            exercises: day.exercisesInOrder.map(SessionExercise.init(dayExercise:))
        )
    }

    /// Entreno libre: sin día, sin programa y sin chips.
    public static func freeWorkout(startedAt: Date, clientUUID: UUID = UUID()) -> WorkoutSession {
        WorkoutSession(
            clientUUID: clientUUID,
            title: freeWorkoutTitle,
            startedAt: startedAt
        )
    }

    public var isFreeWorkout: Bool { dayId == nil }

    // MARK: - Progreso

    public var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.completedSetCount }
    }

    /// Todas las series de la sesión, incluidas las añadidas a mano: es el denominador que ve
    /// el cliente en «6 of 18 sets».
    public var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    /// Series que prescribió el entrenador. Es el denominador de «sesión parcial», que no puede
    /// depender de cuántas series se haya inventado el cliente.
    public var prescribedSetCount: Int {
        exercises.reduce(0) { $0 + $1.prescribedSetCount }
    }

    /// «6 of 18 sets», literal de la cabecera de S11.
    public var progressText: String {
        "\(completedSetCount) of \(totalSetCount) sets"
    }

    public var completionRatio: Double {
        guard totalSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(totalSetCount)
    }

    /// Menos de la mitad de las series prescritas (plan §4.2). En entreno libre nunca es parcial:
    /// no había nada prescrito contra lo que comparar.
    public var isPartial: Bool {
        WeekMath.isPartial(completedSets: completedSetCount, plannedSets: prescribedSetCount)
    }

    public var totalVolumeKg: Double {
        exercises.reduce(0) { $0 + $1.volumeKg }
    }

    public func durationSeconds(at now: Date) -> Int {
        Int((completedAt ?? now).timeIntervalSince(startedAt).rounded())
    }

    /// Media de RPE de las series marcadas que lo llevan (la cifra «avg RPE» de S18).
    public var averageRPE: Double? {
        let values = exercises.flatMap(\.sets).filter { $0.isDone }.compactMap(\.rpe)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    public var hasAnyCompletedSet: Bool { completedSetCount > 0 }

    // MARK: - Acceso

    public func exercise(id: UUID) -> SessionExercise? {
        exercises.first { $0.id == id }
    }

    public var activeExercise: SessionExercise? {
        guard exercises.indices.contains(activeExerciseIndex) else { return exercises.first }
        return exercises[activeExerciseIndex]
    }

    /// Ejercicios de la misma superserie, para pintar la línea «superset with Row».
    public func supersetPartners(of exerciseId: UUID) -> [SessionExercise] {
        guard let exercise = exercise(id: exerciseId), let group = exercise.supersetGroup else { return [] }
        return exercises.filter { $0.id != exerciseId && $0.supersetGroup == group }
    }

    // MARK: - Marcar y deshacer

    /// Marca una serie. Devuelve lo que la interfaz necesita para reaccionar: descanso que
    /// arrancar, siguiente serie, progreso y anuncio de VoiceOver.
    @discardableResult
    public mutating func markSet(exerciseId: UUID, setId: UUID, at date: Date) -> MarkSetResult? {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }),
              !exercises[exerciseIndex].sets[setIndex].isDone else { return nil }

        let previousBest = bestSetSoFar(forExerciseKey: exercises[exerciseIndex].exerciseKey)
        exercises[exerciseIndex].sets[setIndex].markDone(at: date)
        activeExerciseIndex = exerciseIndex

        let markedSet = exercises[exerciseIndex].sets[setIndex]
        let exercise = exercises[exerciseIndex]
        let rest = exercise.restSeconds(forSet: markedSet.setNumber)
        let next = exercise.activeSet?.setNumber

        let newBest = bestSetSoFar(forExerciseKey: exercise.exerciseKey)
        let isBest: Bool = {
            guard let newBest, newBest.setNumber == markedSet.setNumber else { return false }
            guard let previousBest else { return newBest.e1rmKg != nil || newBest.weightKg != nil }
            return newBest.isBetter(than: previousBest)
        }()

        return MarkSetResult(
            set: markedSet,
            restSeconds: rest,
            exerciseName: exercise.exerciseName,
            nextSetNumber: next,
            totalSetsInExercise: exercise.sets.count,
            isBestSetSoFar: isBest,
            progressText: progressText,
            announcement: Self.announcement(
                setNumber: markedSet.setNumber,
                totalSets: exercise.sets.count,
                restSeconds: rest
            )
        )
    }

    /// Deshacer. Quien llama tiene que cancelar el cronómetro si estaba corriendo (UX §5 S11).
    @discardableResult
    public mutating func undoSet(exerciseId: UUID, setId: UUID) -> Bool {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }),
              exercises[exerciseIndex].sets[setIndex].isDone else { return false }
        exercises[exerciseIndex].sets[setIndex].undo()
        return true
    }

    // MARK: - Editar

    @discardableResult
    public mutating func updateSet(
        exerciseId: UUID,
        setId: UUID,
        reps: Int? = nil,
        weightKg: Double?? = nil,
        rpe: Double?? = nil,
        isWarmup: Bool? = nil
    ) -> Bool {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else { return false }
        if let reps { exercises[exerciseIndex].sets[setIndex].reps = max(0, reps) }
        if let weightKg { exercises[exerciseIndex].sets[setIndex].weightKg = weightKg }
        if let rpe { exercises[exerciseIndex].sets[setIndex].rpe = rpe }
        if let isWarmup { exercises[exerciseIndex].sets[setIndex].isWarmup = isWarmup }
        return true
    }

    /// «+ Add set»: copia los valores de la última serie introducida, que es lo que se espera
    /// después de veinte repeticiones del mismo gesto.
    @discardableResult
    public mutating func addSet(toExerciseId exerciseId: UUID) -> SessionSet? {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return nil }
        let template = exercises[exerciseIndex].sets.last
        let newSet = SessionSet(
            setNumber: (template?.setNumber ?? 0) + 1,
            reps: template?.reps ?? 0,
            weightKg: template?.weightKg,
            rpe: nil,
            isWarmup: template?.isWarmup ?? false,
            isExtra: true,
            prescribedReps: nil,
            prescribedLoadKg: nil,
            prescribedRPE: nil
        )
        exercises[exerciseIndex].sets.append(newSet)
        return newSet
    }

    @discardableResult
    public mutating func removeSet(exerciseId: UUID, setId: UUID) -> Bool {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              exercises[exerciseIndex].sets.contains(where: { $0.id == setId }) else { return false }
        exercises[exerciseIndex].sets.removeAll { $0.id == setId }
        renumberSets(exerciseIndex: exerciseIndex)
        return true
    }

    // MARK: - Ejercicios

    /// «Swap exercise».
    ///
    /// Las series ya marcadas son datos reales del ejercicio ORIGINAL y no se reescriben: si hay
    /// alguna, el ejercicio original se queda con ellas y el sustituto entra justo detrás con las
    /// series que faltaban. Si no hay ninguna, el sustituto ocupa su sitio. Devuelve el id del
    /// ejercicio nuevo.
    @discardableResult
    public mutating func swapExercise(exerciseId: UUID, with catalogItem: ExerciseCatalogItem) -> UUID? {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseId }) else { return nil }
        var original = exercises[index]
        let doneSets = original.sets.filter(\.isDone)
        let pendingSets = original.sets.filter { !$0.isDone }
        guard !pendingSets.isEmpty else { return nil }

        var replacement = original
        replacement = SessionExercise(
            dayExerciseId: original.dayExerciseId,
            exerciseId: catalogItem.id,
            exerciseKey: catalogItem.exerciseKey,
            exerciseName: catalogItem.name,
            orderIndex: original.orderIndex,
            supersetGroup: original.supersetGroup,
            loadMode: original.loadMode,
            prescribedSetCount: doneSets.isEmpty ? original.prescribedSetCount : pendingSets.count,
            prescribedReps: original.prescribedReps,
            prescribedRPE: original.prescribedRPE,
            restSeconds: catalogItem.defaultRestSeconds > 0 ? catalogItem.defaultRestSeconds : original.restSeconds,
            notes: original.notes,
            lastPerformance: nil,
            isSwapped: true,
            isExtra: original.isExtra,
            // La carga del ejercicio anterior no vale para otro movimiento: se limpia y el
            // cliente la teclea. Las repeticiones prescritas sí se conservan.
            sets: pendingSets.enumerated().map { position, set in
                SessionSet(
                    setNumber: position + 1,
                    reps: set.reps,
                    weightKg: nil,
                    rpe: nil,
                    isWarmup: set.isWarmup,
                    isExtra: set.isExtra,
                    prescribedReps: set.prescribedReps,
                    prescribedLoadKg: nil,
                    prescribedRPE: set.prescribedRPE,
                    restSeconds: set.restSeconds
                )
            }
        )

        if doneSets.isEmpty {
            exercises[index] = replacement
        } else {
            original.sets = doneSets
            original.prescribedSetCount = doneSets.count
            exercises[index] = original
            exercises.insert(replacement, at: index + 1)
        }
        return replacement.id
    }

    /// «+ Add exercise» (entreno libre y añadidos sobre un día).
    @discardableResult
    public mutating func addExercise(_ catalogItem: ExerciseCatalogItem, initialSetCount: Int = 1) -> UUID {
        let exercise = SessionExercise(
            catalogItem: catalogItem,
            orderIndex: (exercises.last?.orderIndex ?? -1) + 1,
            initialSetCount: initialSetCount
        )
        exercises.append(exercise)
        return exercise.id
    }

    @discardableResult
    public mutating func removeExercise(id: UUID) -> Bool {
        guard exercises.contains(where: { $0.id == id }) else { return false }
        exercises.removeAll { $0.id == id }
        activeExerciseIndex = min(activeExerciseIndex, max(0, exercises.count - 1))
        return true
    }

    // MARK: - Mejor serie local

    /// La mejor serie de un ejercicio **dentro de esta sesión**. Se llama «Best set so far».
    public func bestSetSoFar(forExerciseKey key: String) -> BestSetSoFar? {
        let candidates = exercises
            .filter { $0.exerciseKey == key }
            .flatMap(\.sets)
            .filter { $0.isDone && !$0.isWarmup && $0.reps > 0 }
            .map {
                BestSetSoFar(
                    exerciseKey: key,
                    setNumber: $0.setNumber,
                    reps: $0.reps,
                    weightKg: $0.weightKg,
                    e1rmKg: $0.estimatedOneRepMaxKg
                )
            }
        return candidates.max { $0.rank < $1.rank }
    }

    /// Mejores series de la sesión, una por ejercicio.
    public var bestSetsSoFar: [BestSetSoFar] {
        let keys = Array(Set(exercises.map(\.exerciseKey)))
        return keys.compactMap { bestSetSoFar(forExerciseKey: $0) }
    }

    // MARK: - Cierre

    /// Cierra la sesión. A partir de aquí solo se pueden cambiar `notes`, `feeling` y
    /// `session_rpe`, que es exactamente lo que admite el servidor (plan §6.4).
    public mutating func finish(at date: Date) {
        completedAt = date
        status = .completed
    }

    /// Reabre la sesión. Solo tiene sentido antes de sincronizar el cierre.
    public mutating func reopen() {
        completedAt = nil
        status = .inProgress
    }

    // MARK: - Sincronización

    /// Cuerpo de `POST /training/logs/sync` (plan §6.4).
    ///
    /// Solo viajan las series marcadas: una fila a medio teclear no es un dato. El `client_uuid`
    /// del registro y el de cada serie se conservan entre envíos, que es lo que hace que reenviar
    /// esto produzca el mismo estado en el servidor.
    public func syncRequest(status overrideStatus: WorkoutLogStatus? = nil, at now: Date) -> WorkoutLogSyncRequest {
        let effectiveStatus = overrideStatus ?? status
        let sets: [SetLogSyncRequest] = exercises.flatMap { exercise in
            exercise.sets.filter(\.isDone).map { set in
                SetLogSyncRequest(
                    clientUUID: set.id,
                    exerciseKey: exercise.exerciseKey,
                    exerciseName: exercise.exerciseName,
                    dayExerciseId: exercise.dayExerciseId,
                    exerciseId: exercise.exerciseId,
                    orderIndex: exercise.orderIndex,
                    setNumber: set.setNumber,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    rpe: set.rpe,
                    isWarmup: set.isWarmup,
                    completedAt: set.completedAt ?? now
                )
            }
        }

        return WorkoutLogSyncRequest(
            clientUUID: clientUUID,
            dayId: dayId,
            programId: programId,
            scheduledDate: scheduledDate,
            title: title,
            status: effectiveStatus,
            startedAt: startedAt,
            completedAt: effectiveStatus == .completed ? (completedAt ?? now) : nil,
            sessionRPE: sessionRPE,
            feeling: feeling,
            notes: notes,
            sets: sets
        )
    }

    // MARK: - Privado

    private mutating func renumberSets(exerciseIndex: Int) {
        for position in exercises[exerciseIndex].sets.indices {
            exercises[exerciseIndex].sets[position].setNumber = position + 1
        }
    }

    static func announcement(setNumber: Int, totalSets: Int, restSeconds: Int) -> String {
        let rest: String
        if restSeconds <= 0 {
            rest = ""
        } else if restSeconds % 60 == 0 {
            let minutes = restSeconds / 60
            rest = " Rest \(minutes) minute\(minutes == 1 ? "" : "s")."
        } else {
            rest = " Rest \(restSeconds) seconds."
        }
        return "Set \(setNumber) done.\(rest)"
    }
}
