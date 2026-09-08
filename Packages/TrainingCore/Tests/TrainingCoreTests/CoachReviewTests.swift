//
//  CoachReviewTests.swift
//  TrainingCoreTests
//
//  La lógica nueva de WP5: desviaciones de S22, modos de carga de S21, rangos de semana al
//  duplicar y cursor del buzón.
//
//  Se prueba aquí y no sobre una captura porque son las cuatro cosas del paquete que, mal hechas,
//  no se ven: una desviación que no se marca es una fila que parece correcta, y un cursor mal
//  calculado es una lista que pagina en bucle sin que nadie se dé cuenta hasta la tercera página.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Revisión del entrenador")
struct CoachReviewTests {

    // MARK: - Fábricas

    private func prescription(
        key: String = "barbell_bench_press",
        sets: Int = 4,
        reps: String = "5",
        loadMode: TrainingLoadMode = .weight,
        load: Double? = 83.9,
        rpe: Double? = 8,
        overrides: [TrainingSetOverride]? = nil
    ) -> TrainingDayExercise {
        TrainingDayExercise(
            id: 1,
            exerciseKey: key,
            exerciseName: "Bench press",
            setsCount: sets,
            reps: reps,
            loadMode: loadMode,
            loadValue: load,
            rpeTarget: rpe,
            restSeconds: 120,
            setOverrides: overrides
        )
    }

    private func set(
        number: Int,
        key: String = "barbell_bench_press",
        reps: Int = 5,
        weight: Double? = 83.9,
        rpe: Double? = 8,
        warmup: Bool = false,
        order: Int = 0
    ) -> TrainingSetLog {
        TrainingSetLog(
            clientUUID: "set-\(order)-\(number)",
            exerciseKey: key,
            exerciseName: "Bench press",
            orderIndex: order,
            setNumber: number,
            reps: reps,
            weightKg: weight,
            rpe: rpe,
            isWarmup: warmup
        )
    }

    // MARK: - Desviaciones

    @Test("Una serie que cumple la prescripción no tiene desviación")
    func onTarget() {
        let result = CoachReview.evaluate(set: set(number: 1), prescription: prescription())
        #expect(result.deviation == nil)
        #expect(result.targetValue == nil)
    }

    @Test("Un RPE por encima del objetivo es «above target»")
    func aboveTarget() {
        let result = CoachReview.evaluate(set: set(number: 3, rpe: 9), prescription: prescription())
        #expect(result.deviation == .aboveTarget)
        #expect(result.targetValue == 8)
        #expect(result.deviation?.text == "above target")
        #expect(result.deviation?.spoken(target: "8") == "Above the target RPE of 8.")
    }

    @Test("Un peso por debajo del prescrito es «below load»")
    func belowLoad() {
        // Mismo RPE que el objetivo: la desviación tiene que ser la carga, no el esfuerzo.
        let result = CoachReview.evaluate(set: set(number: 4, weight: 81.6), prescription: prescription())
        #expect(result.deviation == .belowLoad)
        #expect(result.targetValue == 83.9)
    }

    @Test("El esfuerzo manda sobre la carga cuando se salen los dos")
    func rpeWinsOverLoad() {
        let result = CoachReview.evaluate(set: set(number: 4, weight: 80, rpe: 9.5), prescription: prescription())
        #expect(result.deviation == .aboveTarget)
    }

    @Test("Menos repeticiones que las prescritas es «below reps»")
    func belowReps() {
        let result = CoachReview.evaluate(
            set: set(number: 3, reps: 7, rpe: nil),
            prescription: prescription(reps: "8", rpe: nil)
        )
        #expect(result.deviation == .belowReps)
        #expect(result.targetValue == 8)
    }

