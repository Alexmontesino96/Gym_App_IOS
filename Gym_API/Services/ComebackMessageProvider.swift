import Foundation

// MARK: - Comeback Message Provider
/// Servicio para generar mensajes de re-engagement personalizados basados en días de inactividad
class ComebackMessageProvider {

    /// Genera un mensaje personalizado según los días de inactividad del usuario
    /// - Parameters:
    ///   - daysInactive: Número de días sin asistir a clases
    ///   - userName: Nombre del usuario para personalización
    /// - Returns: ComebackMessage con emoji, título, mensaje y metadata
    static func getMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        switch daysInactive {
        case 0...1:
            return getCasualMessage(daysInactive: daysInactive, userName: userName)
        case 2...3:
            return getFriendlyMessage(daysInactive: daysInactive, userName: userName)
        case 4...7:
            return getMotivationalMessage(daysInactive: daysInactive, userName: userName)
        case 8...14:
            return getChallengingMessage(daysInactive: daysInactive, userName: userName)
        case 15...30:
            return getSupportiveMessage(daysInactive: daysInactive, userName: userName)
        default: // 30+ días
            return getWarmWelcomeMessage(daysInactive: daysInactive, userName: userName)
        }
    }

    // MARK: - Private Message Generators

    /// Días 0-1: Mensajes ligeros y alentadores
    private static func getCasualMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        let messages = [
            ComebackMessage(
                emoji: "🌟",
                title: "¡Hoy es el día!",
                message: "Tu cuerpo te está esperando, \(userName)",
                tone: .encouraging,
                urgency: .medium
            ),
            ComebackMessage(
                emoji: "💫",
                title: "¡Primera clase de la semana!",
                message: "¿Qué tal empezar con energía hoy?",
                tone: .encouraging,
                urgency: .low
            ),
            ComebackMessage(
                emoji: "🎯",
                title: "¡Lista para despegar!",
                message: "Tu espacio está reservado aquí, \(userName)",
                tone: .encouraging,
                urgency: .medium
            )
        ]
        return messages.randomElement() ?? messages[0]
    }

    /// Días 2-3: Mensajes amigables con recordatorio suave
    private static func getFriendlyMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        let messages = [
            ComebackMessage(
                emoji: "💪",
                title: "¡Te extrañamos!",
                message: "Han pasado \(daysInactive) días sin verte. ¿Listo para retomar?",
                tone: .friendly,
                urgency: .medium
            ),
            ComebackMessage(
                emoji: "👋",
                title: "¡Hola, \(userName)!",
                message: "El gimnasio te extraña. ¿Nos vemos hoy?",
                tone: .friendly,
                urgency: .medium
            ),
            ComebackMessage(
                emoji: "💙",
                title: "Tu entrenador preguntó por ti",
                message: "Han sido \(daysInactive) días... ¿todo bien?",
                tone: .friendly,
                urgency: .medium
            )
        ]
        return messages.randomElement() ?? messages[0]
    }

    /// Días 4-7: Mensajes motivacionales más directos
    private static func getMotivationalMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        let messages = [
            ComebackMessage(
                emoji: "🏋️",
                title: "¡Es hora de volver!",
                message: "Ya son \(daysInactive) días... ¡Tu mejor versión te espera!",
                tone: .motivational,
                urgency: .high
            ),
            ComebackMessage(
                emoji: "⚡",
                title: "¡Rompe la pausa!",
                message: "Llevas \(daysInactive) días fuera. Tu cuerpo merece este momento.",
                tone: .motivational,
                urgency: .high
            ),
            ComebackMessage(
                emoji: "🎯",
                title: "\(userName), ¡vuelve más fuerte!",
                message: "Una semana es tiempo suficiente. ¿Empezamos hoy?",
                tone: .motivational,
                urgency: .high
            )
        ]
        return messages.randomElement() ?? messages[0]
    }

    /// Días 8-14: Mensajes con desafío y recordatorio de logros pasados
    private static func getChallengingMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        let messages = [
            ComebackMessage(
                emoji: "🔥",
                title: "¡Enciende tu fuego interior!",
                message: "Llevas \(daysInactive) días fuera. Recuerda tu racha de antes.",
                tone: .challenging,
                urgency: .high
            ),
            ComebackMessage(
                emoji: "💥",
                title: "Tu progreso te espera",
                message: "\(daysInactive) días es mucho tiempo, \(userName). ¡No pierdas lo que construiste!",
                tone: .challenging,
                urgency: .high
            ),
            ComebackMessage(
                emoji: "🚀",
                title: "¡Regresa con todo!",
                message: "Han pasado \(daysInactive) días. El único camino es hacia adelante.",
                tone: .challenging,
                urgency: .high
            )
        ]
        return messages.randomElement() ?? messages[0]
    }

    /// Días 15-30: Mensajes empáticos y comprensivos
    private static func getSupportiveMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        let messages = [
            ComebackMessage(
                emoji: "🤗",
                title: "Vamos a recuperar el ritmo",
                message: "Han pasado \(daysInactive) días. Pequeños pasos, grandes cambios.",
                tone: .supportive,
                urgency: .critical
            ),
            ComebackMessage(
                emoji: "💚",
                title: "Sabemos que la vida es complicada",
                message: "Llevas \(daysInactive) días fuera, pero estamos aquí para ti, \(userName).",
                tone: .supportive,
                urgency: .critical
            ),
            ComebackMessage(
                emoji: "🌱",
                title: "Pequeños pasos cuentan",
                message: "\(daysInactive) días después, ¿empezamos de nuevo juntos?",
                tone: .supportive,
                urgency: .critical
            )
        ]
        return messages.randomElement() ?? messages[0]
    }

    /// Días 30+: Mensajes cálidos de bienvenida sin presión
    private static func getWarmWelcomeMessage(daysInactive: Int, userName: String) -> ComebackMessage {
        let messages = [
            ComebackMessage(
                emoji: "🌈",
                title: "Un nuevo comienzo te espera",
                message: "Nunca es tarde para volver, \(userName). ¿Empezamos hoy?",
                tone: .warm,
                urgency: .critical
            ),
            ComebackMessage(
                emoji: "☀️",
                title: "Bienvenido de nuevo",
                message: "Sin presión, sin juicios. Solo tu espacio esperándote.",
                tone: .warm,
                urgency: .critical
            ),
            ComebackMessage(
                emoji: "🎈",
                title: "Cada día es una nueva oportunidad",
                message: "Han pasado \(daysInactive) días, pero estamos listos cuando tú lo estés.",
                tone: .warm,
                urgency: .critical
            )
        ]
        return messages.randomElement() ?? messages[0]
    }

    // MARK: - Helper Methods

    /// Genera un mensaje de seguimiento para notificaciones push
    /// - Parameter daysInactive: Días sin asistir
    /// - Returns: Texto breve para notificación
    static func getPushNotificationMessage(daysInactive: Int) -> String {
        switch daysInactive {
        case 0...1:
            return "¿Nos vemos hoy? 🏋️"
        case 2...3:
            return "¡Te extrañamos! ¿Lista para entrenar?"
        case 4...7:
            return "Tu mejor racha te está esperando 🔥"
        case 8...14:
            return "¿Volvemos a entrenar juntos?"
        case 15...30:
            return "Un pequeño paso hoy = gran progreso mañana 💪"
        default:
            return "Nunca es tarde para volver. ¿Empezamos?"
        }
    }

    /// Determina si se debe mostrar la vista de comeback basado en días de inactividad
    /// - Parameter daysInactive: Días sin asistir
    /// - Returns: true si se debe mostrar, false si no
    static func shouldShowComebackView(daysInactive: Int, hasShownToday: Bool) -> Bool {
        // No mostrar más de una vez al día
        guard !hasShownToday else { return false }

        // Mostrar solo si hay al menos 1 día de inactividad
        return daysInactive >= 1
    }
}
