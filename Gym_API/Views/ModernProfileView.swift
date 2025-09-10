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
    @State private var showingProfileOptions = false
    @State private var showingColorPicker = false
    @State private var selectedSection: ProfileSection = .achievements
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingEditProfile = false
    @State private var showingGymSelector = false
    @StateObject private var gymService = GymService.shared
    @State private var showProfileCelebration = false
    
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
            .safeAreaPadding(.top, 16)
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
            .sheet(isPresented: $showingProfileOptions) {
                ProfileOptionsSheet(
                    isPresented: $showingProfileOptions,
                    onEditProfile: { showingEditProfile = true },
                    onSettings: { showingSettings = true },
                    onGymSelector: { showingGymSelector = true },
                    onCustomizeColors: {
                        // Cerrar el sheet de opciones antes de abrir el de colores
                        showingProfileOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showingColorPicker = true
                        }
                    },
                    authService: authService,
                    gymService: gymService,
                    themeManager: themeManager
                )
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingGymSelector) {
                NavigationView {
                    GymSelectionView { selected in
                        gymService.selectGym(selected)
                        showingGymSelector = false
                    }
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                SimpleColorSettingsView()
                    .environmentObject(themeManager)
            }
        }
        .overlay(
            // Profile completion celebration overlay
            Group {
                if showProfileCelebration {
                    ProfileCompletionCelebration(
                        isShowing: $showProfileCelebration,
                        theme: themeManager.currentTheme
                    )
                    .zIndex(1000)
                }
            }
        )
        .onAppear {
            setupServices()
            loadData()
        }
        .onDisappear {
            // Asegurar que no quede un sheet pendiente al cambiar de tab
            showingColorPicker = false
            showingProfileOptions = false
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { await uploadProfileImage(image) }
            }
        }
    }
    
    // MARK: - Header Section
    private var profileHeader: some View {
        VStack(spacing: 24) {
            // Simple header con opciones
            HStack {
                Button(action: { showingProfileOptions = true }) {
                    HStack(spacing: 8) {
                        Text(gymDisplayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Avatar centrado sin borde
            VStack(spacing: 24) {
                Button(action: { showingImagePicker = true }) {
                    // Avatar sin borde gradiente
                    if let picture = profileService.userProfile?.picture,
                       let url = URL(string: picture) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 145, height: 145)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 145, height: 145)
                                .overlay(
                                    Text(getUserInitials())
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 145, height: 145)
                            .overlay(
                                Text(getUserInitials())
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Change profile picture"))
                
                // User Name, Role and Bio
                VStack(spacing: 8) {
                    Text(profileService.userProfile?.fullName ?? "Jose Paul Rodriguez")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                    
                    // User Role below name
                    Text(profileService.userProfile?.displayRole ?? "Member")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    
                    // Bio (si existe)
                    if let bio = profileService.userProfile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .lineLimit(3)
                    }
                }
                
                // Animated metrics container replacing the old static layout
                EnhancedProfileMetricsContainer(
                    profileService: profileService,
                    userStatsService: userStatsService,
                    theme: themeManager.currentTheme,
                    showCelebration: $showProfileCelebration
                )
                
                // Badges (centered and properly spaced) - only streak badge now
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
            Text("Achievements")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            // Loading state: evita parpadeo mostrando datos obsoletos
            if userStatsService.isLoading && userStatsService.comprehensiveStats == nil {
                achievementsSkeleton
            } else {
            // Call-to-action card for new users
            if userStatsService.userStats.monthlyClasses == 0 {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Trophy icon
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.yellow)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Record your first workout")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("to unlock achievements!")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Tip: set a weekly goal to stay on track")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .padding(.top, 4)
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(userStatsService.achievements) { achievement in
                            ProfileAchievementCard(achievement: achievement, theme: themeManager.currentTheme)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Quick Stats - Fixed sizing and alignment
            HStack(spacing: 16) {
                // Total Workouts Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
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
    }

    // Simple skeleton para evitar flicker mientras carga
    private var achievementsSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .frame(width: 140, height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 0.5)
                        )
                        .redacted(reason: .placeholder)
                }
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
        // Limpiar logros previos para evitar parpadeo con datos antiguos
        userStatsService.achievements = []
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
    
    // Returns first word and, if present, the second word (second given name or first surname)
    private func shortDisplayName(from profile: UserProfile) -> String {
        let parts = profile.fullName.split(separator: " ").map(String.init)
        guard let first = parts.first else { return profile.fullName }
        if parts.count >= 2 {
            return first + " " + parts[1]
        }
        return first
    }
    
    // Extracts user initials for avatar fallback
    private func getUserInitials() -> String {
        let fullName = profileService.userProfile?.fullName ?? "Jose Paul Rodriguez"
        let parts = fullName.split(separator: " ").map(String.init)
        
        if parts.count >= 2 {
            // First name initial + Last name initial
            let firstInitial = String(parts[0].prefix(1)).uppercased()
            let lastInitial = String(parts[parts.count - 1].prefix(1)).uppercased()
            return firstInitial + lastInitial
        } else if let first = parts.first {
            // Solo primera inicial si hay un solo nombre
            return String(first.prefix(1)).uppercased()
        } else {
            // Fallback si no hay nombre
            return "U"
        }
    }
    
    // Computed property for gym display name in header
    private var gymDisplayName: String {
        if let currentGym = gymService.currentGym {
            return currentGym.name
        } else if gymService.isLoadingGyms {
            return "Loading..."
        } else {
            return "Select Gym"
        }
    }
}
