import SwiftUI

// MARK: - Profile Options Sheet (simplified)
struct ProfileOptionsSheet: View {
    @Binding var isPresented: Bool
    let onEditProfile: () -> Void
    let onSettings: () -> Void
    let onGymSelector: () -> Void
    let onCustomizeColors: () -> Void
    let authService: AuthServiceDirect
    let gymService: GymService
    let themeManager: ThemeManager
    
    private var currentRole: String? {
        gymService.currentGym?.userRoleInGym
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Handle indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 6)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Options list
                VStack(spacing: 0) {
                    row(icon: "person.crop.circle", title: "Edit Profile") {
                        isPresented = false
                        onEditProfile()
                    }

                    row(icon: "paintpalette.fill", title: "Customize Colors") {
                        isPresented = false
                        onCustomizeColors()
                    }
                    
                    // Administrative options (only for staff)
                    if RolePermissions.canManageUsers(currentRole) {
                        row(icon: "person.2.fill", title: "Manage Members") {
                            isPresented = false
                            print("Manage Members tapped - Admin feature")
                        }
                    }
                    
                    if RolePermissions.canViewReports(currentRole) {
                        row(icon: "chart.bar.fill", title: "View Reports") {
                            isPresented = false
                            print("View Reports tapped - Staff feature")
                        }
                    }
                    
                    if RolePermissions.canManageGym(currentRole) {
                        row(icon: "building.2.badge.gearshape", title: "Gym Settings") {
                            isPresented = false
                            print("Gym Settings tapped - Owner feature")
                        }
                    }

                    row(icon: "gear", title: "Settings") {
                        isPresented = false
                        onSettings()
                    }

                    row(icon: "building.2", title: "Switch Gym") {
                        isPresented = false
                        onGymSelector()
                    }

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    // Sign out
                    Button(action: {
                        isPresented = false
                        Task { await authService.logout() }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)

                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileOptionsSheet(
        isPresented: .constant(true),
        onEditProfile: {},
        onSettings: {},
        onGymSelector: {},
        onCustomizeColors: {},
        authService: AuthServiceDirect(),
        gymService: GymService.shared,
        themeManager: ThemeManager()
    )
}

