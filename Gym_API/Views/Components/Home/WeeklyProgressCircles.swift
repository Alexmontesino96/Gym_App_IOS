import SwiftUI

struct WeeklyProgressCircles: View {
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("TUS METAS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Progress circles
            HStack(spacing: 16) {
                // Racha (Streak)
                CircularProgressView(
                    progress: streakProgress,
                    current: streakCount,
                    goal: 7,
                    title: "Racha",
                    emoji: "🔥",
                    gradientColors: [.orange, .red]
                )

                // Workouts semanales
                CircularProgressView(
                    progress: weeklyWorkoutsProgress,
                    current: weeklyWorkouts,
                    goal: 7,
                    title: "Workouts",
                    emoji: "💪",
                    gradientColors: [Color(hex: "#FF416C") ?? .pink, Color(hex: "#8E2DE2") ?? .purple]
                )

                // Classes mensuales
                CircularProgressView(
                    progress: monthlyClassesProgress,
                    current: monthlyClasses,
                    goal: 12,
                    title: "Classes",
                    emoji: "📅",
                    gradientColors: [Color(hex: "#4776E6") ?? .blue, Color(hex: "#8E54E9") ?? .purple]
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Computed Properties

    private var streakCount: Int {
        userStatsService.userStats.currentStreak
    }

    private var streakProgress: Double {
        min(Double(streakCount) / 7.0, 1.0)
    }

    private var weeklyWorkouts: Int {
        // Usar datos del backend en UserStats
        userStatsService.userStats.weeklyClasses + userStatsService.userStats.weeklyEvents
    }

    private var weeklyWorkoutsProgress: Double {
        min(Double(weeklyWorkouts) / 7.0, 1.0)
    }

    private var monthlyClasses: Int {
        // Usar datos del backend en UserStats
        userStatsService.userStats.monthlyClasses
    }

    private var monthlyClassesProgress: Double {
        min(Double(monthlyClasses) / 12.0, 1.0)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        WeeklyProgressCircles()
            .environmentObject(UserStatsService.shared)
            .environmentObject(ThemeManager())
    }
}
