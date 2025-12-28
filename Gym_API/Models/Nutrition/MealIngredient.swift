import Foundation

// MARK: - MealIngredient Model

struct MealIngredient: Codable, Identifiable {
    let id: Int
    let mealId: Int
    let name: String
    let quantity: Double
    let unit: String
    let alternatives: String?
    let isOptional: Bool
    let caloriesPerServing: Double?
    let proteinPerServing: Double?
    let carbsPerServing: Double?
    let fatPerServing: Double?
    let orderInMeal: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case name
        case quantity
        case unit
        case alternatives
        case isOptional = "is_optional"
        case caloriesPerServing = "calories_per_serving"
        case proteinPerServing = "protein_per_serving"
        case carbsPerServing = "carbs_per_serving"
        case fatPerServing = "fat_per_serving"
        case orderInMeal = "order_in_meal"
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        mealId = try container.decode(Int.self, forKey: .mealId)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unit = try container.decode(String.self, forKey: .unit)
        isOptional = try container.decode(Bool.self, forKey: .isOptional)
        caloriesPerServing = try container.decodeIfPresent(Double.self, forKey: .caloriesPerServing)
        proteinPerServing = try container.decodeIfPresent(Double.self, forKey: .proteinPerServing)
        carbsPerServing = try container.decodeIfPresent(Double.self, forKey: .carbsPerServing)
        fatPerServing = try container.decodeIfPresent(Double.self, forKey: .fatPerServing)
        orderInMeal = try container.decodeIfPresent(Int.self, forKey: .orderInMeal)

        // Handle alternatives - puede ser string o array
        if let alternativesArray = try? container.decode([String].self, forKey: .alternatives) {
            // Si es un array, unir con comas
            alternatives = alternativesArray.joined(separator: ", ")
        } else if let alternativesString = try? container.decode(String.self, forKey: .alternatives) {
            alternatives = alternativesString
        } else {
            alternatives = nil
        }
    }

    // MARK: - Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(mealId, forKey: .mealId)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encodeIfPresent(alternatives, forKey: .alternatives)
        try container.encode(isOptional, forKey: .isOptional)
        try container.encodeIfPresent(caloriesPerServing, forKey: .caloriesPerServing)
        try container.encodeIfPresent(proteinPerServing, forKey: .proteinPerServing)
        try container.encodeIfPresent(carbsPerServing, forKey: .carbsPerServing)
        try container.encodeIfPresent(fatPerServing, forKey: .fatPerServing)
        try container.encodeIfPresent(orderInMeal, forKey: .orderInMeal)
    }
}

// MARK: - Helper Extensions

extension MealIngredient {
    /// Formatea la cantidad con su unidad
    var formattedQuantity: String {
        // Formatear la cantidad sin decimales innecesarios
        let formattedNumber: String
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            formattedNumber = String(format: "%.0f", quantity)
        } else {
            formattedNumber = String(format: "%.1f", quantity)
        }
        return "\(formattedNumber) \(unit)"
    }

    /// Indica si el ingrediente tiene informacion nutricional
    var hasNutritionalInfo: Bool {
        return caloriesPerServing != nil ||
               proteinPerServing != nil ||
               carbsPerServing != nil ||
               fatPerServing != nil
    }

    /// Lista de alternativas como array
    var alternativesList: [String] {
        guard let alternatives = alternatives, !alternatives.isEmpty else {
            return []
        }
        return alternatives
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Indica si tiene alternativas disponibles
    var hasAlternatives: Bool {
        return !alternativesList.isEmpty
    }

    /// Calorias totales basadas en la cantidad
    var totalCalories: Double? {
        guard let caloriesPerServing = caloriesPerServing else { return nil }
        return caloriesPerServing * quantity
    }

    /// Proteina total basada en la cantidad
    var totalProtein: Double? {
        guard let proteinPerServing = proteinPerServing else { return nil }
        return proteinPerServing * quantity
    }

    /// Carbohidratos totales basados en la cantidad
    var totalCarbs: Double? {
        guard let carbsPerServing = carbsPerServing else { return nil }
        return carbsPerServing * quantity
    }

    /// Grasa total basada en la cantidad
    var totalFat: Double? {
        guard let fatPerServing = fatPerServing else { return nil }
        return fatPerServing * quantity
    }
}

// MARK: - Comparable for Sorting

extension MealIngredient: Comparable {
    static func < (lhs: MealIngredient, rhs: MealIngredient) -> Bool {
        // Ordenar por orderInMeal, luego por nombre
        // Manejar valores opcionales: nil se considera mayor (va al final)
        switch (lhs.orderInMeal, rhs.orderInMeal) {
        case (let lOrder?, let rOrder?):
            if lOrder != rOrder {
                return lOrder < rOrder
            }
        case (nil, _?):
            return false // nil va después de cualquier valor
        case (_?, nil):
            return true // cualquier valor va antes de nil
        case (nil, nil):
            break // ambos nil, continuar con nombre
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
