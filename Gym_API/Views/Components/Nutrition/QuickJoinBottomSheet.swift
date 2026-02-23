import SwiftUI

// MARK: - QuickJoinBottomSheet

/// Bottom sheet optimizado para unirse rapidamente a un plan LIVE
/// Reduce el friction mostrando solo informacion clave y un CTA claro
struct QuickJoinBottomSheet: View {
    // MARK: - Properties

    let plan: NutritionPlan
    let onJoin: () async -> Void
    let onViewDetails: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var isJoining = false
    @State private var hasAppeared = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            dragIndicator

            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    heroSection

                    // Benefits section
                    benefitsSection

                    // CTA section
                    ctaSection
                }
                .padding(24)
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .presentationDetents([.height(550), .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
            .frame(width: 40, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // LIVE badge or countdown
            if plan.isActiveLiveChallenge {
                liveBadge
            } else if plan.isUpcomingLiveChallenge {
                countdownBadge
            }

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
                    .frame(width: 80, height: 80)
                    .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: 15)

                Image(systemName: planIcon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Plan title
            Text(plan.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)

            // Quick stats
            HStack(spacing: 20) {
                quickStat(
                    icon: "calendar",
                    value: "\(plan.durationDays)",
                    label: plan.durationDays == 1 ? "día" : "días"
                )

                Divider()
                    .frame(height: 30)

                quickStat(
                    icon: "person.2.fill",
                    value: "\(plan.liveParticipantsCount ?? 0)",
                    label: "participantes"
                )

                if plan.isActiveLiveChallenge, let currentDay = plan.currentDay {
                    Divider()
                        .frame(height: 30)

                    quickStat(
                        icon: "chart.bar.fill",
                        value: "Día \(currentDay)",
                        label: "actual"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
        .scaleEffect(hasAppeared ? 1.0 : 0.95)
        .opacity(hasAppeared ? 1.0 : 0)
    }

    // MARK: - LIVE Badge

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Text("EN VIVO")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .tracking(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.red)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
    }

    // MARK: - Countdown Badge

    private var countdownBadge: some View {
        VStack(spacing: 4) {
            Text("COMIENZA PRONTO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .tracking(1)

            if let startDate = plan.liveStartDate {
                Text(formatCountdown(to: startDate))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("QUÉ INCLUYE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .tracking(1)

                Spacer()
            }
            .padding(.bottom, 16)

            // Benefits list
            VStack(spacing: 12) {
                BenefitRow(
                    icon: "calendar.badge.checkmark",
                    text: plan.durationDays == 1
                        ? "Plan nutricional de 1 día"
                        : "Plan nutricional de \(plan.durationDays) días completo"
                )

                BenefitRow(
                    icon: "person.2.fill",
                    text: "Comunidad activa con \(plan.liveParticipantsCount ?? 0)+ miembros"
                )

                BenefitRow(
                    icon: "bell.badge.fill",
                    text: "Recordatorios diarios de comidas"
                )

                if plan.isActiveLiveChallenge {
                    BenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Progreso sincronizado con el grupo"
                    )
                }
            }
        }
        .offset(y: hasAppeared ? 0 : 20)
        .opacity(hasAppeared ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 12) {
            // Primary CTA
            Button(action: {
                Task {
                    await handleJoin()
                }
            }) {
                HStack(spacing: 10) {
                    if isJoining {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: plan.isActiveLiveChallenge ? "play.fill" : "bookmark.fill")
                            .font(.system(size: 16))
                    }

                    Text(ctaText)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: gradientColors.first?.opacity(0.3) ?? .clear, radius: 10, y: 5)
            }
            .disabled(isJoining)

            // Secondary CTA - View details
            Button(action: {
                dismiss()
                onViewDetails()
            }) {
                HStack(spacing: 6) {
                    Text("Ver detalles completos")
                        .font(.system(size: 15, weight: .medium))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .offset(y: hasAppeared ? 0 : 20)
        .opacity(hasAppeared ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }

    // MARK: - Quick Stat

    private func quickStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private var ctaText: String {
        if isJoining {
            return "Uniéndote..."
        } else if plan.isActiveLiveChallenge {
            return "UNIRME AHORA"
        } else if plan.isUpcomingLiveChallenge {
            return "RESERVAR MI LUGAR"
        } else {
            return "COMENZAR PLAN"
        }
    }

    private var gradientColors: [Color] {
        let title = plan.title.lowercased()

        // Match gradient based on plan type/name
        if title.contains("detox") || title.contains("cleanse") {
            return [Color(hex: "#11998E") ?? .teal, Color(hex: "#38EF7D") ?? .green]
        } else if title.contains("músculo") || title.contains("muscular") || title.contains("masa") {
            return [Color(hex: "#FF6B6B") ?? .red, Color(hex: "#FF8E53") ?? .orange]
        } else if title.contains("pérdida") || title.contains("peso") || title.contains("definición") {
            return [Color(hex: "#4776E6") ?? .blue, Color(hex: "#8E54E9") ?? .purple]
        } else if title.contains("keto") || title.contains("cetog") {
            return [Color(hex: "#F2994A") ?? .orange, Color(hex: "#F2C94C") ?? .yellow]
        } else if title.contains("vegan") || title.contains("plant") {
            return [Color(hex: "#56AB2F") ?? .green, Color(hex: "#A8E063") ?? .green]
        }

        // Default LIVE gradient
        return [Color(hex: "#FF6B6B") ?? .red, Color(hex: "#FF8E53") ?? .orange]
    }

    private var planIcon: String {
        let title = plan.title.lowercased()

        if title.contains("detox") || title.contains("cleanse") {
            return "leaf.fill"
        } else if title.contains("músculo") || title.contains("muscular") {
            return "dumbbell.fill"
        } else if title.contains("pérdida") || title.contains("peso") {
            return "flame.fill"
        } else if title.contains("keto") {
            return "bolt.fill"
        } else if title.contains("vegan") {
            return "leaf.fill"
        }

        return "fork.knife"
    }

    // MARK: - Actions

    private func handleJoin() async {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        isJoining = true

        await onJoin()

        await MainActor.run {
            isJoining = false

            // Success feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)

            // Dismiss sheet
            dismiss()
        }
    }

    // MARK: - Helpers

    private func formatCountdown(to date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: date)

        if let days = components.day, days > 0 {
            return "En \(days) \(days == 1 ? "día" : "días")"
        } else if let hours = components.hour, hours > 0 {
            return "En \(hours) \(hours == 1 ? "hora" : "horas")"
        } else {
            return "¡Comienza hoy!"
        }
    }
}

// MARK: - BenefitRow

/// Fila individual de beneficio con icono y texto
struct BenefitRow: View {
    let icon: String
    let text: String

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Text
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview("Plan LIVE Activo") {
    let activePlan = NutritionPlan(
        id: 1,
        title: "Challenge Detox 21 Días",
        description: "Plan de detox completo",
        planType: .live,
        goal: .weightLoss,
        difficultyLevel: .intermediate,
        budgetLevel: .medium,
        dietaryRestrictions: [],
        durationDays: 21,
        isRecurring: false,
        liveStartDate: Date().addingTimeInterval(-5 * 24 * 3600),
        liveEndDate: Date().addingTimeInterval(16 * 24 * 3600),
        isLiveActive: true,
        liveParticipantsCount: 87,
        isFollowedByUser: false,
        tags: ["detox", "live"],
        isPublic: true,
        createdAt: Date()
    )

    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            QuickJoinBottomSheet(
                plan: activePlan,
                onJoin: {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                },
                onViewDetails: {}
            )
            .environmentObject(ThemeManager())
        }
}

#Preview("Plan LIVE Próximo") {
    let upcomingPlan = NutritionPlan(
        id: 2,
        title: "Plan de Ganancia Muscular",
        description: "Aumenta tu masa muscular",
        planType: .live,
        goal: .muscleGain,
        difficultyLevel: .advanced,
        budgetLevel: .premium,
        dietaryRestrictions: [],
        durationDays: 30,
        isRecurring: false,
        liveStartDate: Date().addingTimeInterval(3 * 24 * 3600),
        liveEndDate: Date().addingTimeInterval(33 * 24 * 3600),
        isLiveActive: false,
        liveParticipantsCount: 45,
        isFollowedByUser: false,
        tags: ["muscle", "live"],
        isPublic: true,
        createdAt: Date()
    )

    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            QuickJoinBottomSheet(
                plan: upcomingPlan,
                onJoin: {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                },
                onViewDetails: {}
            )
            .environmentObject(ThemeManager())
        }
}

#Preview("Plan Keto") {
    let ketoPlan = NutritionPlan(
        id: 3,
        title: "Plan Keto 14 Días",
        description: "Dieta cetogénica",
        planType: .live,
        goal: .cut,
        difficultyLevel: .intermediate,
        budgetLevel: .medium,
        dietaryRestrictions: [.keto],
        durationDays: 14,
        isRecurring: false,
        liveStartDate: Date().addingTimeInterval(-2 * 24 * 3600),
        liveEndDate: Date().addingTimeInterval(12 * 24 * 3600),
        isLiveActive: true,
        liveParticipantsCount: 120,
        isFollowedByUser: false,
        tags: ["keto", "live"],
        isPublic: true,
        createdAt: Date()
    )

    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            QuickJoinBottomSheet(
                plan: ketoPlan,
                onJoin: {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                },
                onViewDetails: {}
            )
            .environmentObject(ThemeManager())
        }
}

#Preview("Dark Mode") {
    let plan = NutritionPlan(
        id: 4,
        title: "Plan Vegano 7 Días",
        description: "Plant-based nutrition",
        planType: .live,
        goal: .maintenance,
        difficultyLevel: .beginner,
        budgetLevel: .economic,
        dietaryRestrictions: [.vegan],
        durationDays: 7,
        isRecurring: false,
        liveStartDate: Date(),
        liveEndDate: Date().addingTimeInterval(7 * 24 * 3600),
        isLiveActive: true,
        liveParticipantsCount: 65,
        isFollowedByUser: false,
        tags: ["vegan", "live"],
        isPublic: true,
        createdAt: Date()
    )

    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            QuickJoinBottomSheet(
                plan: plan,
                onJoin: {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                },
                onViewDetails: {}
            )
            .environmentObject(ThemeManager())
        }
        .preferredColorScheme(.dark)
}
