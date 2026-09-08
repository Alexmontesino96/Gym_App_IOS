//
//  StaffRequestBodyTests.swift
//  TrainingCoreTests
//
//  Fija el cuerpo EXACTO que la app del entrenador manda en sus cuatro escrituras.
//
//  Por qué existe: `PUT /programs/{id}/days/{n}` es un reemplazo completo y `POST /assign`
//  valida el lunes en servidor. Un campo con el nombre equivocado no da error de compilación ni
//  de decodificación: da un día sin superserie, o un 422 que solo se ve con el móvil en la mano.
//  Aquí se compara la codificación real con `Resources/TrainingFixtures/staff_requests.json`, que
//  es el mismo fichero que consume la prueba de integración contra el backend local. Si los dos
//  lados hablan del mismo JSON, el circuito cierra.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Cuerpos de escritura del entrenador")
struct StaffRequestBodyTests {

    /// `<repo>/Gym_API/Gym_API/Resources/TrainingFixtures/staff_requests.json`
    private static let fixture: [String: Any] = {
        var url = URL(fileURLWithPath: #filePath)
        // .../Gym_API/Packages/TrainingCore/Tests/TrainingCoreTests/StaffRequestBodyTests.swift
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url = url
            .appendingPathComponent("Gym_API")
            .appendingPathComponent("Resources")
            .appendingPathComponent("TrainingFixtures")
            .appendingPathComponent("staff_requests.json")
        let data = (try? Data(contentsOf: url)) ?? Data()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }()

    private func expected(_ key: String) throws -> [String: Any] {
        try #require(Self.fixture[key] as? [String: Any], "Falta «\(key)» en staff_requests.json")
    }

    private func encoded<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try TrainingJSON.encoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Asignar

    @Test("POST /programs/{id}/assign manda user_ids, un lunes, el modo y replace")
    func assign() throws {
        let body = AssignProgramRequest(
            userIds: [2],
            startDate: CalendarDate(year: 2026, month: 9, day: 28),
            mode: .copy,
            replace: false
        )
        // La fecha que viaja es un lunes: el servidor responde 422 si no lo es (plan §4.2).
        #expect(body.startDate.isMonday)

        let json = try encoded(body)
        let target = try expected("assign")
        #expect(json["user_ids"] as? [Int] == target["user_ids"] as? [Int])
        #expect(json["start_date"] as? String == target["start_date"] as? String)
        #expect(json["mode"] as? String == target["mode"] as? String)
        #expect(json["replace"] as? Bool == target["replace"] as? Bool)
        // La fecha no se convierte en instante: sin hora ni zona no hay lunes que se pierda.
        #expect(json["start_date"] as? String == "2026-09-28")
    }

    @Test("Responder al 409 solo cambia replace")
    func assignReplace() throws {
        let body = AssignProgramRequest(
            userIds: [2],
            startDate: CalendarDate(year: 2026, month: 9, day: 28),
            mode: .copy,
            replace: true
        )
        let json = try encoded(body)
        #expect(json["replace"] as? Bool == true)
        #expect(json["start_date"] as? String == (try expected("assign_replace")["start_date"] as? String))
    }

    // MARK: - Revisión

    @Test("POST /logs/{id}/review manda comentario y felicitación juntos")
    func review() throws {
        let target = try expected("review")
        let body = LogReviewRequest(
            comment: target["comment"] as? String,
            congratulate: true
        )
        let json = try encoded(body)
        #expect(json["comment"] as? String == target["comment"] as? String)
        #expect(json["congratulate"] as? Bool == true)
    }

    @Test("Felicitar sin comentario no manda la clave vacía")
    func congratulateOnly() throws {
        let json = try encoded(LogReviewRequest(comment: nil, congratulate: true))
        // Un `comment: null` reescribiría el comentario anterior a nulo; omitirlo no.
        #expect(json["comment"] == nil)
        #expect(json["congratulate"] as? Bool == true)
    }

    // MARK: - Nota del día

    @Test("PUT /clients/{id}/day-notes/{date} recorta a 280 caracteres")
    func dayNote() throws {
        let target = try expected("day_note")
        let text = try #require(target["text"] as? String)
        let json = try encoded(DayNoteRequest(text: text))
        #expect(json["text"] as? String == text)

        // El contrato son 280; el tipo los impone en el borde, no en la vista.
        let long = String(repeating: "x", count: 400)
        #expect(DayNoteRequest(text: long).text.count == TrainingClientDayNote.maxLength)
    }

    // MARK: - Día completo

    @Test("PUT /programs/{id}/days/{n} manda el día entero, con superserie y AMRAP")
    func dayUpsert() throws {
        let body = DayUpsertRequest(
            name: "Upper B",
            isRest: false,
            isPublished: true,
            exercises: [
                DayExerciseInput(
                    exerciseKey: "barbell_bench_press",
                    exerciseName: "Barbell Bench Press",
                    orderIndex: 9,              // se renumera al construir la petición
                    supersetGroup: "A",
                    setsCount: 4,
                    reps: "5",
                    loadMode: .weight,
                    loadValue: 83.9,
                    rpeTarget: 8,
                    restSeconds: 180,
                    notes: "Strict press."
                ),
                DayExerciseInput(
                    exerciseKey: "pull_up",
                    orderIndex: 3,
                    supersetGroup: "A",
                    setsCount: 4,
                    reps: "AMRAP",
                    loadMode: .bodyweight,
                    restSeconds: 90
                )
            ]
        )

        let json = try encoded(body)
        let target = try expected("day_upsert")

        #expect(json["name"] as? String == "Upper B")
        #expect(json["is_rest"] as? Bool == false)
        #expect(json["is_published"] as? Bool == true)
        // Sin foco ni notas, las claves no viajan: `null` y ausente son lo mismo aquí, y omitir
        // es lo que hace el codificador con un opcional.
        #expect(json["focus"] == nil)
        #expect(json["notes"] == nil)

        let exercises = try #require(json["exercises"] as? [[String: Any]])
        let targetExercises = try #require(target["exercises"] as? [[String: Any]])
        #expect(exercises.count == targetExercises.count)

        // El orden lo renumera `DayUpsertRequest`: lo que se ve es lo que se guarda.
        #expect(exercises.map { $0["order_index"] as? Int } == [0, 1])
        #expect(exercises[0]["exercise_key"] as? String == "barbell_bench_press")
        #expect(exercises[0]["superset_group"] as? String == "A")
        #expect(exercises[0]["load_mode"] as? String == "weight")
        #expect(exercises[0]["load_value"] as? Double == 83.9)
        #expect(exercises[0]["rpe_target"] as? Double == 8)
        #expect(exercises[0]["notes"] as? String == "Strict press.")

        // El de peso corporal no manda carga: `load_value` nulo es lo que espera el contrato.
        #expect(exercises[1]["reps"] as? String == "AMRAP")
        #expect(exercises[1]["load_mode"] as? String == "bodyweight")
        #expect(exercises[1]["load_value"] == nil)
        #expect(exercises[1]["rpe_target"] == nil)
        // El identificador local de la lista NUNCA sale del teléfono.
        #expect(exercises[0]["local_id"] == nil)
        #expect(exercises[0]["localId"] == nil)
        #expect(exercises[0]["id"] == nil)
    }

    @Test("Un día de descanso viaja sin ejercicios aunque la lista tuviera alguno")
    func restDayDropsExercises() throws {
        let body = DayUpsertRequest(
            name: nil,
            isRest: true,
            exercises: []
        )
        let json = try encoded(body)
        #expect(json["is_rest"] as? Bool == true)
        #expect((json["exercises"] as? [[String: Any]])?.isEmpty == true)
        #expect(json["name"] == nil)
    }

    // MARK: - Duplicar

    @Test("POST /weeks/{n}/duplicate ordena las semanas destino")
    func duplicateWeek() throws {
        let body = DuplicateWeekRequest(targetWeeks: [5, 4], keepLoads: true)
        let json = try encoded(body)
        let target = try expected("duplicate_week")
        #expect(json["target_weeks"] as? [Int] == target["target_weeks"] as? [Int])
        #expect(json["keep_loads"] as? Bool == true)
    }
}
