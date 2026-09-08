//
//  WorkoutSessionTests.swift
//  TrainingCoreTests
//
//  Máquina de estados de la sesión (UX §5, pantalla S11).
//
//  Nota de estilo: las llamadas que MUTAN la sesión se sacan fuera de `#expect` y `#require`.
//  Esas macros capturan la expresión en un cierre para poder contar lo que pasó, y un cierre no
//  puede llamar a un método `mutating` de un valor.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Sesión de entrenamiento")
struct WorkoutSessionTests {

    // MARK: - Datos de apoyo

    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    static func bench(sets: Int = 4, rest: Int = 120) -> TrainingDayExercise {
        TrainingDayExercise(
            id: 510,
            exerciseId: 41,
            exerciseKey: "barbell_bench_press",
            exerciseName: "Bench press",
            orderIndex: 0,
            supersetGroup: "A",
            setsCount: sets,
            reps: "5",
            loadMode: .weight,
            loadValue: 83.9,
            rpeTarget: 8,
            restSeconds: rest,
            notes: "Pause one second on the chest.",
            setOverrides: [TrainingSetOverride(setNumber: 4, reps: "AMRAP", rpeTarget: 9, restSeconds: 180)]
        )
    }

    static func row(sets: Int = 4) -> TrainingDayExercise {
        TrainingDayExercise(
            id: 511,
            exerciseId: 58,
            exerciseKey: "cable_row",
            exerciseName: "Cable row",
            orderIndex: 1,
            supersetGroup: "A",
            setsCount: sets,
            reps: "8-10",
            loadMode: .weight,
            loadValue: 61.2,
            restSeconds: 90
        )
    }

    static func day(exercises: [TrainingDayExercise]) -> TrainingDay {
        TrainingDay(id: 88, programId: 7, dayNumber: 18, name: "Upper B", exercises: exercises)
    }

    static func session(exercises: [TrainingDayExercise] = [bench(), row()]) -> WorkoutSession {
        WorkoutSession(
            day: day(exercises: exercises),
            programId: 7,
            scheduledDate: CalendarDate(year: 2026, month: 9, day: 24),
            startedAt: start
        )
    }

    static let catalogSwap = ExerciseCatalogItem(
        id: 62,
        exerciseKey: "dumbbell_incline_press",
        name: "Incline dumbbell press",
        defaultRestSeconds: 90
    )

    // MARK: - Construcción

    @Test("La prescripción se convierte en filas precargadas, overrides incluidos")
    func buildsSetsFromPrescription() throws {
        let session = Self.session()
        let bench = try #require(session.exercises.first)

        #expect(bench.sets.count == 4)
        #expect(bench.sets[0].reps == 5)
        #expect(bench.sets[0].weightKg == 83.9)
        #expect(bench.prescriptionText == "4 × 5 @ RPE 8 · rest 2:00")
        // La cuarta serie es AMRAP y descansa 3 minutos por el override.
        #expect(bench.sets[3].prescribedReps == "AMRAP")
        #expect(bench.sets[3].reps == 0)
        #expect(bench.restSeconds(forSet: 4) == 180)
        #expect(bench.restSeconds(forSet: 1) == 120)
        #expect(session.title == "Upper B")
        #expect(session.isFreeWorkout == false)
    }

    @Test("La sugerencia del servidor gana a la carga prescrita al precargar")
    func lastPerformanceSuggestionWins() throws {
        let exercise = TrainingDayExercise(
            id: 510,
            exerciseKey: "barbell_bench_press",
            exerciseName: "Bench press",
            setsCount: 2,
            reps: "5",
            loadMode: .weight,
            loadValue: nil,
            restSeconds: 120,
            lastPerformance: TrainingLastPerformance(suggestedWeightKg: 86.2)
        )
        let session = Self.session(exercises: [exercise])
        let first = try #require(session.exercises.first?.sets.first)
        #expect(first.weightKg == 86.2)
    }

    // MARK: - Marcar, deshacer, añadir

