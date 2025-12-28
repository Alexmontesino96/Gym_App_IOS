import Foundation

// MARK: - Enums

enum PlanType: String, Codable {
    case template
    case live
    case archived
}

enum PlanStatus: String, Codable {
    case notStarted = "not_started"
    case running
    case finished
}

enum NutritionGoal: String, Codable {
    case weightLoss = "weight_loss"
    case muscleGain = "muscle_gain"
    case maintenance
    case bulk
    case cut
    case performance

    var displayName: String {
        switch self {
        case .weightLoss: return "Pérdida de Peso"
        case .muscleGain: return "Ganancia Muscular"
        case .maintenance: return "Mantenimiento"
        case .bulk: return "Volumen"
        case .cut: return "Definición"
        case .performance: return "Rendimiento"
        }
    }

    var icon: String {
        switch self {
        case .weightLoss: return "arrow.down.circle.fill"
        case .muscleGain: return "arrow.up.circle.fill"
        case .maintenance: return "equal.circle.fill"
        case .bulk: return "chart.line.uptrend.xyaxis"
        case .cut: return "scissors"
        case .performance: return "bolt.fill"
        }
    }
}

// NOTE: DifficultyLevel is defined in GymClass.swift

enum BudgetLevel: String, Codable {
    case economic
    case medium
    case premium

    var displayName: String {
        switch self {
        case .economic: return "Económico"
        case .medium: return "Medio"
        case .premium: return "Premium"
        }
    }

    var icon: String {
        switch self {
        case .economic: return "dollarsign.circle"
        case .medium: return "dollarsign.circle.fill"
        case .premium: return "star.circle.fill"
        }
    }
}

enum DietaryRestriction: String, Codable {
    case none
    case vegetarian
    case vegan
    case glutenFree = "gluten_free"
    case lactoseFree = "lactose_free"
    case keto
    case paleo
    case mediterranean

    var displayName: String {
        switch self {
        case .none: return "Sin restricciones"
        case .vegetarian: return "Vegetariano"
        case .vegan: return "Vegano"
        case .glutenFree: return "Sin Gluten"
        case .lactoseFree: return "Sin Lactosa"
        case .keto: return "Cetogénico"
        case .paleo: return "Paleo"
        case .mediterranean: return "Mediterráneo"
        }
    }

    var icon: String {
        switch self {
        case .none: return "leaf"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .glutenFree: return "allergens"
        case .lactoseFree: return "drop.triangle"
        case .keto: return "flame.fill"
        case .paleo: return "figure.walk"
        case .mediterranean: return "globe.europe.africa.fill"
        }
    }
}

// MARK: - NutritionPlan Model

