//
//  NetworkMonitor.swift
//  Gym_API
//
//  Saber si hay red, publicado para la interfaz.
//
//  Por qué existe: hasta ahora la app solo se enteraba de que no había red cuando una petición
//  fallaba. Con el módulo de entrenamiento eso no basta: el registro se escribe en un outbox
//  local y hay que drenarlo EN CUANTO vuelve la cobertura, no en el siguiente toque del usuario.
//
//  Regla de uso: esto NO es un permiso para hacer la petición. Apple lleva años diciendo que no
//  se compruebe la conectividad antes de conectar (el «reachability check» es una carrera que
//  siempre se pierde). Se usa para dos cosas y solo dos: disparar el drenaje del outbox cuando
//  la ruta pasa a satisfecha, y pintar el chip «Pending sync».
//

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Singleton
    static let shared = NetworkMonitor()

    // MARK: - Published

    /// `true` mientras la ruta actual esté satisfecha. Empieza en `true` a propósito: asumir que
    /// no hay red antes de la primera actualización haría parpadear «Offline» en cada arranque.
    @Published private(set) var isConnected = true
    /// Red cara: el drenaje de un outbox de texto plano cabe igual, pero WP4 puede querer
    /// posponer subidas grandes.
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false

    // MARK: - Privado

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.gymapi.networkmonitor", qos: .utility)
    private var isRunning = false

    private init() {}

    // MARK: - Ciclo de vida

    /// Arranca la vigilancia. Idempotente: llamarlo dos veces no crea dos monitores.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            // `pathUpdateHandler` llega en la cola del monitor; el estado publicado es de la UI.
            Task { @MainActor [weak self] in
                self?.apply(connected: connected, expensive: expensive, constrained: constrained)
            }
        }
        monitor.start(queue: queue)

        Logger.shared.info("NetworkMonitor iniciado", category: .network)
    }

    func stop() {
        guard isRunning else { return }
        monitor.cancel()
        isRunning = false
    }

    private func apply(connected: Bool, expensive: Bool, constrained: Bool) {
        isExpensive = expensive
        isConstrained = constrained
        guard connected != isConnected else { return }
        isConnected = connected
        Logger.shared.info(
            connected ? "Red disponible" : "Sin red",
            category: .network
        )
    }

    deinit {
        // `monitor` es una clase de Network.framework y se puede cancelar desde cualquier hilo.
        monitor.cancel()
        #if DEBUG
        print("🗑️ NetworkMonitor deinitialized")
        #endif
    }
}
