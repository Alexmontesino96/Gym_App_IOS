//
//  FixtureDecodingTests.swift
//  TrainingCoreTests
//
//  Decodificación de los fixtures del contrato (plan §6.4 y §6.5).
//
//  Estos tests son el contrato con el agente de backend: si el servidor cambia una clave, el
//  fixture cambia y esto se pone rojo antes de que nadie abra el simulador.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Fixtures del contrato")
struct FixtureDecodingTests {

    @Test("§6.4 · el cuerpo de POST /logs/sync decodifica entero")
    func decodesSyncRequest() throws {
        let request = try Fixtures.decode(WorkoutLogSyncRequest.self, from: "logs_sync_request")

        #expect(request.clientUUID.uuidString == "6F1C0A2E-6C8B-4C6E-9C1E-1E2D3F4A5B6C")
        #expect(request.dayId == 88)
        #expect(request.programId == 7)
        #expect(request.scheduledDate == CalendarDate(year: 2026, month: 9, day: 24))
        #expect(request.title == "Upper B")
        #expect(request.status == .completed)
        #expect(request.sessionRPE == 8)
        #expect(request.feeling == 4)
        #expect(request.notes == "Shoulder felt tight on set 3.")
        #expect(request.sets.count == 3)
        #expect(request.sets[0].exerciseKey == "barbell_bench_press")
        #expect(request.sets[0].weightKg == 83.9)
        #expect(request.sets[0].isWarmup == false)
        #expect(request.sets[2].rpe == nil)
    }

    @Test("§6.4 · la respuesta trae ids, e1RM y marcas del servidor")
    func decodesSyncResponse() throws {
        let log = try Fixtures.decode(TrainingWorkoutLog.self, from: "logs_sync_response")

        #expect(log.id == 301)
        #expect(log.status == .completed)
        #expect(log.receivedAt != nil)
        #expect(log.totalSets == 3)
        #expect(log.totalVolumeKg == 1451.0)
        #expect(log.prCount == 1)
        #expect(log.isPartial == false)
        #expect(log.isReviewed == false)
        #expect(log.sets.count == 3)

        let record = try #require(log.topPersonalRecord)
        #expect(record.prKind == .e1rm)
        #expect(record.e1rmKg == 97.88)
        #expect(log.personalRecordSets.count == 1)
        // La segunda serie es idéntica pero no es marca: eso lo decidió el servidor, no la app.
        #expect(log.sets[1].isPR == false)
        #expect(log.sets[1].prKind == nil)
    }

    @Test("La app confirma con el servidor lo que ella misma había estimado")
    func localEstimateMatchesServer() throws {
        let log = try Fixtures.decode(TrainingWorkoutLog.self, from: "logs_sync_response")
        let set = try #require(log.sets.first)
        let local = try #require(OneRepMax.estimate(weightKg: set.weightKg, reps: set.reps))
        let server = try #require(set.e1rmKg)
        #expect(abs(local - server) < 0.01)
    }

    @Test("§6.5 · GET /me/program alimenta W4, W6, W8 y el acuse del coach")
    func decodesMyProgram() throws {
        let response = try Fixtures.decode(MyProgramResponse.self, from: "me_program")

        let assignment = try #require(response.assignment)
        #expect(assignment.id == 12)
        #expect(assignment.mode == .copy)
        #expect(assignment.startDate == CalendarDate(year: 2026, month: 9, day: 7))
        #expect(assignment.startDate.isMonday)

        let program = try #require(response.program)
        #expect(program.name == "Off-season strength")
        #expect(program.durationWeeks == 12)
        #expect(program.visibility == .private)
        #expect(program.showsGroupFeatures == false)
        #expect(program.focusExerciseKeys.count == 2)
        #expect(program.totalDays == 84)

        let current = try #require(response.current)
        #expect(current.dayNumber == 18)
        #expect(current.weekNumber == 3)
        #expect(current.block?.name == "Upper strength")
        #expect(response.contextNote == "Upper strength · Week 3")
        #expect(response.hasActiveProgram)

        let week = try #require(response.week)
        #expect(week.days.count == 7)
        #expect(week.progressText == "2 of 5")
        #expect(week.days[0].status == .done)
        #expect(week.days[2].status == .rest)
        #expect(week.days[3].status == .today)
        #expect(week.days[4].status == .pending)
        #expect(response.today?.name == "Upper B")

        // La semana derivada del día coincide con la que manda el servidor.
        #expect(WeekMath.weekNumber(forDayNumber: current.dayNumber) == current.weekNumber)
        // Y la fecha del día 18 desde el lunes de inicio es la que trae el JSON.
        #expect(WeekMath.date(forDayNumber: 18, startDate: assignment.startDate) == week.days[3].date)
    }

    @Test("§6.5 · el acuse del coach lleva nombre, hora y si ya se dieron las gracias")
    func decodesCoachActivity() throws {
        let response = try Fixtures.decode(MyProgramResponse.self, from: "me_program")

        let coach = try #require(response.coach)
        #expect(coach.name == "Marcus Hale")
        #expect(coach.initials == "MH")

        let activity = try #require(response.coachActivity)
        #expect(activity.logId == 301)
        #expect(activity.congratulated)
        #expect(activity.clientThanked == false)
        #expect(activity.canThank)
        #expect(activity.commentFirstLine == "Bar speed held on the last set. Same weight next week.")

        let lastLog = try #require(response.lastLog)
        #expect(lastLog.totalSets == 18)
        #expect(lastLog.isReviewed)
        #expect(lastLog.topPR?.exerciseName == "Bench press")
    }