struct NutritionPlan: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let planType: PlanType
    let goal: NutritionGoal
    let difficultyLevel: DifficultyLevel
    let budgetLevel: BudgetLevel
    let dietaryRestrictions: [DietaryRestriction]
    let durationDays: Int
    let isRecurring: Bool
    let targetCalories: Int?
    let targetProteinG: Int?
    let targetCarbsG: Int?
    let targetFatG: Int?

    // Live plan specific fields
    let liveStartDate: Date?
    let liveEndDate: Date?
    let isLiveActive: Bool
    let liveParticipantsCount: Int

    // Archived plan specific fields
    let originalLivePlanId: Int?
    let originalParticipantsCount: Int?
    let archivedAt: Date?

    // User context
    let isFollowedByUser: Bool
    let currentDay: Int?
    let status: PlanStatus?
    let daysUntilStart: Int?

    // Creator info (opcional porque no siempre viene del backend)
    let creatorId: Int?
    let creatorName: String?
    let followersCount: Int?
    let avgSatisfaction: Double?

    // Tags and metadata
    let tags: [String]
    let isPublic: Bool

    // Timestamps
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case planType = "plan_type"
        case goal
        case difficultyLevel = "difficulty_level"
        case budgetLevel = "budget_level"
        case dietaryRestrictions = "dietary_restrictions"
        case durationDays = "duration_days"
        case isRecurring = "is_recurring"
        case targetCalories = "target_calories"
        case targetProteinG = "target_protein_g"
        case targetCarbsG = "target_carbs_g"
        case targetFatG = "target_fat_g"
        case liveStartDate = "live_start_date"
        case liveEndDate = "live_end_date"
        case isLiveActive = "is_live_active"
        case liveParticipantsCount = "live_participants_count"
        case originalLivePlanId = "original_live_plan_id"
        case originalParticipantsCount = "original_participants_count"
        case archivedAt = "archived_at"
        case isFollowedByUser = "is_followed_by_user"
        case currentDay = "current_day"
        case status
        case daysUntilStart = "days_until_start"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case followersCount = "total_followers"
        case avgSatisfaction = "avg_satisfaction"
        case tags
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Public Initializer

    init(
        id: Int,
        title: String,
        description: String? = nil,
        planType: PlanType,
        goal: NutritionGoal,
        difficultyLevel: DifficultyLevel,
        budgetLevel: BudgetLevel,
        dietaryRestrictions: [DietaryRestriction],
        durationDays: Int,
        isRecurring: Bool,
        targetCalories: Int? = nil,
        targetProteinG: Int? = nil,
        targetCarbsG: Int? = nil,
        targetFatG: Int? = nil,
        liveStartDate: Date? = nil,
        liveEndDate: Date? = nil,
        isLiveActive: Bool,
        liveParticipantsCount: Int,
        originalLivePlanId: Int? = nil,
        originalParticipantsCount: Int? = nil,
        archivedAt: Date? = nil,
        isFollowedByUser: Bool,
        currentDay: Int? = nil,
        status: PlanStatus? = nil,
        daysUntilStart: Int? = nil,
        creatorId: Int? = nil,
        creatorName: String? = nil,
        followersCount: Int? = nil,
        avgSatisfaction: Double? = nil,
        tags: [String],
        isPublic: Bool,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.planType = planType
        self.goal = goal
        self.difficultyLevel = difficultyLevel
        self.budgetLevel = budgetLevel
        self.dietaryRestrictions = dietaryRestrictions
        self.durationDays = durationDays
        self.isRecurring = isRecurring
        self.targetCalories = targetCalories
        self.targetProteinG = targetProteinG
        self.targetCarbsG = targetCarbsG
        self.targetFatG = targetFatG
        self.liveStartDate = liveStartDate
        self.liveEndDate = liveEndDate
        self.isLiveActive = isLiveActive
        self.liveParticipantsCount = liveParticipantsCount
        self.originalLivePlanId = originalLivePlanId
        self.originalParticipantsCount = originalParticipantsCount
        self.archivedAt = archivedAt
        self.isFollowedByUser = isFollowedByUser
        self.currentDay = currentDay
        self.status = status
        self.daysUntilStart = daysUntilStart
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.followersCount = followersCount
        self.avgSatisfaction = avgSatisfaction
        self.tags = tags
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        planType = try container.decode(PlanType.self, forKey: .planType)
        goal = try container.decode(NutritionGoal.self, forKey: .goal)
        difficultyLevel = try container.decode(DifficultyLevel.self, forKey: .difficultyLevel)
        budgetLevel = try container.decode(BudgetLevel.self, forKey: .budgetLevel)

        // Handle dietaryRestrictions - puede ser string o array
        // Intentar primero como String (formato mas comun del backend)
        if let restrictionString = try? container.decode(String.self, forKey: .dietaryRestrictions) {
            // Si es un string, intentar convertir a DietaryRestriction
            if let restriction = DietaryRestriction(rawValue: restrictionString) {
                dietaryRestrictions = [restriction]
            } else {
                dietaryRestrictions = [.none]
            }
        } else if let restrictionsArray = try? container.decode([DietaryRestriction].self, forKey: .dietaryRestrictions) {
            dietaryRestrictions = restrictionsArray
        } else {
            // Si no se puede decodificar ni como string ni como array
            dietaryRestrictions = [.none]
        }

        durationDays = try container.decode(Int.self, forKey: .durationDays)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        targetCalories = try container.decodeIfPresent(Int.self, forKey: .targetCalories)
        targetProteinG = try container.decodeIfPresent(Int.self, forKey: .targetProteinG)
        targetCarbsG = try container.decodeIfPresent(Int.self, forKey: .targetCarbsG)
        targetFatG = try container.decodeIfPresent(Int.self, forKey: .targetFatG)

        liveStartDate = try container.decodeIfPresent(Date.self, forKey: .liveStartDate)
        liveEndDate = try container.decodeIfPresent(Date.self, forKey: .liveEndDate)
        isLiveActive = try container.decode(Bool.self, forKey: .isLiveActive)
        liveParticipantsCount = try container.decode(Int.self, forKey: .liveParticipantsCount)

        originalLivePlanId = try container.decodeIfPresent(Int.self, forKey: .originalLivePlanId)
        originalParticipantsCount = try container.decodeIfPresent(Int.self, forKey: .originalParticipantsCount)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)

        // is_followed_by_user puede no estar presente en available_plans
        isFollowedByUser = try container.decodeIfPresent(Bool.self, forKey: .isFollowedByUser) ?? false
        currentDay = try container.decodeIfPresent(Int.self, forKey: .currentDay)
        status = try container.decodeIfPresent(PlanStatus.self, forKey: .status)
        daysUntilStart = try container.decodeIfPresent(Int.self, forKey: .daysUntilStart)

        creatorId = try container.decodeIfPresent(Int.self, forKey: .creatorId)
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)
        avgSatisfaction = try container.decodeIfPresent(Double.self, forKey: .avgSatisfaction)

        tags = try container.decode([String].self, forKey: .tags)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    // MARK: - Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(planType, forKey: .planType)
        try container.encode(goal, forKey: .goal)
        try container.encode(difficultyLevel, forKey: .difficultyLevel)
        try container.encode(budgetLevel, forKey: .budgetLevel)
        try container.encode(dietaryRestrictions, forKey: .dietaryRestrictions)
        try container.encode(durationDays, forKey: .durationDays)
        try container.encode(isRecurring, forKey: .isRecurring)
        try container.encodeIfPresent(targetCalories, forKey: .targetCalories)
        try container.encodeIfPresent(targetProteinG, forKey: .targetProteinG)
        try container.encodeIfPresent(targetCarbsG, forKey: .targetCarbsG)
        try container.encodeIfPresent(targetFatG, forKey: .targetFatG)
        try container.encodeIfPresent(liveStartDate, forKey: .liveStartDate)
        try container.encodeIfPresent(liveEndDate, forKey: .liveEndDate)
        try container.encode(isLiveActive, forKey: .isLiveActive)
        try container.encode(liveParticipantsCount, forKey: .liveParticipantsCount)
        try container.encodeIfPresent(originalLivePlanId, forKey: .originalLivePlanId)
        try container.encodeIfPresent(originalParticipantsCount, forKey: .originalParticipantsCount)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try container.encode(isFollowedByUser, forKey: .isFollowedByUser)
        try container.encodeIfPresent(currentDay, forKey: .currentDay)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(daysUntilStart, forKey: .daysUntilStart)
        try container.encodeIfPresent(creatorId, forKey: .creatorId)
        try container.encodeIfPresent(creatorName, forKey: .creatorName)
        try container.encodeIfPresent(followersCount, forKey: .followersCount)
        try container.encodeIfPresent(avgSatisfaction, forKey: .avgSatisfaction)
        try container.encode(tags, forKey: .tags)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Helper Extensions

