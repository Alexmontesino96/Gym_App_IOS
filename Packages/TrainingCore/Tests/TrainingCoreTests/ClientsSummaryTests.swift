//
//  ClientsSummaryTests.swift
//  TrainingCoreTests
//
//  El triage del entrenador (visión §8.3): `GET /training/clients/summary`.
//
//  El JSON de `sample` es literalmente el del contrato, copiado sin tocar una coma. Cuando el
//  backend capture su muestra real en `contract-samples/`, este caso seguirá valiendo como
//  «lo que se acordó», que es lo que hace visible una desviación.
//
//  Lo demás que se prueba aquí es lo que ninguna vista puede probar: la traducción de las
//  razones a texto humano, incluidas las que esta versión de la app no conoce.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Resumen de clientes · §8.3")
struct ClientsSummaryTests {

    /// El ejemplo del contrato, tal cual.
    private static let sample = """
    {
      "week_start": "2026-09-07",
      "clients": [
        {
          "user_id": 12, "full_name": "Dana Ruiz", "picture_url": null,
          "joined_at": "2026-08-01T10:00:00Z",
          "program": {"id": 3, "name": "Hypertrophy A", "adherence_pct": 71.4},
          "last_logged_at": "2026-09-06T18:22:00Z",
          "days_silent": 2,
          "this_week": {"planned": 4, "done": 2, "missed": 1, "pending": 1},
          "unreviewed_logs": 1,
          "checkin": {"status": "pending", "week_start": "2026-09-07"},
          "attention": ["missed_1", "checkin_pending", "unreviewed"]
        }
      ]
    }
    """

    private static func decode(_ json: String) throws -> TrainingClientsSummary {
        try TrainingJSON.decoder().decode(TrainingClientsSummary.self, from: Data(json.utf8))
    }

    // MARK: - Decodificación

    @Test("El JSON de ejemplo del contrato decodifica entero")
    func decodesContractSample() throws {
        let summary = try Self.decode(Self.sample)
        #expect(summary.clients.count == 1)

        let dana = try #require(summary.clients.first)
        #expect(dana.userId == 12)
        #expect(dana.id == 12)
        #expect(dana.fullName == "Dana Ruiz")
        #expect(dana.pictureURL == nil)
        #expect(dana.joinedAt != nil)
        #expect(dana.program?.id == 3)
        #expect(dana.program?.name == "Hypertrophy A")
        #expect(dana.program?.adherencePct == 71.4)
        #expect(dana.lastLoggedAt != nil)
        #expect(dana.daysSilent == 2)
        #expect(dana.thisWeek.planned == 4)
        #expect(dana.thisWeek.done == 2)
        #expect(dana.thisWeek.missed == 1)
        #expect(dana.thisWeek.pending == 1)
        #expect(dana.unreviewedLogs == 1)
        #expect(dana.checkin?.status == .pending)
        #expect(dana.checkin?.isSubmitted == false)
        #expect(dana.attention == ["missed_1", "checkin_pending", "unreviewed"])
        #expect(dana.needsAttention)
    }

    @Test("week_start es una fecha simple, no un instante")
    func weekStartIsADate() throws {
        let summary = try Self.decode(Self.sample)
        let weekStart = try #require(summary.weekStart)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(calendar.component(.year, from: weekStart) == 2026)
        #expect(calendar.component(.month, from: weekStart) == 9)
        #expect(calendar.component(.day, from: weekStart) == 7)
    }

    @Test("Un cliente al que le faltan la mitad de los campos no tumba la respuesta")
    func decodesTolerantly() throws {
        let summary = try Self.decode("""
        {"clients": [{"user_id": 9, "full_name": "Sam Lee"}]}
        """)
        let sam = try #require(summary.clients.first)
        #expect(summary.weekStart == nil)
        #expect(sam.program == nil)
        #expect(sam.daysSilent == 0)
        #expect(sam.thisWeek.planned == 0)
        #expect(sam.unreviewedLogs == 0)
        #expect(sam.checkin == nil)
        #expect(sam.attention.isEmpty)
        #expect(!sam.needsAttention)
    }

    @Test("Un estado de check-in desconocido cae en pending, no lanza")
    func unknownCheckinStatusFallsBack() throws {
        let summary = try Self.decode("""
        {"clients": [{"user_id": 1, "full_name": "A B", "checkin": {"status": "skipped"}}]}
        """)
        #expect(summary.clients.first?.checkin?.status == .pending)
    }

