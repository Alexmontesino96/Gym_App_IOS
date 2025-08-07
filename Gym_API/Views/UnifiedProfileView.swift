import SwiftUI

// MARK: - Social Profile View
/// Vista de perfil social moderna inspirada en redes sociales y fitness apps.
/// Incluye header hero, stats de gimnasio, bio, actividad reciente, y recomendaciones.
/// Diseño completamente rediseñado para una experiencia social inmersiva.
struct UnifiedProfileView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var profileService: UserProfileService
    @EnvironmentObject var oneSignalService: OneSignalService
    @StateObject private var membershipService = MembershipService.shared
    @StateObject private var gymService = GymService.shared
    @StateObject private var profileImageService = ProfileImageService()
    
    // Image picker state
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    // Modal states
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingGymSelector = false
    
    // Alert states
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Animation states
    @State private var headerScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0.0
    @State private var cardsOffset: CGFloat = 50
    @State private var refreshID = UUID()
    @State private var socialDataLoaded = false
    
    let onThemeChangeRequest: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Social media inspired gradient background
                LinearGradient(
                    colors: [
                        Color.dynamicBackground(theme: themeManager.currentTheme),
                        Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.95),
                        Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if profileService.isLoading {
                    SocialProfileLoadingView(themeManager: themeManager)
                } else if let profile = profileService.userProfile ?? createFallbackProfile() {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Hero Profile Header (Social Media Style)
                            SocialProfileHero(
                                profile: profile,
                                onImageTap: { showingImagePicker = true },
                                themeManager: themeManager,
                                profileImageService: profileImageService
                            )
                            .scaleEffect(headerScale)
                            .opacity(headerOpacity)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: headerScale)
                            .animation(.easeOut(duration: 0.6), value: headerOpacity)
                            
                            // Fitness Stats Row (Instagram Stories Style)
                            FitnessStatsRow(profile: profile, themeManager: themeManager)
                                .offset(y: cardsOffset)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: cardsOffset)
                            
                            // Bio & About Section
                            if profile.bio != nil || profile.goals != nil {
                                SocialBioSection(profile: profile, themeManager: themeManager)
                                    .offset(y: cardsOffset)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: cardsOffset)
                            }
                            
                            // Current Gym Info (Social Card Style)
                            SocialGymCard(
                                gymService: gymService,
                                membershipService: membershipService,
                                themeManager: themeManager,
                                onSwitchGym: { showingGymSelector = true }
                            )
                            .offset(y: cardsOffset)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: cardsOffset)
                            
                            // Recent Activity Feed
                            RecentActivitySection(profile: profile, themeManager: themeManager)
                                .offset(y: cardsOffset)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: cardsOffset)
                            
                            // Recommended For You Section
                            ProfileRecommendedSection(themeManager: themeManager)
                                .offset(y: cardsOffset)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: cardsOffset)
                            
                            // Quick Settings & Actions
                            SocialQuickActions(
                                themeManager: themeManager,
                                onSettingsRequest: { showingSettings = true },
                                onThemeChangeRequest: onThemeChangeRequest,
                                onGymSelectorRequest: { showingGymSelector = true },
                                authService: authService
                            )
                            .offset(y: cardsOffset)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: cardsOffset)
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .refreshable {
                        await refreshProfile()
                    }
                } else {
                    ProfileErrorView(themeManager: themeManager)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .onAppear {
                setupServices()
                withAnimation {
                    headerScale = 1.0
                    headerOpacity = 1.0
                    cardsOffset = 0
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    sourceType: .photoLibrary,
                    selectedImage: $selectedImage,
                    isPresented: $showingImagePicker
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(onThemeChangeRequest: onThemeChangeRequest)
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                    .environmentObject(profileService)
            }
            .sheet(isPresented: $showingGymSelector) {
                UnifiedGymSelectorModal(
                    gymService: gymService,
                    themeManager: themeManager,
                    isPresented: $showingGymSelector
                )
            }
            .alert("Información", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    Task {
                        await uploadProfileImage(image)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupServices() {
        membershipService.authService = authService
        gymService.authService = authService
        profileImageService.authService = authService
        profileService.authService = authService
        
        Task {
            await loadProfileData()
        }
    }
    
    private func loadProfileData() async {
        async let membershipTask = membershipService.getMyMembershipStatus()
        async let gymTask = gymService.getMyGyms()
        async let profileTask = profileService.fetchUserProfile()
        
        await membershipTask
        await gymTask
        await profileTask
    }
    
    private func refreshProfile() async {
        refreshID = UUID()
        await profileService.fetchUserProfile()
        await loadProfileData()
    }
    
    private func uploadProfileImage(_ image: UIImage) async {
        let success = await profileImageService.uploadProfileImage(image)
        
        await MainActor.run {
            if success {
                alertMessage = "Imagen de perfil actualizada exitosamente"
            } else {
                alertMessage = "Error al subir la imagen"
            }
            showingAlert = true
        }
    }
    
    /// Crea un perfil de fallback basado en los datos del AuthUser cuando el API no responde
    private func createFallbackProfile() -> UserProfile? {
        guard let authUser = authService.user else { return nil }
        
        // Separar el nombre completo en firstName y lastName
        let nameParts = authUser.name.split(separator: " ")
        let firstName = String(nameParts.first ?? "")
        let lastName = nameParts.count > 1 ? String(nameParts.dropFirst().joined(separator: " ")) : ""
        
        return UserProfile(
            id: Int(authUser.id.suffix(6)) ?? 123456, // Usar los últimos 6 caracteres como ID numérico
            email: authUser.email,
            isActive: true,
            isSuperuser: false,
            firstName: firstName,
            lastName: lastName,
            role: authUser.isCoach ? "TRAINER" : "MEMBER",
            phoneNumber: nil,
            birthDate: nil,
            height: nil,
            weight: nil,
            bio: nil,
            goals: nil,
            healthConditions: nil,
            gymRole: authUser.isCoach ? "TRAINER" : "MEMBER",
            qrCode: "fallback-qr-\(authUser.id)",
            createdAt: Date(),
            updatedAt: Date(),
            auth0Id: authUser.id,
            picture: authUser.picture
        )
    }
}

// MARK: - Social Profile Hero
struct SocialProfileHero: View {
    let profile: UserProfile
    let onImageTap: () -> Void
    let themeManager: ThemeManager
    let profileImageService: ProfileImageService
    
    var body: some View {
        ZStack {
            // Dark hero background inspired by the reference image
            LinearGradient(
                colors: [
                    Color.black.opacity(0.9),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.5),
                    Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            
            VStack(spacing: 24) {
                Spacer(minLength: 30)
                
                // Large centered profile image (like Maria Parker in reference)
                Button(action: onImageTap) {
                    AsyncImage(url: URL(string: profile.picture ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8),
                                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 65, weight: .light))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.dynamicAccent(theme: themeManager.currentTheme),
                                        Color.white.opacity(0.8),
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Name prominently displayed (like Maria Parker)
                Text(profile.fullName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 2)
                
                // Role badge with green indicator (Coach style from reference)
                HStack(spacing: 10) {
                    Circle()
                        .fill(profile.role == "TRAINER" ? Color.green : Color.blue)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Text(profile.role == "TRAINER" ? "Coach" : "Member")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Spacer(minLength: 30)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}

// MARK: - Fitness Stats Row (Instagram Stories Style)
struct FitnessStatsRow: View {
    let profile: UserProfile
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Weight Stat
            SocialStatCard(
                title: "Weight",
                value: profile.weight != nil ? "\(Int(profile.weight!)) kg" : "--",
                icon: "scalemass",
                color: Color.blue,
                themeManager: themeManager
            )
            
            // Height Stat
            SocialStatCard(
                title: "Height",
                value: profile.height != nil ? "\(Int(profile.height!)) cm" : "--",
                icon: "ruler",
                color: Color.green,
                themeManager: themeManager
            )
            
            // Age Stat
            SocialStatCard(
                title: "Age",
                value: profile.age != nil ? "\(profile.age!)" : "--",
                icon: "calendar",
                color: Color.orange,
                themeManager: themeManager
            )
            
            // Member Since
            SocialStatCard(
                title: "Member",
                value: profile.memberSince.prefix(3) + " '" + String(profile.memberSince.suffix(2)),
                icon: "star.fill",
                color: Color.dynamicAccent(theme: themeManager.currentTheme),
                themeManager: themeManager
            )
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Social Stat Card
struct SocialStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 6) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Value
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Title
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Social Bio Section
struct SocialBioSection: View {
    let profile: UserProfile
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bio = profile.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text("About")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                    }
                    
                    Text(bio)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.8))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
            }
            
            if let goals = profile.goals, !goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("Goals")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                    }
                    
                    Text(goals)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.8))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
}

// MARK: - Modern Membership Card
struct ModernMembershipCard: View {
    @ObservedObject var membershipService: MembershipService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            if membershipService.isLoading {
                ProfileLoadingCard(themeManager: themeManager)
            } else if let membership = membershipService.membershipStatus {
                // Modern membership card design
                ZStack {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(membership.statusColor).opacity(0.8),
                                    Color(membership.statusColor).opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Card content
                    VStack(spacing: 16) {
                        // Header with icon and status
                        HStack {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: membership.membershipIcon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Membership")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(membership.membershipDisplayName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Spacer()
                            
                            // Status indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                                
                                Text(membership.statusText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        }
                        
                        // Expiration info (if available)
                        if let expiresAt = membership.expiresAt, !expiresAt.isEmpty {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(membership.expirationText)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Spacer()
                                
                                if let days = membership.daysRemaining, days > 0 {
                                    Text("\(days) days left")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                        )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                ProfileMembershipErrorCard(themeManager: themeManager)
            }
        }
    }
}

// MARK: - Loading Card
struct ProfileLoadingCard: View {
    let themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isAnimating)
                .onAppear { isAnimating = true }
            
            Text("Loading membership...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Membership Error Card
struct ProfileMembershipErrorCard: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text("Unable to load membership")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Quick Actions Grid
struct QuickActionsGrid: View {
    let themeManager: ThemeManager
    let onSettingsRequest: () -> Void
    let onThemeChangeRequest: () -> Void
    let onGymSelectorRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                QuickActionCard(
                    title: "Settings",
                    icon: "gear",
                    color: .blue,
                    action: onSettingsRequest,
                    themeManager: themeManager
                )
                
                QuickActionCard(
                    title: themeManager.currentTheme == .dark ? "Light Mode" : "Dark Mode",
                    icon: themeManager.currentTheme == .dark ? "sun.max" : "moon",
                    color: .orange,
                    action: onThemeChangeRequest,
                    themeManager: themeManager
                )
                
                QuickActionCard(
                    title: "Switch Gym",
                    icon: "building.2",
                    color: Color.dynamicAccent(theme: themeManager.currentTheme),
                    action: onGymSelectorRequest,
                    themeManager: themeManager
                )
                
                QuickActionCard(
                    title: "Support",
                    icon: "questionmark.circle",
                    color: .purple,
                    action: {},
                    themeManager: themeManager
                )
            }
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let themeManager: ThemeManager
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Modern Current Gym Section
struct ModernCurrentGymSection: View {
    @ObservedObject var gymService: GymService
    let themeManager: ThemeManager
    let onSwitchGym: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Gym")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            
            if let currentGym = gymService.currentGym {
                ModernGymCard(gym: currentGym, onSwitchGym: onSwitchGym, themeManager: themeManager)
            } else {
                NoGymSelectedCard(onSwitchGym: onSwitchGym, themeManager: themeManager)
            }
        }
    }
}

// MARK: - Modern Gym Card
struct ModernGymCard: View {
    let gym: GymInfo
    let onSwitchGym: () -> Void
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Gym icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "building.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Gym information
            VStack(alignment: .leading, spacing: 6) {
                Text(gym.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                
                Text(gym.address)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Switch button
            Button(action: onSwitchGym) {
                Text("Switch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 1.5)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - No Gym Selected Card
struct NoGymSelectedCard: View {
    let onSwitchGym: () -> Void
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            
            Text("No gym selected")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
            
            Button(action: onSwitchGym) {
                Text("Select Gym")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Modern Logout Button
struct ModernLogoutButton: View {
    let authService: AuthServiceDirect
    let themeManager: ThemeManager
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            Task {
                await authService.logout()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color.red,
                        Color.red.opacity(0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: Color.red.opacity(0.3),
                radius: isPressed ? 8 : 12,
                x: 0,
                y: isPressed ? 4 : 8
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}


// MARK: - Unified Gym Selector Modal
struct UnifiedGymSelectorModal: View {
    @ObservedObject var gymService: GymService
    let themeManager: ThemeManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if gymService.isLoadingGyms {
                    ProgressView("Cargando gimnasios...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                } else if gymService.myGyms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 50))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                        
                        Text("No tienes gimnasios disponibles")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(gymService.myGyms, id: \.id) { gym in
                                UnifiedGymSelectorRow(
                                    gym: gym,
                                    isSelected: gym.id == gymService.currentGym?.id,
                                    themeManager: themeManager
                                ) {
                                    gymService.selectGym(gym)
                                    isPresented = false
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Seleccionar Gimnasio")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Unified Gym Selector Row
struct UnifiedGymSelectorRow: View {
    let gym: GymInfo
    let isSelected: Bool
    let themeManager: ThemeManager
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gym.name)
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(gym.address)
                        .font(.caption)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Modern Loading View
struct ProfileLoadingView: View {
    let themeManager: ThemeManager
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#D93333")!.opacity(0.3),
                                Color(hex: "#D93333")!.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0.0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#D93333")!,
                                Color(hex: "#FF6B6B")!
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
            }
            
            Text("Loading profile...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Modern Error View
struct ProfileErrorView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Unable to load profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Please check your connection and try again")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Extensions
extension View {
    func onPressGesture(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}


// MARK: - Social Gym Card
struct SocialGymCard: View {
    @ObservedObject var gymService: GymService
    @ObservedObject var membershipService: MembershipService
    let themeManager: ThemeManager
    let onSwitchGym: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                
                Text("My Gym")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                Button("Switch") {
                    onSwitchGym()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            
            if let currentGym = gymService.currentGym {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8),
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentGym.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text(currentGym.address)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Membership status indicator
                    if let membership = membershipService.membershipStatus {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(membership.statusText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(membership.statusColor))
                                )
                            
                            if let days = membership.daysRemaining, days > 0 {
                                Text("\(days) days")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "building.2")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No gym selected")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                        
                        Text("Choose your gym to get started")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.4))
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    let profile: UserProfile
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                
                Text("Recent Activity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                Button("View All") {
                    // Navigate to activity history
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            
            LazyVStack(spacing: 12) {
                ActivityFeedItem(
                    icon: "figure.strengthtraining.traditional",
                    title: "Completed Strength Session",
                    subtitle: "Upper Body Workout • 45 min",
                    time: "2 hours ago",
                    color: .orange,
                    themeManager: themeManager
                )
                
                ActivityFeedItem(
                    icon: "figure.run",
                    title: "Finished Cardio Session",
                    subtitle: "5K Running • 32 min",
                    time: "Yesterday",
                    color: .green,
                    themeManager: themeManager
                )
                
                ActivityFeedItem(
                    icon: "figure.yoga",
                    title: "Attended Yoga Class",
                    subtitle: "Morning Flow • 60 min",
                    time: "2 days ago",
                    color: .purple,
                    themeManager: themeManager
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Activity Feed Item
struct ActivityFeedItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Activity details
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
            }
            
            Spacer()
            
            // Time indicator
            Text(time)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recommended Section
struct ProfileRecommendedSection: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Recommended")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                Button("See All") {
                    // Navigate to recommendations
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    RecommendationCard(
                        title: "Kickboxing",
                        subtitle: "High Intensity",
                        icon: "figure.boxing",
                        color: Color.dynamicAccent(theme: themeManager.currentTheme),
                        themeManager: themeManager
                    )
                    
                    RecommendationCard(
                        title: "Personal Training",
                        subtitle: "1-on-1 Session",
                        icon: "person.2.fill",
                        color: .blue,
                        themeManager: themeManager
                    )
                    
                    RecommendationCard(
                        title: "Nutrition Plan",
                        subtitle: "Custom Diet",
                        icon: "leaf.fill",
                        color: .green,
                        themeManager: themeManager
                    )
                    
                    RecommendationCard(
                        title: "Yoga Flow",
                        subtitle: "Mindfulness",
                        icon: "figure.yoga",
                        color: .purple,
                        themeManager: themeManager
                    )
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Recommendation Card
struct RecommendationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with gradient background (like image reference)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 70)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 8)
    }
}

// MARK: - Social Quick Actions
struct SocialQuickActions: View {
    let themeManager: ThemeManager
    let onSettingsRequest: () -> Void
    let onThemeChangeRequest: () -> Void
    let onGymSelectorRequest: () -> Void
    let authService: AuthServiceDirect
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                
                Text("Quick Actions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
            }
            
            // Main action buttons in grid layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                SocialActionButton(
                    title: "Edit Profile",
                    icon: "person.crop.circle",
                    color: .blue,
                    action: {},
                    themeManager: themeManager
                )
                
                SocialActionButton(
                    title: "Settings",
                    icon: "gear",
                    color: .gray,
                    action: onSettingsRequest,
                    themeManager: themeManager
                )
                
                SocialActionButton(
                    title: themeManager.currentTheme == .dark ? "Light" : "Dark",
                    icon: themeManager.currentTheme == .dark ? "sun.max" : "moon",
                    color: .orange,
                    action: onThemeChangeRequest,
                    themeManager: themeManager
                )
                
                SocialActionButton(
                    title: "Switch Gym",
                    icon: "building.2",
                    color: Color.dynamicAccent(theme: themeManager.currentTheme),
                    action: onGymSelectorRequest,
                    themeManager: themeManager
                )
            }
            
            // Logout button as full-width special action
            Button(action: {
                Task {
                    await authService.logout()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Social Action Button
struct SocialActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let themeManager: ThemeManager
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 85)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Social Profile Loading View
struct SocialProfileLoadingView: View {
    let themeManager: ThemeManager
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32) {
            // Hero loading placeholder
            VStack(spacing: 20) {
                // Profile image placeholder with pulse animation
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)
                    .overlay(
                        Circle()
                            .trim(from: 0.0, to: 0.3)
                            .stroke(
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(rotationAngle))
                            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
                    )
                
                // Name placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2))
                    .frame(width: 180, height: 24)
                    .redacted(reason: .placeholder)
                
                // Role placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.15))
                    .frame(width: 100, height: 16)
                    .redacted(reason: .placeholder)
            }
            
            // Stats row placeholder
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.15))
                            .frame(width: 40, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.1))
                            .frame(width: 30, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                Text("Loading your social profile...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Getting your fitness journey ready")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            rotationAngle = 360
            pulseScale = 1.1
        }
    }
}

// MARK: - Preview
#Preview {
    UnifiedProfileView(onThemeChangeRequest: {})
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
        .environmentObject(UserProfileService.shared)
        .environmentObject(OneSignalService.shared)
}