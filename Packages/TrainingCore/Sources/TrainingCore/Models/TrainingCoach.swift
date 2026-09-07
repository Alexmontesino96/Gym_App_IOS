//
//  TrainingCoach.swift
//  TrainingCore
//
//  El entrenador como persona: identidad, nota del día y acuse de recibo de un registro
//  (plan §2.1 principio 7, §6.1 y §6.5).
//

import Foundation

// MARK: - Persona

public struct TrainingPerson: Codable, Hashable, Identifiable, Sendable {

    public let userId: Int
    public let name: String
    public let pictureURL: String?

    public var id: Int { userId }

    public enum CodingKeys: String, CodingKey {
        case name
        case userId = "user_id"
        case pictureURL = "picture_url"
    }

    public init(userId: Int, name: String, pictureURL: String? = nil) {
        self.userId = userId
        self.name = name
        self.pictureURL = pictureURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        pictureURL = try container.decodeIfPresent(String.self, forKey: .pictureURL)
    }

    /// Iniciales para el avatar cuando no hay foto.
    public var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }
}

// MARK: - Nota del coach para un día

public struct TrainingClientDayNote: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let gymId: Int?
    public let userId: Int?
    public let authorId: Int?
    public let date: CalendarDate
    public let dayId: Int?
    /// Máximo 280 caracteres en el contrato.
    public let text: String
    public let readAt: Date?
    public let author: TrainingPerson?

    public static let maxLength = 280

    public enum CodingKeys: String, CodingKey {
        case id, date, text, author
        case gymId = "gym_id"
        case userId = "user_id"
        case authorId = "author_id"
        case dayId = "day_id"
        case readAt = "read_at"
    }

    public init(
        id: Int,
        gymId: Int? = nil,
        userId: Int? = nil,
        authorId: Int? = nil,
        date: CalendarDate,
        dayId: Int? = nil,
        text: String,
        readAt: Date? = nil,
        author: TrainingPerson? = nil
    ) {
        self.id = id
        self.gymId = gymId
        self.userId = userId
        self.authorId = authorId
        self.date = date
        self.dayId = dayId
        self.text = text
        self.readAt = readAt
        self.author = author
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        gymId = try container.decodeIfPresent(Int.self, forKey: .gymId)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        authorId = try container.decodeIfPresent(Int.self, forKey: .authorId)
        date = try container.decode(CalendarDate.self, forKey: .date)
        dayId = try container.decodeIfPresent(Int.self, forKey: .dayId)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        author = try container.decodeIfPresent(TrainingPerson.self, forKey: .author)
    }

    public var isUnread: Bool { readAt == nil }
}

// MARK: - Acuse del coach sobre un registro

public struct TrainingCoachActivity: Codable, Hashable, Sendable {

    public let logId: Int
    public let reviewedAt: Date?
    public let comment: String?
    public let congratulated: Bool
    public let clientThanked: Bool
    public let coach: TrainingPerson?

    public enum CodingKeys: String, CodingKey {
        case comment, congratulated, coach
        case logId = "log_id"
        case reviewedAt = "reviewed_at"
        case clientThanked = "client_thanked"
    }

    public init(
        logId: Int,
        reviewedAt: Date? = nil,
        comment: String? = nil,
        congratulated: Bool = false,
        clientThanked: Bool = false,
        coach: TrainingPerson? = nil
    ) {
        self.logId = logId
        self.reviewedAt = reviewedAt
        self.comment = comment
        self.congratulated = congratulated
        self.clientThanked = clientThanked
        self.coach = coach
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logId = try container.decodeIfPresent(Int.self, forKey: .logId) ?? 0
        reviewedAt = try container.decodeIfPresent(Date.self, forKey: .reviewedAt)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        congratulated = try container.decodeIfPresent(Bool.self, forKey: .congratulated) ?? false
        clientThanked = try container.decodeIfPresent(Bool.self, forKey: .clientThanked) ?? false
        coach = try container.decodeIfPresent(TrainingPerson.self, forKey: .coach)
    }

    /// Solo se puede dar las gracias sobre una revisión existente y una sola vez (plan §6.1).
    public var canThank: Bool { reviewedAt != nil && !clientThanked }

    /// Primera línea del comentario, que es lo que enseña la tarjeta de acuse en la home.
    public var commentFirstLine: String? {
        guard let comment, !comment.isEmpty else { return nil }
        return comment.split(separator: "\n").first.map(String.init) ?? comment
    }
}
