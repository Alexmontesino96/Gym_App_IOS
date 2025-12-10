//
//  UnifiedChatService.swift
//  Gym_API
//
//  Servicio unificado para todas las operaciones de chat
//  Consolida: ChatService, DirectMessageService
//  Created as part of Phase 2 - Service Consolidation
//

import Foundation
import Combine
import SwiftUI

// MARK: - Chat Room Model (Unified)
struct UnifiedChatRoom: Codable, Identifiable {
    let id: Int
    let name: String?
    let isDirect: Bool
    let eventId: Int?
    let streamChannelId: String
    let streamChannelType: String
    let createdAt: Date
    let lastMessageAt: Date?
    let lastMessageText: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isDirect = "is_direct"
        case eventId = "event_id"
        case streamChannelId = "stream_channel_id"
        case streamChannelType = "stream_channel_type"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case lastMessageText = "last_message_text"
    }

    // MARK: - Computed Properties
    var chatType: ChatType {
        if isDirect {
            return .direct
        } else if eventId != nil {
            return .event
        } else {
            return .general
        }
    }

    var displayName: String {
        let safeName = name ?? "Direct chat"
        switch chatType {
        case .direct:
            let cleanName = safeName.replacingOccurrences(of: "Chat with ", with: "")
                                    .replacingOccurrences(of: "Chat ", with: "")
            if cleanName.hasPrefix("auth0") {
                return "Direct Message"
            }
            return cleanName
        case .event:
            return safeName.replacingOccurrences(of: "Event ", with: "")
        case .general:
            return safeName
        }
    }

    var iconName: String {
        switch chatType {
        case .direct:
            return "person.circle.fill"
        case .event:
            return "calendar.circle.fill"
        case .general:
            return "bubble.left.and.bubble.right.fill"
        }
    }

    var effectiveDate: Date {
        return lastMessageAt ?? createdAt
    }

    var lastMessageFormattedDate: String {
        let date = effectiveDate
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    var truncatedLastMessage: String {
        guard let text = lastMessageText, !text.isEmpty else {
            return "New chat"
        }
        return text.count > 50 ? String(text.prefix(50)) + "..." : text
    }

    var displayInitials: String {
        let name = displayName
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].first ?? "?") + String(words[1].first ?? "?")
        } else if let firstChar = name.first {
            return String(firstChar).uppercased()
        } else {
            return "?"
        }
    }
}




// MARK: - Unified Chat Service
@MainActor
final class UnifiedChatService: ObservableObject {

    // MARK: - Singleton
    static let shared = UnifiedChatService()

    // MARK: - Published Properties

    // Chat Rooms
    @Published var chatRooms: [UnifiedChatRoom] = []
    @Published var isLoadingRooms = false
    @Published var roomsErrorMessage: String?

    // Stream.io
    @Published var streamToken: StreamTokenResponse?
    @Published var isConnectedToStream = false
    @Published var isLoadingToken = false

    // Users
    @Published var allUsers: [UserProfile] = []
    @Published var isLoadingUsers = false
    @Published var usersErrorMessage: String?

    // MIGRADO A UserDataCacheService - caché centralizado
    private let userCache = UserDataCacheService.shared

    // General State
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let baseURL = apiBaseURL // Using environment-based URL
    private let session = URLSession.shared
    private weak var authService: AuthServiceDirect?

    // Stream Configuration
    private let streamAPIKey = StreamConfig.apiKey

    // Request Management
    private var currentMyRoomsTask: Task<Void, Never>?
    private var currentTokenTask: Task<StreamTokenResponse?, Never>?

    // Current User
    private var currentUserId: Int?

    // Gym Service Reference
    private var currentGymId: Int {
        return GymService.shared.currentGymId ?? 4
    }

    // MARK: - Initialization
    private init() {
        print("✅ UnifiedChatService initialized")
    }

    // MARK: - Configuration
    func configure(authService: AuthServiceDirect, userId: Int? = nil) {
        self.authService = authService
        if let userId = userId {
            self.currentUserId = userId
        } else if let userIdString = authService.user?.id {
            self.currentUserId = Int(userIdString)
        }
        print("🔧 UnifiedChatService configured with user: \(currentUserId ?? -1)")
    }

    // MARK: - Chat Room Management

