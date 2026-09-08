//
//  TrainingRecentExercises.swift
//  Gym_API
//
//  «Recently used with Dana»: los ejercicios que este entrenador ha puesto últimamente a este
//  cliente (UX §6, S21).
//
//  Es el atajo que más tiempo ahorra de verdad —un entrenador escribe el mismo puñado de
//  movimientos semana tras semana para la misma persona— y **no existe en el backend**: el
//  contrato de §6.2 no tiene endpoint de «último uso por cliente». En vez de inventarse uno o de
//  quedarse sin la sección, se guarda en el dispositivo: es una preferencia de quien escribe, no
//  un dato del cliente, y perderla al cambiar de teléfono solo cuesta un scroll.
//
//  Qué NO se guarda aquí: nada del cliente. Solo su id y una lista de claves de ejercicio del
//  catálogo, que son públicas dentro del espacio.
//

import Foundation

@MainActor
enum TrainingRecentExercises {

    /// Cuántas claves se recuerdan por cliente. Más de seis y la sección deja de ser un atajo
    /// para convertirse en otra lista que hay que leer.
    static let limit = 6

    private static let storageKey = "training.recentExercises"

    /// Las claves usadas con un cliente, de la más reciente a la más antigua.
    static func keys(forClient clientId: Int) -> [String] {
        stored()[String(clientId)] ?? []
    }

    /// Registra que estas claves se acaban de prescribir a un cliente.
    ///
    /// Se llama al **guardar el día**, no al elegir en el catálogo: lo que interesa recordar es
    /// lo que quedó escrito, no lo que se probó y se borró antes de guardar.
    static func remember(_ keys: [String], forClient clientId: Int) {
        guard !keys.isEmpty else { return }
        var map = stored()
        let previous = map[String(clientId)] ?? []

        // Las nuevas primero, en el orden en que aparecen en el día, y sin repetir.
        var merged: [String] = []
        var seen = Set<String>()
        for key in keys + previous where !key.isEmpty && !seen.contains(key) {
            seen.insert(key)
            merged.append(key)
        }

        map[String(clientId)] = Array(merged.prefix(limit))
        save(map)
    }

    /// Se llama al cerrar sesión y al cambiar de espacio: la cartera de clientes es de la cuenta,
    /// no del dispositivo.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Privado

    private static func stored() -> [String: [String]] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [String]] ?? [:]
    }

    private static func save(_ map: [String: [String]]) {
        UserDefaults.standard.set(map, forKey: storageKey)
    }
}
