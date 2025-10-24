//
//  Auth0Config.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import Foundation

/// Loads Auth0 configuration from Auth0.plist at runtime for sensitive data.
/// Public configuration can be in Info.plist for easier environment management.
struct Auth0Config {
    private static let plistName = "Auth0"

    /// Domain from Auth0.plist or Info.plist (e.g., dev-xxxx.us.auth0.com)
    static var domain: String {
        // Primero intentar desde Info.plist (para configuración por ambiente)
        if let domainFromInfo = Bundle.main.object(forInfoDictionaryKey: "AUTH0_DOMAIN") as? String,
           !domainFromInfo.isEmpty {
            return domainFromInfo
        }
        // Fallback a Auth0.plist
        return value(forKey: "Domain") ?? ""
    }

    /// Client ID from Auth0.plist or Info.plist
    static var clientId: String {
        // Primero intentar desde Info.plist (para configuración por ambiente)
        if let clientIdFromInfo = Bundle.main.object(forInfoDictionaryKey: "AUTH0_CLIENT_ID") as? String,
           !clientIdFromInfo.isEmpty {
            return clientIdFromInfo
        }
        // Fallback a Auth0.plist
        // NOTA: El ClientID correcto según documentación es OuJ6IKE0lJSdaMG6jaW04jfptsMRbyvp
        return value(forKey: "ClientId") ?? "OuJ6IKE0lJSdaMG6jaW04jfptsMRbyvp"
    }

    /// API audience. Kept as a non-secret constant or can be moved to Info.plist.
    static var audience: String {
        // Primero intentar desde Info.plist
        if let audienceFromInfo = Bundle.main.object(forInfoDictionaryKey: "AUTH0_AUDIENCE") as? String,
           !audienceFromInfo.isEmpty {
            return audienceFromInfo
        }
        // If "Audience" is present in Auth0.plist, use it; else default.
        return value(forKey: "Audience") ?? "https://gymapi"
    }

    /// Issuer derived from domain
    static var issuer: String {
        guard !domain.isEmpty else { return "" }
        return "https://\(domain)/"
    }

    // Secrets such as clientSecret must NOT be stored on-device for Auth Code + PKCE flows.

    // MARK: - Private helpers
    private static func value(forKey key: String) -> String? {
        guard let path = Bundle.main.path(forResource: plistName, ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict[key] as? String
    }
}
