//
//  Outbox.swift
//  TrainingCore
//
//  Serialización y política de reintento del registro pendiente (plan §4.7).
//
//  «Offline es el estado normal, no la excepción» (UX §1.3): el sótano de un gimnasio no tiene
//  cobertura. La app escribe la serie en local en el momento de marcarla y esto es lo que se
//  guarda: un cuerpo de `POST /training/logs/sync` completo, con su `client_uuid` y el de cada
//  serie, más el espacio y la persona a la que pertenece y cuántas veces se ha intentado enviar.
//
//  Dos reglas que este fichero existe para hacer cumplir:
//
//  1. **Cada entrada sabe a qué espacio pertenece.** El envío usa `gymId` de la entrada, no el
//     gimnasio que esté seleccionado cuando por fin haya red. Sin esto, cambiar de espacio con
//     un entreno pendiente lo atribuye al espacio equivocado y nadie se entera.
//  2. **Una entrada no se borra por un error.** Solo desaparece del disco tras un 2xx o cuando
//     se borra la cuenta. Un 403, un 422 o un 404 la dejan en estado `failed` con su motivo, a
//     la vista y reintentable a mano. Media hora de la vida de alguien no se tira por un código
//     de estado.
//
//  Como el envío es un upsert por `client_uuid`, reenviar la misma entrada no duplica nada. Eso
//  es lo que permite reintentar sin miedo.
//

import Foundation

// MARK: - Estado de una entrada

public enum OutboxEntryState: String, TrainingCodableEnum {
    /// En cola. Se intenta sola cuando toca.
    case pending
    /// El servidor la rechazó de una forma que no mejora reintentando. Sigue en disco, fuera
    /// del drenaje automático, esperando a que alguien pulse «Retry».
    case failed

    public static var fallback: OutboxEntryState { .pending }
}

// MARK: - Entrada del outbox

public struct OutboxEntry: Codable, Hashable, Identifiable, Sendable {

    /// El id de la entrada es el `client_uuid` del registro: una entrada por sesión, siempre.
    public var id: UUID { payload.clientUUID }

    public private(set) var payload: WorkoutLogSyncRequest
    /// Espacio al que pertenece el entreno. Se fija al encolar y no cambia nunca: es lo que
    /// viaja en `X-Gym-ID` cuando por fin se envía.
    public let gymId: Int
    /// Persona a la que pertenece. Decide en qué carpeta vive el fichero.
    public let userId: Int
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var attemptCount: Int
    public private(set) var lastAttemptAt: Date?
    public private(set) var lastError: String?
    public private(set) var state: OutboxEntryState
    public private(set) var failedAt: Date?
    public private(set) var failureReason: String?
    /// Ya se degradó a entreno libre porque el servidor no reconocía su `day_id`. Solo se hace
    /// una vez: si vuelve a fallar, es otro problema.
    public private(set) var didRetryAsFreeWorkout: Bool

    public enum CodingKeys: String, CodingKey {
        case payload, state
        case gymId = "gym_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case attemptCount = "attempt_count"
        case lastAttemptAt = "last_attempt_at"
        case lastError = "last_error"
        case failedAt = "failed_at"
        case failureReason = "failure_reason"
        case didRetryAsFreeWorkout = "did_retry_as_free_workout"
    }