    @Test("Sin clientes, la lista está vacía y no hay a quién mirar")
    func emptyResponse() throws {
        let summary = try Self.decode("{\"week_start\": \"2026-09-07\", \"clients\": []}")
        #expect(summary.clients.isEmpty)
        #expect(summary.needingAttention.isEmpty)
    }

    // MARK: - Razones en texto humano

    @Test("Las razones del contrato se traducen a lo que lee el entrenador",
          arguments: [
            ("missed_1", "Missed 1"),
            ("missed_3", "Missed 3"),
            ("silent_5d", "Silent 5 days"),
            ("silent_1d", "Silent 1 day"),
            ("checkin_pending", "Check-in pending"),
            ("unreviewed", "To review"),
            ("no_program", "No program")
          ])
    func humanReasons(raw: String, expected: String) {
        #expect(TrainingAttentionReason.humanText(for: raw) == expected)
    }

    @Test("Una razón que esta versión no conoce se pinta tal cual",
          arguments: ["injury_reported", "silent_", "missed_", "silent_xd", "parq_flagged", ""])
    func unknownReasonsSurviveVerbatim(raw: String) {
        #expect(TrainingAttentionReason.humanText(for: raw) == raw)
    }

    @Test("Las razones se unen con el separador de la interfaz")
    func reasonsJoin() throws {
        let dana = try #require(try Self.decode(Self.sample).clients.first)
        #expect(dana.attentionText == "Missed 1 · Check-in pending · To review")
        #expect(dana.attentionTexts == ["Missed 1", "Check-in pending", "To review"])
    }

    // MARK: - Segunda línea de la fila

    @Test("La línea gris cuenta cuándo entrenó y con qué adherencia")
    func statusLineWithProgram() throws {
        let dana = try #require(try Self.decode(Self.sample).clients.first)
        #expect(dana.statusLine == "Trained 2 days ago · 71% adherence")
    }

    @Test("Hoy y ayer se dicen con palabras, no con números")
    func statusLineToday() {
        let base = TrainingClientProgramRef(id: 1, name: "A", adherencePct: 90)
        let today = TrainingClientSummary(
            userId: 1, fullName: "A B", program: base, lastLoggedAt: Date(), daysSilent: 0
        )
        let yesterday = TrainingClientSummary(
            userId: 2, fullName: "C D", program: base, lastLoggedAt: Date(), daysSilent: 1
        )
        #expect(today.statusLine == "Trained today · 90% adherence")
        #expect(yesterday.statusLine == "Trained yesterday · 90% adherence")
    }

    @Test("A partir de cuatro días la línea deja de contar entrenos y cuenta silencio")
    func statusLineSilent() {
        let client = TrainingClientSummary(
            userId: 3,
            fullName: "Eve Stone",
            program: TrainingClientProgramRef(id: 1, name: "A"),
            lastLoggedAt: Date(),
            daysSilent: 5
        )
        #expect(client.statusLine == "Silent 5 days")
    }

    @Test("Sin programa la línea lo dice y no inventa adherencia")
    func statusLineNoProgram() {
        let client = TrainingClientSummary(userId: 4, fullName: "Ana Ruiz", daysSilent: 12)
        #expect(client.statusLine == "No program yet")
        #expect(client.initials == "AR")
        #expect(client.firstName == "Ana")
    }

    @Test("Con programa pero sin un solo registro, se dice eso y no «trained today»")
    func statusLineNoLogs() {
        let client = TrainingClientSummary(
            userId: 5,
            fullName: "Leo",
            program: TrainingClientProgramRef(id: 1, name: "A", adherencePct: 0),
            daysSilent: 0
        )
        #expect(client.statusLine == "No sessions yet · 0% adherence")
    }

    @Test("El progreso de la semana calla cuando no hay nada planificado")
    func weekProgressText() throws {
        let dana = try #require(try Self.decode(Self.sample).clients.first)
        #expect(dana.thisWeek.progressText == "2 of 4 this week")
        #expect(TrainingClientWeekCounts().progressText == nil)
    }

    @Test("El filtro «needs attention» solo deja a quien tiene razones")
    func needingAttentionFilter() {
        let summary = TrainingClientsSummary(clients: [
            TrainingClientSummary(userId: 1, fullName: "A B", attention: ["unreviewed"]),
            TrainingClientSummary(userId: 2, fullName: "C D"),
            TrainingClientSummary(userId: 3, fullName: "E F", attention: ["no_program"])
        ])
        #expect(summary.needingAttention.map(\.userId) == [1, 3])
        #expect(summary.client(withId: 2)?.fullName == "C D")
        #expect(summary.client(withId: 99) == nil)
    }
}
