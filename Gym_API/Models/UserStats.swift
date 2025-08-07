import Foundation

// MARK: - Legacy UserStats (for backward compatibility)
struct UserStats: Codable {
    let weeklyClasses: Int
    let weeklyEvents: Int
    let weeklyHours: Double
    let monthlyClasses: Int
    let totalStreak: Int
    let lastUpdated: Date
    
    // Computed properties para UI
    var weeklyHoursString: String {
        return String(format: "%.1f", weeklyHours)
    }
    
    var streakText: String {
        return totalStreak > 0 ? "\(totalStreak) days" : "Start today!"
    }
}

// MARK: - Comprehensive User Stats Models (New API Structure)

struct ComprehensiveStats: Codable {
    let userId: Int
    let period: String
    let periodStart: String
    let periodEnd: String
    let fitnessMetrics: FitnessMetrics
    let eventsMetrics: EventsMetrics
    let socialMetrics: SocialMetrics
    let healthMetrics: HealthMetrics
    let membershipUtilization: MembershipUtilization
    let achievements: [Achievement]
    let trends: Trends
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case period = "period"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case fitnessMetrics = "fitness_metrics"
        case eventsMetrics = "events_metrics"
        case socialMetrics = "social_metrics"
        case healthMetrics = "health_metrics"
        case membershipUtilization = "membership_utilization"
        case achievements = "achievements"
        case trends = "trends"
        case recommendations = "recommendations"
    }
}

struct FitnessMetrics: Codable {
    let classesAttended: Int
    let classesScheduled: Int
    let attendanceRate: Double
    let totalWorkoutHours: Double
    let averageSessionDuration: Double
    let streakCurrent: Int
    let streakLongest: Int
    let favoriteClassTypes: [String]
    let peakWorkoutTimes: [String]
    let caloriesBurnedEstimate: Double
    
    enum CodingKeys: String, CodingKey {
        case classesAttended = "classes_attended"
        case classesScheduled = "classes_scheduled"
        case attendanceRate = "attendance_rate"
        case totalWorkoutHours = "total_workout_hours"
        case averageSessionDuration = "average_session_duration"
        case streakCurrent = "streak_current"
        case streakLongest = "streak_longest"
        case favoriteClassTypes = "favorite_class_types"
        case peakWorkoutTimes = "peak_workout_times"
        case caloriesBurnedEstimate = "calories_burned_estimate"
    }
    
    // Computed properties for UI
    var workoutHoursString: String {
        return String(format: "%.1f", totalWorkoutHours)
    }
    
    var attendanceRateString: String {
        return String(format: "%.0f%%", attendanceRate)
    }
    
    var averageSessionString: String {
        return String(format: "%.0f min", averageSessionDuration)
    }
    
    var streakText: String {
        return streakCurrent > 0 ? "\(streakCurrent) days" : "Start today!"
    }
    
    var caloriesString: String {
        return String(format: "%.0f cal", caloriesBurnedEstimate)
    }
}

struct EventsMetrics: Codable {
    let eventsAttended: Int
    let eventsRegistered: Int
    let eventsCreated: Int
    let attendanceRate: Double
    let favoriteEventTypes: [String]
    
    enum CodingKeys: String, CodingKey {
        case eventsAttended = "events_attended"
        case eventsRegistered = "events_registered"
        case eventsCreated = "events_created"
        case attendanceRate = "attendance_rate"
        case favoriteEventTypes = "favorite_event_types"
    }
    
    // Computed properties for UI
    var attendanceRateString: String {
        return String(format: "%.0f%%", attendanceRate)
    }
}

struct SocialMetrics: Codable {
    let chatMessagesSent: Int
    let chatRoomsActive: Int
    let socialScore: Double
    let trainerInteractions: Int
    
    enum CodingKeys: String, CodingKey {
        case chatMessagesSent = "chat_messages_sent"
        case chatRoomsActive = "chat_rooms_active"
        case socialScore = "social_score"
        case trainerInteractions = "trainer_interactions"
    }
    
