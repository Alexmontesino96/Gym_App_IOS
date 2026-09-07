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
//  Formato: un fichero JSON por registro, `Application Support/TrainingOutbox/{client_uuid}.json`.
//  Un fichero por sesión y no una base de datos porque una escritura atómica de un fichero es la
//  operación más difícil de corromper que existe, y porque el fichero se puede abrir y leer a
//  ojo cuando algo va mal.
//
//  Es un `actor`: escribir en disco no puede pasar por el hilo principal mientras alguien está
//  marcando series a un toque por segundo.
//

import Foundation
import TrainingCore

actor TrainingOutboxStore {

    // MARK: - Singleton
    static let shared = TrainingOutboxStore()

    // MARK: - Ubicación

    private let fileManager = FileManager.default

    /// `Application Support/TrainingOutbox`. Application Support y no Caches a propósito: el
    /// sistema puede vaciar Caches cuando le falta espacio, y ahí vive trabajo sin sincronizar.
    private lazy var directory: URL? = {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Self.logError("Outbox: no hay Application Support")
            return nil
        }
        let url = base.appendingPathComponent("TrainingOutbox", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                Self.logError("Outbox: no se pudo crear la carpeta: \(error)")
                return nil
            }
        }
        return url
    }()

    private init() {}

    // MARK: - Escritura

    /// Guarda el estado completo de una sesión. Si ya había una entrada con ese `client_uuid`
    /// se reemplaza el cuerpo y se conserva el historial de intentos: la entrada es la sesión,
    /// no cada serie suelta.
    @discardableResult
    func upsert(_ payload: WorkoutLogSyncRequest, at date: Date = Date()) -> OutboxEntry? {
        var entry: OutboxEntry
        if var existing = load(payload.clientUUID) {
            existing.update(payload: payload, at: date)
            entry = existing
        } else {
            entry = OutboxEntry(payload: payload, createdAt: date)
        }
        return write(entry) ? entry : nil
    }

    /// Anota un intento fallido para que la política de reintento sepa cuándo volver.
    func recordAttempt(_ id: UUID, at date: Date = Date(), error: String?) {
        guard var entry = load(id) else { return }
        entry.recordAttempt(at: date, error: error)
        _ = write(entry)
    }

    /// Borra la entrada. Se llama SOLO cuando el servidor ha confirmado el registro.
    func remove(_ id: UUID) {
        guard let directory else { return }
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            Self.logError("Outbox: no se pudo borrar \(id): \(error)")
        }
    }

    /// Vacía la cola. Es del usuario, así que se llama al cerrar sesión.
    func removeAll() {
        guard let directory else { return }
        for name in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] {
            guard Outbox.identifier(fromFileName: name) != nil else { continue }
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    // MARK: - Lectura

    func load(_ id: UUID) -> OutboxEntry? {
        guard let directory else { return nil }
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Outbox.decode(data)
        } catch {
            // Un fichero ilegible es basura, no un entreno: se retira para que no bloquee la cola.
            Self.logError("Outbox: entrada corrupta \(id), se descarta: \(error)")
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    /// Todas las entradas en orden de drenaje: primero las sesiones cerradas, luego por antigüedad.
    func all() -> [OutboxEntry] {
        guard let directory else { return [] }
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        let entries = names.compactMap { name -> OutboxEntry? in
            guard let id = Outbox.identifier(fromFileName: name) else { return nil }
            return load(id)
        }
        return Outbox.drainOrder(entries)
    }

    /// Entradas que toca intentar ahora, según el backoff de cada una.
    func ready(at date: Date = Date(), policy: OutboxRetryPolicy = .standard) -> [OutboxEntry] {
        Outbox.ready(all(), at: date, policy: policy)
    }

    var count: Int { all().count }

    /// Cuántas sesiones cerradas siguen sin llegar al servidor. Es lo que pinta «Pending sync».
    var pendingFinalCount: Int { all().filter(\.isFinal).count }

    // MARK: - Privado

    @discardableResult
    private func write(_ entry: OutboxEntry) -> Bool {
        guard let directory else { return false }
        let url = directory.appendingPathComponent(entry.fileName)
        do {
            let data = try Outbox.encode(entry)
            // Atómica: o está el fichero entero o está el anterior. Nunca medio JSON.
            // Protección hasta el primer desbloqueo: una serie se puede marcar con la pantalla
            // bloqueada, y `.complete` haría fallar la escritura justo entonces.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            Self.logError("Outbox: no se pudo guardar \(entry.id): \(error)")
            return false
        }
    }

    /// `Logger` vive en el hilo principal y esto es un actor: el log salta, el trabajo no.
    private nonisolated static func logError(_ message: String) {
        Task { @MainActor in
            Logger.shared.error(message, category: .training)
        }
    }

    deinit {
        #if DEBUG
        print("🗑️ TrainingOutboxStore deinitialized")
        #endif
    }
}
