//
//  TrainingRoute.swift
//  Gym_API
//
//  Destinos de navegación del módulo dentro de la pila de la home del cliente (UX §2).
//
//  Son valores, no vistas: eso es lo que permite que un push llegue desde una tarjeta, desde un
//  deep link de notificación o desde la galería de revisión sin que ninguna de las tres conozca
//  a la siguiente pantalla.
//

import Foundation

enum TrainingRoute: Hashable {
    /// S12 · Weekly program. `week` nulo abre la semana en curso.
    case weeklyProgram(week: Int?)
    /// S17 · Day detail.
    case day(id: Int)
    /// S15 · Exercise history.
    case exerciseHistory(key: String, name: String)
    /// S16 · Records.
    case records
}

/// Presentaciones a pantalla completa: S11 y S18 (UX §2, regla de retorno).
enum TrainingCover: Identifiable, Hashable {
    /// S11 con el día de hoy (o el día indicado); `nil` es entreno libre.
    case sessionLog(dayId: Int?)
    /// S18 en modo lectura de un registro ya cerrado.
    case sessionSummary(logId: Int)

    var id: String {
        switch self {
        case .sessionLog(let dayId): return "log-\(dayId.map(String.init) ?? "free")"
        case .sessionSummary(let logId): return "summary-\(logId)"
        }
    }
}

extension Notification.Name {
    /// Deep link de push `training/logs/{id}`: el id viaja como `object`.
    static let trainingOpenLog = Notification.Name("training.openLog")
    /// La notificación local del descanso trae la acción «Add 30s».
    static let trainingRestAddThirty = Notification.Name("training.restAddThirty")
}
