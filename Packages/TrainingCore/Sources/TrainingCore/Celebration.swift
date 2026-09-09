//
//  Celebration.swift
//  TrainingCore
//
//  Sistema de celebración de marcas (UX §7) y estado de una fila de serie (UX §5, S11).
//
//  Vive en el paquete y no en la vista por una razón concreta: decidir QUÉ se celebra y CÓMO se
//  llama es donde está el error caro. Llamar «Personal record» a una serie que el servidor
//  todavía no ha confirmado es mentirle a alguien sobre su propio entrenamiento, y el plan §4.5
//  lo prohíbe explícitamente. Aquí eso es un tipo con dos constructores distintos y una batería
//  de tests; en una vista sería un `if` que alguien tocará dentro de seis meses.
//
//  La vista solo pinta lo que este fichero devuelve.
//

import Foundation

// MARK: - Nivel de celebración

/// Los tres niveles de UX §7, más «ninguna».
///
/// El orden importa: `rawValue` mayor es celebración mayor, y la vista puede comparar.
public enum CelebrationLevel: Int, Hashable, Sendable, Comparable {
    /// No hay nada que celebrar.
    case none = 0
    /// Nivel 1 · Reconocimiento: mejor serie del ejercicio en esta sesión, sin confirmar.
    case recognition = 1
    /// Nivel 2 · Marca: nuevo 1RM estimado **confirmado por el servidor**.
    case record = 2
    /// Nivel 3 · Hito: primer registro del ejercicio, o cifra redonda del catálogo.
    case milestone = 3

    public static func < (lhs: CelebrationLevel, rhs: CelebrationLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Duración de la animación en milisegundos (UX §7). Con Reduce Motion la vista usa 150 ms
    /// de fundido en los tres niveles y no consulta esto.
    public var durationMilliseconds: Int {
        switch self {
        case .none: return 0
        case .recognition: return 260
        case .record: return 900
        case .milestone: return 1200
        }
    }

    public var durationSeconds: Double { Double(durationMilliseconds) / 1000 }

    /// Solo los niveles 2 y 3 traen partículas. El 1 es un fundido con escala.
    public var usesParticles: Bool { self >= .record }

    /// El nivel 3 ofrece compartir en línea; los demás no proponen nada.
    public var suggestsSharing: Bool { self == .milestone }

    /// Número de partículas de UX §7 (nivel 2 y 3): doce, no treinta.
    public var particleCount: Int { usesParticles ? 12 : 0 }
}

// MARK: - Contenido de la celebración

/// Lo que se pinta. Todos los textos vienen del catálogo de microcopy de UX §9.
public struct PersonalRecordCelebration: Hashable, Sendable {

    public let level: CelebrationLevel
    /// Encabezado de la tarjeta: `NEW RECORD`, `MILESTONE` o `BEST SET SO FAR`.
    public let title: String
    /// «Bench press · 185 × 5»
    public let headline: String
    /// «est. 1RM 208 lb · up 10 lb», «first record» o nulo.
    public let detail: String?
    /// `false` mientras el servidor no lo haya confirmado. La vista NUNCA dice «Personal
    /// record» con esto en falso.
    public let isConfirmed: Bool
    /// Etiqueta de VoiceOver: una frase entera, con unidad y significado (UX §1.8).
    public let accessibilityLabel: String

    public init(
        level: CelebrationLevel,
        title: String,
        headline: String,
        detail: String?,
        isConfirmed: Bool,
        accessibilityLabel: String
    ) {
        self.level = level
        self.title = title
        self.headline = headline
        self.detail = detail
        self.isConfirmed = isConfirmed
        self.accessibilityLabel = accessibilityLabel
    }
}

// MARK: - Fábrica

public enum Celebration {

    // MARK: Literales (UX §9)

    public static let confirmedTitle = "NEW RECORD"
    public static let milestoneTitle = "MILESTONE"
    public static let unconfirmedTitle = "BEST SET SO FAR"
    public static let firstRecordDetail = "first record"
    public static let shareSuggestion = "Share this"

    // MARK: Formateo

    /// «185 lb» / «84 kg». Redondea al escalón de la unidad para no enseñar 83,914 kg.
    public static func loadText(kilograms: Double, unit: TrainingWeightUnit) -> String {
        let rounded = OneRepMax.roundToStep(kilograms: kilograms, unit: unit)
        return "\(number(unit.fromKilograms(rounded))) \(unit.symbol)"
    }

    /// «up 10 lb» / «down 2.5 kg». El delta llega en kilos y se convierte entero, no por partes.
    public static func deltaText(kilograms: Double, unit: TrainingWeightUnit) -> String? {
        let converted = unit.fromKilograms(kilograms)
        guard abs(converted) >= 0.1 else { return nil }
        // Al medio más cercano: convertir 4,54 kg da 10,0086 lb y «up 10 lb» es lo que se dice
        // en un gimnasio. Sin redondear salían deltas como «up 9.9 lb».
        let rounded = (abs(converted) * 2).rounded() / 2
        let word = converted > 0 ? "up" : "down"
        return "\(word) \(number(rounded)) \(unit.symbol)"
    }

