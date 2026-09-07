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

    enum CodingKeys: String, CodingKey {
        case id, energy, sleep, soreness, notes, weight
        case weekStart = "week_start"
        case measurementId = "measurement_id"
        case createdAt = "created_at"
    }
}
