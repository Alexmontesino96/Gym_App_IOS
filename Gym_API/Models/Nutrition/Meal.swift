import Foundation

// MARK: - MealType Enum

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case midMorning = "mid_morning"
    case lunch
    case afternoon
    case dinner
    case postWorkout = "post_workout"
    case lateSnack = "late_snack"

    var displayName: String {
        switch self {
        case .breakfast: return "Desayuno"
        case .midMorning: return "Media Mañana"
        case .lunch: return "Almuerzo"
        case .afternoon: return "Merienda"
        case .dinner: return "Cena"
        case .postWorkout: return "Post-Entreno"
        case .lateSnack: return "Snack Nocturno"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .midMorning: return "sun.min.fill"
        case .lunch: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .dinner: return "moon.stars.fill"
        case .postWorkout: return "figure.run"
        case .lateSnack: return "moon.fill"
        }
    }

    var typicalTime: String {
        switch self {
        case .breakfast: return "07:00 - 09:00"
        case .midMorning: return "10:00 - 11:00"
        case .lunch: return "13:00 - 15:00"
        case .afternoon: return "16:00 - 17:00"
        case .dinner: return "19:00 - 21:00"
        case .postWorkout: return "Después de entrenar"
        case .lateSnack: return "22:00 - 23:00"
        }
    }

    var order: Int {
        switch self {
        case .breakfast: return 1
        case .midMorning: return 2
        case .lunch: return 3
        case .afternoon: return 4
        case .postWorkout: return 5
        case .dinner: return 6
        case .lateSnack: return 7
        }
    }
}

// MARK: - Meal Model

struct Meal: Codable, Identifiable {
    let id: Int
    let dailyPlanId: Int
    let mealType: MealType
    let name: String
    let description: String?
    let calories: Int
    let proteinG: Int?
    let carbsG: Int?
    let fatG: Int?
    let fiberG: Int?
    let preparationTimeMinutes: Int?
    let cookingInstructions: String?
    let orderInDay: Int
    let imageUrl: String?
    let ingredients: [MealIngredient]

    // User completion status
    let isCompleted: Bool
    let completionId: Int?
    let completedAt: Date?
    let satisfactionRating: Int?
    let completionPhotoUrl: String?

    // Nested user_completion object from /nutrition/today endpoint
    private struct UserCompletion: Codable {
        let satisfactionRating: Int?
        let photoUrl: String?
        let notes: String?
        let portionSizeModifier: Double?
        let completedAt: Date?
        let id: Int?

        enum CodingKeys: String, CodingKey {
            case satisfactionRating = "satisfaction_rating"
            case photoUrl = "photo_url"
            case notes
            case portionSizeModifier = "portion_size_modifier"
            case completedAt = "completed_at"
            case id
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case dailyPlanId = "daily_plan_id"
        case mealType = "meal_type"
        case name
        case description
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case preparationTimeMinutes = "preparation_time_minutes"
        case cookingInstructions = "cooking_instructions"
        case orderInDay = "order_in_day"
        case imageUrl = "image_url"
        case ingredients
        case isCompleted = "is_completed"
        case completionId = "completion_id"
        case completedAt = "completed_at"
        case satisfactionRating = "satisfaction_rating"
        case completionPhotoUrl = "completion_photo_url"
        case userCompletion = "user_completion"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        dailyPlanId = try container.decode(Int.self, forKey: .dailyPlanId)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        calories = try container.decode(Int.self, forKey: .calories)
        proteinG = try container.decodeIfPresent(Int.self, forKey: .proteinG)
        carbsG = try container.decodeIfPresent(Int.self, forKey: .carbsG)
        fatG = try container.decodeIfPresent(Int.self, forKey: .fatG)
        fiberG = try container.decodeIfPresent(Int.self, forKey: .fiberG)
        preparationTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .preparationTimeMinutes)
        cookingInstructions = try container.decodeIfPresent(String.self, forKey: .cookingInstructions)
        orderInDay = try container.decode(Int.self, forKey: .orderInDay)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        ingredients = try container.decodeIfPresent([MealIngredient].self, forKey: .ingredients) ?? []

        // Parse completion status from multiple sources:
        // 1. Direct "is_completed" field (some endpoints)
        // 2. "user_completion" nested object (from /nutrition/today)
        // 3. "completion_id" presence
        let userCompletion = try container.decodeIfPresent(UserCompletion.self, forKey: .userCompletion)
        let directIsCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
        let directCompletionId = try container.decodeIfPresent(Int.self, forKey: .completionId)

        // A meal is completed if:
        // - is_completed == true, OR
        // - user_completion has a satisfaction_rating (not null), OR
        // - user_completion has an id, OR
        // - completion_id exists
        if let direct = directIsCompleted {
            isCompleted = direct
        } else if let uc = userCompletion, (uc.satisfactionRating != nil || uc.id != nil || uc.completedAt != nil) {
            isCompleted = true
        } else if directCompletionId != nil {
            isCompleted = true
        } else {
            isCompleted = false
        }