    @Test("Un rango de repeticiones se cumple por su extremo bajo")
    func repsRange() {
        let prescribed = prescription(reps: "8-10", rpe: nil)
        #expect(CoachReview.evaluate(set: set(number: 1, reps: 8, rpe: nil), prescription: prescribed).deviation == nil)
        #expect(CoachReview.evaluate(set: set(number: 1, reps: 12, rpe: nil), prescription: prescribed).deviation == nil)
        #expect(CoachReview.evaluate(set: set(number: 1, reps: 7, rpe: nil), prescription: prescribed).deviation == .belowReps)
    }

    @Test("AMRAP nunca se queda corto de repeticiones")
    func amrapNeverBelow() {
        let result = CoachReview.evaluate(
            set: set(number: 1, reps: 2, rpe: nil),
            prescription: prescription(reps: "AMRAP", rpe: nil)
        )
        #expect(result.deviation == nil)
        #expect(CoachReview.minimumReps(in: "AMRAP") == nil)
    }

    @Test("Una serie de calentamiento no se compara con nada")
    func warmupIsNotEvaluated() {
        let result = CoachReview.evaluate(
            set: set(number: 1, reps: 2, weight: 40, rpe: 10, warmup: true),
            prescription: prescription()
        )
        #expect(result.deviation == nil)
    }

    @Test("Sin prescripción no hay desviación: un entreno libre no promete nada")
    func freeWorkoutHasNoDeviation() {
        let result = CoachReview.evaluate(set: set(number: 1, weight: 20, rpe: 10), prescription: nil)
        #expect(result.deviation == nil)
    }

    @Test("La tolerancia evita marcar el redondeo de la conversión de unidades")
    func tolerance() {
        // 185 lb son 83,9146 kg; la app envía 83,9. Eso no es «below load».
        let result = CoachReview.evaluate(
            set: set(number: 1, weight: 83.9),
            prescription: prescription(load: 83.9146)
        )
        #expect(result.deviation == nil)

        // Medio kilo justo tampoco: el umbral es el mismo que usa el servidor para una marca.
        let borderline = CoachReview.evaluate(
            set: set(number: 1, weight: 83.4),
            prescription: prescription(load: 83.9)
        )
        #expect(borderline.deviation == nil)
    }

    @Test("Un porcentaje de 1RM no se compara con kilos")
    func percentModeIsNotComparedToWeight() {
        // 70 % de 1RM prescrito; la persona movió 60 kg. Sin el 1RM no hay nada que comparar y
        // afirmar «below load» sería inventarse un dato.
        let result = CoachReview.evaluate(
            set: set(number: 1, weight: 60, rpe: nil),
            prescription: prescription(loadMode: .percent1RM, load: 70, rpe: nil)
        )
        #expect(result.deviation == nil)
    }

    @Test("Un override de serie manda sobre la prescripción del ejercicio")
    func overrideWins() {
        let prescribed = prescription(
            overrides: [TrainingSetOverride(setNumber: 4, rpeTarget: 9)]
        )
        // La serie 4 tiene objetivo 9: un RPE 9 la cumple aunque el ejercicio pida 8.
        #expect(CoachReview.evaluate(set: set(number: 4, rpe: 9), prescription: prescribed).deviation == nil)
        // La serie 3 sigue con el objetivo del ejercicio.
        #expect(CoachReview.evaluate(set: set(number: 3, rpe: 9), prescription: prescribed).deviation == .aboveTarget)
    }

    // MARK: - Agrupación

    @Test("Las series se agrupan por ejercicio en el orden en que se hicieron")
    func grouping() {
        let sets = [
            set(number: 1, order: 0),
            set(number: 2, order: 0),
            set(number: 3, rpe: 9, order: 0),
            set(number: 1, key: "barbell_row", reps: 8, weight: 61.2, rpe: nil, order: 1),
            set(number: 2, key: "barbell_row", reps: 8, weight: 61.2, rpe: nil, order: 1)
        ]
        let prescribed = [
            prescription(),
            prescription(key: "barbell_row", reps: "8", load: 61.2, rpe: nil)
        ]

        let groups = CoachReview.group(sets: sets, prescription: prescribed)
        #expect(groups.count == 2)
        #expect(groups[0].exerciseKey == "barbell_bench_press")
        #expect(groups[0].sets.count == 3)
        #expect(groups[0].deviationCount == 1)
        #expect(!groups[0].isCompact)

        // Sin desviaciones el ejercicio se pinta en una línea, como el wireframe.
        #expect(groups[1].exerciseKey == "barbell_row")
        #expect(groups[1].deviationCount == 0)
        #expect(groups[1].isCompact)
        #expect(groups[1].prescription?.reps == "8")
    }

