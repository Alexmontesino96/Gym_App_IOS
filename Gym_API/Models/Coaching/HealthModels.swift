//
//  HealthModels.swift
//  Gym_API
//
//  Modelos del módulo de salud del backend (/api/v1/health).
//
//  Alimentan el check-in semanal (peso y variación) y el progreso hacia un objetivo.
//  Todos los CodingKeys son explícitos: el decodificador NO usa keyDecodingStrategy.
//

import Foundation
import TrainingCore

// MARK: - Medición corporal

struct HealthMeasurement: Codable, Identifiable, Equatable {
    let id: Int
    let weight: Double?
    let bodyFatPercentage: Double?
    let muscleMass: Double?
    let visceralFat: Double?
    let boneMass: Double?
    let waterPercentage: Double?
    let measurementType: String
    let notes: String?
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, weight, notes
        case bodyFatPercentage = "body_fat_percentage"
        case muscleMass = "muscle_mass"
        case visceralFat = "visceral_fat"
        case boneMass = "bone_mass"
        case waterPercentage = "water_percentage"
        case measurementType = "measurement_type"
        case recordedAt = "recorded_at"
    }

    /// Una medición tomada por el entrenador se muestra distinto que una que se pesó el cliente.
    var takenByTrainer: Bool { measurementType.lowercased() == "trainer" }
}

// MARK: - Serie de peso

struct WeightHistoryPoint: Codable, Equatable, Identifiable {
    let recordedAt: Date
    let weight: Double

    var id: Date { recordedAt }

    enum CodingKeys: String, CodingKey {
        case recordedAt = "recorded_at"
        case weight
    }
}

struct WeightHistory: Codable, Equatable {
    let days: Int
    let points: [WeightHistoryPoint]
    let currentWeight: Double?
    /// Diferencia entre la última y la primera medición de la ventana. Negativa si ha bajado.
    let change: Double?

    enum CodingKeys: String, CodingKey {
        case days, points, change
        case currentWeight = "current_weight"
    }

    static let empty = WeightHistory(days: 0, points: [], currentWeight: nil, change: nil)

    var values: [Double] { points.map(\.weight) }
}

// MARK: - Objetivos

struct HealthGoal: Codable, Identifiable, Equatable {
    let id: Int
    let goalType: String
    let title: String
    let description: String?
    let targetValue: Double
    let currentValue: Double
    let startValue: Double?
    let unit: String
    let targetDate: Date?
    let status: String
    let progressPercentage: Double
    let createdAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, unit, status
        case goalType = "goal_type"
        case targetValue = "target_value"
        case currentValue = "current_value"
        case startValue = "start_value"
        case targetDate = "target_date"
        case progressPercentage = "progress_percentage"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    var isStrength: Bool { goalType.lowercased() == "strength" }

    /// Mejora sobre el punto de partida, en porcentaje. Nil si no hay punto de partida útil.
    var improvementPercentage: Double? {
        guard let start = startValue, start > 0 else { return nil }
        return ((currentValue - start) / start) * 100
    }
}

// MARK: - Cuerpos de petición

struct HealthMeasurementRequest: Codable {
    let weight: Double?
    let bodyFatPercentage: Double?
    let muscleMass: Double?
    let measurementType: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case weight, notes
        case bodyFatPercentage = "body_fat_percentage"
        case muscleMass = "muscle_mass"
        case measurementType = "measurement_type"
    }

    init(weight: Double?, bodyFatPercentage: Double? = nil, muscleMass: Double? = nil,
         measurementType: String = "manual", notes: String? = nil) {
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.muscleMass = muscleMass
        self.measurementType = measurementType
        self.notes = notes
    }
}

struct HealthGoalProgressRequest: Codable {
    let currentValue: Double

    enum CodingKeys: String, CodingKey {
        case currentValue = "current_value"
    }
}

// MARK: - Check-in semanal

/// Lo que se envía al hacer el check-in de la semana.
///
/// El peso va en kilos: es lo que guarda el servidor. La conversión desde libras la hace la
/// pantalla antes de construir esto.
struct WeeklyCheckInRequest: Codable {
    let weight: Double?
    let energy: Int?
    let sleep: Int?
    let soreness: Int?
    let notes: String?
}

/// Check-in devuelto por el servidor, con el peso de la medición que creó en el mismo gesto.
struct WeeklyCheckIn: Codable, Identifiable, Equatable {
    let id: Int
    let weekStart: Date
    let energy: Int?
    let sleep: Int?
    let soreness: Int?
    let notes: String?
    /// Peso en kilos de la medición enlazada. Nil si esa semana no hubo báscula.
    let weight: Double?
    let measurementId: Int?
    let createdAt: Date
    /// Respuesta del entrenador (8.5). Los tres son opcionales a propósito: la mayoría de
    /// check-ins nunca se contestan, y un JSON que no traiga estas claves no debe tumbar el
    /// decodificador.
    let coachReply: String?
    let coachReplyAt: Date?
    let coachReplyBy: Int?

    enum CodingKeys: String, CodingKey {
        case id, energy, sleep, soreness, notes, weight
        case weekStart = "week_start"
        case measurementId = "measurement_id"
        case createdAt = "created_at"
        case coachReply = "coach_reply"
        case coachReplyAt = "coach_reply_at"
        case coachReplyBy = "coach_reply_by"
    }
}

