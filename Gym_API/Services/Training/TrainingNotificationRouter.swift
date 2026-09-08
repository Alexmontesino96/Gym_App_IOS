//
//  TrainingNotificationRouter.swift
//  Gym_API
//
//  Enrutado de las notificaciones del módulo (plan §7.1 y §8.2).
//
//  Hace dos cosas y ninguna más:
//
//  1. **Deep link `training/logs/{id}`.** Un push de revisión del entrenador abre S18 en modo
//     lectura. Sin esto, tocar la notificación abre la app en la home y la persona tiene que
//     buscar de qué le hablaban.
//  2. **Acción «Add 30s» del cronómetro.** La notificación local del descanso trae esa acción
//     desde WP3 (`RestTimerNotifier.registerCategory`), pero hasta ahora nadie la escuchaba.
//
//  Sobre el delegado: OneSignal instala el suyo al inicializarse. Este se pone DESPUÉS y guarda
//  el anterior para reenviarle todo, así que las notificaciones de OneSignal siguen funcionando
//  igual. Si algún día el SDK deja de aceptar la cadena, lo que se rompe es el deep link, no el
//  push.
//

import Foundation
import UserNotifications
import UIKit

final class TrainingNotificationRouter: NSObject {

    static let shared = TrainingNotificationRouter()

    /// El delegado que había antes (el de OneSignal), al que se le reenvía todo.
    ///
    /// Aislado en el actor principal, como `isInstalled`: los dos se escriben en `install()`,
    /// que ya era `@MainActor`, pero se leían desde los callbacks del sistema, que llegan
    /// `nonisolated` y pueden venir en cualquier hilo. Con Swift 6 estricto eso es un error de
    /// compilación, y sin él es una lectura sin sincronizar que hoy no rompe solo porque
    /// `install()` se llama una vez al arrancar.
    @MainActor private weak var previousDelegate: UNUserNotificationCenterDelegate?
    @MainActor private var isInstalled = false

    private override init() {
        super.init()
    }

    /// Se llama al arrancar, después de `OneSignalService.initialize()`.
    @MainActor
    func install() {
        guard !isInstalled else { return }
        isInstalled = true

        let center = UNUserNotificationCenter.current()
        previousDelegate = center.delegate
        center.delegate = self

        RestTimerNotifier.shared.registerCategory()
    }

    /// Extrae el id de `training/logs/{id}`. Devuelve `nil` con cualquier otra cosa.
    static func logId(fromDeeplink deeplink: String) -> Int? {
        let parts = deeplink.split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "training", parts[1] == "logs" else { return nil }
        return Int(parts[2])
    }

    /// Busca el deep link en el `userInfo` de un push, mire donde mire OneSignal.
    static func deeplink(in userInfo: [AnyHashable: Any]) -> String? {
        if let direct = userInfo["deeplink"] as? String { return direct }
        if let custom = userInfo["custom"] as? [AnyHashable: Any],
           let data = custom["a"] as? [AnyHashable: Any],
           let deeplink = data["deeplink"] as? String {
            return deeplink
        }
        if let data = userInfo["data"] as? [AnyHashable: Any],
           let deeplink = data["deeplink"] as? String {
            return deeplink
        }
        return nil
    }

    @MainActor
    private func handle(_ response: UNNotificationResponse) {
        let content = response.notification.request.content

        if RestTimerNotifier.isAddThirtyAction(
            response.actionIdentifier,
            categoryIdentifier: content.categoryIdentifier
        ) {
            NotificationCenter.default.post(name: .trainingRestAddThirty, object: nil)
            return
        }

        guard let deeplink = Self.deeplink(in: content.userInfo),
              let logId = Self.logId(fromDeeplink: deeplink) else { return }
        NotificationCenter.default.post(name: .trainingOpenLog, object: logId)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension TrainingNotificationRouter: UNUserNotificationCenterDelegate {

    // Los dos callbacks entran `nonisolated` —el sistema los entrega donde quiere— y lo primero
    // que hacen es saltar al actor principal. Todo lo demás, incluida la lectura del delegado
    // anterior y la llamada al `completionHandler`, ocurre ya dentro. El coste es que el reenvío
    // al SDK se hace un turno más tarde; a cambio no hay ni una lectura sin sincronizar.

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler()
                return
            }
            self.handle(response)

            if let previous = self.previousDelegate,
               previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
                previous.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
            } else {
                completionHandler()
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler([.banner, .sound, .list])
                return
            }
            if let previous = self.previousDelegate,
               previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
                previous.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
            } else {
                // El aviso del descanso se enseña también con la app abierta: la persona puede
                // tener el móvil en el suelo mirando otra cosa.
                completionHandler([.banner, .sound, .list])
            }
        }
    }
}
