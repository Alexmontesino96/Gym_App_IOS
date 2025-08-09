import Foundation
import Combine
import SwiftUI

// MARK: - User Stats Service
@MainActor
class UserStatsService: ObservableObject {
    // MARK: - Published Properties
    @Published var userStats: UserStats = .empty
    @Published var comprehensiveStats: ComprehensiveStats? = nil
    @Published var achievements: [Achievement] = []
    @Published var workoutHistory: [WorkoutHistory] = []
    @Published var personalGoals: [PersonalGoal] = []
    @Published var workoutBuddies: [WorkoutBuddy] = []
    @Published var leaderboardPosition: LeaderboardEntry?
    @Published var activityAnalytics: ActivityAnalytics?
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependency Injection
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?
    
    // MARK: - Singleton
    static let shared = UserStatsService()
    
    private init() {
        // Generar datos de ejemplo para desarrollo
        generateMockData()
    }
    
    // MARK: - Public Methods
    
    /// Obtiene estadísticas completas del usuario
    func fetchComprehensiveStats(period: StatsPeriod = .week) async {
        isLoading = true
        error = nil
        
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            print("❌ [UserStatsService] Missing auth token or gym ID")
            isLoading = false
            return
        }
        
        guard let url = URL(string: "\(baseURL)/users/stats/comprehensive?period=\(period.rawValue)") else {
            print("❌ [UserStatsService] Invalid URL")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let stats = try decoder.decode(ComprehensiveStats.self, from: data)
                comprehensiveStats = stats
                userStats = UserStats(from: stats)
                achievements = stats.achievements
                print("✅ [UserStatsService] Comprehensive stats loaded successfully")
            }
        } catch {
            print("❌ [UserStatsService] Error fetching stats: \(error)")
            self.error = error
            // Usar datos de ejemplo si falla la API
            generateMockData()
        }
        
        isLoading = false
    }
    
    /// Obtiene el historial de entrenamientos
    func fetchWorkoutHistory() async {
        // Por ahora usar datos de ejemplo
        generateMockWorkoutHistory()
    }
    
    /// Obtiene los objetivos personales
    func fetchPersonalGoals() async {
        // Por ahora usar datos de ejemplo
        generateMockGoals()
    }
    
    /// Obtiene los compañeros de entrenamiento
    func fetchWorkoutBuddies() async {
        // Por ahora usar datos de ejemplo
        generateMockBuddies()
    }
    
    /// Obtiene la posición en el leaderboard
    func fetchLeaderboardPosition(category: LeaderboardCategory = .workouts, period: LeaderboardPeriod = .month) async {
        // Por ahora usar datos de ejemplo
        generateMockLeaderboard()
    }
    
    /// Obtiene análisis de actividad
    func fetchActivityAnalytics() async {
        // Por ahora usar datos de ejemplo
        generateMockAnalytics()
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockData() {
        // Generar estadísticas básicas
        userStats = UserStats(
            weeklyClasses: 5,
            weeklyEvents: 2,
            weeklyHours: 7.5,
            monthlyClasses: 18,
            totalStreak: 12,
            currentStreak: 12,
            lastUpdated: Date()
        )
        
        // Generar logros
        achievements = [
            Achievement(
                id: 1,
                type: "streak",
                name: "Iron Will",
                description: "30-day workout streak",
                earnedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 5)),
                badgeIcon: "flame.fill"
            ),
            Achievement(
                id: 2,
                type: "milestone",
                name: "Century Club",
                description: "Complete 100 workouts",
                earnedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 10)),
                badgeIcon: "star.circle.fill"
            ),
            Achievement(
                id: 3,
                type: "social",
                name: "Team Player",
                description: "Join 10 group classes",
                earnedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 2)),
                badgeIcon: "person.3.fill"
            )
        ]
        
        generateMockWorkoutHistory()
        generateMockGoals()
        generateMockBuddies()
        generateMockLeaderboard()
        generateMockAnalytics()
    }
    
    private func generateMockWorkoutHistory() {
        workoutHistory = [
            WorkoutHistory(
                id: 1,
                date: Date(),
                type: .strength,
                duration: 45,
                caloriesBurned: 320,
                className: "Power Lifting",
                trainerName: "Mike Johnson",
                notes: "Great session, PR on deadlift!",
                performance: PerformanceMetric(
                    metric: "Deadlift",
                    value: 120,
                    unit: "kg",
                    improvement: 5.2
                )
            ),
            WorkoutHistory(
                id: 2,
                date: Date().addingTimeInterval(-86400),
                type: .cardio,
                duration: 30,
                caloriesBurned: 280,
                className: "HIIT Blast",
                trainerName: "Sarah Williams",
                notes: nil,
                performance: nil
            ),
            WorkoutHistory(
                id: 3,
                date: Date().addingTimeInterval(-86400 * 2),
                type: .yoga,
                duration: 60,
                caloriesBurned: 180,
                className: "Vinyasa Flow",
                trainerName: "Emma Davis",
                notes: "Feeling more flexible",
                performance: nil
            )
        ]
    }
    
    private func generateMockGoals() {
        personalGoals = [
            PersonalGoal(
                id: "goal1",
                title: "Lose 5kg",
                description: "Reach target weight of 75kg",
                targetValue: 5,
                currentValue: 3.2,
                unit: "kg",
                deadline: Date().addingTimeInterval(86400 * 30),
                category: .weight,
                createdAt: Date().addingTimeInterval(-86400 * 15),
                isCompleted: false
            ),
            PersonalGoal(
                id: "goal2",
                title: "Run 10K",
                description: "Complete a 10K run under 50 minutes",
                targetValue: 10,
                currentValue: 7.5,
                unit: "km",
                deadline: Date().addingTimeInterval(86400 * 45),
                category: .fitness,
                createdAt: Date().addingTimeInterval(-86400 * 20),
                isCompleted: false
            ),
            PersonalGoal(
                id: "goal3",
                title: "100 Push-ups",
                description: "Do 100 consecutive push-ups",
                targetValue: 100,
                currentValue: 65,
                unit: "reps",
                deadline: nil,
                category: .fitness,
                createdAt: Date().addingTimeInterval(-86400 * 30),
                isCompleted: false
            )
        ]
    }
    
    private func generateMockBuddies() {
        workoutBuddies = [
            WorkoutBuddy(
                id: 1,
                name: "Alex Thompson",
                picture: nil,
                sharedWorkouts: 15,
                lastWorkoutTogether: Date().addingTimeInterval(-86400 * 2),
                favoriteClass: "CrossFit"
            ),
            WorkoutBuddy(
                id: 2,
                name: "Maria Garcia",
                picture: nil,
                sharedWorkouts: 8,
                lastWorkoutTogether: Date().addingTimeInterval(-86400 * 5),
                favoriteClass: "Yoga Flow"
            ),
            WorkoutBuddy(
                id: 3,
                name: "John Smith",
                picture: nil,
                sharedWorkouts: 12,
                lastWorkoutTogether: Date().addingTimeInterval(-86400),
                favoriteClass: "Strength Training"
            )
        ]
    }
    
    private func generateMockLeaderboard() {
        leaderboardPosition = LeaderboardEntry(
            id: 1,
            userId: 1,
            userName: "You",
            userPicture: nil,
            score: 18,
            rank: 5,
            category: .workouts,
            period: .month
        )
    }
    
    private func generateMockAnalytics() {
        // Generar datos de actividad semanal
        let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var weeklyData: [DayActivity] = []
        
        for (index, day) in weekDays.enumerated() {
            let date = Date().addingTimeInterval(Double(-86400 * (6 - index)))
            let isActive = Bool.random() || index < 4
            weeklyData.append(DayActivity(
                dayOfWeek: day,
                date: date,
                workoutCount: isActive ? Int.random(in: 1...2) : 0,
                totalMinutes: isActive ? Int.random(in: 30...90) : 0,
                isActive: isActive
            ))
        }
        
        // Generar tendencia mensual
        var monthlyTrend: [MonthDataPoint] = []
        for i in 0..<4 {
            monthlyTrend.append(MonthDataPoint(
                date: Date().addingTimeInterval(Double(-86400 * 7 * i)),
                value: Double.random(in: 3...8),
                label: "Week \(4-i)"
            ))
        }
        
        // Desglose por categoría
        let categoryBreakdown = [
            CategoryData(category: .strength, percentage: 35, totalSessions: 7),
            CategoryData(category: .cardio, percentage: 30, totalSessions: 6),
            CategoryData(category: .yoga, percentage: 20, totalSessions: 4),
            CategoryData(category: .hiit, percentage: 15, totalSessions: 3)
        ]
        
        activityAnalytics = ActivityAnalytics(
            weeklyData: weeklyData,
            monthlyTrend: monthlyTrend,
            categoryBreakdown: categoryBreakdown,
            timeInvestment: TimeInvestment(
                averageSessionDuration: 52,
                peakHour: 18,
                preferredDays: ["Monday", "Wednesday", "Friday"],
                consistency: 0.75
            )
        )
    }
}

