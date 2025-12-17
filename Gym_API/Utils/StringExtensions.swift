//
//  StringExtensions.swift
//  Gym_API
//
//  Extensiones de String para manejo consistente de IDs de usuario
//

import Foundation

extension String {
    /// Extrae el ID numérico de un user ID en cualquier formato
    /// - Returns: ID numérico como String
    ///
    /// Soporta múltiples formatos:
    /// - `gym_4_user_10` → `"10"`
    /// - `user_10` → `"10"`
    /// - `10` → `"10"`
    func extractNumericUserId() -> String {
        // Patrón: gym_X_user_Y → extraer Y
        if let range = self.range(of: #"gym_\d+_user_(\d+)"#, options: .regularExpression) {
            let match = self[range]
            if let userIdRange = match.range(of: #"\d+$"#, options: .regularExpression) {
                return String(match[userIdRange])
            }
        }

        // Patrón: user_Y → extraer Y
        if let range = self.range(of: #"user_(\d+)"#, options: .regularExpression) {
            let match = self[range]
            if let userIdRange = match.range(of: #"\d+$"#, options: .regularExpression) {
                return String(match[userIdRange])
            }
        }

        // Si ya es un número o formato desconocido, devolver tal cual
        return self
    }

    /// Genera un cache key consistente para avatares de usuario
    /// - Returns: Cache key en formato `avatar_user_X` donde X es el ID numérico
    ///
    /// Ejemplos:
    /// - `gym_4_user_10`.userAvatarCacheKey() → `"avatar_user_10"`
    /// - `user_10`.userAvatarCacheKey() → `"avatar_user_10"`
    /// - `10`.userAvatarCacheKey() → `"avatar_user_10"`
    func userAvatarCacheKey() -> String {
        return "avatar_user_\(self.extractNumericUserId())"
    }

    /// Genera un cache key para avatares generados con UI Avatars
    /// - Returns: Cache key en formato `uiavatar_X` donde X es el ID numérico
    func uiAvatarCacheKey() -> String {
        return "uiavatar_\(self.extractNumericUserId())"
    }
}
