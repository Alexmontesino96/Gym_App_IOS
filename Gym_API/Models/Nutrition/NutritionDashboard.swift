import Foundation

// MARK: - NutritionDashboard Model

struct NutritionDashboard: Codable {
    let templatePlans: [NutritionPlan]
    let livePlans: [NutritionPlan]
    let availablePlans: [NutritionPlan]
    let todayPlan: TodayMealPlan?
    let stats: UserNutritionStats?

    enum CodingKeys: String, CodingKey {
        case templatePlans = "template_plans"
        case livePlans = "live_plans"
        case availablePlans = "available_plans"
        case todayPlan = "today_plan"
        case stats
    }
}

// MARK: - TodayMealPlan Model

struct TodayMealPlan: Codable {
    let date: String
    let plan: NutritionPlan?
    let currentDay: Int
    let status: PlanStatus
    let daysUntilStart: Int?
    let meals: [Meal]
    let progress: DayProgress?

    enum CodingKeys: String, CodingKey {
        case date
        case plan
        case currentDay = "current_day"
        case status
        case daysUntilStart = "days_until_start"
        case meals
        case progress
    }
}

// MARK: - DayProgress Model

struct DayProgress: Codable {
    let mealsCompleted: Int
    let totalMeals: Int
    let percentage: Double
    let caloriesConsumed: Int
    let caloriesTarget: Int
    let proteinConsumed: Int
    let proteinTarget: Int
    let carbsConsumed: Int?
    let carbsTarget: Int?
    let fatConsumed: Int?
    let fatTarget: Int?

    enum CodingKeys: String, CodingKey {
        case mealsCompleted = "meals_completed"
        case totalMeals = "total_meals"
        case percentage
        case caloriesConsumed = "calories_consumed"
        case caloriesTarget = "calories_target"
        case proteinConsumed = "protein_consumed"
        case proteinTarget = "protein_target"
        case carbsConsumed = "carbs_consumed"
        case carbsTarget = "carbs_target"
        case fatConsumed = "fat_consumed"
        case fatTarget = "fat_target"
    }
}

// MARK: - UserNutritionStats Model

struct UserNutritionStats: Codable {
    let completionStreak: Int
    let weeklyAverage: Double
    let totalPlansFollowed: Int
    let totalMealsCompleted: Int
    let bestStreak: Int?
    let averageSatisfaction: Double?
    let totalPhotosUploaded: Int?

    enum CodingKeys: String, CodingKey {
        case completionStreak = "completion_streak"
        case weeklyAverage = "weekly_average"
        case totalPlansFollowed = "total_plans_followed"
        case totalMealsCompleted = "total_meals_completed"
        case bestStreak = "best_streak"
        case averageSatisfaction = "average_satisfaction"
        case totalPhotosUploaded = "total_photos_uploaded"
    }
}

// MARK: - Helper Extensions

extension NutritionDashboard {
    /// Indica si hay un plan LIVE activo actualmente
    var hasActiveLiveChallenge: Bool {
        return livePlans.contains { $0.status == .running }
    }

    /// Obtiene el plan LIVE activo actual
    var activeLiveChallenge: NutritionPlan? {
        return livePlans.first { $0.status == .running }
    }

    /// Planes LIVE proximos a empezar
    var upcomingLiveChallenges: [NutritionPlan] {
        return livePlans.filter { $0.status == .notStarted }
    }

    /// Indica si el usuario tiene un plan activo hoy
    var hasPlanToday: Bool {
        return todayPlan?.plan != nil
    }

    /// Total de planes disponibles para explorar
    var totalAvailablePlans: Int {
        return availablePlans.count
    }
}

extension TodayMealPlan {
    /// Indica si el dia ya esta completado
    var isDayCompleted: Bool {
        return (progress?.percentage ?? 0) >= 100
    }

    /// Comidas pendientes
    var pendingMeals: [Meal] {
        return meals.filter { !$0.isCompleted }
    }

    /// Comidas completadas
    var completedMeals: [Meal] {
        return meals.filter { $0.isCompleted }
    }

    /// Proxima comida a completar
    var nextMeal: Meal? {
        return pendingMeals.sorted().first
    }

    /// Indica si el plan aun no ha empezado
    var isPending: Bool {
        return status == .notStarted
    }

    /// Mensaje de estado para UI
    var statusMessage: String {
        switch status {
        case .notStarted:
            if let days = daysUntilStart {
                return "Empieza en \(days) dia\(days == 1 ? "" : "s")"
            }
            return "Proximo a empezar"
        case .running:
            if isDayCompleted {
                return "Dia completado"
            }
            return "\(pendingMeals.count) comida\(pendingMeals.count == 1 ? "" : "s") pendiente\(pendingMeals.count == 1 ? "" : "s")"
        case .finished:
            return "Plan completado"
        }
    }
}

extension DayProgress {
    /// Porcentaje de calorias consumidas
    var caloriesPercentage: Double {
        guard caloriesTarget > 0 else { return 0 }
        return Double(caloriesConsumed) / Double(caloriesTarget) * 100
    }

    /// Porcentaje de proteina consumida
    var proteinPercentage: Double {
        guard proteinTarget > 0 else { return 0 }
        return Double(proteinConsumed) / Double(proteinTarget) * 100
    }

    /// Calorias restantes
    var remainingCalories: Int {
        return max(0, caloriesTarget - caloriesConsumed)
    }

    /// Proteina restante
    var remainingProtein: Int {
        return max(0, proteinTarget - proteinConsumed)
    }

    /// Indica si se excedio el objetivo de calorias
    var isOverCalorieTarget: Bool {
        return caloriesConsumed > caloriesTarget
    }

    /// Formatea el progreso para UI
    var formattedProgress: String {
        return "\(mealsCompleted)/\(totalMeals) comidas"
    }
}

extension UserNutritionStats {
    /// Indica si el usuario es nuevo (sin actividad previa)
    var isNewUser: Bool {
        return totalMealsCompleted == 0 && totalPlansFollowed == 0
    }

    /// Mensaje motivacional basado en las estadisticas
    var motivationalMessage: String {
        if isNewUser {
            return "Comienza tu primer plan de nutricion"
        }

        if completionStreak >= 7 {
            return "Racha increible de \(completionStreak) dias"
        }

        if weeklyAverage >= 80 {
            return "Excelente consistencia esta semana"
        }

        if totalMealsCompleted > 50 {
            return "Mas de \(totalMealsCompleted) comidas completadas"
        }

        return "Sigue asi, cada comida cuenta"
    }

    /// Nivel del usuario basado en estadisticas
    var userLevel: NutritionUserLevel {
        switch totalMealsCompleted {
        case 0..<10: return .beginner
        case 10..<50: return .intermediate
        case 50..<200: return .advanced
        default: return .expert
        }
    }
}

// MARK: - Supporting Types

enum NutritionUserLevel: String {
    case beginner
    case intermediate
    case advanced
    case expert

    var displayName: String {
        switch self {
        case .beginner: return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced: return "Avanzado"
        case .expert: return "Experto"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "leaf"
        case .intermediate: return "leaf.fill"
        case .advanced: return "star"
        case .expert: return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .expert: return "purple"
        }
    }
}
