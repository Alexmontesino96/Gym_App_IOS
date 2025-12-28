import SwiftUI

// MARK: - ExplorePlansView

/// Tab 2 del Dashboard: Explorar templates y planes disponibles
/// Incluye:
/// - Barra de busqueda funcional
/// - Chips de categorias (filtros)
/// - Seccion "Recomendados para ti"
/// - Grid de templates populares
struct ExplorePlansView: View {
    // MARK: - Properties

    let onPlanSelected: (NutritionPlan) -> Void

    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var searchText = ""
    @State private var selectedCategory: NutritionCategory = .all
    @State private var isRefreshing = false
    @State private var appearAnimation = false

    // MARK: - Category Enum

    enum NutritionCategory: String, CaseIterable {
        case all = "Todos"
        case weightLoss = "Perdida peso"
        case muscleGain = "Musculo"
        case detox = "Detox"
        case vegan = "Vegano"
        case keto = "Keto"
        case maintenance = "Mantenimiento"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .weightLoss: return "arrow.down.circle"
            case .muscleGain: return "arrow.up.circle"
            case .detox: return "leaf"
            case .vegan: return "leaf.circle"
            case .keto: return "flame"
            case .maintenance: return "equal.circle"
            }
        }

        var goalFilter: NutritionGoal? {
            switch self {
            case .all: return nil
            case .weightLoss: return .weightLoss
            case .muscleGain: return .muscleGain
            case .detox: return nil // Filter by tag
            case .vegan: return nil // Filter by restriction
            case .keto: return nil // Filter by restriction
            case .maintenance: return .maintenance
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if nutritionService.isLoading && filteredPlans.isEmpty {
                loadingView
            } else {
                contentView
            }
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            loadDataIfNeeded()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        LazyVStack(spacing: 24) {
            // Search Bar
            searchBar
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)

            // Category Chips
            categoryChips
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)

            // Recommended Section
            if selectedCategory == .all && searchText.isEmpty {
                recommendedSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Plans Grid
            if filteredPlans.isEmpty {
                emptySearchView
            } else {
                plansGridSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }

            // Bottom spacing
            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            TextField("Buscar planes...", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NutritionCategory.allCases, id: \.self) { category in
                    NutritionCategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    }
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Recommended Section

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    Text("Recomendados para ti")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()
            }

            // Recommended Hero Card
            if let recommendedPlan = recommendedPlan {
                RecommendedPlanCard(plan: recommendedPlan) {
                    onPlanSelected(recommendedPlan)
                }
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Plans Grid Section

    private var plansGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text(sectionTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text("\(filteredPlans.count) plan\(filteredPlans.count == 1 ? "" : "es")")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // 2-column Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredPlans) { plan in
                    ExplorePlanCard(plan: plan) {
                        onPlanSelected(plan)
                    }
                    .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Empty Search View

    private var emptySearchView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Text("No se encontraron planes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Intenta con otra busqueda o categoria")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Button(action: {
                searchText = ""
                selectedCategory = .all
            }) {
                Text("Limpiar filtros")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.dynamicAccent(theme: themeManager.currentTheme))

            Text("Cargando planes...")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Computed Properties

    private var allPlans: [NutritionPlan] {
        var plans = nutritionService.templatePlans + nutritionService.availablePlans
        // Remove duplicates by ID
        var seen = Set<Int>()
        plans = plans.filter { plan in
            if seen.contains(plan.id) {
                return false
            }
            seen.insert(plan.id)
            return true
        }
        return plans
    }

    private var filteredPlans: [NutritionPlan] {
        var plans = allPlans

        // Filter by search text
        if !searchText.isEmpty {
            plans = plans.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by category
        switch selectedCategory {
        case .all:
            break
        case .weightLoss:
            plans = plans.filter { $0.goal == .weightLoss }
        case .muscleGain:
            plans = plans.filter { $0.goal == .muscleGain }
        case .detox:
            plans = plans.filter { $0.tags.contains("detox") || $0.title.localizedCaseInsensitiveContains("detox") }
        case .vegan:
            plans = plans.filter { $0.dietaryRestrictions.contains(.vegan) }
        case .keto:
            plans = plans.filter { $0.dietaryRestrictions.contains(.keto) }
        case .maintenance:
            plans = plans.filter { $0.goal == .maintenance }
        }

        return plans
    }

    private var recommendedPlan: NutritionPlan? {
        // Get the most popular plan that user hasn't followed
        return allPlans
            .filter { !$0.isFollowedByUser }
            .sorted { ($0.followersCount ?? 0) > ($1.followersCount ?? 0) }
            .first
    }

    private var sectionTitle: String {
        if !searchText.isEmpty {
            return "Resultados"
        } else if selectedCategory != .all {
            return selectedCategory.rawValue
        } else {
            return "Templates Populares"
        }
    }

    // MARK: - Actions

    private func loadDataIfNeeded() {
        if nutritionService.templatePlans.isEmpty && !nutritionService.isLoading {
            Task {
                await nutritionService.getDashboard()
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        await nutritionService.getDashboard()
        isRefreshing = false
    }
}

// MARK: - NutritionCategoryChip

/// Chip de categoria para filtrar planes de nutricion
struct NutritionCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected
                ? .white
                : Color.dynamicText(theme: themeManager.currentTheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected
                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                        : Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected
                        ? Color.clear
                        : Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3),
                           lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - RecommendedPlanCard

/// Hero card para plan recomendado
struct RecommendedPlanCard: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Top Section
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Plan Type Badge
                        PlanTypeBadge(planType: plan.planType)
                            .environmentObject(themeManager)

                        // Title
                        Text(plan.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(2)

                        // Goal
                        HStack(spacing: 4) {
                            Image(systemName: plan.goal.icon)
                                .font(.system(size: 11))
                            Text(plan.goal.displayName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }

                    Spacer()

                    // Rating
                    if let avgSatisfaction = plan.avgSatisfaction, avgSatisfaction > 0 {
                        VStack(spacing: 4) {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", avgSatisfaction))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text("\(plan.followersCount ?? 0) usuarios")
                                .font(.system(size: 10))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                }

                // Description
                if let description = plan.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(2)
                }

                // Stats Row
                HStack(spacing: 16) {
                    StatPill(icon: "calendar", text: "\(plan.durationDays) dias")
                        .environmentObject(themeManager)

                    if let calories = plan.targetCalories {
                        StatPill(icon: "flame.fill", text: "\(calories) kcal")
                            .environmentObject(themeManager)
                    }

                    StatPill(icon: plan.difficultyLevel.iconName, text: plan.difficultyLevel.displayName)
                        .environmentObject(themeManager)
                }

                // CTA
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Text("Ver detalles")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.4),
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
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

// MARK: - ExplorePlanCard

/// Card compacta para el grid de planes
struct ExplorePlanCard: View {
    let plan: NutritionPlan
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    PlanTypeBadge(planType: plan.planType, compact: true)
                        .environmentObject(themeManager)

                    Spacer()

                    if plan.isFollowedByUser {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }

                // Title
                Text(plan.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Goal
                HStack(spacing: 4) {
                    Image(systemName: plan.goal.icon)
                        .font(.system(size: 10))
                    Text(plan.goal.displayName)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                // Stats
                HStack(spacing: 8) {
                    Label("\(plan.durationDays)d", systemImage: "calendar")
                    Spacer()
                    if let calories = plan.targetCalories {
                        Label("\(calories)", systemImage: "flame.fill")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                // Rating/Users
                HStack(spacing: 4) {
                    if let rating = plan.avgSatisfaction, rating > 0 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11, weight: .medium))
                    }

                    Spacer()

                    Text("\(plan.followersCount ?? 0) usuarios")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(14)
            .frame(height: 170)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - DifficultyLevel Extension

extension DifficultyLevel {
    var iconName: String {
        switch self {
        case .beginner: return "leaf"
        case .intermediate: return "bolt"
        case .advanced: return "flame"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExplorePlansView(onPlanSelected: { _ in })
            .environmentObject(NutritionService.shared)
            .environmentObject(ThemeManager())
    }
}