// MARK: - Extended Models for Profile Page

struct WorkoutHistory: Identifiable, Codable {
    let id: Int
    let date: Date
    let type: WorkoutType
    let duration: Int // in minutes
    let caloriesBurned: Int?
    let className: String?
    let trainerName: String?
    let notes: String?
    let performance: PerformanceMetric?
    
    var formattedDuration: String {
        if duration < 60 {
            return "\(duration) min"
        } else {
            let hours = duration / 60
            let minutes = duration % 60
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case strength = "strength"
    case cardio = "cardio"
    case yoga = "yoga"
    case hiit = "hiit"
    case cycling = "cycling"
    case swimming = "swimming"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .yoga: return "Yoga"
        case .hiit: return "HIIT"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .other: return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .yoga: return "figure.yoga"
        case .hiit: return "bolt.heart.fill"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.walk"
        }
    }
    
    var color: Color {
        switch self {
        case .strength: return .blue
        case .cardio: return .red
        case .yoga: return .purple
        case .hiit: return .orange
        case .cycling: return .green
        case .swimming: return .cyan
        case .other: return .gray
        }
    }
}

struct PerformanceMetric: Codable {
    let metric: String
    let value: Double
    let unit: String
    let improvement: Double? // percentage improvement
}

struct PersonalGoal: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let deadline: Date?
    let category: GoalCategory
    let createdAt: Date
    let isCompleted: Bool
    
    var progress: Double {
        return min(currentValue / targetValue, 1.0)
    }
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var daysRemaining: Int? {
        guard let deadline = deadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case weight = "weight"
    case fitness = "fitness"
    case nutrition = "nutrition"
    case wellness = "wellness"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .fitness: return "Fitness"
        case .nutrition: return "Nutrition"
        case .wellness: return "Wellness"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .fitness: return "figure.strengthtraining.traditional"
        case .nutrition: return "leaf.fill"
        case .wellness: return "heart.fill"
        case .custom: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .weight: return .orange
        case .fitness: return .blue
        case .nutrition: return .green
        case .wellness: return .pink
        case .custom: return .purple
        }
    }
}

