import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var gymService = GymService.shared
    @EnvironmentObject var classService: ClassService
    @StateObject private var profileService = UserProfileService.shared
    @ObservedObject private var userStatsService = UserStatsService.shared
    @StateObject private var paymentService = EventPaymentService.shared
    @StateObject private var scheduledActivityService = ScheduledActivityService.shared
    @EnvironmentObject var activityService: ActivityService
    @StateObject private var storyService = StoryService()

    @State private var currentDate = Date()
    @State private var isInitialLoad = true
    @State private var showingPaymentSheet = false
    @State private var showNutritionDashboard = false
    @State private var showQRCode = false
    @State private var currentPaymentIntent: PaymentIntent?
    @State private var currentParticipationId: Int?
    @State private var selectedEventForPayment: Event?

    // MARK: - Computed Properties

    private var userName: String {
        if let firstName = profileService.userProfile?.firstName, !firstName.isEmpty {
            return firstName
        }
        if let auth0Name = authService.user?.name, !auth0Name.isEmpty {
            let components = auth0Name.components(separatedBy: " ")
            let firstComponent = components.first ?? ""
            if firstComponent.contains("@") {
                return firstComponent.components(separatedBy: "@").first ?? "Atleta"
            }
            return firstComponent
        }
        return "Atleta"
    }

    private var userInitials: String {
        let name = profileService.userProfile?.firstName ?? authService.user?.name ?? userName
        let parts = name.components(separatedBy: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return initials.joined()
    }

    private var nextUserClass: GymClass? {
        let now = Date()
        let userRegisteredClasses = classService.classes.filter { gymClass in
            let isRegistered = classService.userRegistrationStatus[gymClass.id] ?? false
            return isRegistered && gymClass.startTime > now
        }
        return userRegisteredClasses.sorted { $0.startTime < $1.startTime }.first
    }

    private var upcomingClasses: [GymClass] {
        let now = Date()
        return classService.classes
            .filter { $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    /// Returns array of 7 bools (Mon-Sun) indicating which days had activity this week
    private var activeDaysThisWeek: [Bool] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return Array(repeating: false, count: 7)
        }

        // Build set of weekday indices (Mon=0..Sun=6) that had workouts
        var activeDays = Set<Int>()
        for workout in userStatsService.workoutHistory {
            let workoutDate = workout.date
            if workoutDate >= weekStart && workoutDate <= today {
                let weekday = calendar.component(.weekday, from: workoutDate)
                // Convert from Sunday=1..Saturday=7 to Mon=0..Sun=6
                let index = (weekday + 5) % 7
                activeDays.insert(index)
            }
        }

        return (0..<7).map { activeDays.contains($0) }
    }

    /// Weekly activity chart data aggregated by day
    private var weeklyChartData: [WeeklyActivityChart.DayActivity] {
        let calendar = Calendar.current
        let today = Date()
        let dayLabels = ["L", "M", "X", "J", "V", "S", "D"]

        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return dayLabels.map { WeeklyActivityChart.DayActivity(dayLabel: $0, kcal: 0, value: 0) }
        }

        // Aggregate calories per day
        var dailyKcal = [Int](repeating: 0, count: 7)
        for workout in userStatsService.workoutHistory {
            let workoutDate = workout.date
            if workoutDate >= weekStart && workoutDate <= today {
                let weekday = calendar.component(.weekday, from: workoutDate)
                let index = (weekday + 5) % 7
                dailyKcal[index] += workout.caloriesBurned ?? estimateCalories(duration: workout.duration)
            }
        }

        let maxKcal = max(dailyKcal.max() ?? 1, 1)
        return dayLabels.enumerated().map { index, label in
            let kcal = dailyKcal[index]
            let value = CGFloat(kcal) / CGFloat(maxKcal)
            return WeeklyActivityChart.DayActivity(dayLabel: label, kcal: kcal, value: value)
        }
    }

    private var totalWeeklyKcal: Int {
        weeklyChartData.reduce(0) { $0 + $1.kcal }
    }

    private func estimateCalories(duration: Int?) -> Int {
        guard let duration = duration else { return 0 }
        // Rough estimate: ~8 kcal per minute of exercise
        return duration * 8
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                if isInitialLoad {
                    HomeViewSkeleton()
                        .environmentObject(themeManager)
                        .transition(.opacity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // 1. Header
                            HomeHeaderView(
                                userName: userName,
                                userInitials: userInitials,
                                onNotificationTap: {
                                    HapticManager.shared.buttonTap()
                                    // Navigate to notifications
                                },
                                onAvatarTap: {
                                    HapticManager.shared.buttonTap()
                                    NotificationCenter.default.post(name: .openProfileTab, object: nil)
                                }
                            )
                            .environmentObject(themeManager)

                            // 1.5. Stories Bar
                            VStack(spacing: 0) {
                                InstagramStoriesBar()
                                    .environmentObject(storyService)
                                    .environmentObject(authService)
                                    .environmentObject(themeManager)
                                    .environmentObject(profileService)

                                // Bottom border — matches prototype: 1px solid var(--border)
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                            }
                            .padding(.bottom, 4)

                            // 2. Hero Card - Today's Session
                            if let nextClass = nextUserClass {
                                TodaySessionHeroCard(
                                    gymClass: nextClass,
                                    onCheckInTap: {
                                        HapticManager.shared.buttonTap()
                                        // Navigate to QR check-in
                                    },
                                    onCardTap: {
                                        HapticManager.shared.buttonTap()
                                        NotificationCenter.default.post(name: .openClassesTab, object: nil)
                                    }
                                )
                                .environmentObject(themeManager)
                            }

                            // 2.5. Live Widgets (pulse del gym en tiempo real)
                            LiveWidgetsSection()
                                .environmentObject(activityService)
                                .environmentObject(themeManager)
                                .environmentObject(classService)

                            // 3. Quick Actions
                            QuickActionsGrid(
                                onCommunity: {
                                    // Navigate to Social/Community tab
                                    NotificationCenter.default.post(name: .openSocialTab, object: nil)
                                },
                                onPlans: {
                                    showNutritionDashboard = true
                                },
                                onScanMeal: {
                                    // Navigate to nutrition scanner
                                },
                                onMyQR: {
                                    showQRCode = true
                                }
                            )
                            .environmentObject(themeManager)

                            // 4. Stats Row (Streak + Weekly Goal)
                            StatsRowView(
                                streak: userStatsService.userStats.currentStreak,
                                weeklyClasses: userStatsService.userStats.weeklyClasses,
                                weeklyGoal: 5,
                                activeDaysThisWeek: activeDaysThisWeek
                            )
                            .environmentObject(themeManager)

                            // 5. Weekly Activity Chart
                            WeeklyActivityChart(
                                dailyData: weeklyChartData,
                                totalKcal: totalWeeklyKcal,
                                trendPercentage: 18 // TODO: calculate from previous week comparison
                            )
                            .environmentObject(themeManager)

                            // 6. Upcoming Classes
                            HomeUpcomingClassesSection(
                                classes: upcomingClasses,
                                registrationStatus: classService.userRegistrationStatus,
                                onClassTap: { _ in
                                    HapticManager.shared.buttonTap()
                                    NotificationCenter.default.post(name: .openClassesTab, object: nil)
                                },
                                onSeeAllTap: {
                                    NotificationCenter.default.post(name: .openClassesTab, object: nil)
                                }
                            )
                            .environmentObject(themeManager)

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                    .safeAreaPadding(.top, 20)
                    .safeAreaPadding(.bottom, 16)
                }
            }
            .refreshable {
                await userStatsService.fetchComprehensiveStats()
                await userStatsService.fetchDashboardSummary()
                await userStatsService.fetchWorkoutHistory()
                await classService.forceRefreshSessions(date: Date())
                await classService.fetchMyClasses()
                await eventService.fetchEvents()
                await eventService.fetchUserParticipations()
                await activityService.fetchAllData()
                HapticManager.shared.play(.success)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showNutritionDashboard) {
                PlansListView()
                    .environmentObject(themeManager)
                    .environmentObject(NutritionService.shared)
            }
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeSheet(
                qrCode: profileService.userProfile?.qrCode,
                userName: profileService.userProfile?.fullName
            )
            .environmentObject(themeManager)
        }
        .sheet(item: Binding(
            get: { currentPaymentIntent },
            set: { currentPaymentIntent = $0 }
        )) { paymentIntent in
            EventPaymentView(
                paymentIntent: paymentIntent,
                participationId: currentParticipationId,
                event: selectedEventForPayment,
                onPaymentComplete: { success in
                    currentPaymentIntent = nil
                    currentParticipationId = nil
                    selectedEventForPayment = nil
                }
            )
            .environmentObject(themeManager)
            .environmentObject(paymentService)
            .environmentObject(eventService)
        }
        .onDisappear {
            activityService.stopRealtimeUpdates()
        }
        .onAppear {
            currentDate = Date()
            setupServices()

            // Check if data was already preloaded by AuthenticatedView
            let wasPreloaded = UserDefaults.standard.bool(forKey: "home_data_preloaded")

            if wasPreloaded {
                // Data already loaded — just mark as ready, no API calls
                UserDefaults.standard.set(false, forKey: "home_data_preloaded")
                isInitialLoad = false
                activityService.startRealtimeUpdates(interval: 30)
            } else {
                // Fresh load (tab switch, pull-to-refresh, etc.)
                Task {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { await eventService.fetchEvents() }
                        group.addTask { await eventService.fetchUserParticipations() }
                        group.addTask { await classService.fetchMyClasses() }
                        group.addTask { await classService.loadTrainers() }
                        group.addTask { await classService.loadSessionsForDateIfNeeded(date: Date()) }
                        group.addTask {
                            await userStatsService.fetchComprehensiveStats()
                            await userStatsService.fetchDashboardSummary()
                        }
                        group.addTask { await userStatsService.fetchWorkoutHistory() }
                        group.addTask { await activityService.fetchAllData() }
                        group.addTask { await storyService.fetchStoriesFeed() }
                        group.addTask {
                            let nutritionService = NutritionService.shared
                            nutritionService.configure(authService: authService, gymService: gymService)
                            await nutritionService.getDashboard()
                        }
                    }

                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isInitialLoad = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper Methods
extension HomeView {
    private func setupServices() {
        gymService.authService = authService
        classService.authService = authService
        profileService.authService = authService
        userStatsService.authService = authService
        userStatsService.gymService = gymService
        storyService.authService = authService
        activityService.startRealtimeUpdates(interval: 30)
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager())
        .environmentObject(EventService())
        .environmentObject(AuthServiceDirect())
}
