//
//  Environment.swift
//  Gym_API
//
//  Configuration management for different environments (development, staging, production)
//  Created as part of security optimization phase
//

import Foundation

enum AppEnvironment {
    case development
    case staging
    case production

    // MARK: - Current Environment Detection
    static var current: AppEnvironment {
        #if DEBUG
        // En debug, siempre desarrollo por defecto
        return .development
        #else
        // En release, leer desde Info.plist
        guard let config = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT") as? String else {
            // Si no está configurado, asumir producción por seguridad
            return .production
        }

        switch config.lowercased() {
        case "development", "dev":
            return .development
        case "staging", "stage":
            return .staging
        case "production", "prod":
            return .production
        default:
            // Por defecto a producción si no se reconoce
            return .production
        }
        #endif
    }

    // MARK: - Environment-specific URLs
    var baseURL: String {
        switch self {
        case .development:
            // URL de desarrollo local o servidor de desarrollo
            return "https://dev.gymapi-eh6m.onrender.com/api/v1"
        case .staging:
            // URL de staging para pruebas
            return "https://staging.gymapi-eh6m.onrender.com/api/v1"
        case .production:
            // URL de producción
            return "https://gymapi-eh6m.onrender.com/api/v1"
        }
    }

    var auth0Domain: String {
        switch self {
        case .development:
            // Dominio de Auth0 para desarrollo
            return "dev-gd5crfe6qbqlu23p.us.auth0.com"
        case .staging:
            // Mismo dominio para staging (por ahora)
            return "dev-gd5crfe6qbqlu23p.us.auth0.com"
        case .production:
            // TODO: Actualizar con dominio de producción cuando esté disponible
            return "dev-gd5crfe6qbqlu23p.us.auth0.com"
        }
    }

    var auth0ClientId: String {
        switch self {
        case .development:
            // ClientID de desarrollo
            return "OuJ6IKE0lJSdaMG6jaW04jfptsMRbyvp"
        case .staging:
            // ClientID de staging
            return "OuJ6IKE0lJSdaMG6jaW04jfptsMRbyvp"
        case .production:
            // ClientID de producción
            return "OuJ6IKE0lJSdaMG6jaW04jfptsMRbyvp"
        }
    }

    var auth0Audience: String {
        // Mismo audience para todos los ambientes por ahora
        return "https://gymapi"
    }

    // MARK: - Stream Chat Configuration
    var streamChatDomain: String {
        // Mismo dominio para todos los ambientes
        return "https://us-east-1.stream-io-api.com"
    }

    // MARK: - Feature Flags
    var isDebugLoggingEnabled: Bool {
        switch self {
        case .development:
            return true
        case .staging:
            return true
        case .production:
            return false
        }
    }

    var isCrashReportingEnabled: Bool {
        switch self {
        case .development:
            return false // No enviar crashes en desarrollo
        case .staging:
            return true
        case .production:
            return true
        }
    }

    var isAnalyticsEnabled: Bool {
        switch self {
        case .development:
            return false // No analytics en desarrollo
        case .staging:
            return true
        case .production:
            return true
        }
    }

    // MARK: - Timeouts
    var networkTimeout: TimeInterval {
        switch self {
        case .development:
            return 60.0 // Más tiempo en desarrollo para debugging
        case .staging:
            return 30.0
        case .production:
            return 15.0 // Timeout más estricto en producción
        }
    }

    // MARK: - Cache Configuration
    var cacheExpirationTime: TimeInterval {
        switch self {
        case .development:
            return 60 // 1 minuto en desarrollo para pruebas
        case .staging:
            return 300 // 5 minutos en staging
        case .production:
            return 600 // 10 minutos en producción
        }
    }

    // MARK: - Helpers
    var displayName: String {
        switch self {
        case .development:
            return "Desarrollo"
        case .staging:
            return "Staging"
        case .production:
            return "Producción"
        }
    }

    var isProduction: Bool {
        self == .production
    }

    var isDevelopment: Bool {
        self == .development
    }

    // MARK: - Configuration Validation
    static func validateConfiguration() {
        let env = current

        #if DEBUG
        print("🔧 Environment: \(env.displayName)")
        print("📍 Base URL: \(env.baseURL)")
        print("🔐 Auth0 Domain: \(env.auth0Domain)")
        print("📊 Analytics: \(env.isAnalyticsEnabled ? "Enabled" : "Disabled")")
        print("🐛 Debug Logging: \(env.isDebugLoggingEnabled ? "Enabled" : "Disabled")")
        #endif

        // Validar que las configuraciones críticas no estén vacías
        if env.baseURL.isEmpty {
            fatalError("❌ Base URL no configurada para ambiente \(env.displayName)")
        }

        if env.auth0Domain.isEmpty {
            fatalError("❌ Auth0 Domain no configurado para ambiente \(env.displayName)")
        }
    }
}

// MARK: - Global Helper
/// Acceso rápido al ambiente actual
var currentEnvironment: AppEnvironment {
    AppEnvironment.current
}

/// Acceso rápido a la base URL
var apiBaseURL: String {
    AppEnvironment.current.baseURL
}