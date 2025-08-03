import SwiftUI

// MARK: - Modern Profile View
struct ModernProfileView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var profileService: UserProfileService
    @StateObject private var membershipService = MembershipService.shared
    @StateObject private var gymService = GymService.shared
    @StateObject private var profileImageService = ProfileImageService()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let onThemeChangeRequest: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background that respects theme
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if profileService.isLoading {
                    ProgressView("Cargando perfil...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                } else if let profile = profileService.userProfile {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header Section with Profile Image
                            ProfileHeaderSection(
                                profile: profile,
                                onImageTap: { showingImagePicker = true },
                                themeManager: themeManager,
                                profileImageService: profileImageService
                            )
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                            
                            // Stats Section
                            StatsSection(
                                profile: profile,
                                membershipService: membershipService,
                                themeManager: themeManager
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 25)
                            
                            // Bio Section
                            BioSection(bio: profile.bio, themeManager: themeManager)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 25)
                            
                            // Recommended Section
                            RecommendedSection(themeManager: themeManager)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 80) // Space for tab bar
                        }
                    }
                    .refreshable {
                        async let profileRefresh: Void = profileService.refreshProfile()
                        async let membershipRefresh: Void = membershipService.refreshMembershipStatus()
                        
                        await profileRefresh
                        await membershipRefresh
                    }
                } else {
                    // Error State
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        Text("No se pudo cargar el perfil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        if let error = profileService.error {
                            Text(error.localizedDescription)
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button("Reintentar") {
                            Task {
                                await profileService.fetchUserProfile()
                            }
                        }
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 2)
                        )
                    }
                }
            }
            .navigationBarHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .onAppear {
            Task {
                await profileService.fetchUserProfile()
                await membershipService.getMyMembershipStatus()
            }
            profileImageService.authService = authService
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerSheet(selectedImage: $selectedImage, isPresented: $showingImagePicker)
                .environmentObject(themeManager)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task {
                    let success = await profileImageService.uploadProfileImage(image)
                    if success {
                        // Actualizar el perfil del usuario
                        await profileService.refreshProfile()
                        alertMessage = "Foto de perfil actualizada exitosamente"
                        showingAlert = true
                    } else {
                        alertMessage = profileImageService.uploadError ?? "Error al actualizar la foto de perfil"
                        showingAlert = true
                    }
                    selectedImage = nil // Reset selection
                }
            }
        }
        .alert("Actualización de Perfil", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingEditProfile) {
            Text("Edit Profile")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onThemeChangeRequest: onThemeChangeRequest)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(profileService)
        }
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    let profile: UserProfile
    let onImageTap: () -> Void
    let themeManager: ThemeManager
    let profileImageService: ProfileImageService
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image with Instagram-style edit button
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: profileImageService.profileImageURL ?? profile.picture ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        Circle()
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
                            .frame(width: 140, height: 140)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Instagram-style edit button
                Button(action: onImageTap) {
                    ZStack {
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .strokeBorder(Color.dynamicBackground(theme: themeManager.currentTheme), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: -5, y: -5)
                
                // Loading overlay
                if profileImageService.isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 140, height: 140)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        )
                }
            }
            
            // Name and Role
            VStack(spacing: 8) {
                Text(profile.fullName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text(profile.displayRole)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
    }
}

// MARK: - Stats Section
struct StatsSection: View {
    let profile: UserProfile
    let membershipService: MembershipService
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 40) {
            // Weight
            StatItem(
                title: "Weight",
                value: profile.weight != nil ? "\(Int(profile.weight!)) lbs" : "155 lbs",
                themeManager: themeManager
            )
            
            // Height
            StatItem(
                title: "Height", 
                value: profile.heightDisplay ?? (profile.height != nil ? "\(Int(profile.height!))cm" : "5'8\""),
                themeManager: themeManager
            )
            
            // Age
            StatItem(
                title: "Age",
                value: profile.age != nil ? "\(profile.age!)" : "30",
                themeManager: themeManager
            )
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
    }
}

// MARK: - Bio Section
struct BioSection: View {
    let bio: String?
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bio")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(bio ?? "I'm dedicated to helping my clients achieve their fitness goals and overcome any obstacles they face.")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Recommended Section
struct RecommendedSection: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    RecommendedCard(
                        title: "Kickboxing",
                        icon: "figure.boxing",
                        color: .red,
                        themeManager: themeManager
                    )
                    
                    RecommendedCard(
                        title: "Shin Guard",
                        icon: "shield.fill",
                        color: .blue,
                        themeManager: themeManager
                    )
                    
                    RecommendedCard(
                        title: "Boxing",
                        icon: "sportscourt.fill",
                        color: .orange,
                        themeManager: themeManager
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Recommended Card
struct RecommendedCard: View {
    let title: String
    let icon: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                )
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
        }
        .frame(width: 100)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

// MARK: - Preview
#Preview {
    ModernProfileView(onThemeChangeRequest: {})
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(UserProfileService.shared)
}