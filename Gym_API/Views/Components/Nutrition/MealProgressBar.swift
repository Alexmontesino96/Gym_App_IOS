import SwiftUI

// MARK: - MealProgressBar

/// Barra de progreso para mostrar comidas completadas
/// Incluye texto de progreso y animacion suave
struct MealProgressBar: View {
    // MARK: - Properties

    let mealsCompleted: Int
    let totalMeals: Int
    let height: CGFloat
    let showText: Bool

    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Computed Properties

    private var percentage: Double {
        guard totalMeals > 0 else { return 0 }
        return min(Double(mealsCompleted) / Double(totalMeals), 1.0)
    }

    private var percentageInt: Int {
        return Int(percentage * 100)
    }

    // MARK: - Initialization

    init(
        mealsCompleted: Int,
        totalMeals: Int,
        height: CGFloat = 8,
        showText: Bool = true
    ) {
        self.mealsCompleted = mealsCompleted
        self.totalMeals = totalMeals
        self.height = height
        self.showText = showText
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showText {
                progressTextRow
            }

            progressBar
        }
    }

    // MARK: - Private Views

    private var progressTextRow: some View {
        HStack {
            Text("\(mealsCompleted) de \(totalMeals) comidas")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()

            Text("\(percentageInt)%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(progressColor)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .frame(height: height)

                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(progressGradient)
                    .frame(width: geometry.size.width * percentage, height: height)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentage)
            }
        }
        .frame(height: height)
    }

    // MARK: - Styling

    private var progressColor: Color {
        if percentage >= 1.0 {
            return .green
        } else if percentage >= 0.5 {
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        } else {
            return .orange
        }
    }

    private var progressGradient: LinearGradient {
        if percentage >= 1.0 {
            return LinearGradient(
                colors: [.green, .green.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.dynamicAccent(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - MacroProgressBar

/// Barra de progreso para macronutrientes individuales
struct MacroProgressBar: View {
    let current: Int
    let target: Int
    let color: Color
    let height: CGFloat

    @EnvironmentObject var themeManager: ThemeManager

    private var percentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.5) // Permite hasta 150%
    }

    private var isOverTarget: Bool {
        return current > target
    }

    init(
        current: Int,
        target: Int,
        color: Color = .orange,
        height: CGFloat = 6
    ) {
        self.current = current
        self.target = target
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .frame(height: height)

                // Target marker (100% line)
                if percentage > 1.0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: height + 4)
                        .offset(x: geometry.size.width - 1)
                }

                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(isOverTarget ? Color.red : color)
                    .frame(width: geometry.size.width * min(percentage, 1.0), height: height)
                    .animation(.spring(response: 0.5), value: percentage)
            }
        }
        .frame(height: height)
    }
}

// MARK: - CircularProgressRing

/// Anillo de progreso circular para estadisticas
struct CircularProgressRing: View {
    let progress: Double // 0.0 - 1.0
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        size: CGFloat = 60,
        color: Color = .red
    ) {
        self.progress = min(max(progress, 0), 1.0)
        self.lineWidth = lineWidth
        self.size = size
        self.color = color
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Color.dynamicSurface(theme: themeManager.currentTheme),
                    lineWidth: lineWidth
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - DayProgressSummary

/// Resumen visual del progreso del dia con multiples indicadores
struct DayProgressSummary: View {
    let progress: DayProgress

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Meal progress bar
            MealProgressBar(
                mealsCompleted: progress.mealsCompleted,
                totalMeals: progress.totalMeals
            )
            .environmentObject(themeManager)

            // Macro summary row
            HStack(spacing: 16) {
                MacroIndicator(
                    icon: "flame.fill",
                    current: progress.caloriesConsumed,
                    target: progress.caloriesTarget,
                    unit: "kcal",
                    color: .orange
                )

                MacroIndicator(
                    icon: "leaf.fill",
                    current: progress.proteinConsumed,
                    target: progress.proteinTarget,
                    unit: "g",
                    color: .green
                )

                if let carbsConsumed = progress.carbsConsumed,
                   let carbsTarget = progress.carbsTarget {
                    MacroIndicator(
                        icon: "bolt.fill",
                        current: carbsConsumed,
                        target: carbsTarget,
                        unit: "g",
                        color: .blue
                    )
                }
            }
        }
    }
}

// MARK: - MacroIndicator

/// Indicador individual de macro con icono y valores
struct MacroIndicator: View {
    let icon: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    private var percentage: Double {
        guard target > 0 else { return 0 }
        return Double(current) / Double(target)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Icon with circular progress
            ZStack {
                CircularProgressRing(
                    progress: min(percentage, 1.0),
                    lineWidth: 4,
                    size: 44,
                    color: color
                )
                .environmentObject(themeManager)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            // Values
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("/\(target)\(unit)")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            // Meal Progress Bar
            VStack(spacing: 16) {
                Text("Meal Progress Bars")
                    .font(.headline)
                    .foregroundColor(.white)

                MealProgressBar(mealsCompleted: 2, totalMeals: 5)
                MealProgressBar(mealsCompleted: 5, totalMeals: 5)
                MealProgressBar(mealsCompleted: 0, totalMeals: 4)
                MealProgressBar(mealsCompleted: 3, totalMeals: 6, showText: false)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            // Macro Progress Bars
            VStack(spacing: 16) {
                Text("Macro Progress Bars")
                    .font(.headline)
                    .foregroundColor(.white)

                MacroProgressBar(current: 1200, target: 2000, color: .orange)
                MacroProgressBar(current: 80, target: 100, color: .green)
                MacroProgressBar(current: 250, target: 200, color: .blue) // Over target
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            // Circular Progress
            VStack(spacing: 16) {
                Text("Circular Progress")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    CircularProgressRing(progress: 0.3, color: .orange)
                    CircularProgressRing(progress: 0.7, color: .green)
                    CircularProgressRing(progress: 1.0, color: .blue)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            // Macro Indicators
            VStack(spacing: 16) {
                Text("Macro Indicators")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    MacroIndicator(icon: "flame.fill", current: 1500, target: 2000, unit: "kcal", color: .orange)
                    MacroIndicator(icon: "leaf.fill", current: 90, target: 120, unit: "g", color: .green)
                    MacroIndicator(icon: "bolt.fill", current: 200, target: 250, unit: "g", color: .blue)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
