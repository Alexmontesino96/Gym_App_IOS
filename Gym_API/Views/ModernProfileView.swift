import SwiftUI

// MARK: - Modern Profile View
struct ModernProfileView: View {
    // MARK: - Environment & State
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var colorCustomizationManager = ColorCustomizationManager.shared
    @StateObject private var profileService = UserProfileService.shared
    @StateObject private var userStatsService = UserStatsService.shared
    
    @State private var showingSettings = false
    @State private var showingColorPicker = false
    @State private var selectedSection: ProfileSection = .achievements
    
    // MARK: - Profile Sections
    enum ProfileSection: String, CaseIterable {
        case achievements = "Achievements"
        case analytics = "Analytics"
        case social = "Social"
        case goals = "Goals"
        case history = "History"
        
        var iconName: String {
            switch self {
            case .achievements: return "trophy.fill"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .social: return "person.2.fill"
            case .goals: return "target"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Compact Header with Settings Icon
                        profileHeader
                        
                        // Section Selector
                        sectionSelector
                        
                        // Dynamic Content Based on Selection
                        Group {
                            switch selectedSection {
                            case .achievements:
                                achievementShowcase
                            case .analytics:
                                progressAnalytics
                            case .social:
                                socialFitnessJourney
                            case .goals:
                                personalGoalsTracking
                            case .history:
                                trainingHistory
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSettings) {
                SettingsView(onThemeChangeRequest: {})
            }
            .sheet(isPresented: $showingColorPicker) {
                ProfileColorPickerSheet(
                    isPresented: $showingColorPicker,
                    currentColor: colorCustomizationManager.currentBackgroundColor
                )
                .environmentObject(themeManager)
                .environmentObject(colorCustomizationManager)
            }
        }
        .onAppear {
            setupServices()
            loadData()
        }
    }
    
    // MARK: - Header Section
    private var profileHeader: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: colorCustomizationManager.currentBackgroundColor.gradientColors + [
                    Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .cornerRadius(20)
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                // Top Bar with Settings
                HStack {
                    Spacer()
                    
                    // Settings Icon
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .background(
                                        VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                                            .clipShape(Circle())
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                // Profile Picture and Info
                VStack(spacing: 8) {
                    ZStack {
                        // Profile Image
                        if let picture = profileService.userProfile?.picture,
                           let url = URL(string: picture) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            colorCustomizationManager.currentBackgroundColor.accentColor.opacity(0.8),
                                            colorCustomizationManager.currentBackgroundColor.accentColor.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(profileService.userProfile?.fullName.prefix(2).uppercased() ?? "??")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        // Edit Color Button
                        Button(action: { showingColorPicker = true }) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.85, green: 0.2, blue: 0.2))
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                )
                        }
                        .offset(x: 30, y: 30)
                    }
                    
                    // Name and Role
                    Text(profileService.userProfile?.fullName ?? "Loading...")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        // Streak Badge
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("\(userStatsService.userStats.currentStreak) days")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                        
                        // Member Badge
                        Text(profileService.userProfile?.displayRole ?? "Member")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Section Selector
    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ProfileSection.allCases, id: \.self) { section in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSection = section
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(
                                    selectedSection == section
                                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                        : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6)
                                )
                            
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(
                                    selectedSection == section
                                        ? Color.dynamicText(theme: themeManager.currentTheme)
                                        : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6)
                                )
                            
                            // Selection Indicator
                            Rectangle()
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .frame(height: 2)
                                .opacity(selectedSection == section ? 1 : 0)
                        }
                        .frame(width: 80)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Achievement Showcase
    private var achievementShowcase: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Achievements")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(userStatsService.achievements) { achievement in
                        ProfileAchievementCard(achievement: achievement, theme: themeManager.currentTheme)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Quick Stats
            HStack(spacing: 16) {
                ProfileStatCard(
                    title: "Total Workouts",
                    value: "\(userStatsService.userStats.monthlyClasses)",
                    icon: "figure.strengthtraining.traditional",
                    color: .blue,
                    theme: themeManager.currentTheme
                )
                
                ProfileStatCard(
                    title: "This Week",
                    value: "\(userStatsService.userStats.weeklyClasses)",
                    icon: "calendar",
                    color: .green,
                    theme: themeManager.currentTheme
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Progress Analytics
    private var progressAnalytics: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Activity Analytics")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            // Weekly Activity Heatmap
            WeeklyActivityView(
                weeklyData: userStatsService.activityAnalytics?.weeklyData ?? [],
                theme: themeManager.currentTheme
            )
            .padding(.horizontal, 20)
            
            // Category Breakdown
            CategoryBreakdownView(
                categoryData: userStatsService.activityAnalytics?.categoryBreakdown ?? [],
                theme: themeManager.currentTheme
            )
            .padding(.horizontal, 20)
            
            // Time Investment
            if let timeInvestment = userStatsService.activityAnalytics?.timeInvestment {
                TimeInvestmentCard(
                    timeInvestment: timeInvestment,
                    theme: themeManager.currentTheme
                )
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Social Fitness Journey
    private var socialFitnessJourney: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Fitness Community")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            // Leaderboard Position
            if let position = userStatsService.leaderboardPosition {
                LeaderboardCard(
                    entry: position,
                    theme: themeManager.currentTheme
                )
                .padding(.horizontal, 20)
            }
            
            // Workout Buddies
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout Partners")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.8))
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(userStatsService.workoutBuddies) { buddy in
                            WorkoutBuddyCard(buddy: buddy, theme: themeManager.currentTheme)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Personal Goals & Tracking
    private var personalGoalsTracking: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Active Goals")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            ForEach(userStatsService.personalGoals) { goal in
                PersonalGoalCard(goal: goal, theme: themeManager.currentTheme)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Training History
    private var trainingHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Workouts")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            ForEach(userStatsService.workoutHistory) { workout in
                WorkoutHistoryCard(workout: workout, theme: themeManager.currentTheme)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupServices() {
        userStatsService.authService = authService
        userStatsService.gymService = GymService.shared
        profileService.authService = authService
        colorCustomizationManager.authService = authService
        colorCustomizationManager.profileService = profileService
    }
    
    private func loadData() {
        Task {
            await profileService.fetchUserProfile()
            await userStatsService.fetchComprehensiveStats()
            await userStatsService.fetchWorkoutHistory()
            await userStatsService.fetchPersonalGoals()
            await userStatsService.fetchWorkoutBuddies()
            await userStatsService.fetchLeaderboardPosition()
            await userStatsService.fetchActivityAnalytics()
            
            // Load color from profile
            if let profile = profileService.userProfile {
                colorCustomizationManager.loadColorFromProfile(profile)
            }
        }
    }
}