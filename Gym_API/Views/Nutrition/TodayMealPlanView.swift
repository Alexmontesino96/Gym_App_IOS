import SwiftUI

// MARK: - TodayMealPlanView

/// Vista principal del plan de nutricion del dia actual
/// Muestra el challenge activo, progreso y lista de comidas
struct TodayMealPlanView: View {
    // MARK: - Properties

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var nutritionService: NutritionService

    @State private var isRefreshing = false
    @State private var selectedMeal: Meal?
    @State private var showMealDetail = false
    @State private var showError = false
    @State private var appearAnimation = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            if nutritionService.isLoading && nutritionService.todayPlan == nil {
                loadingView
            } else if let todayPlan = nutritionService.todayPlan {
                contentView(todayPlan: todayPlan)
            } else {
                emptyStateView
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationTitle("Plan del Dia")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshData()
        }
        .sheet(isPresented: $showMealDetail) {
            if let meal = selectedMeal {
                MealDetailView(meal: meal)
                    .environmentObject(themeManager)
                    .environmentObject(nutritionService)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(nutritionService.errorMessage ?? "Error desconocido")
        }
        .onAppear {
            loadDataIfNeeded()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
        .onChange(of: nutritionService.errorMessage) { _, newValue in
            if newValue != nil {
                showError = true
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private func contentView(todayPlan: TodayMealPlan) -> some View {
        VStack(spacing: 20) {
            // Challenge Header
            if let plan = todayPlan.plan {
                challengeHeaderCard(plan: plan, status: todayPlan.status, currentDay: todayPlan.currentDay, daysUntilStart: todayPlan.daysUntilStart)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Progress Section
            progressSectionCard(progress: todayPlan.progress)
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)

            // Status message for pending plans
            if todayPlan.status == .notStarted {
                pendingStatusCard(daysUntilStart: todayPlan.daysUntilStart)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Meals Section
            if !todayPlan.meals.isEmpty {
                mealsSectionCard(meals: todayPlan.meals)
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

    // MARK: - Challenge Header Card

    private func challengeHeaderCard(plan: NutritionPlan, status: PlanStatus, currentDay: Int, daysUntilStart: Int?) -> some View {
        VStack(spacing: 16) {
            // Header with live indicator
            HStack(spacing: 10) {
                if plan.planType == .live && status == .running {
                    LivePulseIndicator(size: 10)

                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }

                Text(plan.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(2)

                Spacer()
            }

            // Challenge info row
            HStack(spacing: 20) {
                // Day counter
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                    if status == .running {
                        Text("Dia \(currentDay) de \(plan.durationDays)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    } else if status == .notStarted {
                        Text("\(plan.durationDays) dias")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    } else {
                        Text("Completado")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                }

                // Participants
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                    Text("\(plan.liveParticipantsCount) personas")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()
            }

            // Goal badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: plan.goal.icon)
                        .font(.system(size: 12))
                    Text(plan.goal.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                )

                Spacer()

                // Creator
                Text("por \(plan.creatorName)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Progress Section Card

    private func progressSectionCard(progress: DayProgress?) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Tu Progreso Hoy")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                if let progress = progress, progress.percentage >= 100 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Completado")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.green)
                }
            }

            if let progress = progress {
                // Meal progress bar
                MealProgressBar(
                    mealsCompleted: progress.mealsCompleted,
                    totalMeals: progress.totalMeals
                )
                .environmentObject(themeManager)

                // Macro summary
                MacroSummaryView(progress: progress)
                    .environmentObject(themeManager)
            } else {
                // No progress data available
                Text("Cargando progreso...")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Pending Status Card

    private func pendingStatusCard(daysUntilStart: Int?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("El challenge aun no ha comenzado")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            if let days = daysUntilStart {
                Text("Empieza en \(days) dia\(days == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }

            Text("Las comidas estaran disponibles cuando comience")
                .font(.system(size: 13))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Meals Section Card

    private func mealsSectionCard(meals: [Meal]) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Comidas del Dia")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                let completed = meals.filter { $0.isCompleted }.count
                Text("\(completed)/\(meals.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Meal cards
            ForEach(meals.sorted()) { meal in
                MealCard(meal: meal) {
                    handleMealTap(meal)
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

            Text("Cargando plan del dia...")
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

                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 50))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Title
            Text("No tienes plan activo")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Description
            Text("Explora planes de nutricion y unete a un challenge para comenzar tu transformacion")
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // CTA Button
            Button(action: {
                // Navegar a explorar planes
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Explorar Planes")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func handleMealTap(_ meal: Meal) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        selectedMeal = meal
        showMealDetail = true
    }

    private func loadDataIfNeeded() {
        if nutritionService.todayPlan == nil {
            Task {
                await nutritionService.getTodayPlan()
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        await nutritionService.getTodayPlan()
        isRefreshing = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TodayMealPlanView()
            .environmentObject(ThemeManager())
            .environmentObject(NutritionService.shared)
    }
}
