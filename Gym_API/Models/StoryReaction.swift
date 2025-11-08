//
//  StoryReaction.swift
//  Gym_API
//
//  Created on November 2024
//

import Foundation
import SwiftUI

// MARK: - Fitness Emoji Reactions
enum FitnessEmoji: String, CaseIterable {
    case strength = "💪"
    case fire = "🔥"
    case heart = "❤️"
    case clap = "👏"
    case hundred = "💯"
    case target = "🎯"
    case lightning = "⚡"
    case trophy = "🏆"
    case explosion = "💥"
    case hands = "🙌"

    var meaning: String {
        switch self {
        case .strength: return "Fuerza"
        case .fire: return "En fuego"
        case .heart: return "Me encanta"
        case .clap: return "Aplausos"
        case .hundred: return "Perfecto"
        case .target: return "Enfocado"
        case .lightning: return "Energía"
        case .trophy: return "Campeón"
        case .explosion: return "Explosivo"
        case .hands: return "Increíble"
        }
    }

    static var allowedEmojis: Set<String> {
        Set(FitnessEmoji.allCases.map { $0.rawValue })
    }

    static func isValid(_ emoji: String) -> Bool {
        allowedEmojis.contains(emoji)
    }
}

// MARK: - Story Reaction Model
struct StoryReaction: Identifiable, Codable {
    let id: Int
    let storyId: Int
    let userId: Int
    let emoji: String
    let message: String?
    let createdAt: Date
    let user: ReactionUser

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case userId = "user_id"
        case emoji
        case message
        case createdAt = "created_at"
        case user
    }

    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Reaction User
struct ReactionUser: Codable {
    let id: Int
    let name: String
    let avatar: String?
}

// MARK: - Story Highlight Model
struct StoryHighlight: Identifiable, Codable {
    let id: Int
    let userId: Int
    let title: String
    let coverImageUrl: String?
    let storyIds: [Int]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case coverImageUrl = "cover_image_url"
        case storyIds = "story_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Story Report Reason
enum StoryReportReason: String, CaseIterable, Codable {
    case spam = "spam"
    case inappropriate = "inappropriate"
    case harassment = "harassment"
    case violence = "violence"
    case falseInformation = "false_information"
    case other = "other"

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .inappropriate: return "Contenido inapropiado"
        case .harassment: return "Acoso"
        case .violence: return "Violencia"
        case .falseInformation: return "Información falsa"
        case .other: return "Otro"
        }
    }
}

// MARK: - Story Report Request
struct StoryReportRequest: Codable {
    let reason: StoryReportReason
    let description: String

    enum CodingKeys: String, CodingKey {
        case reason
        case description
    }
}

// MARK: - Reaction Animation Type
enum ReactionAnimationType {
    case floatUp
    case scale
    case particleExplosion
    case bounce

    var duration: Double {
        switch self {
        case .floatUp: return 1.5
        case .scale: return 0.5
        case .particleExplosion: return 1.0
        case .bounce: return 0.6
        }
    }
}