    // Computed properties for UI
    var socialScoreString: String {
        return String(format: "%.0f", socialScore)
    }
    
    var socialLevel: String {
        switch socialScore {
        case 0...2: return "Just Started"
        case 3...5: return "Getting Social"
        case 6...7: return "Community Member"
        case 8...9: return "Social Butterfly"
        case 10: return "Community Leader"
        default: return "Unknown"
        }
    }
}

struct HealthMetrics: Codable {
    let currentWeight: Double?
    let currentHeight: Double?
    let bmi: Double?
    let bmiCategory: String?
    let weightChange: Double?
    let goalsProgress: [GoalProgress]
    
    enum CodingKeys: String, CodingKey {
        case currentWeight = "current_weight"
        case currentHeight = "current_height"
        case bmi = "bmi"
        case bmiCategory = "bmi_category"
        case weightChange = "weight_change"
        case goalsProgress = "goals_progress"
    }
    
    // Computed properties for UI
    var weightString: String {
        guard let weight = currentWeight else { return "Not set" }
        return String(format: "%.1f kg", weight)
    }
    
    var heightString: String {
        guard let height = currentHeight else { return "Not set" }
        return String(format: "%.0f cm", height)
    }
    
    var bmiString: String {
        guard let bmi = bmi else { return "N/A" }
        return String(format: "%.1f", bmi)
    }
    
    var bmiCategoryFormatted: String {
        return bmiCategory?.capitalized ?? "Unknown"
    }
    
    var weightChangeString: String {
        guard let change = weightChange else { return "No change" }
        let prefix = change >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", change)) kg"
    }
}

struct GoalProgress: Codable {
    let goalId: Int
    let goalType: String
    let targetValue: Double
    let currentValue: Double
    let progressPercentage: Double
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case goalType = "goal_type"
        case targetValue = "target_value"
        case currentValue = "current_value"
        case progressPercentage = "progress_percentage"
        case status = "status"
    }
    
    // Computed properties for UI
    var progressString: String {
        return String(format: "%.0f%%", progressPercentage)
    }
    
    var statusFormatted: String {
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct MembershipUtilization: Codable {
    let planName: String
    let utilizationRate: Double
    let valueScore: Double
    let daysUntilRenewal: Int
    let recommendedActions: [String]
    
    enum CodingKeys: String, CodingKey {
        case planName = "plan_name"
        case utilizationRate = "utilization_rate"
        case valueScore = "value_score"
        case daysUntilRenewal = "days_until_renewal"
        case recommendedActions = "recommended_actions"
    }
    
    // Computed properties for UI
    var utilizationString: String {
        return String(format: "%.0f%%", utilizationRate)
    }
    
    var valueScoreString: String {
        return String(format: "%.1f/10", valueScore)
    }
    
    var renewalText: String {
        if daysUntilRenewal <= 0 {
            return "Expired"
        } else if daysUntilRenewal <= 7 {
            return "\(daysUntilRenewal) days left"
        } else if daysUntilRenewal <= 30 {
            return "\(daysUntilRenewal) days left"
        } else {
            return "Active"
        }
    }
    
    var utilizationLevel: String {
        switch utilizationRate {
        case 0...20: return "Low Usage"
        case 21...50: return "Moderate Usage"
        case 51...80: return "Good Usage"
        case 81...100: return "Excellent Usage"
        default: return "Unknown"
        }
    }
}

struct Achievement: Codable {
    let id: Int
    let type: String
    let name: String
    let description: String
    let earnedAt: String
    let badgeIcon: String
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case type = "type"
        case name = "name"
        case description = "description"
        case earnedAt = "earned_at"
        case badgeIcon = "badge_icon"
    }
    
    // Computed properties for UI
    var earnedAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: earnedAt)
    }
    
    var earnedAtFormatted: String {
        guard let date = earnedAtDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct Trends: Codable {
    let attendanceTrend: String
    let workoutIntensityTrend: String
    let socialEngagementTrend: String
    
    enum CodingKeys: String, CodingKey {
        case attendanceTrend = "attendance_trend"
        case workoutIntensityTrend = "workout_intensity_trend"
        case socialEngagementTrend = "social_engagement_trend"
    }
    
    // Computed properties for UI
    var attendanceTrendFormatted: String {
        return attendanceTrend.capitalized
    }
    
    var workoutIntensityTrendFormatted: String {
        return workoutIntensityTrend.capitalized
    }
    
    var socialEngagementTrendFormatted: String {
        return socialEngagementTrend.capitalized
    }
}

// MARK: - Period Enum for API Requests
enum StatsPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "This Quarter"
        case .year: return "This Year"
        }
    }
    
    var shortName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }
}

