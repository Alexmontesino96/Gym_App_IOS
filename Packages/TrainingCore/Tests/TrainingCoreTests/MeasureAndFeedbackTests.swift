//
//  MeasureAndFeedbackTests.swift
//  TrainingCoreTests
//
//  Series por tiempo y por distancia (contrato §8.1) y feedback por ejercicio (§8.2).
//
//  Lo que se prueba aquí es lo que decide si «Plank 3 × 45s» es una prescripción o son
//  45 repeticiones: la medida viaja con la serie, precarga su objetivo, no cuenta como volumen
//  ni como 1RM, y la desviación del entrenador se calcula contra el objetivo correcto.
//
//  Nota de estilo, como en `WorkoutSessionTests`: las llamadas que MUTAN la sesión se sacan
//  fuera de `#expect` y `#require`.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Medida de la serie y feedback")
struct MeasureAndFeedbackTests {

    // MARK: - Datos de apoyo

    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    static func plank(sets: Int = 3, seconds: Int = 45) -> TrainingDayExercise {
        TrainingDayExercise(
            id: 610,
            exerciseId: 77,
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            orderIndex: 0,
            setsCount: sets,
            reps: "",
            measure: .duration,
            durationSeconds: seconds,
            loadMode: .bodyweight,
            restSeconds: 60,
            setOverrides: [TrainingSetOverride(setNumber: 3, durationSeconds: 60)]
        )
    }

    static func intervals(sets: Int = 4, meters: Double = 400) -> TrainingDayExercise {
        TrainingDayExercise(
            id: 611,
            exerciseId: 78,
            exerciseKey: "run",
            exerciseName: "Run",
            orderIndex: 1,
            setsCount: sets,
            reps: "",
            measure: .distance,
            distanceMeters: meters,
            loadMode: .bodyweight,
            restSeconds: 120
        )
    }

    // MARK: - Enum

