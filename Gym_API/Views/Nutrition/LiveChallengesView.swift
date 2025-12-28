import SwiftUI

// MARK: - LiveChallengesView

/// Tab 1 del Dashboard: Challenges LIVE activos y proximos
/// Muestra:
/// - Hero Card si el usuario esta inscrito en un challenge activo
/// - Proximos challenges (grid de cards)
/// - Challenges completados (scroll horizontal de badges)
struct LiveChallengesView: View {
    // MARK: - Properties

    let onPlanSelected: (NutritionPlan) -> Void
    let onViewTodayPlan: () -> Void

    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isRefreshing = false
    @State private var appearAnimation = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            if nutritionService.isLoading && nutritionService.livePlans.isEmpty {
                loadingView
            } else if nutritionService.livePlans.isEmpty && !hasAnyContent {
                emptyStateView
            } else {
                contentView
            }
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        LazyVStack(spacing: 24) {
            // Active Challenge Hero Card
            if let activeChallenge = nutritionService.activeLiveChallenge,
               activeChallenge.isFollowedByUser {
                activeChallengeSectionView(activeChallenge)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Running Challenges (not enrolled)
            let runningChallenges = nutritionService.livePlans.filter {
                $0.status == .running && !$0.isFollowedByUser
            }
            if !runningChallenges.isEmpty {
                runningChallengesSectionView(runningChallenges)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Upcoming Challenges
            let upcomingChallenges = nutritionService.livePlans.filter {
                $0.status == .notStarted
            }
            if !upcomingChallenges.isEmpty {
                upcomingChallengesSectionView(upcomingChallenges)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Completed Challenges
            let completedChallenges = nutritionService.livePlans.filter {
                $0.status == .finished && $0.isFollowedByUser
            }
            if !completedChallenges.isEmpty {
                completedChallengesSectionView(completedChallenges)
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

    // MARK: - Active Challenge Section

    private func activeChallengeSectionView(_ plan: NutritionPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    LivePulseIndicator(size: 10)
                    Text("Tu Challenge Activo")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()
            }

            // Hero Card
            ActiveChallengeHeroCard(
                plan: plan,
                progress: nutritionService.todayProgress ?? DayProgress(
                    mealsCompleted: 0,
                    totalMeals: 0,
                    percentage: 0,
                    caloriesConsumed: 0,
                    caloriesTarget: 2000,
                    proteinConsumed: 0,
                    proteinTarget: 150,
                    carbsConsumed: nil,
                    carbsTarget: nil,
                    fatConsumed: nil,
                    fatTarget: nil
                ),
                onTap: {
                    onViewTodayPlan()
                }
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Running Challenges Section

    private func runningChallengesSectionView(_ challenges: [NutritionPlan]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    LivePulseIndicator(size: 8)
                    Text("En Curso Ahora")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                Text("\(challenges.count) activo\(challenges.count == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Challenge Cards
            ForEach(challenges) { challenge in
                LiveChallengeCard(plan: challenge) {
                    onPlanSelected(challenge)
                }
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Upcoming Challenges Section

    private func upcomingChallengesSectionView(_ challenges: [NutritionPlan]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    Text("Proximos Challenges")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                Text("\(challenges.count) disponible\(challenges.count == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // 2-column Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(challenges) { challenge in
                    UpcomingChallengeCard(plan: challenge) {
                        onPlanSelected(challenge)
                    }
                    .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Completed Challenges Section

    private func completedChallengesSectionView(_ challenges: [NutritionPlan]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.yellow)
                    Text("Challenges Completados")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()
            }

            // Horizontal Scroll of Badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(challenges) { challenge in
                        CompletedChallengeBadge(plan: challenge) {
                            onPlanSelected(challenge)
                        }
                        .environmentObject(themeManager)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.dynamicAccent(theme: themeManager.currentTheme))

            Text("Cargando challenges...")
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
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 44))
                    .foregroundColor(.red)
            }

            // Title
            Text("No hay challenges LIVE")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Description
            Text("Pronto tendras nuevos challenges grupales para unirte y mejorar tu alimentacion junto a otros")
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Notification CTA
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Notificarme cuando haya uno")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 2)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var hasAnyContent: Bool {
        return !nutritionService.livePlans.isEmpty
    }

    private func refreshData() async {
        isRefreshing = true
        await nutritionService.getDashboard()
        isRefreshing = false
    }
}

// MARK: - ActiveChallengeHeroCard

/// Hero card prominente para el challenge activo del usuario
struct ActiveChallengeHeroCard: View {
    let plan: NutritionPlan
    let progress: DayProgress
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            LivePulseIndicator(size: 10)
                            Text("LIVE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }

                        Text(plan.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(2)
                    }

                    Spacer()

                    // Day Badge
                    VStack(spacing: 2) {
                        Text("DIA")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        Text("\(plan.currentDay ?? 1)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        Text("de \(plan.durationDays)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    )
                }

                // Progress Section
                VStack(spacing: 12) {
                    MealProgressBar(
                        mealsCompleted: progress.mealsCompleted,
                        totalMeals: progress.totalMeals
                    )
                    .environmentObject(themeManager)

                    // Macro Stats
                    HStack(spacing: 24) {
                        MacroStatItem(
                            icon: "flame.fill",
                            value: progress.caloriesConsumed,
                            target: progress.caloriesTarget,
                            unit: "kcal",
                            color: .orange
                        )

                        MacroStatItem(
                            icon: "leaf.fill",
                            value: progress.proteinConsumed,
                            target: progress.proteinTarget,
                            unit: "g prot",
                            color: .green
                        )

                        Spacer()

                        // Participants
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                            Text("\(plan.liveParticipantsCount)")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }

                // CTA
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Text("VER MI DIA")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.5),
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
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

// MARK: - MacroStatItem

struct MacroStatItem: View {
    let icon: String
    let value: Int
    let target: Int
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text("\(value)/\(target)")
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - LiveChallengeCard

/// Card para challenges en curso donde el usuario no esta inscrito
struct LiveChallengeCard: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Left side - Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        LivePulseIndicator(size: 8)
                        Text("EN CURSO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }

                    Text(plan.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label("Dia \(plan.currentDay ?? 1)/\(plan.durationDays)", systemImage: "calendar")
                        Label("\(plan.liveParticipantsCount)", systemImage: "person.2.fill")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                // Right side - CTA
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                    Text("Unirse")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - UpcomingChallengeCard

/// Card compacta para challenges proximos (usada en grid 2x2)
struct UpcomingChallengeCard: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Countdown Badge
                HStack {
                    if let daysUntilStart = plan.daysUntilStart {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(daysUntilStart == 0 ? "HOY" : "En \(daysUntilStart)d")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                    }

                    Spacer()

                    if plan.isFollowedByUser {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                }

                // Title
                Text(plan.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Stats
                HStack(spacing: 8) {
                    Label("\(plan.durationDays)d", systemImage: "calendar")
                    Spacer()
                    Label("\(plan.liveParticipantsCount)", systemImage: "person.2.fill")
                }
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                // CTA
                Text(plan.isFollowedByUser ? "Inscrito" : "Reservar lugar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(plan.isFollowedByUser
                                ? Color.gray
                                : Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
            }
            .padding(16)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - CompletedChallengeBadge

/// Badge para challenges completados (scroll horizontal)
struct CompletedChallengeBadge: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 12) {
                // Trophy Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }

                // Title
                Text(plan.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Duration
                Text("\(plan.durationDays) dias")
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .frame(width: 100)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveChallengesView(
            onPlanSelected: { _ in },
            onViewTodayPlan: { }
        )
        .environmentObject(NutritionService.shared)
        .environmentObject(ThemeManager())
    }
}
