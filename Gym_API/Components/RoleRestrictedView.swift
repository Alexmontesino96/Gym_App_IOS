//
//  RoleRestrictedView.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import SwiftUI

// MARK: - Role Restricted ViewModifier
struct RoleRestricted: ViewModifier {
    let requiredPermission: (String?) -> Bool
    let currentRole: String?
    let fallback: AnyView?
    
    init(requiredPermission: @escaping (String?) -> Bool, currentRole: String?, fallback: AnyView? = nil) {
        self.requiredPermission = requiredPermission
        self.currentRole = currentRole
        self.fallback = fallback
    }
    
    func body(content: Content) -> some View {
        if requiredPermission(currentRole) {
            content
        } else if let fallback = fallback {
            fallback
        }
    }
}

// MARK: - View Extension for Convenience
extension View {
    /// Restringe la vista a usuarios con un permiso específico
    func roleRestricted(
        _ permission: @escaping (String?) -> Bool,
        currentRole: String?,
        fallback: AnyView? = nil
    ) -> some View {
        self.modifier(RoleRestricted(
            requiredPermission: permission,
            currentRole: currentRole,
            fallback: fallback
        ))
    }
    
    /// Restringe la vista solo a administradores (ADMIN/OWNER)
    func adminOnly(currentRole: String?, fallback: AnyView? = nil) -> some View {
        self.roleRestricted(
            RolePermissions.isAdminLevel,
            currentRole: currentRole,
            fallback: fallback
        )
    }
    
    /// Restringe la vista solo a creadores de contenido (TRAINER/ADMIN/OWNER)
    func creatorsOnly(currentRole: String?, fallback: AnyView? = nil) -> some View {
        self.roleRestricted(
            RolePermissions.canCreateEvents,
            currentRole: currentRole,
            fallback: fallback
        )
    }
    
    /// Restringe la vista solo a owners
    func ownerOnly(currentRole: String?, fallback: AnyView? = nil) -> some View {
        self.roleRestricted(
            RolePermissions.canManageGym,
            currentRole: currentRole,
            fallback: fallback
        )
    }
    
    /// Restringe la vista a usuarios con permisos de gestión (no members)
    func staffOnly(currentRole: String?, fallback: AnyView? = nil) -> some View {
        self.roleRestricted(
            RolePermissions.canModerate,
            currentRole: currentRole,
            fallback: fallback
        )
    }
}

// MARK: - Role-Based Container Views
struct RoleRestrictedContainer<Content: View>: View {
    let content: Content
    let requiredPermission: (String?) -> Bool
    let currentRole: String?
    let emptyStateView: AnyView?
    
    init(
        requiredPermission: @escaping (String?) -> Bool,
        currentRole: String?,
        emptyStateView: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.requiredPermission = requiredPermission
        self.currentRole = currentRole
        self.emptyStateView = emptyStateView
    }
    
    var body: some View {
        if requiredPermission(currentRole) {
            content
        } else if let emptyStateView = emptyStateView {
            emptyStateView
        } else {
            EmptyView()
        }
    }
}

// MARK: - Admin Panel Container
struct AdminPanelContainer<Content: View>: View {
    let content: Content
    let currentRole: String?
    let themeManager: ThemeManager
    
    init(
        currentRole: String?,
        themeManager: ThemeManager,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.currentRole = currentRole
        self.themeManager = themeManager
    }
    
    var body: some View {
        RoleRestrictedContainer(
            requiredPermission: RolePermissions.isAdminLevel,
            currentRole: currentRole,
            emptyStateView: AnyView(
                adminEmptyState
            )
        ) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("Administration")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                }
                
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private var adminEmptyState: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            Text("Administrative privileges required")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
        )
    }
}

// MARK: - Staff Tools Container
struct StaffToolsContainer<Content: View>: View {
    let content: Content
    let currentRole: String?
    let themeManager: ThemeManager
    let title: String
    let icon: String
    
    init(
        currentRole: String?,
        themeManager: ThemeManager,
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.currentRole = currentRole
        self.themeManager = themeManager
        self.title = title
        self.icon = icon
    }
    
    var body: some View {
        RoleRestrictedContainer(
            requiredPermission: RolePermissions.canModerate,
            currentRole: currentRole
        ) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                }
                
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
    }
}

// MARK: - Preview Support
#Preview {
    VStack(spacing: 20) {
        // Admin only content
        Text("Admin Only Button")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .adminOnly(currentRole: "ADMIN")
        
        // Creator only content
        Text("Creator Only Button")
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .creatorsOnly(currentRole: "TRAINER")
        
        // Admin panel container
        AdminPanelContainer(
            currentRole: "ADMIN",
            themeManager: ThemeManager()
        ) {
            VStack {
                Text("Admin Option 1")
                Text("Admin Option 2")
            }
        }
    }
    .padding()
    .environmentObject(ThemeManager())
}