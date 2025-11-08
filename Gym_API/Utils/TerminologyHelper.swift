//
//  TerminologyHelper.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import Foundation

// MARK: - Terminology Helper
/// Helper para obtener terminología adaptada al tipo de workspace
class TerminologyHelper {

    // MARK: - Default Terminology (Gym)
    static let defaultTerminology: [String: String] = [
        "gym": "gym",
        "member": "member",
        "members": "members",
        "trainer": "trainer",
        "trainers": "trainers",
        "class": "class",
        "classes": "classes",
        "schedule": "schedule",
        "membership": "membership",
        "event": "event",
        "events": "events"
    ]

    // MARK: - Get Term
    /// Obtiene un término traducido según el contexto del workspace
    /// - Parameters:
    ///   - key: Clave del término (ej: "members")
    ///   - terminology: Diccionario de terminología del workspace (opcional)
    /// - Returns: Término traducido o el default si no existe
    static func getTerm(_ key: String, from terminology: [String: String]?) -> String {
        guard let terminology = terminology else {
            return defaultTerminology[key] ?? key
        }
        return terminology[key] ?? defaultTerminology[key] ?? key
    }

    // MARK: - Capitalized Term
    /// Obtiene un término capitalizado
    static func getCapitalizedTerm(_ key: String, from terminology: [String: String]?) -> String {
        return getTerm(key, from: terminology).capitalized
    }

    // MARK: - Uppercased Term
    /// Obtiene un término en mayúsculas
    static func getUppercasedTerm(_ key: String, from terminology: [String: String]?) -> String {
        return getTerm(key, from: terminology).uppercased()
    }
}

// MARK: - String Extension for Terminology
extension String {
    /// Reemplaza términos genéricos con los específicos del workspace
    /// - Parameter terminology: Diccionario de terminología
    /// - Returns: String con términos reemplazados
    func withWorkspaceTerminology(_ terminology: [String: String]?) -> String {
        guard let terminology = terminology else { return self }

        var result = self
        for (key, value) in terminology {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