    // MARK: Medida de la serie (contrato §8.1)

    /// «1:30» / «0:45». Es el formato del CAMPO de una serie por tiempo: siempre minutos y
    /// segundos, para que la cifra no cambie de forma mientras se teclea. Reusa el mismo reloj
    /// que el cronómetro de descanso, que es donde ya vivía este formato.
    public static func durationText(_ seconds: Int) -> String {
        RestTimer.clock(TimeInterval(max(0, seconds)))
    }

    /// «45s» / «1:30». El de una PRESCRIPCIÓN, donde lo que se lee es «3 × 45s» y escribir
    /// «0:45» ahí sobra.
    public static func compactDurationText(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return value < 60 ? "\(value)s" : durationText(value)
    }

    /// «400 m» / «1.5 km». A partir de mil metros se pasa a kilómetros: un 5000 escrito en
    /// metros se lee como un número de teléfono.
    public static func distanceText(meters: Double) -> String {
        guard meters.isFinite else { return "—" }
        let value = max(0, meters)
        if value >= 1000 { return "\(number(value / 1000)) km" }
        return "\(number(value)) m"
    }

    /// «45 seconds» / «1 minute 30 seconds», dicho entero para VoiceOver (UX §1.8).
    public static func spokenDuration(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let rest = total % 60
        if minutes == 0 { return "\(rest) second\(rest == 1 ? "" : "s")" }
        var text = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        if rest > 0 { text += " \(rest) second\(rest == 1 ? "" : "s")" }
        return text
    }

    /// «400 meters» / «1.5 kilometers».
    public static func spokenDistance(meters: Double) -> String {
        guard meters.isFinite else { return "no distance" }
        let value = max(0, meters)
        if value >= 1000 {
            let kilometers = number(value / 1000)
            return "\(kilometers) kilometer\(kilometers == "1" ? "" : "s")"
        }
        let text = number(value)
        return "\(text) meter\(text == "1" ? "" : "s")"
    }

    /// Sin decimales cuando el valor es entero: «185», no «185.0».
    public static func number(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.05 {
            return String(Int(rounded.rounded()))
        }
        return String(format: "%.1f", rounded)
    }

    // MARK: Serie confirmada por el servidor (niveles 2 y 3)

    /// Celebración de una serie que el servidor ya marcó como `is_pr`.
    ///
    /// - Parameters:
    ///   - isFirstRecord: no había marca previa de este ejercicio (`delta_kg` nulo o `pr_kind`
    ///     `first`). Sube a nivel 3.
    ///   - previousBestKg: mejor peso anterior, para saber si se ha cruzado una cifra redonda.
    public static func forConfirmedRecord(
        exerciseName: String,
        weightKg: Double?,
        reps: Int,
        e1rmKg: Double?,
        deltaKg: Double?,
        isFirstRecord: Bool,
        previousBestKg: Double? = nil,
        unit: TrainingWeightUnit
    ) -> PersonalRecordCelebration {

        // El hito por cifra redonda solo se evalúa cuando se sabe cuál era la marca anterior.
        // Sin ese dato, cualquier serie que caiga en 185 lb se celebraría como hito aunque la
        // persona lleve un año levantando más: es celebrar de más, que gasta la celebración.
        let milestone: Double? = {
            guard let weightKg, let previousBestKg else { return nil }
            return OneRepMax.milestoneReached(
                weightKg: weightKg,
                previousBestKg: previousBestKg,
                unit: unit
            )
        }()
        let level: CelebrationLevel = (isFirstRecord || milestone != nil) ? .milestone : .record

        let headline = setText(exerciseName: exerciseName, weightKg: weightKg, reps: reps, unit: unit)

        var pieces: [String] = []
        if let e1rmKg {
            pieces.append("est. 1RM \(loadText(kilograms: e1rmKg, unit: unit))")
        }
        if isFirstRecord {
            pieces.append(firstRecordDetail)
        } else if let deltaKg, let delta = deltaText(kilograms: deltaKg, unit: unit) {
            pieces.append(delta)
        }

        let title = level == .milestone ? milestoneTitle : confirmedTitle
        let spoken = level == .milestone
            ? "Milestone. \(spokenSet(exerciseName: exerciseName, weightKg: weightKg, reps: reps, unit: unit))"
            : "Personal record. \(spokenSet(exerciseName: exerciseName, weightKg: weightKg, reps: reps, unit: unit))"

        return PersonalRecordCelebration(
            level: level,
            title: title,
            headline: headline,
            detail: pieces.isEmpty ? nil : pieces.joined(separator: " · "),
            isConfirmed: true,
            accessibilityLabel: pieces.isEmpty ? spoken : "\(spoken) \(pieces.joined(separator: ", "))."
        )
    }

    // MARK: Mejor serie local (nivel 1)

