//
//  CelebrationTests.swift
//  TrainingCoreTests
//
//  Celebración de marcas por niveles (UX §7) y estado de la fila de serie (UX §5).
//
//  Lo que estos casos protegen: que la app nunca diga «Personal record» de algo que el servidor
//  no ha confirmado, que el nivel suba solo cuando toca, y que las cifras se lean en la unidad
//  del cliente sin decimales inventados.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Celebración de marcas")
struct CelebrationTests {

    // MARK: - Niveles

    @Test("Una marca confirmada normal es nivel 2 y se llama NEW RECORD")
    func confirmedRecordIsLevelTwo() {
        // 86,18 kg son 190 lb y la mejor anterior eran 185: ninguna cifra redonda de por medio.
        let celebration = Celebration.forConfirmedRecord(
            exerciseName: "Bench press",
            weightKg: 86.18,
            reps: 5,
            e1rmKg: 100.5,
            deltaKg: 2.27,
            isFirstRecord: false,
            previousBestKg: 83.9,
            unit: .pounds
        )
        #expect(celebration.level == .record)
        #expect(celebration.title == "NEW RECORD")
        #expect(celebration.isConfirmed)
    }

    @Test("La primera marca de un ejercicio sube a nivel 3 y dice «first record»")
    func firstRecordIsMilestone() {
        let celebration = Celebration.forConfirmedRecord(
            exerciseName: "Deadlift",
            weightKg: 142.9,
            reps: 1,
            e1rmKg: 142.9,
            deltaKg: nil,
            isFirstRecord: true,
            previousBestKg: nil,
            unit: .pounds
        )
        #expect(celebration.level == .milestone)
        #expect(celebration.title == "MILESTONE")
        #expect(celebration.detail?.contains("first record") == true)
        #expect(celebration.level.suggestsSharing)
    }

    @Test("Cruzar una cifra redonda sube a nivel 3 aunque no sea la primera marca")
    func roundNumberIsMilestone() {
        // 102,1 kg son 225 lb; la mejor anterior eran 220 lb.
        let celebration = Celebration.forConfirmedRecord(
            exerciseName: "Back squat",
            weightKg: 102.1,
            reps: 3,
            e1rmKg: 112.3,
            deltaKg: 2.3,
            isFirstRecord: false,
            previousBestKg: 99.8,
            unit: .pounds
        )
        #expect(celebration.level == .milestone)
    }

    @Test("Si ya estaba por encima de la cifra redonda, se queda en nivel 2")
    func alreadyPastMilestoneStaysLevelTwo() {
        let celebration = Celebration.forConfirmedRecord(
            exerciseName: "Back squat",
            weightKg: 106.6,   // 235 lb
            reps: 3,
            e1rmKg: 117.3,
            deltaKg: 2.3,
            isFirstRecord: false,
            previousBestKg: 104.3,  // 230 lb: 225 ya estaba superado
            unit: .pounds
        )
        #expect(celebration.level == .record)
    }

    @Test("Sin saber la marca anterior no se inventa un hito")
    func withoutPreviousBestThereIsNoMilestone() {
        // 83,9 kg son exactamente 185 lb, que es una cifra redonda del catálogo. Sin la marca
        // anterior no hay forma de saber si se acaba de cruzar, así que se queda en nivel 2.
        let celebration = Celebration.forConfirmedRecord(
            exerciseName: "Bench press",
            weightKg: 83.9,
            reps: 5,
            e1rmKg: 97.88,
            deltaKg: 2.3,
            isFirstRecord: false,
            previousBestKg: nil,
            unit: .pounds
        )
        #expect(celebration.level == .record)
        #expect(celebration.title == "NEW RECORD")
    }

    @Test("La mejor serie local es nivel 1 y NUNCA se llama Personal record")
    func localBestIsNeverAPersonalRecord() {
        let best = BestSetSoFar(
            exerciseKey: "barbell_bench_press",
            setNumber: 3,
            reps: 5,
            weightKg: 83.9,
            e1rmKg: 97.88
        )
        let celebration = Celebration.forLocalBestSet(
            exerciseName: "Bench press",
            best: best,
            unit: .pounds
        )
        #expect(celebration.level == .recognition)
        #expect(celebration.isConfirmed == false)
        #expect(celebration.title == "BEST SET SO FAR")
        #expect(celebration.title.lowercased().contains("record") == false)
        #expect(celebration.accessibilityLabel.contains("Personal record") == false)
    }

    @Test("Cada nivel tiene la duración y el adorno de la especificación")
    func levelsMatchTheSpecification() {
        #expect(CelebrationLevel.recognition.durationMilliseconds == 260)
        #expect(CelebrationLevel.record.durationMilliseconds == 900)
        #expect(CelebrationLevel.milestone.durationMilliseconds == 1200)
        #expect(CelebrationLevel.recognition.usesParticles == false)
        #expect(CelebrationLevel.record.particleCount == 12)
        #expect(CelebrationLevel.milestone.particleCount == 12)
        #expect(CelebrationLevel.none.durationMilliseconds == 0)
        #expect(CelebrationLevel.record.suggestsSharing == false)
    }

    // MARK: - Formateo

