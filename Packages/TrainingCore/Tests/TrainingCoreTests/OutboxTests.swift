//
//  OutboxTests.swift
//  TrainingCoreTests
//
//  Serialización e idempotencia del outbox (plan §4.7).
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Outbox")
struct OutboxTests {

    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static let logUUID = UUID(uuidString: "6F1C0A2E-6C8B-4C6E-9C1E-1E2D3F4A5B6C")!
    static let setUUID = UUID(uuidString: "A91B7D14-2F3C-4D5E-8A9B-0C1D2E3F4A5B")!

    static func payload(status: WorkoutLogStatus = .inProgress, sets: Int = 1) -> WorkoutLogSyncRequest {
        WorkoutLogSyncRequest(
            clientUUID: logUUID,
            dayId: 88,
            programId: 7,
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

    @Test("Una entrada sobrevive al viaje de ida y vuelta por JSON")
    func roundTripJSON() throws {
        var entry = OutboxEntry(payload: Self.payload(), createdAt: Self.start)
        entry.recordAttempt(at: Self.start.addingTimeInterval(5), error: "Could not connect")

        let data = try Outbox.encode(entry)
        let decoded = try Outbox.decode(data)

        #expect(decoded.id == Self.logUUID)
        #expect(decoded.payload.title == "Upper B")
        #expect(decoded.payload.dayId == 88)
        #expect(decoded.payload.scheduledDate == CalendarDate(year: 2026, month: 9, day: 24))
        #expect(decoded.payload.sets.count == 1)
        #expect(decoded.payload.sets[0].clientUUID == Self.setUUID)
        #expect(decoded.payload.sets[0].weightKg == 83.9)
        #expect(decoded.attemptCount == 1)
        #expect(decoded.lastError == "Could not connect")
        #expect(decoded.createdAt.timeIntervalSince1970 == Self.start.timeIntervalSince1970)
    }

    @Test("El JSON usa las claves snake_case del contrato")
    func encodesContractKeys() throws {
        let entry = OutboxEntry(payload: Self.payload(), createdAt: Self.start)
        let data = try Outbox.encode(entry)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.contains("\"client_uuid\""))
        #expect(text.contains("\"day_id\""))
        #expect(text.contains("\"scheduled_date\":\"2026-09-24\""))
        #expect(text.contains("\"session_rpe\""))
        #expect(text.contains("\"is_warmup\""))
        #expect(text.contains("\"set_number\""))
        // Y NO usa camelCase: si esto falla, alguien encendió convertToSnakeCase.
        #expect(text.contains("\"clientUUID\"") == false)
    }

    @Test("Actualizar la entrada conserva el client_uuid y el historial de intentos")
    func updateKeepsIdentityAndAttempts() throws {
        var entry = OutboxEntry(payload: Self.payload(sets: 1), createdAt: Self.start)
        entry.recordAttempt(at: Self.start.addingTimeInterval(10), error: "offline")

        entry.update(payload: Self.payload(status: .completed, sets: 3), at: Self.start.addingTimeInterval(60))

        #expect(entry.id == Self.logUUID)
        #expect(entry.payload.sets.count == 3)
        #expect(entry.payload.sets[0].clientUUID == Self.setUUID)
        #expect(entry.isFinal)
        #expect(entry.attemptCount == 1)
        #expect(entry.createdAt == Self.start)
        #expect(entry.updatedAt == Self.start.addingTimeInterval(60))
    }

    @Test("Reenviar el mismo cuerpo produce exactamente los mismos bytes")
    func idempotentSerialization() throws {
        let first = try Outbox.encode(OutboxEntry(payload: Self.payload(sets: 1), createdAt: Self.start))
        let second = try Outbox.encode(OutboxEntry(payload: Self.payload(sets: 1), createdAt: Self.start))
        #expect(first == second)
    }

    @Test("El nombre del fichero es el client_uuid y se puede leer de vuelta")
    func fileNaming() {
        let entry = OutboxEntry(payload: Self.payload(), createdAt: Self.start)
        #expect(entry.fileName == "\(Self.logUUID.uuidString).json")
        #expect(Outbox.identifier(fromFileName: entry.fileName) == Self.logUUID)
        #expect(Outbox.identifier(fromFileName: "no-soy-un-uuid.json") == nil)
        #expect(Outbox.identifier(fromFileName: "\(Self.logUUID.uuidString).txt") == nil)
    }

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
        var entry = OutboxEntry(payload: Self.payload(), createdAt: Self.start)
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

    @Test("Se drenan antes las sesiones cerradas, y dentro de cada grupo las más antiguas")
    func drainOrder() {
        let older = OutboxEntry(payload: Self.payload(status: .inProgress), createdAt: Self.start)
        var newerFinalPayload = Self.payload(status: .completed)
        newerFinalPayload = WorkoutLogSyncRequest(
            clientUUID: UUID(),
            dayId: newerFinalPayload.dayId,
            programId: newerFinalPayload.programId,
            scheduledDate: newerFinalPayload.scheduledDate,
            title: newerFinalPayload.title,
            status: .completed,
            startedAt: newerFinalPayload.startedAt,
            completedAt: newerFinalPayload.completedAt,
            sets: newerFinalPayload.sets
        )
        let newerFinal = OutboxEntry(payload: newerFinalPayload, createdAt: Self.start.addingTimeInterval(600))

        let ordered = Outbox.drainOrder([older, newerFinal])
        #expect(ordered.first?.id == newerFinal.id)
        #expect(ordered.last?.id == older.id)

        let ready = Outbox.ready([older, newerFinal], at: Self.start.addingTimeInterval(700))
        #expect(ready.count == 2)
    }

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

        let entry = OutboxEntry(payload: session.syncRequest(at: Self.start), createdAt: Self.start)
        let decoded = try Outbox.decode(try Outbox.encode(entry))

        #expect(decoded.id == session.clientUUID)
        #expect(decoded.payload.title == "Free workout")
        #expect(decoded.payload.dayId == nil)
        #expect(decoded.payload.sets.count == 1)
        #expect(decoded.payload.sets[0].reps == 5)
        #expect(decoded.isFinal == false)
    }
}
