import SwiftUI

// MARK: - GroupProgressWidget

/// Widget que muestra las estadísticas de grupo para planes LIVE
/// Muestra participación, adherencia promedio y desglose por tipo de comida
struct GroupProgressWidget: View {
    let groupStats: GroupCompletionStats

    @EnvironmentObject var themeManager: ThemeManager
    @State private var animateProgress = false

    var body: some View {
        VStack(spacing: 16) {
            // Header con título y emoji motivacional
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tu Gym en el Desafío")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text("Día \(groupStats.currentDay)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                // Energy level indicator
                Text(groupStats.groupEnergyLevel.emoji)
                    .font(.system(size: 32))
                    .scaleEffect(animateProgress ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateProgress)
            }

            // Stats principales
            HStack(spacing: 12) {
                // Total Participants
                GroupStatCard(
                    icon: "person.3.fill",
                    value: "\(groupStats.totalParticipants)",
                    label: "Participantes",
                    color: .blue
                )
                .environmentObject(themeManager)

                // Active Today
                GroupStatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(groupStats.activeToday)",
                    label: "Activos Hoy",
                    color: .green
                )
                .environmentObject(themeManager)

                // Completed Day
                GroupStatCard(
                    icon: "star.fill",
                    value: "\(groupStats.completedDayFully)",
                    label: "Completaron",
                    color: .yellow
                )
                .environmentObject(themeManager)
            }

            // Circular progress con adherencia promedio
            VStack(spacing: 12) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2),
                            lineWidth: 12
                        )
                        .frame(width: 120, height: 120)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: animateProgress ? groupStats.avgCompletionPercentage / 100 : 0)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    groupStats.avgCompletionPercentage >= 80 ? .green :
                                    groupStats.avgCompletionPercentage >= 50 ? .orange : .red,
                                    groupStats.avgCompletionPercentage >= 80 ? .green.opacity(0.6) :
                                    groupStats.avgCompletionPercentage >= 50 ? .orange.opacity(0.6) : .red.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 1.2), value: animateProgress)

                    // Center text
                    VStack(spacing: 2) {
                        Text(groupStats.formattedAvgCompletion)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                        Text("Adherencia")
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                .padding(.vertical, 8)

                // Motivational message
                Text(groupStats.motivationalMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }

            // Meal breakdown section
            if !groupStats.mealCompletions.isEmpty {
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Desglose por Comida")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    VStack(spacing: 8) {
                        ForEach(groupStats.mealCompletions.sorted(by: { $0.mealType < $1.mealType }), id: \.mealType) { mealCompletion in
                            MealCompletionRow(mealCompletion: mealCompletion)
                                .environmentObject(themeManager)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .onAppear {
            animateProgress = true
        }
    }
}

// MARK: - GroupStatCard

/// Card individual para una estadística de grupo
struct GroupStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - MealCompletionRow

/// Fila que muestra el progreso de un tipo de comida
struct MealCompletionRow: View {
    let mealCompletion: MealTypeCompletion

    @EnvironmentObject var themeManager: ThemeManager
    @State private var animateBar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: emoji + nombre + porcentaje
            HStack {
                Text(mealCompletion.emoji)
                    .font(.system(size: 16))

                Text(mealCompletion.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text(mealCompletion.formattedCompletionRate)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(mealCompletion.statusColor == "green" ? .green :
                                    mealCompletion.statusColor == "orange" ? .orange : .red)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    mealCompletion.statusColor == "green" ? Color.green :
                                    mealCompletion.statusColor == "orange" ? Color.orange : Color.red,
                                    (mealCompletion.statusColor == "green" ? Color.green :
                                     mealCompletion.statusColor == "orange" ? Color.orange : Color.red).opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: animateBar ? geometry.size.width * (mealCompletion.completionRate / 100) : 0,
                            height: 6
                        )
                        .animation(.spring(duration: 0.8), value: animateBar)
                }
            }
            .frame(height: 6)

            // Users count
            Text("\(mealCompletion.usersCompleted) de \(mealCompletion.totalUsersWithMeal) usuarios")
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .onAppear {
            animateBar = true
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Widget con stats completas
            GroupProgressWidget(
                groupStats: GroupCompletionStats(
                    totalParticipants: 87,
                    activeToday: 64,
                    completedDayFully: 23,
                    avgCompletionPercentage: 71.5,
                    mealCompletions: [
                        MealTypeCompletion(
                            mealType: "breakfast",
                            totalUsersWithMeal: 87,
                            usersCompleted: 78,
                            completionRate: 89.7
                        ),
                        MealTypeCompletion(
                            mealType: "lunch",
                            totalUsersWithMeal: 87,
                            usersCompleted: 65,
                            completionRate: 74.7
                        ),
                        MealTypeCompletion(
                            mealType: "dinner",
                            totalUsersWithMeal: 87,
                            usersCompleted: 52,
                            completionRate: 59.8
                        ),
                        MealTypeCompletion(
                            mealType: "snack",
                            totalUsersWithMeal: 50,
                            usersCompleted: 38,
                            completionRate: 76.0
                        )
                    ],
                    currentDay: 5,
                    planId: 123,
                    date: "2024-02-20T00:00:00"
                )
            )
            .padding()

            // Widget con adherencia baja
            GroupProgressWidget(
                groupStats: GroupCompletionStats(
                    totalParticipants: 45,
                    activeToday: 18,
                    completedDayFully: 5,
                    avgCompletionPercentage: 38.2,
                    mealCompletions: [
                        MealTypeCompletion(
                            mealType: "breakfast",
                            totalUsersWithMeal: 45,
                            usersCompleted: 22,
                            completionRate: 48.9
                        ),
                        MealTypeCompletion(
                            mealType: "lunch",
                            totalUsersWithMeal: 45,
                            usersCompleted: 18,
                            completionRate: 40.0
                        )
                    ],
                    currentDay: 12,
                    planId: 456,
                    date: "2024-02-20T00:00:00"
                )
            )
            .padding()

            // Widget con adherencia alta
            GroupProgressWidget(
                groupStats: GroupCompletionStats(
                    totalParticipants: 120,
                    activeToday: 112,
                    completedDayFully: 98,
                    avgCompletionPercentage: 92.5,
                    mealCompletions: [
                        MealTypeCompletion(
                            mealType: "breakfast",
                            totalUsersWithMeal: 120,
                            usersCompleted: 115,
                            completionRate: 95.8
                        ),
                        MealTypeCompletion(
                            mealType: "lunch",
                            totalUsersWithMeal: 120,
                            usersCompleted: 110,
                            completionRate: 91.7
                        ),
                        MealTypeCompletion(
                            mealType: "dinner",
                            totalUsersWithMeal: 120,
                            usersCompleted: 108,
                            completionRate: 90.0
                        )
                    ],
                    currentDay: 3,
                    planId: 789,
                    date: "2024-02-20T00:00:00"
                )
            )
            .padding()
        }
        .padding(.vertical)
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
