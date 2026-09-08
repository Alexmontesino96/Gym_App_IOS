//
//  WeekMath.swift
//  TrainingCore
//
//  Calendario del programa: `day_number` ↔ `week_number` ↔ fecha, lunes y estados de día
//  (plan §4.2).
//
//  Todo se calcula sobre `CalendarDate`, que no tiene hora ni zona: el único sitio donde entra
//  una zona horaria es al preguntar «qué día es hoy», y hay que pasarla a mano. Así no existe
//  el error clásico de que «el lunes» cambie de día al cruzar un meridiano.
//

import Foundation

public enum WeekMath {

    public static let daysPerWeek = 7

    // MARK: - Día ↔ semana

    /// `week_number = ((day_number − 1) ÷ 7) + 1`.
    public static func weekNumber(forDayNumber dayNumber: Int) -> Int {
        guard dayNumber >= 1 else { return 1 }
        return ((dayNumber - 1) / daysPerWeek) + 1
    }

    /// Los siete `day_number` de una semana, en orden de lunes a domingo.
    public static func dayNumbers(inWeek weekNumber: Int) -> [Int] {
        let week = max(1, weekNumber)
        let first = (week - 1) * daysPerWeek + 1
        return Array(first..<(first + daysPerWeek))
    }

    /// Posición dentro de la semana: 1 = lunes … 7 = domingo.
    public static func weekdayIndex(forDayNumber dayNumber: Int) -> Int {
        guard dayNumber >= 1 else { return 1 }
        return ((dayNumber - 1) % daysPerWeek) + 1
    }

    /// Días posibles de un programa: `duration_weeks × 7`.
    public static func totalDays(durationWeeks: Int) -> Int {
        max(0, durationWeeks) * daysPerWeek
    }

    // MARK: - Día ↔ fecha

    /// Fecha de un `day_number` a partir del inicio de la asignación.
    /// El día 1 es exactamente `startDate`.
    public static func date(forDayNumber dayNumber: Int, startDate: CalendarDate) -> CalendarDate {
        startDate.adding(days: dayNumber - 1)
    }

    /// `day_number` de una fecha. Puede ser < 1 (antes de empezar) o mayor que el total del
    /// programa (ya terminado): quien llama decide qué hacer con eso.
    public static func dayNumber(for date: CalendarDate, startDate: CalendarDate) -> Int {
        date.days(since: startDate) + 1
    }

    /// «Mi día de hoy», o `nil` si hoy cae fuera del programa.
    public static func currentDayNumber(
        today: CalendarDate,
        startDate: CalendarDate,
        durationWeeks: Int
    ) -> Int? {
        let number = dayNumber(for: today, startDate: startDate)
        guard number >= 1, number <= totalDays(durationWeeks: durationWeeks) else { return nil }
        return number
    }

    /// El programa ya se ha consumido entero: su estado pasa a `completed` (plan §4.2).
    public static func isProgramFinished(
        today: CalendarDate,
        startDate: CalendarDate,
        durationWeeks: Int
    ) -> Bool {
        dayNumber(for: today, startDate: startDate) > totalDays(durationWeeks: durationWeeks)
    }

    /// La semana en curso, o `nil` si hoy cae fuera del programa.
    public static func currentWeekNumber(
        today: CalendarDate,
        startDate: CalendarDate,
        durationWeeks: Int
    ) -> Int? {
        currentDayNumber(today: today, startDate: startDate, durationWeeks: durationWeeks)
            .map(weekNumber(forDayNumber:))
    }

    // MARK: - Lunes

    /// Hoy en la zona horaria del espacio, que es la que manda para decidir qué toca.
    public static func today(in timeZone: TimeZone, now: Date = Date()) -> CalendarDate {
        CalendarDate(date: now, in: timeZone)
    }

    /// El lunes de la semana que contiene esa fecha. Si ya es lunes, se devuelve tal cual.
    public static func monday(of date: CalendarDate) -> CalendarDate {
        date.adding(days: -(date.isoWeekday - 1))
    }

    /// El lunes siguiente. Si la fecha ya es lunes, devuelve el de la semana que viene: es la
    /// opción «Next Monday» del entrenador, y significa «no hoy».
    public static func nextMonday(after date: CalendarDate) -> CalendarDate {
        monday(of: date).adding(days: daysPerWeek)
    }

    /// Las dos opciones de inicio que se ofrecen al asignar (plan §4.2). «This week» es el lunes
    /// pasado y hace que los días anteriores a hoy se pinten como descanso; «Next Monday» es el
    /// valor por defecto.
    public static func startOptions(today: CalendarDate) -> AssignmentStartOptions {
        AssignmentStartOptions(thisWeek: monday(of: today), nextMonday: nextMonday(after: today))
    }

    /// Validación del contrato: `start_date` tiene que ser lunes.
    public static func isValidStartDate(_ date: CalendarDate) -> Bool { date.isMonday }

    // MARK: - Estados de día

    /// Estado con el que la interfaz pinta un día de la semana (plan §4.2).
    ///
    /// - `hasCompletedLog`: existe un registro completado para ese día.
    /// - Un día anterior a `startDate` no existe todavía: se trata como descanso, que es lo que
    ///   hace la opción «This week» al asignar a mitad de semana.
    public static func status(
        dayNumber: Int,
        isRest: Bool,
        hasCompletedLog: Bool,
        today: CalendarDate,
        startDate: CalendarDate
    ) -> TrainingDayStatus {
        if hasCompletedLog { return .done }
        if isRest { return .rest }

        let todayNumber = self.dayNumber(for: today, startDate: startDate)
        if dayNumber == todayNumber { return .today }
        if dayNumber > todayNumber { return .pending }
        // Pasado, no era descanso y no hay registro.
        return .skipped
    }

    /// Un registro con menos de la mitad de las series prescritas cuenta como hecho, pero
    /// parcial (plan §4.2). Nunca se le llama «fallado».
    public static let partialThreshold = 0.5

    public static func isPartial(completedSets: Int, plannedSets: Int) -> Bool {
        guard plannedSets > 0 else { return false }
        return Double(completedSets) / Double(plannedSets) < partialThreshold
    }
}
