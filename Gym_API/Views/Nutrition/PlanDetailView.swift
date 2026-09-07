import SwiftUI

// MARK: - PlanDetailView (Prototype-matched)

struct PlanDetailView: View {
    let plan: NutritionPlan

    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var joined: Bool = false
    @State private var showConfirmSheet = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let accentColor = Color(hex: "#D4FF3F")!

    private var isLive: Bool { plan.planType == .live }

    private var goalColor: Color {
        switch plan.goal {
        case .cut: return Color(hex: "#FF5A1F")!
        case .bulk: return Color(hex: "#3B82F6")!
        case .maintenance: return Color(hex: "#4ADE80")!
        case .weightLoss: return Color(hex: "#F472B6")!
        case .muscleGain: return Color(hex: "#A78BFA")!
        case .performance: return Color(hex: "#D4FF3F")!
        }
    }

    private var goalLabel: String { plan.goal.displayName.uppercased() }

    private var macroSplit: (p: Int, c: Int, f: Int) {
        let pKcal = (plan.targetProteinG ?? 0) * 4
        let cKcal = (plan.targetCarbsG ?? 0) * 4
        let fKcal = (plan.targetFatG ?? 0) * 9
        let total = max(pKcal + cKcal + fKcal, 1)
        return (
            p: Int((pKcal / total) * 100),
            c: Int((cKcal / total) * 100),
            f: Int((fKcal / total) * 100)
        )
    }

