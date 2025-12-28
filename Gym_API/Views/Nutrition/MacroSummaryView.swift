import SwiftUI

// MARK: - MacroSummaryView

/// Vista que muestra el resumen de macros consumidos vs objetivo
/// Incluye calorias, proteina, carbohidratos y grasa
struct MacroSummaryView: View {
    // MARK: - Properties

    let progress: DayProgress
    let showAllMacros: Bool
    let style: MacroSummaryStyle

    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Initialization

    init(
        progress: DayProgress,
        showAllMacros: Bool = false,
        style: MacroSummaryStyle = .compact
    ) {
        self.progress = progress
        self.showAllMacros = showAllMacros
        self.style = style
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .compact:
            compactLayout
        case .detailed:
            detailedLayout
        case .pills:
            pillsLayout
        }
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        HStack(spacing: 16) {
            MacroCircleIndicator(
                icon: "flame.fill",
                current: progress.caloriesConsumed,
                target: progress.caloriesTarget,
                unit: "kcal",
                color: .orange
            )
            .environmentObject(themeManager)

            MacroCircleIndicator(
                icon: "leaf.fill",
                current: progress.proteinConsumed,
                target: progress.proteinTarget,
                unit: "g",
                color: .green
            )
            .environmentObject(themeManager)

            if showAllMacros {
                if let carbsConsumed = progress.carbsConsumed,
                   let carbsTarget = progress.carbsTarget {
                    MacroCircleIndicator(
                        icon: "bolt.fill",
                        current: carbsConsumed,
                        target: carbsTarget,
                        unit: "g",
                        color: .blue
                    )
                    .environmentObject(themeManager)
                }

                if let fatConsumed = progress.fatConsumed,
                   let fatTarget = progress.fatTarget {
                    MacroCircleIndicator(
                        icon: "drop.fill",
                        current: fatConsumed,
                        target: fatTarget,
                        unit: "g",
                        color: .yellow
                    )
                    .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Detailed Layout

    private var detailedLayout: some View {
        VStack(spacing: 16) {
            // Calories - main indicator
            MacroDetailedRow(
                icon: "flame.fill",
                name: "Calorias",
                current: progress.caloriesConsumed,
                target: progress.caloriesTarget,
                unit: "kcal",
                color: .orange
            )
            .environmentObject(themeManager)

            Divider()
                .background(Color.dynamicBorder(theme: themeManager.currentTheme))

            // Protein
            MacroDetailedRow(
                icon: "leaf.fill",
                name: "Proteina",
                current: progress.proteinConsumed,
                target: progress.proteinTarget,
                unit: "g",
                color: .green
            )
            .environmentObject(themeManager)

            // Carbs (if available)
            if let carbsConsumed = progress.carbsConsumed,
               let carbsTarget = progress.carbsTarget {
                MacroDetailedRow(
                    icon: "bolt.fill",
                    name: "Carbohidratos",
                    current: carbsConsumed,
                    target: carbsTarget,
                    unit: "g",
                    color: .blue
                )
                .environmentObject(themeManager)
            }

            // Fat (if available)
            if let fatConsumed = progress.fatConsumed,
               let fatTarget = progress.fatTarget {
                MacroDetailedRow(
                    icon: "drop.fill",
                    name: "Grasa",
                    current: fatConsumed,
                    target: fatTarget,
                    unit: "g",
                    color: .yellow
                )
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Pills Layout

    private var pillsLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MacroPill(
                    icon: "flame.fill",
                    value: progress.caloriesConsumed,
                    target: progress.caloriesTarget,
                    unit: "kcal",
                    color: .orange
                )
                .environmentObject(themeManager)

                MacroPill(
                    icon: "leaf.fill",
                    value: progress.proteinConsumed,
                    target: progress.proteinTarget,
                    unit: "g prot",
                    color: .green
                )
                .environmentObject(themeManager)

                if let carbsConsumed = progress.carbsConsumed,
                   let carbsTarget = progress.carbsTarget {
                    MacroPill(
                        icon: "bolt.fill",
                        value: carbsConsumed,
                        target: carbsTarget,
                        unit: "g carbs",
                        color: .blue
                    )
                    .environmentObject(themeManager)
                }

                if let fatConsumed = progress.fatConsumed,
                   let fatTarget = progress.fatTarget {
                    MacroPill(
                        icon: "drop.fill",
                        value: fatConsumed,
                        target: fatTarget,
                        unit: "g grasa",
                        color: .yellow
                    )
                    .environmentObject(themeManager)
                }
            }
        }
    }
}

// MARK: - MacroSummaryStyle

enum MacroSummaryStyle {
    case compact
    case detailed
    case pills
}

// MARK: - MacroCircleIndicator

/// Indicador circular de un macro con icono y valores
struct MacroCircleIndicator: View {
    let icon: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    private var percentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    private var isOverTarget: Bool {
        return current > target
    }

    var body: some View {
        VStack(spacing: 8) {
            // Circular progress with icon
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 4)
                    .frame(width: 48, height: 48)

                // Progress arc
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(
                        isOverTarget ? Color.red : color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: percentage)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isOverTarget ? .red : color)
            }

            // Values
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("/\(target) \(unit)")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MacroDetailedRow

/// Fila detallada de un macro con barra de progreso
struct MacroDetailedRow: View {
    let icon: String
    let name: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    private var percentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    private var isOverTarget: Bool {
        return current > target
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Icon and name
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)

                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                // Values
                HStack(spacing: 4) {
                    Text("\(current)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isOverTarget ? .red : Color.dynamicText(theme: themeManager.currentTheme))

                    Text("/ \(target) \(unit)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverTarget ? Color.red : color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: percentage)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - MacroPill

/// Pill compacta para mostrar un macro
struct MacroPill: View {
    let icon: String
    let value: Int
    let target: Int
    let unit: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    private var isOverTarget: Bool {
        return value > target
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isOverTarget ? .red : color)

            Text("\(value)/\(target)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isOverTarget ? .red : Color.dynamicText(theme: themeManager.currentTheme))

            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - MealMacrosPills

/// Pills de macros para una comida individual
struct MealMacrosPills: View {
    let meal: Meal

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Calories
                SingleMacroPill(
                    icon: "flame.fill",
                    value: "\(meal.calories)",
                    unit: "kcal",
                    color: .orange
                )
                .environmentObject(themeManager)

                // Protein
                if let protein = meal.proteinG {
                    SingleMacroPill(
                        icon: "leaf.fill",
                        value: "\(protein)",
                        unit: "g prot",
                        color: .green
                    )
                    .environmentObject(themeManager)
                }

                // Carbs
                if let carbs = meal.carbsG {
                    SingleMacroPill(
                        icon: "bolt.fill",
                        value: "\(carbs)",
                        unit: "g carbs",
                        color: .blue
                    )
                    .environmentObject(themeManager)
                }

                // Fat
                if let fat = meal.fatG {
                    SingleMacroPill(
                        icon: "drop.fill",
                        value: "\(fat)",
                        unit: "g grasa",
                        color: .yellow
                    )
                    .environmentObject(themeManager)
                }

                // Fiber
                if let fiber = meal.fiberG {
                    SingleMacroPill(
                        icon: "leaf.circle",
                        value: "\(fiber)",
                        unit: "g fibra",
                        color: .brown
                    )
                    .environmentObject(themeManager)
                }
            }
        }
    }
}

// MARK: - SingleMacroPill

/// Pill individual para un macro
struct SingleMacroPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            // Sample progress data
            let sampleProgress = DayProgress(
                mealsCompleted: 3,
                totalMeals: 5,
                percentage: 60,
                caloriesConsumed: 1450,
                caloriesTarget: 2000,
                proteinConsumed: 85,
                proteinTarget: 120,
                carbsConsumed: 180,
                carbsTarget: 250,
                fatConsumed: 55,
                fatTarget: 70
            )

            VStack(spacing: 16) {
                Text("Compact Style")
                    .font(.headline)
                    .foregroundColor(.white)

                MacroSummaryView(progress: sampleProgress, style: .compact)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
            }

            VStack(spacing: 16) {
                Text("Detailed Style")
                    .font(.headline)
                    .foregroundColor(.white)

                MacroSummaryView(progress: sampleProgress, showAllMacros: true, style: .detailed)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
            }

            VStack(spacing: 16) {
                Text("Pills Style")
                    .font(.headline)
                    .foregroundColor(.white)

                MacroSummaryView(progress: sampleProgress, style: .pills)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
            }
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