        completionId = directCompletionId ?? userCompletion?.id
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt) ?? userCompletion?.completedAt
        satisfactionRating = try container.decodeIfPresent(Int.self, forKey: .satisfactionRating) ?? userCompletion?.satisfactionRating
        completionPhotoUrl = try container.decodeIfPresent(String.self, forKey: .completionPhotoUrl) ?? userCompletion?.photoUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dailyPlanId, forKey: .dailyPlanId)
        try container.encode(mealType, forKey: .mealType)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(calories, forKey: .calories)
        try container.encodeIfPresent(proteinG, forKey: .proteinG)
        try container.encodeIfPresent(carbsG, forKey: .carbsG)
        try container.encodeIfPresent(fatG, forKey: .fatG)
        try container.encodeIfPresent(fiberG, forKey: .fiberG)
        try container.encodeIfPresent(preparationTimeMinutes, forKey: .preparationTimeMinutes)
        try container.encodeIfPresent(cookingInstructions, forKey: .cookingInstructions)
        try container.encode(orderInDay, forKey: .orderInDay)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(completionId, forKey: .completionId)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(satisfactionRating, forKey: .satisfactionRating)
        try container.encodeIfPresent(completionPhotoUrl, forKey: .completionPhotoUrl)
    }
}

// MARK: - Helper Extensions

extension Meal {
    /// Macros de la comida
    var macros: MacroSummary {
        return MacroSummary(
            calories: calories,
            protein: proteinG ?? 0,
            carbs: carbsG ?? 0,
            fat: fatG ?? 0,
            fiber: fiberG ?? 0
        )
    }

    /// Tiempo de preparación formateado
    var preparationTimeFormatted: String? {
        guard let minutes = preparationTimeMinutes else { return nil }

        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)min"
            }
        }
    }

    /// Indica si la comida tiene instrucciones de preparación
    var hasInstructions: Bool {
        return cookingInstructions != nil && !cookingInstructions!.isEmpty
    }

    /// Número de ingredientes
    var ingredientCount: Int {
        return ingredients.count
    }

    /// Indica si la comida está disponible para completar (no bloqueada)
    var isAvailable: Bool {
        // Por ahora, todas las comidas están disponibles
        // En el futuro, podríamos bloquear comidas hasta cierta hora
        return true
    }

    /// Estado de la comida para UI
    var status: MealStatus {
        if isCompleted {
            return .completed
        } else if isAvailable {
            return .available
        } else {
            return .locked
        }
    }

    /// Texto del botón de acción según el estado
    var actionButtonText: String {
        switch status {
        case .completed:
            return "Ver detalles"
        case .available:
            return "Ver receta"
        case .locked:
            return "Bloqueada"
        }
    }

    /// Instrucciones de cocina en pasos (separadas por saltos de línea)
    var cookingSteps: [String] {
        guard let instructions = cookingInstructions else { return [] }
        return instructions
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Rating en formato de estrellas (para mostrar en UI)
    var ratingStars: String {
        guard let rating = satisfactionRating else { return "" }
        let fullStars = String(repeating: "⭐", count: rating)
        let emptyStars = String(repeating: "☆", count: 5 - rating)
        return fullStars + emptyStars
    }
}

// MARK: - Supporting Types

enum MealStatus {
    case completed
    case available
    case locked

    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .available: return "circle"
        case .locked: return "lock.fill"
        }
    }

    var color: String {
        switch self {
        case .completed: return "green"
        case .available: return "blue"
        case .locked: return "gray"
        }
    }
}

// MARK: - Comparable for Sorting

extension Meal: Comparable {
    static func < (lhs: Meal, rhs: Meal) -> Bool {
        // Ordenar primero por tipo de comida, luego por order
        if lhs.mealType.order != rhs.mealType.order {
            return lhs.mealType.order < rhs.mealType.order
        }
        return lhs.orderInDay < rhs.orderInDay
    }
}

// MARK: - MacroSummary

struct MacroSummary: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int

    /// Porcentaje de calorias provenientes de proteina
    var proteinPercentage: Double {
        guard calories > 0 else { return 0 }
        return Double(protein * 4) / Double(calories) * 100
    }

    /// Porcentaje de calorias provenientes de carbohidratos
    var carbsPercentage: Double {
        guard calories > 0 else { return 0 }
        return Double(carbs * 4) / Double(calories) * 100
    }

    /// Porcentaje de calorias provenientes de grasa
    var fatPercentage: Double {
        guard calories > 0 else { return 0 }
        return Double(fat * 9) / Double(calories) * 100
    }

    /// Descripcion formateada de los macros
    var formattedDescription: String {
        return "\(calories) kcal | P: \(protein)g | C: \(carbs)g | G: \(fat)g"
    }

    /// Ratio de macronutrientes (% de calorias)
    var macroRatios: (protein: Double, carbs: Double, fat: Double) {
        let totalCalories = Double(calories)
        guard totalCalories > 0 else {
            return (0, 0, 0)
        }

        // 1g proteina = 4 kcal
        // 1g carbohidratos = 4 kcal
        // 1g grasa = 9 kcal
        let proteinCals = Double(protein) * 4
        let carbsCals = Double(carbs) * 4
        let fatCals = Double(fat) * 9

        return (
            protein: (proteinCals / totalCalories) * 100,
            carbs: (carbsCals / totalCalories) * 100,
            fat: (fatCals / totalCalories) * 100
        )
    }

    /// Indica si los macros estan balanceados (regla general 30-40-30)
    var isBalanced: Bool {
        let ratios = macroRatios
        // Proteina: 25-35%
        // Carbos: 35-45%
        // Grasa: 25-35%
        return ratios.protein >= 25 && ratios.protein <= 35 &&
               ratios.carbs >= 35 && ratios.carbs <= 45 &&
               ratios.fat >= 25 && ratios.fat <= 35
    }
}
