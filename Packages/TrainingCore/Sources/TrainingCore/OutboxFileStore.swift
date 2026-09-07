//
//  OutboxFileStore.swift
//  TrainingCore
//
//  El outbox en disco: un fichero JSON por sesión, dentro de una carpeta por usuario.
//
//      {root}/{user_id}/{client_uuid}.json
//
//  Está en el paquete y no en la app porque la parte que hay que probar es exactamente esta: que
//  la carpeta de una persona no se toca al borrar la de otra, que un fichero corrupto no bloquea
//  la cola y que lo escrito vuelve igual. Con la raíz inyectada, todo eso se prueba con
//  `swift test` sobre un directorio temporal.
//
//  No hace logging ni conoce `Application Support`: eso es del envoltorio de la app
//  (`Services/Training/TrainingOutboxStore.swift`).
//

import Foundation

public struct OutboxFileStore: Sendable {

    /// Qué pasó al leer un fichero. `corrupt` es una respuesta, no una excepción: la app tiene
    /// que poder contarlos y el fichero ya se ha retirado para que no bloquee la cola.
    public enum ReadOutcome: Sendable {
        case ok(OutboxEntry)
        case missing
        case corrupt
    }

    public let root: URL
    /// Opciones de escritura. La app usa `[.atomic, .completeFileProtectionUntilFirstUserAuthentication]`;
    /// los tests usan solo `.atomic`, porque la protección de datos no existe fuera de iOS.
    public let writingOptions: Data.WritingOptions

    private var fileManager: FileManager { .default }

    public init(root: URL, writingOptions: Data.WritingOptions = [.atomic]) {
        self.root = root
        self.writingOptions = writingOptions
    }

    // MARK: - Rutas

    public func directory(forUserId userId: Int) -> URL {
        root.appendingPathComponent(Outbox.directoryName(forUserId: userId), isDirectory: true)
    }

    public func fileURL(id: UUID, userId: Int) -> URL {
        directory(forUserId: userId).appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - Escritura

    /// Guarda la entrada en la carpeta de SU usuario, creándola si hace falta.
    @discardableResult
    public func write(_ entry: OutboxEntry) -> Bool {
        let folder = directory(forUserId: entry.userId)
        if !fileManager.fileExists(atPath: folder.path) {
            guard (try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
                return false
            }
        }
        guard let data = try? Outbox.encode(entry) else { return false }
        // Atómica: o está el fichero entero o está el anterior. Nunca medio JSON.
        return (try? data.write(to: folder.appendingPathComponent(entry.fileName), options: writingOptions)) != nil
    }

    /// Borra una entrada. Se llama SOLO tras un 2xx.
    public func remove(_ id: UUID, userId: Int) {
        let url = fileURL(id: id, userId: userId)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// Vacía la carpeta de UN usuario. La de los demás no se toca.
    public func removeAll(userId: Int) {
        let folder = directory(forUserId: userId)
        guard fileManager.fileExists(atPath: folder.path) else { return }
        try? fileManager.removeItem(at: folder)
    }

    // MARK: - Lectura

    /// Lee una entrada. Un fichero ilegible es basura, no un entreno: se retira para que no
    /// bloquee la cola, y se devuelve `.corrupt` para que la app lo registre.
    public func read(_ id: UUID, userId: Int) -> ReadOutcome {
        let url = fileURL(id: id, userId: userId)
        guard let data = try? Data(contentsOf: url) else { return .missing }
        guard let entry = try? Outbox.decode(data) else {
            try? fileManager.removeItem(at: url)
            return .corrupt
        }
        return .ok(entry)
    }

    /// Todas las entradas de un usuario, en orden de drenaje.
    public func all(userId: Int) -> [OutboxEntry] {
        let folder = directory(forUserId: userId)
        guard fileManager.fileExists(atPath: folder.path) else { return [] }
        let names = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
        let entries = names.compactMap { name -> OutboxEntry? in
            guard let id = Outbox.identifier(fromFileName: name) else { return nil }
            if case .ok(let entry) = read(id, userId: userId) { return entry }
            return nil
        }
        return Outbox.drainOrder(entries)
    }

    /// Ids con carpeta en disco. Sirve para diagnóstico y para los tests: la app nunca drena la
    /// cola de otra persona.
    public func knownUserIds() -> [Int] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let names = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        return names.compactMap(Outbox.userId(fromDirectoryName:)).sorted()
    }
}
