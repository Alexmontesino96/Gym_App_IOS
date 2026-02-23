import Foundation

// MARK: - NutritionDashboard Model

struct NutritionDashboard: Codable {
    // Existing fields
    let templatePlans: [NutritionPlan]?
    let livePlans: [NutritionPlan]?
    let availablePlans: [NutritionPlan]?
    let todayPlan: TodayMealPlan?
    let stats: UserNutritionStats?

    // New API fields
    let userId: Int?
    let activePlans: [ActivePlan]?
    let weeklySummary: NutritionSummary?
    let monthlySummary: NutritionSummary?
    let currentStreak: Int?
    let longestStreak: Int?
    let totalMealsCompleted: Int?
    let favoriteMeals: [FavoriteMeal]?
    let nutritionalGoalsProgress: NutritionalGoalsProgress?

    enum CodingKeys: String, CodingKey {
        case templatePlans = "template_plans"
        case livePlans = "live_plans"
        case availablePlans = "available_plans"
        case todayPlan = "today_plan"
        case stats
        case userId = "user_id"
        case activePlans = "active_plans"
        case weeklySummary = "weekly_summary"
        case monthlySummary = "monthly_summary"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case totalMealsCompleted = "total_meals_completed"
        case favoriteMeals = "favorite_meals"
        case nutritionalGoalsProgress = "nutritional_goals_progress"
    }
}

// MARK: - ActivePlan Model

/// Plan activo que el usuario esta siguiendo
struct ActivePlan: Codable, Identifiable {
    let planId: Int
    let planName: String
    let startDate: Date
    let currentDay: Int
    let adherencePercentage: Double

    var id: Int { planId }

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case planName = "plan_name"
        case startDate = "start_date"
        case currentDay = "current_day"
        case adherencePercentage = "adherence_percentage"
    }
}

// MARK: - NutritionSummary Model

struct NutritionSummary: Codable {
    let averageAdherence: Double?
    let mealsCompleted: Int?
    let totalMeals: Int?
    let caloriesAverage: Int?
    let proteinAverage: Int?

    enum CodingKeys: String, CodingKey {
        case averageAdherence = "average_adherence"
        case mealsCompleted = "meals_completed"
        case totalMeals = "total_meals"
        case caloriesAverage = "calories_average"
        case proteinAverage = "protein_average"
    }
}

// MARK: - FavoriteMeal Model

struct FavoriteMeal: Codable, Identifiable {
    let mealId: Int
    let mealName: String
    let timesCompleted: Int?

    var id: Int { mealId }

    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case mealName = "meal_name"
        case timesCompleted = "times_completed"
    }
}

// MARK: - NutritionalGoalsProgress Model

struct NutritionalGoalsProgress: Codable {
    let caloriesProgress: Double?
    let proteinProgress: Double?
    let carbsProgress: Double?
    let fatProgress: Double?

    enum CodingKeys: String, CodingKey {
        case caloriesProgress = "calories_progress"
        case proteinProgress = "protein_progress"
        case carbsProgress = "carbs_progress"
        case fatProgress = "fat_progress"
    }
}

// MARK: - MealTypeCompletion Model

/// Estadísticas de completitud por tipo de comida en un plan LIVE
struct MealTypeCompletion: Codable {
    let mealType: String
    let totalUsersWithMeal: Int
    let usersCompleted: Int
    let completionRate: Double

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case totalUsersWithMeal = "total_users_with_meal"
        case usersCompleted = "users_completed"
        case completionRate = "completion_rate"
    }
}

// MARK: - GroupCompletionStats Model

/// Estadísticas de grupo para planes LIVE - muestra como le va al gym completo
struct GroupCompletionStats: Codable {
    let totalParticipants: Int
    let activeToday: Int
    let completedDayFully: Int
    let avgCompletionPercentage: Double
    let mealCompletions: [MealTypeCompletion]
    let currentDay: Int
    let planId: Int
    let date: String

    enum CodingKeys: String, CodingKey {
        case totalParticipants = "total_participants"
        case activeToday = "active_today"
        case completedDayFully = "completed_day_fully"
        case avgCompletionPercentage = "avg_completion_percentage"
        case mealCompletions = "meal_completions"
        case currentDay = "current_day"
        case planId = "plan_id"
        case date
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
    let groupStats: GroupCompletionStats?

    enum CodingKeys: String, CodingKey {
        case date
        case plan
        case currentDay = "current_day"
        case status
        case daysUntilStart = "days_until_start"
        case meals
        case progress
        case groupStats = "group_stats"
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
        return livePlans?.contains { $0.status == .running } ?? false
    }

    /// Obtiene el plan LIVE activo actual
    var activeLiveChallenge: NutritionPlan? {
        return livePlans?.first { $0.status == .running }
    }

    /// Planes LIVE proximos a empezar
    var upcomingLiveChallenges: [NutritionPlan] {
        return livePlans?.filter { $0.status == .notStarted } ?? []
    }