// MARK: - Extensions for backward compatibility and empty states

extension UserStats {
    static let empty = UserStats(
        weeklyClasses: 0,
        weeklyEvents: 0, 
        weeklyHours: 0.0,
        monthlyClasses: 0,
        totalStreak: 0,
        lastUpdated: Date()
    )
    
    // Convert from ComprehensiveStats for backward compatibility
    init(from comprehensive: ComprehensiveStats) {
        self.weeklyClasses = comprehensive.fitnessMetrics.classesAttended
        self.weeklyEvents = comprehensive.eventsMetrics.eventsAttended
        self.weeklyHours = comprehensive.fitnessMetrics.totalWorkoutHours
        self.monthlyClasses = comprehensive.fitnessMetrics.classesAttended * 4 // Approximation
        self.totalStreak = comprehensive.fitnessMetrics.streakCurrent
        self.lastUpdated = Date()
    }
}

extension ComprehensiveStats {
    static let empty = ComprehensiveStats(
        userId: 0,
        period: "week",
        periodStart: ISO8601DateFormatter().string(from: Date()),
        periodEnd: ISO8601DateFormatter().string(from: Date()),
        fitnessMetrics: FitnessMetrics.empty,
        eventsMetrics: EventsMetrics.empty,
        socialMetrics: SocialMetrics.empty,
        healthMetrics: HealthMetrics.empty,
        membershipUtilization: MembershipUtilization.empty,
        achievements: [],
        trends: Trends.empty,
        recommendations: []
    )
}

extension FitnessMetrics {
    static let empty = FitnessMetrics(
        classesAttended: 0,
        classesScheduled: 0,
        attendanceRate: 0,
        totalWorkoutHours: 0,
        averageSessionDuration: 0,
        streakCurrent: 0,
        streakLongest: 0,
        favoriteClassTypes: [],
        peakWorkoutTimes: [],
        caloriesBurnedEstimate: 0
    )
}

extension EventsMetrics {
    static let empty = EventsMetrics(
        eventsAttended: 0,
        eventsRegistered: 0,
        eventsCreated: 0,
        attendanceRate: 0,
        favoriteEventTypes: []
    )
}

extension SocialMetrics {
    static let empty = SocialMetrics(
        chatMessagesSent: 0,
        chatRoomsActive: 0,
        socialScore: 0,
        trainerInteractions: 0
    )
}

extension HealthMetrics {
    static let empty = HealthMetrics(
        currentWeight: nil,
        currentHeight: nil,
        bmi: nil,
        bmiCategory: nil,
        weightChange: nil,
        goalsProgress: []
    )
}

extension MembershipUtilization {
    static let empty = MembershipUtilization(
        planName: "Unknown",
        utilizationRate: 0,
        valueScore: 0,
        daysUntilRenewal: 0,
        recommendedActions: []
    )
}

extension Trends {
    static let empty = Trends(
        attendanceTrend: "stable",
        workoutIntensityTrend: "stable",
        socialEngagementTrend: "stable"
    )
}