extension NutritionPlan {
    /// Indica si el plan es un challenge LIVE activo actualmente
    var isActiveLiveChallenge: Bool {
        return planType == .live && status == .running && isLiveActive
    }

    /// Indica si el plan es un challenge LIVE próximo a empezar
    var isUpcomingLiveChallenge: Bool {
        return planType == .live && status == .notStarted && isLiveActive
    }

    /// Indica si el usuario puede unirse al plan
    var canJoin: Bool {
        if isFollowedByUser {
            return false
        }

        switch planType {
        case .template, .archived:
            return true
        case .live:
            return status != .finished
        }
    }

    /// Texto para el botón de acción principal
    var primaryActionText: String {
        if isFollowedByUser {
            return "Ver mi progreso"
        }

        switch status {
        case .notStarted:
            return "Reservar lugar"
        case .running:
            return "Unirse ahora"
        case .finished:
            return "Ver detalles"
        case .none:
            return "Empezar plan"
        }
    }

    /// Color del badge según el tipo de plan
    var typeColor: String {
        switch planType {
        case .live: return "red"
        case .template: return "blue"
        case .archived: return "purple"
        }
    }

    /// Label para el badge de tipo
    var typeLabel: String {
        switch planType {
        case .live: return "LIVE"
        case .template: return "FLEXIBLE"
        case .archived: return "ARCHIVED"
        }
    }
}
