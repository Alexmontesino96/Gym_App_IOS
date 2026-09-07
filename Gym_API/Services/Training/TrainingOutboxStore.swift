//
//  TrainingOutboxStore.swift
//  Gym_API
//
//  Cola de escrituras pendientes del módulo de entrenamiento, en disco (plan §4.7).
//
//  «Offline es el estado normal, no la excepción» (UX §1.3). El sótano de un gimnasio no tiene
//  cobertura, así que la sesión se escribe aquí en el momento de marcar cada serie y se envía
//  cuando se pueda. Perder un entreno registrado es inaceptable: es media hora de la vida de
//  alguien y la razón por la que paga.
//
//  Formato: un fichero JSON por registro, en
//  `Application Support/TrainingOutbox/{user_id}/{client_uuid}.json`.
//
//  **Una carpeta por usuario.** Dos cuentas en el mismo teléfono no se pisan, y cerrar sesión no
//  puede llevarse por delante los entrenos pendientes de quien sale: se quedan en su carpeta y
//  se envían cuando vuelva a entrar. El único borrado masivo es el de `AccountService`, cuando
//  la persona borra su cuenta de verdad.
//
//  El manejo de ficheros vive en `OutboxFileStore`, dentro de `TrainingCore`, para poder probarlo
//  contra un directorio temporal. Esto es el envoltorio: decide la raíz, aplica la protección de
//  datos de iOS y registra en el log.
//
//  Es un `actor`: escribir en disco no puede pasar por el hilo principal mientras alguien está
//  marcando series a un toque por segundo.
//

import Foundation
import TrainingCore

actor TrainingOutboxStore {

    // MARK: - Singleton
    static let shared = TrainingOutboxStore()

    // MARK: - Disco

    /// `Application Support/TrainingOutbox`. Application Support y no Caches a propósito: el
    /// sistema puede vaciar Caches cuando le falta espacio, y ahí vive trabajo sin sincronizar.
    ///
    /// Protección hasta el primer desbloqueo: una serie se puede marcar con la pantalla
    /// bloqueada, y `.complete` haría fallar la escritura justo entonces.
    private let files: OutboxFileStore?

    private init() {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Self.logError("Outbox: no hay Application Support")
            files = nil
            return
        }
        files = OutboxFileStore(
            root: base.appendingPathComponent("TrainingOutbox", isDirectory: true),
            writingOptions: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    // MARK: - Escritura

    /// Guarda el estado completo de una sesión. Si ya había una entrada con ese `client_uuid`
    /// se reemplaza el cuerpo y se conserva el historial de intentos: la entrada es la sesión,
    /// no cada serie suelta.
    ///
    /// `gymId` y `userId` se fijan al crearla y no cambian: son a qué espacio y a quién
    /// pertenece el entreno, y el envío depende de ellos.
    @discardableResult
    func upsert(
        _ payload: WorkoutLogSyncRequest,
        gymId: Int,
        userId: Int,
        at date: Date = Date()
    ) -> OutboxEntry? {
        guard let files else { return nil }
        var entry: OutboxEntry
        if var existing = load(payload.clientUUID, userId: userId) {
            existing.update(payload: payload, at: date)
            entry = existing
        } else {
            entry = OutboxEntry(payload: payload, gymId: gymId, userId: userId, createdAt: date)
        }
        guard files.write(entry) else {
            Self.logError("Outbox: no se pudo guardar \(entry.id)")
            return nil
        }
        return entry
    }

    /// Guarda una entrada ya modificada por el drenaje (intento anotado, degradada o apartada).
    @discardableResult
    func persist(_ entry: OutboxEntry) -> Bool {
        guard let files else { return false }
        guard files.write(entry) else {
            Self.logError("Outbox: no se pudo guardar \(entry.id)")
            return false
        }
        return true
    }

    /// Devuelve a la cola todas las entradas apartadas de un usuario. Es lo que hace «Retry».
    @discardableResult
    func reopenFailed(userId: Int, at date: Date = Date()) -> Int {
        guard let files else { return 0 }
        var reopened = 0
        for var entry in files.all(userId: userId) where entry.isFailed {
            entry.reopenForRetry(at: date)
            if files.write(entry) { reopened += 1 }
        }
        return reopened
    }

    /// Borra la entrada. Se llama SOLO cuando el servidor ha confirmado el registro.
    func remove(_ id: UUID, userId: Int) {
        files?.remove(id, userId: userId)
    }

    /// Vacía la carpeta de un usuario. **Solo se llama al borrar la cuenta**, nunca al cerrar
    /// sesión: cerrar sesión no puede destruir entrenos que todavía no han llegado al servidor.
    func removeAll(userId: Int) {
        files?.removeAll(userId: userId)
        Self.logInfo("Outbox: carpeta de \(userId) borrada")
    }

    // MARK: - Lectura

    func load(_ id: UUID, userId: Int) -> OutboxEntry? {
        guard let files else { return nil }
        switch files.read(id, userId: userId) {
        case .ok(let entry):
            return entry
        case .missing:
            return nil
        case .corrupt:
            Self.logError("Outbox: entrada corrupta \(id), se descarta")
            return nil
        }
    }

    /// Todas las entradas de un usuario en orden de drenaje: primero las sesiones cerradas,
    /// luego por antigüedad.
    func all(userId: Int) -> [OutboxEntry] {
        files?.all(userId: userId) ?? []
    }

    /// Entradas que toca intentar ahora, según el backoff de cada una. Las apartadas quedan fuera.
    func ready(userId: Int, at date: Date = Date(), policy: OutboxRetryPolicy = .standard) -> [OutboxEntry] {
        Outbox.ready(all(userId: userId), at: date, policy: policy)
    }

    /// Entradas apartadas, para la lista que enseña la interfaz.
    func failed(userId: Int) -> [OutboxEntry] {
        Outbox.failed(all(userId: userId))
    }

    func count(userId: Int) -> Int { all(userId: userId).count }

    /// Cuántas sesiones cerradas siguen sin llegar al servidor. Es lo que pinta «Pending sync».
    func pendingFinalCount(userId: Int) -> Int {
        all(userId: userId).filter { $0.isFinal && !$0.isFailed }.count
    }

    /// Ids de usuario con carpeta en disco. Diagnóstico: la app nunca drena la cola de otra
    /// persona.
    func knownUserIds() -> [Int] {
        files?.knownUserIds() ?? []
    }

    // MARK: - Privado

    /// `Logger` vive en el hilo principal y esto es un actor: el log salta, el trabajo no.
    private nonisolated static func logError(_ message: String) {
        Task { @MainActor in
            Logger.shared.error(message, category: .training)
        }
    }

    private nonisolated static func logInfo(_ message: String) {
        Task { @MainActor in
            Logger.shared.info(message, category: .training)
        }
    }

    deinit {
        #if DEBUG
        print("🗑️ TrainingOutboxStore deinitialized")
        #endif
    }
}
