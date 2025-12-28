import SwiftUI

// MARK: - NutritionDashboardView

/// Vista principal del Dashboard de Nutricion con navegacion por tabs
/// Tab 1: LIVE - Challenges activos y proximos
/// Tab 2: EXPLORAR - Templates y planes disponibles
/// Tab 3: MIS PLANES - Planes activos e historial
struct NutritionDashboardView: View {
    // MARK: - Environment

    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    @State private var selectedTab: DashboardTab = .live
    @State private var showPlanDetail = false
    @State private var selectedPlan: NutritionPlan?
    @State private var showTodayPlan = false
    @State private var showLiveChallengePreview = false
    @State private var appearAnimation = false

    // MARK: - Tab Enum

    enum DashboardTab: String, CaseIterable {
        case live = "LIVE"
        case explore = "EXPLORAR"
        case myPlans = "MIS PLANES"

        var icon: String {
            switch self {
            case .live: return "dot.radiowaves.left.and.right"
            case .explore: return "magnifyingglass"
            case .myPlans: return "folder.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Bar
                customTabBar
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -20)

                // Tab Content
                TabView(selection: $selectedTab) {
                    LiveChallengesView(
                        onPlanSelected: { plan in
                            selectedPlan = plan
                            if plan.isFollowedByUser && plan.status == .running {
                                showTodayPlan = true
                            } else {
                                showLiveChallengePreview = true
                            }
                        },
                        onViewTodayPlan: {
                            showTodayPlan = true
                        }
                    )
                    .environmentObject(nutritionService)
                    .environmentObject(themeManager)
                    .tag(DashboardTab.live)

                    ExplorePlansView(
                        onPlanSelected: { plan in
                            selectedPlan = plan
                            showPlanDetail = true
                        }
                    )
                    .environmentObject(nutritionService)
                    .environmentObject(themeManager)
                    .tag(DashboardTab.explore)

                    MyPlansView(
                        onViewTodayPlan: {
                            showTodayPlan = true
                        },
                        onPlanSelected: { plan in
                            selectedPlan = plan
                            showPlanDetail = true
                        }
                    )
                    .environmentObject(nutritionService)
                    .environmentObject(themeManager)
                    .tag(DashboardTab.myPlans)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
            .navigationTitle("Nutricion")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
            }
            .sheet(isPresented: $showTodayPlan) {
                NavigationStack {
                    TodayMealPlanView()
                        .environmentObject(nutritionService)
                        .environmentObject(themeManager)
                }
            }
            .sheet(isPresented: $showPlanDetail) {
                if let plan = selectedPlan {
                    NavigationStack {
                        PlanDetailView(plan: plan)
                            .environmentObject(nutritionService)
                            .environmentObject(themeManager)
                    }
                }
            }
            .sheet(isPresented: $showLiveChallengePreview) {
                if let plan = selectedPlan {
                    NavigationStack {
                        LiveChallengePreviewView(plan: plan)
                            .environmentObject(nutritionService)
                            .environmentObject(themeManager)
                    }
                }
            }
            .onAppear {
                loadDataIfNeeded()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    appearAnimation = true
                }
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func tabButton(for tab: DashboardTab) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 6) {
                if tab == .live && hasActiveLiveChallenge {
                    LivePulseIndicator(size: 8)
                } else {
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .medium))
                }

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selectedTab == tab
                ? .white
                : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private var hasActiveLiveChallenge: Bool {
        return nutritionService.livePlans.contains { $0.status == .running }
    }

    private func loadDataIfNeeded() {
        if nutritionService.dashboard == nil && !nutritionService.isLoading {
            Task {
                await nutritionService.getDashboard()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NutritionDashboardView()
        .environmentObject(NutritionService.shared)
        .environmentObject(ThemeManager())
}
