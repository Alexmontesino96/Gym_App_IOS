import SwiftUI
import Combine

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var profileService: UserProfileService
    @ObservedObject private var membershipService = MembershipService.shared
    @StateObject private var oneSignalService = OneSignalService.shared
    @Environment(\.dismiss) private var dismiss
    
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
                            // Membership Section
                            MembershipSection(
                                membershipService: membershipService,
                                themeManager: themeManager
                            )
                            
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
            // Configurar AuthService en MembershipService
            membershipService.authService = authService
            
            // Dar un pequeño delay para asegurar que authService esté completamente listo
            Task {
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
                
                Text(profile.email)
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

// MARK: - Theme Section
struct ThemeSection: View {
    let themeManager: ThemeManager
    let onThemeChange: () -> Void
    
    var body: some View {
        SettingsCard(title: "Appearance", themeManager: themeManager) {
            VStack(spacing: 12) {
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
            }
        }
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
#Preview {
    SettingsView(onThemeChangeRequest: {})
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(UserProfileService.shared)
}