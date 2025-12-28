import SwiftUI

// MARK: - NutritionLiveChallengeBanner

/// Banner prominente para challenges LIVE activos
/// Se muestra en HomeView cuando el usuario tiene un plan activo
struct NutritionLiveChallengeBanner: View {
    // MARK: - Properties

    let plan: NutritionPlan
    let progress: DayProgress
    let onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    // MARK: - Initialization

    init(
        plan: NutritionPlan,
        progress: DayProgress,
        onTap: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.progress = progress
        self.onTap = onTap
    }

    // MARK: - Body

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: 16) {
                // Header Row
                headerRow

                // Participants & Day Info
                participantsRow

                // Progress Bar + Celebration
                VStack(spacing: 8) {
                    MealProgressBar(
                        mealsCompleted: progress.mealsCompleted,
                        totalMeals: progress.totalMeals
                    )
                    .environmentObject(themeManager)

                    // Mensaje motivacional si completó todas las comidas
                    if progress.mealsCompleted == progress.totalMeals {
                        HStack(spacing: 6) {
                            Text("🎉")
                                .font(.system(size: 13))
                            Text("¡Día completo! Sigue así")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // CTA Row
                ctaRow
            }
            .padding(20)
            .background(bannerBackground)
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

    // MARK: - Private Views

    private var headerRow: some View {
        HStack(spacing: 8) {
            LivePulseIndicator(size: 10)

            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.red)

            Text(plan.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1)

            Spacer()

            // Badge de racha diaria - por ahora mostrar si tiene buen progreso
            if progress.percentage >= 80 {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 12))
                    Text("En racha")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                )
            }
        }
    }

    private var participantsRow: some View {
        HStack {
            ParticipantAvatarStack(
                participantsCount: plan.liveParticipantsCount,
                maxAvatars: 3,
                avatarSize: 28
            )
            .environmentObject(themeManager)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(dayText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("\(plan.liveParticipantsCount) personas activas")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }

    private var ctaRow: some View {
        HStack {
            // Macro summary (más compacto)
            HStack(spacing: 12) {
                macroIndicator(
                    value: progress.caloriesConsumed,
                    target: progress.caloriesTarget,
                    unit: "kcal",
                    color: .orange
                )

                macroIndicator(
                    value: progress.proteinConsumed,
                    target: progress.proteinTarget,
                    unit: "g",
                    color: .green
                )
            }

            Spacer()

            // CTA MEJORADO: Más prominente con gradiente
            HStack(spacing: 6) {
                Text("VER MI DÍA")
                    .font(.system(size: 15, weight: .bold))
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 8, y: 4)
        }
    }

    private func macroIndicator(value: Int, target: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: color == .orange ? "flame.fill" : "leaf.fill")
                .font(.system(size: 11))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)/\(target)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }

    // MARK: - Styling

    private var bannerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.5),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
    }

    // MARK: - Helpers

    private var dayText: String {
        let currentDay = plan.currentDay ?? 1
        return "DIA \(currentDay) DE \(plan.durationDays)"
    }

    private func handleTap() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        onTap?()
    }
}

// MARK: - NutritionUpcomingChallengeBanner

/// Banner para challenges que estan por empezar
struct NutritionUpcomingChallengeBanner: View {
    let plan: NutritionPlan
    let onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    init(plan: NutritionPlan, onTap: (() -> Void)? = nil) {
        self.plan = plan
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("PROXIMO")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )

                    Spacer()

                    if let daysUntilStart = plan.daysUntilStart {
                        Text("Empieza en \(daysUntilStart) dia\(daysUntilStart == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                // Title
                Text(plan.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                // Info row
                HStack {
                    ParticipantsRow(
                        participantsCount: plan.liveParticipantsCount,
                        text: "inscritos"
                    )
                    .environmentObject(themeManager)

                    Spacer()

                    Text("Reservar lugar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
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

// MARK: - NutritionDiscoverBanner

/// Banner para descubrir nuevos planes cuando no hay plan activo
struct NutritionDiscoverBanner: View {
    let onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap?()
        }) {
            ZStack(alignment: .topTrailing) {
                // Main content
                VStack(alignment: .leading, spacing: 12) {
                    // Badge "DESCUBRE" with emoji
                    HStack(spacing: 6) {
                        Text("✨")
                            .font(.system(size: 14))
                        Text("DESCUBRE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )

                    // Title
                    Text("Planes de Nutrición")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    // Description
                    Text("Alcanza tus objetivos con planes personalizados")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)

                    Spacer()

                    // Social proof stats
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                            Text("250+ activos")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.85))

                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                            Text("4.8 rating")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 140) // Increased height for better presence

                // CTA Button (top-right)
                Text("EXPLORAR")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding([.top, .trailing], 16)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#11998E") ?? .green,  // Verde esmeralda
                        Color(hex: "#38EF7D") ?? .green   // Verde teal brillante
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.green.opacity(0.3), radius: 20, y: 10)
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

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Nutrition Banners")
                .font(.headline)
                .foregroundColor(.white)

            // Discover Banner (cuando no hay plan activo)
            NutritionDiscoverBanner {
                print("Explore tapped")
            }

            Divider()
                .background(Color.gray)

            Text("Los banners de challenge LIVE se mostraran aqui con datos reales del API")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
