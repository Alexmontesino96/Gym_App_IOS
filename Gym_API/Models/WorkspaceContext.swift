//
//  WorkspaceContext.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import Foundation

// MARK: - Workspace Context
/// Modelo principal que contiene toda la configuración del workspace
struct WorkspaceContext: Codable {
    let workspace: WorkspaceInfo
    let terminology: [String: String]
    let features: WorkspaceFeatures
    let navigation: [NavigationItem]
    let quickActions: [QuickAction]
    let branding: BrandingConfig
    let userContext: UserContextInfo
    let apiVersion: String
    let environment: String

    enum CodingKeys: String, CodingKey {
        case workspace, terminology, features, navigation, branding, environment
        case quickActions = "quick_actions"
        case userContext = "user_context"
        case apiVersion = "api_version"
    }
}

// MARK: - Workspace Info
/// Información del workspace actual
struct WorkspaceInfo: Codable {
    let id: Int
    let name: String
    let type: String
    let isPersonalTrainer: Bool
    let displayName: String
    let entityLabel: String
    let timezone: String
    let email: String
    let phone: String?
    let address: String?
    let maxClients: Int?
    let specialties: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, type, timezone, email, phone, address
        case isPersonalTrainer = "is_personal_trainer"
        case displayName = "display_name"
        case entityLabel = "entity_label"
        case maxClients = "max_clients"
        case specialties
    }
}

// MARK: - Workspace Features
/// Features disponibles según el tipo de workspace
struct WorkspaceFeatures: Codable {
    let chat: Bool
    let notifications: Bool
    let healthTracking: Bool
    let nutrition: Bool
    let showMultipleTrainers: Bool
    let showEquipmentManagement: Bool
    let showClassSchedule: Bool
    let showAppointments: Bool
    let showClientProgress: Bool
    let showSessionPackages: Bool
    let simplifiedBilling: Bool
    let maxClientsLimit: Bool
    let personalBranding: Bool

    enum CodingKeys: String, CodingKey {
        case chat, notifications, nutrition
        case healthTracking = "health_tracking"
        case showMultipleTrainers = "show_multiple_trainers"
        case showEquipmentManagement = "show_equipment_management"
        case showClassSchedule = "show_class_schedule"
        case showAppointments = "show_appointments"
        case showClientProgress = "show_client_progress"
        case showSessionPackages = "show_session_packages"
        case simplifiedBilling = "simplified_billing"
        case maxClientsLimit = "max_clients_limit"
        case personalBranding = "personal_branding"
    }
}

// MARK: - Navigation Item
/// Item de navegación para construir menús dinámicos
struct NavigationItem: Codable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let path: String
}

// MARK: - Quick Action
/// Acción rápida para dashboard
struct QuickAction: Codable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let color: String
    let action: String
}

// MARK: - Branding Config
/// Configuración de branding personalizado
struct BrandingConfig: Codable {
    let logoUrl: String?
    let primaryColor: String
    let secondaryColor: String
    let accentColor: String
    let appTitle: String
    let appSubtitle: String
    let theme: String
    let showLogo: Bool
    let compactMode: Bool

    enum CodingKeys: String, CodingKey {
        case theme
        case logoUrl = "logo_url"
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case accentColor = "accent_color"
        case appTitle = "app_title"
        case appSubtitle = "app_subtitle"
        case showLogo = "show_logo"
        case compactMode = "compact_mode"
    }
}

// MARK: - User Context Info
/// Información del usuario en el contexto del workspace
struct UserContextInfo: Codable {
    let id: Int
    let email: String
    let name: String
    let photoUrl: String?
    let role: String
    let roleLabel: String
    let permissions: [String]

    enum CodingKeys: String, CodingKey {
        case id, email, name, role, permissions
        case photoUrl = "photo_url"
        case roleLabel = "role_label"
    }
}
