//
//  OutboxTests.swift
//  TrainingCoreTests
//
//  Serialización, identidad e idempotencia del outbox (plan §4.7) y las reglas de drenaje que
//  la revisión 1 convirtió en obligatorias: cada entrada con su espacio, y nada se borra por un
//  error.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Outbox")
struct OutboxTests {

    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static let logUUID = UUID(uuidString: "6F1C0A2E-6C8B-4C6E-9C1E-1E2D3F4A5B6C")!
    static let setUUID = UUID(uuidString: "A91B7D14-2F3C-4D5E-8A9B-0C1D2E3F4A5B")!

    static func payload(
        clientUUID: UUID = logUUID,
        status: WorkoutLogStatus = .inProgress,
        sets: Int = 1,
        dayId: Int? = 88,
        programId: Int? = 7
    ) -> WorkoutLogSyncRequest {
        WorkoutLogSyncRequest(
            clientUUID: clientUUID,
            dayId: dayId,
            programId: programId,
            scheduledDate: CalendarDate(year: 2026, month: 9, day: 24),
            title: "Upper B",
            status: status,
            startedAt: start,
            completedAt: status == .completed ? start.addingTimeInterval(3130) : nil,
            sessionRPE: 8,
            feeling: 4,
            notes: "Shoulder felt tight on set 3.",
            sets: (0..<sets).map { index in
                SetLogSyncRequest(
                    clientUUID: index == 0 ? setUUID : UUID(),
                    exerciseKey: "barbell_bench_press",
                    exerciseName: "Bench press",
                    dayExerciseId: 510,
                    exerciseId: 41,
                    orderIndex: 0,
                    setNumber: index + 1,
                    reps: 5,
                    weightKg: 83.9,
                    rpe: 8,
                    isWarmup: false,
                    completedAt: start.addingTimeInterval(Double(index) * 120)
                )
            }
        )
    }

    static func entry(
        clientUUID: UUID = logUUID,
        gymId: Int = 12,
        userId: Int = 77,
        status: WorkoutLogStatus = .inProgress,
        dayId: Int? = 88,
        createdAt: Date = start
    ) -> OutboxEntry {
        OutboxEntry(
            payload: payload(clientUUID: clientUUID, status: status, dayId: dayId),
            gymId: gymId,
            userId: userId,
            createdAt: createdAt
        )
    }

    // MARK: - Serialización

    @Test("Una entrada sobrevive al viaje de ida y vuelta por JSON, con su espacio y su dueño")
    func roundTripJSON() throws {
        var entry = Self.entry()
        entry.recordAttempt(at: Self.start.addingTimeInterval(5), error: "Could not connect")

        let data = try Outbox.encode(entry)
        let decoded = try Outbox.decode(data)

        #expect(decoded.id == Self.logUUID)
        // Lo que arregla el P0: la entrada sabe a qué espacio y a quién pertenece.
        #expect(decoded.gymId == 12)
        #expect(decoded.userId == 77)
        #expect(decoded.payload.title == "Upper B")
        #expect(decoded.payload.dayId == 88)
        #expect(decoded.payload.scheduledDate == CalendarDate(year: 2026, month: 9, day: 24))
        #expect(decoded.payload.sets.count == 1)
        #expect(decoded.payload.sets[0].clientUUID == Self.setUUID)
        #expect(decoded.payload.sets[0].weightKg == 83.9)
        #expect(decoded.attemptCount == 1)
        #expect(decoded.lastError == "Could not connect")
        #expect(decoded.state == .pending)
        #expect(decoded.isFailed == false)
        #expect(decoded.didRetryAsFreeWorkout == false)
        #expect(decoded.createdAt.timeIntervalSince1970 == Self.start.timeIntervalSince1970)
    }

