//
//  StoryService.swift
//  Gym_API
//
//  Created on November 2024
//

import Foundation
import Combine
import UIKit

@MainActor
class StoryService: ObservableObject {
    // MARK: - Published Properties
    @Published var feedStories: [UserStoryGroup] = []
    @Published var myStories: [Story] = []
    @Published var currentViewingStory: Story?
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Dependencies
    var authService: AuthServiceDirect?
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"

    // MARK: - Cache
    private var feedCache: [UserStoryGroup]?
    private var cacheTimestamp: Date?
    private var cachedGymId: Int? // Track which gym the cache is for
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    init() {
        print("DEBUG: StoryService initialized")
    }

    // MARK: - Fetch Stories Feed
    func fetchStoriesFeed(filter: StoryFilter = .all, forceRefresh: Bool = false) async {
        let currentGymId = GymService.shared.currentGymId
        print("DEBUG: 📸 StoryService.fetchStoriesFeed called (gym: \(currentGymId ?? 0), forceRefresh: \(forceRefresh))")

        // Check cache if not forcing refresh
        if !forceRefresh {
            if let cached = feedCache, let timestamp = cacheTimestamp, let cachedGym = cachedGymId {
                let cacheAge = Date().timeIntervalSince(timestamp)
                let gymMatches = cachedGym == currentGymId
                print("DEBUG: 💾 Cache found - Age: \(Int(cacheAge))s / Valid: \(Int(cacheValidityDuration))s / Gym matches: \(gymMatches)")

                if cacheAge < cacheValidityDuration && gymMatches {
                    if cached.isEmpty {
                        print("DEBUG: ⚠️ Cached stories is empty, bypassing cache to fetch fresh data")
                    } else {
                        print("DEBUG: ✅ Using cached stories (\(cached.count) users)")
                        await MainActor.run {
                            self.feedStories = cached
                        }
                        return
                    }
                } else if !gymMatches {
                    print("DEBUG: 🏋️ Gym changed (cached: \(cachedGym), current: \(currentGymId ?? 0)), fetching fresh data")
                } else {
                    print("DEBUG: ⏰ Cache expired, fetching fresh data")
                }
            } else {
                print("DEBUG: ❌ No cache available")
            }
        } else {
            print("DEBUG: 🔄 Force refresh requested, bypassing cache")
        }

        print("DEBUG: 📱 StoryService: Obteniendo feed de stories (filter: \(filter.rawValue))")

        isLoading = true
        errorMessage = nil

        do {
            let url = URL(string: "\(baseURL)/stories/feed")!
            print("DEBUG: 🔗 StoryService: URL del feed: \(url.absoluteString)")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var query: [URLQueryItem] = [
                URLQueryItem(name: "limit", value: "25"),
                URLQueryItem(name: "offset", value: "0")
            ]
            // Do NOT send filter_type when it's the default (.all) — backend may treat missing differently
            if filter != .all {
                query.append(URLQueryItem(name: "filter_type", value: filter.rawValue))
            }
            components.queryItems = query

            guard var request = await HTTPClient.shared.makeRequest(url: components.url!, method: "GET") else {
                print("DEBUG: ❌ StoryService: No auth (HTTPClient) para obtener feed")
                throw NSError(domain: "StoryService", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
            }
            // Prefer Accept over Content-Type on GET
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            // Agregar X-Gym-ID si está disponible (HTTPClient ya intenta hacerlo)
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
                print("DEBUG: 🏋️ StoryService: X-Gym-ID agregado: \(gymId)")
            } else {
                print("DEBUG: ⚠️ StoryService: X-Gym-ID no disponible")
            }

            // Log final URL and headers
            print("DEBUG:🔗 Feed final URL: \(request.url?.absoluteString ?? components.url!.absoluteString)")
            print("DEBUG:📋 Feed Request Headers:")
            request.allHTTPHeaderFields?.forEach { print("DEBUG:   \($0.key): \($0.value)") }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "StoryService", code: 0,
                             userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                    // Try: "2025-11-12T06:14:09.045286Z" (with microseconds AND Z)
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }

                    // Try: "2025-11-09T09:24:12.747377" (with microseconds, no timezone)
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }

