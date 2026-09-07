//
//  WeekMathTests.swift
//  TrainingCoreTests
//
//  Calendario del programa: lunes, «this week» vs «next Monday», semana derivada y estados
//  de día (plan §4.2).
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Calendario del programa")
struct WeekMathTests {

    // 2026-09-07 es lunes; 2026-09-24, jueves.
    let monday = CalendarDate(year: 2026, month: 9, day: 7)
    let thursday = CalendarDate(year: 2026, month: 9, day: 24)

    @Test("La semana se deriva del número de día, no de una tabla")
    func weekNumberIsDerived() {
        #expect(WeekMath.weekNumber(forDayNumber: 1) == 1)
        #expect(WeekMath.weekNumber(forDayNumber: 7) == 1)
        #expect(WeekMath.weekNumber(forDayNumber: 8) == 2)
        #expect(WeekMath.weekNumber(forDayNumber: 18) == 3)
        #expect(WeekMath.weekNumber(forDayNumber: 84) == 12)
    }

    @Test("Una semana son siete días consecutivos y el índice va de lunes a domingo")
    func weekContainsSevenDays() {
        #expect(WeekMath.dayNumbers(inWeek: 3) == [15, 16, 17, 18, 19, 20, 21])
        #expect(WeekMath.weekdayIndex(forDayNumber: 15) == 1)
        #expect(WeekMath.weekdayIndex(forDayNumber: 21) == 7)
        #expect(WeekMath.totalDays(durationWeeks: 12) == 84)
    }

    @Test("Día ↔ fecha es reversible y el día 1 es la fecha de inicio")
    func dateRoundTrip() {
        #expect(WeekMath.date(forDayNumber: 1, startDate: monday) == monday)
        #expect(WeekMath.date(forDayNumber: 18, startDate: monday) == thursday)
        #expect(WeekMath.dayNumber(for: thursday, startDate: monday) == 18)
    }

    @Test("Hoy fuera del programa no tiene día")
    func currentDayOutsideProgramIsNil() {
        let beforeStart = CalendarDate(year: 2026, month: 9, day: 6)
        let afterEnd = CalendarDate(year: 2027, month: 1, day: 1)
        #expect(WeekMath.currentDayNumber(today: beforeStart, startDate: monday, durationWeeks: 12) == nil)
        #expect(WeekMath.currentDayNumber(today: afterEnd, startDate: monday, durationWeeks: 12) == nil)
        #expect(WeekMath.currentDayNumber(today: thursday, startDate: monday, durationWeeks: 12) == 18)
        #expect(WeekMath.currentWeekNumber(today: thursday, startDate: monday, durationWeeks: 12) == 3)
    }

    @Test("Pasado el último día, el programa está terminado")
    func programFinishesAfterLastDay() {
        let lastDay = WeekMath.date(forDayNumber: 84, startDate: monday)
        #expect(WeekMath.isProgramFinished(today: lastDay, startDate: monday, durationWeeks: 12) == false)
        #expect(
            WeekMath.isProgramFinished(today: lastDay.adding(days: 1), startDate: monday, durationWeeks: 12)
        )
    }

    @Test("El lunes de una semana es lunes, y si ya lo es no se mueve")
    func mondayOfWeek() {
        #expect(WeekMath.monday(of: thursday) == CalendarDate(year: 2026, month: 9, day: 21))
        #expect(WeekMath.monday(of: monday) == monday)
        #expect(monday.isMonday)
        #expect(thursday.isMonday == false)
        #expect(thursday.isoWeekday == 4)
    }

    @Test("«Next Monday» desde un lunes es el de la semana siguiente, no hoy")
    func nextMondayFromMonday() {
        #expect(WeekMath.nextMonday(after: monday) == CalendarDate(year: 2026, month: 9, day: 14))
        #expect(WeekMath.nextMonday(after: thursday) == CalendarDate(year: 2026, month: 9, day: 28))
    }

    @Test("Asignar a mitad de semana ofrece «this week» y «next Monday»")
    func startOptions() {
        let options = WeekMath.startOptions(today: thursday)
        #expect(options.thisWeek == CalendarDate(year: 2026, month: 9, day: 21))
        #expect(options.nextMonday == CalendarDate(year: 2026, month: 9, day: 28))
        // El valor por defecto del contrato es el lunes siguiente.
        #expect(options.defaultChoice == options.nextMonday)
        #expect(WeekMath.isValidStartDate(options.thisWeek))
        #expect(WeekMath.isValidStartDate(options.nextMonday))
        #expect(WeekMath.isValidStartDate(thursday) == false)
    }

    @Test("Los cinco estados de un día salen de registro, descanso y fecha")
    func dayStatuses() {
        // Hoy es el día 18.
        func status(day: Int, isRest: Bool = false, done: Bool = false) -> TrainingDayStatus {
            WeekMath.status(
                dayNumber: day,
                isRest: isRest,
                hasCompletedLog: done,
                today: thursday,
                startDate: monday
            )
        }

        #expect(status(day: 15, done: true) == .done)
        #expect(status(day: 18) == .today)
        #expect(status(day: 17, isRest: true) == .rest)
        #expect(status(day: 19) == .pending)
        #expect(status(day: 16) == .skipped)
        // Un registro completado manda sobre todo lo demás, incluso en un día de descanso.
        #expect(status(day: 17, isRest: true, done: true) == .done)
    }

    @Test("Menos de la mitad de las series prescritas es una sesión parcial")
    func partialSession() {
        #expect(WeekMath.isPartial(completedSets: 8, plannedSets: 18))
        #expect(WeekMath.isPartial(completedSets: 9, plannedSets: 18) == false)
        #expect(WeekMath.isPartial(completedSets: 18, plannedSets: 18) == false)
        // Sin prescripción (entreno libre) no hay nada contra lo que comparar.
        #expect(WeekMath.isPartial(completedSets: 1, plannedSets: 0) == false)
    }

    @Test("«Hoy» depende de la zona horaria del espacio, no de la del servidor")
    func todayDependsOnTimeZone() throws {
        // 2026-09-25 a las 02:00 UTC todavía es 24 de septiembre en Nueva York.
        let instant = try #require(
            TrainingJSON.parseDate("2026-09-25T02:00:00Z")
        )
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let utc = try #require(TimeZone(secondsFromGMT: 0))
        #expect(WeekMath.today(in: newYork, now: instant) == CalendarDate(year: 2026, month: 9, day: 24))
        #expect(WeekMath.today(in: utc, now: instant) == CalendarDate(year: 2026, month: 9, day: 25))
    }

    @Test("La fecha de calendario se serializa como la espera el backend")
    func calendarDateCoding() throws {
        let encoded = try TrainingJSON.encoder().encode(thursday)
        #expect(String(data: encoded, encoding: .utf8) == "\"2026-09-24\"")

        let decoded = try TrainingJSON.decoder().decode(CalendarDate.self, from: Data(#""2026-09-24""#.utf8))
        #expect(decoded == thursday)

        // Tolerante: la misma columna llega a veces como marca de tiempo completa.
        #expect(CalendarDate(iso: "2026-09-24T00:00:00Z") == thursday)
        #expect(CalendarDate(iso: "not a date") == nil)
    }
}
