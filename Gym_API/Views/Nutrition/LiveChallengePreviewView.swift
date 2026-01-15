import SwiftUI

// MARK: - LiveChallengePreviewView

/// Vista especifica para preview de challenges LIVE
/// Incluye:
/// - Contador regresivo animado
/// - Participantes inscritos con avatares
/// - Beneficios del challenge
/// - CTA para unirse
struct LiveChallengePreviewView: View {
    // MARK: - Properties

    let plan: NutritionPlan

    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appearAnimation = false
    @State private var countdownTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection
                    .opacity(appearAnimation ? 1 : 0)

                // Content
                VStack(spacing: 24) {
                    // Countdown Section
                    if plan.status == .notStarted {
                        countdownSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                    }

                    // Status Section (if running)
                    if plan.status == .running {
                        runningStatusSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                    }

                    // Participants Section
                    participantsSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Benefits Section
                    benefitsSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Challenge Details
                    detailsSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Description
                    if let description = plan.description, !description.isEmpty {
                        descriptionSection(description)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                    }

                    // Bottom spacing for CTA
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
        .overlay(alignment: .bottom) {
            ctaSection
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: sharePlan) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Unirse al Challenge", isPresented: $showConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Unirme") {
                Task { await joinChallenge() }
            }
        } message: {
            Text("Vas a unirte a \"\(plan.title)\". Recibiras notificaciones diarias para completar tus comidas.")
        }
        .onAppear {
            setupCountdown()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background
            LinearGradient(
                colors: [.red, .red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            // Animated Circles
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: CGFloat.random(in: 40...120))
                            .offset(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...280)
                            )
                    }
                }
            }
            .frame(height: 280)

            // Content
            VStack(spacing: 16) {
                // LIVE Badge
                HStack(spacing: 8) {
                    LivePulseIndicator(size: 12)
                    Text("LIVE CHALLENGE")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )

                // Title
                Text(plan.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Creator
                Text("por \(plan.creatorName)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Countdown Section

    private var countdownSection: some View {
        VStack(spacing: 16) {
            Text("Empieza en")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            HStack(spacing: 12) {
                countdownUnit(value: days, label: "DIAS")
                countdownSeparator
                countdownUnit(value: hours, label: "HORAS")
                countdownSeparator
                countdownUnit(value: minutes, label: "MIN")
                countdownSeparator
                countdownUnit(value: seconds, label: "SEG")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.red.opacity(0.5), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .monospacedDigit()

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
    }

    private var countdownSeparator: some View {
        Text(":")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            .opacity(0.5)
    }

    // MARK: - Running Status Section

    private var runningStatusSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                LivePulseIndicator(size: 12)

                Text("EN CURSO AHORA")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("DIA")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Text("\(plan.currentDay ?? 1)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Text("de \(plan.durationDays)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Rectangle()
                    .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                    .frame(width: 1, height: 60)

                VStack(spacing: 4) {
                    Text("PARTICIPANTES")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Text("\(plan.liveParticipantsCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Text("activos")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Participantes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text("\(plan.liveParticipantsCount) inscritos")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            HStack(spacing: 16) {
                // Avatar Stack (larger)
                ParticipantAvatarStack(
                    participantsCount: plan.liveParticipantsCount,
                    maxAvatars: 5,
                    avatarSize: 44
                )
                .environmentObject(themeManager)

                Spacer()

                // Join indicator
                if !plan.isFollowedByUser {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 24))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        Text("Unete")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text("Inscrito")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                Text("Por que unirte")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            VStack(spacing: 14) {
                benefitItem(
                    icon: "person.3.fill",
                    title: "Comunidad Activa",
                    description: "Unete a \(plan.liveParticipantsCount) personas trabajando juntas"
                )

                benefitItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Ranking en Tiempo Real",
                    description: "Compite y motivate con el progreso del grupo"
                )

                benefitItem(
                    icon: "bell.badge.fill",
                    title: "Recordatorios Diarios",
                    description: "Nunca olvides tus comidas con alertas personalizadas"
                )

                benefitItem(
                    icon: "trophy.fill",
                    title: "Logros Desbloqueables",
                    description: "Gana badges al completar dias y hitos"
                )

                benefitItem(
                    icon: "calendar.badge.checkmark",
                    title: "\(plan.durationDays) Dias de Plan",
                    description: "Comidas planificadas para cada dia del challenge"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    private func benefitItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detalles del Challenge")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                detailCard(icon: "flame.fill", label: "Objetivo", value: plan.goal.displayName)
                detailCard(icon: "speedometer", label: "Dificultad", value: plan.difficultyLevel.displayName)

                if let calories = plan.targetCalories {
                    detailCard(icon: "bolt.fill", label: "Calorias", value: "\(Int(calories)) kcal")
                }

                detailCard(icon: "dollarsign.circle", label: "Presupuesto", value: plan.budgetLevel.displayName)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    private func detailCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acerca del Challenge")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(description)
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .lineSpacing(4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.dynamicBorder(theme: themeManager.currentTheme))

            VStack(spacing: 12) {
                if plan.isFollowedByUser {
                    // Already Enrolled
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ya estas inscrito")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)

                            if plan.status == .notStarted {
                                Text("Te notificaremos cuando empiece")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                } else {
                    // Join Button
                    Button(action: {
                        showConfirmation = true
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: plan.status == .notStarted ? "calendar.badge.plus" : "play.fill")
                                    .font(.system(size: 18))
                                Text(plan.status == .notStarted ? "RESERVAR MI LUGAR" : "UNIRME AHORA")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .red.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 20)

                    // Urgency text
                    if plan.status == .notStarted, let days = plan.daysUntilStart, days <= 3 {
                        Text("Solo quedan \(days) dia\(days == 1 ? "" : "s") para inscribirte")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 16)
            .background(
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
            )
        }
    }

    // MARK: - Countdown Helpers

    private var days: Int {
        Int(timeRemaining) / 86400
    }

    private var hours: Int {
        (Int(timeRemaining) % 86400) / 3600
    }

    private var minutes: Int {
        (Int(timeRemaining) % 3600) / 60
    }

    private var seconds: Int {
        Int(timeRemaining) % 60
    }

    private func setupCountdown() {
        guard plan.status == .notStarted,
              let startDate = plan.liveStartDate else {
            return
        }

        timeRemaining = startDate.timeIntervalSinceNow

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                countdownTimer?.invalidate()
            }
        }
    }

    // MARK: - Actions

    private func joinChallenge() async {
        isLoading = true

        let success = await nutritionService.followPlan(planId: plan.id)

        isLoading = false

        if success {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            dismiss()
        } else {
            errorMessage = nutritionService.errorMessage ?? "Error al unirse al challenge"
            showError = true
        }
    }

    private func sharePlan() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        // Share functionality
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveChallengePreviewView(plan: NutritionPlan(
            id: 1,
            title: "Challenge Detox 21 Dias",
            description: "Un plan completo para limpiar tu cuerpo y resetear tus habitos alimenticios con comidas saludables y nutritivas.",
            planType: .live,
            goal: .weightLoss,
            difficultyLevel: .intermediate,
            budgetLevel: .medium,
            dietaryRestrictions: [.vegetarian],
            durationDays: 21,
            isRecurring: false,
            targetCalories: 1800,
            targetProteinG: 100,
            targetCarbsG: 200,
            targetFatG: 60,
            liveStartDate: Date().addingTimeInterval(86400 * 3),
            liveEndDate: nil,
            isLiveActive: true,
            liveParticipantsCount: 47,
            originalLivePlanId: nil,
            originalParticipantsCount: nil,
            archivedAt: nil,
            isFollowedByUser: false,
            currentDay: nil,
            status: .notStarted,
            daysUntilStart: 3,
            creatorId: 1,
            creatorName: "Nutricionista Pro",
            followersCount: 234,
            avgSatisfaction: 4.7,
            tags: ["detox", "limpieza"],
            isPublic: true,
            createdAt: Date(),
            updatedAt: nil
        ))
        .environmentObject(NutritionService.shared)
        .environmentObject(ThemeManager())
    }
}
