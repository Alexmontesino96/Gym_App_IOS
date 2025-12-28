import SwiftUI

// MARK: - IngredientChecklistView

/// Vista de lista de ingredientes con checkboxes para seguimiento de preparacion
/// Permite marcar ingredientes como "listos" durante la preparacion
struct IngredientChecklistView: View {
    // MARK: - Properties

    let ingredients: [MealIngredient]
    let isInteractive: Bool

    @EnvironmentObject var themeManager: ThemeManager
    @State private var checkedIngredients: Set<Int> = []
    @State private var expandedAlternatives: Set<Int> = []

    // MARK: - Initialization

    init(ingredients: [MealIngredient], isInteractive: Bool = true) {
        self.ingredients = ingredients
        self.isInteractive = isInteractive
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ingredients.sorted()) { ingredient in
                VStack(spacing: 0) {
                    ingredientRow(ingredient)

                    // Alternatives section (expandable)
                    if ingredient.hasAlternatives && expandedAlternatives.contains(ingredient.id) {
                        alternativesSection(for: ingredient)
                    }

                    // Divider
                    if ingredient.id != ingredients.sorted().last?.id {
                        Divider()
                            .background(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.5))
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Ingredient Row

    private func ingredientRow(_ ingredient: MealIngredient) -> some View {
        HStack(spacing: 14) {
            // Checkbox
            if isInteractive {
                Button(action: {
                    toggleIngredient(ingredient.id)
                }) {
                    checkboxIcon(isChecked: checkedIngredients.contains(ingredient.id))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 24)
            }

            // Ingredient info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ingredient.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(
                            checkedIngredients.contains(ingredient.id)
                                ? Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                                : Color.dynamicText(theme: themeManager.currentTheme)
                        )
                        .strikethrough(checkedIngredients.contains(ingredient.id))

                    if ingredient.isOptional {
                        Text("(opcional)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                    }
                }

                // Quantity
                Text(ingredient.formattedQuantity)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()

            // Alternatives toggle button
            if ingredient.hasAlternatives {
                Button(action: {
                    toggleAlternatives(ingredient.id)
                }) {
                    HStack(spacing: 4) {
                        Text("Alt")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: expandedAlternatives.contains(ingredient.id) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Nutritional info indicator
            if ingredient.hasNutritionalInfo {
                nutritionalBadge(ingredient)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if isInteractive {
                toggleIngredient(ingredient.id)
            }
        }
    }

    // MARK: - Checkbox Icon

    private func checkboxIcon(isChecked: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(
                    isChecked
                        ? Color.green
                        : Color.dynamicBorder(theme: themeManager.currentTheme),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if isChecked {
                Circle()
                    .fill(Color.green)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChecked)
    }

    // MARK: - Alternatives Section

    private func alternativesSection(for ingredient: MealIngredient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alternativas:")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            ForEach(ingredient.alternativesList, id: \.self) { alternative in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10))
                        .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))

                    Text(alternative)
                        .font(.system(size: 13))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(.horizontal, 54)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.5))
    }

    // MARK: - Nutritional Badge

    private func nutritionalBadge(_ ingredient: MealIngredient) -> some View {
        HStack(spacing: 2) {
            if let calories = ingredient.totalCalories {
                Text("\(Int(calories))")
                    .font(.system(size: 10, weight: .medium))
                Image(systemName: "flame.fill")
                    .font(.system(size: 8))
            }
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Actions

    private func toggleIngredient(_ id: Int) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if checkedIngredients.contains(id) {
                checkedIngredients.remove(id)
            } else {
                checkedIngredients.insert(id)
            }
        }
    }

    private func toggleAlternatives(_ id: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if expandedAlternatives.contains(id) {
                expandedAlternatives.remove(id)
            } else {
                expandedAlternatives.insert(id)
            }
        }
    }
}

// MARK: - CompactIngredientList

/// Lista compacta de ingredientes sin checkboxes
struct CompactIngredientList: View {
    let ingredients: [MealIngredient]
    let maxDisplay: Int

    @EnvironmentObject var themeManager: ThemeManager
    @State private var showAll = false

    init(ingredients: [MealIngredient], maxDisplay: Int = 4) {
        self.ingredients = ingredients
        self.maxDisplay = maxDisplay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(displayedIngredients) { ingredient in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 6, height: 6)

                    Text(ingredient.name)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Spacer()

                    Text(ingredient.formattedQuantity)
                        .font(.system(size: 13))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }

            if ingredients.count > maxDisplay {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showAll.toggle()
                    }
                }) {
                    HStack {
                        Text(showAll ? "Ver menos" : "Ver \(ingredients.count - maxDisplay) mas")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: showAll ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .padding(.top, 4)
            }
        }
    }

    private var displayedIngredients: [MealIngredient] {
        if showAll {
            return ingredients.sorted()
        }
        return Array(ingredients.sorted().prefix(maxDisplay))
    }
}

// MARK: - IngredientSummaryRow

/// Fila de resumen de ingredientes (para vista previa)
struct IngredientSummaryRow: View {
    let ingredients: [MealIngredient]

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

            Text("\(ingredients.count) ingredientes")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()

            // Count optional
            let optionalCount = ingredients.filter { $0.isOptional }.count
            if optionalCount > 0 {
                Text("\(optionalCount) opcionales")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("Ingredient Checklist")
                .font(.headline)
                .foregroundColor(.white)

            // Note: Preview would show empty state since we need real data
            Text("La lista de ingredientes se mostrara aqui con datos reales del API")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
