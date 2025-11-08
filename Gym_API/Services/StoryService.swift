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
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute

    init() {
        print("DEBUG: StoryService initialized")
    }

    // MARK: - Fetch Stories Feed
    func fetchStoriesFeed(filter: StoryFilter = .all, forceRefresh: Bool = false) async {
        // Check cache if not forcing refresh
        if !forceRefresh, let cached = feedCache, let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            self.feedStories = cached
            return
        }

        print("DEBUG: 📱 StoryService: Obteniendo feed de stories (filter: \(filter.rawValue))")

        isLoading = true
        errorMessage = nil

        do {
            guard let token = await authService?.getValidAccessToken() else {
                print("DEBUG: ❌ StoryService: Error obteniendo token para feed")
                throw NSError(domain: "StoryService", code: 401,
                             userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
            }

            let url = URL(string: "\(baseURL)/stories/feed")!
            print("DEBUG: 🔗 StoryService: URL del feed: \(url.absoluteString)")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "filter_type", value: filter.rawValue),
                URLQueryItem(name: "limit", value: "25")
            ]

            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "StoryService", code: 0,
                             userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let feedResponse = try decoder.decode(StoryFeedResponse.self, from: data)

                print("DEBUG: ✅ StoryService: Feed obtenido exitosamente - \(feedResponse.userStories.count) usuarios con stories")

                await MainActor.run {
                    self.feedStories = feedResponse.userStories
                    self.feedCache = feedResponse.userStories
                    self.cacheTimestamp = Date()
                    self.isLoading = false
                    print("DEBUG:💾 StoryService: Feed guardado en caché")
                }
            } else {
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
            guard let token = await authService?.getValidAccessToken() else {
                print("DEBUG:❌ StoryService: No se pudo obtener token de autenticación")
                throw NSError(domain: "StoryService", code: 401,
                             userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
            }

            print("DEBUG:✅ StoryService: Token obtenido correctamente")

            let url = URL(string: "\(baseURL)/stories/")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            // Create form data
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)",
                           forHTTPHeaderField: "Content-Type")

            var body = Data()

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
                body.append(mediaData)
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

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
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
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
            guard let token = await authService?.getValidAccessToken() else {
                print("DEBUG:⚠️ StoryService: No se pudo obtener token para marcar como visto")
                return
            }

            let url = URL(string: "\(baseURL)/stories/\(storyId)/view")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
            guard let token = await authService?.getValidAccessToken() else {
                print("DEBUG:⚠️ StoryService: No se pudo obtener token para añadir reacción")
                return false
            }

            guard FitnessEmoji.isValid(emoji) else {
                print("DEBUG:❌ StoryService: Emoji no válido: \(emoji)")
                errorMessage = "Emoji no válido"
                return false
            }

            let url = URL(string: "\(baseURL)/stories/\(storyId)/reaction")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
            guard let token = await authService?.getValidAccessToken() else { return nil }

            let url = URL(string: "\(baseURL)/stories/\(storyId)/viewers")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([StoryViewer].self, from: data)
        } catch {
            print("DEBUG: Error fetching viewers: \(error)")
            return nil
        }
    }

    // MARK: - Delete Story
    func deleteStory(storyId: Int) async -> Bool {
        do {
            guard let token = await authService?.getValidAccessToken() else { return false }

            let url = URL(string: "\(baseURL)/stories/\(storyId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

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
            guard let token = await authService?.getValidAccessToken() else { return false }

            let url = URL(string: "\(baseURL)/stories/\(storyId)/report")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                var updatedStory = updatedStories[storyIndex]

                // Create a new story with updated hasViewed
                // Note: Since Story is struct, we need to recreate it
                // This is a simplified version - in production you'd properly copy all fields
                feedStories[index] = UserStoryGroup(
                    userId: group.userId,
                    userName: group.userName,
                    userAvatar: group.userAvatar,
                    hasUnseen: group.hasUnseen,
                    stories: updatedStories
                )
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
    }

    deinit {
        print("DEBUG: StoryService deallocated")
    }
}