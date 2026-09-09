//
//  CoachReview.swift
//  TrainingCore
//
//  La lógica del panel del entrenador que no puede vivir en una vista (plan §10, WP5).
//
//  Tres cosas, todas puras y todas con test:
//
//  1. **Desviaciones de S22.** Comparar lo ejecutado con lo prescrito y decir en qué se apartó.
//     Es lo que un entrenador busca en un registro y lo único que justifica abrirlo.
//  2. **Conversión entre modos de carga (S21).** Cambiar de `Weight` a `% of 1RM` no puede
//     perder el número si es convertible; tampoco puede inventarse uno si no lo es.
//  3. **Rangos de semanas y cursor del buzón.** Aritmética aburrida que, mal hecha, manda una
//     petición que el servidor rechaza con 422 o pagina en bucle.
//

import Foundation

// MARK: - Desviación de una serie respecto a lo prescrito

/// En qué se apartó una serie de su prescripción (UX §6, S22).
///
/// Nunca es solo un color: cada caso trae su texto («above target», «below load») porque el
/// checklist §10.5 prohíbe comunicar un estado únicamente con color, y porque un entrenador con
/// el móvil al sol necesita leerlo, no distinguir un matiz de amarillo.
public enum SetDeviation: String, Hashable, Sendable, CaseIterable {

    /// El RPE ejecutado supera el objetivo: costó más de lo previsto.
    case aboveTarget = "above target"
    /// El peso movido queda por debajo del prescrito.
    case belowLoad = "below load"
    /// Menos repeticiones que las prescritas.
    case belowReps = "below reps"
    /// Menos tiempo que el prescrito, en un ejercicio por duración (contrato §8.1).
    case belowTime = "below time"
    /// Menos distancia que la prescrita.
    case belowDistance = "below distance"

    public var text: String { rawValue }

    /// Lo que dice VoiceOver, con el porqué. `target` es la cifra prescrita ya formateada.
    public func spoken(target: String) -> String {
        switch self {
        case .aboveTarget: return "Above the target RPE of \(target)."
        case .belowLoad: return "Below the prescribed load of \(target)."
        case .belowReps: return "Below the prescribed \(target) reps."
        case .belowTime: return "Below the prescribed \(target)."
        case .belowDistance: return "Below the prescribed \(target)."
        }
    }
}

/// Una serie ejecutada junto a la desviación que tuvo, si tuvo alguna.
public struct ReviewedSet: Hashable, Identifiable, Sendable {

    public let setLog: TrainingSetLog
    public let deviation: SetDeviation?
    /// Cifra prescrita contra la que se comparó, para poder decirla en voz alta.
    /// RPE objetivo, carga en kilos o repeticiones, según la desviación.
    public let targetValue: Double?

    public var id: String { setLog.clientUUID }

    public init(setLog: TrainingSetLog, deviation: SetDeviation? = nil, targetValue: Double? = nil) {
        self.setLog = setLog
        self.deviation = deviation
        self.targetValue = targetValue
    }
}

/// Un ejercicio del registro con su prescripción al lado y sus series ya evaluadas.
public struct ReviewedExercise: Hashable, Identifiable, Sendable {

    public let exerciseKey: String
    public let exerciseName: String
    public let orderIndex: Int
    /// La prescripción del día, si el registro cuelga de uno. Nula en un entreno libre.
    public let prescription: TrainingDayExercise?
    public let sets: [ReviewedSet]

    public var id: String { "\(orderIndex)-\(exerciseKey)" }

    public init(
        exerciseKey: String,
        exerciseName: String,
        orderIndex: Int,
        prescription: TrainingDayExercise? = nil,
        sets: [ReviewedSet] = []
    ) {
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.prescription = prescription
        self.sets = sets
    }

    /// Series con alguna desviación. Es el resumen que decide si merece un comentario.
    public var deviationCount: Int { sets.filter { $0.deviation != nil }.count }

    /// Una sola línea con todas las series, para los ejercicios sin desviaciones: el wireframe
    /// los compacta («1 135 × 8 · 2 135 × 8 · 3 135 × 7»).
    public var isCompact: Bool { deviationCount == 0 && sets.count > 1 }
}

// MARK: - Motor de revisión

public enum CoachReview {

