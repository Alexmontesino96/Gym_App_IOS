//
//  Auth0Config.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import Foundation

/// Loads Auth0 configuration from Auth0.plist at runtime.
/// Do not hardcode secrets in source code.
struct Auth0Config {
    private static let plistName = "Auth0"

    /// Domain from Auth0.plist (e.g., dev-xxxx.us.auth0.com)
    static var domain: String {
        value(forKey: "Domain") ?? ""
    }

    /// Client ID from Auth0.plist
    static var clientId: String {
        value(forKey: "ClientId") ?? ""
    }

    /// API audience. Kept as a non-secret constant or can be moved to Info.plist.
    static var audience: String {
        // If "Audience" is present in Auth0.plist, use it; else default.
        value(forKey: "Audience") ?? "https://gymapi"
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
