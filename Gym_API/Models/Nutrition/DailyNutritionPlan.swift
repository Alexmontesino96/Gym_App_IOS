import Foundation

// MARK: - DailyNutritionPlan Model

struct DailyNutritionPlan: Codable, Identifiable {
    let id: Int
    let nutritionPlanId: Int
    let dayNumber: Int
    let totalCalories: Int
    let totalProteinG: Int?
    let totalCarbsG: Int?
    let totalFatG: Int?
    let totalFiberG: Int?
    let notes: String?
    let isPublished: Bool
    let meals: [Meal]

    enum CodingKeys: String, CodingKey {
        case id
        case nutritionPlanId = "nutrition_plan_id"
        case dayNumber = "day_number"
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"
        case notes
        case isPublished = "is_published"
        case meals
    }
}

// MARK: - Helper Extensions

extension DailyNutritionPlan {
    /// Total de macros del día
    var totalMacros: MacroSummary {
        return MacroSummary(
            calories: totalCalories,
            protein: totalProteinG ?? 0,
            carbs: totalCarbsG ?? 0,
            fat: totalFatG ?? 0,
            fiber: totalFiberG ?? 0
        )
    }

    /// Número de comidas en el día
    var mealCount: Int {
        return meals.count
    }

    /// Indica si el día tiene todas las comidas completadas (para un usuario)
    func isFullyCompleted() -> Bool {
        guard !meals.isEmpty else { return false }
        return meals.allSatisfy { $0.isCompleted }
    }

    /// Porcentaje de completado del día (0-100)
    func completionPercentage() -> Double {
        guard !meals.isEmpty else { return 0 }
        let completedCount = meals.filter { $0.isCompleted }.count
        return (Double(completedCount) / Double(meals.count)) * 100
    }

    /// Comidas por tipo de comida
    func meals(ofType type: MealType) -> [Meal] {
        return meals.filter { $0.mealType == type }
    }
}

// NOTE: MacroSummary is defined in Meal.swift
