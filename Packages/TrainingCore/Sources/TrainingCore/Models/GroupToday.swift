//
//  GroupToday.swift
//  TrainingCore
//
//  `GET /training/programs/{id}/group/today` (plan §6.1).
//
//  Contrato de privacidad: este endpoint devuelve **solo** nombre, foto, si entrenó hoy y el
//  nombre del día. Nunca series, pesos ni volumen de otro cliente (plan §4.8). Si algún día el
//  servidor mandara más, este modelo lo ignora.
//

import Foundation

public struct GroupTodayMember: Codable, Hashable, Identifiable, Sendable {

    public let userId: Int
    public let name: String
    public let pictureURL: String?
    public let dayName: String?
    public let logId: Int?
    /// Si el llamante ya le dio kudos hoy.
    public let kudosGiven: Bool

    public var id: Int { userId }

    public enum CodingKeys: String, CodingKey {
        case name
        case userId = "user_id"
        case pictureURL = "picture_url"
        case dayName = "day_name"
        case logId = "log_id"
        case kudosGiven = "kudos_given"
    }

    public init(
        userId: Int,
        name: String,
        pictureURL: String? = nil,
        dayName: String? = nil,
        logId: Int? = nil,
        kudosGiven: Bool = false
    ) {
        self.userId = userId
        self.name = name
        self.pictureURL = pictureURL
        self.dayName = dayName
        self.logId = logId
        self.kudosGiven = kudosGiven
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        pictureURL = try container.decodeIfPresent(String.self, forKey: .pictureURL)
        dayName = try container.decodeIfPresent(String.self, forKey: .dayName)
        logId = try container.decodeIfPresent(Int.self, forKey: .logId)
        kudosGiven = try container.decodeIfPresent(Bool.self, forKey: .kudosGiven) ?? false
    }
}

public struct GroupTodayWeekDay: Codable, Hashable, Identifiable, Sendable {

    public let date: CalendarDate
    public let trainedCount: Int

    public var id: String { date.iso }

    public enum CodingKeys: String, CodingKey {
        case date
        case trainedCount = "trained_count"
    }

    public init(date: CalendarDate, trainedCount: Int) {
        self.date = date
        self.trainedCount = trainedCount
    }
}

public struct GroupToday: Codable, Hashable, Sendable {

    public let trainedToday: [GroupTodayMember]
    public let trainedCount: Int
    public let totalMembers: Int
    public let week: [GroupTodayWeekDay]
    public let consistencyPct: Double?
    /// Grupo recién creado: la tarjeta se presenta sin cifras que humillen a nadie.
    public let isNew: Bool

    public enum CodingKeys: String, CodingKey {
        case week
        case trainedToday = "trained_today"
        case trainedCount = "trained_count"
        case totalMembers = "total_members"
        case consistencyPct = "consistency_pct"
        case isNew = "is_new"
    }

    public init(
        trainedToday: [GroupTodayMember] = [],
        trainedCount: Int = 0,
        totalMembers: Int = 0,
        week: [GroupTodayWeekDay] = [],
        consistencyPct: Double? = nil,
        isNew: Bool = false
    ) {
        self.trainedToday = trainedToday
        self.trainedCount = trainedCount
        self.totalMembers = totalMembers
        self.week = week
        self.consistencyPct = consistencyPct
        self.isNew = isNew
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trainedToday = try container.decodeIfPresent([GroupTodayMember].self, forKey: .trainedToday) ?? []
        trainedCount = try container.decodeIfPresent(Int.self, forKey: .trainedCount) ?? 0
        totalMembers = try container.decodeIfPresent(Int.self, forKey: .totalMembers) ?? 0
        week = try container.decodeIfPresent([GroupTodayWeekDay].self, forKey: .week) ?? []
        consistencyPct = try container.decodeIfPresent(Double.self, forKey: .consistencyPct)
        isNew = try container.decodeIfPresent(Bool.self, forKey: .isNew) ?? false
    }

    /// «2 of 3 trained today».
    public var headline: String { "\(trainedCount) of \(totalMembers) trained today" }
}