    /// Get all chat rooms for current user
    func getMyRooms() async {
        // Cancel any existing request
        currentMyRoomsTask?.cancel()

        isLoadingRooms = true
        roomsErrorMessage = nil

        currentMyRoomsTask = Task {
            guard !Task.isCancelled else { return }

            do {
                guard let authService = authService,
                      let token = await authService.getValidAccessToken() else {
                    throw ChatServiceError.authenticationRequired
                }

                let rooms = try await fetchChatRooms(token: token)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.chatRooms = rooms
                    self.isLoadingRooms = false
                    self.persistChatRooms(rooms)
                }

                print("✅ Loaded \(rooms.count) chat rooms")

            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.roomsErrorMessage = error.localizedDescription
                    self.isLoadingRooms = false
                    self.loadPersistedChatRooms()
                }

                print("❌ Error loading rooms: \(error)")
            }
        }
    }

    /// Create or get direct chat with another user
    func getOrCreateDirectChat(with otherUserId: Int) async -> UnifiedChatRoom? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            guard let authService = authService,
                  let token = await authService.getValidAccessToken() else {
                throw ChatServiceError.authenticationRequired
            }

            let urlString = "\(baseURL)/chat/rooms/direct/\(otherUserId)"
            guard let url = URL(string: urlString) else {
                throw ChatServiceError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatServiceError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
                let chatRoom = try decoder.decode(UnifiedChatRoom.self, from: data)

                // Update local cache
                if !chatRooms.contains(where: { $0.id == chatRoom.id }) {
                    chatRooms.append(chatRoom)
                    persistChatRooms(chatRooms)
                }

                print("✅ Direct chat created/retrieved: \(chatRoom.streamChannelId)")
                return chatRoom
            } else {
                throw ChatServiceError.httpError(httpResponse.statusCode)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error creating direct chat: \(error)")
            return nil
        }
    }

    /// Create room for event
    func createRoomForEvent(eventId: Int, eventTitle: String) async throws -> UnifiedChatRoom {
        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            throw ChatServiceError.authenticationRequired
        }

        let urlString = "\(baseURL)/chat/rooms"
        guard let url = URL(string: urlString) else {
            throw ChatServiceError.invalidURL
        }

        let payload = [
            "name": "Event - \(eventTitle)",
            "is_direct": false,
            "event_id": eventId
        ] as [String: Any]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
            let chatRoom = try decoder.decode(UnifiedChatRoom.self, from: data)

            // Update local cache
            if !chatRooms.contains(where: { $0.id == chatRoom.id }) {
                chatRooms.append(chatRoom)
                persistChatRooms(chatRooms)
            }

            print("✅ Event chat room created: \(chatRoom.streamChannelId)")
            return chatRoom
        } else {
            throw ChatServiceError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Stream.io Token Management

    /// Get Stream.io token for current user
    func getStreamToken() async -> StreamTokenResponse? {
        // Cancel any existing request
        currentTokenTask?.cancel()

        isLoadingToken = true

        currentTokenTask = Task {
            guard !Task.isCancelled else { return nil }

            do {
                guard let authService = authService,
                      let token = await authService.getValidAccessToken() else {
                    throw ChatServiceError.authenticationRequired
                }

                let streamToken = try await fetchStreamToken(token: token)

                guard !Task.isCancelled else { return nil }

                await MainActor.run {
                    self.streamToken = streamToken
                    self.isConnectedToStream = true
                    self.isLoadingToken = false
                }

                print("✅ Stream token obtained")
                return streamToken

            } catch {
                guard !Task.isCancelled else { return nil }

                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoadingToken = false
                }

                print("❌ Error getting Stream token: \(error)")
                return nil
            }
        }

        return await currentTokenTask?.value
    }

    // MARK: - User Management

    /// Load all users in gym
    func loadAllUsers() async {
        isLoadingUsers = true
        usersErrorMessage = nil

        do {
            guard let authService = authService,
                  let token = await authService.getValidAccessToken() else {
                throw ChatServiceError.authenticationRequired
            }

            let urlString = "\(baseURL)/users/p/gym-participants?skip=0&limit=100"
            guard let url = URL(string: urlString) else {
                throw ChatServiceError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatServiceError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
                let users = try decoder.decode([UserProfile].self, from: data)

                await MainActor.run {
                    self.allUsers = users
                    self.isLoadingUsers = false

                    // Actualizar caché centralizado
                    self.userCache.updateUserProfiles(users)
                }

                print("✅ Loaded \(users.count) users")
            } else {
                throw ChatServiceError.httpError(httpResponse.statusCode)
            }
        } catch {
            usersErrorMessage = error.localizedDescription
            isLoadingUsers = false
            print("❌ Error loading users: \(error)")
        }
    }

    /// Get user profile by ID
    func getUserProfile(userId: Int) async -> UserProfile? {
        // Check cache first
        if let cached = await userCache.getUserProfile(userId) {
            return cached
        }

        // Fetch from API
        do {
            guard let authService = authService,
                  let token = await authService.getValidAccessToken() else {
                throw ChatServiceError.authenticationRequired
            }

            let urlString = "\(baseURL)/users/profile/\(userId)"
            guard let url = URL(string: urlString) else {
                throw ChatServiceError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatServiceError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
                let profile = try decoder.decode(UserProfile.self, from: data)

                // Actualizar caché centralizado
                userCache.updateUserProfile(userId, profile: profile)

                return profile
            }
        } catch {
            print("❌ Error fetching user profile: \(error)")
        }

        return nil
    }

    // MARK: - Private Helper Methods

    /// Fetch chat rooms from API
    private func fetchChatRooms(token: String) async throws -> [UnifiedChatRoom] {
        let urlString = "\(baseURL)/chat/my-rooms"
        guard let url = URL(string: urlString) else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
            return try decoder.decode([UnifiedChatRoom].self, from: data)
        } else {
            throw ChatServiceError.httpError(httpResponse.statusCode)
        }
    }

    /// Fetch Stream token from API
    private func fetchStreamToken(token: String) async throws -> StreamTokenResponse {
        let urlString = "\(baseURL)/chat/token"
        guard let url = URL(string: urlString) else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(StreamTokenResponse.self, from: data)
        } else {
            throw ChatServiceError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Persistence

    /// Persist chat rooms to UserDefaults
    private func persistChatRooms(_ rooms: [UnifiedChatRoom]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(rooms)
            UserDefaults.standard.set(data, forKey: "unifiedChatRooms")
            print("💾 Persisted \(rooms.count) chat rooms")
        } catch {
            print("❌ Error persisting chat rooms: \(error)")
        }
    }

    /// Load persisted chat rooms from UserDefaults
    private func loadPersistedChatRooms() {
        guard let data = UserDefaults.standard.data(forKey: "unifiedChatRooms") else { return }

        do {
            let decoder = JSONDecoder()
            let rooms = try decoder.decode([UnifiedChatRoom].self, from: data)
            self.chatRooms = rooms
            print("💾 Loaded \(rooms.count) persisted chat rooms")
        } catch {
            print("❌ Error loading persisted chat rooms: \(error)")
        }
    }

    /// Clear all cached data
    func clearCache() {
        chatRooms.removeAll()
        // Caché manejado por UserDataCacheService
        UserDefaults.standard.removeObject(forKey: "unifiedChatRooms")
        print("🗑️ Cache cleared")
    }

    // MARK: - Stream Channel ID Utilities

    /// Extract channel type from stream channel ID
    func getChannelType(from channelId: String) -> ChatChannelType {
        if channelId.starts(with: "messaging:direct-") {
            return .direct
        } else if channelId.starts(with: "messaging:event-") {
            return .event
        }
        return .general
    }

    /// Parse stream channel ID to extract metadata
    func parseStreamChannelId(_ channelId: String) -> (type: String, metadata: [String: String]) {
        var metadata: [String: String] = [:]

        if channelId.starts(with: "messaging:direct-") {
            let idPart = channelId.replacingOccurrences(of: "messaging:direct-", with: "")
            let users = idPart.split(separator: "-").map(String.init)
            if users.count >= 2 {
                metadata["userId1"] = users[0]
                metadata["userId2"] = users[1]
            }
            return ("direct", metadata)
        } else if channelId.starts(with: "messaging:event-") {
            let eventId = channelId.replacingOccurrences(of: "messaging:event-", with: "")
            metadata["eventId"] = eventId
            return ("event", metadata)
        }

        return ("general", metadata)
    }

    // MARK: - Cleanup
    deinit {
        currentMyRoomsTask?.cancel()
        currentTokenTask?.cancel()
        #if DEBUG
        print("🗑️ UnifiedChatService deinitialized")
        #endif
    }
}

// MARK: - Chat Service Errors
enum ChatServiceError: LocalizedError {
    case authenticationRequired
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError

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
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
    ]

    for format in dateFormatters {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = formatter.date(from: dateString) {
            return date
        }
    }

    throw ChatServiceError.decodingError
}