    @Test("Un ejercicio cambiado a mitad de sesión no hereda la prescripción de otro")
    func swappedExerciseHasNoPrescription() {
        let sets = [set(number: 1, key: "dumbbell_press", weight: 30, rpe: 10, order: 0)]
        let groups = CoachReview.group(sets: sets, prescription: [prescription()])
        #expect(groups.count == 1)
        #expect(groups[0].prescription == nil)
        #expect(groups[0].deviationCount == 0)
        #expect(groups[0].exerciseName == "Bench press")
    }

    @Test("Un registro sin series no produce ningún grupo")
    func emptyLog() {
        #expect(CoachReview.group(sets: [], prescription: [prescription()]).isEmpty)
    }

    // MARK: - Modos de carga (S21)

    @Test("Cambiar de modo y volver recupera el valor de cada modo")
    func loadDraftRemembersEachMode() {
        var draft = LoadDraft(mode: .weight, value: 80)
        #expect(draft.loadValue == 80)
        #expect(draft.hasNumericField)

        draft.select(.percent1RM)
        // El 80 no se arrastra: 80 kg y 80 % no son el mismo dato.
        #expect(draft.loadValue == nil)
        draft.setValue(70)
        #expect(draft.loadValue == 70)

        draft.select(.weight)
        #expect(draft.loadValue == 80)
        draft.select(.percent1RM)
        #expect(draft.loadValue == 70)
    }

    @Test("Los modos sin carga no envían valor y no aceptan escritura")
    func loadDraftModesWithoutValue() {
        var draft = LoadDraft(mode: .weight, value: 100)
        draft.select(.rpe)
        #expect(draft.loadValue == nil)
        #expect(!draft.hasNumericField)

        draft.setValue(9)
        #expect(draft.loadValue == nil)

        draft.select(.bodyweight)
        #expect(draft.loadValue == nil)

        // Y el peso original sigue esperando por si se vuelve.
        draft.select(.weight)
        #expect(draft.loadValue == 100)
    }

    @Test("Cada modo tiene su rango y su etiqueta")
    func loadModeRanges() {
        #expect(LoadModeConversion.range(for: .weight) == 0...500)
        #expect(LoadModeConversion.range(for: .percent1RM) == 0...100)
        #expect(LoadModeConversion.range(for: .rpe) == nil)
        #expect(LoadModeConversion.range(for: .bodyweight) == nil)

        #expect(LoadModeConversion.title(for: .weight) == "Weight")
        #expect(LoadModeConversion.title(for: .percent1RM) == "% of 1RM")
        #expect(LoadModeConversion.title(for: .rpe) == "RPE")
        #expect(LoadModeConversion.title(for: .bodyweight) == "Bodyweight")
        #expect(LoadModeConversion.allModes.count == 4)
    }

    // MARK: - Rango de semanas al duplicar

    @Test("Las semanas destino nunca incluyen la de origen")
    func duplicableWeeks() {
        let weeks = WeekMath.duplicableWeeks(from: 3, durationWeeks: 6)
        #expect(weeks == [1, 2, 4, 5, 6])
        #expect(!weeks.contains(3))
    }

    @Test("Un programa de una semana no tiene a dónde duplicar")
    func duplicableWeeksSingleWeek() {
        #expect(WeekMath.duplicableWeeks(from: 1, durationWeeks: 1).isEmpty)
        #expect(WeekMath.duplicableWeeks(from: 1, durationWeeks: 0).isEmpty)
    }

