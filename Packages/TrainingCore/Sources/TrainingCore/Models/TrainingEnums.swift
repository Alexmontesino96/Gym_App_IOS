//
//  TrainingEnums.swift
//  TrainingCore
//
//  Enumeraciones del contrato (plan §5 y §6). Todas decodifican con reserva: un valor nuevo en
//  el servidor no puede tumbar la pantalla entera del cliente, así que cae en el caso por
//  defecto y la interfaz lo trata como «otro».
//

import Foundation

/// Enum del backend que nunca lanza al decodificar: un valor desconocido cae en `fallback`.
public protocol TrainingCodableEnum: RawRepresentable, Codable, Hashable, Sendable, CaseIterable
where RawValue == String {
    static var fallback: Self { get }
}

public extension TrainingCodableEnum {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.fallback
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Catálogo

public enum ExerciseCategory: String, TrainingCodableEnum {
    case strength
    case cardio
    case mobility
    case other

    public static var fallback: ExerciseCategory { .other }
}

// MARK: - Programa

public enum TrainingProgramStatus: String, TrainingCodableEnum {
    case draft
    case active
    case archived

    public static var fallback: TrainingProgramStatus { .draft }
}

public enum TrainingProgramVisibility: String, TrainingCodableEnum {
    case `private`
    case group

    /// Falla cerrado: lo que no se reconoce no enseña nada social.
    public static var fallback: TrainingProgramVisibility { .private }
}

// MARK: - Prescripción

/// Con qué se mide una serie (contrato §8.1).
///
/// `reps` es el valor por defecto de todas las filas que existían antes: un servidor que no
/// mande el campo describe exactamente lo que describía ayer. Con `duration` el objetivo es
/// `duration_seconds` y las repeticiones se ignoran; con `distance`, `distance_m`. La carga
/// (`load_mode` / `load_value`) sigue valiendo para las tres: un farmer carry tiene tiempo y peso.
public enum TrainingMeasure: String, TrainingCodableEnum {
    case reps
    case duration
    case distance

    public static var fallback: TrainingMeasure { .reps }

    /// Los tres, en el orden en que se ofrecen en el menú «Measure» del editor.
    public static let allMeasures: [TrainingMeasure] = [.reps, .duration, .distance]

    /// Con la que entra un ejercicio del catálogo: el cardio se mide en tiempo, todo lo demás
    /// en repeticiones. Es una propuesta, no una atadura: el entrenador la cambia en un toque.
    public static func `default`(for category: ExerciseCategory) -> TrainingMeasure {
        category == .cardio ? .duration : .reps
    }

    /// Etiqueta del selector: `Reps` / `Time` / `Distance` (contrato §8.1).
    public var title: String {
        switch self {
        case .reps: return "Reps"
        case .duration: return "Time"
        case .distance: return "Distance"
        }
    }

    /// Volumen y 1RM estimado solo existen para repeticiones. Un plank no tiene tonelaje y un
    /// 400 m no tiene 1RM; inventárselos ensuciaría el histórico de fuerza de la persona.
    public var countsTowardsVolume: Bool { self == .reps }
}

public enum TrainingLoadMode: String, TrainingCodableEnum {
    /// `load_value` en kilos.
    case weight
    /// `load_value` es un porcentaje del 1RM.
    case percent1RM = "percent_1rm"
    /// La carga la decide el RPE objetivo; `load_value` es nulo.
    case rpe
    /// Sin carga externa.
    case bodyweight

    public static var fallback: TrainingLoadMode { .weight }
}

// MARK: - Asignación

public enum TrainingAssignmentMode: String, TrainingCodableEnum {
    case copy
    case shared

    public static var fallback: TrainingAssignmentMode { .copy }
}

public enum TrainingAssignmentStatus: String, TrainingCodableEnum {
    case active
    case completed
    case ended

    public static var fallback: TrainingAssignmentStatus { .ended }
}

// MARK: - Registro

public enum WorkoutLogStatus: String, TrainingCodableEnum {
    case inProgress = "in_progress"
    case completed

    public static var fallback: WorkoutLogStatus { .inProgress }
}

/// Lo que el cliente dice de un ejercicio al terminarlo (contrato §8.2).
///
/// Cuatro respuestas y nada más: son las que un entrenador puede leer de un vistazo y las
/// únicas que el servidor acepta. `unknown` no se ofrece ni se envía: existe para que un flag
/// que este cliente todavía no conoce no tumbe la pantalla al decodificar.
public enum TrainingFeedbackFlag: String, TrainingCodableEnum {
    case pain
    case tooEasy = "too_easy"
    case tooHard = "too_hard"
    case skipped
    case unknown

    public static var fallback: TrainingFeedbackFlag { .unknown }

    /// Los cuatro que se pueden elegir, en el orden de la hoja.
    public static let selectable: [TrainingFeedbackFlag] = [.pain, .tooEasy, .tooHard, .skipped]

    /// Texto del chip y del botón: «Pain», «Too easy», «Too hard», «Skipped».
    public var title: String {
        switch self {
        case .pain: return "Pain"
        case .tooEasy: return "Too easy"
        case .tooHard: return "Too hard"
        case .skipped: return "Skipped"
        case .unknown: return ""
        }
    }

    /// SF Symbol del chip. Nunca es lo único que distingue un flag de otro: al lado va la palabra.
    public var systemImage: String {
        switch self {
        case .pain: return "exclamationmark.triangle"
        case .tooEasy: return "arrow.down"
        case .tooHard: return "arrow.up"
        case .skipped: return "minus.circle"
        case .unknown: return "questionmark"
        }
    }

    /// `pain` es el único que el entrenador tiene que ver antes que nada: se pinta con la tinta
    /// de aviso del tema (`Color.dynamicWarningText`), no con un amarillo crudo.
    public var isAlarming: Bool { self == .pain }
}

public enum PersonalRecordKind: String, TrainingCodableEnum {
    case e1rm
    case weight
    case reps
    case first

    public static var fallback: PersonalRecordKind { .first }
}

// MARK: - Estado de un día en la interfaz (plan §4.2)

public enum TrainingDayStatus: String, TrainingCodableEnum {
    /// Existe un registro completado para ese día.
    case done
    /// Es hoy y no hay registro todavía.
    case today
    /// Día de descanso.
    case rest
    /// Futuro.
    case pending
    /// Pasado, no era descanso y no hay registro.
    case skipped

    public static var fallback: TrainingDayStatus { .pending }
}

// MARK: - Unidad de peso

/// Unidad de presentación. El servidor guarda **siempre** kilos (plan §4.4); esto es del borde
/// de la interfaz. La app tiene su propia `WeightUnit` en `Utils/MeasurementFormatting.swift`
/// y hace de puente con esta.
public enum TrainingWeightUnit: String, TrainingCodableEnum {
    case kilograms = "kg"
    case pounds = "lb"

    public static var fallback: TrainingWeightUnit { .kilograms }

    public static let poundsPerKilogram = 2.204622621848776

    /// Paso de carga del módulo de entrenamiento: 5 lb / 2,5 kg (plan §2.2).
    public var loadStep: Double {
        switch self {
        case .kilograms: return 2.5
        case .pounds: return 5
        }
    }

    public var symbol: String { rawValue }

    public func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kilograms: return kilograms
        case .pounds: return kilograms * Self.poundsPerKilogram
        }
    }

    public func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: return value
        case .pounds: return value / Self.poundsPerKilogram
        }
    }
}
