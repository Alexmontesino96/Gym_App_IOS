//
//  TrainingSyncCoordinator.swift
//  Gym_API
//
//  Drena el outbox de entrenamiento (plan §4.7 y §8.1).
//
//  Reglas que este objeto existe para cumplir:
//
//  1. **Nunca dos envíos a la vez.** Dos drenajes concurrentes mandarían la misma entrada dos
//     veces; el upsert por `client_uuid` lo sobreviviría, pero el segundo POST llegaría con un
//     cuerpo viejo y podría pisar el nuevo. Un único `Task` y una bandera.
//  2. **Se drena solo.** Cuando `NetworkMonitor` dice que hay red y cuando la app vuelve a
//     primer plano. El usuario no tiene que pedir que se sincronice: la sincronización se
//     comunica, no se pide (UX §1.3).
//  3. **Nada se borra sin confirmación.** La entrada sale del disco cuando el servidor devuelve
//     el registro, y solo entonces.
//

import Foundation
import Combine
import UIKit
import TrainingCore

@MainActor
final class TrainingSyncCoordinator: ObservableObject {

    // MARK: - Singleton
    static let shared = TrainingSyncCoordinator()
    private init() {}

    // MARK: - Published

    /// Sesiones que siguen sin llegar al servidor. Es lo que pinta el chip «Pending sync».
    @Published private(set) var pendingCount = 0
    /// Último fallo de sincronización, en inglés y listo para pintar. Nulo si todo está enviado.
    @Published private(set) var lastSyncError: String?
    @Published private(set) var isDraining = false
    /// Cuándo se vació la cola por última vez, para el «Synced just now» de WP4.
    @Published private(set) var lastSyncedAt: Date?

    // MARK: - Dependencias
    private weak var trainingService: TrainingService?
    private weak var networkMonitor: NetworkMonitor?

    // MARK: - Privado

    private let store = TrainingOutboxStore.shared
    private let policy = OutboxRetryPolicy.standard
    private var cancellables = Set<AnyCancellable>()
    private var drainTask: Task<Void, Never>?
    private var isObserving = false

    func configure(trainingService: TrainingService?, networkMonitor: NetworkMonitor?) {
        self.trainingService = trainingService
        self.networkMonitor = networkMonitor
        startObserving()
    }

    // MARK: - Observadores