    @Test("Marcar una serie arranca el descanso y activa la siguiente")
    func markSetAdvances() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)
        let firstSet = try #require(exercise.sets.first)

        let marked = session.markSet(exerciseId: exercise.id, setId: firstSet.id, at: Self.start.addingTimeInterval(60))
        let result = try #require(marked)

        #expect(result.restSeconds == 120)
        #expect(result.nextSetNumber == 2)
        #expect(result.totalSetsInExercise == 4)
        #expect(result.exerciseName == "Bench press")
        #expect(result.announcement == "Set 1 done. Rest 2 minutes.")
        #expect(session.exercises[0].sets[0].isDone)
        #expect(session.exercises[0].sets[0].completedAt == Self.start.addingTimeInterval(60))
        #expect(session.exercises[0].activeSet?.setNumber == 2)
        #expect(session.completedSetCount == 1)
    }

    @Test("Marcar dos veces la misma serie no hace nada")
    func markingTwiceIsIgnored() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)
        let firstSet = try #require(exercise.sets.first)
        _ = session.markSet(exerciseId: exercise.id, setId: firstSet.id, at: Self.start)
        let second = session.markSet(exerciseId: exercise.id, setId: firstSet.id, at: Self.start)
        #expect(second == nil)
        #expect(session.completedSetCount == 1)
    }

    @Test("Deshacer devuelve la serie a pendiente")
    func undoSet() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)
        let firstSet = try #require(exercise.sets.first)
        _ = session.markSet(exerciseId: exercise.id, setId: firstSet.id, at: Self.start)

        let undone = session.undoSet(exerciseId: exercise.id, setId: firstSet.id)
        #expect(undone)
        #expect(session.exercises[0].sets[0].isDone == false)
        #expect(session.exercises[0].sets[0].completedAt == nil)
        #expect(session.completedSetCount == 0)

        // Deshacer algo que no estaba marcado no cambia nada.
        let again = session.undoSet(exerciseId: exercise.id, setId: firstSet.id)
        #expect(again == false)
    }

    @Test("«Add set» copia los valores de la última serie introducida")
    func addSetCopiesLastValues() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)
        session.updateSet(exerciseId: exercise.id, setId: exercise.sets[3].id, reps: 7, weightKg: .some(90))

        let created = session.addSet(toExerciseId: exercise.id)
        let added = try #require(created)
        #expect(added.setNumber == 5)
        #expect(added.reps == 7)
        #expect(added.weightKg == 90)
        #expect(added.isExtra)
        #expect(added.isDone == false)
        #expect(session.exercises[0].sets.count == 5)
        // Añadir series no cambia lo prescrito: el parcial se mide contra el entrenador.
        #expect(session.exercises[0].prescribedSetCount == 4)
    }

    @Test("Quitar una serie renumera las que quedan")
    func removeSetRenumbers() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)
        let removed = session.removeSet(exerciseId: exercise.id, setId: exercise.sets[1].id)
        #expect(removed)
        #expect(session.exercises[0].sets.map(\.setNumber) == [1, 2, 3])
    }

    // MARK: - Progreso

    @Test("El progreso se lee «6 of 18 sets»")
    func progressText() throws {
        var session = Self.session(exercises: [Self.bench(sets: 10), Self.row(sets: 8)])
        #expect(session.totalSetCount == 18)
        #expect(session.progressText == "0 of 18 sets")

        for index in 0..<6 {
            let exercise = session.exercises[0]
            _ = session.markSet(
                exerciseId: exercise.id,
                setId: exercise.sets[index].id,
                at: Self.start.addingTimeInterval(Double(index) * 120)
            )
        }
        #expect(session.progressText == "6 of 18 sets")
        #expect(abs(session.completionRatio - 6.0 / 18.0) < 0.0001)
        // Seis de dieciocho es menos de la mitad: sesión parcial.
        #expect(session.isPartial)
    }

    @Test("Nueve de dieciocho ya no es parcial")
    func halfIsNotPartial() throws {
        var session = Self.session(exercises: [Self.bench(sets: 10), Self.row(sets: 8)])
        for index in 0..<9 {
            let exercise = index < 10 ? session.exercises[0] : session.exercises[1]
            let target = index < 10 ? index : index - 10
            _ = session.markSet(exerciseId: exercise.id, setId: exercise.sets[target].id, at: Self.start)
        }
        #expect(session.completedSetCount == 9)
        #expect(session.isPartial == false)
    }

    // MARK: - Swap

    @Test("Cambiar un ejercicio sin series marcadas lo sustituye en su sitio")
    func swapWithoutCompletedSets() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)

        let swapped = session.swapExercise(exerciseId: exercise.id, with: Self.catalogSwap)
        let newId = try #require(swapped)
        #expect(session.exercises.count == 2)
        #expect(session.exercises[0].id == newId)
        #expect(session.exercises[0].exerciseKey == "dumbbell_incline_press")
        #expect(session.exercises[0].isSwapped)
        #expect(session.exercises[0].sets.count == 4)
        // La carga del movimiento anterior no vale para otro: se limpia.
        let loadsCleared = session.exercises[0].sets.allSatisfy { $0.weightKg == nil }
        #expect(loadsCleared)
    }

    @Test("Cambiar un ejercicio ya empezado conserva las series hechas del original")
    func swapKeepsCompletedSets() throws {
        var session = Self.session()
        let exercise = try #require(session.exercises.first)
        _ = session.markSet(exerciseId: exercise.id, setId: exercise.sets[0].id, at: Self.start)
        _ = session.markSet(exerciseId: exercise.id, setId: exercise.sets[1].id, at: Self.start)

        let swapped = session.swapExercise(exerciseId: exercise.id, with: Self.catalogSwap)
        let newId = try #require(swapped)
        #expect(session.exercises.count == 3)
        #expect(session.exercises[0].exerciseKey == "barbell_bench_press")
        #expect(session.exercises[0].sets.count == 2)
        let keptSetsAreDone = session.exercises[0].sets.allSatisfy(\.isDone)
        #expect(keptSetsAreDone)
        #expect(session.exercises[1].id == newId)
        #expect(session.exercises[1].exerciseKey == "dumbbell_incline_press")
        #expect(session.exercises[1].sets.map(\.setNumber) == [1, 2])
        #expect(session.completedSetCount == 2)
    }

    @Test("Un ejercicio terminado no se puede cambiar: no queda nada que hacer")
    func swapCompletedExerciseIsRefused() throws {
        var session = Self.session(exercises: [Self.bench(sets: 1)])
        let exercise = try #require(session.exercises.first)
        _ = session.markSet(exerciseId: exercise.id, setId: exercise.sets[0].id, at: Self.start)
        let swapped = session.swapExercise(exerciseId: exercise.id, with: Self.catalogSwap)
        #expect(swapped == nil)
    }

    // MARK: - Entreno libre

    @Test("El entreno libre empieza vacío y acepta ejercicios del catálogo")
    func freeWorkout() throws {
        var session = WorkoutSession.freeWorkout(startedAt: Self.start)
        #expect(session.title == "Free workout")
        #expect(session.isFreeWorkout)
        #expect(session.exercises.isEmpty)
        #expect(session.progressText == "0 of 0 sets")
        #expect(session.isPartial == false)

        let id = session.addExercise(Self.catalogSwap, initialSetCount: 3)
        let exercise = try #require(session.exercise(id: id))
        #expect(exercise.sets.count == 3)
        #expect(exercise.prescribedSetCount == 0)
        #expect(exercise.prescriptionText == nil)
        #expect(exercise.isExtra)

        let removed = session.removeExercise(id: id)
        #expect(removed)
        #expect(session.exercises.isEmpty)
    }

    // MARK: - Mejor serie

    @Test("«Best set so far» sale de las series marcadas y no afirma ninguna marca")
    func bestSetSoFar() throws {
        var session = Self.session(exercises: [Self.bench(sets: 3)])
        let exercise = try #require(session.exercises.first)

        session.updateSet(exerciseId: exercise.id, setId: exercise.sets[0].id, reps: 5, weightKg: .some(80))
        session.updateSet(exerciseId: exercise.id, setId: exercise.sets[1].id, reps: 5, weightKg: .some(85))
        session.updateSet(exerciseId: exercise.id, setId: exercise.sets[2].id, reps: 5, weightKg: .some(82.5))

        // Sin marcar no hay nada: una fila tecleada no es una serie hecha.
        #expect(session.bestSetSoFar(forExerciseKey: "barbell_bench_press") == nil)

        let firstMark = session.markSet(exerciseId: exercise.id, setId: exercise.sets[0].id, at: Self.start)
        let first = try #require(firstMark)
        #expect(first.isBestSetSoFar)

        let secondMark = session.markSet(exerciseId: exercise.id, setId: exercise.sets[1].id, at: Self.start)
        let second = try #require(secondMark)
        #expect(second.isBestSetSoFar)

        let thirdMark = session.markSet(exerciseId: exercise.id, setId: exercise.sets[2].id, at: Self.start)
        let third = try #require(thirdMark)
        #expect(third.isBestSetSoFar == false)

        let best = try #require(session.bestSetSoFar(forExerciseKey: "barbell_bench_press"))
        #expect(best.setNumber == 2)
        #expect(best.weightKg == 85)
        #expect(abs((best.e1rmKg ?? 0) - 99.1666) < 0.001)
    }

    @Test("Una serie de calentamiento no puede ser la mejor serie")
    func warmupIsNeverBest() throws {
        var session = Self.session(exercises: [Self.bench(sets: 2)])
        let exercise = try #require(session.exercises.first)
        session.updateSet(
            exerciseId: exercise.id,
            setId: exercise.sets[0].id,
            reps: 5,
            weightKg: .some(200),
            isWarmup: true
        )
        session.updateSet(exerciseId: exercise.id, setId: exercise.sets[1].id, reps: 5, weightKg: .some(80))
        _ = session.markSet(exerciseId: exercise.id, setId: exercise.sets[0].id, at: Self.start)
        _ = session.markSet(exerciseId: exercise.id, setId: exercise.sets[1].id, at: Self.start)

        let best = try #require(session.bestSetSoFar(forExerciseKey: "barbell_bench_press"))
        #expect(best.weightKg == 80)
        // Y el calentamiento tampoco cuenta para el volumen.
        #expect(abs(session.totalVolumeKg - 400) < 0.001)
    }

    // MARK: - Cierre y sincronización

    @Test("El cuerpo de sync solo lleva las series marcadas y conserva los client_uuid")
    func syncRequestOnlyIncludesCompletedSets() throws {
        var session = Self.session(exercises: [Self.bench(sets: 3)])
        let exercise = try #require(session.exercises.first)
        let markedId = exercise.sets[0].id
        _ = session.markSet(exerciseId: exercise.id, setId: markedId, at: Self.start.addingTimeInterval(30))

        let inProgress = session.syncRequest(at: Self.start.addingTimeInterval(60))
        #expect(inProgress.status == .inProgress)
        #expect(inProgress.completedAt == nil)
        #expect(inProgress.sets.count == 1)
        #expect(inProgress.sets[0].clientUUID == markedId)
        #expect(inProgress.sets[0].exerciseKey == "barbell_bench_press")
        #expect(inProgress.clientUUID == session.clientUUID)
        #expect(inProgress.dayId == 88)
        #expect(inProgress.programId == 7)
        #expect(inProgress.scheduledDate == CalendarDate(year: 2026, month: 9, day: 24))

        session.feeling = 4
        session.sessionRPE = 8
        session.finish(at: Self.start.addingTimeInterval(3130))

        let final = session.syncRequest(at: Self.start.addingTimeInterval(3200))
        #expect(final.status == .completed)
        #expect(final.completedAt == Self.start.addingTimeInterval(3130))
        #expect(final.feeling == 4)
        #expect(final.sessionRPE == 8)
        // El identificador del registro y el de la serie no cambian entre envíos: eso es lo que
        // hace idempotente el upsert del servidor.
        #expect(final.clientUUID == inProgress.clientUUID)
        #expect(final.sets[0].clientUUID == markedId)
        #expect(session.durationSeconds(at: Self.start.addingTimeInterval(9999)) == 3130)
    }

    @Test("Los ejercicios de la misma superserie se reconocen entre ellos")
    func supersetPartners() throws {
        let session = Self.session()
        let bench = try #require(session.exercises.first)
        let partners = session.supersetPartners(of: bench.id)
        #expect(partners.count == 1)
        #expect(partners.first?.exerciseKey == "cable_row")
    }
}
