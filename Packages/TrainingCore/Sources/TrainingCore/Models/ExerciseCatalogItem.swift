//
//  ExerciseCatalogItem.swift
//  TrainingCore
//
//  `GET /training/exercises` (plan §5, tabla `exercise_catalog`).
//

import Foundation

public struct ExerciseCatalogItem: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    /// Clave estable: global en snake_case (`barbell_back_squat`) o del espacio (`g12_my_lift`).
    public let exerciseKey: String
    public let name: String
    /// Nulo = ejercicio global del catálogo.
    public let gymId: Int?
    public let category: ExerciseCategory
    public let primaryMuscles: [String]
    public let equipment: String?
    public let isUnilateral: Bool
    public let defaultRestSeconds: Int
    public let instructions: String?
    public let demoVideoURL: String?
    public let thumbnailURL: String?
    public let isActive: Bool

    public enum CodingKeys: String, CodingKey {
        case id, name, category, equipment, instructions
        case exerciseKey = "exercise_key"
        case gymId = "gym_id"
        case primaryMuscles = "primary_muscles"
        case isUnilateral = "is_unilateral"
        case defaultRestSeconds = "default_rest_seconds"
        case demoVideoURL = "demo_video_url"
        case thumbnailURL = "thumbnail_url"
        case isActive = "is_active"
    }

    public init(
        id: Int,
        exerciseKey: String,
        name: String,
        gymId: Int? = nil,
        category: ExerciseCategory = .strength,
        primaryMuscles: [String] = [],
        equipment: String? = nil,
        isUnilateral: Bool = false,
        defaultRestSeconds: Int = 90,
        instructions: String? = nil,
        demoVideoURL: String? = nil,
        thumbnailURL: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.exerciseKey = exerciseKey
        self.name = name
        self.gymId = gymId
        self.category = category
        self.primaryMuscles = primaryMuscles
        self.equipment = equipment
        self.isUnilateral = isUnilateral
        self.defaultRestSeconds = defaultRestSeconds
        self.instructions = instructions
        self.demoVideoURL = demoVideoURL
        self.thumbnailURL = thumbnailURL
        self.isActive = isActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        exerciseKey = try container.decode(String.self, forKey: .exerciseKey)
        name = try container.decode(String.self, forKey: .name)
        gymId = try container.decodeIfPresent(Int.self, forKey: .gymId)
        category = try container.decodeIfPresent(ExerciseCategory.self, forKey: .category) ?? .strength
        primaryMuscles = try container.decodeIfPresent([String].self, forKey: .primaryMuscles) ?? []
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        isUnilateral = try container.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        defaultRestSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultRestSeconds) ?? 90
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        demoVideoURL = try container.decodeIfPresent(String.self, forKey: .demoVideoURL)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }

    /// `true` si el ejercicio lo creó el espacio y por tanto se puede editar desde el panel.
    public var isCustom: Bool { gymId != nil }
}
