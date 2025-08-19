//
//  RolePermissions.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import Foundation

/// Helper struct para validar permisos basados en el rol del usuario en el gimnasio
struct RolePermissions {
    
    // MARK: - Permission Checks
    
    /// Verifica si el usuario puede crear eventos
    /// Solo ADMIN y OWNER pueden crear eventos
    static func canCreateEvents(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede gestionar otros usuarios
    /// Solo ADMIN y OWNER pueden gestionar usuarios
    static func canManageUsers(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede configurar el gimnasio
    /// Solo OWNER puede gestionar configuración del gym
    static func canManageGym(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return role == "OWNER"
    }
    
    /// Verifica si el usuario tiene nivel de administrador
    /// ADMIN y OWNER tienen nivel administrativo
    static func isAdminLevel(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede ver reportes avanzados
    /// TRAINER, ADMIN y OWNER pueden ver reportes
    static func canViewReports(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN", "TRAINER"].contains(role)
    }
    
    /// Verifica si el usuario puede moderar chat/eventos
    /// TRAINER, ADMIN y OWNER pueden moderar
    static func canModerate(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN", "TRAINER"].contains(role)
    }
    
    /// Verifica si el usuario puede editar cualquier evento
    /// Solo ADMIN y OWNER pueden editar eventos de otros
    static func canEditAnyEvent(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede cancelar cualquier evento
    /// Solo ADMIN y OWNER pueden cancelar eventos de otros
    static func canCancelAnyEvent(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede editar un evento específico
    /// El creador del evento o ADMIN/OWNER pueden editar
    static func canEditEvent(_ role: String?, creatorId: Int?, currentUserId: String?) -> Bool {
        // Si es admin/owner, puede editar cualquier evento
        if canEditAnyEvent(role) {
            return true
        }
        
        // Si es el creador del evento, puede editarlo
        if let creatorId = creatorId,
           let currentUserId = currentUserId,
           let currentUserIdInt = Int(currentUserId) {
            return creatorId == currentUserIdInt
        }
        
        return false
    }
    
    /// Verifica si el usuario puede eliminar un evento específico  
    /// El creador del evento o ADMIN/OWNER pueden eliminar
    static func canDeleteEvent(_ role: String?, creatorId: Int?, currentUserId: String?) -> Bool {
        // Si es admin/owner, puede eliminar cualquier evento
        if canCancelAnyEvent(role) {
            return true
        }
        
        // Si es el creador del evento, puede eliminarlo
        if let creatorId = creatorId,
           let currentUserId = currentUserId,
           let currentUserIdInt = Int(currentUserId) {
            return creatorId == currentUserIdInt
        }
        
        return false
    }
    
    /// Verifica si el usuario puede crear clases (además de eventos)
    /// TRAINER, ADMIN y OWNER pueden crear clases
    static func canCreateClasses(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN", "TRAINER"].contains(role)
    }
    
    /// Verifica si el usuario puede gestionar horarios del gym
    /// Solo ADMIN y OWNER pueden gestionar horarios
    static func canManageSchedule(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede realizar registro masivo de usuarios en eventos
    /// Solo ADMIN y OWNER pueden realizar registro masivo
    static func canBulkRegisterUsers(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede crear sesiones de clases
    /// Solo ADMIN y OWNER pueden crear sesiones (mismos permisos que eventos)
    static func canCreateSessions(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    // MARK: - Role Utilities
    
    /// Obtiene el rol formateado para display
    static func roleDisplayName(_ role: String?) -> String {
        guard let role = role else { return "Member" }
        switch role.uppercased() {
        case "OWNER":
            return "Owner"
        case "ADMIN":
            return "Administrator"
        case "TRAINER":
            return "Trainer"
        case "MEMBER":
            return "Member"
        default:
            return role.capitalized
        }
    }
    
    /// Obtiene el icono apropiado para el rol
    static func roleIcon(_ role: String?) -> String {
        guard let role = role else { return "person.fill" }
        switch role.uppercased() {
        case "OWNER":
            return "crown.fill"
        case "ADMIN":
            return "person.badge.key.fill"
        case "TRAINER":
            return "figure.strengthtraining.traditional"
        case "MEMBER":
            return "person.fill"
        default:
            return "person.fill"
        }
    }
    
    /// Obtiene una lista de permisos para el rol (para debugging/UI)
    static func permissionsForRole(_ role: String?) -> [String] {
        var permissions: [String] = []
        
        if canCreateEvents(role) { permissions.append("Create Events") }
        if canCreateClasses(role) { permissions.append("Create Classes") }
        if canViewReports(role) { permissions.append("View Reports") }
        if canModerate(role) { permissions.append("Moderate") }
        if canManageUsers(role) { permissions.append("Manage Users") }
        if canManageSchedule(role) { permissions.append("Manage Schedule") }
        if canManageGym(role) { permissions.append("Manage Gym") }
        if canEditAnyEvent(role) { permissions.append("Edit Any Event") }
        if canCancelAnyEvent(role) { permissions.append("Cancel Any Event") }
        if canBulkRegisterUsers(role) { permissions.append("Bulk Register Users") }
        if canCreateSessions(role) { permissions.append("Create Sessions") }
        
        return permissions
    }
}

// MARK: - UserRole Enum for Type Safety
enum UserRole: String, CaseIterable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case trainer = "TRAINER"
    case member = "MEMBER"
    
    var displayName: String {
        return RolePermissions.roleDisplayName(self.rawValue)
    }
    
    var icon: String {
        return RolePermissions.roleIcon(self.rawValue)
    }
    
    var permissions: [String] {
        return RolePermissions.permissionsForRole(self.rawValue)
    }
    
    var canCreateEvents: Bool {
        return RolePermissions.canCreateEvents(self.rawValue)
    }
    
    var canManageUsers: Bool {
        return RolePermissions.canManageUsers(self.rawValue)
    }
    
    var isAdminLevel: Bool {
        return RolePermissions.isAdminLevel(self.rawValue)
    }
}