    /// Tolerancia de carga: por debajo de esto no se marca nada.
    ///
    /// Medio kilo es el mismo umbral con el que el servidor decide una marca (plan §4.5), y en
    /// libras es un disco de 1 lb: por debajo de eso la diferencia es del redondeo de unidades,
    /// no de lo que hizo la persona. Sin tolerancia, un 83,9 kg prescrito y un 83,91 registrado
    /// se pintarían como «below load» en toda la pantalla.
    public static let loadToleranceKg: Double = 0.5

    /// Tolerancia de RPE: el RPE se registra en pasos de 0,5 y el objetivo también.
    public static let rpeTolerance: Double = 0.25

    /// Tolerancia de tiempo: un segundo. Nadie suelta un plank exactamente en el 45,000, y
    /// marcar «below time» por un segundo convierte la señal en ruido.
    public static let durationToleranceSeconds = 1

    /// Tolerancia de distancia: un metro, por lo mismo.
    public static let distanceToleranceMeters: Double = 1

    /// Evalúa una serie contra su prescripción.
    ///
    /// Orden de prioridad, y solo una desviación por serie: primero el esfuerzo (RPE), luego la
    /// carga, luego las repeticiones. Un entrenador que ve tres marcas en la misma fila deja de
    /// mirar ninguna; lo que importa es lo primero que se salió.
    ///
    /// - Las series de calentamiento nunca se comparan: no están prescritas.
    /// - Sin prescripción no hay desviación (entreno libre, o ejercicio cambiado por el cliente).
    /// - `AMRAP` no puede quedarse corto de repeticiones: su objetivo es «las que salgan».
    public static func evaluate(
        set: TrainingSetLog,
        prescription: TrainingDayExercise?
    ) -> ReviewedSet {
        guard let prescription, !set.isWarmup else { return ReviewedSet(setLog: set) }

        if let target = prescription.rpeTarget(forSet: set.setNumber),
           let rpe = set.rpe,
           rpe > target + rpeTolerance {
            return ReviewedSet(setLog: set, deviation: .aboveTarget, targetValue: target)
        }

        if prescription.loadMode == .weight,
           let target = prescription.loadValue(forSet: set.setNumber),
           let weight = set.weightKg,
           weight < target - loadToleranceKg {
            return ReviewedSet(setLog: set, deviation: .belowLoad, targetValue: target)
        }

        // Lo que se compara después depende de con qué se mide el ejercicio: comparar
        // repeticiones en un plank acusaría a alguien de no hacer algo que nadie le pidió.
        switch prescription.measure {
        case .duration:
            if let target = prescription.durationSeconds(forSet: set.setNumber),
               let done = set.durationSeconds,
               done < target - durationToleranceSeconds {
                return ReviewedSet(setLog: set, deviation: .belowTime, targetValue: Double(target))
            }

        case .distance:
            if let target = prescription.distanceMeters(forSet: set.setNumber),
               let done = set.distanceMeters,
               done < target - distanceToleranceMeters {
                return ReviewedSet(setLog: set, deviation: .belowDistance, targetValue: target)
            }

        case .reps:
            let reps = prescription.reps(forSet: set.setNumber)
            if !reps.uppercased().contains("AMRAP"),
               let target = minimumReps(in: reps),
               set.reps < target {
                return ReviewedSet(setLog: set, deviation: .belowReps, targetValue: Double(target))
            }
        }

        return ReviewedSet(setLog: set)
    }

    /// Agrupa las series del registro por ejercicio, en el orden en que se hicieron, y le pega
    /// a cada una su prescripción.
    ///
    /// El emparejamiento es por `exercise_key`, no por `day_exercise_id`: el cliente puede haber
    /// cambiado un ejercicio a mitad de sesión, y entonces el `day_exercise_id` apunta al que ya
    /// no hizo. Con la clave, lo que no estaba prescrito simplemente no tiene contra qué
    /// compararse, que es la verdad.
    public static func group(
        sets: [TrainingSetLog],
        prescription: [TrainingDayExercise]
    ) -> [ReviewedExercise] {
        let byKey = Dictionary(prescription.map { ($0.exerciseKey, $0) }, uniquingKeysWith: { first, _ in first })

        var order: [String] = []
        var buckets: [String: [TrainingSetLog]] = [:]
        for set in sets.sorted(by: { ($0.orderIndex, $0.setNumber) < ($1.orderIndex, $1.setNumber) }) {
            if buckets[set.exerciseKey] == nil {
                buckets[set.exerciseKey] = []
                order.append(set.exerciseKey)
            }
            buckets[set.exerciseKey]?.append(set)
        }

        return order.enumerated().map { index, key in
            let group = buckets[key] ?? []
            let prescribed = byKey[key]
            return ReviewedExercise(
                exerciseKey: key,
                exerciseName: group.first?.exerciseName ?? prescribed?.exerciseName ?? key,
                orderIndex: index,
                prescription: prescribed,
                sets: group.map { evaluate(set: $0, prescription: prescribed) }
            )
        }
    }

