import SwiftUI

/// Dedicated fullscreen view showcasing user's workout streak with gamification
struct StreakDetailView: View {
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var slideUp = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Main content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero number with fire animations
                        StreakHeroNumber(
                            count: userStatsService.userStats.currentStreak,
                            theme: themeManager.currentTheme
                        )
                        .padding(.top, 20)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                        // Stats grid (2x2)
                        statsGrid
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)

                        // Activity calendar heatmap
                        StreakCalendarHeatmap(
                            activityData: generateActivityData(),
                            theme: themeManager.currentTheme
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 40)

                        // Bottom spacing
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .offset(y: slideUp ? 0 : UIScreen.main.bounds.height)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header Component

    private var header: some View {
        HStack {
            // Title
            Text("Tu Racha")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()

            // Close button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    slideUp = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .padding()
        .background(
            Color.dynamicSurface(theme: themeManager.currentTheme)
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    y: 2
                )
        )
    }

    // MARK: - Stats Grid (2x2)

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            // Best Streak
            StreakStatsCard.bestStreak(
                userStatsService.userStats.totalStreak,
                theme: themeManager.currentTheme
            )

            // Start Date
            StreakStatsCard.startDate(
                userStatsService.lastAttendanceDate,
                theme: themeManager.currentTheme
            )

            // Level
            StreakStatsCard.level(
                userStatsService.userStats.currentStreak,
                theme: themeManager.currentTheme
            )

            // Total Workouts
            // TODO: Replace with actual total workouts count when available from backend
            StreakStatsCard.totalWorkouts(
                userStatsService.userStats.totalStreak,
                theme: themeManager.currentTheme
            )
        }
    }

    // MARK: - Animation Helpers

    private func startAnimations() {
        // Slide up animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            slideUp = true
        }

        // Staggered content reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }

    // MARK: - Data Helpers

    /// Genera datos de actividad para el calendario basado en historial real
    /// TODO: Reemplazar con datos reales del backend cuando estén disponibles
    private func generateActivityData() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()

        // Por ahora generar datos simulados
        // En producción, esto vendría del backend con el historial de asistencias
        for dayOffset in 0..<84 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let startOfDay = calendar.startOfDay(for: date)
                // Simular actividad aleatoria
                // TODO: Fetch from backend API endpoint
                data[startOfDay] = Int.random(in: 0...3)
            }
        }

        return data
    }
}

// MARK: - Preview

#Preview {
    StreakDetailView()
        .withServiceContainer()
}
