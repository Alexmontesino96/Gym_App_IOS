import Foundation
import Combine

/// Service for managing gym activity feed, rankings, realtime stats, and insights
@MainActor
class ActivityService: ObservableObject {
    // MARK: - Published Properties

    /// Main activity feed
    @Published var activities: [FeedActivity] = []
    @Published var hasMoreActivities = false

    /// Realtime stats
    @Published var realtimeStats: RealtimeStats?
    @Published var isPeakTime = false
    @Published var totalTraining = 0

    /// Rankings
    @Published var currentRankings: [RankingEntry] = []
    @Published var rankingsUnit: String = ""

    /// Insights
    @Published var insights: [Insight] = []
    @Published var topInsight: Insight?

    /// Daily summary
    @Published var dailySummary: DailySummaryResponse?

    /// Legacy achievements (for backwards compatibility)
    @Published var achievements: [Achievement] = []

    /// Loading states
    @Published var isLoading = false
    @Published var isLoadingRealtime = false
    @Published var isLoadingRankings = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    var authService: AuthServiceDirect?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var realtimeRefreshTimer: Timer?
    private var currentOffset = 0
    private let pageLimit = 20
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"

    // MARK: - Initialization

    init() {
        #if DEBUG
        print("📊 ActivityService initialized")
        #endif
    }

    // MARK: - Activity Feed

