//
//  StaffContractSampleTests.swift
//  TrainingCoreTests
//
//  Las muestras REALES de los endpoints del entrenador (plan §6.2), capturadas en
//  `PLAN_MODULO_ENTRENAMIENTO_REPORTES/contract-samples/`.
//
//  Mismo criterio que `ContractSampleTests`: se decodifica el JSON tal cual, sin normalizar, y se
//  afirma sobre la FORMA. Los valores concretos que sí se fijan son los que codifican una regla
//  del contrato y no el calendario del día en que se sembró la base: los siete días de una semana
//  con huecos, el sobre `{assignments}`, la prescripción que viaja con el registro.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Muestras reales · entrenador")
struct StaffContractSampleTests {

    private static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try ContractSampleTests.decode(type, from: name)
    }

    // MARK: - Programas

    @Test("GET /programs es una lista plana con assigned_count")
    func programs() throws {
        let programs = try Self.decode([TrainingProgram].self, from: "GET_api-v1-training-programs")
        let program = try #require(programs.first)
        #expect(program.name == "Off-season strength")
        #expect(program.durationWeeks == 12)
        #expect(program.status == .active)
        #expect(program.visibility == .private)
        #expect(program.assignedCount == 1)
        #expect(program.focusExerciseKeys.count == 2)
    }

    @Test("GET /programs/{id} trae los bloques embebidos y ningún día")
    func programDetail() throws {
        let detail = try Self.decode(
            TrainingProgramDetail.self,
            from: "GET_api-v1-training-programs-program_id"
        )
        #expect(detail.program.id == 2)
        #expect(detail.program.durationWeeks == 12)
        #expect(detail.blocks.count == 3)
        // Los bloques llegan ordenados por `order_index` y cubren el programa sin solaparse.
        #expect(detail.blocks.map(\.weekStart) == [1, 3, 7])
        #expect(detail.block(forWeek: 4)?.name == "Upper strength")
        #expect(detail.block(forWeek: 12)?.name == "Peak")
    }

    @Test("POST /programs devuelve el programa con su id")
    func createProgram() throws {
        let program = try Self.decode(TrainingProgram.self, from: "POST_api-v1-training-programs")
        #expect(program.id == 3)
        #expect(program.status == .draft)
        #expect(program.visibility == .group)
    }

    @Test("PUT /programs/{id} devuelve el programa actualizado")
    func updateProgram() throws {
        let program = try Self.decode(TrainingProgram.self, from: "PUT_api-v1-training-programs-program_id")
        #expect(program.name == "Off-season strength (2027)")
        #expect(program.goal == "hypertrophy")
    }

    @Test("POST /programs/{id}/duplicate devuelve una copia en borrador")
    func duplicateProgram() throws {
        let program = try Self.decode(
            TrainingProgram.self,
            from: "POST_api-v1-training-programs-program_id-duplicate"
        )
        #expect(program.name.hasSuffix("(copy)"))
        #expect(program.status == .draft)
    }

    @Test("POST /programs/{id}/publish deja el programa activo")
    func publishProgram() throws {
        let program = try Self.decode(
            TrainingProgram.self,
            from: "POST_api-v1-training-programs-program_id-publish"
        )
        #expect(program.status == .active)
    }

    // MARK: - Bloques

    @Test("POST y PUT de bloque devuelven el bloque con su rango")
    func blocks() throws {
        let created = try Self.decode(
            TrainingBlock.self,
            from: "POST_api-v1-training-programs-program_id-blocks"
        )
        #expect(created.name == "Peak")
        #expect(created.weekStart == 7)
        #expect(created.weekEnd == 12)
        #expect(created.weekCount == 6)
        #expect(created.contains(week: 9))

        let updated = try Self.decode(
            TrainingBlock.self,
            from: "PUT_api-v1-training-programs-program_id-blocks-block_id"
        )
        #expect(updated.name == "Base rebuilt")
        #expect(updated.focus == "Volume")
    }

    // MARK: - Días

    @Test("GET /programs/{id}/days devuelve siempre 7 días, con id nulo en los que no existen")
    func programDays() throws {
        let days = try Self.decode([TrainingDay].self, from: "GET_api-v1-training-programs-program_id-days")
        #expect(days.count == 7)
        #expect(days.map(\.dayNumber) == [1, 2, 3, 4, 5, 6, 7])

        // Un `id: null` no rompe la decodificación: se traduce a 0 y `exists` lo delata.
        let missing = days.filter { !$0.exists }
        #expect(missing.count == 3)
        #expect(missing.allSatisfy { $0.isRest && $0.exercises.isEmpty })

        let upperA = try #require(days.first { $0.name == "Upper A" })
        #expect(upperA.exists)
        #expect(upperA.exercises.count == 2)
        // Los dos ejercicios de Upper A son una superserie real: mismo grupo, dos ejercicios.
        #expect(upperA.exercises.allSatisfy { $0.supersetGroup == "A" })

        let upperB = try #require(days.first { $0.name == "Upper B" })
        #expect(upperB.exercises.first?.isAMRAP == true)
        #expect(upperB.exercises.first?.targetReps == nil)
    }

    @Test("PUT /programs/{id}/days/{n} devuelve el día con los ids nuevos")
    func saveDay() throws {
        let day = try Self.decode(
            TrainingDay.self,
            from: "PUT_api-v1-training-programs-program_id-days-day_number"
        )
        #expect(day.id == 34)
        #expect(day.exists)
        #expect(day.dayNumber == 2)
        #expect(day.weekNumber == 1)
        #expect(day.exercises.count == 1)
        #expect(day.exercises.first?.id == 42)
        #expect(day.exercises.first?.dayId == 34)
        #expect(day.plannedSetCount == 3)
    }

    @Test("Duplicar semana y día devuelven copied_days y los destinos")
    func duplicateResults() throws {
        let week = try Self.decode(
            DuplicateResult.self,
            from: "POST_api-v1-training-programs-program_id-weeks-week-duplicate"
        )
        #expect(week.copiedDays == 12)
        #expect(week.targetDayNumbers.count == 12)

        let day = try Self.decode(
            DuplicateResult.self,
            from: "POST_api-v1-training-programs-program_id-days-day_number-duplicate"
        )
        #expect(day.copiedDays == 2)
        #expect(day.targetDayNumbers == [8, 15])
    }

    // MARK: - Asignación

    @Test("POST /assign conserva la envoltura {assignments}")
    func assign() throws {
        let response = try Self.decode(
            AssignmentsResponse.self,
            from: "POST_api-v1-training-programs-program_id-assign"
        )
        #expect(response.assignments.count == 3)
        #expect(response.assignments.allSatisfy { $0.status == .active })
        #expect(response.assignments.allSatisfy { $0.mode == .shared })
        #expect(response.assignments.map(\.userId) == [2, 3, 4])
        // La fecha de inicio es un lunes: lo valida el servidor y lo comprueba la hoja antes de
        // enviarla (plan §4.2).
        #expect(response.assignments.first?.startDate.isMonday == true)
    }

    // MARK: - Ficha del cliente

    @Test("GET /clients/{id}/programs separa el activo de los pasados")
    func clientPrograms() throws {
        let response = try Self.decode(
            ClientProgramsResponse.self,
            from: "GET_api-v1-training-clients-user_id-programs"
        )
        #expect(response.active == nil)
        #expect(response.past.count == 2)
        #expect(response.hasAnyProgram)

        let bootcamp = try #require(response.past.first { $0.program.name == "Spring Bootcamp" })
        #expect(bootcamp.currentWeek == 1)
        #expect(bootcamp.program.visibility == .group)
        #expect(bootcamp.assignment.mode == .shared)
        #expect(bootcamp.assignment.status == .ended)
        let week = try #require(bootcamp.week)
        #expect(week.days.count == 7)
        #expect(week.days.first?.status == .done)
        #expect(week.days.first?.logId == 1)

        // Un programa terminado no trae semana ni adherencia: no hay nada que medir.
        let offSeason = try #require(response.past.first { $0.program.name == "Off-season strength" })
        #expect(offSeason.week == nil)
        #expect(offSeason.adherencePct == nil)
        #expect(offSeason.missedText == nil)
        #expect(!offSeason.isAdherenceLow)
    }

    @Test("GET /clients/{id}/logs trae lo que necesita la lista de revisión")
    func clientLogs() throws {
        let logs = try Self.decode(
            [TrainingWorkoutLogSummary].self,
            from: "GET_api-v1-training-clients-user_id-logs"
        )
        let log = try #require(logs.first)
        #expect(log.id == 1)
        #expect(log.title == "Lower A")
        #expect(log.totalSets == 3)
        #expect(log.prCount == 3)
        #expect(log.reviewedAt == nil)
        #expect(!log.isReviewed)
        #expect(!log.isPartial)
    }

    @Test("GET /clients/{id}/records es idéntico a /me/records")
    func clientRecords() throws {
        let records = try Self.decode(
            [TrainingPersonalRecord].self,
            from: "GET_api-v1-training-clients-user_id-records"
        )
        let record = try #require(records.first)
        #expect(record.exerciseKey == "barbell_back_squat")
        #expect(record.bestE1RMKg == 87.5)
        #expect(record.bestWeightKg == 75)
        #expect(record.bestReps == 5)
        #expect(record.displayName == "Barbell Back Squat")
    }

    @Test("GET /clients/{id}/exercises/{key}/history añade best_sets")
    func clientHistory() throws {
        let history = try Self.decode(
            ExerciseHistory.self,
            from: "GET_api-v1-training-clients-user_id-exercises-exercise_key-history"
        )
        #expect(history.exerciseKey == "barbell_back_squat")
        #expect(history.range == "all")
        #expect(history.points.count == 1)
        #expect(history.points.first?.e1rmKg == 87.5)
        #expect(history.bestSets.count == 1)
        #expect(history.bestSets.first?.isPR == true)
        #expect(history.best?.bestE1RMKg == 87.5)
    }

    @Test("GET /clients/{id}/exercises/{key}/last-performance trae la sugerencia y la serie")
    func clientLastPerformance() throws {
        let performance = try Self.decode(
            ClientLastPerformance.self,
            from: "GET_api-v1-training-clients-user_id-exercises-exercise_key-last-performance"
        )
        #expect(performance.exerciseKey == "barbell_back_squat")
        #expect(performance.weightKg == 75)
        #expect(performance.reps == 5)
        #expect(performance.e1rmKg == 87.5)
        // 75 + 2,5 kg, tal y como lo calcula el servidor; el redondeo al paso de la unidad del
        // cliente lo hace la interfaz.
        #expect(performance.suggestedWeightKg == 77.5)
        #expect(performance.lastSet?.setNumber == 3)
        #expect(performance.hasData)
    }

    // MARK: - Notas del día

    @Test("GET y PUT de day-notes devuelven la nota con su fecha")
    func dayNotes() throws {
        let single = try Self.decode(
            TrainingClientDayNote.self,
            from: "GET_api-v1-training-clients-user_id-day-notes-note_date"
        )
        #expect(single.id == 1)
        #expect(single.date.iso == "2026-09-08")
        #expect(single.authorId == 1)
        #expect(single.dayId == 34)
        #expect(single.isUnread)
        #expect(single.text.count <= TrainingClientDayNote.maxLength)

        let list = try Self.decode(
            [TrainingClientDayNote].self,
            from: "GET_api-v1-training-clients-user_id-day-notes"
        )
        #expect(list.count == 1)

        let saved = try Self.decode(
            TrainingClientDayNote.self,
            from: "PUT_api-v1-training-clients-user_id-day-notes-note_date"
        )
        #expect(saved.text == single.text)
    }

    // MARK: - Buzón y revisión

    @Test("GET /inbox trae el nombre y la foto de quien entrenó")
    func inbox() throws {
        let inbox = try Self.decode([TrainingWorkoutLogSummary].self, from: "GET_api-v1-training-inbox")
        let entry = try #require(inbox.first)
        #expect(entry.userId == 2)
        #expect(entry.userName == "Dana User")
        #expect(entry.reviewedAt == nil)
        #expect(entry.totalVolumeKg == 1050)
        // El cursor de la página siguiente es el id más pequeño de lo que ya se tiene.
        #expect(InboxCursor.next(after: inbox) == entry.id)
        #expect(!InboxCursor.hasMore(page: inbox, limit: 20))
    }

    @Test("POST /logs/{id}/review devuelve el registro con la prescripción")
    func review() throws {
        let log = try Self.decode(
            TrainingWorkoutLog.self,
            from: "POST_api-v1-training-logs-log_id-review"
        )
        #expect(log.id == 1)
        #expect(log.isReviewed)
        #expect(log.coachCongratulated)
        #expect(!log.clientThanked)
        #expect(log.coachComment?.contains("Bar speed") == true)
        #expect(log.sets.count == 1)
        #expect(log.prescription.count == 1)
        #expect(log.prescription.first?.setsCount == 3)
        #expect(log.prescription.first?.loadValue == 60)
        #expect(log.topPersonalRecord?.prKind == .first)
    }

    @Test("GET /logs/{id} trae la prescripción para calcular las desviaciones")
    func logDetailHasPrescription() throws {
        let log = try Self.decode(TrainingWorkoutLog.self, from: "GET_api-v1-training-logs-log_id")
        #expect(log.prescription.count == 1)
        #expect(log.prescription.first?.exerciseKey == "barbell_back_squat")

        // 82,5 kg contra 60 prescritos: por encima, no por debajo. El registro no se marca.
        let reviewed = CoachReview.group(sets: log.sets, prescription: log.prescription)
        #expect(reviewed.count == 1)
        #expect(reviewed.first?.deviationCount == 0)
    }

    // MARK: - Catálogo propio

    @Test("POST /exercises genera la clave g{gym_id}_{slug}")
    func createExercise() throws {
        let item = try Self.decode(ExerciseCatalogItem.self, from: "POST_api-v1-training-exercises")
        #expect(item.id == 4)
        #expect(item.exerciseKey == "g1_sled_push")
        #expect(item.gymId == 1)
        #expect(item.name == "Sled push")
        #expect(item.primaryMuscles == ["quads", "glutes"])
        #expect(item.defaultRestSeconds == 120)
        #expect(item.isActive)
    }

    @Test("PUT /exercises/{id} renombra sin cambiar la clave")
    func updateExercise() throws {
        let item = try Self.decode(ExerciseCatalogItem.self, from: "PUT_api-v1-training-exercises-exercise_id")
        #expect(item.name == "Heavy sled push")
        #expect(item.exerciseKey == "g1_sled_push")
    }
}
