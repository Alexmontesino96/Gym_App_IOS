//
//  UserStatsService.swift
//  Gym_API
//
//  Created by Alex Montesino on 8/4/25.
//

import Foundation
import Combine

@MainActor
class UserStatsService: ObservableObject {
    static let shared = UserStatsService()
    
    private init() {
        print("📊 UserStatsService singleton inicializado")
    }
    
    // Legacy stats (for backward compatibility)
    @Published var currentStats: UserStats?
    
    // New comprehensive stats
    @Published var comprehensiveStats: ComprehensiveStats?
    @Published var selectedPeriod: StatsPeriod = .week
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    weak var authService: AuthServiceDirect?
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    
    // MARK: - Task Management
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Helper for Main Thread Updates
    private func updateOnMainThread(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async {
                updates()
            }
        }
    }
    
    // MARK: - Helper for Authenticated Requests
    private func createAuthenticatedRequest(url: URL, method: String = "GET") async -> URLRequest? {
        guard let authService = authService else {
            print("❌ No authService configured")
            updateOnMainThread {
                self.errorMessage = "Authentication service not available"
                self.isLoading = false
            }
            return nil
        }
        
        guard let token = await authService.getValidAccessToken() else {
            print("❌ No valid access token")
            updateOnMainThread {
                self.errorMessage = "Authentication failed"
                self.isLoading = false
            }
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Agregar gym header si está disponible
        let gymService = GymService.shared
        if let currentGymId = gymService.currentGymId {
            request.setValue(String(currentGymId), forHTTPHeaderField: "X-Gym-ID")
        }
        
        return request
    }
    
    func fetchUserStats() async {
        await fetchComprehensiveStats(period: selectedPeriod, includeGoals: true)
    }
    
    func fetchComprehensiveStats() async {
        await fetchComprehensiveStats(period: selectedPeriod, includeGoals: true)
    }
    
    func fetchComprehensiveStats(period: StatsPeriod = .week, includeGoals: Bool = true) async {
        print("📊 Fetching comprehensive user stats for period: \(period.rawValue)")
        
        // Cancel any existing task
        currentTask?.cancel()
        
        currentTask = Task {
            guard !Task.isCancelled else { return }
            
            updateOnMainThread {
                self.isLoading = true
                self.errorMessage = nil
                self.selectedPeriod = period
            }
            
            // Create API request
            guard let url = URL(string: "\(baseURL)/users/stats/comprehensive") else {
                print("❌ Invalid URL for comprehensive stats")
                updateOnMainThread {
                    self.errorMessage = "Invalid request URL"
                    self.isLoading = false
                }
                return
            }
            
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = [
                URLQueryItem(name: "period", value: period.rawValue),
                URLQueryItem(name: "include_goals", value: String(includeGoals))
            ]
            
            guard let finalURL = urlComponents?.url else {
                print("❌ Failed to create URL with query parameters")
                updateOnMainThread {
                    self.errorMessage = "Failed to create request"
                    self.isLoading = false
                }
                return
            }
            
            guard let request = await createAuthenticatedRequest(url: finalURL, method: "GET") else {
                return // Error already handled in createAuthenticatedRequest
            }
            
            guard !Task.isCancelled else { return }
            
            do {
                print("🌐 Making request to: \(finalURL.absoluteString)")
                let (data, response) = try await session.data(for: request)
                
                guard !Task.isCancelled else { return }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Stats API Response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Parse comprehensive stats
                        let decoder = JSONDecoder()
                        let comprehensiveStats = try decoder.decode(ComprehensiveStats.self, from: data)
                        
                        updateOnMainThread {
                            self.comprehensiveStats = comprehensiveStats
                            // Update legacy stats for backward compatibility
                            self.currentStats = UserStats(from: comprehensiveStats)
                            self.isLoading = false
                            self.errorMessage = nil
                        }
                        
                        print("✅ Comprehensive stats loaded successfully")
                        print("   Classes: \(comprehensiveStats.fitnessMetrics.classesAttended)")
                        print("   Events: \(comprehensiveStats.eventsMetrics.eventsAttended)")
                        print("   Hours: \(comprehensiveStats.fitnessMetrics.workoutHoursString)")
                        print("   Achievements: \(comprehensiveStats.achievements.count)")
                        print("   Recommendations: \(comprehensiveStats.recommendations.count)")
                    } else {
                        // Handle error response
                        let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                        print("❌ API Error \(httpResponse.statusCode): \(errorString)")
                        
                        updateOnMainThread {
                            self.errorMessage = "Failed to load stats (Error \(httpResponse.statusCode))"
                            self.isLoading = false
                        }
                        
                        // Fallback to mock data on error
                        await fallbackToMockData()
                    }
                } else {
                    print("❌ Invalid response type")
                    updateOnMainThread {
                        self.errorMessage = "Invalid server response"
                        self.isLoading = false
                    }
                    await fallbackToMockData()
                }
                
            } catch {
                guard !Task.isCancelled else { return }
                
                print("❌ Network error: \(error.localizedDescription)")
                updateOnMainThread {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    self.isLoading = false
                }
                
                // Fallback to mock data on network error
                await fallbackToMockData()
            }
        }
    }
    
    // MARK: - Fallback Methods
    
    private func fallbackToMockData() async {
        print("📊 Falling back to mock data...")
        
        updateOnMainThread {
            let mockComprehensiveStats = self.createMockComprehensiveStats()
            self.comprehensiveStats = mockComprehensiveStats
            self.currentStats = UserStats(from: mockComprehensiveStats)
            self.isLoading = false
            // Keep the original error message
        }
    }
    
    private func createMockStats() -> UserStats {
        // Datos mock realistas basados en uso típico de gimnasio
        let mockClasses = Int.random(in: 2...8)
        let mockEvents = Int.random(in: 0...3)
        let mockHours = Double.random(in: 3.0...12.0)
        
        return UserStats(
            weeklyClasses: mockClasses,
            weeklyEvents: mockEvents,
            weeklyHours: mockHours,
            monthlyClasses: mockClasses * 4,
            totalStreak: Int.random(in: 0...30),
            lastUpdated: Date()
        )
    }
    
    private func createMockComprehensiveStats() -> ComprehensiveStats {
        let mockClasses = Int.random(in: 2...8)
        let mockEvents = Int.random(in: 0...3)
        let mockHours = Double.random(in: 3.0...12.0)
        let mockStreak = Int.random(in: 0...15)
        let mockSocialScore = Double.random(in: 0...10)
        
        return ComprehensiveStats(
            userId: 0,
            period: selectedPeriod.rawValue,
            periodStart: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()),
            periodEnd: ISO8601DateFormatter().string(from: Date()),
            fitnessMetrics: FitnessMetrics(
                classesAttended: mockClasses,
                classesScheduled: mockClasses + Int.random(in: 1...3),
                attendanceRate: Double.random(in: 60...100),
                totalWorkoutHours: mockHours,
                averageSessionDuration: Double.random(in: 45...90),
                streakCurrent: mockStreak,
                streakLongest: mockStreak + Int.random(in: 5...20),
                favoriteClassTypes: ["HIIT", "Yoga", "CrossFit"].shuffled().prefix(Int.random(in: 1...3)).map { String($0) },
                peakWorkoutTimes: ["18:00", "19:00", "07:00"].shuffled().prefix(Int.random(in: 1...2)).map { String($0) },
                caloriesBurnedEstimate: Double.random(in: 1200...3500)
            ),
            eventsMetrics: EventsMetrics(
                eventsAttended: mockEvents,
                eventsRegistered: mockEvents + Int.random(in: 0...2),
                eventsCreated: Int.random(in: 0...1),
                attendanceRate: mockEvents > 0 ? Double.random(in: 70...100) : 0,
                favoriteEventTypes: ["Fitness Challenge", "Community Event"].shuffled().prefix(1).map { String($0) }
            ),
            socialMetrics: SocialMetrics(
                chatMessagesSent: Int.random(in: 5...50),
                chatRoomsActive: Int.random(in: 1...5),
                socialScore: mockSocialScore,
                trainerInteractions: Int.random(in: 0...10)
            ),
            healthMetrics: HealthMetrics(
                currentWeight: Double.random(in: 60...90),
                currentHeight: Double.random(in: 160...190),
                bmi: nil, // Will be calculated
                bmiCategory: ["normal", "underweight", "overweight"].randomElement(),
                weightChange: Double.random(in: -2...2),
                goalsProgress: []
            ),
            membershipUtilization: MembershipUtilization(
                planName: ["Basic", "Premium", "Elite"].randomElement() ?? "Basic",
                utilizationRate: Double.random(in: 20...90),
                valueScore: Double.random(in: 3...9),
                daysUntilRenewal: Int.random(in: 5...365),
                recommendedActions: [
                    "Try attending more classes to get better value",
                    "Consider joining group events",
                    "Book sessions with trainers"
                ].shuffled().prefix(Int.random(in: 2...3)).map { String($0) }
            ),
            achievements: [],
            trends: Trends(
                attendanceTrend: ["increasing", "stable", "decreasing"].randomElement() ?? "stable",
                workoutIntensityTrend: ["increasing", "stable", "decreasing"].randomElement() ?? "stable",
                socialEngagementTrend: ["increasing", "stable", "decreasing"].randomElement() ?? "stable"
            ),
            recommendations: [
                "Try scheduling classes in advance",
                "Consider a new workout type",
                "Join community events to meet new people",
                "Track your progress weekly"
            ].shuffled().prefix(Int.random(in: 2...4)).map { String($0) }
        )
    }
    
    // MARK: - Utility Methods
    func refreshStats() async {
        await fetchUserStats()
    }
    
    func refreshStatsForPeriod(_ period: StatsPeriod) async {
        await fetchComprehensiveStats(period: period, includeGoals: true)
    }
    
    func clearStats() {
        updateOnMainThread {
            self.currentStats = nil
            self.comprehensiveStats = nil
            self.errorMessage = nil
            self.isLoading = false
        }
    }
    
    // MARK: - Convenience Methods for UI
    
    var hasValidStats: Bool {
        return comprehensiveStats != nil || currentStats != nil
    }
    
    func getDisplayStats() -> UserStats? {
        return currentStats
    }
    
    func getComprehensiveStats() -> ComprehensiveStats? {
        return comprehensiveStats
    }
    
    func getCurrentPeriodDisplayName() -> String {
        return selectedPeriod.displayName
    }
    
    // MARK: - Analytics Helper Methods
    
    func hasAchievements() -> Bool {
        return comprehensiveStats?.achievements.isEmpty == false
    }
    
    func hasRecommendations() -> Bool {
        return comprehensiveStats?.recommendations.isEmpty == false
    }
    
    func hasHealthMetrics() -> Bool {
        guard let health = comprehensiveStats?.healthMetrics else { return false }
        return health.currentWeight != nil || health.currentHeight != nil
    }
    
    func getAttendanceRate() -> Double {
        return comprehensiveStats?.fitnessMetrics.attendanceRate ?? 0.0
    }
    
    func getSocialScore() -> Double {
        return comprehensiveStats?.socialMetrics.socialScore ?? 0.0
    }
    
    func getMembershipUtilization() -> Double {
        return comprehensiveStats?.membershipUtilization.utilizationRate ?? 0.0
    }
}