    /// Fetches the main activity feed
    func fetchActivityFeed(refresh: Bool = false) async {
        guard let url = URL(string: "\(baseURL)/activity-feed/?limit=\(pageLimit)&offset=\(refresh ? 0 : currentOffset)") else { return }
        guard let request = await HTTPClient.shared.makeRequest(url: url) else {
            errorMessage = "No authentication token"
            return
        }

        if refresh {
            currentOffset = 0
        }

        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let feedResponse = try JSONDecoder().decode(ActivityFeedResponse.self, from: data)

            if refresh {
                activities = feedResponse.activities
            } else {
                activities.append(contentsOf: feedResponse.activities)
            }

            hasMoreActivities = feedResponse.hasMore
            currentOffset += feedResponse.activities.count

            #if DEBUG
            print("📊 Fetched \(feedResponse.activities.count) activities, total: \(activities.count)")
            #endif

        } catch {
            errorMessage = "Error loading activity feed: \(error.localizedDescription)"
            #if DEBUG
            print("❌ ActivityService fetch error: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Load more activities (pagination)
    func loadMoreActivities() async {
        guard hasMoreActivities, !isLoading else { return }
        await fetchActivityFeed(refresh: false)
    }

    // MARK: - Realtime Stats

    /// Fetches realtime gym statistics
    func fetchRealtimeStats() async {
        guard let url = URL(string: "\(baseURL)/activity-feed/realtime") else { return }
        guard let request = await HTTPClient.shared.makeRequest(url: url) else { return }

        // Preservar valores anteriores en caso de error
        let previousTotalTraining = totalTraining
        let previousIsPeakTime = isPeakTime
        let previousRealtimeStats = realtimeStats

        isLoadingRealtime = true

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let realtimeResponse = try JSONDecoder().decode(RealtimeResponse.self, from: data)
            realtimeStats = realtimeResponse.data
            totalTraining = realtimeResponse.data.totalTraining
            isPeakTime = realtimeResponse.data.peakTime

            #if DEBUG
            print("📊 Realtime: \(totalTraining) training, peak: \(isPeakTime)")
            #endif

        } catch {
            // Restaurar valores anteriores si teníamos datos válidos
            if previousTotalTraining > 0 {
                totalTraining = previousTotalTraining
                isPeakTime = previousIsPeakTime
                realtimeStats = previousRealtimeStats
                #if DEBUG
                print("⚠️ Realtime stats error, preservando datos anteriores: \(previousTotalTraining) training")
                #endif
            } else {
                #if DEBUG
                print("❌ Realtime stats error: \(error)")
                #endif
            }
        }

        isLoadingRealtime = false
    }

    /// Starts periodic realtime stats refresh
    func startRealtimeUpdates(interval: TimeInterval = 30) {
        stopRealtimeUpdates()
        realtimeRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchRealtimeStats()
            }
        }
        // Initial fetch
        Task {
            await fetchRealtimeStats()
        }
    }

    /// Stops periodic realtime stats refresh
    func stopRealtimeUpdates() {
        realtimeRefreshTimer?.invalidate()
        realtimeRefreshTimer = nil
    }

    // MARK: - Rankings

    /// Fetches rankings for a specific type and period
    func fetchRankings(type: RankingType = .attendance, period: RankingPeriod = .daily, limit: Int = 10) async {
        guard let url = URL(string: "\(baseURL)/activity-feed/rankings/\(type.rawValue)?period=\(period.rawValue)&limit=\(limit)") else { return }
        guard let request = await HTTPClient.shared.makeRequest(url: url) else { return }

        isLoadingRankings = true

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let rankingsResponse = try JSONDecoder().decode(RankingsResponse.self, from: data)
            currentRankings = rankingsResponse.rankings
            rankingsUnit = rankingsResponse.unit

            #if DEBUG
            print("📊 Rankings: \(currentRankings.count) entries for \(type.rawValue)")
            #endif

        } catch {
            #if DEBUG
            print("❌ Rankings error: \(error)")
            #endif
        }

        isLoadingRankings = false
    }

    // MARK: - Insights

    /// Fetches motivational insights
    func fetchInsights() async {
        guard let url = URL(string: "\(baseURL)/activity-feed/insights") else { return }
        guard let request = await HTTPClient.shared.makeRequest(url: url) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let insightsResponse = try JSONDecoder().decode(InsightsResponse.self, from: data)
            insights = insightsResponse.insights.sorted { $0.priority < $1.priority }
            topInsight = insights.first

            #if DEBUG
            print("📊 Insights: \(insights.count) loaded")
            #endif

        } catch {
            #if DEBUG
            print("❌ Insights error: \(error)")
            #endif
        }
    }

    // MARK: - Daily Summary

    /// Fetches daily summary statistics
    func fetchDailySummary() async {
        guard let url = URL(string: "\(baseURL)/activity-feed/stats/summary") else { return }
        guard let request = await HTTPClient.shared.makeRequest(url: url) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            dailySummary = try JSONDecoder().decode(DailySummaryResponse.self, from: data)

            #if DEBUG
            print("📊 Daily summary loaded: \(dailySummary?.stats.attendance ?? 0) attendance")
            #endif

        } catch {
            #if DEBUG
            print("❌ Daily summary error: \(error)")
            #endif
        }
    }

    // MARK: - Convenience Methods

    /// Fetches all activity feed data at once
    func fetchAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchActivityFeed(refresh: true) }
            group.addTask { await self.fetchRealtimeStats() }
            group.addTask { await self.fetchRankings() }
            group.addTask { await self.fetchInsights() }
        }
    }

    /// Refreshes all data
    func refreshAll() {
        Task {
            await fetchAllData()
        }
    }

    // MARK: - Legacy Support

    /// Loads achievements (legacy, maps to activity feed)
    func loadAchievements() async {
        await fetchActivityFeed(refresh: true)

        // Map activities to achievements for backwards compatibility
        achievements = activities.compactMap { activity in
            guard activity.type == "achievement_unlocked" ||
                  activity.type == "milestone" ||
                  activity.type == "pr_broken" else { return nil }

            return Achievement(
                id: activity.id.hashValue,
                type: activity.type,
                name: activity.message,
                description: activity.message,
                earnedAt: activity.timestamp,
                badgeIcon: mapActivityTypeToIcon(activity.type)
            )
        }
    }

    private func mapActivityTypeToIcon(_ type: String) -> String {
        switch type {
        case "achievement_unlocked": return "star.fill"
        case "milestone": return "flag.checkered"
        case "pr_broken": return "trophy.fill"
        case "streak_milestone": return "flame.fill"
        default: return "star.fill"
        }
    }

    func refreshAchievements() {
        Task {
            await loadAchievements()
        }
    }

    // MARK: - Deinit

    deinit {
        realtimeRefreshTimer?.invalidate()
        #if DEBUG
        print("🗑️ ActivityService deinitialized")
        #endif
    }
}
