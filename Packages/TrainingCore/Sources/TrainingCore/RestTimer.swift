//
//  RestTimer.swift
//  TrainingCore
//
//  Cronómetro de descanso (UX §8).
//
//  Se representa con una FECHA DE FIN ABSOLUTA, no con un contador que decrementa. Es la
//  diferencia entre volver de segundo plano y ver el tiempo correcto o ver una mentira: un
//  contador que solo baja mientras la app está en primer plano se queda congelado y luego
//  «reanuda» un descanso que en realidad terminó hace cuatro minutos.
//

import Foundation

// MARK: - Cronómetro

public struct RestTimer: Hashable, Sendable {

    /// Descanso por defecto cuando el ejercicio no prescribe ninguno (UX §8).
    public static let defaultSeconds = 90
    /// Lo que añade el botón `+30s`.
    public static let extensionSeconds: TimeInterval = 30
    /// Últimos segundos en los que la cifra cambia de color.
    public static let finalCountdownSeconds: TimeInterval = 10

    public let exerciseName: String
    public let setNumber: Int
    public let totalSets: Int
    public let startedAt: Date
    /// Único estado que se guarda: cuándo termina. Todo lo demás se deriva de «ahora».
    public private(set) var endsAt: Date
    /// Cuántos `+30s` se han pulsado, para la analítica y para la hoja del cronómetro.
    public private(set) var extensionCount: Int

    public init(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        seconds: Int,
        startedAt: Date
    ) {
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.totalSets = totalSets
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(TimeInterval(max(0, seconds)))
        self.extensionCount = 0
    }

    // MARK: - Estado

    public enum Phase: Hashable, Sendable {
        /// Quedan `remaining` segundos.
        case running(remaining: TimeInterval)
        /// Terminó hace `ago` segundos.
        case done(ago: TimeInterval)
    }

    public var plannedDuration: TimeInterval { endsAt.timeIntervalSince(startedAt) }

    public func phase(at now: Date) -> Phase {
        let remaining = endsAt.timeIntervalSince(now)
        // Se compara con `< 1` y no con `<= 0` para que el último segundo no se lea «0:00»
        // durante un segundo entero antes de cambiar a «Rest done».
        return remaining < 1 ? .done(ago: -remaining) : .running(remaining: remaining)
    }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(now))
    }

    public func isFinished(at now: Date) -> Bool {
        if case .done = phase(at: now) { return true }
        return false
    }

    /// De 1 (recién empezado) a 0 (terminado). La barra se vacía de izquierda a derecha.
    public func progress(at now: Date) -> Double {
        let total = plannedDuration
        guard total > 0 else { return 0 }
        return min(1, max(0, endsAt.timeIntervalSince(now) / total))
    }

    /// Últimos diez segundos: la cifra pasa de tinta a acento, sin sonido ni parpadeo.
    public func isInFinalCountdown(at now: Date) -> Bool {
        let remaining = endsAt.timeIntervalSince(now)
        return remaining > 0 && remaining <= Self.finalCountdownSeconds
    }

    // MARK: - Acciones

    /// `+30s`. Extiende sobre la fecha de fin, no sobre «ahora»: pulsarlo dos veces seguidas
    /// tiene que sumar un minuto, no reiniciar el descanso.
    public mutating func extend(by seconds: TimeInterval = RestTimer.extensionSeconds) {
        endsAt = endsAt.addingTimeInterval(seconds)
        extensionCount += 1
    }

    // MARK: - Textos (inglés, literales de la UX)

    /// «Rest 1:24» mientras corre, «Rest done · 0:42 ago» cuando terminó.
    public func label(at now: Date) -> String {
        switch phase(at: now) {
        case .running(let remaining):
            return "Rest \(Self.clock(remaining))"
        case .done(let ago):
            return ago < 1 ? "Rest done" : "Rest done · \(Self.clock(ago)) ago"
        }
    }

    /// Cuerpo de la notificación local: «Bench press · set 4 of 4».
    public var notificationBody: String {
        "\(exerciseName) · set \(setNumber) of \(totalSets)"
    }

    public static let notificationTitle = "Rest done"

    /// Valor de accesibilidad de la barra. Se actualiza cada 15 s, no cada segundo, para no
    /// saturar VoiceOver (UX §8).
    public func accessibilityValue(at now: Date) -> String {
        switch phase(at: now) {
        case .running(let remaining):
            let seconds = Int(remaining.rounded())
            let minutes = seconds / 60
            let rest = seconds % 60
            if minutes > 0 && rest > 0 { return "\(minutes) minutes \(rest) seconds remaining" }
            if minutes > 0 { return "\(minutes) minutes remaining" }
            return "\(rest) seconds remaining"
        case .done:
            return "Rest done"
        }
    }

    /// «1:24» / «0:42». Redondea hacia arriba mientras corre para no enseñar 0:00 con tiempo vivo.
    public static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Controlador

/// Envoltorio del cronómetro con las tres acciones de la barra: arrancar, `Skip` y `+30s`.
///
/// Es un valor: quien lo posee (el modelo de la pantalla en WP4) lo guarda en `@Published` y
/// refresca la vista con un ticker; el cálculo del tiempo nunca depende de que ese ticker corra.
public struct RestTimerController: Hashable, Sendable {

    public private(set) var timer: RestTimer?
    /// Cuántas veces se ha saltado el descanso en esta sesión (evento `rest_timer_skipped`).
    public private(set) var skipCount: Int

    public init(timer: RestTimer? = nil) {
        self.timer = timer
        self.skipCount = 0
    }

    public var isActive: Bool { timer != nil }

    public func isRunning(at now: Date) -> Bool {
        guard let timer else { return false }
        return !timer.isFinished(at: now)
    }

    /// Arranca un descanso nuevo. Sustituye al anterior sin contarlo como saltado: marcar la
    /// serie siguiente cancela el descanso de la anterior por definición.
    public mutating func start(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        seconds: Int,
        at now: Date
    ) {
        timer = RestTimer(
            exerciseName: exerciseName,
            setNumber: setNumber,
            totalSets: totalSets,
            seconds: seconds,
            startedAt: now
        )
    }

    /// `Skip`. Cuenta como salto solo si el descanso todavía corría.
    @discardableResult
    public mutating func skip(at now: Date) -> Bool {
        guard let timer else { return false }
        let wasRunning = !timer.isFinished(at: now)
        self.timer = nil
        if wasRunning { skipCount += 1 }
        return wasRunning
    }

    /// Cancela sin contarlo como salto (deshacer una serie, cerrar la sesión).
    public mutating func cancel() {
        timer = nil
    }

    /// `+30s`.
    @discardableResult
    public mutating func addThirtySeconds() -> Bool {
        guard var timer else { return false }
        timer.extend()
        self.timer = timer
        return true
    }

    public func label(at now: Date) -> String? {
        timer?.label(at: now)
    }
}
