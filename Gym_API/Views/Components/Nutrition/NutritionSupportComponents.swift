import SwiftUI

// MARK: - CompletedPlanBadge (Extended)

/// Badge extendido para planes completados con mas detalles
struct CompletedPlanBadgeExtended: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 16) {
                // Trophy with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                }

                VStack(spacing: 6) {
                    Text(plan.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("\(plan.durationDays) dias completados")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    // Rating if available
                    if let rating = plan.avgSatisfaction, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                }
            }
            .frame(width: 120)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.4), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - QuickStatsRow

/// Fila rapida de estadisticas para el dashboard
struct QuickStatsRow: View {
    let stats: UserNutritionStats

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            QuickStatItem(
                icon: "flame.fill",
                value: "\(stats.completionStreak)",
                label: "Racha",
                color: .orange
            )
            .environmentObject(themeManager)

            QuickStatItem(
                icon: "percent",
                value: "\(Int(stats.weeklyAverage))%",
                label: "Semanal",
                color: .blue
            )
            .environmentObject(themeManager)

            QuickStatItem(
                icon: "fork.knife",
                value: "\(stats.totalMealsCompleted)",
                label: "Comidas",
                color: .green
            )
            .environmentObject(themeManager)
        }
    }
}

// MARK: - QuickStatItem

/// Item individual de estadistica rapida
struct QuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - EmptyNutritionState

/// Vista de estado vacio para nutricion
struct EmptyNutritionState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    init(
        icon: String = "fork.knife.circle",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - NutritionErrorView

/// Vista de error para nutricion
struct NutritionErrorView: View {
    let message: String
    let retryAction: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Algo salio mal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)

            Button(action: retryAction) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Reintentar")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

// MARK: - SectionHeader

/// Header reutilizable para secciones
struct NutritionSectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color = .clear,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor == .clear
                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                            : iconColor)
                }

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            // Section Headers
            VStack(spacing: 16) {
                Text("Section Headers")
                    .font(.headline)
                    .foregroundColor(.white)

                NutritionSectionHeader(
                    title: "Challenges LIVE",
                    icon: "dot.radiowaves.left.and.right",
                    iconColor: .red
                )

                NutritionSectionHeader(
                    title: "Mis Planes",
                    subtitle: "3 activos",
                    actionTitle: "Ver todos",
                    action: { }
                )
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            // Quick Stats
            VStack(spacing: 16) {
                Text("Quick Stats")
                    .font(.headline)
                    .foregroundColor(.white)

                QuickStatsRow(stats: UserNutritionStats(
                    completionStreak: 7,
                    weeklyAverage: 85.0,
                    totalPlansFollowed: 3,
                    totalMealsCompleted: 42,
                    bestStreak: 14,
                    averageSatisfaction: 4.5,
                    totalPhotosUploaded: 10
                ))
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            // Empty State
            VStack(spacing: 16) {
                Text("Empty State")
                    .font(.headline)
                    .foregroundColor(.white)

                EmptyNutritionState(
                    title: "No hay planes",
                    message: "Explora planes de nutricion disponibles",
                    actionTitle: "Explorar",
                    action: { }
                )
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            // Error View
            VStack(spacing: 16) {
                Text("Error View")
                    .font(.headline)
                    .foregroundColor(.white)

                NutritionErrorView(
                    message: "No se pudieron cargar los datos",
                    retryAction: { }
                )
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