// MARK: - Respuesta al check-in (8.5)

/// Cuerpo de `POST /health/clients/{user_id}/check-ins/{checkin_id}/reply`.
struct CheckInReplyRequest: Codable {
    let text: String
}

// MARK: - Intake del cliente (8.4)

/// Nivel de experiencia declarado en el intake. Un valor desconocido del servidor cae a
/// `.beginner` en vez de tumbar la pantalla, como manda `TrainingCodableEnum`.
enum IntakeExperience: String, TrainingCodableEnum {
    case beginner
    case intermediate
    case advanced

    static var fallback: IntakeExperience { .beginner }

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

/// Las siete preguntas del PAR-Q+ (forma corta). Las claves y el orden son el contrato del
/// backend; el texto en inglés que las acompaña vive en `IntakeFlowView`, no aquí.
struct ParqAnswers: Codable, Equatable {
    var q1: Bool
    var q2: Bool
    var q3: Bool
    var q4: Bool
    var q5: Bool
    var q6: Bool
    var q7: Bool

    static let allNo = ParqAnswers(q1: false, q2: false, q3: false, q4: false, q5: false, q6: false, q7: false)

    /// Si cualquiera es «sí», el servidor guarda `parq_flagged = true` y el cliente enseña el
    /// aviso de que el entrenador lo revisará antes de la primera sesión.
    var anyYes: Bool { q1 || q2 || q3 || q4 || q5 || q6 || q7 }

    /// Claves en `q1`, en el orden en que se preguntan, de las que la respuesta fue «sí». Sirve
    /// para pintar los flags en la ficha del entrenador sin repetir el `switch` en cada sitio.
    var flaggedKeys: [String] {
        var keys: [String] = []
        if q1 { keys.append("q1") }
        if q2 { keys.append("q2") }
        if q3 { keys.append("q3") }
        if q4 { keys.append("q4") }
        if q5 { keys.append("q5") }
        if q6 { keys.append("q6") }
        if q7 { keys.append("q7") }
        return keys
    }
}

/// `coaching_client_intakes`, tal y como lo devuelve el servidor.
struct ClientIntake: Codable, Equatable {
    let goals: String
    let experience: IntakeExperience
    /// `mon`…`sun`. Se guarda tal cual llega: filtrar claves desconocidas es cosa de quien
    /// pinta la lista, no del modelo.
    let availableDays: [String]
    let injuries: String?
    let medicalNotes: String?
    let parq: ParqAnswers
    let parqFlagged: Bool
    let waiverAcceptedAt: Date?
    let waiverVersion: String?
    let submittedAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case goals, experience, injuries, parq
        case availableDays = "available_days"
        case medicalNotes = "medical_notes"
        case parqFlagged = "parq_flagged"
        case waiverAcceptedAt = "waiver_accepted_at"
        case waiverVersion = "waiver_version"
        case submittedAt = "submitted_at"
        case updatedAt = "updated_at"
    }

    /// Decodificación tolerante.
    ///
    /// El contrato §8.4 describe `goals`, `experience`, `available_days` y `parq` como columnas
    /// con valor, pero `PUT /health/intake` acepta un upsert PARCIAL: una fila creada mandando
    /// solo `goals` vuelve con `experience`, `available_days` y `parq` a nulo. Con los campos
    /// obligatorios esa respuesta tumbaba la decodificación entera y la ficha del entrenador
    /// enseñaba «no se pudo cargar» en vez del intake a medias que el cliente escribió.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goals = try container.decodeIfPresent(String.self, forKey: .goals) ?? ""
        experience = try container.decodeIfPresent(IntakeExperience.self, forKey: .experience) ?? .fallback
        availableDays = try container.decodeIfPresent([String].self, forKey: .availableDays) ?? []
        injuries = try container.decodeIfPresent(String.self, forKey: .injuries)
        medicalNotes = try container.decodeIfPresent(String.self, forKey: .medicalNotes)
        parq = try container.decodeIfPresent(ParqAnswers.self, forKey: .parq) ?? .allNo
        parqFlagged = try container.decodeIfPresent(Bool.self, forKey: .parqFlagged) ?? false
        waiverAcceptedAt = try container.decodeIfPresent(Date.self, forKey: .waiverAcceptedAt)
        waiverVersion = try container.decodeIfPresent(String.self, forKey: .waiverVersion)
        submittedAt = try container.decodeIfPresent(Date.self, forKey: .submittedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

/// Cuerpo de `PUT /health/intake`. La versión del waiver mostrado en el paso 4 de
/// `IntakeFlowView`; sin `waiverAccepted` en `true` la hoja no deja enviar.
struct ClientIntakeRequest: Codable {
    let goals: String
    let experience: IntakeExperience
    let availableDays: [String]
    let injuries: String?
    let medicalNotes: String?
    let parq: ParqAnswers
    let waiverAccepted: Bool
    let waiverVersion: String

    enum CodingKeys: String, CodingKey {
        case goals, experience, injuries, parq
        case availableDays = "available_days"
        case medicalNotes = "medical_notes"
        case waiverAccepted = "waiver_accepted"
        case waiverVersion = "waiver_version"
    }
}