    /// Repeticiones mínimas de un texto de prescripción: "5" → 5, "8-10" → 8, "AMRAP" → nil.
    public static func minimumReps(in reps: String) -> Int? {
        let trimmed = reps.trimmingCharacters(in: .whitespaces)
        guard !trimmed.uppercased().contains("AMRAP") else { return nil }
        let digits = trimmed.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }
}

// MARK: - Modos de carga (S21)

/// El campo numérico de la carga cuando el modo cambia (UX §6, S21: «al cambiar el modo, el
/// campo numérico se adapta y conserva el valor si es convertible»).
///
/// **Convertible aquí significa una cosa muy concreta:** el número sigue queriendo decir lo
/// mismo. 100 kg y 100 % no son el mismo dato, y arrastrar la cifra de uno a otro escribe una
/// prescripción falsa que nadie revisa después. Sin el 1RM del cliente —que no viaja en el
/// editor— no existe la conversión entre peso y porcentaje.
///
/// Lo que sí se conserva es el valor **de cada modo por separado**: quien pone 80 kg, mira el
/// RPE y vuelve a `Weight` recupera sus 80. Es lo que la UX quiere decir con conservar, y no
/// obliga a inventar ninguna aritmética.
public struct LoadDraft: Hashable, Sendable {

    public private(set) var mode: TrainingLoadMode
    /// Kilos recordados del modo `weight`.
    public private(set) var weightValue: Double?
    /// Porcentaje recordado del modo `percent_1rm`.
    public private(set) var percentValue: Double?

    public init(mode: TrainingLoadMode, value: Double?) {
        self.mode = mode
        switch mode {
        case .weight: weightValue = value
        case .percent1RM: percentValue = value
        case .rpe, .bodyweight: break
        }
    }

    /// El valor que va en el cuerpo de la petición: nulo en los modos que no llevan carga.
    public var loadValue: Double? {
        switch mode {
        case .weight: return weightValue
        case .percent1RM: return percentValue
        case .rpe, .bodyweight: return nil
        }
    }

    /// Cambia de modo recordando lo anterior.
    public mutating func select(_ newMode: TrainingLoadMode) {
        guard newMode != mode else { return }
        mode = newMode
    }

    /// Escribe el número del campo en el modo activo. En `rpe` y `bodyweight` no hay campo, así
    /// que la escritura se ignora en vez de guardar un dato que nunca se enviaría.
    public mutating func setValue(_ value: Double?) {
        switch mode {
        case .weight: weightValue = value
        case .percent1RM: percentValue = value
        case .rpe, .bodyweight: break
        }
    }

    /// `true` cuando el modo tiene campo numérico.
    public var hasNumericField: Bool { mode == .weight || mode == .percent1RM }
}

public enum LoadModeConversion {

    /// Rango válido del campo numérico según el modo, para el stepper.
    public static func range(for mode: TrainingLoadMode) -> ClosedRange<Double>? {
        switch mode {
        case .weight: return 0...500
        case .percent1RM: return 0...100
        case .rpe, .bodyweight: return nil
        }
    }

    /// Etiqueta del selector: `Weight` / `% of 1RM` / `RPE` / `Bodyweight` (UX §9, S21).
    public static func title(for mode: TrainingLoadMode) -> String {
        switch mode {
        case .weight: return "Weight"
        case .percent1RM: return "% of 1RM"
        case .rpe: return "RPE"
        case .bodyweight: return "Bodyweight"
        }
    }

    /// Los cuatro modos, en el orden en que se ofrecen.
    public static let allModes: [TrainingLoadMode] = [.weight, .percent1RM, .rpe, .bodyweight]
}

