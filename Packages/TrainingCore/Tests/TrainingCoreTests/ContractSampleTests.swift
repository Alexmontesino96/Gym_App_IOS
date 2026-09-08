//
//  ContractSampleTests.swift
//  TrainingCoreTests
//
//  Decodifica las respuestas REALES del backend, capturadas en
//  `PLAN_MODULO_ENTRENAMIENTO_REPORTES/contract-samples/`.
//
//  Los fixtures de `TrainingFixtures/` los escribió esta app a partir del plan: prueban que los
//  modelos entienden el contrato **como se documentó**. Estas muestras prueban lo otro, que es lo
//  que rompe en producción: que los modelos entienden lo que el servidor **manda de verdad**.
//  Las diferencias que encontraron (el sobre `{entries}` de strength-summary, `coach_note` como
//  cadena, `client_uuid` que no es un UUID, `last_pr` como fecha) no se habrían visto de otro
//  modo hasta tener la app delante de un backend.
//
//  Las muestras se regeneraron el 7 de septiembre con los decimales ya como números; estos casos
//  decodifican el JSON **tal cual**, sin normalizar nada. Ni los modelos ni `TrainingJSON` aceptan
//  cadenas donde el contrato dice número, y no deben aprender a hacerlo.
//
//  Las aserciones son de FORMA, no de los valores concretos de la base sembrada: las muestras se
//  regeneran y un test que fije «el día 1 es hoy» se pone rojo por el calendario, no por un fallo.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Muestras reales del backend")
struct ContractSampleTests {

    // MARK: - Localización

    /// `<repo padre>/PLAN_MODULO_ENTRENAMIENTO_REPORTES/contract-samples`
    static let directory: URL = {
        // Este fichero vive en
        // <padre>/Gym_API/Packages/TrainingCore/Tests/TrainingCoreTests/ContractSampleTests.swift
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
            .appendingPathComponent("PLAN_MODULO_ENTRENAMIENTO_REPORTES")
            .appendingPathComponent("contract-samples")
    }()

    static func data(_ name: String) throws -> Data {
        let url = directory.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SampleError.missing(url.path)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try TrainingJSON.decoder().decode(type, from: data(name))
    }

    enum SampleError: Error, CustomStringConvertible {
        case missing(String)
        var description: String {
            switch self {
            case .missing(let path): return "Muestra no encontrada: \(path)"
            }
        }
    }

    // MARK: - Cliente (plan §6.1)

    @Test("GET /me/program")
    func meProgram() throws {
        let response = try Self.decode(MyProgramResponse.self, from: "GET_api-v1-training-me-program")
        #expect(response.assignment?.id == 2)
        #expect(response.program?.name == "Spring Bootcamp")
        #expect(response.program?.visibility == .group)
        #expect(response.current?.dayNumber ?? 0 >= 1)
        #expect(response.week?.days.count == 7)
        #expect(response.hasActiveProgram)
    }

    @Test("GET /me/week")
    func meWeek() throws {
        let week = try Self.decode(TrainingWeek.self, from: "GET_api-v1-training-me-week")
        #expect(week.weekNumber == 1)
        #expect(week.days.count == 7)
        // Los días que no existen en base viajan con `day_id: null` y hay que tratarlos como
        // descanso, no como un día que se puede abrir.
        #expect(week.days.contains { $0.dayId == nil })
        #expect(week.days.allSatisfy { $0.dayNumber >= 1 })
    }

    @Test("GET /me/days/{id}")
    func meDay() throws {
        let day = try Self.decode(TrainingDay.self, from: "GET_api-v1-training-me-days-day_id")
        #expect(day.id == 34)
        #expect(day.exercises.count == 1)
        #expect(day.exercises.first?.loadMode == .weight)
        // El backend manda la nota del coach como CADENA, no como el objeto del plan §6.1.
        #expect(day.coachNote?.text.isEmpty == false)
        #expect(day.date != nil)
    }

    @Test("GET /me/today")
    func meToday() throws {
        let day = try Self.decode(TrainingDay.self, from: "GET_api-v1-training-me-today")
        #expect(day.id == 33)
        #expect(day.isRest == false)
        #expect(day.coachNote == nil)
        #expect(day.plannedSetCount == 3)
    }

