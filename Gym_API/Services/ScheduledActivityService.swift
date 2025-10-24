//
//  ScheduledActivityService.swift
//  Gym_API
//
//  Servicio unificado para todas las actividades programadas (eventos y clases)
//  Consolida funcionalidad común de: EventService, ClassService, EventCreationService, SessionCreationService
//  Created as part of Phase 2 - Service Consolidation
//

import Foundation
import Combine
import SwiftUI

// MARK: - Activity Type
enum ActivityType: String, CaseIterable {
    case event = "event"
    case gymClass = "class"
    case session = "session"

    var displayName: String {
        switch self {
        case .event: return "Evento"
        case .gymClass: return "Clase"
        case .session: return "Sesión"
        }
    }

    var iconName: String {
        switch self {
        case .event: return "calendar"
        case .gymClass: return "figure.run"
        case .session: return "clock"
        }
    }
}

// MARK: - Activity Status (Unified)
enum ActivityStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case active = "active"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .scheduled: return "Programado"
        case .active: return "Activo"
        case .inProgress: return "En Progreso"
        case .completed: return "Completado"
        case .cancelled: return "Cancelado"
        }
    }

    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .active, .inProgress: return "green"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }

    // Convert from EventStatus
    init(from eventStatus: EventStatus) {
        switch eventStatus {
        case .scheduled:
            self = .scheduled
        case .active:
            self = .active
        case .completed:
            self = .completed
        case .cancelled:
            self = .cancelled
        }
    }

    // Convert from SessionStatus
    init(from sessionStatus: String) {
        switch sessionStatus.lowercased() {
        case "scheduled":
            self = .scheduled
        case "in_progress", "in progress":
            self = .inProgress
        case "completed":
            self = .completed
        case "cancelled":
            self = .cancelled
        default:
            self = .scheduled
        }
    }
}

// MARK: - Scheduled Activity Protocol
protocol ScheduledActivity: Identifiable {
    var id: Int { get }
    var title: String { get }
    var description: String { get }
    var startTime: Date { get }
    var endTime: Date { get }
    var location: String { get }
    var maxParticipants: Int { get }
    var currentParticipants: Int { get }
    var activityStatus: ActivityStatus { get }
    var activityType: ActivityType { get }
    var instructorId: Int? { get }
    var instructorName: String? { get }
}

// MARK: - Event as Scheduled Activity
extension Event: ScheduledActivity {
    var currentParticipants: Int {
        return participantsCount
    }

    var activityStatus: ActivityStatus {
        return ActivityStatus(from: self.status)
    }

    var activityType: ActivityType {
        return .event
    }

    var instructorId: Int? {
        return creatorId
    }

    var instructorName: String? {
        return nil // To be resolved from user cache
    }
}

// MARK: - Session with Class Wrapper
struct SessionActivityWrapper: ScheduledActivity {
    let session: ClassSession
    let className: String
    let classDescription: String
    let trainerName: String?

    var id: Int { session.id }
    var title: String { className }
    var description: String { classDescription }
    var startTime: Date { session.startTime }
    var endTime: Date { session.endTime }
    var location: String { session.room ?? "TBD" }
    var maxParticipants: Int { session.overrideCapacity ?? 30 }
    var currentParticipants: Int { session.currentParticipants }
    var activityStatus: ActivityStatus { ActivityStatus(from: session.status.rawValue) }
    var activityType: ActivityType { .gymClass }
    var instructorId: Int? { session.trainerId }
    var instructorName: String? { trainerName }
}

// MARK: - Activity Creation Request
struct ActivityCreationRequest {
    let type: ActivityType
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let location: String
    let maxParticipants: Int
    let instructorId: Int?
    let isRecurring: Bool
    let recurrencePattern: String?
    let notes: String?
}

// MARK: - Activity Update Request
struct ActivityUpdateRequest {
    let id: Int
    let type: ActivityType
    let title: String?
    let description: String?
    let startTime: Date?
    let endTime: Date?
    let location: String?
    let maxParticipants: Int?
    let status: ActivityStatus?
    let instructorId: Int?
    let notes: String?
}

