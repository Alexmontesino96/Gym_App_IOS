import SwiftUI

// MARK: - MyPlansView

/// Tab 3 del Dashboard: Mis Planes
/// Muestra:
/// - Plan activo actual (si existe)
/// - Historial de planes completados
/// - Estadisticas personales
struct MyPlansView: View {
    // MARK: - Properties

    let onViewTodayPlan: () -> Void
    let onPlanSelected: (NutritionPlan) -> Void

    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isRefreshing = false
    @State private var appearAnimation = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            if nutritionService.isLoading && nutritionService.userStats == nil {
                loadingView
            } else if !hasAnyContent {
                emptyStateView
            } else {
                contentView
            }
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            loadDataIfNeeded()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        LazyVStack(spacing: 24) {
            // Active Plan Section
            if let todayPlan = nutritionService.todayPlan,
               let plan = todayPlan.plan {
                activePlanSectionView(plan: plan, todayPlan: todayPlan)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Stats Section
            if let stats = nutritionService.userStats, !stats.isNewUser {
                statsSectionView(stats: stats)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // History Section
            let completedPlans = getCompletedPlans()
            if !completedPlans.isEmpty {
                historySectionView(plans: completedPlans)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Followed Plans (not started)
            let upcomingFollowedPlans = getUpcomingFollowedPlans()
            if !upcomingFollowedPlans.isEmpty {
                upcomingFollowedSectionView(plans: upcomingFollowedPlans)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Bottom spacing
            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Active Plan Section

    private func activePlanSectionView(plan: NutritionPlan, todayPlan: TodayMealPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    if plan.planType == .live {
                        LivePulseIndicator(size: 10)
                    } else {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }

                    Text("Plan Activo")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                if todayPlan.status == .running {
                    Text("Dia \(todayPlan.currentDay)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }

            // Active Plan Card
            ActivePlanCard(
                plan: plan,
                todayPlan: todayPlan,
                onTap: onViewTodayPlan
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Stats Section

    private func statsSectionView(stats: UserNutritionStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    Text("Mis Estadisticas")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                // User Level Badge
                UserLevelBadge(level: stats.userLevel)
                    .environmentObject(themeManager)
            }

            // Stats Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                PlanStatsCard(
                    icon: "checkmark.circle.fill",
                    value: "\(stats.totalPlansFollowed)",
                    label: "Planes",
                    color: .green
                )
                .environmentObject(themeManager)

                PlanStatsCard(
                    icon: "percent",
                    value: "\(Int(stats.weeklyAverage))%",
                    label: "Promedio",
                    color: .blue
                )
                .environmentObject(themeManager)

                PlanStatsCard(
                    icon: "fork.knife",
                    value: "\(stats.totalMealsCompleted)",
                    label: "Comidas",
                    color: .orange
                )
                .environmentObject(themeManager)
            }

            // Streak Card
            if stats.completionStreak > 0 {
                StreakCard(
                    currentStreak: stats.completionStreak,
                    bestStreak: stats.bestStreak ?? stats.completionStreak
                )
                .environmentObject(themeManager)
            }

            // Motivational Message
            Text(stats.motivationalMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    // MARK: - History Section

    private func historySectionView(plans: [NutritionPlan]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Text("Historial")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                Text("\(plans.count) completado\(plans.count == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // History List
            ForEach(plans) { plan in
                HistoryPlanCard(plan: plan) {
                    onPlanSelected(plan)
                }
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Upcoming Followed Section

    private func upcomingFollowedSectionView(plans: [NutritionPlan]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    Text("Proximos a Empezar")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()
            }

            // Cards
            ForEach(plans) { plan in
                UpcomingFollowedPlanCard(plan: plan) {
                    onPlanSelected(plan)
                }
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.dynamicAccent(theme: themeManager.currentTheme))

            Text("Cargando tus planes...")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 44))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Title
            Text("Aun no tienes planes")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Description
            Text("Explora planes de nutricion y unete a tu primer challenge para comenzar tu transformacion")
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Stats Preview (if new user)
            VStack(spacing: 12) {
                Text("Cuando completes tu primer plan, veras aqui:")
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                HStack(spacing: 20) {
                    PreviewStatItem(icon: "trophy.fill", label: "Logros")
                    PreviewStatItem(icon: "chart.line.uptrend.xyaxis", label: "Progreso")
                    PreviewStatItem(icon: "flame.fill", label: "Racha")
                }
            }
            .padding(.top, 16)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var hasAnyContent: Bool {
        return nutritionService.todayPlan?.plan != nil ||
               nutritionService.userStats?.totalPlansFollowed ?? 0 > 0 ||
               !getCompletedPlans().isEmpty ||
               !getUpcomingFollowedPlans().isEmpty
    }

    private func getCompletedPlans() -> [NutritionPlan] {
        var plans: [NutritionPlan] = []

        // From live plans
        plans += nutritionService.livePlans.filter {
            $0.status == .finished && $0.isFollowedByUser
        }

        // From template plans
        plans += nutritionService.templatePlans.filter {
            $0.status == .finished && $0.isFollowedByUser
        }

        return plans
    }

    private func getUpcomingFollowedPlans() -> [NutritionPlan] {
        return nutritionService.livePlans.filter {
            $0.status == .notStarted && $0.isFollowedByUser
        }
    }

    private func loadDataIfNeeded() {
        if nutritionService.userStats == nil && !nutritionService.isLoading {
            Task {
                await nutritionService.getDashboard()
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        await nutritionService.getDashboard()
        isRefreshing = false
    }
}

// MARK: - ActivePlanCard

/// Card para el plan activo actual
struct ActivePlanCard: View {
    let plan: NutritionPlan
    let todayPlan: TodayMealPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            PlanTypeBadge(planType: plan.planType)
                                .environmentObject(themeManager)

                            if plan.planType == .live {
                                Text("\(plan.liveParticipantsCount) activos")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }

                        Text(plan.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                                lineWidth: 6
                            )

                        Circle()
                            .trim(from: 0, to: CGFloat(todayPlan.progress?.percentage ?? 0) / 100)
                            .stroke(
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: todayPlan.progress?.percentage ?? 0)

                        Text("\(Int(todayPlan.progress?.percentage ?? 0))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    .frame(width: 60, height: 60)
                }

                // Status & Info
                HStack {
                    // Day info
                    if todayPlan.status == .running {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dia \(todayPlan.currentDay) de \(plan.durationDays)")
                                .font(.system(size: 14, weight: .semibold))
                            Text(todayPlan.statusMessage)
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    } else if todayPlan.status == .notStarted {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proximo a empezar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            if let days = todayPlan.daysUntilStart {
                                Text("En \(days) dia\(days == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                    }

                    Spacer()

                    // CTA
                    HStack(spacing: 6) {
                        Text(todayPlan.status == .running ? "VER HOY" : "VER PLAN")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - PlanStatsCard

/// Card para mostrar una estadistica
struct PlanStatsCard: View {
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
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - StreakCard

/// Card para mostrar la racha actual
struct StreakCard: View {
    let currentStreak: Int
    let bestStreak: Int

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            // Flame Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // Streak Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Racha Actual")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text("dias")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.bottom, 4)
                }
            }

            Spacer()

            // Best Streak
            VStack(alignment: .trailing, spacing: 4) {
                Text("Mejor")
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                HStack(spacing: 2) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("\(bestStreak)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.5), .red.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - HistoryPlanCard

/// Card para plan completado en historial
struct HistoryPlanCard: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Checkmark Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }

                // Plan Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label("\(plan.durationDays) dias", systemImage: "calendar")

                        if let satisfaction = plan.avgSatisfaction, satisfaction > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", satisfaction))
                            }
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - UpcomingFollowedPlanCard

/// Card para planes inscritos que aun no empiezan
struct UpcomingFollowedPlanCard: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Calendar Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }

                // Plan Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(1)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }

                    if let daysUntilStart = plan.daysUntilStart {
                        Text("Empieza en \(daysUntilStart) dia\(daysUntilStart == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - UserLevelBadge

/// Badge para mostrar nivel del usuario
struct UserLevelBadge: View {
    let level: NutritionUserLevel

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.system(size: 10))
            Text(level.displayName)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(levelColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(levelColor.opacity(0.15))
        )
    }

    private var levelColor: Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .purple
        }
    }
}

// MARK: - PreviewStatItem

/// Item de preview para estadisticas (empty state)
struct PreviewStatItem: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.gray)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyPlansView(
            onViewTodayPlan: { },
            onPlanSelected: { _ in }
        )
        .environmentObject(NutritionService.shared)
        .environmentObject(ThemeManager())
    }
}