                    // Try: without microseconds but with Z
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }

                    // Try: without microseconds and no Z
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }

                    // Fallback: try ISO8601 standard
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = isoFormatter.date(from: dateString) {
                        return date
                    }

                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                let feedResponse = try decoder.decode(StoryFeedResponse.self, from: data)

                print("DEBUG: ✅ StoryService: Feed obtenido exitosamente - \(feedResponse.userStories.count) usuarios con stories")

                await MainActor.run {
                    self.feedStories = feedResponse.userStories
                    self.feedCache = feedResponse.userStories
                    self.cacheTimestamp = Date()
                    self.cachedGymId = currentGymId
                    self.isLoading = false
                    print("DEBUG:💾 StoryService: Feed guardado en caché (gym: \(currentGymId ?? 0), \(feedResponse.userStories.count) users)")
                }
            } else {
                if let body = String(data: data, encoding: .utf8) {
                    print("DEBUG:❌ Feed error body: \(body)")
                }
                print("DEBUG:❌ StoryService: Error HTTP \(httpResponse.statusCode) al obtener feed")
                throw NSError(domain: "StoryService", code: httpResponse.statusCode,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to fetch stories"])
            }
        } catch {
            print("DEBUG:❌ StoryService: Error obteniendo feed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("DEBUG: Error fetching stories: \(error)")
            }
        }
    }

    // MARK: - Create Story
    func createStory(
        type: StoryType,
        caption: String? = nil,
        mediaData: Data? = nil,
        workoutData: WorkoutData? = nil,
        privacy: StoryPrivacy = .public,
        duration: Int = 24
    ) async -> Story? {
        print("DEBUG:📸 StoryService: Iniciando creación de story tipo: \(type.rawValue)")
        print("DEBUG:📊 StoryService: Privacidad: \(privacy.rawValue), Duración: \(duration)h")

        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        do {
            // Use trailing slash to avoid 307/308 redirects that can drop Authorization headers
            let url = URL(string: "\(baseURL)/stories/")!
            guard var request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
                print("DEBUG:❌ StoryService: No auth (HTTPClient) al crear story")
                throw NSError(domain: "StoryService", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
            }

            // Asegurar X-Gym-ID header requerido (HTTPClient ya lo agrega si está configurado)
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
                print("DEBUG:🏋️ X-Gym-ID header agregado: \(gymId)")
            } else {
                print("DEBUG:⚠️ X-Gym-ID NO está disponible - esto causará error 403")
            }

            // Ensure Authorization present (fallback if HTTPClient missing auth)
            if request.value(forHTTPHeaderField: "Authorization") == nil {
                if let token = await authService?.getValidAccessToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    print("DEBUG:🔒 Authorization header inyectado manualmente en createStory")
                } else {
                    print("DEBUG:❌ No se pudo inyectar Authorization: token no disponible")
                }
            }

            // Create form data
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)",
                           forHTTPHeaderField: "Content-Type")

            var body = Data()
            // Reserve capacity to reduce re-allocations during multipart assembly
            if let mediaData = mediaData {
                body.reserveCapacity(mediaData.count + 8192)
            }

            // Add form fields
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"story_type\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(type.rawValue)\r\n".data(using: .utf8)!)

            if let caption = caption {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(caption)\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"privacy\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(privacy.rawValue)\r\n".data(using: .utf8)!)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"duration_hours\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(duration)\r\n".data(using: .utf8)!)

            // Add workout data if present
            if let workoutData = workoutData {
                let encoder = JSONEncoder()
                let workoutJSON = try encoder.encode(workoutData)
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"workout_data\"\r\n\r\n".data(using: .utf8)!)
                body.append(workoutJSON)
                body.append("\r\n".data(using: .utf8)!)
            }

            // Add media if present
            if let mediaData = mediaData {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                let filename = type == .video ? "story.mp4" : "story.jpg"
                let mimeType = type == .video ? "video/mp4" : "image/jpeg"
                body.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                // Append within autoreleasepool to reduce peak memory
                autoreleasepool {
                    body.append(mediaData)
                }
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            // Log request headers for debugging (including Authorization token)
            print("DEBUG:📋 Request Headers (including Authorization token)")
            var hasAuthHeader = false
            request.allHTTPHeaderFields?.forEach { key, value in
                if key.lowercased() == "authorization" {
                    hasAuthHeader = true
                }
                print("DEBUG:   \(key): \(value)")
            }
            let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? "nil"
            print("DEBUG:🔎 Authorization presente: \(hasAuthHeader) | Header: \(authHeader)")

            // Simulate upload progress
            Task {
                for progress in stride(from: 0.0, through: 0.9, by: 0.1) {
                    await MainActor.run {
                        self.uploadProgress = progress
                    }
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "StoryService", code: 0,
                             userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                let decoder = DateDecoding.serverDecoder()
                let story = try decoder.decode(Story.self, from: data)

                await MainActor.run {
                    self.myStories.append(story)
                    self.uploadProgress = 1.0
                    self.isUploading = false
                    self.successMessage = "Historia publicada exitosamente"

                    // Refresh feed to show new story
                    Task {
                        await self.fetchStoriesFeed(forceRefresh: true)
                    }
                }

                return story
            } else {
                // Log error response body for debugging
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("DEBUG:❌ Error response body: \(errorBody)")
                }
                print("DEBUG:❌ HTTP Status Code: \(httpResponse.statusCode)")
                print("DEBUG:❌ Response Headers: \(httpResponse.allHeaderFields)")

                throw NSError(domain: "StoryService", code: httpResponse.statusCode,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create story"])
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isUploading = false
                self.uploadProgress = 0.0
                print("DEBUG: Error creating story: \(error)")
            }
            return nil
        }
    }

    // MARK: - Mark Story as Viewed
    func markAsViewed(storyId: Int, duration: Int? = nil) async {
        print("DEBUG:👁️ StoryService: Marcando story \(storyId) como visto")

        do {
            let url = URL(string: "\(baseURL)/stories/\(storyId)/view")!
            guard var request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
                print("DEBUG:⚠️ StoryService: No auth (HTTPClient) para marcar como visto")
                return
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Agregar X-Gym-ID header requerido
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
            }

            var body: [String: Any] = ["device_info": "iOS"]
            if let duration = duration {
                body["view_duration_seconds"] = duration
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Update local state
                await MainActor.run {
                    self.updateStoryViewedState(storyId: storyId)
                }
            }
        } catch {
            print("DEBUG: Error marking story as viewed: \(error)")
        }
    }

    // MARK: - Add Reaction
    func addReaction(storyId: Int, emoji: String, message: String? = nil) async -> Bool {
        print("DEBUG:💪 StoryService: Añadiendo reacción \(emoji) a story \(storyId)")

        do {
            guard FitnessEmoji.isValid(emoji) else {
                print("DEBUG:❌ StoryService: Emoji no válido: \(emoji)")
                errorMessage = "Emoji no válido"
                return false
            }

            let url = URL(string: "\(baseURL)/stories/\(storyId)/reaction")!
            guard var request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
                print("DEBUG:⚠️ StoryService: No auth (HTTPClient) para reacción")
                return false
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Agregar X-Gym-ID header requerido
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
            }

            let body: [String: Any] = [
                "emoji": emoji,
                "message": message ?? ""
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.successMessage = "Reacción agregada"
                    self.updateStoryReactionState(storyId: storyId)
                }
                return true
            }
            return false
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Fetch Story Viewers
    func fetchViewers(storyId: Int) async -> [StoryViewer]? {
        do {
            let url = URL(string: "\(baseURL)/stories/\(storyId)/viewers")!
            guard var request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else { return nil }

            // Agregar X-Gym-ID header requerido
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let decoder = DateDecoding.serverDecoder()
            return try decoder.decode([StoryViewer].self, from: data)
        } catch {
            print("DEBUG: Error fetching viewers: \(error)")
            return nil
        }
    }

    // MARK: - Delete Story
    func deleteStory(storyId: Int) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/stories/\(storyId)")!
            guard var request = await HTTPClient.shared.makeRequest(url: url, method: "DELETE") else { return false }

            // Agregar X-Gym-ID header requerido
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
            }

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.myStories.removeAll { $0.id == storyId }
                    self.successMessage = "Historia eliminada"

                    // Refresh feed
                    Task {
                        await self.fetchStoriesFeed(forceRefresh: true)
                    }
                }
                return true
            }
            return false
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Report Story
    func reportStory(storyId: Int, reason: StoryReportReason, description: String) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/stories/\(storyId)/report")!
            guard var request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else { return false }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Agregar X-Gym-ID header requerido
            if let gymId = GymService.shared.currentGymId {
                request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
            }

            let reportRequest = StoryReportRequest(reason: reason, description: description)
            request.httpBody = try JSONEncoder().encode(reportRequest)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.successMessage = "Historia reportada. Será revisada por los administradores."
                }
                return true
            }
            return false
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Helper Methods
    private func updateStoryViewedState(storyId: Int) {
        for (index, group) in feedStories.enumerated() {
            if let storyIndex = group.stories.firstIndex(where: { $0.id == storyId }) {
                var updatedStories = group.stories

                // Actualizar hasViewed en el story
                updatedStories[storyIndex].hasViewed = true

                // Recalcular hasUnseen: true si hay alguna historia sin ver y activa
                let hasUnseen = updatedStories.contains { story in
                    !story.hasViewed && story.isActive
                }

                // Crear un nuevo UserStoryGroup con los valores actualizados
                feedStories[index] = UserStoryGroup(
                    userId: group.userId,
                    userName: group.userName,
                    userAvatar: group.userAvatar,
                    hasUnseen: hasUnseen,
                    stories: updatedStories
                )

                print("DEBUG:✅ Story \(storyId) marcada como vista. hasUnseen: \(hasUnseen)")
                return
            }
        }
    }

    private func updateStoryReactionState(storyId: Int) {
        // Similar to updateStoryViewedState but for reactions
        // Implementation would update the hasReacted flag
    }


    // MARK: - Clear Cache
    func clearCache() {
        feedCache = nil
        cacheTimestamp = nil
        cachedGymId = nil
        print("DEBUG:🧹 StoryService: Cache cleared")
    }

    deinit {
        print("DEBUG: StoryService deallocated")
    }

    // MARK: - Helpers for UI Integration
    /// Returns the story group for a given user id if present in the current feed
    func userStoryGroup(for userId: Int) -> UserStoryGroup? {
        return feedStories.first(where: { $0.userId == userId })
    }

    /// Whether the given user has any active story in the current feed
    func hasActiveStory(for userId: Int) -> Bool {
        guard let group = userStoryGroup(for: userId) else { return false }
        return !group.activeStories.isEmpty
    }

    /// Count of unseen active stories for a given user
    func unseenCount(for userId: Int) -> Int {
        guard let group = userStoryGroup(for: userId) else { return 0 }
        return group.stories.filter { $0.isActive && !$0.hasViewed }.count
    }
}