// MARK: - Activity Participation
struct ActivityParticipation: Identifiable {
    let id: Int
    let activityId: Int
    let activityType: ActivityType
    let userId: Int
    let status: String
    let joinedAt: Date
    let checkInTime: Date?
    let checkOutTime: Date?
}

// MARK: - Scheduled Activity Service
@MainActor
final class ScheduledActivityService: ObservableObject {

    // MARK: - Singleton
    static let shared = ScheduledActivityService()

    // MARK: - Published Properties

    // All activities
    @Published var allActivities: [any ScheduledActivity] = []
    @Published var isLoadingActivities = false
    @Published var activitiesError: String?

    // Events
    @Published var events: [Event] = []
    @Published var myEvents: [Event] = []
    @Published var isLoadingEvents = false

    // Classes/Sessions
    @Published var sessions: [SessionActivityWrapper] = []
    @Published var mySessions: [SessionActivityWrapper] = []
    @Published var isLoadingClasses = false

    // Participations
    @Published var myParticipations: [ActivityParticipation] = []
    @Published var isLoadingParticipations = false

    // Creation/Update State
    @Published var isCreating = false
    @Published var isUpdating = false
    @Published var operationError: String?

    // MARK: - Private Properties

    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    private weak var authService: AuthServiceDirect?
    private weak var gymService: GymService?

    // Cache
    private var activitiesCache: [String: [any ScheduledActivity]] = [:]
    private var trainersCache: [Int: String] = [:]

    // Request Management
    private var loadActivitiesTask: Task<Void, Never>?

    // MARK: - Initialization
    private init() {
        print("✅ ScheduledActivityService initialized")
    }

    // MARK: - Configuration
    func configure(authService: AuthServiceDirect, gymService: GymService) {
        self.authService = authService
        self.gymService = gymService
        print("🔧 ScheduledActivityService configured")
    }

    // MARK: - Public Methods

    /// Load all activities (events and classes)
    func loadAllActivities() async {
        loadActivitiesTask?.cancel()

        isLoadingActivities = true
        activitiesError = nil

        loadActivitiesTask = Task {
            guard !Task.isCancelled else { return }

            await withTaskGroup(of: Void.self) { group in
                // Load events
                group.addTask { [weak self] in
                    await self?.loadEvents()
                }

                // Load classes/sessions
                group.addTask { [weak self] in
                    await self?.loadSessions()
                }

                // Wait for both to complete
                await group.waitForAll()
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.combineAllActivities()
                self.isLoadingActivities = false
            }
        }
    }

    /// Create a new activity
    func createActivity(_ request: ActivityCreationRequest) async throws -> Int {
        isCreating = true
        operationError = nil

        defer { isCreating = false }

        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            throw ActivityServiceError.authenticationRequired
        }

