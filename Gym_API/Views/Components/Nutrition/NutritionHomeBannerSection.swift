import SwiftUI

// MARK: - NutritionHomeBannerSection

/// Seccion de HomeView que muestra el banner de nutricion apropiado
/// basado en el estado del usuario:
/// - Si tiene un plan activo: ActivePlanCard (full-width, moderno)
/// - Si tiene un plan LIVE activo: NutritionLiveChallengeBanner
/// - Si hay un plan LIVE proximo: NutritionUpcomingChallengeBanner
/// - Si no tiene plan: NutritionDiscoverBanner
struct NutritionHomeBannerSection: View {
    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showTodayMealPlan = false
    @State private var showNutritionDashboard = false
    @State private var hasLoadedData = false
    @State private var hasAppeared = false
    @State private var showQuickJoin = false
    @State private var selectedPlanForQuickJoin: NutritionPlan?

    var body: some View {
        VStack(spacing: 12) {
            bannerContent
                .scaleEffect(hasAppeared ? 1.0 : 0.95)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .offset(y: hasAppeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showTodayMealPlan) {
            NavigationStack {
                TodayMealPlanView()
                    .environmentObject(nutritionService)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showNutritionDashboard) {
            NutritionDashboardView()
                .environmentObject(nutritionService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showQuickJoin) {
            if let plan = selectedPlanForQuickJoin {
                QuickJoinBottomSheet(
                    plan: plan,
                    onJoin: {
                        await nutritionService.followPlan(planId: plan.id)
                        // Refresh dashboard after joining
                        await nutritionService.getDashboard()
                    },
                    onViewDetails: {
                        showQuickJoin = false
                        // Small delay to allow sheet dismissal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showNutritionDashboard = true
                        }
                    }
                )
                .environmentObject(themeManager)
            }
        }
        .task {
            guard !hasLoadedData else { return }
            hasLoadedData = true

            // Cargar datos con timeout implícito usando Task
            await Task {
                await nutritionService.getDashboard()
            }.value
        }
    }

    // MARK: - Banner Content

    @ViewBuilder
    private var bannerContent: some View {
        Group {
            // Widget 1: Plan activo del usuario (adherencia general)
            if let activePlan = nutritionService.activePlans.first {
                ActivePlanHomeCard(
                    plan: activePlan,
                    currentStreak: nutritionService.currentStreak,
                    onTap: { showNutritionDashboard = true }
                )
                .environmentObject(themeManager)
            }

            // Widget 2: Banner LIVE (progreso del día actual)
            if let todayPlan = nutritionService.todayPlan,
               let plan = todayPlan.plan,
               let progress = todayPlan.progress {
                NutritionLiveChallengeBanner(
                    plan: plan,
                    progress: progress
                ) {
                    showTodayMealPlan = true
                }
                .environmentObject(themeManager)
            }

            // Fallback: Solo si NO hay ninguno de los dos anteriores
            if nutritionService.activePlans.isEmpty && nutritionService.todayPlan == nil {
                // Plan LIVE próximo - Mostrar QuickJoin si puede unirse
                if let upcomingPlan = nutritionService.livePlans.first(where: { $0.status == .notStarted }) {
                    NutritionUpcomingChallengeBanner(plan: upcomingPlan) {
                        // Si el plan es un LIVE y puede unirse, mostrar quick join
                        if upcomingPlan.canJoin {
                            selectedPlanForQuickJoin = upcomingPlan
                            showQuickJoin = true
                        } else {
                            showNutritionDashboard = true
                        }
                    }
                    .environmentObject(themeManager)
                }
                // Discover banner (si no hay nada)
                else {
                    NutritionDiscoverBanner {
                        // Si hay algún plan LIVE disponible, mostrar quick join del primero
                        if let firstLivePlan = nutritionService.livePlans.first(where: { $0.canJoin }) {
                            selectedPlanForQuickJoin = firstLivePlan
                            showQuickJoin = true
                        } else {
                            showNutritionDashboard = true
                        }
                    }
                    .environmentObject(themeManager)
                }
            }
        }
    }
}

// MARK: - Design Tokens

private struct NutritionCardTokens {
    static let cardCornerRadius: CGFloat = 16  // Match live elements
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16
    static let planIconSize: CGFloat = 52
    static let planIconFontSize: CGFloat = 24
    static let adherenceRingSize: CGFloat = 64
    static let adherenceRingWidth: CGFloat = 6
    static let streakColor = Color(hex: "#FF9500") ?? .orange
}

// MARK: - ActivePlanHomeCard (Full-Width Modern Design)

/// Card moderno full-width para mostrar el plan nutricional activo
struct ActivePlanHomeCard: View {
    let plan: ActivePlan
    let currentStreak: Int
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var animatedProgress: CGFloat = 0
    @State private var hasAppeared = false

    private var gradientColors: [Color] {
        let name = plan.planName.lowercased()
        if name.contains("ganancia") || name.contains("muscular") || name.contains("masa") {
            return [Color(hex: "#FF6B6B") ?? .red, Color(hex: "#FF8E53") ?? .orange]
        } else if name.contains("pérdida") || name.contains("perdida") || name.contains("definición") {
            return [Color(hex: "#4776E6") ?? .blue, Color(hex: "#8E54E9") ?? .purple]
        } else if name.contains("mantenimiento") || name.contains("equilibrado") {
            return [Color(hex: "#11998E") ?? .teal, Color(hex: "#38EF7D") ?? .green]
        } else if name.contains("keto") || name.contains("cetog") {
            return [Color(hex: "#F2994A") ?? .orange, Color(hex: "#F2C94C") ?? .yellow]
        } else if name.contains("vegan") || name.contains("plant") {
            return [Color(hex: "#56AB2F") ?? .green, Color(hex: "#A8E063") ?? .green]
        }
        return [Color(hex: "#667EEA") ?? .blue, Color(hex: "#764BA2") ?? .purple]
    }

    private var primaryColor: Color {
        gradientColors.first ?? .blue
    }

    private var planIcon: String {
        let name = plan.planName.lowercased()
        if name.contains("ganancia") || name.contains("muscular") || name.contains("masa") {
            return "dumbbell.fill"
        } else if name.contains("pérdida") || name.contains("perdida") || name.contains("definición") {
            return "flame.fill"
        } else if name.contains("mantenimiento") || name.contains("equilibrado") {
            return "scale.3d"
        } else if name.contains("keto") || name.contains("cetog") {
            return "bolt.fill"
        } else if name.contains("vegan") || name.contains("plant") {
            return "leaf.fill"
        }
        return "fork.knife"
    }

    private var adherenceColor: Color {
        switch plan.adherencePercentage {
        case 0.8...: return Color(hex: "#00C853") ?? .green
        case 0.5..<0.8: return Color(hex: "#FFB300") ?? .orange
        default: return plan.adherencePercentage == 0 ? .gray : Color(hex: "#FF5252") ?? .red
        }
    }

    private var daysSinceStart: Int {
        Calendar.current.dateComponents([.day], from: plan.startDate, to: Date()).day ?? 0
    }

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: NutritionCardTokens.sectionSpacing) {
                // MARK: Header
                headerSection

                // MARK: Progress Section
                progressSection

                // MARK: CTA
                ctaSection
            }
            .padding(NutritionCardTokens.cardPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NutritionCardTokens.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: NutritionCardTokens.cardCornerRadius)
                    .stroke(
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(NutritionCardButtonStyle())
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = CGFloat(plan.adherencePercentage)
                hasAppeared = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 14) {
            // Plan icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: NutritionCardTokens.planIconSize, height: NutritionCardTokens.planIconSize)
                    .shadow(color: primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: planIcon)
                    .font(.system(size: NutritionCardTokens.planIconFontSize, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Plan info
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.planName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                Text("Día \(plan.currentDay)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()

            // Streak badge
            if currentStreak > 0 {
                streakBadge
            }
        }
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(NutritionCardTokens.streakColor)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))

            Text("\(currentStreak)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(NutritionCardTokens.streakColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(NutritionCardTokens.streakColor.opacity(0.12))
        )
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        HStack(spacing: 20) {
            // Adherence Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        adherenceColor.opacity(0.15),
                        lineWidth: NutritionCardTokens.adherenceRingWidth
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        adherenceColor,
                        style: StrokeStyle(
                            lineWidth: NutritionCardTokens.adherenceRingWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                // Percentage
                Text(String(format: "%.0f%%", plan.adherencePercentage * 100))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(adherenceColor)
            }
            .frame(width: NutritionCardTokens.adherenceRingSize, height: NutritionCardTokens.adherenceRingSize)

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                StatRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Adherencia",
                    value: adherenceLabel,
                    color: adherenceColor
                )

                StatRow(
                    icon: "calendar",
                    label: "Iniciado",
                    value: startDateLabel,
                    color: .dynamicTextSecondary(theme: themeManager.currentTheme)
                )
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var adherenceLabel: String {
        switch plan.adherencePercentage {
        case 0.8...: return "Excelente"
        case 0.6..<0.8: return "Buena"
        case 0.4..<0.6: return "Regular"
        default: return plan.adherencePercentage == 0 ? "Sin datos" : "Mejorable"
        }
    }

    private var startDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: plan.startDate)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        HStack {
            Image(systemName: "fork.knife")
                .font(.system(size: 16))
                .foregroundColor(primaryColor)

            Text("Ver plan de comidas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(primaryColor)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(primaryColor.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(primaryColor.opacity(0.08))
        )
    }

}

// MARK: - StatRow Component

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Button Style

private struct NutritionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Con Plan Activo") {
    let samplePlan = ActivePlan(
        planId: 1,
        planName: "Plan de Ganancia Muscular",
        startDate: Date().addingTimeInterval(-15 * 24 * 3600),
        currentDay: 15,
        adherencePercentage: 0.85
    )