    @Test("El JSON usa las claves snake_case del contrato")
    func encodesContractKeys() throws {
        let data = try Outbox.encode(Self.entry())
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.contains("\"client_uuid\""))
        #expect(text.contains("\"gym_id\":12"))
        #expect(text.contains("\"user_id\":77"))
        #expect(text.contains("\"day_id\""))
        #expect(text.contains("\"scheduled_date\":\"2026-09-24\""))
        #expect(text.contains("\"session_rpe\""))
        #expect(text.contains("\"is_warmup\""))
        #expect(text.contains("\"set_number\""))
        // Y NO usa camelCase: si esto falla, alguien encendió convertToSnakeCase.
        #expect(text.contains("\"clientUUID\"") == false)
    }

    @Test("Una entrada fallida guarda su motivo y vuelve así del disco")
    func failedStateSurvivesJSON() throws {
        var entry = Self.entry()
        entry.markFailed(reason: "This is not available in your space", at: Self.start.addingTimeInterval(60))

        let decoded = try Outbox.decode(try Outbox.encode(entry))
        #expect(decoded.isFailed)
        #expect(decoded.state == .failed)
        #expect(decoded.failureReason == "This is not available in your space")
        #expect(decoded.failedAt == Self.start.addingTimeInterval(60))
        #expect(decoded.summary.title == "Upper B")
        #expect(decoded.summary.setCount == 1)
        #expect(decoded.summary.reason == "This is not available in your space")
    }

    @Test("Actualizar la entrada conserva el client_uuid y el historial de intentos")
    func updateKeepsIdentityAndAttempts() throws {
        var entry = Self.entry()
        entry.recordAttempt(at: Self.start.addingTimeInterval(10), error: "offline")

        entry.update(
            payload: Self.payload(status: .completed, sets: 3),
            at: Self.start.addingTimeInterval(60)
        )

        #expect(entry.id == Self.logUUID)
        #expect(entry.gymId == 12)
        #expect(entry.payload.sets.count == 3)
        #expect(entry.payload.sets[0].clientUUID == Self.setUUID)
        #expect(entry.isFinal)
        #expect(entry.attemptCount == 1)
        #expect(entry.createdAt == Self.start)
        #expect(entry.updatedAt == Self.start.addingTimeInterval(60))
    }

    @Test("Seguir entrenando sobre una entrada fallida la devuelve a la cola")
    func updatingAFailedEntryReopensIt() {
        var entry = Self.entry()
        entry.markFailed(reason: "Those values are not valid", at: Self.start)
        #expect(entry.isFailed)

        entry.update(payload: Self.payload(sets: 2), at: Self.start.addingTimeInterval(120))
        #expect(entry.isFailed == false)
        #expect(entry.state == .pending)
        #expect(entry.failureReason == nil)
        #expect(entry.attemptCount == 0)
    }

    @Test("Reenviar el mismo cuerpo produce exactamente los mismos bytes")
    func idempotentSerialization() throws {
        let first = try Outbox.encode(Self.entry())
        let second = try Outbox.encode(Self.entry())
        #expect(first == second)
    }

    @Test("El nombre del fichero es el client_uuid y se puede leer de vuelta")
    func fileNaming() {
        let entry = Self.entry()
        #expect(entry.fileName == "\(Self.logUUID.uuidString).json")
        #expect(Outbox.identifier(fromFileName: entry.fileName) == Self.logUUID)
        #expect(Outbox.identifier(fromFileName: "no-soy-un-uuid.json") == nil)
        #expect(Outbox.identifier(fromFileName: "\(Self.logUUID.uuidString).txt") == nil)
        // Carpeta por usuario, que es lo que aísla los entrenos de dos cuentas en el mismo móvil.
        #expect(Outbox.directoryName(forUserId: 77) == "77")
        #expect(Outbox.userId(fromDirectoryName: "77") == 77)
        #expect(Outbox.userId(fromDirectoryName: "unclaimed") == nil)
    }

    // MARK: - Política

    @Test("El backoff crece y tiene techo")
    func retryBackoff() {
        let policy = OutboxRetryPolicy.standard
        #expect(policy.delay(beforeAttempt: 1) == 0)
        #expect(policy.delay(beforeAttempt: 2) == 2)
        #expect(policy.delay(beforeAttempt: 3) == 4)
        #expect(policy.delay(beforeAttempt: 4) == 8)
        #expect(policy.delay(beforeAttempt: 10) == 300)
    }

    @Test("Una entrada recién fallada espera antes de reintentarse")
    func readyRespectsBackoff() {
        let policy = OutboxRetryPolicy.standard
        var entry = Self.entry()
        #expect(policy.isReady(entry, at: Self.start))

        entry.recordAttempt(at: Self.start, error: "offline")
        #expect(policy.isReady(entry, at: Self.start.addingTimeInterval(1)) == false)
        #expect(policy.isReady(entry, at: Self.start.addingTimeInterval(2)))
        #expect(policy.hasExhaustedAutomaticRetries(entry) == false)

        for attempt in 1..<policy.maxAttempts {
            entry.recordAttempt(at: Self.start.addingTimeInterval(Double(attempt) * 600), error: "offline")
        }
        #expect(policy.hasExhaustedAutomaticRetries(entry))
    }

    @Test("Una entrada fallida nunca está lista ni entra en el drenaje automático")
    func failedEntriesAreExcludedFromDrain() {
        let policy = OutboxRetryPolicy.standard
        var failed = Self.entry()
        failed.markFailed(reason: "Those values are not valid", at: Self.start)
        let pending = Self.entry(clientUUID: UUID())

        #expect(policy.isReady(failed, at: Self.start.addingTimeInterval(10_000)) == false)

        let ready = Outbox.ready([failed, pending], at: Self.start.addingTimeInterval(10_000))
        #expect(ready.map(\.id) == [pending.id])
        #expect(Outbox.failed([failed, pending]).map(\.id) == [failed.id])
    }

    @Test("«Retry» devuelve una entrada fallida a la cola con el contador a cero")
    func reopenForRetry() {
        var entry = Self.entry()
        entry.recordAttempt(at: Self.start, error: "boom")
        entry.markFailed(reason: "boom", at: Self.start)

        entry.reopenForRetry(at: Self.start.addingTimeInterval(600))
        #expect(entry.state == .pending)
        #expect(entry.isFailed == false)
        #expect(entry.attemptCount == 0)
        #expect(entry.lastError == nil)
        #expect(entry.failureReason == nil)
        #expect(OutboxRetryPolicy.standard.isReady(entry, at: Self.start.addingTimeInterval(600)))
    }

    @Test("Se drenan antes las sesiones cerradas, y dentro de cada grupo las más antiguas")
    func drainOrder() {
        let older = Self.entry(clientUUID: UUID(), status: .inProgress, createdAt: Self.start)
        let newerFinal = Self.entry(
            clientUUID: UUID(),
            status: .completed,
            createdAt: Self.start.addingTimeInterval(600)
        )

        let ordered = Outbox.drainOrder([older, newerFinal])
        #expect(ordered.first?.id == newerFinal.id)
        #expect(ordered.last?.id == older.id)

        let ready = Outbox.ready([older, newerFinal], at: Self.start.addingTimeInterval(700))
        #expect(ready.count == 2)
    }

    // MARK: - Degradación a entreno libre

    @Test("Un day_id caducado se suelta y el entreno se conserva entero")
    func downgradeToFreeWorkout() {
        var entry = Self.entry()
        let downgraded = entry.downgradeToFreeWorkout(at: Self.start.addingTimeInterval(30))
        #expect(downgraded)

        #expect(entry.payload.dayId == nil)
        #expect(entry.payload.programId == nil)
        #expect(entry.payload.scheduledDate == nil)
        // El título y las series son reales y se quedan.
        #expect(entry.payload.title == "Upper B")
        #expect(entry.payload.sets.count == 1)
        #expect(entry.payload.sets[0].clientUUID == Self.setUUID)
        #expect(entry.payload.sets[0].weightKg == 83.9)
        // El day_exercise_id apunta al mismo día que ya no existe: también se suelta.
        #expect(entry.payload.sets[0].dayExerciseId == nil)
        #expect(entry.payload.sets[0].exerciseId == 41)
        #expect(entry.didRetryAsFreeWorkout)

        // Solo una vez.
        #expect(entry.downgradeToFreeWorkout(at: Self.start.addingTimeInterval(60)) == false)
    }

    @Test("Un entreno que ya era libre no tiene nada que degradar")
    func freeWorkoutCannotBeDowngraded() {
        var entry = Self.entry(dayId: nil)
        let payloadWithoutProgram = WorkoutLogSyncRequest(
            clientUUID: Self.logUUID,
            dayId: nil,
            programId: nil,
            scheduledDate: nil,
            title: "Free workout",
            status: .completed,
            startedAt: Self.start,
            completedAt: Self.start.addingTimeInterval(600),
            sets: []
        )
        entry.update(payload: payloadWithoutProgram, at: Self.start)
        #expect(entry.downgradeToFreeWorkout(at: Self.start) == false)
    }

    // MARK: - Drenaje

    /// Espía del envío: apunta con qué espacio se manda cada entrada y qué contesta el servidor.
    private actor SendSpy {
        private(set) var sentGymIds: [(UUID, Int)] = []
        private(set) var sentPayloads: [WorkoutLogSyncRequest] = []
        private var outcomes: [OutboxSendOutcome]

        init(outcomes: [OutboxSendOutcome]) { self.outcomes = outcomes }

        func send(_ entry: OutboxEntry) -> OutboxSendOutcome {
            sentGymIds.append((entry.id, entry.gymId))
            sentPayloads.append(entry.payload)
            return outcomes.isEmpty ? .success : outcomes.removeFirst()
        }
    }

    /// Disco de mentira: guarda y borra en memoria.
    private actor FakeStore {
        private(set) var entries: [UUID: OutboxEntry] = [:]
        private(set) var deleted: [UUID] = []

        init(_ initial: [OutboxEntry]) {
            for entry in initial { entries[entry.id] = entry }
        }

        func persist(_ entry: OutboxEntry) { entries[entry.id] = entry }
        func delete(_ entry: OutboxEntry) {
            entries[entry.id] = nil
            deleted.append(entry.id)
        }
        func entry(_ id: UUID) -> OutboxEntry? { entries[id] }
        var count: Int { entries.count }
    }

    @Test("Cada entrada se envía con SU espacio, no con el que esté seleccionado")
    func drainSendsEachEntryWithItsOwnGym() async throws {
        let first = Self.entry(clientUUID: UUID(), gymId: 12, userId: 77)
        let second = Self.entry(clientUUID: UUID(), gymId: 44, userId: 77)
        let spy = SendSpy(outcomes: [.success, .success])
        let store = FakeStore([first, second])

        let report = await OutboxDrainer().drain(
            Outbox.ready([first, second], at: Self.start),
            at: Self.start,
            send: { await spy.send($0) },
            persist: { await store.persist($0) },
            delete: { await store.delete($0) }
        )

        #expect(report.sentIds.count == 2)
        #expect(report.failedIds.isEmpty)
        #expect(report.lastError == nil)

        let sent = await spy.sentGymIds
        #expect(Set(sent.map(\.1)) == [12, 44])
        #expect(sent.first { $0.0 == first.id }?.1 == 12)
        #expect(sent.first { $0.0 == second.id }?.1 == 44)

        // Confirmadas por el servidor: y solo entonces salen del disco.
        let remaining = await store.count
        #expect(remaining == 0)
    }

    @Test("Un rechazo del servidor NO borra la sesión: la aparta y la deja a la vista")
    func rejectedEntryIsKeptAndMarkedFailed() async throws {
        let entry = Self.entry()
        let spy = SendSpy(outcomes: [.rejected(reason: "This is not available in your space")])
        let store = FakeStore([entry])

        let report = await OutboxDrainer().drain(
            [entry],
            at: Self.start,
            send: { await spy.send($0) },
            persist: { await store.persist($0) },
            delete: { await store.delete($0) }
        )

        #expect(report.sentIds.isEmpty)
        #expect(report.failedIds == [entry.id])
        #expect(report.lastError == "This is not available in your space")

        let deleted = await store.deleted
        #expect(deleted.isEmpty)

        let kept = try #require(await store.entry(entry.id))
        #expect(kept.isFailed)
        #expect(kept.failureReason == "This is not available in your space")
        #expect(kept.payload.sets.count == 1)

        // Y no vuelve a intentarse sola por mucho que pase el tiempo.
        let readyLater = Outbox.ready([kept], at: Self.start.addingTimeInterval(86_400))
        #expect(readyLater.isEmpty)
    }

    @Test("Un 404 por day_id caducado se reintenta UNA vez como entreno libre")
    func staleDayIsRetriedAsFreeWorkout() async throws {
        let entry = Self.entry()
        let spy = SendSpy(outcomes: [.staleDay(reason: "Not found"), .success])
        let store = FakeStore([entry])

        let report = await OutboxDrainer().drain(
            [entry],
            at: Self.start,
            send: { await spy.send($0) },
            persist: { await store.persist($0) },
            delete: { await store.delete($0) }
        )

        #expect(report.sentIds == [entry.id])
        #expect(report.retriedAsFreeWorkoutIds == [entry.id])
        #expect(report.failedIds.isEmpty)

        let payloads = await spy.sentPayloads
        #expect(payloads.count == 2)
        // Primer intento: con su día. Segundo: sin él, pero con las mismas series.
        #expect(payloads[0].dayId == 88)
        #expect(payloads[1].dayId == nil)
        #expect(payloads[1].programId == nil)
        #expect(payloads[1].title == "Upper B")
        #expect(payloads[1].sets.count == 1)
        #expect(payloads[1].sets[0].clientUUID == Self.setUUID)

        let remaining = await store.count
        #expect(remaining == 0)
    }

    @Test("Si el reintento como entreno libre también falla, se aparta sin borrarse")
    func staleDayThatKeepsFailingIsMarkedFailed() async throws {
        let entry = Self.entry()
        let spy = SendSpy(outcomes: [
            .staleDay(reason: "Not found"),
            .rejected(reason: "Those values are not valid")
        ])
        let store = FakeStore([entry])

        let report = await OutboxDrainer().drain(
            [entry],
            at: Self.start,
            send: { await spy.send($0) },
            persist: { await store.persist($0) },
            delete: { await store.delete($0) }
        )

        #expect(report.failedIds == [entry.id])
        let deleted = await store.deleted
        #expect(deleted.isEmpty)

        let kept = try #require(await store.entry(entry.id))
        #expect(kept.isFailed)
        #expect(kept.didRetryAsFreeWorkout)
        #expect(kept.payload.sets.count == 1)
    }

    @Test("Sin red se corta el recorrido y no se pierde nada")
    func transientErrorStopsTheDrain() async throws {
        let first = Self.entry(clientUUID: UUID(), createdAt: Self.start)
        let second = Self.entry(clientUUID: UUID(), createdAt: Self.start.addingTimeInterval(60))
        let spy = SendSpy(outcomes: [.transient(reason: "Waiting for a connection")])
        let store = FakeStore([first, second])

        let report = await OutboxDrainer().drain(
            Outbox.ready([first, second], at: Self.start.addingTimeInterval(120)),
            at: Self.start.addingTimeInterval(120),
            send: { await spy.send($0) },
            persist: { await store.persist($0) },
            delete: { await store.delete($0) }
        )

        #expect(report.stoppedForConnectivity)
        #expect(report.sentIds.isEmpty)
        #expect(report.failedIds.isEmpty)
        #expect(report.lastError == "Waiting for a connection")

        // Solo se intentó una; ninguna se borró ni se marcó fallida.
        let sent = await spy.sentGymIds
        #expect(sent.count == 1)
        let remaining = await store.count
        #expect(remaining == 2)
        let attempted = try #require(await store.entry(sent[0].0))
        #expect(attempted.attemptCount == 1)
        #expect(attempted.isFailed == false)
    }

    // MARK: - Desde una sesión real

    @Test("Una sesión real produce la entrada que se guarda en disco")
    func entryFromSession() throws {
        var session = WorkoutSession.freeWorkout(startedAt: Self.start)
        let exerciseId = session.addExercise(
            ExerciseCatalogItem(id: 41, exerciseKey: "barbell_bench_press", name: "Bench press"),
            initialSetCount: 2
        )
        let exercise = try #require(session.exercise(id: exerciseId))
        session.updateSet(exerciseId: exerciseId, setId: exercise.sets[0].id, reps: 5, weightKg: .some(83.9))
        _ = session.markSet(exerciseId: exerciseId, setId: exercise.sets[0].id, at: Self.start.addingTimeInterval(30))

        let entry = OutboxEntry(
            payload: session.syncRequest(at: Self.start),
            gymId: 12,
            userId: 77,
            createdAt: Self.start
        )
        let decoded = try Outbox.decode(try Outbox.encode(entry))

        #expect(decoded.id == session.clientUUID)
        #expect(decoded.gymId == 12)
        #expect(decoded.userId == 77)
        #expect(decoded.payload.title == "Free workout")
        #expect(decoded.payload.dayId == nil)
        #expect(decoded.payload.sets.count == 1)
        #expect(decoded.payload.sets[0].reps == 5)
        #expect(decoded.isFinal == false)
    }
}
