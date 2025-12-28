import SwiftUI

// MARK: - MealCard

/// Tarjeta para mostrar una comida individual
/// Incluye imagen, info nutricional y estado de completado
struct MealCard: View {
    // MARK: - Properties

    let meal: Meal
    let onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Initialization

    init(meal: Meal, onTap: (() -> Void)? = nil) {
        self.meal = meal
        self.onTap = onTap
    }

    // MARK: - Body

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Meal Image/Icon
                mealImageView

                // Meal Info
                VStack(alignment: .leading, spacing: 4) {
                    mealTypeHeader

                    mealTitle

                    macrosRow
                }

                Spacer()

                // Status Indicator
                statusIndicator
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: meal.isCompleted ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Private Views

    @ViewBuilder
    private var mealImageView: some View {
        if let imageUrl = meal.imageUrl, !imageUrl.isEmpty {
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    mealIconPlaceholder
                @unknown default:
                    mealIconPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            mealIconPlaceholder
        }
    }

    private var mealIconPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(mealTypeColor.opacity(0.15))

            Image(systemName: meal.mealType.icon)
                .font(.system(size: 24))
                .foregroundColor(mealTypeColor)
        }
        .frame(width: 60, height: 60)
    }

    private var mealTypeHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: meal.mealType.icon)
                .font(.system(size: 10))
                .foregroundColor(mealTypeColor)

            Text(meal.mealType.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(mealTypeColor)

            if let time = meal.mealType.typicalTime.split(separator: " ").first {
                Text("- \(time)")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }

    private var mealTitle: some View {
        Text(meal.name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .lineLimit(1)
    }

    private var macrosRow: some View {
        HStack(spacing: 12) {
            MacroLabel(icon: "flame.fill", value: "\(meal.calories)", color: .orange)

            if let protein = meal.proteinG {
                MacroLabel(icon: "leaf.fill", value: "\(protein)g", color: .green)
            }

            if let prepTime = meal.preparationTimeFormatted {
                MacroLabel(icon: "clock", value: prepTime, color: .blue)
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if meal.isCompleted {
            completedIndicator
        } else {
            pendingIndicator
        }
    }

    private var completedIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)

            if let rating = meal.satisfactionRating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }

    private var pendingIndicator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
    }

    // MARK: - Styling

    private var cardBackground: Color {
        if meal.isCompleted {
            return Color.green.opacity(0.05)
        }
        return Color.dynamicSurface(theme: themeManager.currentTheme)
    }

    private var borderColor: Color {
        return Color.green.opacity(0.3)
    }

    private var mealTypeColor: Color {
        switch meal.mealType {
        case .breakfast: return .orange
        case .midMorning: return .yellow
        case .lunch: return .green
        case .afternoon: return .blue
        case .dinner: return .purple
        case .postWorkout: return .red
        case .lateSnack: return .indigo
        }
    }
}

// MARK: - MacroLabel

/// Etiqueta para mostrar un valor de macro con icono
struct MacroLabel: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(color.opacity(0.8))
    }
}

// MARK: - CompactMealCard

/// Version compacta de MealCard para listas
struct CompactMealCard: View {
    let meal: Meal
    let onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    init(meal: Meal, onTap: (() -> Void)? = nil) {
        self.meal = meal
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(meal.isCompleted ? Color.green : Color.dynamicSurface(theme: themeManager.currentTheme))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Group {
                            if meal.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                meal.isCompleted ? Color.green : Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3),
                                lineWidth: 2
                            )
                    )

                // Meal info
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.mealType.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Text(meal.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                }

                Spacer()

                // Calories
                Text("\(meal.calories) kcal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                // Chevron
                if !meal.isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - MealListSection

/// Seccion de lista de comidas con header
struct MealListSection: View {
    let title: String
    let meals: [Meal]
    let onMealTap: ((Meal) -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    init(title: String = "Comidas del Dia", meals: [Meal], onMealTap: ((Meal) -> Void)? = nil) {
        self.title = title
        self.meals = meals
        self.onMealTap = onMealTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text("\(completedCount)/\(meals.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Meals list
            ForEach(meals.sorted()) { meal in
                MealCard(meal: meal) {
                    onMealTap?(meal)
                }
                .environmentObject(themeManager)
            }
        }
    }

    private var completedCount: Int {
        return meals.filter { $0.isCompleted }.count
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Meal Cards")
                .font(.headline)
                .foregroundColor(.white)

            // Sample meals would be shown here
            // In real usage, these would come from the API

            Text("Las tarjetas de comida se mostraran aqui con datos reales del API")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
