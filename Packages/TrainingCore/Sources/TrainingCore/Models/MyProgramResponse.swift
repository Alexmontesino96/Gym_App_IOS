//
//  MyProgramResponse.swift
//  TrainingCore
//
//  `GET /training/me/program` (plan §6.5). Una sola llamada alimenta W4, W6, W8 y el acuse
//  del coach, así que este tipo es el que más mira WP4.
//

import Foundation

public struct MyProgramResponse: Codable, Hashable, Sendable {

    /// Nulo cuando el cliente todavía no tiene programa: la home enseña el hueco honesto.
    public let assignment: TrainingAssignment?
    public let program: TrainingProgram?
    public let current: MyProgramCurrent?
    public let week: TrainingWeek?
    public let coach: TrainingPerson?
    public let lastLog: TrainingWorkoutLogSummary?
    public let coachActivity: TrainingCoachActivity?
    public let focusLifts: [StrengthSummaryItem]

    public enum CodingKeys: String, CodingKey {
        case assignment, program, current, week, coach
        case lastLog = "last_log"
        case coachActivity = "coach_activity"
        case focusLifts = "focus_lifts"
    }

    public init(
        assignment: TrainingAssignment? = nil,
        program: TrainingProgram? = nil,
        current: MyProgramCurrent? = nil,
        week: TrainingWeek? = nil,
        coach: TrainingPerson? = nil,
        lastLog: TrainingWorkoutLogSummary? = nil,
        coachActivity: TrainingCoachActivity? = nil,
        focusLifts: [StrengthSummaryItem] = []
    ) {
        self.assignment = assignment
        self.program = program
        self.current = current
        self.week = week
        self.coach = coach
        self.lastLog = lastLog
        self.coachActivity = coachActivity
        self.focusLifts = focusLifts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assignment = try container.decodeIfPresent(TrainingAssignment.self, forKey: .assignment)
        program = try container.decodeIfPresent(TrainingProgram.self, forKey: .program)
        current = try container.decodeIfPresent(MyProgramCurrent.self, forKey: .current)
        week = try container.decodeIfPresent(TrainingWeek.self, forKey: .week)
        coach = try container.decodeIfPresent(TrainingPerson.self, forKey: .coach)
        lastLog = try container.decodeIfPresent(TrainingWorkoutLogSummary.self, forKey: .lastLog)
        coachActivity = try container.decodeIfPresent(TrainingCoachActivity.self, forKey: .coachActivity)
        focusLifts = try container.decodeIfPresent([StrengthSummaryItem].self, forKey: .focusLifts) ?? []
    }

    /// El cliente tiene programa publicado y activo.
    public var hasActiveProgram: Bool {
        assignment?.isActive == true && program != nil
    }

    /// «Block 2 · Week 3» del héroe de la home. Sin bloque, solo la semana.
    public var contextNote: String? {
        guard let current else { return nil }
        if let block = current.block {
            return "\(block.name) · Week \(current.weekNumber)"
        }
        return "Week \(current.weekNumber)"
    }

    /// El día de hoy dentro de la semana devuelta, si el servidor lo incluyó.
    public var today: TrainingWeekDay? {
        guard let dayNumber = current?.dayNumber else { return nil }
        return week?.days.first { $0.dayNumber == dayNumber }
    }
}

/// «Dónde estoy»: día, semana y bloque en curso.
public struct MyProgramCurrent: Codable, Hashable, Sendable {

    public let dayNumber: Int
    public let weekNumber: Int
    public let block: TrainingBlock?

    public enum CodingKeys: String, CodingKey {
        case block
        case dayNumber = "day_number"
        case weekNumber = "week_number"
    }

    public init(dayNumber: Int, weekNumber: Int? = nil, block: TrainingBlock? = nil) {
        self.dayNumber = dayNumber
        self.weekNumber = weekNumber ?? WeekMath.weekNumber(forDayNumber: dayNumber)
        self.block = block
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let number = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1
        dayNumber = number
        weekNumber = try container.decodeIfPresent(Int.self, forKey: .weekNumber)
            ?? WeekMath.weekNumber(forDayNumber: number)
        block = try container.decodeIfPresent(TrainingBlock.self, forKey: .block)
    }
}
