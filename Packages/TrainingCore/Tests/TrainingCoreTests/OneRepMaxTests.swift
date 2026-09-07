//
//  OneRepMaxTests.swift
//  TrainingCoreTests
//
//  Fórmula de Epley, elegibilidad y cifras redondas (plan §4.5).
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("1RM estimado")
struct OneRepMaxTests {

    @Test("Epley: 100 kg × 5 reps = 116,67 kg")
    func epleyFormula() throws {
        let estimate = try #require(OneRepMax.estimate(weightKg: 100, reps: 5))
        #expect(abs(estimate - 116.6666) < 0.001)
    }

    @Test("Con una repetición, el 1RM es el peso levantado")
    func singleRepIsTheWeight() throws {
        let estimate = try #require(OneRepMax.estimate(weightKg: 142.9, reps: 1))
        #expect(estimate == 142.9)
    }

    @Test("Más de 12 repeticiones no estima ni opta a marca")
    func moreThanTwelveRepsIsNotEligible() {
        #expect(OneRepMax.estimate(weightKg: 60, reps: 13) == nil)
        #expect(OneRepMax.isEligible(reps: 13, weightKg: 60) == false)
        #expect(OneRepMax.isEligible(reps: 12, weightKg: 60) == true)
    }

    @Test("Una serie de calentamiento nunca es elegible")
    func warmupIsNotEligible() {
        #expect(OneRepMax.estimate(weightKg: 60, reps: 5, isWarmup: true) == nil)
        #expect(OneRepMax.isEligible(reps: 5, weightKg: 60, isWarmup: true) == false)
    }

    @Test("Sin peso no hay 1RM: el mérito es en repeticiones")
    func bodyweightHasNoEstimate() {
        #expect(OneRepMax.estimate(weightKg: nil, reps: 10) == nil)
        #expect(OneRepMax.estimate(weightKg: 0, reps: 10) == nil)
        #expect(OneRepMax.isEligible(reps: 10, weightKg: nil) == false)
    }

    @Test("Cero repeticiones no es una serie")
    func zeroRepsIsNotASet() {
        #expect(OneRepMax.estimate(weightKg: 100, reps: 0) == nil)
    }

    @Test("El redondeo respeta el escalón de la unidad: 5 lb y 2,5 kg")
    func roundsToUnitStep() {
        // 84,1 kg son 185,4 lb: en una barra americana eso es 185 lb.
        let pounds = OneRepMax.roundToStep(kilograms: 84.1, unit: .pounds)
        #expect(abs(TrainingWeightUnit.pounds.fromKilograms(pounds) - 185) < 0.001)

        // 84,1 kg redondeados al escalón métrico son 85 kg.
        let kilos = OneRepMax.roundToStep(kilograms: 84.1, unit: .kilograms)
        #expect(abs(kilos - 85) < 0.001)
    }

    @Test("La inversa de Epley devuelve la carga de la prescripción por porcentaje")
    func percentOfOneRepMax() throws {
        let weight = try #require(OneRepMax.weight(forE1RM: 116.6666, reps: 5))
        #expect(abs(weight - 100) < 0.01)

        // 80 % de un 1RM de 100 kg, redondeado al escalón métrico.
        let load = OneRepMax.load(forPercent: 80, ofE1RM: 100, unit: .kilograms)
        #expect(abs(load - 80) < 0.001)
    }

    @Test("Una cifra redonda se celebra la primera vez que se alcanza")
    func milestoneReachedInPounds() throws {
        // 102,1 kg son 225,1 lb.
        let milestone = try #require(
            OneRepMax.milestoneReached(weightKg: 102.1, previousBestKg: 95, unit: .pounds)
        )
        #expect(milestone == 225)
    }

    @Test("Una cifra redonda ya superada no se vuelve a celebrar")
    func milestoneNotRepeated() {
        // Ya movía 225 lb; subir a 230 lb no cruza ningún hito nuevo.
        let milestone = OneRepMax.milestoneReached(weightKg: 104.3, previousBestKg: 102.1, unit: .pounds)
        #expect(milestone == nil)
    }

    @Test("Los hitos métricos son otros: 100 kg, no 225 lb")
    func metricMilestones() throws {
        let milestone = try #require(
            OneRepMax.milestoneReached(weightKg: 100, previousBestKg: 97.5, unit: .kilograms)
        )
        #expect(milestone == 100)
    }

    @Test("La mejor serie ordena por 1RM, luego peso, luego repeticiones")
    func bestSetRanking() {
        let heavy = BestSetSoFar(exerciseKey: "k", setNumber: 1, reps: 3, weightKg: 100, e1rmKg: 110)
        let lighter = BestSetSoFar(exerciseKey: "k", setNumber: 2, reps: 8, weightKg: 80, e1rmKg: 101.3)
        #expect(heavy.isBetter(than: lighter))
        #expect(lighter.isBetter(than: heavy) == false)
    }
}