    private func startObserving() {
        guard !isObserving, let networkMonitor else { return }
        isObserving = true

        // Vuelve la red: se drena. `dropFirst` porque el valor inicial no es un cambio.
        networkMonitor.$isConnected
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] connected in
                guard connected else { return }
                self?.scheduleDrain(reason: "network")
            }
            .store(in: &cancellables)

        // Vuelve la app: se drena. Cubre el caso de haber quedado sin red con la app cerrada.
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.scheduleDrain(reason: "foreground")
            }
            .store(in: &cancellables)

        Task { [weak self] in
            await self?.refreshPendingCount()
        }
    }

    // MARK: - Encolar

    /// Guarda el estado de la sesión en el outbox e intenta enviarlo.
    ///
    /// Lo llama la pantalla de sesión cada vez que hay algo nuevo que contar: al marcar una
    /// serie (`in_progress`) y al cerrar (`completed`). Nunca falla de cara al usuario: si no
    /// hay red, la entrada se queda en disco y el chip lo dice.
    func enqueue(_ session: WorkoutSession, status: WorkoutLogStatus? = nil, at date: Date = Date()) async {
        let payload = session.syncRequest(status: status, at: date)
        await enqueue(payload, at: date)
    }

    func enqueue(_ payload: WorkoutLogSyncRequest, at date: Date = Date()) async {
        await store.upsert(payload, at: date)
        await refreshPendingCount()
        scheduleDrain(reason: "enqueue")
    }

    // MARK: - Drenar

    /// Lanza un drenaje si no hay otro en curso. No espera: quien encola sigue con lo suyo.
    func scheduleDrain(reason: String) {
        guard drainTask == nil else { return }
        drainTask = Task { [weak self] in
            await self?.drain(reason: reason)
            self?.drainTask = nil
        }
    }

    /// Drena la cola entera. Espera a que termine, para el «Retry» explícito de la interfaz.
    ///
    /// `ignoringBackoff` salta la espera entre reintentos: solo lo usa el «Retry» que pulsa la
    /// persona, porque acabar de pedirlo es información que el backoff no tiene.
    func drain(reason: String = "manual", ignoringBackoff: Bool = false) async {
        guard !isDraining else { return }
        guard let trainingService else { return }
        // Sin red no se intenta: el backoff se gastaría en fallos garantizados.
        if let networkMonitor, !networkMonitor.isConnected {
            await refreshPendingCount()
            return
        }

        isDraining = true
        defer { isDraining = false }

        let entries = ignoringBackoff ? await store.all() : await store.ready(at: Date(), policy: policy)
        guard !entries.isEmpty else {
            lastSyncError = nil
            await refreshPendingCount()
            return
        }

        Logger.shared.info("Outbox: drenando \(entries.count) entrada(s) [\(reason)]", category: .training)
        var failure: String?

        for entry in entries {
            if Task.isCancelled { break }
            do {
                // `NetworkRetryManager` absorbe los cortes de un segundo dentro de este intento;
                // la política del outbox decide cuándo se vuelve a intentar entre drenajes.
                let log = try await NetworkRetryManager.shared.retry(
                    operation: { try await trainingService.syncLog(entry.payload) },
                    policy: .conservative,
                    context: "training/logs/sync"
                )
                await store.remove(entry.id)
                announce(log, wasFinal: entry.isFinal)
            } catch {
                let message = describe(error)
                await store.recordAttempt(entry.id, at: Date(), error: message)

                if let serviceError = error as? TrainingServiceError, !serviceError.isRetryable {
                    // El servidor lo ha rechazado por el cuerpo o por permisos: reintentarlo no
                    // lo arregla y dejarlo bloquearía la cola para siempre. Se retira y se avisa.
                    await store.remove(entry.id)
                    failure = message
                    Logger.shared.error("Outbox: entrada \(entry.id) descartada: \(message)", category: .training)
                } else {
                    failure = message
                    Logger.shared.error("Outbox: fallo en \(entry.id): \(message)", category: .training)
                    // Sin red no tiene sentido seguir con el resto de la cola.
                    break
                }
            }
        }

        lastSyncError = failure
        if failure == nil { lastSyncedAt = Date() }
        await refreshPendingCount()
    }

    /// Reintento explícito del usuario. Si ya hay un drenaje en marcha, espera a ese en lugar de
    /// arrancar otro: dos envíos simultáneos de la misma entrada es justo lo que hay que evitar.
    func retryNow() async {
        lastSyncError = nil
        if let task = drainTask {
            await task.value
            return
        }
        await drain(reason: "retry", ignoringBackoff: true)
    }

    // MARK: - Estado

    func refreshPendingCount() async {
        pendingCount = await store.pendingFinalCount
    }

    /// El registro cerrado ya está confirmado por el servidor: es el único momento en el que se
    /// puede hablar de marca personal (plan §4.5).
    private func announce(_ log: TrainingWorkoutLog, wasFinal: Bool) {
        guard wasFinal, log.status == .completed else { return }

        Analytics.track(
            log.isPartial ? Analytics.Event.sessionPartial : Analytics.Event.sessionCompleted,
            [
                Analytics.Property.logId: log.id,
                Analytics.Property.setCount: log.totalSets,
                Analytics.Property.volumeKg: log.totalVolumeKg,
                Analytics.Property.durationSeconds: log.durationSeconds ?? 0,
                Analytics.Property.prCount: log.prCount
            ]
        )
        for record in log.personalRecordSets {
            Analytics.track(
                Analytics.Event.prAchieved,
                [
                    Analytics.Property.logId: log.id,
                    Analytics.Property.exerciseKey: record.exerciseKey,
                    Analytics.Property.setNumber: record.setNumber
                ]
            )
        }
        NotificationCenter.default.post(name: .trainingLogSynced, object: log.id)
    }

    private func describe(_ error: Error) -> String {
        if let serviceError = error as? TrainingServiceError {
            return serviceError.errorDescription ?? "Could not sync"
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Waiting for a connection"
        }
        return error.localizedDescription
    }

    // MARK: - Ciclo de vida

    /// Al cerrar sesión. El outbox es de la persona que entrenó, no del dispositivo.
    func clearData() {
        drainTask?.cancel()
        drainTask = nil
        lastSyncError = nil
        lastSyncedAt = nil
        pendingCount = 0
        Task { [store] in
            await store.removeAll()
        }
    }

    /// Al cambiar de espacio: las entradas pendientes son del gimnasio anterior y se envían
    /// antes de que la app cambie de contexto. No se borran: son trabajo real de alguien.
    func flushBeforeGymChange() {
        scheduleDrain(reason: "gym-change")
    }

    deinit {
        #if DEBUG
        print("🗑️ TrainingSyncCoordinator deinitialized")
        #endif
    }
}

// MARK: - Avisos

extension Notification.Name {
    /// El servidor confirmó un registro cerrado. El objeto es el `Int` del id del registro.
    /// S18 lo escucha para pasar de «Best set so far» a «Personal record».
    static let trainingLogSynced = Notification.Name("trainingLogSynced")
}
