import Foundation

// MARK: - Activity Feed Models

/// Represents a single activity in the gym feed
struct FeedActivity: Codable, Identifiable, Equatable {
    let id: String?
    let type: String
    let subtype: String?
    let count: Int?
    let message: String
    let timestamp: String
    let icon: String
    let timeAgo: String?
    let ttlMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id, type, subtype, count, message, timestamp, icon
        case timeAgo = "time_ago"
        case ttlMinutes = "ttl_minutes"
    }

    static func == (lhs: FeedActivity, rhs: FeedActivity) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }

    var parsedTimestamp: Date? {
        ISO8601DateFormatter().date(from: timestamp)
    }
}

/// Response for the main activity feed endpoint
struct ActivityFeedResponse: Codable {
    let activities: [FeedActivity]
    let count: Int
    let hasMore: Bool
    let offset: Int
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case activities, count, offset, limit
        case hasMore = "has_more"
    }
}

// MARK: - Rankings Models

struct RankingEntry: Codable, Identifiable {
    let position: Int
    let value: Int
    let userId: Int?
    let name: String?
    let label: String

    var id: Int { position }

    enum CodingKeys: String, CodingKey {
        case position, value, label, name
        case userId = "user_id"
    }

    var displayName: String {
        name ?? label
    }
}

struct RankingsResponse: Codable {
    let type: String
    let period: String
    let rankings: [RankingEntry]
    let unit: String
    let count: Int
}

enum RankingType: String, CaseIterable {
    case attendance
    case consistency
    case improvement
    case activity
    case dedication

    var displayName: String {
        switch self {
        case .attendance: return "Asistencia"
        case .consistency: return "Consistencia"
        case .improvement: return "Mejora"
        case .activity: return "Actividad"
        case .dedication: return "Dedicación"
        }
    }

    var icon: String {
        switch self {
        case .attendance: return "figure.run"
        case .consistency: return "flame.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .activity: return "bolt.fill"
        case .dedication: return "heart.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .attendance: return "blue"
        case .consistency: return "orange"
        case .improvement: return "green"
        case .activity: return "purple"
        case .dedication: return "red"
        }
    }
}

enum RankingPeriod: String, CaseIterable {
    case daily
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .daily: return "Hoy"
        case .weekly: return "Semana"
        case .monthly: return "Mes"
        }
    }
}

// MARK: - Realtime Stats Models

struct PopularClass: Codable {
    let name: String
    let count: Int
}

struct RealtimeStats: Codable {
    let totalTraining: Int
    let byArea: [String: Int]?
    let popularClasses: [PopularClass]
    let peakTime: Bool
    let lastUpdate: String

    enum CodingKeys: String, CodingKey {
        case totalTraining = "total_training"
        case byArea = "by_area"
        case popularClasses = "popular_classes"
        case peakTime = "peak_time"
        case lastUpdate = "last_update"
    }
}

struct RealtimeResponse: Codable {
    let status: String
    let data: RealtimeStats
}

// MARK: - Insights Models

struct Insight: Codable, Identifiable {
    let message: String
    let type: String
    let priority: Int

    var id: String { "\(type)_\(priority)_\(message.prefix(20))" }
}

struct InsightsResponse: Codable {
    let insights: [Insight]
    let count: Int
}

// MARK: - Daily Summary Models

struct DailyStats: Codable {
    let attendance: Int
    let achievements: Int
    let personalRecords: Int
    let goalsCompleted: Int
    let classesCompleted: Int
    let totalHours: Double
    let activeStreaks: Int
    let averageClassSize: Double
    let engagementScore: Int

    enum CodingKeys: String, CodingKey {
        case attendance, achievements
        case personalRecords = "personal_records"
        case goalsCompleted = "goals_completed"
        case classesCompleted = "classes_completed"
        case totalHours = "total_hours"
        case activeStreaks = "active_streaks"
        case averageClassSize = "average_class_size"
        case engagementScore = "engagement_score"
    }
}

struct DailySummaryResponse: Codable {
    let date: String
    let stats: DailyStats
    let highlights: [String]
}

// MARK: - Activity Icons

struct ActivityIcons {
    static let mapping: [String: String] = [
        "training_count": "💪",
        "class_checkin": "📍",
        "achievement_unlocked": "⭐",
        "streak_milestone": "🔥",
        "pr_broken": "🏆",
        "goal_completed": "🎯",
        "social_activity": "👥",
        "class_popular": "📈",
        "hourly_summary": "📊",
        "motivational": "💫",
        "class_completed": "✅",
        "realtime": "💪",
        "new_member": "🎉"
    ]

    static func icon(for type: String, subtype: String? = nil) -> String {
        if let subtype = subtype, let icon = mapping[subtype] {
            return icon
        }
        return mapping[type] ?? "📊"
    }
}