    private var fillPct: Double {
        guard plan.liveParticipantsCount > 0 else { return 50 }
        return Double(plan.liveParticipantsCount) / 60.0 * 100
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. HERO (280px)
                    heroSection

                    // 2. CTA card overlapping
                    creatorCard
                        .padding(.horizontal, 20)
                        .offset(y: -28)
                        .zIndex(3)

                    // 3. Description
                    descriptionSection
                        .padding(.horizontal, 20)
                        .padding(.top, -8)

                    // 4. Macro target card
                    macroTargetCard
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 5. What's included
                    whatsIncludedCard
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 6. Tags
                    if !plan.tags.isEmpty {
                        tagsSection(plan.tags)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }

                    // 7. Sample day
                    sampleDayCard
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    Spacer(minLength: 120)
                }
            }

            // 8. Sticky CTA
            stickyCTA
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            joined = plan.isFollowedByUser
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showConfirmSheet) {
            confirmationSheet
        }
    }

    // MARK: - 1. Hero (280px)

    private var heroSection: some View {
        ZStack(alignment: .top) {
            // Background: real image if available, else gradient
            ZStack {
                Group {
                    if let imageName = goalImageName {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [goalColor, goalColor.opacity(0.5), Color(hex: "#0A0A0A")!.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(height: 280)
                .clipped()

                // Dark overlay for text readability
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 280)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32))

            VStack {
                // Nav bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        Button(action: {}) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // Bottom: badges + title
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        if isLive {
                            HStack(spacing: 5) {
                                Circle().fill(accentColor).frame(width: 6, height: 6)
                                Text("LIVE").font(.system(size: 10, weight: .heavy)).tracking(1.0)
                            }
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(Color.black.opacity(0.7)).clipShape(Capsule())
                        }

                        Text(goalLabel)
                            .font(.system(size: 10, weight: .heavy)).tracking(0.8)
                            .foregroundColor(goalColor)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(Color.black.opacity(0.7)).clipShape(Capsule())

                        Text("\(plan.durationDays) DAYS")
                            .font(.system(size: 10, weight: .bold)).tracking(0.6)
                            .foregroundColor(.white)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(Color.black.opacity(0.7)).clipShape(Capsule())
                    }

                    Text(plan.title)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .frame(height: 280)
    }

    // MARK: - 2. Creator Card (overlapping)

    private var creatorCard: some View {
        VStack(spacing: 0) {
            // Creator row
            HStack(spacing: 10) {
                Circle()
                    .fill(goalColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(creatorInitials)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.creatorName ?? "Coach")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Text("Nutrition")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                }

                Spacer()

                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(width: 40, height: 40)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }

            // Live info (followers + status)
            if isLive {
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2").font(.system(size: 11))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                            Text("\(plan.liveParticipantsCount)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            Text("plazas")
                                .font(.system(size: 11))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                        }
                        Spacer()
                        if plan.status == .running {
                            Text("DAY \(plan.currentDay ?? 0)/\(plan.durationDays)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor)
                        } else if let days = plan.daysUntilStart, days > 0 {
                            Text("Empieza en \(days)d")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.1))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(fillPct > 80 ? Color(hex: "#FF5A1F")! : goalColor)
                                .frame(width: geo.size.width * CGFloat(min(fillPct / 100, 1)))
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                        .padding(.top, 12)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - 3. Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Aviso médico completo, aquí y no solo en la lista: esta es la pantalla desde la
            // que se decide empezar un plan.
            NutritionDisclaimerView()
                .environmentObject(themeManager)

            Text("ABOUT")
                .font(.system(size: 9, weight: .bold)).tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            if let desc = plan.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    .lineSpacing(4)
            }

            // Info banner
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(accentColor)

                Text(isLive
                    ? "Plan LIVE: avanzas con tu cohorte. Cada día se publica una nueva comida. Si llegas tarde, puedes acceder a días anteriores."
                    : "Template: empieza cuando quieras. Todo el contenido disponible desde el primer día."
                )
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                .lineSpacing(2)
            }
            .padding(14)
            .background(accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.22), lineWidth: 1))
        }
    }

    // MARK: - 4. Macro Target Card

    private var macroTargetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OBJETIVO DIARIO")
                .font(.system(size: 9, weight: .bold)).tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 12) {
                // Calories header
                HStack {
                    Text("Calories")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Spacer()
                    Text("\(Int(plan.targetCalories ?? 0))")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(-0.4)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                // Macro proportion bar
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 100).fill(accentColor)
                        .frame(height: 8)
                        .layoutPriority(Double(macroSplit.p))
                    RoundedRectangle(cornerRadius: 100).fill(Color(hex: "#FF5A1F")!)
                        .frame(height: 8)
                        .layoutPriority(Double(macroSplit.c))
                    RoundedRectangle(cornerRadius: 100).fill(Color(hex: "#A78BFA")!)
                        .frame(height: 8)
                        .layoutPriority(Double(macroSplit.f))
                }
                .padding(.vertical, 2)

                // Macro columns
                HStack {
                    macroColumn(label: "Proteína", value: Int(plan.targetProteinG ?? 0), pct: macroSplit.p, color: accentColor)
                    Spacer()
                    macroColumn(label: "Carbos", value: Int(plan.targetCarbsG ?? 0), pct: macroSplit.c, color: Color(hex: "#FF5A1F")!)
                    Spacer()
                    macroColumn(label: "Grasas", value: Int(plan.targetFatG ?? 0), pct: macroSplit.f, color: Color(hex: "#A78BFA")!)
                }
            }
            .padding(16)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func macroColumn(label: String, value: Int, pct: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(0.5)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            + Text("g")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
            Text("\(pct)%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
        }
    }

    // MARK: - 5. What's Included

    private var whatsIncludedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT YOU GET")
                .font(.system(size: 9, weight: .bold)).tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 0) {
                includedRow(label: "Duración", value: "\(plan.durationDays) días\(plan.isRecurring ? " (recurrente)" : "")", showDivider: true)
                includedRow(label: "Dificultad", value: plan.difficultyLevel.displayName, color: difficultyColor, showDivider: true)
                includedRow(label: "Presupuesto", value: plan.budgetLevel.displayName, showDivider: true)
                includedRow(label: "Restricciones", value: dietaryLabel, showDivider: false)
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func includedRow(label: String, value: String, color: Color? = nil, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color ?? Color.dynamicText(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            }
        }
    }

    // MARK: - 6. Tags

    private func tagsSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FEATURES")
                .font(.system(size: 9, weight: .bold)).tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - 7. Sample Day

    private var sampleDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAMPLE DAY")
                .font(.system(size: 9, weight: .bold)).tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 0) {
                sampleMealRow(time: "08:00", name: "Bowl de avena con frutos rojos", kcal: 420, showDivider: true)
                sampleMealRow(time: "14:00", name: "Pollo a la plancha con quinoa", kcal: 547, showDivider: true)
                sampleMealRow(time: "20:30", name: "Salmón al horno con verduras", kcal: 480, showDivider: false)
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

            Text("+ 2 snacks · \(Int(plan.targetCalories ?? 1800)) kcal totales")
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    private func sampleMealRow(time: String, name: String, kcal: Int, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(time)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    .frame(width: 40, alignment: .leading)

                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 2) {
                    Text("\(kcal)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                    Text("kcal")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            }
        }
    }

    // MARK: - 8. Sticky CTA

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0), Color.dynamicBackground(theme: themeManager.currentTheme)],
                startPoint: .top, endPoint: .center
            )
            .frame(height: 30)
            .allowsHitTesting(false)

            Button(action: {
                if !joined { showConfirmSheet = true }
            }) {
                HStack(spacing: 8) {
                    if joined {
                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                        Text("You are already enrolled").font(.system(size: 16, weight: .bold))
                    } else {
                        Text("Unirse al plan").font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundColor(joined ? Color.dynamicText(theme: themeManager.currentTheme) : Color.accentInk)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(joined ? Color.dynamicSurface(theme: themeManager.currentTheme) : accentColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(joined ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 6)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
    }

    // MARK: - Confirmation Sheet

    private var confirmationSheet: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule().fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12).padding(.bottom, 24)

            // Icon
            Image(systemName: "fork.knife")
                .font(.system(size: 30))
                .foregroundColor(goalColor)
                .frame(width: 64, height: 64)
                .background(goalColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 16)

            // Title
            Text("Confirm enrollment")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.bottom, 6)

            Text("\(plan.title) · \(plan.durationDays) days")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                .padding(.bottom, 24)

            // Benefits
            VStack(spacing: 10) {
                benefitRow(icon: "bell.fill", text: "Recibirás notificaciones a las horas de comida")
                benefitRow(icon: "bubble.left.fill", text: "Te unirás al chat del plan con otros participantes")
                benefitRow(icon: "calendar", text: isLive ? "El plan empieza \(plan.daysUntilStart == 0 ? "hoy" : "en \(plan.daysUntilStart ?? 0) días")" : "Puedes empezar ahora mismo")
                benefitRow(icon: "checkmark", text: "Puedes salir del plan cuando quieras")
            }
            .padding(16)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Join button
            Button(action: {
                Task { await joinPlan() }
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(Color.accentInk)
                    } else {
                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                        Text("Confirm enrollment").font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundColor(Color.accentInk)
                .background(RoundedRectangle(cornerRadius: 14).fill(accentColor))
            }
            .disabled(isLoading)
            .padding(.horizontal, 20)

            // Cancel
            Button(action: { showConfirmSheet = false }) {
                Text("Cancel")
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                    .padding(.vertical, 14)
            }

            Spacer(minLength: 20)
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(accentColor)
                .frame(width: 28, height: 28)
                .background(accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                .lineSpacing(2)
        }
    }

    // MARK: - Helpers

    private var goalImageName: String? {
        switch plan.goal {
        case .cut, .weightLoss: return "NutritionPlans/cut_image"
        case .bulk, .muscleGain: return "NutritionPlans/bulk_image"
        case .maintenance: return "NutritionPlans/maintain_image"
        case .performance: return "NutritionPlans/performance_image"
        }
    }

    private var creatorInitials: String {
        let name = plan.creatorName ?? "C"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var difficultyColor: Color {
        switch plan.difficultyLevel {
        case .beginner: return Color(hex: "#4ADE80")!
        case .intermediate: return Color(hex: "#FFB347")!
        case .advanced: return Color(hex: "#FF5A1F")!
        }
    }

    private var dietaryLabel: String {
        let restrictions = plan.dietaryRestrictions.filter { $0 != .none }
        if restrictions.isEmpty { return "Sin restricciones" }
        return restrictions.map { $0.displayName }.joined(separator: ", ")
    }

    private func joinPlan() async {
        isLoading = true
        let success = await nutritionService.followPlan(planId: plan.id)
        isLoading = false

        if success {
            joined = true
            showConfirmSheet = false
            HapticManager.shared.play(.success)
        } else {
            errorMessage = nutritionService.errorMessage ?? "Error al unirse al plan"
            showError = true
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: ProposedViewSize(result.sizes[index])
            )
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
