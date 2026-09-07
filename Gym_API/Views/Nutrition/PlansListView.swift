import SwiftUI

// MARK: - Plans List View (Prototype-matched)
/// Browse nutrition plans: segmented control (All/Live/Templates), goal filter chips,
/// user active plan, live plan cards (horizontal), template cards (vertical list)

struct PlansListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var nutritionService: NutritionService
    @Environment(\.dismiss) private var dismiss

    @State private var planType: PlanTypeFilter = .all
    @State private var goalFilter: NutritionGoal? = nil
    @State private var selectedPlan: NutritionPlan?
    @State private var showPlanDetail = false
    @State private var allPlans: [NutritionPlan] = []
    @State private var isLoading = false

    enum PlanTypeFilter: String, CaseIterable {
        case all, live, template
        var label: String {
            switch self {
            case .all: return "Todos"
            case .live: return "Live"
            case .template: return "Templates"
            }
        }
    }

    private var filteredPlans: [NutritionPlan] {
        // Los planes restrictivos se ocultan a propósito. El servidor los protege con un
        // cuestionario médico que todavía no tiene pantalla, así que pulsarlos devolvía 403 y
        // no había forma de resolverlo desde la app: eran imposibles de seguir. Un plan que
        // no se puede seguir es peor que un plan que no está. Ver isRestrictive.
        allPlans.filter { plan in
            guard !plan.isRestrictive else { return false }
            let typeMatch: Bool = {
                switch planType {
                case .all: return true
                case .live: return plan.planType == .live
                case .template: return plan.planType == .template
                }
            }()
            let goalMatch = goalFilter == nil || plan.goal == goalFilter
            return typeMatch && goalMatch
        }
    }

    private var livePlans: [NutritionPlan] { filteredPlans.filter { $0.planType == .live } }
    private var templatePlans: [NutritionPlan] { filteredPlans.filter { $0.planType == .template } }
    private var userPlans: [NutritionPlan] { allPlans.filter { $0.isFollowedByUser } }

    private let goalChips: [(id: NutritionGoal?, label: String, color: Color?)] = [
        (nil, "Todos", nil),
        (.cut, "Cut", Color(hex: "#FF5A1F")!),
        (.bulk, "Bulk", Color(hex: "#3B82F6")!),
        (.maintenance, "Mantener", Color(hex: "#4ADE80")!),
        (.weightLoss, "Pérdida", Color(hex: "#F472B6")!),
        (.muscleGain, "Ganancia", Color(hex: "#A78BFA")!),
        (.performance, "Rendimiento", Color(hex: "#D4FF3F")!),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection

                // Aviso médico. Guía 1.4.1: la app reparte planes de calorías y hasta ahora no
                // decía en ningún sitio lo que eso no es.
                NutritionDisclaimerView(compact: true)
                    .environmentObject(themeManager)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // User active plan
                if !userPlans.isEmpty {
                    userActivePlanSection
                }

                // Type segmented control
                typeSegmentedControl
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                // Goal filter chips
                goalFilterChips
                    .padding(.bottom, 24)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading plans…")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if allPlans.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                        Text("No plans available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Live plans (horizontal scroll)
                    if !livePlans.isEmpty && (planType == .all || planType == .live) {
                        livePlansSection
                    }

                    // Templates (vertical list)
                    if !templatePlans.isEmpty && (planType == .all || planType == .template) {
                        templatePlansSection
                    }
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showPlanDetail) {
            if let plan = selectedPlan {
                PlanDetailView(plan: plan)
                    .environmentObject(themeManager)
                    .environmentObject(nutritionService)
            }
        }
        .onAppear {
            loadPlansIfNeeded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Nav bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 40, height: 40)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .frame(width: 40, height: 40)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .frame(width: 40, height: 40)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Title
            VStack(alignment: .leading, spacing: 6) {
                Text("DESCUBRE PLANES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Text("Encuentra tu plan")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.8)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - User Active Plan

    private var userActivePlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TUS PLANES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                Spacer()
                Text("\(userPlans.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }
            .padding(.horizontal, 20)

            ForEach(userPlans) { plan in
                Button(action: {
                    selectedPlan = plan
                    showPlanDetail = true
                }) {
                    userPlanCard(plan)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    private func userPlanCard(_ plan: NutritionPlan) -> some View {
        let progress = Double(plan.currentDay ?? 0) / Double(max(plan.durationDays, 1)) * 100
        let accentColor = goalColor(for: plan.goal)

        return VStack(alignment: .leading, spacing: 8) {
            // LIVE + day counter
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "#D4FF3F")!)
                        .frame(width: 6, height: 6)
                    Text("LIVE · DAY \(plan.currentDay ?? 0)/\(plan.durationDays)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "#D4FF3F")!)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
            }

            // Title
            Text(plan.title)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.3)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Creator
            Text("por \(plan.creatorName ?? "Coach")")
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(progress / 100))
                }
            }
            .frame(height: 4)
            .padding(.top, 4)

            // Progress labels
            HStack {
                Text("\(Int(progress))% completado")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                Spacer()
                Text("\(plan.durationDays - (plan.currentDay ?? 0)) days left")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [accentColor.opacity(0.16), Color.dynamicSurface(theme: themeManager.currentTheme)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(accentColor.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Type Segmented Control

    @Namespace private var typeAnimation

    private var typeSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(PlanTypeFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        planType = filter
                    }
                }) {
                    Text(filter.label)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundColor(
                            planType == filter
                                ? Color.dynamicBackground(theme: themeManager.currentTheme)
                                : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45)
                        )
                        .background(
                            ZStack {
                                if planType == filter {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.dynamicText(theme: themeManager.currentTheme))
                                        .matchedGeometryEffect(id: "type_indicator", in: typeAnimation)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Goal Filter Chips

    private var goalFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(goalChips.enumerated()), id: \.offset) { _, chip in
                    let isActive = goalFilter == chip.id
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            goalFilter = chip.id
                        }
                    }) {
                        HStack(spacing: 5) {
                            if let color = chip.color {
                                Circle()
                                    .fill(color)
                                    .frame(width: 5, height: 5)
                            }
                            Text(chip.label)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .foregroundColor(
                            isActive
                                ? (chip.color ?? Color.dynamicText(theme: themeManager.currentTheme))
                                : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45)
                        )
                        .background(
                            isActive
                                ? Color.dynamicSurface(theme: themeManager.currentTheme)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    isActive
                                        ? (chip.color ?? Color.white.opacity(0.14))
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Live Plans Section

    private var livePlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLANES LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    Text("Empieza con tu cohorte")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.3)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                Spacer()
                Text("\(livePlans.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(livePlans) { plan in
                        Button(action: {
                            selectedPlan = plan
                            showPlanDetail = true
                        }) {
                            livePlanCard(plan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 28)
    }

    private func livePlanCard(_ plan: NutritionPlan) -> some View {
        let fillPct = plan.liveParticipantsCount > 0 ? Double(plan.liveParticipantsCount) / 60.0 * 100 : 50
        let isAlmostFull = fillPct > 80
        let isRunning = plan.status == .running
        let accentColor = goalColor(for: plan.goal)

        return VStack(alignment: .leading, spacing: 0) {
            // Image area with badges
            ZStack(alignment: .topLeading) {
                // Background: real image or gradient
                Group {
                    if let imageName = planImageName(for: plan.goal) {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.3), Color(hex: "#0A0A0A")!],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .clipped()

                // LIVE pill (top-left)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "#D4FF3F")!)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "#D4FF3F")!)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .padding(12)

                // Goal chip (top-right)
                VStack {
                    HStack {
                        Spacer()
                        Text(goalShort(for: plan.goal))
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                }
                .padding(12)

                // Day/starts badge (bottom-left)
                VStack {
                    Spacer()
                    HStack {
                        Group {
                            if isRunning {
                                HStack(spacing: 0) {
                                    Text("DAY \(plan.currentDay ?? 0)")
                                        .foregroundColor(Color(hex: "#D4FF3F")!)
                                    Text(" /\(plan.durationDays)")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            } else {
                                Text("Empieza pronto")
                                    .foregroundColor(Color(hex: "#D4FF3F")!)
                            }
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                }
                .padding(12)
            }
            .frame(height: 130)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))

            // Info area
            VStack(alignment: .leading, spacing: 0) {
                Text(plan.title)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(-0.2)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.bottom, 4)

                // Creator
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(creatorInitials(plan.creatorName ?? "Coach"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text(plan.creatorName ?? "Coach")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                }
                .padding(.bottom, 12)

                // Followers progress
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                        Text("\(plan.liveParticipantsCount)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    Spacer()
                    if isAlmostFull {
                        Text("POCAS PLAZAS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(Color(hex: "#FF5A1F")!)
                    }
                }
                .padding(.bottom, 6)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isAlmostFull ? Color(hex: "#FF5A1F")! : accentColor)
                            .frame(width: geo.size.width * CGFloat(min(fillPct / 100, 1)))
                    }
                }
                .frame(height: 3)
            }
            .padding(14)
        }
        .frame(width: 280)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Template Plans Section

    private var templatePlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TEMPLATES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    Text("Empieza cuando quieras")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.3)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                Spacer()
                Text("\(templatePlans.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(templatePlans) { plan in
                    Button(action: {
                        selectedPlan = plan
                        showPlanDetail = true
                    }) {
                        templatePlanCard(plan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func templatePlanCard(_ plan: NutritionPlan) -> some View {
        let accentColor = goalColor(for: plan.goal)

        return HStack(alignment: .top, spacing: 0) {
            // Color strip (image area)
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let imageName = planImageName(for: plan.goal) {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: 100)
                .clipped()

                // Goal badge
                Text(goalShort(for: plan.goal))
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(8)
            }
            .frame(width: 100)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Title + TEMPLATE badge
                HStack(alignment: .top) {
                    Text(plan.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .lineSpacing(2)

                    Spacer()

                    Text("TEMPLATE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.bottom, 6)

                // Creator + duration
                Text("\(plan.creatorName ?? "Coach") · \(plan.durationDays) días")
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                    .padding(.bottom, 10)

                // Followers + difficulty + dietary
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                        Text("\(plan.liveParticipantsCount)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    }

                    Text("·")
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

                    Text(plan.difficultyLevel.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(difficultyColor(for: plan.difficultyLevel))

                    if let restriction = plan.dietaryRestrictions.first, restriction != .none {
                        Text("·")
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                        Text(restriction.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                    }
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func goalColor(for goal: NutritionGoal) -> Color {
        switch goal {
        case .cut: return Color(hex: "#FF5A1F")!
        case .bulk: return Color(hex: "#3B82F6")!
        case .maintenance: return Color(hex: "#4ADE80")!
        case .weightLoss: return Color(hex: "#F472B6")!
        case .muscleGain: return Color(hex: "#A78BFA")!
        case .performance: return Color(hex: "#D4FF3F")!
        }
    }

    private func goalShort(for goal: NutritionGoal) -> String {
        switch goal {
        case .cut: return "CUT"
        case .bulk: return "BULK"
        case .maintenance: return "MAINT"
        case .weightLoss: return "LOSS"
        case .muscleGain: return "GAIN"
        case .performance: return "PERF"
        }
    }

    private func difficultyColor(for level: DifficultyLevel) -> Color {
        switch level {
        case .beginner: return Color(hex: "#4ADE80")!
        case .intermediate: return Color(hex: "#FFB347")!
        case .advanced: return Color(hex: "#FF5A1F")!
        }
    }

    private func planImageName(for goal: NutritionGoal) -> String? {
        switch goal {
        case .cut, .weightLoss: return "NutritionPlans/cut_image"
        case .bulk, .muscleGain: return "NutritionPlans/bulk_image"
        case .maintenance: return "NutritionPlans/maintain_image"
        case .performance: return "NutritionPlans/performance_image"
        }
    }

    private func creatorInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func loadPlansIfNeeded() {
        guard allPlans.isEmpty && !isLoading else { return }
        isLoading = true
        Task {
            let plans = await nutritionService.getPlans(
                planType: nil,
                status: nil,
                goal: nil,
                page: 1,
                perPage: 50
            )
            await MainActor.run {
                allPlans = plans
                isLoading = false
            }
        }
    }
}
