import SwiftUI

// MARK: - NutritionPlanView
/// Main nutrition plan screen with 3 tabs: Today, Calendar, Macros
/// Replicates the prototype NutritionPlanScreen exactly
struct NutritionPlanView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var nutritionService: NutritionService
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: PlanTab = .today
    @State private var selectedMeal: Meal?
    @State private var showMealDetail = false
    @State private var selectedCalendarDay: Int? = nil
    @State private var selectedDayMeals: [Meal] = []
    @State private var isLoadingDayMeals = false

    private let accentColor = Color(hex: "#D4FF3F")!

    // MARK: - Computed Properties

    private var plan: NutritionPlan? {
        nutritionService.todayPlan?.plan ?? nutritionService.currentPlan
    }

    private var todayPlan: TodayMealPlan? {
        nutritionService.todayPlan
    }

    private var currentDay: Int {
        todayPlan?.currentDay ?? plan?.currentDay ?? 1
    }

    private var totalDays: Int {
        plan?.durationDays ?? 28
    }

    private var meals: [Meal] {
        todayPlan?.meals ?? []
    }

    private var progress: DayProgress? {
        todayPlan?.progress
    }

    private var doneMeals: Int {
        progress?.mealsCompleted ?? meals.filter { $0.isCompleted }.count
    }

    private var totalMeals: Int {
        progress?.totalMeals ?? meals.count
    }

    private var caloriesConsumed: Int {
        progress?.caloriesConsumed ?? meals.filter { $0.isCompleted }.reduce(0) { $0 + $1.calories }
    }

    private var caloriesTarget: Int {
        progress?.caloriesTarget ?? Int(plan?.targetCalories ?? 1800)
    }

    private var proteinConsumed: Int {
        progress?.proteinConsumed ?? meals.filter { $0.isCompleted }.reduce(0) { $0 + ($1.proteinG ?? 0) }
    }

    private var proteinTarget: Int {
        progress?.proteinTarget ?? Int(plan?.targetProteinG ?? 140)
    }

    private var carbsConsumed: Int {
        progress?.carbsConsumed ?? meals.filter { $0.isCompleted }.reduce(0) { $0 + ($1.carbsG ?? 0) }
    }

    private var carbsTarget: Int {
        progress?.carbsTarget ?? Int(plan?.targetCarbsG ?? 180)
    }

    private var fatConsumed: Int {
        progress?.fatConsumed ?? meals.filter { $0.isCompleted }.reduce(0) { $0 + ($1.fatG ?? 0) }
    }

    private var fatTarget: Int {
        progress?.fatTarget ?? Int(plan?.targetFatG ?? 60)
    }

    private var planProgress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay - 1) / Double(totalDays) * 100
    }

    private var streak: Int {
        nutritionService.currentStreak
    }

    private var goalColor: Color {
        switch plan?.goal {
        case .cut: return Color(hex: "#FF5A1F")!
        case .bulk: return Color(hex: "#3B82F6")!
        case .maintenance: return Color(hex: "#4ADE80")!
        case .weightLoss: return Color(hex: "#FF5A1F")!
        case .muscleGain: return Color(hex: "#A78BFA")!
        case .performance: return accentColor
        case .none: return accentColor
        }
    }

    private var goalLabel: String {
        switch plan?.goal {
        case .cut: return "CUT"
        case .bulk: return "BULK"
        case .maintenance: return "MANTENER"
        case .weightLoss: return "PÉRDIDA"
        case .muscleGain: return "GANANCIA"
        case .performance: return "RENDIMIENTO"
        case .none: return ""
        }
    }

    private var creatorInitials: String {
        guard let name = plan?.creatorName else { return "?" }
        let parts = name.components(separatedBy: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    /// Find the current meal based on time of day and completion status
    private var currentMealId: Int? {
        let now = Calendar.current.component(.hour, from: Date())
        let sortedMeals = meals.sorted()

        // Map meal types to their typical hours
        func mealHour(_ type: MealType) -> Int {
            switch type {
            case .breakfast: return 8
            case .midMorning: return 11
            case .lunch: return 14
            case .afternoon: return 16
            case .postWorkout: return 18
            case .dinner: return 20
            case .lateSnack: return 22
            }
        }

        // Find the meal whose time window we're currently in (or closest upcoming)
        // that hasn't been completed yet
        let incompleteMeals = sortedMeals.filter { !$0.isCompleted }
        guard !incompleteMeals.isEmpty else { return nil }

        // First: find incomplete meal whose hour is <= now (we should be eating it)
        // Pick the latest one that's still <= now
        let currentOrPast = incompleteMeals.filter { mealHour($0.mealType) <= now }
        if let latest = currentOrPast.last {
            return latest.id
        }

        // If all incomplete meals are in the future, pick the next upcoming one
        return incompleteMeals.first?.id
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // HEADER
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // TAB BAR
                tabBar

                // TAB CONTENT
                switch selectedTab {
                case .today:
                    todayTab
                        .padding(.horizontal, 20)
                case .calendar:
                    calendarTab
                        .padding(.horizontal, 20)
                case .macros:
                    macrosTab
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .sheet(item: $selectedMeal) { meal in
            NavigationStack {
                MealDetailView(meal: meal)
                    .environmentObject(themeManager)
                    .environmentObject(nutritionService)
            }
        }
        .onAppear {
            nutritionService.configure(authService: ServiceContainer.shared.authService, gymService: GymService.shared)
            Task {
                await nutritionService.getDashboard()
                await nutritionService.getTodayPlan()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // LIVE indicator + day + goal badge
            HStack(spacing: 6) {
                // LIVE pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .modifier(PulseAnimation())

                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
                .clipShape(Capsule())

                // Day label
                Text("Day \(currentDay) / \(totalDays)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))

                // Goal badge
                if !goalLabel.isEmpty {
                    Text(goalLabel)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.7)
                        .foregroundColor(goalColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(goalColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.bottom, 12)

            // Title
            Text(plan?.title ?? "Plan Nutricional")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.bottom, 6)

            // Description
            if let description = plan?.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    .lineSpacing(4)
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(.bottom, 16)
            }

            // Trainer + followers
            HStack {
                // Trainer
                HStack(spacing: 8) {
                    Text(creatorInitials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "#A78BFA")!)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(plan?.creatorName ?? "Trainer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(1)

                        Text("Trainer · Nutrition")
                            .font(.system(size: 10))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }
                }

                Spacer()

                // Followers
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(plan?.followersCount ?? plan?.liveParticipantsCount ?? 0)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(-0.36)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text("siguiendo")
                        .font(.system(size: 10))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                }
            }
            .padding(.bottom, 16)

            // Plan progress card
            VStack(spacing: 8) {
                HStack {
                    Text("PLAN · \(totalDays) DAYS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                    Spacer()

                    Text("\(Int(planProgress))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                }

                PlanProgressBar(totalDays: totalDays, currentDay: currentDay)
                    .environmentObject(themeManager)
            }
            .padding(12)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PlanTab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
                    VStack(spacing: 0) {
                        Text(tab.label)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(
                                selectedTab == tab
                                    ? Color.dynamicText(theme: themeManager.currentTheme)
                                    : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)

                        // Active indicator
                        if selectedTab == tab {
                            Rectangle()
                                .fill(accentColor)
                                .frame(height: 2)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .padding(.horizontal, 20)
                        } else {
                            Color.clear.frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Today Tab

    private var todayTab: some View {
        VStack(spacing: 16) {
            // Macros card
            macrosCard

            // Meals timeline
            mealsTimeline
        }
    }

    private var macrosCard: some View {
        VStack(spacing: 16) {
            // Top row: calories + streak
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOY · \(formattedDate)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                        .padding(.bottom, 6)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(caloriesConsumed)")
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .tracking(-1.5)
                        Text("/ \(caloriesTarget) kcal")
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }

                    Text("\(caloriesTarget - caloriesConsumed) restantes")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                        .padding(.top, 4)
                }

                Spacer()

                // Streak
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)

                        Text("\(streak)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }

                    Text("comidas seguidas")
                        .font(.system(size: 10))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                }
            }

            // Calorie progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.dynamicSurface2(theme: themeManager.currentTheme))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geo.size.width * calorieProgress)
                }
            }
            .frame(height: 6)

            // Macro rings
            HStack(spacing: 0) {
                Spacer()
                MacroRingView(value: proteinConsumed, target: proteinTarget, color: accentColor, label: "Proteína", unit: "g")
                    .environmentObject(themeManager)
                Spacer()
                MacroRingView(value: carbsConsumed, target: carbsTarget, color: Color(hex: "#FF5A1F")!, label: "Carbos", unit: "g")
                    .environmentObject(themeManager)
                Spacer()
                MacroRingView(value: fatConsumed, target: fatTarget, color: Color(hex: "#A78BFA")!, label: "Grasas", unit: "g")
                    .environmentObject(themeManager)
                Spacer()
            }
        }
        .padding(18)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mealsTimeline: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text("COMIDAS DE HOY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Spacer()

                HStack(spacing: 0) {
                    Text("\(doneMeals)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text("/\(totalMeals)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                }
            }
            .padding(.bottom, 2)

            // Meal cards
            ForEach(meals.sorted(), id: \.id) { meal in
                MealTimelineCard(
                    meal: meal,
                    isCurrentMeal: meal.id == currentMealId,
                    onTap: {
                        selectedMeal = meal
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Calendar Tab

    private var calendarTab: some View {
        VStack(spacing: 20) {
            Text("\(totalDays) DAYS PUBLISHED")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(1...totalDays, id: \.self) { day in
                    calendarDayCell(day: day)
                }
            }

            // Legend
            HStack(spacing: 12) {
                legendItem(color: accentColor, label: "Hoy")
                legendItem(color: Color.dynamicSurface(theme: themeManager.currentTheme), label: "Completado", hasDot: true)
                legendItem(color: Color.dynamicSurface2(theme: themeManager.currentTheme), label: "Futuro")
            }
            .padding(.top, 8)

            // Selected day meals
            if let day = selectedCalendarDay {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("DAY \(day)")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                        Spacer()

                        if !selectedDayMeals.isEmpty {
                            let done = selectedDayMeals.filter { $0.isCompleted }.count
                            HStack(spacing: 0) {
                                Text("\(done)")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                Text("/\(selectedDayMeals.count)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                            }
                        }
                    }

                    if isLoadingDayMeals {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else if selectedDayMeals.isEmpty {
                        Text("No meals for this day")
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(selectedDayMeals.sorted(), id: \.id) { meal in
                            MealTimelineCard(
                                meal: meal,
                                isCurrentMeal: false,
                                onTap: { selectedMeal = meal }
                            )
                            .environmentObject(themeManager)
                        }
                    }
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedCalendarDay)
    }

    private func calendarDayCell(day: Int) -> some View {
        let status = calendarDayStatus(day: day)
        let isSelected = selectedCalendarDay == day
        let isTappable = status == .past || status == .today

        return Button(action: {
            guard isTappable else { return }
            HapticManager.shared.buttonTap()
            if selectedCalendarDay == day {
                selectedCalendarDay = nil
                selectedDayMeals = []
            } else {
                selectedCalendarDay = day
                loadMealsForDay(day)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(calendarDayBackground(status))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? accentColor : calendarDayBorder(status),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(calendarDayTextColor(status))

                    if status == .past {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
    }

    private func legendItem(color: Color, label: String, hasDot: Bool = false) -> some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 10, height: 10)

                if hasDot {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 3, height: 3)
                        .offset(y: 2)
                }
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
        }
    }

    // MARK: - Macros Tab

    private var macrosTab: some View {
        VStack(spacing: 24) {
            // Daily target card
            VStack(spacing: 16) {
                Text("OBJETIVO DIARIO")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    // Total calories
                    HStack {
                        Text("Total calories")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text("\(caloriesTarget)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                    }

                    // Macro proportion bar
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accentColor)
                                .frame(width: geo.size.width * macroBarFraction(macro: .protein))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#FF5A1F")!)
                                .frame(width: geo.size.width * macroBarFraction(macro: .carbs))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#A78BFA")!)
                                .frame(width: geo.size.width * macroBarFraction(macro: .fat))
                        }
                    }
                    .frame(height: 8)

                    // Macro details
                    VStack(spacing: 14) {
                        macroDetailRow(label: "Proteína", target: proteinTarget, color: accentColor, multiplier: 4)
                        macroDetailRow(label: "Carbohidratos", target: carbsTarget, color: Color(hex: "#FF5A1F")!, multiplier: 4)
                        macroDetailRow(label: "Grasas", target: fatTarget, color: Color(hex: "#A78BFA")!, multiplier: 9)
                    }
                }
                .padding(18)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Plan details card
            VStack(spacing: 12) {
                Text("DETALLES DEL PLAN")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    planDetailRow(label: "Dificultad", value: plan?.difficultyLevel.rawValue.capitalized ?? "Intermedio")
                    planDetailRow(label: "Presupuesto", value: plan?.budgetLevel.displayName ?? "Medio")
                    planDetailRow(label: "Restricciones", value: plan?.dietaryRestrictions.first?.displayName ?? "Ninguna")
                    planDetailRow(label: "Duración", value: "\(totalDays) días")
                    planDetailRow(label: "Inicio", value: formattedStartDate, isLast: true)
                }
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func macroDetailRow(label: String, target: Int, color: Color, multiplier: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            HStack(spacing: 6) {
                Text("\(target)g")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Text("\(target * multiplier) kcal")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
            }
        }
    }

    private func planDetailRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Helpers

    private var calorieProgress: CGFloat {
        guard caloriesTarget > 0 else { return 0 }
        return min(CGFloat(caloriesConsumed) / CGFloat(caloriesTarget), 1.0)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: Date())
    }

    private var formattedStartDate: String {
        guard let date = plan?.liveStartDate else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    private enum MacroType { case protein, carbs, fat }

    private func macroBarFraction(macro: MacroType) -> CGFloat {
        let pCal = CGFloat(proteinTarget * 4)
        let cCal = CGFloat(carbsTarget * 4)
        let fCal = CGFloat(fatTarget * 9)
        let total = pCal + cCal + fCal
        guard total > 0 else { return 0.33 }

        switch macro {
        case .protein: return pCal / total
        case .carbs: return cCal / total
        case .fat: return fCal / total
        }
    }

    private enum CalendarDayStatus { case past, today, published, future }

    private func loadMealsForDay(_ day: Int) {
        guard let planId = plan?.id else { return }
        isLoadingDayMeals = true
        selectedDayMeals = []

        // If it's today's day, use the already loaded meals
        if day == currentDay {
            selectedDayMeals = meals
            isLoadingDayMeals = false
            return
        }

        Task {
            if let dailyPlan = await nutritionService.getDailyPlan(planId: planId, dayNumber: day) {
                await MainActor.run {
                    selectedDayMeals = dailyPlan.meals
                    isLoadingDayMeals = false
                }
            } else {
                await MainActor.run {
                    selectedDayMeals = []
                    isLoadingDayMeals = false
                }
            }
        }
    }

    private func calendarDayStatus(day: Int) -> CalendarDayStatus {
        if day < currentDay { return .past }
        if day == currentDay { return .today }
        if day <= currentDay + 1 { return .published }
        return .future
    }

    private func calendarDayBackground(_ status: CalendarDayStatus) -> Color {
        switch status {
        case .today: return accentColor
        case .past: return Color.dynamicSurface(theme: themeManager.currentTheme)
        case .published: return Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08)
        case .future: return Color.dynamicSurface2(theme: themeManager.currentTheme)
        }
    }

    private func calendarDayBorder(_ status: CalendarDayStatus) -> Color {
        switch status {
        case .today: return .clear
        case .past: return accentColor.opacity(0.3)
        default: return Color.white.opacity(0.08)
        }
    }

    private func calendarDayTextColor(_ status: CalendarDayStatus) -> Color {
        switch status {
        case .today: return Color.accentInk
        case .future: return Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3)
        default: return Color.dynamicText(theme: themeManager.currentTheme)
        }
    }
}

// MARK: - Tab Enum

private enum PlanTab: String, CaseIterable {
    case today, calendar, macros

    var label: String {
        switch self {
        case .today: return "Hoy"
        case .calendar: return "Calendario"
        case .macros: return "Macros"
        }
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
