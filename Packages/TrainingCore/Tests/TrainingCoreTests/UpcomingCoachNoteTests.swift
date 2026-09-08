//
//  UpcomingCoachNoteTests.swift
//  TrainingCoreTests
//
//  La nota del entrenador que se lee ANTES de que llegue su día.
//
//  Una nota escrita para el jueves no mandaba aviso (es deliberado: un push por algo que pasa
//  dentro de tres días es ruido) y tampoco se veía en ningún sitio hasta el jueves. Ahora la
//  home la trae en `next_note` y la tarjeta del coach la anuncia con el día al que pertenece.
//
//  Lo que se prueba aquí es esa etiqueta, porque es la parte que puede mentir: decir «Tomorrow»
//  el día equivocado hace que alguien se presente con la ropa que no era.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Nota del coach para días próximos")
struct UpcomingCoachNoteTests {

    private let today = CalendarDate(year: 2026, month: 9, day: 8)  // un martes

    private func note(on date: CalendarDate, text: String = "Bring the belt.") -> TrainingClientDayNote {
        TrainingClientDayNote(id: 1, date: date, text: text)
    }

    // MARK: - Cómo se anuncia el día

    @Test("La nota de hoy dice «Today»")
    func todayLabel() {
        #expect(note(on: today).dayLabel(today: today, locale: Locale(identifier: "en_US")) == "Today")
    }

    @Test("La de mañana dice «Tomorrow», no el nombre del día")
    func tomorrowLabel() {
        let tomorrow = today.adding(days: 1)
        #expect(note(on: tomorrow).dayLabel(today: today, locale: Locale(identifier: "en_US")) == "Tomorrow")
    }

    @Test("Dentro de la semana se anuncia con el nombre del día")
    func weekdayLabel() {
        // Martes 8 + 2 = jueves 10.
        let thursday = today.adding(days: 2)
        let label = note(on: thursday).dayLabel(today: today, locale: Locale(identifier: "en_US"))
        #expect(label == "Thursday")
    }

    @Test("A partir de una semana el nombre del día ya no es único y gana la fecha")
    func farLabelFallsBackToDate() {
        let far = today.adding(days: 9)
        let label = note(on: far).dayLabel(today: today, locale: Locale(identifier: "en_US"))
        #expect(label == far.iso)
    }

    @Test("El día siete todavía no es ambiguo por poco, pero el nombre se repetiría: usa fecha")
    func theSeventhDayUsesTheDate() {
        let seventh = today.adding(days: 7)
        #expect(note(on: seventh).dayLabel(today: today, locale: Locale(identifier: "en_US")) == seventh.iso)
    }

    // MARK: - Decodificación del contrato

    @Test("`next_note` ausente no rompe la home: un backend anterior no lo manda")
    func missingNextNoteDecodes() throws {
        let json = Data("""
        {"assignment": null, "program": null, "focus_lifts": []}
        """.utf8)

        let response = try JSONDecoder().decode(MyProgramResponse.self, from: json)
        #expect(response.nextNote == nil)
    }

    @Test("`next_note` presente se decodifica con su fecha y su texto")
    func nextNoteDecodes() throws {
        let json = Data("""
        {
          "assignment": null,
          "program": null,
          "focus_lifts": [],
          "next_note": {
            "id": 12,
            "user_id": 3,
            "author_id": 9,
            "date": "2026-09-10",
            "text": "Deload: leave two reps in the tank.",
            "read_at": null
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(MyProgramResponse.self, from: json)
        let note = try #require(response.nextNote)
        #expect(note.text == "Deload: leave two reps in the tank.")
        #expect(note.date == CalendarDate(year: 2026, month: 9, day: 10))
        #expect(note.isUnread)
        #expect(note.dayLabel(today: today, locale: Locale(identifier: "en_US")) == "Thursday")
    }

    @Test("`has_note` ausente en un día es apagado, no desconocido")
    func missingHasNoteIsFalse() throws {
        let json = Data("""
        {"day_number": 3, "date": "2026-09-10", "is_rest": false}
        """.utf8)

        let day = try JSONDecoder().decode(TrainingWeekDay.self, from: json)
        #expect(day.hasNote == false)
    }

    @Test("`has_note` viaja cuando el servidor lo manda")
    func hasNoteDecodes() throws {
        let json = Data("""
        {"day_number": 3, "date": "2026-09-10", "is_rest": false, "has_note": true}
        """.utf8)

        let day = try JSONDecoder().decode(TrainingWeekDay.self, from: json)
        #expect(day.hasNote)
    }
}
