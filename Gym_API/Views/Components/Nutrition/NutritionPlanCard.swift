import SwiftUI

// MARK: - NutritionPlanCard

/// Tarjeta completa para mostrar un plan de nutricion
/// Incluye tipo, titulo, descripcion, stats y CTA
struct NutritionPlanCard: View {
    // MARK: - Properties

    let plan: NutritionPlan
    let onTap: (() -> Void)?
    let onAction: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Initialization

    init(
        plan: NutritionPlan,
        onTap: (() -> Void)? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.onTap = onTap
        self.onAction = onAction
    }

    // MARK: - Body

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with type badge and participants
                headerRow

                // Title
                titleSection

                // Description
                if let description = plan.description, !description.isEmpty {
                    descriptionText(description)
                }

                // Stats pills
                statsRow

                // Live-specific info
                if plan.planType == .live {
                    liveInfoSection
                }

                // CTA Button
                ctaButton
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(plan.isFollowedByUser ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Private Views

    private var headerRow: some View {
        HStack {
            PlanTypeBadge(planType: plan.planType)
                .environmentObject(themeManager)

            Spacer()

            if plan.planType == .live {
                ParticipantCountLabel(count: plan.liveParticipantsCount)
                    .environmentObject(themeManager)
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(2)

            // Goal badge
            HStack(spacing: 4) {
                Image(systemName: plan.goal.icon)
                    .font(.system(size: 10))
                Text(plan.goal.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
    }

    private func descriptionText(_ description: String) -> some View {
        Text(description)
            .font(.system(size: 14))
            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            .lineLimit(2)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatPill(icon: "calendar", text: "\(plan.durationDays) dias")
                .environmentObject(themeManager)

            if let calories = plan.targetCalories {
                StatPill(icon: "flame.fill", text: "\(calories) kcal")
                    .environmentObject(themeManager)
            }

            StatPill(icon: plan.difficultyLevel.color == "green" ? "leaf" : "bolt", text: plan.difficultyLevel.displayName)
                .environmentObject(themeManager)
        }
    }

    @ViewBuilder
    private var liveInfoSection: some View {
        if let status = plan.status {
            VStack(alignment: .leading, spacing: 4) {
                switch status {
                case .notStarted:
                    if let daysUntilStart = plan.daysUntilStart {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("Empieza en \(daysUntilStart) dia\(daysUntilStart == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                case .running:
                    if let currentDay = plan.currentDay {
                        HStack(spacing: 4) {
                            LivePulseIndicator(size: 8)
                            Text("Dia \(currentDay) de \(plan.durationDays)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red)
                    }
                case .finished:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Challenge completado")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.green)
                }
            }
        }
    }

    private var ctaButton: some View {
        Button(action: { onAction?() }) {
            HStack {
                Text(plan.primaryActionText)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Image(systemName: ctaIcon)
            }
            .foregroundColor(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ctaColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private var ctaColor: Color {
        if plan.isFollowedByUser {
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        }

        switch plan.status {
        case .finished:
            return .gray
        default:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        }
    }

    private var ctaIcon: String {
        if plan.isFollowedByUser {
            return "chart.line.uptrend.xyaxis"
        }

        switch plan.status {
        case .notStarted:
            return "calendar.badge.plus"
        case .running:
            return "arrow.right"
        case .finished:
            return "info.circle"
        case .none:
            return "play.fill"
        }
    }
}

// MARK: - StatPill

/// Pill para mostrar una estadistica
struct StatPill: View {
    let icon: String
    let text: String

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
        )
    }
}

// MARK: - CompactPlanCard

/// Version compacta de NutritionPlanCard para listas horizontales
struct CompactPlanCard: View {
    let plan: NutritionPlan
    let width: CGFloat
    let onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    init(plan: NutritionPlan, width: CGFloat = 280, onTap: (() -> Void)? = nil) {
        self.plan = plan
        self.width = width
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    PlanTypeBadge(planType: plan.planType)
                        .environmentObject(themeManager)

                    Spacer()

                    if plan.isFollowedByUser {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                }

                // Title
                Text(plan.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(2)

                // Quick stats
                HStack(spacing: 8) {
                    Label("\(plan.durationDays)d", systemImage: "calendar")
                    if let calories = plan.targetCalories {
                        Label("\(calories)", systemImage: "flame.fill")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Spacer()

                // Participants for live
                if plan.planType == .live {
                    ParticipantsRow(participantsCount: plan.liveParticipantsCount, text: "activos")
                        .environmentObject(themeManager)
                }
            }
            .padding(16)
            .frame(width: width, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - PlanCarousel

/// Carousel horizontal de planes de nutricion
struct PlanCarousel: View {
    let title: String
    let plans: [NutritionPlan]
    let onPlanTap: ((NutritionPlan) -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    init(title: String, plans: [NutritionPlan], onPlanTap: ((NutritionPlan) -> Void)? = nil) {
        self.title = title
        self.plans = plans
        self.onPlanTap = onPlanTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                if plans.count > 2 {
                    Text("Ver todos")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 20)

            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(plans) { plan in
                        CompactPlanCard(plan: plan) {
                            onPlanTap?(plan)
                        }
                        .environmentObject(themeManager)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("Nutrition Plan Cards")
                .font(.headline)
                .foregroundColor(.white)

            // Sample cards would be shown here with real data
            Text("Las tarjetas de planes se mostraran aqui con datos reales del API")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()

            // Stat Pills
            VStack(spacing: 12) {
                Text("Stat Pills")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    StatPill(icon: "calendar", text: "21 dias")
                    StatPill(icon: "flame.fill", text: "2000 kcal")
                    StatPill(icon: "leaf", text: "Principiante")
                }
            }
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
