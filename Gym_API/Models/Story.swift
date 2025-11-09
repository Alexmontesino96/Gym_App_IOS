//
//  Story.swift
//  Gym_API
//
//  Created on November 2024
//

import Foundation
import SwiftUI

// MARK: - Story Type Enum
enum StoryType: String, CaseIterable, Codable {
    case image = "image"
    case video = "video"
    case text = "text"
    case workout = "workout"
    case achievement = "achievement"

    var displayName: String {
        switch self {
        case .image: return "Foto"
        case .video: return "Video"
        case .text: return "Texto"
        case .workout: return "Workout"
        case .achievement: return "Logro"
        }
    }

    var icon: String {
        switch self {
        case .image: return "camera.fill"
        case .video: return "video.fill"
        case .text: return "text.bubble.fill"
        case .workout: return "figure.strengthtraining.traditional"
        case .achievement: return "trophy.fill"
        }
    }
}

// MARK: - Story Privacy Enum
enum StoryPrivacy: String, CaseIterable, Codable {
    case `public` = "public"
    case followers = "followers"
    case closeFriends = "close_friends"
    case `private` = "private"

    var displayName: String {
        switch self {
        case .public: return "Público"
        case .followers: return "Seguidores"
        case .closeFriends: return "Amigos cercanos"
        case .private: return "Privado"
        }
    }

    var icon: String {
        switch self {
        case .public: return "globe"
        case .followers: return "person.2.fill"
        case .closeFriends: return "heart.circle.fill"
        case .private: return "lock.fill"
        }
    }
}

// MARK: - Workout Data
struct WorkoutData: Codable {
    let exercise: String
    let weight: Double?
    let weightUnit: String?
    let reps: Int?
    let sets: Int?
    let durationMinutes: Int?
    let caloriesBurned: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case exercise
        case weight
        case weightUnit = "weight_unit"
        case reps
        case sets
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case notes
    }
}

// MARK: - Story Model
struct Story: Identifiable, Codable {
    let id: Int
    let gymId: Int?  // Opcional porque el backend puede no enviarlo
    let userId: Int?  // Opcional - viene en el nivel de user_stories
    let storyType: StoryType
    let caption: String?
    let privacy: StoryPrivacy?  // Opcional con default
    let mediaUrl: String?
    let thumbnailUrl: String?
    let workoutData: WorkoutData?
    let viewCount: Int
    let reactionCount: Int
    let isPinned: Bool
    let isExpired: Bool?  // Opcional - se puede calcular
    let isOwnStory: Bool?  // Opcional con default
    var hasViewed: Bool  // Mutable para permitir actualizaciones locales
    let hasReacted: Bool?  // Opcional con default
    let createdAt: Date
    let expiresAt: Date
    let userInfo: StoryUserInfo?  // Opcional - viene en el nivel de user_stories

    enum CodingKeys: String, CodingKey {
        case id
        case gymId = "gym_id"
        case userId = "user_id"
        case storyType = "story_type"
        case caption
        case privacy
        case mediaUrl = "media_url"
        case thumbnailUrl = "thumbnail_url"
        case workoutData = "workout_data"
        case viewCount = "view_count"
        case reactionCount = "reaction_count"
        case isPinned = "is_pinned"
        case isExpired = "is_expired"
        case isOwnStory = "is_own_story"
        case hasViewed = "has_viewed"
        case hasReacted = "has_reacted"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case userInfo = "user_info"
    }

    // Computed properties
    var isActive: Bool {
        let expired = isExpired ?? (expiresAt < Date())
        return !expired && expiresAt > Date()
    }

    var timeRemaining: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        if remaining <= 0 { return "Expirado" }

        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedViewCount: String {
        if viewCount >= 1000 {
            return String(format: "%.1fK", Double(viewCount) / 1000.0)
        }
        return "\(viewCount)"
    }
}

// MARK: - Story User Info
struct StoryUserInfo: Codable {
    let id: Int
    let name: String
    let avatar: String?
}

// MARK: - User Story Group (for feed)
struct UserStoryGroup: Identifiable, Codable {
    let userId: Int
    let userName: String
    let userAvatar: String?
    let hasUnseen: Bool
    let stories: [Story]

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case hasUnseen = "has_unseen"
        case stories
    }

    // Computed properties
    var activeStories: [Story] {
        stories.filter { $0.isActive }
    }

    var unseenCount: Int {
        stories.filter { !$0.hasViewed && $0.isActive }.count
    }

    var mostRecentStory: Story? {
        stories.sorted { $0.createdAt > $1.createdAt }.first
    }
}

// MARK: - Story Feed Response
struct StoryFeedResponse: Codable {
    let userStories: [UserStoryGroup]
    let totalUsers: Int
    let hasMore: Bool
    let nextOffset: Int?
    let lastUpdate: Date

    enum CodingKeys: String, CodingKey {
        case userStories = "user_stories"
        case totalUsers = "total_users"
        case hasMore = "has_more"
        case nextOffset = "next_offset"
        case lastUpdate = "last_update"
    }
}

// MARK: - Story Viewer
struct StoryViewer: Identifiable, Codable {
    let viewerId: Int
    let viewerName: String
    let viewerAvatar: String?
    let viewedAt: Date
    let viewDurationSeconds: Int?

    var id: Int { viewerId }

    enum CodingKeys: String, CodingKey {
        case viewerId = "viewer_id"
        case viewerName = "viewer_name"
        case viewerAvatar = "viewer_avatar"
        case viewedAt = "viewed_at"
        case viewDurationSeconds = "view_duration_seconds"
    }

    var formattedViewTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: viewedAt, relativeTo: Date())
    }
}

// MARK: - Story Create Request
struct StoryCreateRequest: Codable {
    let caption: String?
    let storyType: StoryType
    let privacy: StoryPrivacy
    let durationHours: Int
    let mediaUrl: String?
    let workoutData: WorkoutData?

    enum CodingKeys: String, CodingKey {
        case caption
        case storyType = "story_type"
        case privacy
        case durationHours = "duration_hours"
        case mediaUrl = "media_url"
        case workoutData = "workout_data"
    }
}

// MARK: - Story Filter
enum StoryFilter: String {
    case all = "all"
    case following = "following"
    case closeFriends = "close_friends"
}