    /// Celebración de la mejor serie de la sesión en curso. **Nunca** se llama «Personal
    /// record»: el servidor todavía no ha dicho nada (plan §4.5).
    public static func forLocalBestSet(
        exerciseName: String,
        best: BestSetSoFar,
        unit: TrainingWeightUnit
    ) -> PersonalRecordCelebration {

        let headline = setText(
            exerciseName: exerciseName,
            weightKg: best.weightKg,
            reps: best.reps,
            unit: unit
        )
        let detail = best.e1rmKg.map { "est. 1RM \(loadText(kilograms: $0, unit: unit))" }
        let spoken = "Best set so far. \(spokenSet(exerciseName: exerciseName, weightKg: best.weightKg, reps: best.reps, unit: unit))"

        return PersonalRecordCelebration(
            level: .recognition,
            title: unconfirmedTitle,
            headline: headline,
            detail: detail,
            isConfirmed: false,
            accessibilityLabel: detail == nil ? spoken : "\(spoken) \(detail!)."
        )
    }

    // MARK: Texto de una serie

    /// «Bench press · 185 × 5». Sin peso (peso corporal): «Pull-up · 12 reps».
    public static func setText(
        exerciseName: String,
        weightKg: Double?,
        reps: Int,
        unit: TrainingWeightUnit
    ) -> String {
        guard let weightKg else { return "\(exerciseName) · \(reps) reps" }
        let value = number(unit.fromKilograms(OneRepMax.roundToStep(kilograms: weightKg, unit: unit)))
        return "\(exerciseName) · \(value) × \(reps)"
    }

    /// La misma serie, dicha en voz alta con su unidad entera (UX §1.8).
    public static func spokenSet(
        exerciseName: String,
        weightKg: Double?,
        reps: Int,
        unit: TrainingWeightUnit
    ) -> String {
        let repsText = reps == 1 ? "1 rep" : "\(reps) reps"
        guard let weightKg else { return "\(exerciseName), \(repsText)." }
        let value = number(unit.fromKilograms(OneRepMax.roundToStep(kilograms: weightKg, unit: unit)))
        let unitWord = unit == .pounds ? "pounds" : "kilograms"
        return "\(exerciseName), \(value) \(unitWord) for \(repsText)."
    }
}

// MARK: - Estado de una fila de serie (S11)

/// Los tres estados en los que puede estar una fila de la tabla de series.
///
/// Se comunica con glifo Y con texto, nunca solo con color (checklist §10.5): el círculo relleno
/// del hecho, el anillo de acento de la activa y el círculo vacío de la que falta.
public enum SetRowState: String, Hashable, Sendable {
    /// Marcada. La fila baja su opacidad y el check se rellena.
    case done
    /// La siguiente que toca: es la única con los controles de edición a la vista.
    case active
    /// Todavía no le toca.
    case upcoming

    /// Lo que lee VoiceOver como estado de la fila.
    public var spokenState: String {
        switch self {
        case .done: return "Done"
        case .active: return "Up next"
        case .upcoming: return "Not started"
        }
    }
}

public extension SessionExercise {

    /// Estado de cada fila: la primera no marcada es la activa; las demás, hechas o pendientes.
    ///
    /// No se usa `activeSet` desde la vista para esto porque compararía identidades en cada
    /// redibujado de cada fila; aquí se resuelve una vez por fila con una sola pasada.
    func rowState(forSetId id: UUID) -> SetRowState {
        guard let set = sets.first(where: { $0.id == id }) else { return .upcoming }
        if set.isDone { return .done }
        if let first = sets.first(where: { !$0.isDone }), first.id == id { return .active }
        return .upcoming
    }

    /// Etiqueta de VoiceOver de una fila: «Set 3 of 4».
    func rowLabel(forSetNumber number: Int) -> String {
        "Set \(number) of \(max(sets.count, number))"
    }

    /// Valor de VoiceOver de una fila: «185 pounds, 5 reps, RPE not set».
    ///
    /// Con una serie por tiempo o por distancia lo que se dice es lo que se midió («45 seconds»,
    /// «400 meters»); el peso sigue delante cuando lo hay, porque un farmer carry lo tiene.
    func rowValue(for set: SessionSet, unit: TrainingWeightUnit) -> String {
        var parts: [String] = []
        if let weight = set.weightKg {
            let value = Celebration.number(unit.fromKilograms(OneRepMax.roundToStep(kilograms: weight, unit: unit)))
            parts.append("\(value) \(unit == .pounds ? "pounds" : "kilograms")")
        } else if measure == .reps {
            parts.append("bodyweight")
        }
        switch measure {
        case .reps:
            parts.append(set.reps == 1 ? "1 rep" : "\(set.reps) reps")
        case .duration:
            parts.append(Celebration.spokenDuration(set.durationSeconds ?? 0))
        case .distance:
            parts.append(Celebration.spokenDistance(meters: set.distanceMeters ?? 0))
        }
        if let rpe = set.rpe {
            parts.append("RPE \(Celebration.number(rpe))")
        } else {
            parts.append("RPE not set")
        }
        return parts.joined(separator: ", ")
    }
}
