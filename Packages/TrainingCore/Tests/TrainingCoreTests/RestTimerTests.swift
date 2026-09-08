//
//  RestTimerTests.swift
//  TrainingCoreTests
//
//  Cronómetro de descanso (UX §8). Lo que se prueba aquí es justo lo que rompe en producción:
//  volver de segundo plano y que el tiempo siga siendo verdad.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Cronómetro de descanso")
struct RestTimerTests {

    @Test("El valor hablado cambia cada 15 s, no cada segundo")
    func accessibilityValueDoesNotChangeEverySecond() {
        let start = Date()
        let timer = RestTimer(
            exerciseName: "Bench press",
            setNumber: 2,
            totalSets: 4,
            seconds: 120,
            startedAt: start
        )
        // Diez segundos seguidos dentro del mismo bloque: el valor tiene que ser el mismo, o
        // VoiceOver reanunciaría el cronómetro una vez por segundo durante todo el descanso.
        let values = (0..<10).map { offset in
            timer.accessibilityValue(at: start.addingTimeInterval(Double(offset)))
        }
        #expect(Set(values).count == 1)

        // Y al cruzar el bloque, cambia.
        let later = timer.accessibilityValue(at: start.addingTimeInterval(20))
        #expect(later != values[0])
    }

    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    static func timer(seconds: Int = 120) -> RestTimer {
        RestTimer(
            exerciseName: "Bench press",
            setNumber: 4,
            totalSets: 4,
            seconds: seconds,
            startedAt: start
        )
    }

    @Test("El descanso vive en una fecha de fin absoluta")
    func absoluteEndDate() {
        let timer = Self.timer()
        #expect(timer.endsAt == Self.start.addingTimeInterval(120))
        #expect(timer.plannedDuration == 120)
        #expect(timer.label(at: Self.start.addingTimeInterval(36)) == "Rest 1:24")
        #expect(abs(timer.progress(at: Self.start.addingTimeInterval(60)) - 0.5) < 0.0001)
    }

    @Test("Cinco minutos en segundo plano y el cronómetro dice la verdad")
    func survivesBackground() {
        let timer = Self.timer()
        // La app estuvo cerrada; al volver han pasado 5 minutos desde que empezó el descanso.
        let comeback = Self.start.addingTimeInterval(300)
        #expect(timer.isFinished(at: comeback))
        #expect(timer.remaining(at: comeback) == 0)
        #expect(timer.progress(at: comeback) == 0)
        // Terminó hace 3 minutos, y así se lee.
        #expect(timer.label(at: comeback) == "Rest done · 3:00 ago")
        #expect(timer.accessibilityValue(at: comeback) == "Rest done")
    }

    @Test("«Rest done · 0:42 ago» es literalmente lo que pide la UX")
    func restDoneWithElapsed() {
        let timer = Self.timer(seconds: 90)
        #expect(timer.label(at: Self.start.addingTimeInterval(132)) == "Rest done · 0:42 ago")
        #expect(timer.label(at: Self.start.addingTimeInterval(90)) == "Rest done")
    }

    @Test("«+30s» suma sobre el final, no reinicia el descanso")
    func addThirtySecondsExtendsFromEnd() {
        var timer = Self.timer(seconds: 60)
        timer.extend()
        #expect(timer.endsAt == Self.start.addingTimeInterval(90))
        timer.extend()
        #expect(timer.endsAt == Self.start.addingTimeInterval(120))
        #expect(timer.extensionCount == 2)
        // Pulsarlo con el descanso ya vencido lo revive por 30 s desde donde acabó.
        let late = Self.start.addingTimeInterval(150)
        #expect(timer.isFinished(at: late))
        timer.extend()
        #expect(timer.endsAt == Self.start.addingTimeInterval(150))
    }

    @Test("Los últimos diez segundos son un estado propio")
    func finalCountdown() {
        let timer = Self.timer(seconds: 60)
        #expect(timer.isInFinalCountdown(at: Self.start.addingTimeInterval(45)) == false)
        #expect(timer.isInFinalCountdown(at: Self.start.addingTimeInterval(52)))
        #expect(timer.isInFinalCountdown(at: Self.start.addingTimeInterval(61)) == false)
    }

    @Test("El cuerpo de la notificación nombra el ejercicio y la serie")
    func notificationBody() {
        #expect(Self.timer().notificationBody == "Bench press · set 4 of 4")
        #expect(RestTimer.notificationTitle == "Rest done")
    }

    @Test("VoiceOver lee minutos y segundos, no una cifra desnuda")
    func accessibilityValue() {
        let timer = Self.timer(seconds: 120)
        #expect(timer.accessibilityValue(at: Self.start) == "2 minutes remaining")
        // Redondeado al bloque de 15 s: a los 36 s quedan 84, que se dicen como 1:30.
        #expect(timer.accessibilityValue(at: Self.start.addingTimeInterval(36)) == "1 minutes 30 seconds remaining")
        #expect(timer.accessibilityValue(at: Self.start.addingTimeInterval(105)) == "15 seconds remaining")
    }

    @Test("Skip para el cronómetro y lo cuenta solo si estaba corriendo")
    func skipStopsAndCounts() {
        var controller = RestTimerController()
        #expect(controller.isActive == false)
        #expect(controller.label(at: Self.start) == nil)

        controller.start(exerciseName: "Bench press", setNumber: 1, totalSets: 4, seconds: 120, at: Self.start)
        #expect(controller.isActive)
        #expect(controller.isRunning(at: Self.start.addingTimeInterval(10)))

        let skipped = controller.skip(at: Self.start.addingTimeInterval(10))
        #expect(skipped)
        #expect(controller.isActive == false)
        #expect(controller.skipCount == 1)

        // Saltar cuando no hay nada corriendo no cuenta.
        let again = controller.skip(at: Self.start.addingTimeInterval(20))
        #expect(again == false)
        #expect(controller.skipCount == 1)
    }

    @Test("Saltar un descanso ya vencido no cuenta como salto")
    func skippingFinishedTimerDoesNotCount() {
        var controller = RestTimerController()
        controller.start(exerciseName: "Bench press", setNumber: 1, totalSets: 4, seconds: 60, at: Self.start)
        let skipped = controller.skip(at: Self.start.addingTimeInterval(120))
        #expect(skipped == false)
        #expect(controller.skipCount == 0)
    }

    @Test("El controlador arranca, extiende y cancela")
    func controllerLifecycle() throws {
        var controller = RestTimerController()
        controller.start(exerciseName: "Cable row", setNumber: 2, totalSets: 4, seconds: 90, at: Self.start)

        let extended = controller.addThirtySeconds()
        #expect(extended)
        let timer = try #require(controller.timer)
        #expect(timer.endsAt == Self.start.addingTimeInterval(120))
        #expect(controller.label(at: Self.start.addingTimeInterval(36)) == "Rest 1:24")

        controller.cancel()
        #expect(controller.isActive == false)
        #expect(controller.skipCount == 0)

        let extendedWithoutTimer = controller.addThirtySeconds()
        #expect(extendedWithoutTimer == false)
    }

    @Test("El reloj redondea hacia arriba: 0:01 sigue siendo tiempo vivo")
    func clockFormatting() {
        #expect(RestTimer.clock(0) == "0:00")
        #expect(RestTimer.clock(0.2) == "0:01")
        #expect(RestTimer.clock(84) == "1:24")
        #expect(RestTimer.clock(600) == "10:00")
        #expect(RestTimer.defaultSeconds == 90)
    }
}