// MARK: - Rango de semanas (duplicar)

public extension WeekMath {

    /// Semanas destino válidas al duplicar la semana `week` de un programa de `durationWeeks`.
    ///
    /// Se excluye la propia semana: duplicar una semana sobre sí misma responde 422
    /// (WP2-informe §4.3), y ofrecerlo en la hoja es prometer un error.
    static func duplicableWeeks(from week: Int, durationWeeks: Int) -> [Int] {
        guard durationWeeks >= 1 else { return [] }
        return (1...durationWeeks).filter { $0 != week }
    }

    /// Días destino válidos al duplicar el día `dayNumber`.
    static func duplicableDayNumbers(from dayNumber: Int, durationWeeks: Int) -> [Int] {
        let total = totalDays(durationWeeks: durationWeeks)
        guard total >= 1 else { return [] }
        return (1...total).filter { $0 != dayNumber }
    }

    /// ¿Se puede pedir esta duplicación? Sin destinos, o con un destino fuera del programa, la
    /// petición viaja para nada.
    static func isValidDuplication(targets: [Int], from source: Int, limit: Int) -> Bool {
        guard !targets.isEmpty, limit >= 1 else { return false }
        return targets.allSatisfy { $0 >= 1 && $0 <= limit && $0 != source }
    }

    /// Una semana existe dentro del programa.
    static func isValidWeek(_ week: Int, durationWeeks: Int) -> Bool {
        week >= 1 && week <= max(1, durationWeeks)
    }

    /// Mueve una semana sin salirse del programa, para las flechas `‹ WEEK 3 ›` de S20.
    static func clampWeek(_ week: Int, durationWeeks: Int) -> Int {
        min(max(1, week), max(1, durationWeeks))
    }
}

// MARK: - Cursor del buzón

/// Paginación por cursor de `/inbox` y de `/clients/{id}/logs`: `before=<id>` (plan §6).
public enum InboxCursor {

    /// El `before` de la siguiente página: el id más pequeño de lo que ya se tiene.
    ///
    /// Es el id, no la fecha: dos registros sincronizados en el mismo segundo tienen la misma
    /// `completed_at` y con fecha la página se repetiría en bucle.
    public static func next(after page: [TrainingWorkoutLogSummary]) -> Int? {
        page.map(\.id).min()
    }

    /// Hay más páginas mientras el servidor devuelva la página entera que se le pidió.
    public static func hasMore(page: [TrainingWorkoutLogSummary], limit: Int) -> Bool {
        page.count >= limit && limit > 0
    }

    /// Une una página nueva con lo que ya había, sin duplicados y en orden descendente por id.
    ///
    /// El servidor puede devolver un registro ya conocido si alguien sincronizó entre las dos
    /// peticiones; sin esta unión, la lista pinta la misma fila dos veces y `ForEach` se queja
    /// del id repetido.
    public static func merge(
        _ existing: [TrainingWorkoutLogSummary],
        with page: [TrainingWorkoutLogSummary]
    ) -> [TrainingWorkoutLogSummary] {
        var known = Set(existing.map(\.id))
        var result = existing
        for item in page where !known.contains(item.id) {
            known.insert(item.id)
            result.append(item)
        }
        return result.sorted { $0.id > $1.id }
    }

    /// Cuántas filas se conservan en memoria de una lista paginada.
    ///
    /// Diez páginas de veinte. Quien ha bajado diez páginas no va a subir a la primera sin
    /// soltar el dedo, y si lo hace la lista se recarga desde arriba. El número existe porque
    /// `TrainingService` es un singleton que vive toda la sesión: sin tope, `logs`, `clientLogs`
    /// e `inbox` crecen mientras la persona siga bajando y solo se vacían al cambiar de espacio
    /// o cerrar sesión.
    public static let maxRetained = 200

    /// Recorta una lista ya unida a las `limit` filas más recientes.
    ///
    /// Se quitan por el final, que es donde están los ids más pequeños: lo más viejo. Con menos
    /// filas que el tope no hace nada y no copia el array.
    public static func capped(
        _ items: [TrainingWorkoutLogSummary],
        to limit: Int = maxRetained
    ) -> [TrainingWorkoutLogSummary] {
        guard limit > 0, items.count > limit else { return items }
        return Array(items.prefix(limit))
    }
}
