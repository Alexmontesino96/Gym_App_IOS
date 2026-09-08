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
//  2. **Cada entrada viaja con SU espacio.** El `X-Gym-ID` sale de la entrada, no del gimnasio
//     que esté seleccionado cuando por fin haya red.
//  3. **Se drena solo.** Cuando `NetworkMonitor` dice que hay red y cuando la app vuelve a
//     primer plano. El usuario no tiene que pedir que se sincronice: la sincronización se
//     comunica, no se pide (UX §1.3).
//  4. **Nada se borra sin confirmación, y nada se borra por un error.** La entrada sale del
//     disco cuando el servidor devuelve el registro. Un 403, un 422 o un 404 la dejan apartada
//     y a la vista, nunca la destruyen.
//
//  La decisión de qué hacer con cada entrada NO vive aquí: vive en `OutboxDrainer`, dentro de
//  `TrainingCore`, donde se prueba sin red ni simulador. Esto es la fontanería.
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

    /// Sesiones cerradas que siguen sin llegar al servidor. Es lo que pinta el chip «Pending sync».
    @Published private(set) var pendingCount = 0
    /// Sesiones apartadas porque el servidor las rechazó. Siguen en disco.
    @Published private(set) var failedCount = 0
    /// Lo mínimo para poder enseñarlas y ofrecer «Retry».
    @Published private(set) var failedEntries: [FailedSyncSummary] = []
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
    private let drainer = OutboxDrainer(policy: .standard)
    private var cancellables = Set<AnyCancellable>()
    private var drainTask: Task<Void, Never>?
    private var isObserving = false

    func configure(trainingService: TrainingService?, networkMonitor: NetworkMonitor?) {
        self.trainingService = trainingService
        self.networkMonitor = networkMonitor
        startObserving()
    }

    // MARK: - Identidad

    /// A quién pertenece lo que se encola. Es el id interno del backend, el mismo `user_id` que
    /// lleva el registro, y decide en qué carpeta vive el fichero.
    ///
    /// Se lee del perfil, que la app carga nada más autenticarse y mucho antes de que nadie
    /// pueda empezar una sesión. Si aún no está, no se encola nada: escribir en la carpeta
    /// equivocada sería peor que devolver `false` y que la pantalla lo reintente.
    var currentUserId: Int? { UserProfileService.shared.userProfile?.id }

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
            await self?.refreshCounts()
        }
    }

    // MARK: - Encolar

    /// Guarda el estado de la sesión en el outbox e intenta enviarlo.
    ///
    /// Lo llama la pantalla de sesión cada vez que hay algo nuevo que contar: al marcar una
    /// serie (`in_progress`) y al cerrar (`completed`). Sin red no falla: la entrada se queda en
    /// disco y el chip lo dice.
    ///
    /// Devuelve `false` solo si no se pudo determinar el espacio o la persona, que en el flujo
    /// real no puede pasar (no hay sesión sin gimnasio seleccionado ni sin perfil cargado).
    @discardableResult
    func enqueue(
        _ session: WorkoutSession,
        status: WorkoutLogStatus? = nil,
        at date: Date = Date()
    ) async -> Bool {
        await enqueue(session.syncRequest(status: status, at: date), at: date)
    }

    @discardableResult
    func enqueue(
        _ payload: WorkoutLogSyncRequest,
        gymId: Int? = nil,
        userId: Int? = nil,
        at date: Date = Date()
    ) async -> Bool {
        guard let gym = gymId ?? GymService.shared.currentGymId,
              let user = userId ?? currentUserId else {
            Logger.shared.error(
                "Outbox: no se pudo encolar \(payload.clientUUID): falta gimnasio o perfil",
                category: .training
            )
            return false
        }

        await store.upsert(payload, gymId: gym, userId: user, at: date)
        await refreshCounts()
        scheduleDrain(reason: "enqueue")
        return true
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

    /// Drena la cola entera del usuario actual. Espera a que termine, para el «Retry» explícito.
    func drain(reason: String = "manual") async {
        guard !isDraining else { return }
        guard let trainingService, let userId = currentUserId else { return }
        // Sin red no se intenta: el backoff se gastaría en fallos garantizados.
        if let networkMonitor, !networkMonitor.isConnected {
            await refreshCounts()
            return
        }

        isDraining = true
        defer { isDraining = false }

        let entries = await store.ready(userId: userId, at: Date())
        guard !entries.isEmpty else {
            lastSyncError = nil
            await refreshCounts()
            return
        }

        Logger.shared.info("Outbox: drenando \(entries.count) entrada(s) [\(reason)]", category: .training)

        let store = self.store
        let report = await drainer.drain(
            entries,
            at: Date(),
            // `Send` está tipado `@Sendable`, y `TrainingService` es un `@MainActor class` que
            // no conforma a `Sendable`: capturarlo fuerte aquí es el error que el propio
            // `syncLogWithRetry` de más abajo dice evitar. Hoy no rompe en ejecución porque el
            // acceso real ocurre dentro de `await self.send(...)`, que vuelve al actor
            // principal, pero con concurrencia estricta no compilaría.
            send: { [weak self, weak trainingService] entry in
                guard let self, let trainingService else {
                    return .transient(reason: "Could not sync")
                }
                return await self.send(entry, using: trainingService)
            },
            persist: { entry in await store.persist(entry) },
            delete: { entry in await store.remove(entry.id, userId: entry.userId) }
        )

        lastSyncError = report.lastError
        if report.lastError == nil { lastSyncedAt = Date() }
        if !report.retriedAsFreeWorkoutIds.isEmpty {
            Logger.shared.warning(
                "Outbox: \(report.retriedAsFreeWorkoutIds.count) registro(s) enviados como entreno libre "
                + "porque su día ya no existe",
                category: .training
            )
        }
        await refreshCounts()
    }

    /// Envía una entrada con SU espacio y traduce la respuesta a lo que el drenador entiende.
    private func send(_ entry: OutboxEntry, using service: TrainingService) async -> OutboxSendOutcome {
        do {
            let log = try await service.syncLogWithRetry(entry.payload, gymId: entry.gymId)
            announce(log, wasFinal: entry.isFinal)
            return .success
        } catch let error as TrainingServiceError {
            if case .server(let status, let message) = error {
                // 404 con día: el entrenador reescribió el día o cambió la asignación. El
                // entreno es real; lo caducado es a qué día del programa colgaba.
                if status == 404, entry.payload.dayId != nil || entry.payload.programId != nil {
                    return .staleDay(reason: message ?? "That day no longer exists")
                }
                if !error.isRetryable {
                    return .rejected(reason: error.errorDescription ?? "Server error (\(status))")
                }
            }
            return error.isRetryable
                ? .transient(reason: error.errorDescription ?? "Could not sync")
                : .rejected(reason: error.errorDescription ?? "Could not sync")
        } catch {
            if (error as NSError).domain == NSURLErrorDomain {
                return .transient(reason: "Waiting for a connection")
            }
            return .transient(reason: error.localizedDescription)
        }
    }

    /// Reintento explícito del usuario. Si ya hay un drenaje en marcha, espera a ese en lugar de
    /// arrancar otro: dos envíos simultáneos de la misma entrada es justo lo que hay que evitar.
    func retryNow() async {
        lastSyncError = nil
        if let task = drainTask {
            await task.value
            return
        }
        await drain(reason: "retry")
    }

    /// Devuelve a la cola las sesiones apartadas y las vuelve a intentar. Es el botón «Retry»
    /// de la lista de fallidas.
    func retryFailed() async {
        guard let userId = currentUserId else { return }
        let reopened = await store.reopenFailed(userId: userId, at: Date())
        guard reopened > 0 else { return }
        Logger.shared.info("Outbox: \(reopened) entrada(s) devueltas a la cola", category: .training)
        lastSyncError = nil
        await refreshCounts()
        await retryNow()
    }

    // MARK: - Estado

    func refreshCounts() async {
        guard let userId = currentUserId else {
            pendingCount = 0
            failedCount = 0
            failedEntries = []
            return
        }
        let all = await store.all(userId: userId)
        pendingCount = all.filter { $0.isFinal && !$0.isFailed }.count
        let failed = all.filter(\.isFailed)
        failedCount = failed.count
        failedEntries = failed.map(\.summary)
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

    // MARK: - Ciclo de vida

    /// Al cerrar sesión. **No borra nada del disco**: los entrenos pendientes son de la persona
    /// que sale y siguen en su carpeta hasta que vuelva a entrar. Aquí solo se apaga lo que hay
    /// en memoria y se corta el drenaje en curso.
    func clearData() {
        drainTask?.cancel()
        drainTask = nil
        lastSyncError = nil
        lastSyncedAt = nil
        pendingCount = 0
        failedCount = 0
        failedEntries = []
    }

    /// Al cambiar de espacio: lo pendiente se manda ANTES de seguir. Se espera a propósito, para
    /// que la precarga del espacio nuevo no compita con el envío del anterior.
    func flushBeforeGymChange() async {
        await drain(reason: "gym-change")
    }

    /// Al borrar la cuenta. Es el único borrado masivo del outbox: si la persona se va de
    /// verdad, sus entrenos sin sincronizar se van con ella.
    func eraseAllData(userId: Int) async {
        drainTask?.cancel()
        drainTask = nil
        await store.removeAll(userId: userId)
        clearData()
    }

    #if DEBUG
    /// Solo para la galería de revisión: pinta el chip de sincronización en el estado pedido.
    /// No toca el disco ni encola nada; es el estado publicado y nada más.
    func simulateGalleryState(pending: Int, failed: Int, reason: String = "The training module is off in this space.") {
        pendingCount = pending
        failedCount = failed
        failedEntries = (0..<failed).map { index in
            FailedSyncSummary(
                id: UUID(),
                title: index == 0 ? "Upper B" : "Lower A",
                completedAt: Date().addingTimeInterval(-3600),
                setCount: 14,
                reason: reason,
                failedAt: Date().addingTimeInterval(-1800)
            )
        }
        lastSyncError = failed > 0 ? reason : nil
    }
    #endif

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
