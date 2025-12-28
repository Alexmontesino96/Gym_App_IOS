import Foundation

// MARK: - MealCompletion Model

struct MealCompletion: Codable, Identifiable {
    let id: Int
    let userId: Int
    let mealId: Int
    let completedAt: Date
    let satisfactionRating: Int // 1-5
    let photoUrl: String?
    let notes: String?
    let portionSizeModifier: Double? // 0.5 = 50%, 1.0 = 100%, 1.5 = 150%

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mealId = "meal_id"
        case completedAt = "completed_at"
        case satisfactionRating = "satisfaction_rating"
        case photoUrl = "photo_url"
        case notes
        case portionSizeModifier = "portion_size_modifier"
    }
}

// MARK: - Helper Extensions

extension MealCompletion {
    /// Rating en formato de estrellas
    var ratingStars: String {
        let fullStars = String(repeating: "star.fill", count: satisfactionRating)
        let emptyStars = String(repeating: "star", count: 5 - satisfactionRating)
        return fullStars + emptyStars
    }

    /// Descripcion del rating
    var ratingDescription: String {
        switch satisfactionRating {
        case 1: return "Muy insatisfecho"
        case 2: return "Insatisfecho"
        case 3: return "Neutral"
        case 4: return "Satisfecho"
        case 5: return "Muy satisfecho"
        default: return "Sin calificar"
        }
    }

    /// Indica si tiene foto adjunta
    var hasPhoto: Bool {
        return photoUrl != nil && !photoUrl!.isEmpty
    }

    /// Indica si tiene notas
    var hasNotes: Bool {
        return notes != nil && !notes!.isEmpty
    }

    /// Porcion modificada formateada
    var portionDescription: String {
        guard let modifier = portionSizeModifier else {
            return "Porcion completa"
        }
        let percentage = Int(modifier * 100)
        switch percentage {
        case 50: return "Media porcion"
        case 75: return "Tres cuartos"
        case 100: return "Porcion completa"
        case 125: return "Porcion extra"
        case 150: return "Porcion y media"
        default: return "\(percentage)% de la porcion"
        }
    }

    /// Hora formateada de completado
    var completedTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }

    /// Fecha formateada de completado
    var completedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: completedAt)
    }
}

// MARK: - MealCompletionRequest

struct MealCompletionRequest: Codable {
    let satisfactionRating: Int
    let photoUrl: String?
    let notes: String?
    let portionSizeModifier: Double?

    enum CodingKeys: String, CodingKey {
        case satisfactionRating = "satisfaction_rating"
        case photoUrl = "photo_url"
        case notes
        case portionSizeModifier = "portion_size_modifier"
    }

    init(
        satisfactionRating: Int,
        photoUrl: String? = nil,
        notes: String? = nil,
        portionSizeModifier: Double? = 1.0
    ) {
        self.satisfactionRating = min(max(satisfactionRating, 1), 5) // Clamp between 1-5
        self.photoUrl = photoUrl
        self.notes = notes
        self.portionSizeModifier = portionSizeModifier
    }
}

// MARK: - Comparable for Sorting

extension MealCompletion: Comparable {
    static func < (lhs: MealCompletion, rhs: MealCompletion) -> Bool {
        return lhs.completedAt < rhs.completedAt
    }
}
