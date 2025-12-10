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
    
    /// Verifica si el usuario puede editar cualquier sesión de clase
    /// Solo ADMIN y OWNER pueden editar sesiones de otros
    static func canEditAnySessions(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede eliminar cualquier sesión de clase
    /// Solo ADMIN y OWNER pueden eliminar sesiones de otros
    static func canDeleteAnySessions(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede editar una sesión específica
    /// El creador de la sesión o ADMIN/OWNER pueden editar
    static func canEditSession(_ role: String?, creatorId: Int?, currentUserId: String?) -> Bool {
        // Si es admin/owner, puede editar cualquier sesión
        if canEditAnySessions(role) {
            return true
        }
        
        // Si es el creador de la sesión, puede editarla
        if let creatorId = creatorId,
           let currentUserId = currentUserId,
           let currentUserIdInt = Int(currentUserId) {
            return creatorId == currentUserIdInt
        }
        
        return false
    }
    
    /// Verifica si el usuario puede eliminar una sesión específica
    /// El creador de la sesión o ADMIN/OWNER pueden eliminar
    static func canDeleteSession(_ role: String?, creatorId: Int?, currentUserId: String?) -> Bool {
        // Si es admin/owner, puede eliminar cualquier sesión
        if canDeleteAnySessions(role) {
            return true
        }
        
        // Si es el creador de la sesión, puede eliminarla
        if let creatorId = creatorId,
           let currentUserId = currentUserId,
           let currentUserIdInt = Int(currentUserId) {
            return creatorId == currentUserIdInt
        }
        
        return false
    }
    
    // MARK: - Survey Management Permissions
    
    /// Verifica si el usuario puede gestionar encuestas
    /// OWNER y ADMIN pueden crear y gestionar todas las encuestas
    /// TRAINER puede crear y ver estadísticas de sus propias encuestas
    static func canManageSurveys(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN", "TRAINER"].contains(role)
    }
    
    /// Verifica si el usuario puede ver todas las respuestas de encuestas
    /// Solo OWNER y ADMIN pueden ver respuestas individuales
    static func canViewAllSurveyResponses(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede exportar datos de encuestas
    /// Solo OWNER y ADMIN pueden exportar datos
    static func canExportSurveyData(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }
    
    /// Verifica si el usuario puede eliminar encuestas
    /// Solo OWNER y ADMIN pueden eliminar encuestas
    static func canDeleteSurveys(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN"].contains(role)
    }

    // MARK: - Attendance/Check-in Permissions

    /// Verifica si un usuario puede escanear QR para realizar check-in de asistencia
    /// TRAINER, ADMIN y OWNER pueden realizar check-in con QR
    static func canScanQRCheckIn(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN", "TRAINER"].contains(role)
    }

    // MARK: - Chat/Messaging Permissions

    /// Verifica si un usuario puede iniciar chat con cualquier miembro del gym
    /// TRAINER, ADMIN y OWNER pueden chatear con cualquier usuario
    /// MEMBER solo puede chatear con coaches
    static func canMessageAnyUser(_ role: String?) -> Bool {
        guard let role = role?.uppercased() else { return false }
        return ["OWNER", "ADMIN", "TRAINER"].contains(role)
    }

    /// Verifica si un usuario puede escanear QR basado en su perfil completo
    /// Verifica tanto el role como el gymRole
    /// - Parameter profile: Perfil del usuario
    /// - Returns: true si el usuario está autorizado (verifica role o gymRole)
    static func canScanQRCheckIn(profile: UserProfile?) -> Bool {
        guard let profile = profile else { return false }

        // Verificar tanto el role como el gymRole
        let hasRolePermission = canScanQRCheckIn(profile.role)
        let hasGymRolePermission = canScanQRCheckIn(profile.gymRole)

        return hasRolePermission || hasGymRolePermission
    }

    /// Obtiene el nombre del rol autorizado para mostrar en la UI del scanner
    /// - Parameter profile: Perfil del usuario
    /// - Returns: Nombre del rol autorizado o nil
    static func getAuthorizedRoleDisplayName(profile: UserProfile?) -> String? {
        guard let profile = profile else { return nil }

        if canScanQRCheckIn(profile.role) {
            return profile.displayRole
        } else if canScanQRCheckIn(profile.gymRole) {
            return profile.displayGymRole
        }

        return nil
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
            return "figure.walk"
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
        if canManageSurveys(role) { permissions.append("Manage Surveys") }
        if canExportSurveyData(role) { permissions.append("Export Survey Data") }
        if canManageSchedule(role) { permissions.append("Manage Schedule") }
        if canManageGym(role) { permissions.append("Manage Gym") }
        if canEditAnyEvent(role) { permissions.append("Edit Any Event") }
        if canCancelAnyEvent(role) { permissions.append("Cancel Any Event") }
        if canBulkRegisterUsers(role) { permissions.append("Bulk Register Users") }
        if canCreateSessions(role) { permissions.append("Create Sessions") }
        if canEditAnySessions(role) { permissions.append("Edit Any Session") }
        if canDeleteAnySessions(role) { permissions.append("Delete Any Session") }
        
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