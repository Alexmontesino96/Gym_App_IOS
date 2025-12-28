import SwiftUI

// MARK: - NutritionHomeBannerSection

/// Seccion de HomeView que muestra el banner de nutricion apropiado
/// basado en el estado del usuario:
/// - Si tiene un plan LIVE activo: NutritionLiveChallengeBanner
/// - Si hay un plan LIVE proximo: NutritionUpcomingChallengeBanner
/// - Si no tiene plan: NutritionDiscoverBanner
///
/// Al tocar el banner, navega al Dashboard completo de nutricion
struct NutritionHomeBannerSection: View {
    @EnvironmentObject var nutritionService: NutritionService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showTodayMealPlan = false
    @State private var showNutritionDashboard = false
    @State private var hasLoadedData = false
    @State private var hasAppeared = false  // Para animación de entrada

    var body: some View {
        VStack(spacing: 12) {
            // Banner Content
            bannerContent
                .frame(minHeight: 150) // Aumentada altura mínima para evitar texto cortado
                .scaleEffect(hasAppeared ? 1.0 : 0.95)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .offset(y: hasAppeared ? 0 : 10)

            // ELIMINADO: Botón redundante "Explorar todos los planes"
            // La navegación debe ser solo desde el banner principal
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showTodayMealPlan) {
            NavigationStack {
                TodayMealPlanView()
                    .environmentObject(nutritionService)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showNutritionDashboard) {
            NutritionDashboardView()
                .environmentObject(nutritionService)
                .environmentObject(themeManager)
        }
        .task {
            // Cargar datos de nutricion si no se han cargado
            if !hasLoadedData {
                await nutritionService.getDashboard()
                hasLoadedData = true
            }
        }
    }

    // MARK: - Banner Content

    @ViewBuilder
    private var bannerContent: some View {
        if let todayPlan = nutritionService.todayPlan,
           let plan = todayPlan.plan,
           let progress = todayPlan.progress {
            // Usuario tiene un plan activo hoy - navegar a TodayMealPlanView
            NutritionLiveChallengeBanner(
                plan: plan,
                progress: progress
            ) {
                showTodayMealPlan = true
            }
            .environmentObject(themeManager)
        } else if let upcomingPlan = nutritionService.livePlans.first(where: { $0.status == .notStarted }) {
            // Hay un plan LIVE proximo
            NutritionUpcomingChallengeBanner(plan: upcomingPlan) {
                showNutritionDashboard = true
            }
            .environmentObject(themeManager)
        } else if !nutritionService.availablePlans.isEmpty || !hasLoadedData {
            // Mostrar banner de descubrimiento si hay planes o si aun no se ha cargado
            NutritionDiscoverBanner {
                showNutritionDashboard = true
            }
            .environmentObject(themeManager)
        }
    }

    // MARK: - Helpers

    private var hasAnyContent: Bool {
        return nutritionService.todayPlan != nil ||
               !nutritionService.livePlans.isEmpty ||
               !nutritionService.availablePlans.isEmpty ||
               hasLoadedData
    }
}

// MARK: - Preview

#Preview {
    VStack {
        NutritionHomeBannerSection()
            .padding()
    }
    .background(Color.black)
    .environmentObject(NutritionService.shared)
    .environmentObject(ThemeManager())
}