    @Test("Una medida que esta versión no conoce se lee como repeticiones")
    func measureFallsBackToReps() throws {
        let json = Data(#"{"measure": "watts"}"#.utf8)
        struct Wrapper: Decodable { let measure: TrainingMeasure }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(decoded.measure == .reps)
    }

    @Test("Un ejercicio de cardio del catálogo entra midiéndose en tiempo")
    func cardioDefaultsToDuration() {
        #expect(TrainingMeasure.default(for: .cardio) == .duration)
        #expect(TrainingMeasure.default(for: .strength) == .reps)
        #expect(TrainingMeasure.default(for: .mobility) == .reps)
    }

    @Test("Un flag de feedback desconocido no tumba la pantalla ni se ofrece")
    func feedbackFlagFallsBack() throws {
        let json = Data(#"{"exercise_key": "front_plank", "flag": "nauseous", "note": null}"#.utf8)
        let decoded = try JSONDecoder().decode(TrainingExerciseFeedback.self, from: json)
        #expect(decoded.flag == .unknown)
        #expect(TrainingFeedbackFlag.selectable.contains(.unknown) == false)
        #expect(TrainingFeedbackFlag.selectable.count == 4)
    }

    // MARK: - Prescripción

    @Test("El día trae la medida, el objetivo y su override por serie")
    func dayExerciseCarriesMeasure() throws {
        let json = Data("""
        {
          "id": 610,
          "exercise_key": "front_plank",
          "exercise_name": "Plank",
          "sets_count": 3,
          "reps": "",
          "measure": "duration",
          "duration_seconds": 45,
          "distance_m": null,
          "load_mode": "bodyweight",
          "rest_seconds": 60,
          "set_overrides": [{"set_number": 3, "duration_seconds": 60}]
        }
        """.utf8)

        let exercise = try JSONDecoder().decode(TrainingDayExercise.self, from: json)
        #expect(exercise.measure == .duration)
        #expect(exercise.durationSeconds == 45)
        #expect(exercise.durationSeconds(forSet: 1) == 45)
        #expect(exercise.durationSeconds(forSet: 3) == 60)
        // La distancia no existe en un ejercicio por tiempo, aunque el override la trajera.
        #expect(exercise.distanceMeters(forSet: 1) == nil)
    }

    @Test("Sin el campo, un ejercicio existente sigue siendo de repeticiones")
    func missingMeasureIsReps() throws {
        let json = Data(#"{"id": 1, "exercise_key": "squat", "exercise_name": "Squat", "reps": "5"}"#.utf8)
        let exercise = try JSONDecoder().decode(TrainingDayExercise.self, from: json)
        #expect(exercise.measure == .reps)
        #expect(exercise.durationSeconds(forSet: 1) == nil)
    }

    // MARK: - Sesión

    @Test("Una serie por tiempo precarga su objetivo y no lleva repeticiones")
    func durationSetPreloadsTarget() throws {
        let exercise = SessionExercise(dayExercise: Self.plank())
        #expect(exercise.measure == .duration)
        #expect(exercise.sets.count == 3)
        #expect(exercise.sets[0].durationSeconds == 45)
        #expect(exercise.sets[0].reps == 0)
        // El override de la tercera serie manda sobre el objetivo del ejercicio.
        #expect(exercise.sets[2].durationSeconds == 60)
        #expect(exercise.prescriptionText == "3 × 45s · rest 1:00")
    }

    @Test("Una serie por distancia precarga sus metros")
    func distanceSetPreloadsTarget() throws {
        let exercise = SessionExercise(dayExercise: Self.intervals())
        #expect(exercise.measure == .distance)
        #expect(exercise.sets[0].distanceMeters == 400)
        #expect(exercise.sets[0].durationSeconds == nil)
        #expect(exercise.prescriptionText == "4 × 400 m · rest 2:00")
    }

    @Test("Volumen y 1RM estimado solo existen para repeticiones")
    func volumeIgnoresTimedWork() throws {
        var carry = SessionExercise(dayExercise: TrainingDayExercise(
            id: 612,
            exerciseKey: "farmer_carry",
            exerciseName: "Farmer carry",
            setsCount: 2,
            reps: "",
            measure: .duration,
            durationSeconds: 40,
            loadMode: .weight,
            loadValue: 32
        ))
        // Un farmer carry tiene tiempo Y carga: la carga se precarga igual.
        #expect(carry.sets[0].weightKg == 32)
        #expect(carry.volumeKg == 0)
        #expect(carry.sets[0].estimatedOneRepMaxKg == nil)

        carry.measure = .reps
        carry.sets[0].reps = 10
        #expect(carry.volumeKg == 320)
    }

    @Test("Una serie por tiempo nunca es «best set so far»")
    func timedSetIsNeverBestSet() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let exercise = try #require(session.exercises.first)
        session.markSet(exerciseId: exercise.id, setId: exercise.sets[0].id, at: Self.start)
        #expect(session.bestSetSoFar(forExerciseKey: "front_plank") == nil)
        #expect(session.totalVolumeKg == 0)
    }

    @Test("El tiempo marcado se suma para el resumen de la sesión")
    func completedDurationAddsUp() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let exercise = try #require(session.exercises.first)
        session.markSet(exerciseId: exercise.id, setId: exercise.sets[0].id, at: Self.start)
        session.markSet(exerciseId: exercise.id, setId: exercise.sets[2].id, at: Self.start)
        // 45 de la primera + 60 del override de la tercera. La segunda no se marcó.
        #expect(session.completedDurationSeconds == 105)
    }

    @Test("Editar una serie por tiempo cambia los segundos, no las repeticiones")
    func updateDurationSet() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let exercise = try #require(session.exercises.first)
        session.updateSet(exerciseId: exercise.id, setId: exercise.sets[0].id, durationSeconds: .some(52))
        #expect(session.exercises[0].sets[0].durationSeconds == 52)
        #expect(session.exercises[0].sets[0].reps == 0)
    }

    // MARK: - Cuerpo de sincronización

    @Test("Cada serie viaja con su medida y con reps a cero fuera de reps")
    func syncRequestCarriesMeasure() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank(), Self.intervals()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let plank = try #require(session.exercises.first)
        let run = try #require(session.exercises.last)
        session.markSet(exerciseId: plank.id, setId: plank.sets[0].id, at: Self.start)
        session.markSet(exerciseId: run.id, setId: run.sets[0].id, at: Self.start)

        let request = session.syncRequest(at: Self.start)
        let encoded = try JSONSerialization.jsonObject(
            with: try TrainingJSON.encoder().encode(request)
        ) as? [String: Any]
        let sets = try #require(encoded?["sets"] as? [[String: Any]])