    public init(payload: WorkoutLogSyncRequest, gymId: Int, userId: Int, createdAt: Date) {
        self.payload = payload
        self.gymId = gymId
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.attemptCount = 0
        self.lastAttemptAt = nil
        self.lastError = nil
        self.state = .pending
        self.failedAt = nil
        self.failureReason = nil
        self.didRetryAsFreeWorkout = false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payload = try container.decode(WorkoutLogSyncRequest.self, forKey: .payload)
        gymId = try container.decode(Int.self, forKey: .gymId)
        userId = try container.decode(Int.self, forKey: .userId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        attemptCount = try container.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
        lastAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        state = try container.decodeIfPresent(OutboxEntryState.self, forKey: .state) ?? .pending
        failedAt = try container.decodeIfPresent(Date.self, forKey: .failedAt)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        didRetryAsFreeWorkout = try container.decodeIfPresent(Bool.self, forKey: .didRetryAsFreeWorkout) ?? false
    }

    // MARK: - Mutación

    /// Sustituye el cuerpo conservando el historial de intentos. Se llama cada vez que el
    /// cliente marca otra serie: la entrada es siempre el estado completo de la sesión.
    ///
    /// Si la entrada estaba en `failed`, volver a tocarla la devuelve a la cola: el cliente ha
    /// seguido entrenando, así que merece otro intento.
    public mutating func update(payload: WorkoutLogSyncRequest, at date: Date) {
        self.payload = payload
        self.updatedAt = date
        if state == .failed { reopenForRetry(at: date) }
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

    /// El servidor la rechazó de una forma que no mejora reintentando. **No se borra**: se
    /// aparta del drenaje automático y se enseña.
    public mutating func markFailed(reason: String, at date: Date) {
        state = .failed
        failureReason = reason
        failedAt = date
        lastError = reason
        updatedAt = date
    }

    /// La devuelve a la cola con el contador a cero, que es lo que hace «Retry».
    public mutating func reopenForRetry(at date: Date) {
        state = .pending
        failureReason = nil
        failedAt = nil
        lastError = nil
        attemptCount = 0
        lastAttemptAt = nil
        updatedAt = date
    }

    /// Degrada el registro a entreno libre.
    ///
    /// Único caso en el que se usa: el servidor devuelve 404 porque el `day_id` ya no existe
    /// (al entrenador le dio por reescribir el día, o la asignación cambió). El entreno es real
    /// y las series son reales; lo único que ha caducado es a qué día del programa colgaban.
    /// Se conserva el título y se sueltan `day_id`, `program_id`, `scheduled_date` y el
    /// `day_exercise_id` de cada serie, que apunta al mismo día que ya no está.
    ///
    /// Devuelve `false` si ya se hizo antes o si no había día al que renunciar.
    @discardableResult
    public mutating func downgradeToFreeWorkout(at date: Date) -> Bool {
        guard !didRetryAsFreeWorkout, payload.dayId != nil || payload.programId != nil else { return false }

        payload = WorkoutLogSyncRequest(
            clientUUID: payload.clientUUID,
            dayId: nil,
            programId: nil,
            scheduledDate: nil,
            title: payload.title,
            status: payload.status,
            startedAt: payload.startedAt,
            completedAt: payload.completedAt,
            sessionRPE: payload.sessionRPE,
            feeling: payload.feeling,
            notes: payload.notes,
            sets: payload.sets.map { set in
                SetLogSyncRequest(
                    clientUUID: set.clientUUID,
                    exerciseKey: set.exerciseKey,
                    exerciseName: set.exerciseName,
                    dayExerciseId: nil,
                    exerciseId: set.exerciseId,
                    orderIndex: set.orderIndex,
                    setNumber: set.setNumber,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    rpe: set.rpe,
                    isWarmup: set.isWarmup,
                    completedAt: set.completedAt
                )
            }
        )
        didRetryAsFreeWorkout = true
        updatedAt = date
        return true
    }

    // MARK: - Derivados

    /// Un cierre de sesión pesa más que un progreso intermedio: se drena antes.
    public var isFinal: Bool { payload.isFinal }

    public var isFailed: Bool { state == .failed }

    /// Nombre del fichero dentro de la carpeta de su usuario.
    public var fileName: String { "\(id.uuidString).json" }

    /// Lo mínimo que la interfaz necesita para enseñar una entrada atascada.
    public var summary: FailedSyncSummary {
        FailedSyncSummary(
            id: id,
            title: payload.title,
            completedAt: payload.completedAt,
            setCount: payload.sets.count,
            reason: failureReason ?? lastError ?? "Could not sync",
            failedAt: failedAt
        )
    }
}

// MARK: - Resumen para la interfaz

public struct FailedSyncSummary: Identifiable, Hashable, Sendable {

    public let id: UUID
    public let title: String
    public let completedAt: Date?
    public let setCount: Int
    public let reason: String
    public let failedAt: Date?

    public init(
        id: UUID,
        title: String,
        completedAt: Date?,
        setCount: Int,
        reason: String,
        failedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.completedAt = completedAt
        self.setCount = setCount
        self.reason = reason
        self.failedAt = failedAt
    }
}

// MARK: - Política de reintento

public struct OutboxRetryPolicy: Hashable, Sendable {

    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let multiplier: Double
    public let maxDelay: TimeInterval

    /// Backoff exponencial con techo de cinco minutos. Ocho intentos cubren más de veinte
    /// minutos sin cobertura; pasado eso, la entrada NO se borra ni se marca fallida: se queda
    /// esperando a que alguien vuelva a abrir la app con red.
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

    /// Una entrada `failed` nunca está lista: sale del drenaje automático hasta que alguien la
    /// reencole a mano.
    public func isReady(_ entry: OutboxEntry, at now: Date) -> Bool {
        guard !entry.isFailed else { return false }
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

    /// Entradas que toca intentar ahora. Las `failed` quedan fuera.
    public static func ready(
        _ entries: [OutboxEntry],
        at now: Date,
        policy: OutboxRetryPolicy = .standard
    ) -> [OutboxEntry] {
        drainOrder(entries).filter { policy.isReady($0, at: now) }
    }

    /// Entradas atascadas, para la lista que enseña la interfaz.
    public static func failed(_ entries: [OutboxEntry]) -> [OutboxEntry] {
        drainOrder(entries).filter(\.isFailed)
    }

    /// Un `client_uuid` válido en el nombre del fichero. Evita que un fichero suelto que alguien
    /// dejó en la carpeta se intente decodificar.
    public static func identifier(fromFileName name: String) -> UUID? {
        guard name.hasSuffix(".json") else { return nil }
        return UUID(uuidString: String(name.dropLast(5)))
    }

    /// Nombre de la carpeta de un usuario dentro de `TrainingOutbox`.
    public static func directoryName(forUserId userId: Int) -> String { "\(userId)" }

    /// Lee el id de usuario de un nombre de carpeta. Nulo si la carpeta no es de nadie.
    public static func userId(fromDirectoryName name: String) -> Int? { Int(name) }
}

// MARK: - Drenaje

/// Qué contesta el servidor a una entrada, traducido a las cuatro cosas que cambian la decisión.
public enum OutboxSendOutcome: Hashable, Sendable {
    /// 2xx. La entrada ya está en el servidor y se puede borrar del disco.
    case success
    /// 404 sobre un `day_id` que el servidor ya no reconoce. El entreno es real; lo caducado es
    /// a qué día del programa colgaba.
    case staleDay(reason: String)
    /// Rechazo definitivo: 403 por módulo apagado o rol, 422 por un cuerpo que no le gusta.
    /// Reintentarlo no lo arregla, pero la sesión NO se tira.
    case rejected(reason: String)
    /// Sin red, 5xx, 408, 429. Vuelve a intentarse solo.
    case transient(reason: String)
}

/// Recorre la cola y decide qué pasa con cada entrada.
///
/// Está aquí y no en el coordinador de la app porque es la parte que se equivoca: el orden, el
/// backoff, cuándo se degrada un registro a entreno libre y cuándo se aparta sin borrarlo. Con
/// el envío y la persistencia inyectados como cierres, todo eso se prueba con `swift test` y sin
/// red, sin servidor y sin simulador.
public struct OutboxDrainer: Sendable {

    public typealias Send = @Sendable (OutboxEntry) async -> OutboxSendOutcome
    public typealias Persist = @Sendable (OutboxEntry) async -> Void
    public typealias Delete = @Sendable (OutboxEntry) async -> Void

    public let policy: OutboxRetryPolicy

    public init(policy: OutboxRetryPolicy = .standard) {
        self.policy = policy
    }

    /// Lo que pasó, para que el coordinador publique estado sin volver a leer el disco.
    public struct Report: Hashable, Sendable {
        public var sentIds: [UUID] = []
        public var failedIds: [UUID] = []
        /// Entradas que llegaron al servidor tras degradarse a entreno libre.
        public var retriedAsFreeWorkoutIds: [UUID] = []
        public var lastError: String?
        /// Se cortó el recorrido porque no hay red: seguir sería gastar backoff en fallos seguros.
        public var stoppedForConnectivity = false

        public init() {}
    }

    /// Drena las entradas ya filtradas y ordenadas (`Outbox.ready`).
    ///
    /// - `send`: hace el `POST /training/logs/sync` de una entrada con SU espacio.
    /// - `persist`: guarda la entrada modificada (intento anotado, degradada o marcada fallida).
    /// - `delete`: la borra del disco. Solo se llama tras un 2xx.
    public func drain(
        _ entries: [OutboxEntry],
        at now: Date,
        send: Send,
        persist: Persist,
        delete: Delete
    ) async -> Report {
        var report = Report()

        for entry in entries {
            if Task.isCancelled { break }
            var current = entry

            switch await send(current) {
            case .success:
                await delete(current)
                report.sentIds.append(current.id)

            case .transient(let reason):
                current.recordAttempt(at: now, error: reason)
                await persist(current)
                report.lastError = reason
                report.stoppedForConnectivity = true
                // Sin red no tiene sentido seguir con el resto de la cola.
                return report

            case .rejected(let reason):
                current.recordAttempt(at: now, error: reason)
                current.markFailed(reason: reason, at: now)
                await persist(current)
                report.failedIds.append(current.id)
                report.lastError = reason

            case .staleDay(let reason):
                current.recordAttempt(at: now, error: reason)
                // Segundo y último intento: el mismo entreno, sin día ni programa.
                guard current.downgradeToFreeWorkout(at: now) else {
                    current.markFailed(reason: reason, at: now)
                    await persist(current)
                    report.failedIds.append(current.id)
                    report.lastError = reason
                    continue
                }
                await persist(current)

                switch await send(current) {
                case .success:
                    await delete(current)
                    report.sentIds.append(current.id)
                    report.retriedAsFreeWorkoutIds.append(current.id)
                case .transient(let secondReason):
                    current.recordAttempt(at: now, error: secondReason)
                    await persist(current)
                    report.lastError = secondReason
                    report.stoppedForConnectivity = true
                    return report
                case .rejected(let secondReason), .staleDay(let secondReason):
                    current.markFailed(reason: secondReason, at: now)
                    await persist(current)
                    report.failedIds.append(current.id)
                    report.lastError = secondReason
                }
            }
        }

        return report
    }
}