    @Test("§6.5 · los focus lifts traen la serie de ocho puntos de W6")
    func decodesFocusLifts() throws {
        let response = try Fixtures.decode(MyProgramResponse.self, from: "me_program")
        #expect(response.focusLifts.count == 2)

        let squat = try #require(response.focusLifts.first)
        #expect(squat.exerciseKey == "barbell_back_squat")
        #expect(squat.points.count == 8)
        #expect(squat.hasEnoughDataForChart)
        #expect(squat.currentE1RMKg == 122.0)
        #expect(squat.deltaWeeks == 8)
        #expect(squat.points.first?.date == CalendarDate(year: 2026, month: 8, day: 3))
    }

    @Test("El día trae prescripción, overrides, nota del coach y última ejecución")
    func decodesDay() throws {
        let day = try Fixtures.decode(TrainingDay.self, from: "me_day")

        #expect(day.id == 88)
        #expect(day.dayNumber == 18)
        #expect(day.weekNumber == 3)
        #expect(day.displayName == "Upper B")
        #expect(day.exercises.count == 4)
        #expect(day.plannedSetCount == 14)

        let bench = try #require(day.exercises.first)
        #expect(bench.loadMode == .weight)
        #expect(bench.rpeTarget == 8)
        #expect(bench.supersetGroup == "A")
        #expect(bench.reps(forSet: 1) == "5")
        #expect(bench.reps(forSet: 4) == "AMRAP")
        #expect(bench.restSeconds(forSet: 4) == 180)
        #expect(bench.rpeTarget(forSet: 4) == 9)
        #expect(bench.targetReps == 5)
        #expect(bench.lastPerformance?.suggestedWeightKg == 86.2)

        let note = try #require(day.coachNote)
        #expect(note.author?.name == "Marcus Hale")
        #expect(note.isUnread)
        #expect(note.date == CalendarDate(year: 2026, month: 9, day: 24))

        // Los modos de carga sin peso decodifican con `load_value` nulo.
        #expect(day.exercises[2].loadMode == .rpe)
        #expect(day.exercises[2].loadValue == nil)
        #expect(day.exercises[3].loadMode == .bodyweight)
        #expect(day.exercises[3].isAMRAP)
        #expect(day.exercises[3].targetReps == nil)
    }

    @Test("Las marcas traen su delta y la primera no tiene ninguno")
    func decodesRecords() throws {
        let records = try Fixtures.decode([TrainingPersonalRecord].self, from: "me_records")
        #expect(records.count == 3)

        let bench = try #require(records.first)
        #expect(bench.exerciseKey == "barbell_bench_press")
        #expect(bench.bestE1RMKg == 97.88)
        #expect(bench.deltaKg == 4.5)
        #expect(bench.isFirstRecord == false)
        #expect(bench.coachCongratulated)
        #expect(bench.set?.prKind == .e1rm)

        let deadlift = try #require(records.last)
        #expect(deadlift.isFirstRecord)
        #expect(deadlift.displayName == "Deadlift")
    }

    @Test("«Your group today» no expone ni una cifra de otro cliente")
    func decodesGroupToday() throws {
        let group = try Fixtures.decode(GroupToday.self, from: "group_today")

        #expect(group.trainedCount == 2)
        #expect(group.totalMembers == 3)
        #expect(group.headline == "2 of 3 trained today")
        #expect(group.week.count == 7)
        #expect(group.isNew == false)
        #expect(group.trainedToday.count == 2)
        #expect(group.trainedToday[0].name == "Leo Prieto")
        #expect(group.trainedToday[0].dayName == "Lower A")
        #expect(group.trainedToday[1].kudosGiven)
    }

    @Test("El catálogo distingue ejercicios globales de los del espacio")
    func decodesExerciseCatalog() throws {
        let exercises = try Fixtures.decode([ExerciseCatalogItem].self, from: "exercises")
        #expect(exercises.count == 4)

        let bench = try #require(exercises.first)
        #expect(bench.exerciseKey == "barbell_bench_press")
        #expect(bench.isCustom == false)
        #expect(bench.category == .strength)
        #expect(bench.defaultRestSeconds == 120)
        #expect(bench.primaryMuscles.contains("chest"))

        let sled = try #require(exercises.last)
        #expect(sled.isCustom)
        #expect(sled.gymId == 12)
        #expect(sled.category == .cardio)
    }

    @Test("Un valor de enum que la app no conoce no tumba la pantalla")
    func unknownEnumValueFallsBack() throws {
        let json = Data(#"{"id":1,"exercise_key":"x","name":"X","category":"plyometrics"}"#.utf8)
        let item = try TrainingJSON.decoder().decode(ExerciseCatalogItem.self, from: json)
        #expect(item.category == .other)
    }

    @Test("Un día del programa se convierte en una sesión lista para registrar")
    func dayBecomesSession() throws {
        let day = try Fixtures.decode(TrainingDay.self, from: "me_day")
        let session = WorkoutSession(
            day: day,
            programId: 7,
            scheduledDate: CalendarDate(year: 2026, month: 9, day: 24),
            startedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        #expect(session.exercises.count == 4)
        #expect(session.totalSetCount == 14)
        #expect(session.progressText == "0 of 14 sets")
        #expect(session.exercises[0].sets[0].weightKg == 83.9)
        // El modo `bodyweight` no precarga carga ninguna.
        #expect(session.exercises[3].sets[0].weightKg == nil)
    }
}