        #expect(sets.count == 2)
        #expect(sets[0]["measure"] as? String == "duration")
        #expect(sets[0]["duration_seconds"] as? Int == 45)
        #expect(sets[0]["reps"] as? Int == 0)
        #expect(sets[0]["distance_m"] == nil)
        #expect(sets[1]["measure"] as? String == "distance")
        #expect(sets[1]["distance_m"] as? Double == 400)
        #expect(sets[1]["duration_seconds"] == nil)
    }

    @Test("El feedback del ejercicio viaja entero y reemplaza al anterior")
    func syncRequestCarriesFeedback() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank(), Self.intervals()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let plank = try #require(session.exercises.first)

        session.setFeedback(exerciseId: plank.id, flag: .pain, note: "  Right shoulder.  ")
        #expect(session.exerciseFeedback.count == 1)
        #expect(session.exerciseFeedback[0].exerciseKey == "front_plank")
        #expect(session.exerciseFeedback[0].note == "Right shoulder.")

        let encoded = try JSONSerialization.jsonObject(
            with: try TrainingJSON.encoder().encode(session.syncRequest(at: Self.start))
        ) as? [String: Any]
        let feedback = try #require(encoded?["exercise_feedback"] as? [[String: Any]])
        #expect(feedback.count == 1)
        #expect(feedback[0]["exercise_key"] as? String == "front_plank")
        #expect(feedback[0]["flag"] as? String == "pain")
        #expect(feedback[0]["note"] as? String == "Right shoulder.")

        // Quitar el flag borra la respuesta entera: una nota huérfana no la admite el contrato.
        session.setFeedback(exerciseId: plank.id, flag: nil)
        #expect(session.exerciseFeedback.isEmpty)
    }

    @Test("La nota del feedback se recorta a 280 caracteres")
    func feedbackNoteIsCapped() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let plank = try #require(session.exercises.first)
        session.setFeedback(exerciseId: plank.id, flag: .tooHard, note: String(repeating: "a", count: 400))
        #expect(session.exerciseFeedback[0].note?.count == 280)
    }

    @Test("Degradar a entreno libre conserva la medida y el feedback")
    func downgradeKeepsMeasureAndFeedback() throws {
        let day = TrainingDay(id: 88, programId: 7, dayNumber: 18, exercises: [Self.plank()])
        var session = WorkoutSession(day: day, programId: 7, scheduledDate: nil, startedAt: Self.start)
        let plank = try #require(session.exercises.first)
        session.markSet(exerciseId: plank.id, setId: plank.sets[0].id, at: Self.start)
        session.setFeedback(exerciseId: plank.id, flag: .tooEasy)

        var entry = OutboxEntry(
            payload: session.syncRequest(at: Self.start),
            gymId: 5,
            userId: 12,
            createdAt: Self.start
        )
        #expect(entry.downgradeToFreeWorkout(at: Self.start) == true)
        #expect(entry.payload.sets[0].measure == .duration)
        #expect(entry.payload.sets[0].durationSeconds == 45)
        #expect(entry.payload.exerciseFeedback.first?.flag == .tooEasy)
    }

    @Test("Una entrada encolada antes de este campo se sigue leyendo")
    func legacyOutboxPayloadStillDecodes() throws {
        let json = Data("""
        {
          "client_uuid": "6C7E0B3E-6C4A-4E3E-9C2E-000000000001",
          "title": "Upper B",
          "status": "completed",
          "started_at": "2026-09-24T17:00:00Z",
          "sets": [
            {
              "client_uuid": "6C7E0B3E-6C4A-4E3E-9C2E-000000000002",
              "exercise_key": "barbell_bench_press",
              "order_index": 0,
              "set_number": 1,
              "reps": 5,
              "weight_kg": 83.9,
              "is_warmup": false,
              "completed_at": "2026-09-24T17:12:00Z"
            }
          ]
        }
        """.utf8)

        let payload = try TrainingJSON.decoder().decode(WorkoutLogSyncRequest.self, from: json)
        #expect(payload.sets.count == 1)
        #expect(payload.sets[0].measure == .reps)
        #expect(payload.sets[0].reps == 5)
        #expect(payload.exerciseFeedback.isEmpty)
    }

    // MARK: - Escritura del entrenador

    @Test("El día que escribe el entrenador manda la medida y su objetivo")
    func dayUpsertCarriesMeasure() throws {
        let body = DayUpsertRequest(
            name: "Conditioning",
            isRest: false,
            exercises: [
                DayExerciseInput(
                    exerciseKey: "front_plank",
                    exerciseName: "Plank",
                    setsCount: 3,
                    reps: "",
                    measure: .duration,
                    durationSeconds: 45,
                    loadMode: .bodyweight,
                    restSeconds: 60,
                    setOverrides: [TrainingSetOverride(setNumber: 3, durationSeconds: 60)]
                ),
                DayExerciseInput(
                    exerciseKey: "run",
                    exerciseName: "Run",
                    setsCount: 4,
                    reps: "",
                    measure: .distance,
                    distanceMeters: 400,
                    loadMode: .bodyweight,
                    restSeconds: 120
                )
            ]
        )

        let encoded = try JSONSerialization.jsonObject(
            with: try TrainingJSON.encoder().encode(body)
        ) as? [String: Any]
        let exercises = try #require(encoded?["exercises"] as? [[String: Any]])

        #expect(exercises[0]["measure"] as? String == "duration")
        #expect(exercises[0]["duration_seconds"] as? Int == 45)
        #expect(exercises[0]["distance_m"] == nil)
        let overrides = try #require(exercises[0]["set_overrides"] as? [[String: Any]])
        #expect(overrides[0]["duration_seconds"] as? Int == 60)
        #expect(exercises[1]["measure"] as? String == "distance")
        #expect(exercises[1]["distance_m"] as? Double == 400)
    }

    @Test("Lo que se lee del día es lo que se vuelve a escribir")
    func dayExerciseInputRoundTrip() {
        let input = DayExerciseInput(from: Self.plank())
        #expect(input.measure == .duration)
        #expect(input.durationSeconds == 45)
        #expect(input.setOverrides?.first?.durationSeconds == 60)

        let preview = input.previewExercise()
        #expect(preview.measure == .duration)
        #expect(preview.durationSeconds(forSet: 3) == 60)
    }

    // MARK: - Revisión del entrenador

    @Test("Menos tiempo del prescrito se marca «below time» con su objetivo")
    func belowTimeDeviation() {
        let prescription = Self.plank()
        let short = TrainingSetLog(
            clientUUID: "s1",
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            setNumber: 1,
            reps: 0,
            measure: .duration,
            durationSeconds: 30
        )
        let onTarget = TrainingSetLog(
            clientUUID: "s2",
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            setNumber: 2,
            reps: 0,
            measure: .duration,
            durationSeconds: 45
        )

        #expect(CoachReview.evaluate(set: short, prescription: prescription).deviation == .belowTime)
        #expect(CoachReview.evaluate(set: short, prescription: prescription).targetValue == 45)
        #expect(CoachReview.evaluate(set: onTarget, prescription: prescription).deviation == nil)
    }

    @Test("Un segundo de menos es redondeo, no una desviación")
    func durationToleranceHoldsTheNoise() {
        let almost = TrainingSetLog(
            clientUUID: "s3",
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            setNumber: 1,
            reps: 0,
            measure: .duration,
            durationSeconds: 44
        )
        #expect(CoachReview.evaluate(set: almost, prescription: Self.plank()).deviation == nil)
    }

    @Test("Menos distancia de la prescrita se marca «below distance»")
    func belowDistanceDeviation() {
        let short = TrainingSetLog(
            clientUUID: "s4",
            exerciseKey: "run",
            exerciseName: "Run",
            setNumber: 1,
            reps: 0,
            measure: .distance,
            distanceMeters: 300
        )
        let reviewed = CoachReview.evaluate(set: short, prescription: Self.intervals())
        #expect(reviewed.deviation == .belowDistance)
        #expect(reviewed.targetValue == 400)
        #expect(reviewed.deviation?.spoken(target: "400 meters") == "Below the prescribed 400 meters.")
    }

    @Test("Un ejercicio por tiempo no se acusa nunca de quedarse corto de repeticiones")
    func timedExerciseIsNeverBelowReps() {
        let set = TrainingSetLog(
            clientUUID: "s5",
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            setNumber: 1,
            reps: 0,
            measure: .duration,
            durationSeconds: 60
        )
        // La prescripción dice «5» en `reps` porque el campo sigue existiendo; con `duration`
        // ese texto se ignora.
        var prescription = Self.plank()
        prescription = TrainingDayExercise(
            id: prescription.id,
            exerciseKey: prescription.exerciseKey,
            exerciseName: prescription.exerciseName,
            setsCount: prescription.setsCount,
            reps: "5",
            measure: .duration,
            durationSeconds: 45,
            loadMode: .bodyweight
        )
        #expect(CoachReview.evaluate(set: set, prescription: prescription).deviation == nil)
    }

    @Test("El RPE sigue mandando sobre la medida: primero el esfuerzo")
    func rpeStillWinsOverMeasure() {
        let prescription = TrainingDayExercise(
            id: 613,
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            setsCount: 3,
            reps: "",
            measure: .duration,
            durationSeconds: 45,
            loadMode: .bodyweight,
            rpeTarget: 8
        )
        let set = TrainingSetLog(
            clientUUID: "s6",
            exerciseKey: "front_plank",
            exerciseName: "Plank",
            setNumber: 1,
            reps: 0,
            measure: .duration,
            durationSeconds: 20,
            rpe: 10
        )
        #expect(CoachReview.evaluate(set: set, prescription: prescription).deviation == .aboveTarget)
    }

    // MARK: - Formato

    @Test("El campo de tiempo es mm:ss y la prescripción se lee «45s»")
    func durationFormats() {
        #expect(Celebration.durationText(45) == "0:45")
        #expect(Celebration.durationText(90) == "1:30")
        #expect(Celebration.durationText(-10) == "0:00")
        #expect(Celebration.compactDurationText(45) == "45s")
        #expect(Celebration.compactDurationText(60) == "1:00")
        #expect(Celebration.spokenDuration(45) == "45 seconds")
        #expect(Celebration.spokenDuration(90) == "1 minute 30 seconds")
        #expect(Celebration.spokenDuration(120) == "2 minutes")
    }

    @Test("La distancia pasa a kilómetros a partir de mil metros")
    func distanceFormats() {
        #expect(Celebration.distanceText(meters: 400) == "400 m")
        #expect(Celebration.distanceText(meters: 999) == "999 m")
        #expect(Celebration.distanceText(meters: 1000) == "1 km")
        #expect(Celebration.distanceText(meters: 1500) == "1.5 km")
        #expect(Celebration.spokenDistance(meters: 400) == "400 meters")
        #expect(Celebration.spokenDistance(meters: 1000) == "1 kilometer")
    }

    @Test("VoiceOver dice el tiempo de una serie por tiempo, no sus repeticiones")
    func rowValueSpeaksTheMeasure() throws {
        let exercise = SessionExercise(dayExercise: Self.plank())
        let value = exercise.rowValue(for: exercise.sets[0], unit: .pounds)
        #expect(value.contains("45 seconds"))
        #expect(value.contains("reps") == false)
    }

    // MARK: - Registro cerrado

    @Test("El registro trae el feedback del cliente y lo encuentra por su ejercicio")
    func logCarriesFeedback() throws {
        let json = Data("""
        {
          "id": 301,
          "title": "Upper B",
          "exercise_feedback": [
            {"exercise_key": "front_plank", "flag": "pain", "note": "Right shoulder."},
            {"exercise_key": "run", "flag": "too_easy", "note": null}
          ]
        }
        """.utf8)

        let log = try TrainingJSON.decoder().decode(TrainingWorkoutLog.self, from: json)
        #expect(log.exerciseFeedback.count == 2)
        #expect(log.hasPainFeedback)
        #expect(log.feedback(forExerciseKey: "run")?.flag == .tooEasy)
        #expect(log.feedback(forExerciseKey: "run")?.note == nil)
        #expect(log.feedback(forExerciseKey: "squat") == nil)
    }

    @Test("Sin el campo, un registro anterior sigue leyéndose sin feedback")
    func logWithoutFeedback() throws {
        let json = Data(#"{"id": 301, "title": "Upper B"}"#.utf8)
        let log = try TrainingJSON.decoder().decode(TrainingWorkoutLog.self, from: json)
        #expect(log.exerciseFeedback.isEmpty)
        #expect(log.hasPainFeedback == false)
    }
}
