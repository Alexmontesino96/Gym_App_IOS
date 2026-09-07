//
//  Outbox.swift
//  TrainingCore
//
//  Serialización y política de reintento del registro pendiente (plan §4.7).
//
//  «Offline es el estado normal, no la excepción» (UX §1.3): el sótano de un gimnasio no tiene
//  cobertura. La app escribe la serie en local en el momento de marcarla y esto es lo que se
//  guarda: un cuerpo de `POST /training/logs/sync` completo, con su `client_uuid` y el de cada
//  serie, más cuántas veces se ha intentado enviar.
//
//  Como el envío es un upsert por `client_uuid`, reenviar la misma entrada no duplica nada. Eso
//  es lo que permite reintentar sin miedo.
//

import Foundation

// MARK: - Entrada del outbox

public struct OutboxEntry: Codable, Hashable, Identifiable, Sendable {

    /// El id de la entrada es el `client_uuid` del registro: una entrada por sesión, siempre.
    public var id: UUID { payload.clientUUID }

    public var payload: WorkoutLogSyncRequest
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var attemptCount: Int
    public private(set) var lastAttemptAt: Date?
    public private(set) var lastError: String?

    public enum CodingKeys: String, CodingKey {
        case payload
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case attemptCount = "attempt_count"
        case lastAttemptAt = "last_attempt_at"
        case lastError = "last_error"
    }

    public init(payload: WorkoutLogSyncRequest, createdAt: Date) {
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.attemptCount = 0
        self.lastAttemptAt = nil
        self.lastError = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payload = try container.decode(WorkoutLogSyncRequest.self, forKey: .payload)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        attemptCount = try container.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
        lastAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
    }

    /// Sustituye el cuerpo conservando el historial de intentos. Se llama cada vez que el
    /// cliente marca otra serie: la entrada es siempre el estado completo de la sesión.
    public mutating func update(payload: WorkoutLogSyncRequest, at date: Date) {
        self.payload = payload
        self.updatedAt = date
    }

    public mutating func recordAttempt(at date: Date, error: String?) {
        attemptCount += 1
        lastAttemptAt = date
        lastError = error
        updatedAt = date
    }

    public mutating func clearError() {
        lastError = nil
    }

    /// Un cierre de sesión pesa más que un progreso intermedio: se drena antes.
    public var isFinal: Bool { payload.isFinal }

    /// Nombre del fichero en `Application Support/TrainingOutbox`.
    public var fileName: String { "\(id.uuidString).json" }
}

// MARK: - Política de reintento

public struct OutboxRetryPolicy: Hashable, Sendable {

    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let multiplier: Double
    public let maxDelay: TimeInterval

    /// Backoff exponencial con techo de cinco minutos. Ocho intentos cubren más de veinte
    /// minutos sin cobertura; pasado eso, la entrada NO se borra: se queda esperando a que
    /// alguien vuelva a abrir la app con red.
    public static let standard = OutboxRetryPolicy(
        maxAttempts: 8,
        initialDelay: 2,
        multiplier: 2,
        maxDelay: 300
    )

    public init(maxAttempts: Int, initialDelay: TimeInterval, multiplier: Double, maxDelay: TimeInterval) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
    }

    /// Espera antes del intento número `attempt` (1 = el primero, sin espera).
    public func delay(beforeAttempt attempt: Int) -> TimeInterval {
        guard attempt > 1 else { return 0 }
        let raw = initialDelay * pow(multiplier, Double(attempt - 2))
        return min(maxDelay, raw)
    }

    /// Cuándo se puede volver a intentar una entrada. `nil` = ahora mismo.
    public func nextAttemptDate(for entry: OutboxEntry) -> Date? {
        guard let last = entry.lastAttemptAt, entry.attemptCount > 0 else { return nil }
        return last.addingTimeInterval(delay(beforeAttempt: entry.attemptCount + 1))
    }

    public func isReady(_ entry: OutboxEntry, at now: Date) -> Bool {
        guard let next = nextAttemptDate(for: entry) else { return true }
        return now >= next
    }

    /// Se agotaron los intentos automáticos. La entrada sigue en disco y se reintenta cuando el
    /// usuario vuelva a abrir la app o toque «Retry»: perder un entreno registrado es inaceptable.
    public func hasExhaustedAutomaticRetries(_ entry: OutboxEntry) -> Bool {
        entry.attemptCount >= maxAttempts
    }
}

// MARK: - Serialización

public enum Outbox {

    public static func encoder() -> JSONEncoder {
        let encoder = TrainingJSON.encoder()
        // Ordenar las claves hace que dos serializaciones del mismo contenido sean idénticas byte
        // a byte, que es lo que permite comparar y depurar los ficheros a ojo.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        TrainingJSON.decoder()
    }

    public static func encode(_ entry: OutboxEntry) throws -> Data {
        try encoder().encode(entry)
    }

    public static func decode(_ data: Data) throws -> OutboxEntry {
        try decoder().decode(OutboxEntry.self, from: data)
    }

    /// Orden de drenaje: primero las sesiones cerradas (que es lo que dispara la revisión del
    /// entrenador y el cálculo de marcas), y dentro de cada grupo, las más antiguas.
    public static func drainOrder(_ entries: [OutboxEntry]) -> [OutboxEntry] {
        entries.sorted { left, right in
            if left.isFinal != right.isFinal { return left.isFinal }
            return left.createdAt < right.createdAt
        }
    }

    /// Entradas que toca intentar ahora.
    public static func ready(
        _ entries: [OutboxEntry],
        at now: Date,
        policy: OutboxRetryPolicy = .standard
    ) -> [OutboxEntry] {
        drainOrder(entries).filter { policy.isReady($0, at: now) }
    }

    /// Un `client_uuid` válido en el nombre del fichero. Evita que un fichero suelto que alguien
    /// dejó en la carpeta se intente decodificar.
    public static func identifier(fromFileName name: String) -> UUID? {
        guard name.hasSuffix(".json") else { return nil }
        return UUID(uuidString: String(name.dropLast(5)))
    }
}
