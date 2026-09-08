//
//  CalendarDate.swift
//  TrainingCore
//
//  Una fecha de calendario sin hora ni zona horaria.
//
//  El backend manda `start_date`, `scheduled_date` y `date` como "2026-09-07": son días del
//  calendario, no instantes. Decodificarlos como `Date` los convierte en medianoche UTC y
//  entonces «el lunes» deja de ser el lunes en cuanto el teléfono está al oeste de Greenwich.
//  Este tipo evita esa clase entera de errores: la aritmética de días y semanas del módulo
//  (WeekMath) trabaja sobre él y nunca sobre instantes.
//

import Foundation

public struct CalendarDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {

    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Día de calendario de un instante en una zona horaria concreta.
    public init(date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    /// Parsea "YYYY-MM-DD". Acepta también un ISO 8601 completo quedándose con la parte de fecha,
    /// porque algunos endpoints devuelven la misma columna como fecha y como marca de tiempo.
    /// Acepta `"2026-09-24"` y también `"2026-09-24T23:31:29.377238"`: algunos endpoints mandan
    /// un instante donde el contrato dice fecha, y para un día de calendario lo que vale es el
    /// día. Nunca al revés: de aquí no sale una hora inventada.
    public init?(iso: String) {
        let trimmed = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        let datePart = trimmed.split(separator: "T", maxSplits: 1).first.map(String.init) ?? trimmed
        let pieces = datePart.split(separator: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    // MARK: - Conversión

    /// Medianoche de este día en la zona horaria indicada.
    public func startOfDay(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// Cadena "YYYY-MM-DD", que es exactamente lo que espera el backend.
    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { iso }

    // MARK: - Aritmética

    /// Suma (o resta) días naturales. Se calcula en UTC: como el tipo no tiene hora, la zona
    /// horaria no puede cambiar el resultado y usar una fija evita los saltos de horario de verano.
    public func adding(days: Int) -> CalendarDate {
        let calendar = Self.utcCalendar
        let base = startOfDay(in: Self.utc)
        guard let moved = calendar.date(byAdding: .day, value: days, to: base) else { return self }
        return CalendarDate(date: moved, in: Self.utc)
    }

    /// Días naturales entre dos fechas: `other.days(since: self)` positivo si `other` es posterior.
    public func days(since other: CalendarDate) -> Int {
        let calendar = Self.utcCalendar
        let from = other.startOfDay(in: Self.utc)
        let to = startOfDay(in: Self.utc)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// 1 = lunes … 7 = domingo (ISO 8601), no el `weekday` de Foundation, que empieza en domingo
    /// y además depende del calendario del dispositivo.
    public var isoWeekday: Int {
        let calendar = Self.utcCalendar
        let weekday = calendar.component(.weekday, from: startOfDay(in: Self.utc))
        return weekday == 1 ? 7 : weekday - 1
    }

    public var isMonday: Bool { isoWeekday == 1 }

    // MARK: - Comparable

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = CalendarDate(iso: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a calendar date: '\(raw)'")
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    // MARK: - Privado

    static let utc = TimeZone(secondsFromGMT: 0) ?? .current

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = CalendarDate.utc
        return calendar
    }()
}
