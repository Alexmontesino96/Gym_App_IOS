import SwiftUI

struct WeeklyCheckInCard: View {
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("homeCheckInExpanded") private var isExpanded = false
    @State private var rotationAngle: Double = 180

    var body: some View {
        VStack(spacing: 12) {
            // Header con chevron
            headerSection

            if isExpanded {
                // Grid 2x2 con animación
                gridContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            } else {
                // Versión colapsada compacta
                collapsedContent
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
                rotationAngle = isExpanded ? 0 : 180
            }
        }) {
            HStack {
                Text(headerTitle)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .rotationEffect(.degrees(rotationAngle))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Grid Content

    private var gridContent: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            // Top row
            MetricCell(
                index: 0,
                icon: "flame.fill",
                color: Color(red: 0.85, green: 0.2, blue: 0.2),
                value: userStatsService.userStats.currentStreak,
                unit: "días",
                label: "RACHA",
                sublabel: streakComparison,
                themeManager: themeManager
            )

            MetricCell(
                index: 1,
                icon: "figure.run",
                color: .blue,
                value: weeklyWorkouts,
                unit: "/ 7",
                label: "WORKOUTS",
                sublabel: "\(weeklyProgress)% meta",
                themeManager: themeManager
            )

            // Bottom row - solo para usuarios activos (14+ días)
            if shouldShowBottomRow {
                MetricCell(
                    index: 2,
                    icon: "calendar",
                    color: .purple,
                    value: userStatsService.userStats.monthlyClasses,
                    unit: "clases",
                    label: "MES",
                    sublabel: monthlyComparison,
                    themeManager: themeManager
                )

                MetricCell(
                    index: 3,
                    icon: "trophy.fill",
                    color: Color(red: 1.0, green: 0.84, blue: 0.0),
                    value: userStatsService.userStats.totalStreak,
                    unit: "total",
                    label: "TOTAL",
                    sublabel: totalLabel,
                    themeManager: themeManager
                )
            } else {
                // Mensaje motivacional para usuarios nuevos
                motivationalMessage
                    .gridCellColumns(2)
            }
        }
    }

    // MARK: - Collapsed Content

    private var collapsedContent: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
                Text("\(userStatsService.userStats.currentStreak) días")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Circle()
                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                .frame(width: 4, height: 4)

            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text("\(weeklyWorkouts) workouts")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()
        }
    }

    // MARK: - Motivational Message

    private var motivationalMessage: some View {
        VStack(spacing: 8) {
            Text(motivationalText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)

            if let actionText = motivationalActionText {
                Text(actionText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
        )
    }

    // MARK: - Computed Properties

    private var headerTitle: String {
        return "STATS SUMMARY"
    }

    private var weeklyWorkouts: Int {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return 0
        }

        // Esto es un placeholder - necesitaríamos workoutHistory del servicio
        // Por ahora usamos una estimación basada en currentStreak
        let streak = userStatsService.userStats.currentStreak
        return min(streak, 7)
    }

    private var weeklyProgress: Int {
        let progress = (Double(weeklyWorkouts) / 7.0) * 100.0
        return Int(progress.rounded())
    }

    private var streakComparison: String? {
        let streak = userStatsService.userStats.currentStreak
        if streak >= 7 {
            return "+\(streak - 5) vs sem"
        }
        return nil
    }

    private var monthlyComparison: String? {
        let monthly = userStatsService.userStats.monthlyClasses
        if monthly > 3 {
            return "+\(monthly - 8) vs prev"
        }
        return nil
    }

    private var totalLabel: String? {
        let total = userStatsService.userStats.totalStreak
        if total >= 50 {
            return "Top 20% 🌟"
        } else if total >= 20 {
            return "¡Excelente!"
        }
        return nil
    }

    private var shouldShowBottomRow: Bool {
        let daysInGym = calculateDaysSinceFirstWorkout()
        return daysInGym >= 14
    }

    private func calculateDaysSinceFirstWorkout() -> Int {
        // Placeholder - necesitaríamos fecha de primera clase
        // Por ahora usamos totalStreak como proxy
        let total = userStatsService.userStats.totalStreak
        return total > 0 ? total : 0
    }

    private var motivationalText: String {
        let workouts = userStatsService.userStats.monthlyClasses

        if workouts == 0 {
            return "Tu primer entrenamiento te espera"
        } else if workouts == 1 {
            return "¡Gran comienzo! Ya completaste 1 sesión"
        } else {
            return "¡Sigue así! Agenda tu próxima clase para crear un hábito"
        }
    }

    private var motivationalActionText: String? {
        let workouts = userStatsService.userStats.monthlyClasses
        if workouts < 3 {
            return "Más stats pronto ✨"
        }
        return nil
    }
}

// MARK: - Metric Cell Component

struct MetricCell: View {
    let index: Int
    let icon: String
    let color: Color
    let value: Int
    let unit: String
    let label: String
    let sublabel: String?
    let themeManager: ThemeManager

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            if let sublabel = sublabel {
                Text(sublabel)
                    .font(.system(size: 9))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
            } else {
                Spacer().frame(height: 9)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 0.5)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.1)) {
                appeared = true
            }
        }
    }
}

#Preview {
    WeeklyCheckInCard()
        .environmentObject(UserStatsService.shared)
        .environmentObject(ThemeManager())
        .padding()
}
