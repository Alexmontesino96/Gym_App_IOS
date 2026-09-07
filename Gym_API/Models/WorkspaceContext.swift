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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        // isPersonalTrainer es opcional - default false si no viene
        isPersonalTrainer = try container.decodeIfPresent(Bool.self, forKey: .isPersonalTrainer) ?? false
        // Tolerantes a propósito: el contexto decide qué raíz monta la app, así que un campo
        // secundario ausente o nulo no puede tumbar la decodificación entera y dejar al usuario
        // en la pantalla equivocada. `type` e `is_personal_trainer` sí siguen siendo obligatorios.
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? name
        entityLabel = try container.decodeIfPresent(String.self, forKey: .entityLabel) ?? ""
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? TimeZone.current.identifier
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        maxClients = try container.decodeIfPresent(Int.self, forKey: .maxClients)
        specialties = try container.decodeIfPresent([String].self, forKey: .specialties)
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
    /// Módulo de entrenamiento (plan §5). Falla cerrado: si el backend todavía no manda la clave,
    /// o el espacio no lo tiene activo, la app no enseña nada del módulo. Se lee con
    /// `workspaceContext.isFeatureEnabled(\.training)`.
    let training: Bool

    enum CodingKeys: String, CodingKey {
        case chat, notifications, nutrition, training
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chat = try container.decode(Bool.self, forKey: .chat)
        notifications = try container.decode(Bool.self, forKey: .notifications)
        healthTracking = try container.decode(Bool.self, forKey: .healthTracking)
        nutrition = try container.decode(Bool.self, forKey: .nutrition)
        showMultipleTrainers = try container.decode(Bool.self, forKey: .showMultipleTrainers)
        showEquipmentManagement = try container.decode(Bool.self, forKey: .showEquipmentManagement)
        showClassSchedule = try container.decode(Bool.self, forKey: .showClassSchedule)
        showAppointments = try container.decode(Bool.self, forKey: .showAppointments)
        showClientProgress = try container.decode(Bool.self, forKey: .showClientProgress)
        showSessionPackages = try container.decode(Bool.self, forKey: .showSessionPackages)
        simplifiedBilling = try container.decode(Bool.self, forKey: .simplifiedBilling)
        maxClientsLimit = try container.decode(Bool.self, forKey: .maxClientsLimit)
        personalBranding = try container.decode(Bool.self, forKey: .personalBranding)
        // La única tolerante: el backend del módulo llega después que esta app, y la caché de
        // contexto que ya está en el disco de la gente no tiene la clave. Ausente = apagado.
        training = try container.decodeIfPresent(Bool.self, forKey: .training) ?? false
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