    @Test("Los días destino cubren todo el programa menos el propio")
    func duplicableDays() {
        let days = WeekMath.duplicableDayNumbers(from: 4, durationWeeks: 2)
        #expect(days.count == 13)
        #expect(days.first == 1)
        #expect(days.last == 14)
        #expect(!days.contains(4))
    }

    @Test("Una duplicación sin destinos o fuera de rango no se envía")
    func duplicationValidation() {
        #expect(WeekMath.isValidDuplication(targets: [1, 2], from: 3, limit: 6))
        #expect(!WeekMath.isValidDuplication(targets: [], from: 3, limit: 6))
        #expect(!WeekMath.isValidDuplication(targets: [3], from: 3, limit: 6))
        #expect(!WeekMath.isValidDuplication(targets: [7], from: 3, limit: 6))
        #expect(!WeekMath.isValidDuplication(targets: [0], from: 3, limit: 6))
    }

    @Test("Las flechas de semana no se salen del programa")
    func clampWeek() {
        #expect(WeekMath.clampWeek(0, durationWeeks: 6) == 1)
        #expect(WeekMath.clampWeek(7, durationWeeks: 6) == 6)
        #expect(WeekMath.clampWeek(3, durationWeeks: 6) == 3)
        #expect(WeekMath.isValidWeek(6, durationWeeks: 6))
        #expect(!WeekMath.isValidWeek(7, durationWeeks: 6))
    }

    // MARK: - Cursor del buzón

    private func summary(_ id: Int) -> TrainingWorkoutLogSummary {
        TrainingWorkoutLogSummary(id: id, title: "Upper A")
    }

    @Test("El cursor de la página siguiente es el id más pequeño de lo que ya se tiene")
    func inboxCursor() {
        let page = [summary(30), summary(28), summary(25)]
        #expect(InboxCursor.next(after: page) == 25)
        #expect(InboxCursor.next(after: []) == nil)
    }

    @Test("Hay más páginas solo mientras el servidor devuelva la página entera")
    func inboxHasMore() {
        #expect(InboxCursor.hasMore(page: Array(1...20).map(summary), limit: 20))
        #expect(!InboxCursor.hasMore(page: Array(1...19).map(summary), limit: 20))
        #expect(!InboxCursor.hasMore(page: [], limit: 20))
        #expect(!InboxCursor.hasMore(page: [summary(1)], limit: 0))
    }

    @Test("Unir páginas no duplica un registro que llegó dos veces")
    func inboxMerge() {
        let first = [summary(30), summary(28)]
        let second = [summary(28), summary(25), summary(22)]
        let merged = InboxCursor.merge(first, with: second)
        #expect(merged.map(\.id) == [30, 28, 25, 22])
    }

    @Test("La lista unida queda en orden descendente aunque llegue desordenada")
    func inboxMergeSorts() {
        let merged = InboxCursor.merge([summary(10)], with: [summary(40), summary(5)])
        #expect(merged.map(\.id) == [40, 10, 5])
    }

    @Test("El tope deja las filas más recientes y tira las más viejas")
    func inboxCapKeepsTheNewest() {
        let many = (1...250).reversed().map(summary)   // 250, 249, … 1
        let capped = InboxCursor.capped(many)
        #expect(capped.count == InboxCursor.maxRetained)
        #expect(capped.first?.id == 250)
        #expect(capped.last?.id == 250 - InboxCursor.maxRetained + 1)
    }

    @Test("Por debajo del tope no se toca nada")
    func inboxCapIsANoOpBelowTheLimit() {
        let few = [summary(30), summary(28), summary(25)]
        #expect(InboxCursor.capped(few).map(\.id) == [30, 28, 25])
        #expect(InboxCursor.capped([]).isEmpty)
        // Un tope de cero o negativo no borra la lista: sería peor que no tener tope.
        #expect(InboxCursor.capped(few, to: 0).count == 3)
    }
}
