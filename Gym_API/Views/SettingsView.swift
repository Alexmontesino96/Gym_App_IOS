import SwiftUI
import Combine

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var profileService: UserProfileService
    @EnvironmentObject var eventService: EventService
    @ObservedObject private var membershipService = MembershipService.shared
    @StateObject private var oneSignalService = OneSignalService.shared
    @StateObject private var gymService = GymService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingMyGym = false
    // Removed bulk registration from Settings; entry now only from event actions
    
    let onThemeChangeRequest: () -> Void
    
    // MARK: - Initialization
    init(onThemeChangeRequest: @escaping () -> Void) {
        self.onThemeChangeRequest = onThemeChangeRequest
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // User Info Header
                        if let profile = profileService.userProfile {
                            UserInfoHeader(profile: profile, themeManager: themeManager)
                                .padding(.top, 20)
                        }
                        
                        // Settings Sections
                        VStack(spacing: 16) {
                            // Gym Section
                            GymSection(
                                gymService: gymService,
                                themeManager: themeManager,
                                showingMyGym: $showingMyGym
                            )
                            
                            // Membership Section
                            MembershipSection(
                                membershipService: membershipService,
                                themeManager: themeManager
                            )
                            
                            // Administrative Section (only for admins/owners)
                            if RolePermissions.isAdminLevel(gymService.currentGym?.userRoleInGym) {
                                SettingsCard(title: "Administration", themeManager: themeManager) {
                                    AdminSettingsSection(
                                        gymService: gymService,
                                        authService: authService,
                                        themeManager: themeManager
                                    )
                                }
                            }
                            
                            // Theme Section
                            ThemeSection(
                                themeManager: themeManager,
                                onThemeChange: onThemeChangeRequest
                            )
                            
                            // Notifications Section
                            NotificationsSection(
                                oneSignalService: oneSignalService,
                                themeManager: themeManager
                            )
                            
                            // Logout Section
                            LogoutSection(
                                authService: authService,
                                themeManager: themeManager
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .sheet(isPresented: $showingMyGym) {
            MyGymView()
                .environmentObject(themeManager)
                .environmentObject(authService)
        }
        // Bulk registration sheet removed from Settings
        .onReceive(authService.$isAuthenticated) { isAuthenticated in
            // Configurar AuthService en MembershipService cuando el estado de autenticación cambie
            membershipService.authService = authService
            
            // Si está autenticado y no hay datos de membresía, cargar
            if isAuthenticated && membershipService.membershipStatus == nil {
                Task {
                    await membershipService.getMyMembershipStatus()
                }
            }
        }
        .onAppear {
            // Configurar AuthService en MembershipService y GymService
            membershipService.authService = authService
            gymService.authService = authService
            
            // Dar un pequeño delay para asegurar que authService esté completamente listo
            Task {
                await gymService.getMyGyms()
                // Pequeño delay para permitir que authService se inicialice completamente
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
                
                // Solo cargar si no hay estado de membresía
                if membershipService.membershipStatus == nil {
                    await membershipService.getMyMembershipStatus()
                }
            }
        }
        
    }
}

// MARK: - User Info Header
struct UserInfoHeader: View {
    let profile: UserProfile
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: profile.picture ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
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
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.fullName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(profile.email ?? "Sin email")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Text(profile.displayRole)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Membership Section
struct MembershipSection: View {
    let membershipService: MembershipService
    let themeManager: ThemeManager
    
    var body: some View {
        SettingsCard(title: "Membership", themeManager: themeManager) {
            VStack(spacing: 12) {
                if let status = membershipService.membershipStatus {
                    SettingsRow(
                        icon: "checkmark.circle.fill",
                        title: "Status",
                        value: status.statusText,
                        themeManager: themeManager
                    )
                    
                    if let expiresAt = status.expiresAt {
                        SettingsRow(
                            icon: "calendar",
                            title: "Valid Until",
                            value: expiresAt,
                            themeManager: themeManager
                        )
                    }
                    
                    if let daysRemaining = status.daysRemaining {
                        SettingsRow(
                            icon: "clock",
                            title: "Days Remaining",
                            value: "\(daysRemaining) days",
                            themeManager: themeManager
                        )
                    }
                } else if membershipService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading membership...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                } else if let errorMessage = membershipService.errorMessage {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Failed to load membership")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await membershipService.forceRefresh()
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .padding(.top, 4)
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("No membership information available")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
            }
        }
    }
}

// MARK: - Gym Section
struct GymSection: View {
    @ObservedObject var gymService: GymService
    let themeManager: ThemeManager
    @Binding var showingMyGym: Bool
    
    var body: some View {
        SettingsCard(title: "My Gym", themeManager: themeManager) {
            VStack(spacing: 12) {
                if gymService.isLoadingGyms {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading gym...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                } else if let gym = gymService.currentGym {
                    Button(action: { showingMyGym = true }) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gym.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(gym.roleDisplayName)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    
                                    if gymService.myGyms.count > 1 {
                                        Text("•")
                                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                        Text("Tap to change")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "building.2")
                            .font(.system(size: 20))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No gym associated")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Contact your gym to get added")
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Theme Section
struct ThemeSection: View {
    let themeManager: ThemeManager
    let onThemeChange: () -> Void
    @State private var showingColorPicker = false
    
    var body: some View {
        SettingsCard(title: "Appearance", themeManager: themeManager) {
            VStack(spacing: 12) {
                // Theme Toggle
                Button(action: onThemeChange) {
                    HStack {
                        Image(systemName: themeManager.currentTheme == .light ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text(themeManager.currentTheme == .light ? "Light Mode" : "Dark Mode")
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                
                // Color Customization
                Button(action: { showingColorPicker = true }) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Colors")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Customize app and profile colors")
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                        
                        // Current accent color preview
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                            )
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                
                // Quick Color Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Themes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(quickThemePresets, id: \.name) { preset in
                                QuickThemeButton(
                                    preset: preset,
                                    isSelected: preset.accentColor == themeManager.accentHex(for: themeManager.currentTheme),
                                    themeManager: themeManager
                                ) {
                                    applyQuickTheme(preset)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            SimpleColorSettingsView()
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Quick Theme Data
    private var quickThemePresets: [QuickTheme] {
        [
            QuickTheme(name: "Red", accentColor: "#C43421", color: Color(red: 0.77, green: 0.20, blue: 0.13)),
            QuickTheme(name: "Blue", accentColor: "#29B6F6", color: Color(red: 0.16, green: 0.71, blue: 0.96)),
            QuickTheme(name: "Green", accentColor: "#66BB6A", color: Color(red: 0.40, green: 0.73, blue: 0.42)),
            QuickTheme(name: "Purple", accentColor: "#9575CD", color: Color(red: 0.58, green: 0.46, blue: 0.80)),
            QuickTheme(name: "Orange", accentColor: "#FF8C42", color: Color(red: 1.0, green: 0.55, blue: 0.26))
        ]
    }
    
    private func applyQuickTheme(_ preset: QuickTheme) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            themeManager.setAccentHex(preset.accentColor, for: themeManager.currentTheme)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Quick Theme Support
struct QuickTheme {
    let name: String
    let accentColor: String
    let color: Color
}

struct QuickThemeButton: View {
    let preset: QuickTheme
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(preset.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.clear,
                                lineWidth: 2
                            )
                            .frame(width: 36, height: 36)
                    )
                
                Text(preset.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notifications Section
struct NotificationsSection: View {
    let oneSignalService: OneSignalService
    let themeManager: ThemeManager
    @State private var notificationsEnabled = false
    
    var body: some View {
        SettingsCard(title: "Notifications", themeManager: themeManager) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Push Notifications")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("Receive updates about classes and events")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .onChange(of: notificationsEnabled) { _, newValue in
                    // Handle notification toggle
                    if newValue {
                        oneSignalService.requestNotificationPermission()
                    }
                }
                
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                
                SettingsRow(
                    icon: "person.badge.plus",
                    title: "Event Invitations",
                    value: "Enabled",
                    themeManager: themeManager
                )
                
                SettingsRow(
                    icon: "dumbbell",
                    title: "Class Reminders",
                    value: "Enabled",
                    themeManager: themeManager
                )
            }
        }
        .onAppear {
            // Sincronizar el estado del toggle con OneSignal
            notificationsEnabled = oneSignalService.isSubscribed()
        }
    }
}

// MARK: - Logout Section
struct LogoutSection: View {
    let authService: AuthServiceDirect
    let themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            Task {
                await authService.logout()
            }
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            )
        }
    }
}

// MARK: - Reusable Components

struct SettingsCard<Content: View>: View {
    let title: String
    let themeManager: ThemeManager
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// MARK: - Preview
// MARK: - Admin Settings Section
struct AdminSettingsSection: View {
    @ObservedObject var gymService: GymService
    let authService: AuthServiceDirect
    let themeManager: ThemeManager
    @State private var showingSurveyManagement = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Manage Users
            SettingsRow(
                icon: "person.2.fill",
                title: "Manage Users",
                value: "View all members",
                themeManager: themeManager
            )
            
            Divider()
                .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
            
            // Survey Management (for admins, owners, and trainers)
            if RolePermissions.canManageSurveys(gymService.currentGym?.userRoleInGym) {
                Button(action: { showingSurveyManagement = true }) {
                    SettingsRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Survey Management",
                        value: "Create & manage surveys",
                        themeManager: themeManager
                    )
                }
                
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
            }
            
            // Bulk registration removed from Settings; access via event options
            
            // Gym Settings (only for owners)
            if RolePermissions.canManageGym(gymService.currentGym?.userRoleInGym) {
                SettingsRow(
                    icon: "building.2.fill",
                    title: "Gym Settings",
                    value: "Configure gym",
                    themeManager: themeManager
                )
                
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
            }
            
            // Reports & Analytics
            if RolePermissions.canViewReports(gymService.currentGym?.userRoleInGym) {
                SettingsRow(
                    icon: "chart.bar.fill",
                    title: "Reports",
                    value: "View analytics",
                    themeManager: themeManager
                )
                
                Divider()
                    .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
            }
            
            // Event Management
            if RolePermissions.canCreateEvents(gymService.currentGym?.userRoleInGym) {
                SettingsRow(
                    icon: "calendar.badge.plus",
                    title: "Event Management",
                    value: "Manage all events",
                    themeManager: themeManager
                )
            }
        }
        .sheet(isPresented: $showingSurveyManagement) {
            SurveyManagementView()
                .environmentObject(SurveyService.shared)
                .environmentObject(themeManager)
                .environmentObject(gymService)
                .environmentObject(authService)
        }
    }
}

#Preview {
    SettingsView(onThemeChangeRequest: {})
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(UserProfileService.shared)
}