struct WorkoutBuddy: Identifiable, Codable {
    let id: Int
    let name: String
    let picture: String?
    let sharedWorkouts: Int
    let lastWorkoutTogether: Date?
    let favoriteClass: String?
    
    var initials: String {
        let components = name.split(separator: " ")
        let firstInitial = components.first?.first ?? Character("?")
        let lastInitial = components.count > 1 ? (components.last?.first ?? Character("")) : Character("")
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: Int
    let userId: Int
    let userName: String
    let userPicture: String?
    let score: Int
    let rank: Int
    let category: LeaderboardCategory
    let period: LeaderboardPeriod
    
    var rankDisplay: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}

enum LeaderboardCategory: String, Codable {
    case workouts = "workouts"
    case minutes = "minutes"
    case streak = "streak"
    case challenges = "challenges"
    
    var displayName: String {
        switch self {
        case .workouts: return "Workouts"
        case .minutes: return "Minutes"
        case .streak: return "Streak"
        case .challenges: return "Challenges"
        }
    }
}

enum LeaderboardPeriod: String, Codable {
    case week = "week"
    case month = "month"
    case year = "year"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

struct ActivityAnalytics: Codable {
    let weeklyData: [DayActivity]
    let monthlyTrend: [MonthDataPoint]
    let categoryBreakdown: [CategoryData]
    let timeInvestment: TimeInvestment
}

struct DayActivity: Codable {
    let dayOfWeek: String
    let date: Date
    let workoutCount: Int
    let totalMinutes: Int
    let isActive: Bool
}

struct MonthDataPoint: Codable {
    let date: Date
    let value: Double
    let label: String
}

struct CategoryData: Codable {
    let category: WorkoutType
    let percentage: Double
    let totalSessions: Int
}

struct TimeInvestment: Codable {
    let averageSessionDuration: Int
    let peakHour: Int
    let preferredDays: [String]
    let consistency: Double // 0.0 to 1.0
}