    /// Indica si el usuario tiene un plan activo hoy
    var hasPlanToday: Bool {
        return todayPlan?.plan != nil
    }

    /// Total de planes disponibles para explorar
    var totalAvailablePlans: Int {
        return availablePlans?.count ?? 0
    }

    /// Indica si el usuario tiene planes activos
    var hasActivePlans: Bool {
        return (activePlans?.isEmpty == false)
    }

    /// Número de planes activos
    var activePlansCount: Int {
        return activePlans?.count ?? 0
    }

    /// Porcentaje de adherencia promedio
    var averageAdherence: Double {
        guard let plans = activePlans, !plans.isEmpty else { return 0 }
        return plans.map { $0.adherencePercentage }.reduce(0, +) / Double(plans.count)
    }
}

extension ActivePlan {
    /// Días desde que inició el plan
    var daysSinceStart: Int {
        return Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }

    /// Texto de adherencia formateado
    var formattedAdherence: String {
        return String(format: "%.0f%%", adherencePercentage * 100)
    }

    /// Indica si la adherencia es buena (>= 70%)
    var hasGoodAdherence: Bool {
        return adherencePercentage >= 0.7
    }

    /// Color basado en adherencia
    var adherenceColorName: String {
        switch adherencePercentage {
        case 0.8...: return "green"
        case 0.5..<0.8: return "orange"
        default: return "red"
        }
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

    /// Indica si es un plan LIVE con estadisticas de grupo
    var isLivePlanWithGroupStats: Bool {
        return plan?.planType == .live && groupStats != nil
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

// MARK: - GroupCompletionStats Extensions

extension GroupCompletionStats {
    /// Porcentaje de usuarios activos hoy
    var activeUsersPercentage: Double {
        guard totalParticipants > 0 else { return 0 }
        return (Double(activeToday) / Double(totalParticipants)) * 100
    }

    /// Porcentaje de usuarios que completaron el día
    var completedDayPercentage: Double {
        guard totalParticipants > 0 else { return 0 }
        return (Double(completedDayFully) / Double(totalParticipants)) * 100
    }

    /// Porcentaje formateado de adherencia promedio
    var formattedAvgCompletion: String {
        return String(format: "%.1f%%", avgCompletionPercentage)
    }

    /// Mensaje motivacional basado en las estadísticas del grupo
    var motivationalMessage: String {
        if avgCompletionPercentage >= 80 {
            return "¡El gym está en fuego! 🔥"
        } else if avgCompletionPercentage >= 60 {
            return "Buen ritmo de grupo 💪"
        } else if avgCompletionPercentage >= 40 {
            return "Vamos juntos 🤝"
        } else {
            return "Empieza el desafío 🚀"
        }
    }

    /// Nivel de energía del grupo basado en adherencia
    var groupEnergyLevel: GroupEnergyLevel {
        switch avgCompletionPercentage {
        case 80...: return .high
        case 50..<80: return .medium
        default: return .low
        }
    }

    /// Obtiene la comida con mejor adherencia
    var bestPerformingMealType: MealTypeCompletion? {
        return mealCompletions.max(by: { $0.completionRate < $1.completionRate })
    }

    /// Obtiene la comida con peor adherencia
    var lowestPerformingMealType: MealTypeCompletion? {
        return mealCompletions.min(by: { $0.completionRate < $1.completionRate })
    }
}

// MARK: - MealTypeCompletion Extensions

extension MealTypeCompletion {
    /// Porcentaje formateado de completitud
    var formattedCompletionRate: String {
        return String(format: "%.1f%%", completionRate)
    }

    /// Nombre legible del tipo de comida
    var displayName: String {
        switch mealType.lowercased() {
        case "breakfast": return "Desayuno"
        case "lunch": return "Almuerzo"
        case "dinner": return "Cena"
        case "snack": return "Snack"
        case "pre_workout": return "Pre-Entreno"
        case "post_workout": return "Post-Entreno"
        default: return mealType.capitalized
        }
    }

    /// Emoji para el tipo de comida
    var emoji: String {
        switch mealType.lowercased() {
        case "breakfast": return "🌅"
        case "lunch": return "🍽️"
        case "dinner": return "🌙"
        case "snack": return "🍎"
        case "pre_workout": return "⚡"
        case "post_workout": return "💪"
        default: return "🍴"
        }
    }

    /// Color para mostrar en UI basado en adherencia
    var statusColor: String {
        switch completionRate {
        case 80...: return "green"
        case 50..<80: return "orange"
        default: return "red"
        }
    }
}

// MARK: - Supporting Types for Group Stats

enum GroupEnergyLevel {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: return "Alta"
        case .medium: return "Media"
        case .low: return "Baja"
        }
    }

    var emoji: String {
        switch self {
        case .high: return "🔥"
        case .medium: return "💪"
        case .low: return "🌱"
        }
    }

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "gray"
        }
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
