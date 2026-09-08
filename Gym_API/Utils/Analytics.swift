//
//  Analytics.swift
//  Gym_API
//
//  Fachada de analítica de producto (plan §7.4).
//
//  Todavía no hay proveedor. Esto escribe en `Logger` con su propia categoría y expone la
//  superficie que tendrá el día que se conecte uno (Amplitude, PostHog, lo que sea): las
//  llamadas de las vistas no cambian, solo cambia `send(_:_:)`.
//
//  Dos decisiones que conviene no perder:
//
//  1. **Los nombres de evento son constantes, no cadenas sueltas.** Un evento mal escrito no se
//     nota hasta que alguien busca un embudo que no existe.
//  2. **Aquí no entra nada personal.** Ni correos, ni nombres, ni notas del coach, ni el
//     contenido de un mensaje. Identificadores y cifras agregadas, nada más.
//

import Foundation

enum Analytics {

    // MARK: - Eventos (plan §7.4)

    enum Event {
        static let programAssigned = "program_assigned"
        static let sessionStarted = "session_started"
        static let setLogged = "set_logged"
        static let sessionCompleted = "session_completed"
        static let sessionPartial = "session_partial"
        static let prAchieved = "pr_achieved"
        static let shareStory = "share_story"
        static let shareFeed = "share_feed"
        static let coachReview = "coach_review"
        static let coachCongratulate = "coach_congratulate"
        static let clientThanks = "client_thanks"
        static let kudosSent = "kudos_sent"
        static let reminderOpened = "reminder_opened"
        static let restTimerSkipped = "rest_timer_skipped"
        /// El entrenador escribe la nota de un día (WP5). No está en la lista de §7.4 porque S23
        /// nació con el paquete del entrenador; el prompt de WP5 sí lo exige.
        static let dayNoteSent = "day_note_sent"
    }

    /// Claves de propiedad que se repiten, para que dos pantallas no las escriban distinto.
    enum Property {
        static let programId = "program_id"
        static let dayId = "day_id"
        static let logId = "log_id"
        static let exerciseKey = "exercise_key"
        static let setNumber = "set_number"
        static let setCount = "set_count"
        static let plannedSetCount = "planned_set_count"
        static let durationSeconds = "duration_seconds"
        static let volumeKg = "volume_kg"
        static let prCount = "pr_count"
        static let source = "source"
        static let mode = "mode"
        static let isFreeWorkout = "is_free_workout"
        /// Solo el identificador, nunca el nombre ni el correo de nadie.
        static let clientId = "client_id"
        static let clientCount = "client_count"
        static let date = "date"
    }

    // MARK: - API

    /// Registra un evento. Nunca lanza ni bloquea: la analítica no puede romper una sesión.
    ///
    /// `@MainActor` porque hoy la salida es `Logger`, que lo es. Las vistas y los servicios del
    /// módulo ya viven ahí, así que ninguna llamada necesita `await`.
    @MainActor
    static func track(_ event: String, _ props: [String: any Sendable] = [:]) {
        send(event, props)
    }

    // MARK: - Salida actual

    @MainActor
    private static func send(_ event: String, _ props: [String: any Sendable]) {
        guard !props.isEmpty else {
            Logger.shared.info(event, category: .analytics)
            return
        }
        Logger.shared.info("\(event) \(describe(props))", category: .analytics)
    }

    /// Orden estable de las claves: dos registros del mismo evento se comparan a ojo.
    private static func describe(_ props: [String: any Sendable]) -> String {
        let pairs = props.keys.sorted().map { key -> String in
            "\(key)=\(props[key].map { "\($0)" } ?? "nil")"
        }
        return "{" + pairs.joined(separator: ", ") + "}"
    }
}