    @Test("El peso se lee en la unidad del cliente y sin decimales de más")
    func loadTextUsesTheClientUnit() {
        #expect(Celebration.loadText(kilograms: 83.9, unit: .pounds) == "185 lb")
        #expect(Celebration.loadText(kilograms: 100, unit: .kilograms) == "100 kg")
        // 82,5 kg cae en el escalón de 2,5: se lee entero, no «82.5000001».
        #expect(Celebration.loadText(kilograms: 82.5, unit: .kilograms) == "82.5 kg")
    }

    @Test("El delta dice hacia dónde va y en qué unidad")
    func deltaTextSaysTheDirection() {
        #expect(Celebration.deltaText(kilograms: 4.54, unit: .pounds) == "up 10 lb")
        #expect(Celebration.deltaText(kilograms: -2.5, unit: .kilograms) == "down 2.5 kg")
        #expect(Celebration.deltaText(kilograms: 0, unit: .kilograms) == nil)
    }

    @Test("Una serie sin peso se cuenta por repeticiones")
    func bodyweightSetReadsAsReps() {
        let text = Celebration.setText(exerciseName: "Pull-up", weightKg: nil, reps: 12, unit: .pounds)
        #expect(text == "Pull-up · 12 reps")
        let spoken = Celebration.spokenSet(exerciseName: "Pull-up", weightKg: nil, reps: 1, unit: .pounds)
        #expect(spoken == "Pull-up, 1 rep.")
    }

    @Test("La etiqueta hablada lleva unidad y significado")
    func spokenLabelCarriesUnitAndMeaning() {
        let celebration = Celebration.forConfirmedRecord(
            exerciseName: "Bench press",
            weightKg: 86.18,
            reps: 5,
            e1rmKg: 100.5,
            deltaKg: 4.54,
            isFirstRecord: false,
            previousBestKg: 83.9,
            unit: .pounds
        )
        #expect(celebration.accessibilityLabel.hasPrefix("Personal record. Bench press, 190 pounds for 5 reps."))
        #expect(celebration.accessibilityLabel.contains("up 10 lb"))
    }
}

@Suite("Fila de serie")
struct SetRowStateTests {

    private func exercise() -> SessionExercise {
        let day = TrainingDayExercise(
            id: 510,
            dayId: 88,
            exerciseId: 41,
            exerciseKey: "barbell_bench_press",
            exerciseName: "Bench press",
            orderIndex: 0,
            supersetGroup: nil,
            setsCount: 4,
            reps: "5",
            loadMode: .weight,
            loadValue: 83.9,
            rpeTarget: 8,
            restSeconds: 120,
            notes: nil,
            setOverrides: nil,
            lastPerformance: nil
        )
        return SessionExercise(dayExercise: day)
    }

    @Test("La primera serie sin marcar es la activa; las siguientes están pendientes")
    func firstUnmarkedSetIsActive() {
        let exercise = exercise()
        #expect(exercise.rowState(forSetId: exercise.sets[0].id) == .active)
        #expect(exercise.rowState(forSetId: exercise.sets[1].id) == .upcoming)
        #expect(exercise.rowState(forSetId: exercise.sets[3].id) == .upcoming)
    }

    @Test("Al marcar una serie, la activa pasa a la siguiente")
    func markingMovesTheActiveRow() {
        var session = WorkoutSession(
            title: "Upper B",
            programId: 7,
            dayId: 88,
            scheduledDate: nil,
            startedAt: Date(),
            exercises: [exercise()]
        )
        let exerciseId = session.exercises[0].id
        let firstSetId = session.exercises[0].sets[0].id
        session.markSet(exerciseId: exerciseId, setId: firstSetId, at: Date())

        let updated = session.exercises[0]
        #expect(updated.rowState(forSetId: firstSetId) == .done)
        #expect(updated.rowState(forSetId: updated.sets[1].id) == .active)
    }

    @Test("Con todas marcadas no queda ninguna activa")
    func completedExerciseHasNoActiveRow() {
        var session = WorkoutSession(
            title: "Upper B",
            programId: 7,
            dayId: 88,
            scheduledDate: nil,
            startedAt: Date(),
            exercises: [exercise()]
        )
        let exerciseId = session.exercises[0].id
        for set in session.exercises[0].sets {
            session.markSet(exerciseId: exerciseId, setId: set.id, at: Date())
        }
        let updated = session.exercises[0]
        #expect(updated.sets.allSatisfy { updated.rowState(forSetId: $0.id) == .done })
        #expect(updated.isComplete)
    }

    @Test("Cada estado se dice con palabras, no solo con color")
    func everyStateHasWords() {
        #expect(SetRowState.done.spokenState == "Done")
        #expect(SetRowState.active.spokenState == "Up next")
        #expect(SetRowState.upcoming.spokenState == "Not started")
    }

    @Test("La fila se lee con su número, su peso, sus reps y su RPE")
    func rowValueReadsEverything() {
        let exercise = exercise()
        #expect(exercise.rowLabel(forSetNumber: 3) == "Set 3 of 4")
        let value = exercise.rowValue(for: exercise.sets[0], unit: .pounds)
        #expect(value == "185 pounds, 5 reps, RPE not set")
    }

    @Test("Una serie sin carga se lee como peso corporal")
    func bodyweightRowSaysBodyweight() {
        var exercise = exercise()
        exercise.sets[0].weightKg = nil
        exercise.sets[0].rpe = 8
        let value = exercise.rowValue(for: exercise.sets[0], unit: .kilograms)
        #expect(value == "bodyweight, 5 reps, RPE 8")
    }
}
