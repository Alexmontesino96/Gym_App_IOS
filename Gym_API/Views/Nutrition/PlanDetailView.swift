import SwiftUI

// MARK: - PlanDetailView

/// Vista de detalle completa para un plan de nutricion
/// Incluye:
/// - Imagen/header del plan
/// - Informacion completa
/// - Seccion "Que incluye"
/// - Descripcion
/// - Reviews/rating
/// - CTA principal
struct PlanDetailView: View {
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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with gradient
                headerSection
                    .opacity(appearAnimation ? 1 : 0)

                // Content
                VStack(spacing: 24) {
                    // Title & Meta
                    titleSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Stats Row
                    statsSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // What's Included
                    whatsIncludedSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Description
                    if let description = plan.description, !description.isEmpty {
                        descriptionSection(description)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                    }

                    // Dietary Restrictions
                    if !plan.dietaryRestrictions.isEmpty && !plan.dietaryRestrictions.contains(.none) {
                        dietaryRestrictionsSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                    }

                    // Reviews & Rating
                    if (plan.followersCount ?? 0) > 0 || plan.avgSatisfaction != nil {
                        ratingsSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                    }

                    // Creator Info
                    creatorSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Bottom spacing for CTA
                    Spacer()
                        .frame(height: 100)
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
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: sharePlan) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Unirse al Plan", isPresented: $showConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Unirme") {
                Task { await joinPlan() }
            }
        } message: {
            Text("Vas a unirte a \"\(plan.title)\". Recibiras notificaciones para recordarte tus comidas.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient Background
            LinearGradient(
                colors: [
                    Color.dynamicAccent(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)

            // Pattern Overlay
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: CGFloat.random(in: 50...150))
                            .offset(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...200)
                            )
                    }
                }
            }
            .frame(height: 200)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Plan Type Badge
                HStack(spacing: 8) {
                    if plan.planType == .live {
                        LivePulseIndicator(size: 10)
                    }
                    Text(plan.typeLabel)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )

                // Goal Icon
                Image(systemName: plan.goal.icon)
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .padding(24)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Goal & Difficulty
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: plan.goal.icon)
                        .font(.system(size: 14))
                    Text(plan.goal.displayName)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                HStack(spacing: 6) {
                    Image(systemName: plan.difficultyLevel.iconName)
                        .font(.system(size: 14))
                    Text(plan.difficultyLevel.displayName)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Status for LIVE plans
            if plan.planType == .live {
                liveStatusBadge
            }
        }
    }

    @ViewBuilder
    private var liveStatusBadge: some View {
        if let status = plan.status {
            HStack(spacing: 8) {
                switch status {
                case .notStarted:
                    if let days = plan.daysUntilStart {
                        Image(systemName: "clock.fill")
                        Text("Empieza en \(days) dia\(days == 1 ? "" : "s")")
                    }
                case .running:
                    LivePulseIndicator(size: 8)
                    Text("Dia \(plan.currentDay ?? 1) de \(plan.durationDays)")
                case .finished:
                    Image(systemName: "checkmark.circle.fill")
                    Text("Completado")
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(statusColor.opacity(0.15))
            )
        }
    }

    private var statusColor: Color {
        switch plan.status {
        case .notStarted: return .orange
        case .running: return .red
        case .finished: return .green
        case .none: return .gray
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 0) {
            // Duration
            statItem(
                icon: "calendar",
                value: "\(plan.durationDays)",
                label: "dias"
            )

            Divider()
                .frame(height: 40)

            // Calories
            if let calories = plan.targetCalories {
                statItem(
                    icon: "flame.fill",
                    value: "\(Int(calories))",
                    label: "kcal/dia"
                )

                Divider()
                    .frame(height: 40)
            }

            // Participants (LIVE)
            if plan.planType == .live {
                statItem(
                    icon: "person.2.fill",
                    value: "\(plan.liveParticipantsCount)",
                    label: "personas"
                )
            } else {
                // Followers (Template)
                statItem(
                    icon: "person.fill",
                    value: "\(plan.followersCount ?? 0)",
                    label: "usuarios"
                )
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - What's Included Section

    private var whatsIncludedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Que incluye")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            VStack(spacing: 12) {
                includedItem(icon: "fork.knife", text: "Comidas diarias planificadas")
                includedItem(icon: "list.bullet", text: "Ingredientes detallados")
                includedItem(icon: "clock", text: "Tiempos de preparacion")

                if plan.planType == .live {
                    includedItem(icon: "person.3.fill", text: "Comunidad de participantes")
                    includedItem(icon: "chart.bar.fill", text: "Ranking y progreso grupal")
                }

                if plan.targetProteinG != nil || plan.targetCarbsG != nil {
                    includedItem(icon: "chart.pie", text: "Macros calculados")
                }

                includedItem(icon: "bell.fill", text: "Recordatorios de comidas")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    private func includedItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 20)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()
        }
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Descripcion")
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

    // MARK: - Dietary Restrictions Section

    private var dietaryRestrictionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restricciones Alimentarias")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            FlowLayout(spacing: 10) {
                ForEach(plan.dietaryRestrictions.filter { $0 != .none }, id: \.self) { restriction in
                    HStack(spacing: 6) {
                        Image(systemName: restriction.icon)
                            .font(.system(size: 12))
                        Text(restriction.displayName)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Ratings Section

    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Valoraciones")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            HStack(spacing: 24) {
                // Rating
                if let rating = plan.avgSatisfaction, rating > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text(String(format: "%.1f de 5", rating))
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }

                // Users Count
                VStack(spacing: 4) {
                    Text("\(plan.followersCount ?? 0)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Text("usuarios han completado")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Creator Section

    private var creatorSection: some View {
        HStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text((plan.creatorName ?? "?").prefix(1).uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Creado por")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                Text(plan.creatorName ?? "Desconocido")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()
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

            HStack(spacing: 16) {
                if plan.isFollowedByUser {
                    // Already Following
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Inscrito")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green.opacity(0.15))
                    )
                } else if plan.status == .finished {
                    // Finished
                    Text("Challenge Finalizado")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                } else {
                    // Join Button
                    Button(action: {
                        showConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: ctaIcon)
                                Text(plan.primaryActionText)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
            )
        }
    }

    private var ctaIcon: String {
        switch plan.status {
        case .notStarted: return "calendar.badge.plus"
        case .running: return "play.fill"
        default: return "plus.circle.fill"
        }
    }

    // MARK: - Actions

    private func joinPlan() async {
        isLoading = true

        let success = await nutritionService.followPlan(planId: plan.id)

        isLoading = false

        if success {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            dismiss()
        } else {
            errorMessage = nutritionService.errorMessage ?? "Error al unirse al plan"
            showError = true
        }
    }

    private func sharePlan() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        // Share functionality would be implemented here
    }
}

// MARK: - FlowLayout

/// Layout que permite fluir elementos en multiples lineas
struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: ProposedViewSize(result.sizes[index]))
        }
    }

    struct FlowResult {
        var sizes: [CGSize] = []
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                sizes.append(size)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            height = currentY + lineHeight
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlanDetailView(plan: NutritionPlan(
            id: 1,
            title: "Challenge Detox 21 Dias",
            description: "Un plan completo para limpiar tu cuerpo y resetear tus habitos alimenticios.",
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
