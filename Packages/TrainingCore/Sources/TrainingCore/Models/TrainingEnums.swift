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
