//
//  OutboxFileStoreTests.swift
//  TrainingCoreTests
//
//  El outbox en disco, sobre un directorio temporal.
//
//  Lo que se prueba aquí es lo que la revisión 1 marcó como P0 y P1: que la carpeta de una
//  persona no se toca al borrar la de otra, que cerrar sesión no vacía nada, y que un fichero
//  corrupto no bloquea la cola.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Outbox en disco")
struct OutboxFileStoreTests {

    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    /// Un directorio nuevo por test, borrado al terminar.
    private final class TempRoot {
        let url: URL
        init() {
            url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("TrainingOutboxTests-\(UUID().uuidString)", isDirectory: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }
    }

    private func makeEntry(
        clientUUID: UUID = UUID(),
        gymId: Int,
        userId: Int,
        status: WorkoutLogStatus = .completed,
        title: String = "Upper B",
        createdAt: Date = start
    ) -> OutboxEntry {
        let payload = WorkoutLogSyncRequest(
            clientUUID: clientUUID,
            dayId: 88,
            programId: 7,
            scheduledDate: CalendarDate(year: 2026, month: 9, day: 24),
            title: title,
            status: status,
            startedAt: createdAt,
            completedAt: status == .completed ? createdAt.addingTimeInterval(3130) : nil,
            sets: [
                SetLogSyncRequest(
                    clientUUID: UUID(),
                    exerciseKey: "barbell_bench_press",
                    exerciseName: "Bench press",
                    dayExerciseId: 510,
                    exerciseId: 41,
                    orderIndex: 0,
                    setNumber: 1,
                    reps: 5,
                    weightKg: 83.9,
                    isWarmup: false,
                    completedAt: createdAt
                )
            ]
        )
        return OutboxEntry(payload: payload, gymId: gymId, userId: userId, createdAt: createdAt)
    }

    @Test("Lo escrito vuelve igual, en la carpeta de su usuario")
    func writeAndRead() throws {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)
        let entry = makeEntry(gymId: 12, userId: 77)

        #expect(store.write(entry))

        let path = store.fileURL(id: entry.id, userId: 77).path
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(store.directory(forUserId: 77).lastPathComponent == "77")

        guard case .ok(let read) = store.read(entry.id, userId: 77) else {
            Issue.record("La entrada no volvió del disco")
            return
        }
        #expect(read.id == entry.id)
        #expect(read.gymId == 12)
        #expect(read.userId == 77)
        #expect(read.payload.sets.count == 1)
        #expect(store.all(userId: 77).count == 1)
    }

    @Test("Las entradas de dos cuentas del mismo teléfono no se mezclan")
    func entriesAreScopedByUser() {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)

        let dana = makeEntry(gymId: 12, userId: 77)
        let leo = makeEntry(gymId: 44, userId: 91)
        #expect(store.write(dana))
        #expect(store.write(leo))

        #expect(store.all(userId: 77).map(\.id) == [dana.id])
        #expect(store.all(userId: 91).map(\.id) == [leo.id])
        #expect(store.knownUserIds() == [77, 91])
        // Y cada una conserva su espacio, que es lo que decide el X-Gym-ID al enviarla.
        #expect(store.all(userId: 77).first?.gymId == 12)
        #expect(store.all(userId: 91).first?.gymId == 44)
    }

    @Test("Borrar la cuenta de una persona no vacía la carpeta de la otra")
    func removeAllOnlyTouchesOneUser() {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)

        let dana = makeEntry(gymId: 12, userId: 77)
        let leo = makeEntry(gymId: 44, userId: 91)
        store.write(dana)
        store.write(leo)

        store.removeAll(userId: 77)

        #expect(store.all(userId: 77).isEmpty)
        // El entreno de Leo sigue ahí, entero.
        #expect(store.all(userId: 91).map(\.id) == [leo.id])
        #expect(store.knownUserIds() == [91])
    }

    @Test("Cerrar sesión no borra nada: al volver a entrar el entreno sigue en la cola")
    func logoutKeepsTheQueue() {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)
        let entry = makeEntry(gymId: 12, userId: 77)
        store.write(entry)

        // Cerrar sesión (el coordinador solo limpia memoria) y volver a entrar: nadie tocó el
        // disco, así que la entrada sigue donde estaba.
        let afterRelogin = OutboxFileStore(root: temp.url)
        #expect(afterRelogin.all(userId: 77).map(\.id) == [entry.id])

        // Y otra cuenta que entre en el mismo teléfono no ve nada de la anterior.
        #expect(afterRelogin.all(userId: 91).isEmpty)
    }

    @Test("Borrar una entrada confirmada deja las demás en su sitio")
    func removeOneEntry() {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)
        let first = makeEntry(gymId: 12, userId: 77, createdAt: Self.start)
        let second = makeEntry(gymId: 12, userId: 77, createdAt: Self.start.addingTimeInterval(600))
        store.write(first)
        store.write(second)

        store.remove(first.id, userId: 77)

        #expect(store.all(userId: 77).map(\.id) == [second.id])
        if case .missing = store.read(first.id, userId: 77) {} else {
            Issue.record("La entrada borrada seguía ahí")
        }
    }

    @Test("Un fichero corrupto se retira y no bloquea la cola")
    func corruptFileIsDiscarded() throws {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)
        let good = makeEntry(gymId: 12, userId: 77)
        store.write(good)

        // Un JSON a medias con nombre válido, como el que dejaría un corte de corriente si la
        // escritura no fuera atómica.
        let brokenId = UUID()
        let brokenURL = store.fileURL(id: brokenId, userId: 77)
        try Data("{\"payload\": {".utf8).write(to: brokenURL)

        if case .corrupt = store.read(brokenId, userId: 77) {} else {
            Issue.record("El fichero roto no se detectó")
        }
        #expect(FileManager.default.fileExists(atPath: brokenURL.path) == false)
        // Y la entrada buena sigue drenándose.
        #expect(store.all(userId: 77).map(\.id) == [good.id])
    }

    @Test("Una entrada apartada sigue en disco y fuera del drenaje automático")
    func failedEntryStaysOnDisk() throws {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)
        var entry = makeEntry(gymId: 12, userId: 77)
        entry.markFailed(reason: "This is not available in your space", at: Self.start)
        store.write(entry)

        let all = store.all(userId: 77)
        #expect(all.count == 1)
        #expect(all[0].isFailed)
        #expect(Outbox.ready(all, at: Self.start.addingTimeInterval(86_400)).isEmpty)
        #expect(Outbox.failed(all).count == 1)

        // «Retry» la devuelve a la cola y entonces sí se drena.
        var reopened = try #require(all.first)
        reopened.reopenForRetry(at: Self.start.addingTimeInterval(600))
        store.write(reopened)
        let after = store.all(userId: 77)
        #expect(after[0].isFailed == false)
        #expect(Outbox.ready(after, at: Self.start.addingTimeInterval(600)).count == 1)
    }

    @Test("Se drena antes la sesión cerrada aunque sea más nueva")
    func drainOrderOnDisk() {
        let temp = TempRoot()
        let store = OutboxFileStore(root: temp.url)
        let inProgress = makeEntry(gymId: 12, userId: 77, status: .inProgress, createdAt: Self.start)
        let completed = makeEntry(
            gymId: 12,
            userId: 77,
            status: .completed,
            createdAt: Self.start.addingTimeInterval(600)
        )
        store.write(inProgress)
        store.write(completed)

        #expect(store.all(userId: 77).map(\.id) == [completed.id, inProgress.id])
    }
}