    VStack {
        ActivePlanHomeCard(
            plan: samplePlan,
            currentStreak: 7,
            onTap: {}
        )
        .environmentObject(ThemeManager())
    }
    .padding(.vertical, 20)
    .background(Color(.systemGroupedBackground))
}

#Preview("Plan Pérdida Peso") {
    let samplePlan = ActivePlan(
        planId: 2,
        planName: "Plan Pérdida de Peso",
        startDate: Date().addingTimeInterval(-5 * 24 * 3600),
        currentDay: 5,
        adherencePercentage: 0.62
    )

    VStack {
        ActivePlanHomeCard(
            plan: samplePlan,
            currentStreak: 3,
            onTap: {}
        )
        .environmentObject(ThemeManager())
    }
    .padding(.vertical, 20)
    .background(Color(.systemGroupedBackground))
}

#Preview("Sin Racha") {
    let samplePlan = ActivePlan(
        planId: 3,
        planName: "Plan Keto",
        startDate: Date(),
        currentDay: 1,
        adherencePercentage: 0.0
    )

    VStack {
        ActivePlanHomeCard(
            plan: samplePlan,
            currentStreak: 0,
            onTap: {}
        )
        .environmentObject(ThemeManager())
    }
    .padding(.vertical, 20)
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    let samplePlan = ActivePlan(
        planId: 1,
        planName: "Plan Vegano",
        startDate: Date().addingTimeInterval(-10 * 24 * 3600),
        currentDay: 10,
        adherencePercentage: 0.92
    )

    VStack {
        ActivePlanHomeCard(
            plan: samplePlan,
            currentStreak: 10,
            onTap: {}
        )
        .environmentObject(ThemeManager())
    }
    .padding(.vertical, 20)
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Banner Section") {
    VStack {
        NutritionHomeBannerSection()
            .padding()
    }
    .background(Color.black)
    .environmentObject(NutritionService.shared)
    .environmentObject(ThemeManager())
}