    @Test("GET /me/logs")
    func meLogs() throws {
        let logs = try Self.decode([TrainingWorkoutLogSummary].self, from: "GET_api-v1-training-me-logs")
        #expect(logs.count == 1)
        #expect(logs.first?.title == "Upper B")
        #expect(logs.first?.prCount == 1)
        // Sin `duration_seconds`: la tarjeta tiene que saber vivir sin ese dato.
        #expect(logs.first?.durationSeconds == nil)
    }

    @Test("GET /logs/{id}")
    func logDetail() throws {
        let log = try Self.decode(TrainingWorkoutLog.self, from: "GET_api-v1-training-logs-log_id")
        #expect(log.id == 1)
        #expect(log.sets.count == 1)
        #expect(log.sets.first?.isPR == true)
        #expect(log.sets.first?.prKind == .first)
        // `client_uuid` NO es un UUID: el servidor devuelve la cadena que le mandó el cliente.
        #expect(log.clientUUID == "scenario-step5-session")
        #expect(log.sets.first?.clientUUID == "scenario-step5-set-1")
    }

    @Test("POST /logs/sync")
    func logSync() throws {
        let log = try Self.decode(TrainingWorkoutLog.self, from: "POST_api-v1-training-logs-sync")
        #expect(log.status == .completed)
        #expect(log.isPartial)
        #expect(log.sets.isEmpty)
    }

    @Test("GET /me/records")
    func meRecords() throws {
        let records = try Self.decode([TrainingPersonalRecord].self, from: "GET_api-v1-training-me-records")
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.exerciseKey == "barbell_back_squat")
        #expect(record.bestReps == 5)
        #expect(record.displayName == "Barbell Back Squat")
    }

    @Test("GET /me/strength-summary llega envuelto en «entries»")
    func meStrengthSummary() throws {
        let response = try Self.decode(
            StrengthSummaryResponse.self,
            from: "GET_api-v1-training-me-strength-summary"
        )
        #expect(response.entries.count == 2)
        let squat = try #require(response.entries.first)
        #expect(squat.exerciseKey == "barbell_back_squat")
        #expect(squat.currentE1RMKg != nil)
        // `points` llega como lista de valores, no de objetos; y `last_pr` como fecha.
        #expect(squat.points.count == 1)
        #expect(squat.lastPRDate != nil)
    }

    @Test("GET /me/exercises/{key}/history")
    func exerciseHistory() throws {
        let history = try Self.decode(
            ExerciseHistory.self,
            from: "GET_api-v1-training-me-exercises-exercise_key-history"
        )
        #expect(history.exerciseKey == "barbell_bench_press")
        #expect(history.points.count == 1)
        // La fecha de un punto llega con HORA; para el eje del gráfico vale el día.
        #expect(history.points.first?.date != nil)
        #expect(history.points.first?.e1rmKg ?? 0 > 0)
        #expect(history.sessions.count == 1)
        #expect(history.sessions.first?.sets.count == 1)
        // El mejor registro viaja en `best`, no en `best_sets`.
        #expect(history.best?.bestReps == 5)
    }

    @Test("GET /exercises con el catálogo vacío")
    func exercises() throws {
        let exercises = try Self.decode([ExerciseCatalogItem].self, from: "GET_api-v1-training-exercises")
        #expect(exercises.isEmpty)
    }

    @Test("GET /programs/{id}/group/today")
    func groupToday() throws {
        let group = try Self.decode(
            GroupToday.self,
            from: "GET_api-v1-training-programs-program_id-group-today"
        )
        #expect(group.trainedCount == 2)
        #expect(group.totalMembers == 3)
        #expect(group.week.count == 7)
        #expect(group.trainedToday.first?.name == "Dana User")
        #expect(group.trainedToday.last?.kudosGiven == true)
    }

    @Test("GET /me/preferences")
    func preferences() throws {
        let preferences = try Self.decode(
            TrainingPreferences.self,
            from: "GET_api-v1-training-me-preferences"
        )
        #expect(preferences.remindersEnabled)
    }

}
