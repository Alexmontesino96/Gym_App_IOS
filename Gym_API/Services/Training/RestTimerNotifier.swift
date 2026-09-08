//
//  RestTimerNotifier.swift
//  Gym_API
//
//  Notificación local del cronómetro de descanso (UX §8, plan §7.3).
//
//  El problema real: entre serie y serie la gente bloquea el móvil. Sin una notificación local
//  el descanso «termina» en una pantalla que nadie está mirando y la sesión se alarga sola.
//
//  Dos reglas de conducta que no se negocian:
//
//  1. **Nunca se pide el permiso al empezar a entrenar.** Un modal en la cara justo cuando la
//     persona va a marcar su primera serie es exactamente lo que la UX prohíbe. Aquí solo se
//     CONSULTA el estado; si está denegado, la hoja del cronómetro enseña una línea con enlace
//     a Ajustes y ya.
//  2. **Se cancela en cuanto deja de ser verdad.** Marcar la serie siguiente o pulsar `Skip`
//     retira la notificación: una alerta de un descanso que ya no existe es ruido.
//

import Foundation
import UserNotifications
import TrainingCore

@MainActor
final class RestTimerNotifier: ObservableObject {

    // MARK: - Singleton
    static let shared = RestTimerNotifier()
    private init() {}

    // MARK: - Identificadores

    /// Uno solo: nunca hay dos descansos a la vez, y reusar el identificador hace que programar
    /// uno nuevo sustituya al anterior sin tener que cancelarlo a mano.
    static let requestIdentifier = "training.rest-timer"
    static let categoryIdentifier = "TRAINING_REST_TIMER"
    static let addThirtyActionIdentifier = "TRAINING_REST_ADD_30"

    // MARK: - Published

    /// Permiso de notificaciones, consultado sin pedir nada. `.notDetermined` mientras no se sepa.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var canNotify: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// La línea que enseña la hoja del cronómetro cuando no se puede avisar. Nula si sí se puede.
    var permissionHint: String? {
        canNotify ? nil : "Turn on notifications to get an alert when rest ends"
    }

    // MARK: - Registro de la categoría

    private var isCategoryRegistered = false

    /// Registra la acción rápida «Add 30s» de la notificación. Se llama al arrancar la app.
    func registerCategory() {
        guard !isCategoryRegistered else { return }
        isCategoryRegistered = true

        let addThirty = UNNotificationAction(
            identifier: Self.addThirtyActionIdentifier,
            title: "Add 30s",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [addThirty],
            intentIdentifiers: [],
            options: []
        )

        let center = UNUserNotificationCenter.current()
        // No se pisan las categorías de OneSignal: se añade la nuestra a las que ya haya.
        center.getNotificationCategories { existing in
            var categories = existing
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    // MARK: - Permiso

    /// Consulta el estado. No pide nada: el permiso se pide en el onboarding (plan §15).
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Programar y cancelar

    /// Programa la alerta del final del descanso.
    ///
    /// Toma la fecha de fin ABSOLUTA del cronómetro y la convierte en segundos desde ahora, que
    /// es lo que pide `UNTimeIntervalNotificationTrigger`. Si el descanso ya venció, no programa
    /// nada: avisar de algo que ya pasó es peor que no avisar.
    func schedule(for timer: RestTimer, now: Date = Date()) {
        guard canNotify else { return }
        let seconds = timer.endsAt.timeIntervalSince(now)
        // Por debajo de un segundo `UNTimeIntervalNotificationTrigger` lanza una excepción.
        guard seconds >= 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = RestTimer.notificationTitle
        content.body = timer.notificationBody
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "type": "training_rest_timer",
            "exercise_name": timer.exerciseName,
            "set_number": timer.setNumber,
            "total_sets": timer.totalSets
        ]

        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.add(request) { error in
            guard let error else { return }
            Task { @MainActor in
                Logger.shared.error("RestTimerNotifier: \(error.localizedDescription)", category: .training)
            }
        }
    }

    /// Retira la alerta pendiente y la ya entregada. Se llama al marcar la serie siguiente, al
    /// pulsar `Skip` y al cerrar la sesión.
    func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
    }

    /// La persona pulsó «Add 30s» desde la notificación: se reprograma con el cronómetro ya
    /// extendido. Quien llama es responsable de extender también el cronómetro en pantalla.
    func reschedule(for timer: RestTimer, now: Date = Date()) {
        cancel()
        schedule(for: timer, now: now)
    }

    /// `true` si la acción que llega desde el centro de notificaciones es nuestro «Add 30s».
    static func isAddThirtyAction(_ actionIdentifier: String, categoryIdentifier: String) -> Bool {
        actionIdentifier == addThirtyActionIdentifier && categoryIdentifier == Self.categoryIdentifier
    }

    deinit {
        #if DEBUG
        print("🗑️ RestTimerNotifier deinitialized")
        #endif
    }
}
