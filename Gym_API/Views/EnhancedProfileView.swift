//
//  EnhancedProfileView.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Vista de perfil rediseñada con estado de membresía

import SwiftUI

struct EnhancedProfileView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var oneSignalService: OneSignalService
    @StateObject private var membershipService = MembershipService.shared
    @State private var refreshID = UUID()
    let onThemeChangeRequest: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header con información del usuario
                        UserHeaderView(themeManager: themeManager)
                        
                        // Tarjeta de membresía
                        MembershipCardView(
                            membershipService: membershipService,
                            themeManager: themeManager
                        )
                        
                        // Opciones de perfil
                        ProfileOptionsSection(
                            themeManager: themeManager,
                            onThemeChangeRequest: onThemeChangeRequest
                        )
                        
                        // Sección de notificaciones
                        NotificationsSection(
                            oneSignalService: oneSignalService,
                            themeManager: themeManager,
                            refreshID: $refreshID
                        )
                        
                        // Botón de logout
                        LogoutButton(
                            authService: authService,
                            themeManager: themeManager
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .refreshable {
                    await membershipService.refreshMembershipStatus()
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.3), value: themeManager.currentTheme)
        }
        .onAppear {
            // Configurar AuthService en MembershipService
            membershipService.authService = authService
            
            // Cargar estado de membresía
            Task {
                await membershipService.getMyMembershipStatus()
            }
        }
    }
}

// MARK: - User Header View
struct UserHeaderView: View {
    let themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar con gradiente
            ZStack {
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
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 45))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Información del usuario
            if let user = authService.user {
                VStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(user.email)
                        .font(.system(size: 15))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Membership Card View
struct MembershipCardView: View {
    @ObservedObject var membershipService: MembershipService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            if membershipService.isLoading {
                // Loading state
                MembershipLoadingView(themeManager: themeManager)
            } else if let membership = membershipService.membershipStatus {
                // Membership content
                MembershipContentView(
                    membership: membership,
                    themeManager: themeManager
                )
            } else {
                // Error or no data state
                MembershipErrorView(
                    errorMessage: membershipService.errorMessage,
                    themeManager: themeManager,
                    onRetry: {
                        Task {
                            await membershipService.refreshMembershipStatus()
                        }
                    }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Membership Content View
struct MembershipContentView: View {
    let membership: MembershipStatus
    let themeManager: ThemeManager
    
    var membershipColor: Color {
        switch membership.membershipType.lowercased() {
        case "premium":
            return .orange
        case "standard":
            return .blue
        case "free":
            return .gray
        default:
            return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header de la tarjeta
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Membership")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text(membership.membershipDisplayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(membership.isActive ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(membership.isActive ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(membership.isActive ? .green : .red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Membresía details
            VStack(spacing: 16) {
                // Gym info
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(membershipColor)
                        .frame(width: 20)
                    
                    Text(membership.gymName)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                }
                
                // Expiration info
                if let daysRemaining = membership.daysRemaining {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(membershipColor)
                            .frame(width: 20)
                        
                        Text(membership.expirationText)
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        if daysRemaining <= 7 && daysRemaining > 0 {
                            Text("¡Renovar pronto!")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "infinity")
                            .foregroundColor(membershipColor)
                            .frame(width: 20)
                        
                        Text("Sin vencimiento")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                    }
                }
                
                // Access status
                HStack {
                    Image(systemName: membership.canAccess ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundColor(membership.canAccess ? .green : .red)
                        .frame(width: 20)
                    
                    Text(membership.canAccess ? "Acceso completo" : "Acceso restringido")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Footer con gradiente del tipo de membresía
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [membershipColor.opacity(0.8), membershipColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Membership Loading View
struct MembershipLoadingView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)
            
            Text("Loading membership...")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Membership Error View
struct MembershipErrorView: View {
    let errorMessage: String?
    let themeManager: ThemeManager
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            
            Text("Error loading membership")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry", action: onRetry)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Option Row Component
struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile Options Section
struct ProfileOptionsSection: View {
    let themeManager: ThemeManager
    let onThemeChangeRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ProfileOptionRow(
                icon: "moon.circle.fill",
                title: "Tema",
                subtitle: themeManager.currentTheme == .dark ? "Oscuro" : "Claro",
                themeManager: themeManager,
                action: onThemeChangeRequest
            )
            
            ProfileOptionRow(
                icon: "bell.circle.fill",
                title: "Notificaciones",
                subtitle: "Configurar alertas",
                themeManager: themeManager,
                action: {
                    // TODO: Implementar configuración de notificaciones
                }
            )
            
            ProfileOptionRow(
                icon: "questionmark.circle.fill",
                title: "Ayuda",
                subtitle: "Soporte y FAQ",
                themeManager: themeManager,
                action: {
                    // TODO: Implementar ayuda
                }
            )
        }
    }
}

// MARK: - Notifications Section
struct NotificationsSection: View {
    @ObservedObject var oneSignalService: OneSignalService
    let themeManager: ThemeManager
    @Binding var refreshID: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .font(.system(size: 18))
                Text("Push Notifications")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            
            // Estado de suscripción
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(oneSignalService.isSubscribed() ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(oneSignalService.isSubscribed() ? "Activado" : "Desactivado")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                // Botón de re-suscripción si no está suscrito
                if !oneSignalService.isSubscribed() {
                    Button(action: {
                        oneSignalService.manuallyOptIn()
                        // Forzar actualización de la vista
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            refreshID = UUID()
                        }
                    }) {
                        Text("Activar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            // Player ID
            if let playerId = oneSignalService.getPlayerId() {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Player ID:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Text(playerId.prefix(16) + "...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .id(refreshID)
    }
}

// MARK: - Logout Button
struct LogoutButton: View {
    @ObservedObject var authService: AuthServiceDirect
    let themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            Task {
                await authService.logout()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                Text("Log Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    EnhancedProfileView(onThemeChangeRequest: {})
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
        .environmentObject(OneSignalService.shared)
}