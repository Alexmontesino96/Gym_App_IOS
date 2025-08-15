import SwiftUI

// MARK: - Modern Profile View
struct ModernProfileView: View {
    // MARK: - Environment & State
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var colorCustomizationManager = ColorCustomizationManager.shared
    @StateObject private var profileService = UserProfileService.shared
    @StateObject private var userStatsService = UserStatsService.shared
    @StateObject private var profileImageService = ProfileImageService()
    
    @State private var showingSettings = false
    @State private var selectedSection: ProfileSection = .achievements
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
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
                // Loading & Error Overlays
                if profileService.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(NSLocalizedString("loading_profile", comment: "Loading profile"))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.6))
                } else if profileService.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.system(size: 24))
                        Text(NSLocalizedString("failed_load_profile", comment: "Failed to load profile"))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Button(NSLocalizedString("retry", comment: "Retry")) {
                            Task { await profileService.fetchUserProfile() }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.dynamicSurface(theme: themeManager.currentTheme)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSettings) {
                SettingsView(onThemeChangeRequest: {})
            }
            .sheet(isPresented: $showingImagePicker) {
                EnhancedImagePickerSheet(
                    selectedImage: $selectedImage,
                    isPresented: $showingImagePicker
                )
                .environmentObject(themeManager)
                .interactiveDismissDisabled(true)
            }
        }
        .onAppear {
            setupServices()
            loadData()
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { await uploadProfileImage(image) }
            }
        }
    }
    
    // MARK: - Header Section
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Settings Bar
            HStack {
                Spacer()
                
                // Settings Icon
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
                .accessibilityLabel(Text("Settings"))
            }
            .padding(.horizontal, 20)
            
            // Instagram-style Profile Layout
            VStack(spacing: 20) {
                // Horizontal Profile Section
                HStack(spacing: 20) {
                    // Profile Picture (circular, Instagram-style)
                    if let picture = profileService.userProfile?.picture,
                       let url = URL(string: picture) {
                        Button(action: { showingImagePicker = true }) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 35))
                                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.4))
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 3)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(NSLocalizedString("change_profile_picture", comment: "Change profile picture")))
                    } else {
                        Button(action: { showingImagePicker = true }) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            colorCustomizationManager.currentBackgroundColor.accentColor.opacity(0.8),
                                            colorCustomizationManager.currentBackgroundColor.accentColor.opacity(0.6)
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
                                .overlay(
                                    Circle()
                                        .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 3)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(NSLocalizedString("change_profile_picture", comment: "Change profile picture")))
                    }
                    
                    // Stats Grid (Instagram-style) - Improved spacing
                    HStack(spacing: 10) {
                        // Total Workouts
                        VStack(spacing: 4) {
                            Text("\(userStatsService.userStats.monthlyClasses)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                            Text(NSLocalizedString("workouts", comment: "Workouts label"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Subtle divider
                        Rectangle()
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.15))
                            .frame(width: 0.5, height: 30)
                        
                        // Weight
                        VStack(spacing: 4) {
                            if let weight = profileService.userProfile?.weight {
                                Text("\(Int(weight)) kg")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            } else {
                                Text("--")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            Text(NSLocalizedString("weight", comment: "Weight label"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Subtle divider
                        Rectangle()
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.15))
                            .frame(width: 0.5, height: 30)
                        
                        // Height
                        VStack(spacing: 4) {
                            if let height = profileService.userProfile?.height {
                                Text("\(Int(height)) cm")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            } else {
                                Text("--")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            Text(NSLocalizedString("height", comment: "Height label"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                
                // User Name and Bio
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(profileService.userProfile?.fullName ?? "Loading...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                    }
                    
                    if let bio = profileService.userProfile?.bio, !bio.isEmpty {
                        HStack {
                            Text(bio)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.8))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Badges (centered and properly spaced)
                HStack(spacing: 12) {
                    // Streak Badge
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        Text("\(userStatsService.userStats.currentStreak) day streak")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Member Badge
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                        Text(profileService.userProfile?.displayRole ?? "Member")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 24)
            }
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
                    .accessibilityLabel(Text("Open section \(section.rawValue)"))
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
            
            // Quick Stats - Fixed sizing and alignment
            HStack(spacing: 16) {
                // Total Workouts Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(userStatsService.userStats.monthlyClasses)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            Spacer()
                        }
                        
                        HStack {
                            Text("Total Workouts")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // This Week Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(userStatsService.userStats.weeklyClasses)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            Spacer()
                        }
                        
                        HStack {
                            Text("This Week")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
            .frame(minHeight: 120, maxHeight: 150)
            .frame(maxWidth: .infinity) // Limitar ancho máximo
            .padding(.horizontal, 20)
            
            // Category Breakdown
            CategoryBreakdownView(
                categoryData: userStatsService.activityAnalytics?.categoryBreakdown ?? [],
                theme: themeManager.currentTheme
            )
            .frame(minHeight: 140, maxHeight: 200)
            .frame(maxWidth: .infinity) // Limitar ancho máximo
            .padding(.horizontal, 20)
            
            // Time Investment
            if let timeInvestment = userStatsService.activityAnalytics?.timeInvestment {
                TimeInvestmentCard(
                    timeInvestment: timeInvestment,
                    theme: themeManager.currentTheme
                )
                .frame(minHeight: 120, maxHeight: 150)
                .frame(maxWidth: .infinity) // Limitar ancho máximo
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300) // Ancho limitado y altura mínima reducida
        .clipped() // Recortar contenido que se desborde
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
                .frame(height: 80)
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
                .frame(height: 120)
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
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(userStatsService.personalGoals) { goal in
                        PersonalGoalCard(goal: goal, theme: themeManager.currentTheme)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 300) // Limitar altura máxima
        }
    }
    
    // MARK: - Training History
    private var trainingHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Workouts")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(userStatsService.workoutHistory) { workout in
                        WorkoutHistoryCard(workout: workout, theme: themeManager.currentTheme)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 300) // Limitar altura máxima
        }
    }
    
    // MARK: - Helper Methods
    private func setupServices() {
        userStatsService.authService = authService
        userStatsService.gymService = GymService.shared
        profileService.authService = authService
        profileImageService.authService = authService
        colorCustomizationManager.authService = authService
        colorCustomizationManager.profileService = profileService
        
        // Configurar authService en GymService también
        GymService.shared.authService = authService
    }
    
    private func loadData() {
        Task {
            // Cargar perfil primero (evitar recargas innecesarias)
            await profileService.fetchUserProfileIfStale()
            
            // Asegurar que GymService esté inicializado con los datos del usuario
            await GymService.shared.getMyGyms()
            
            // Esperar un momento para asegurar que GymService esté completamente configurado
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Verificar que el gym service y gym ID estén disponibles antes de continuar
            guard GymService.shared.currentGymId != nil else {
                print("⚠️ [ModernProfileView] Gym service not ready, skipping stats loading")
                return
            }
            
            print("✅ [ModernProfileView] Gym service ready, loading stats with gym ID: \(GymService.shared.currentGymId!)")
            
            // Solo después de confirmar que tenemos gym seleccionado, cargar estadísticas
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

// MARK: - Upload Image
extension ModernProfileView {
    private func uploadProfileImage(_ image: UIImage) async {
        let success = await profileImageService.uploadProfileImage(image)
        if success {
            await profileService.refreshProfile()
        }
    }
}