        switch request.type {
        case .event:
            return try await createEvent(request, token: token)
        case .gymClass, .session:
            return try await createSession(request, token: token)
        }
    }

    /// Update an existing activity
    func updateActivity(_ request: ActivityUpdateRequest) async throws {
        isUpdating = true
        operationError = nil

        defer { isUpdating = false }

        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            throw ActivityServiceError.authenticationRequired
        }

        switch request.type {
        case .event:
            try await updateEvent(request, token: token)
        case .gymClass, .session:
            try await updateSession(request, token: token)
        }

        // Reload activities
        await loadAllActivities()
    }

    /// Cancel an activity
    func cancelActivity(id: Int, type: ActivityType) async throws {
        let request = ActivityUpdateRequest(
            id: id,
            type: type,
            title: nil,
            description: nil,
            startTime: nil,
            endTime: nil,
            location: nil,
            maxParticipants: nil,
            status: .cancelled,
            instructorId: nil,
            notes: nil
        )

        try await updateActivity(request)
    }

    /// Register for an activity
    func registerForActivity(activityId: Int, type: ActivityType) async throws {
        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            throw ActivityServiceError.authenticationRequired
        }

        let endpoint: String
        switch type {
        case .event:
            endpoint = "\(baseURL)/events/\(activityId)/register"
        case .gymClass, .session:
            endpoint = "\(baseURL)/classes/sessions/\(activityId)/register"
        }

        guard let url = URL(string: endpoint) else {
            throw ActivityServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let gymId = gymService?.currentGymId {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            throw ActivityServiceError.httpError(httpResponse.statusCode)
        }

        // Reload activities to update participant counts
        await loadAllActivities()

        print("✅ Registered for activity: \(activityId)")
    }

    /// Unregister from an activity
    func unregisterFromActivity(activityId: Int, type: ActivityType) async throws {
        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            throw ActivityServiceError.authenticationRequired
        }

        let endpoint: String
        switch type {
        case .event:
            endpoint = "\(baseURL)/events/\(activityId)/unregister"
        case .gymClass, .session:
            endpoint = "\(baseURL)/classes/sessions/\(activityId)/unregister"
        }

        guard let url = URL(string: endpoint) else {
            throw ActivityServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let gymId = gymService?.currentGymId {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw ActivityServiceError.httpError(httpResponse.statusCode)
        }

        // Reload activities
        await loadAllActivities()

        print("✅ Unregistered from activity: \(activityId)")
    }

    /// Get my participations
    func loadMyParticipations() async {
        isLoadingParticipations = true

        do {
            guard let authService = authService,
                  let token = await authService.getValidAccessToken() else {
                throw ActivityServiceError.authenticationRequired
            }

            // Load event participations
            let eventParticipations = try await fetchEventParticipations(token: token)

            // Load class participations
            let classParticipations = try await fetchClassParticipations(token: token)

            await MainActor.run {
                self.myParticipations = eventParticipations + classParticipations
                self.isLoadingParticipations = false
            }

            print("✅ Loaded \(myParticipations.count) participations")

        } catch {
            activitiesError = error.localizedDescription
            isLoadingParticipations = false
            print("❌ Error loading participations: \(error)")
        }
    }

    // MARK: - Private Helper Methods

    /// Load events
    private func loadEvents() async {
        isLoadingEvents = true

        do {
            guard let authService = authService,
                  let token = await authService.getValidAccessToken() else {
                throw ActivityServiceError.authenticationRequired
            }

            let events = try await fetchEvents(token: token)
            let myEvents = try await fetchMyEvents(token: token)

            await MainActor.run {
                self.events = events
                self.myEvents = myEvents
                self.isLoadingEvents = false
            }

            print("✅ Loaded \(events.count) events")

        } catch {
            await MainActor.run {
                self.activitiesError = error.localizedDescription
                self.isLoadingEvents = false
            }
            print("❌ Error loading events: \(error)")
        }
    }

    /// Load sessions/classes
    private func loadSessions() async {
        isLoadingClasses = true

        do {
            guard let authService = authService,
                  let token = await authService.getValidAccessToken() else {
                throw ActivityServiceError.authenticationRequired
            }

            let sessions = try await fetchSessions(token: token)
            let mySessions = try await fetchMySessions(token: token)

            await MainActor.run {
                self.sessions = sessions
                self.mySessions = mySessions
                self.isLoadingClasses = false
            }

            print("✅ Loaded \(sessions.count) sessions")

        } catch {
            await MainActor.run {
                self.activitiesError = error.localizedDescription
                self.isLoadingClasses = false
            }
            print("❌ Error loading sessions: \(error)")
        }
    }

    /// Combine all activities into a single array
    private func combineAllActivities() {
        var activities: [any ScheduledActivity] = []
        activities.append(contentsOf: events)
        activities.append(contentsOf: sessions)

        // Sort by start time
        activities.sort { $0.startTime < $1.startTime }

        self.allActivities = activities
    }

    /// Create event
    private func createEvent(_ request: ActivityCreationRequest, token: String) async throws -> Int {
        let urlString = "\(baseURL)/events"
        guard let url = URL(string: urlString) else {
            throw ActivityServiceError.invalidURL
        }

        let payload: [String: Any] = [
            "title": request.title,
            "description": request.description,
            "start_time": ISO8601DateFormatter().string(from: request.startTime),
            "end_time": ISO8601DateFormatter().string(from: request.endTime),
            "location": request.location,
            "max_participants": request.maxParticipants
        ]

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let gymId = gymService?.currentGymId {
            urlRequest.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityServiceError.invalidResponse
        }

        if httpResponse.statusCode != 201 && httpResponse.statusCode != 200 {
            throw ActivityServiceError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        let event = try decoder.decode(Event.self, from: data)

        return event.id
    }

    /// Create session
    private func createSession(_ request: ActivityCreationRequest, token: String) async throws -> Int {
        // Implementation would create a class session
        // This is a placeholder - actual implementation depends on backend API
        throw ActivityServiceError.notImplemented
    }

    /// Update event
    private func updateEvent(_ request: ActivityUpdateRequest, token: String) async throws {
        let urlString = "\(baseURL)/events/\(request.id)"
        guard let url = URL(string: urlString) else {
            throw ActivityServiceError.invalidURL
        }

        var payload: [String: Any] = [:]
        if let title = request.title { payload["title"] = title }
        if let description = request.description { payload["description"] = description }
        if let startTime = request.startTime {
            payload["start_time"] = ISO8601DateFormatter().string(from: startTime)
        }
        if let endTime = request.endTime {
            payload["end_time"] = ISO8601DateFormatter().string(from: endTime)
        }
        if let location = request.location { payload["location"] = location }
        if let maxParticipants = request.maxParticipants { payload["max_participants"] = maxParticipants }
        if let status = request.status { payload["status"] = status.rawValue }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let gymId = gymService?.currentGymId {
            urlRequest.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw ActivityServiceError.httpError(httpResponse.statusCode)
        }
    }

    /// Update session
    private func updateSession(_ request: ActivityUpdateRequest, token: String) async throws {
        // Implementation would update a class session
        throw ActivityServiceError.notImplemented
    }

    // MARK: - Fetch Methods

    /// Fetch all events
    private func fetchEvents(token: String) async throws -> [Event] {
        let urlString = "\(baseURL)/events?skip=0&limit=100"
        guard let url = URL(string: urlString) else {
            throw ActivityServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let gymId = gymService?.currentGymId {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
            return try decoder.decode([Event].self, from: data)
        } else {
            throw ActivityServiceError.httpError(httpResponse.statusCode)
        }
    }

    /// Fetch my events
    private func fetchMyEvents(token: String) async throws -> [Event] {
        let urlString = "\(baseURL)/events/my-participations?skip=0&limit=100"
        guard let url = URL(string: urlString) else {
            throw ActivityServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let gymId = gymService?.currentGymId {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        let (data, _) = try await session.data(for: request)

        // Parse participations and extract events
        // This would depend on the actual API response structure
        return []
    }

    /// Fetch sessions
    private func fetchSessions(token: String) async throws -> [SessionActivityWrapper] {
        // Implementation would fetch class sessions
        return []
    }

    /// Fetch my sessions
    private func fetchMySessions(token: String) async throws -> [SessionActivityWrapper] {
        // Implementation would fetch user's class sessions
        return []
    }

    /// Fetch event participations
    private func fetchEventParticipations(token: String) async throws -> [ActivityParticipation] {
        // Implementation would fetch event participations
        return []
    }

    /// Fetch class participations
    private func fetchClassParticipations(token: String) async throws -> [ActivityParticipation] {
        // Implementation would fetch class participations
        return []
    }

    // MARK: - Cache Management

    /// Clear all cached data
    func clearCache() {
        activitiesCache.removeAll()
        trainersCache.removeAll()
        allActivities.removeAll()
        events.removeAll()
        sessions.removeAll()
        myEvents.removeAll()
        mySessions.removeAll()
        myParticipations.removeAll()
        print("🗑️ Cache cleared")
    }

    // MARK: - Cleanup
    deinit {
        loadActivitiesTask?.cancel()
        #if DEBUG
        print("🗑️ ScheduledActivityService deinitialized")
        #endif
    }
}

// MARK: - Activity Service Errors
enum ActivityServiceError: LocalizedError {
    case authenticationRequired
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}

// MARK: - Date Decoding Helper
private func flexibleDateDecoder(_ decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let dateString = try container.decode(String.self)

    // Try ISO8601 first
    let iso8601Formatter = ISO8601DateFormatter()
    if let date = iso8601Formatter.date(from: dateString) {
        return date
    }

    // Try other date formats
    let dateFormatters = [
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'"
    ]

    for format in dateFormatters {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = formatter.date(from: dateString) {
            return date
        }
    }

    throw ActivityServiceError.decodingError
}