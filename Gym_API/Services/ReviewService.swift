import Foundation
import SwiftUI

// MARK: - Review Service

@MainActor
class ReviewService: ObservableObject {
    static let shared = ReviewService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    var authService: AuthServiceDirect?
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1/reviews"

    private init() {}

    deinit {
        #if DEBUG
        print("🗑️ ReviewService deinit")
        #endif
    }

    // MARK: - 1. Can Review

    func canReview(sessionId: Int) async -> CanReviewResponse? {
        guard let request = await makeRequest(path: "/session/\(sessionId)/can-review", method: "GET") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try configuredDecoder().decode(CanReviewResponse.self, from: data)
        } catch {
            print("❌ [ReviewService] canReview error: \(error)")
            return nil
        }
    }

    // MARK: - 2. Create Review

    func createReview(sessionId: Int, rating: Int, comment: String?) async -> ClassReview? {
        guard var request = await makeRequest(path: "/", method: "POST") else { return nil }

        let body = CreateReviewRequest(sessionId: sessionId, rating: rating, comment: comment)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            isLoading = true
            let (data, response) = try await URLSession.shared.data(for: request)
            isLoading = false

            guard let http = response as? HTTPURLResponse else { return nil }

            if http.statusCode == 201 {
                return try configuredDecoder().decode(ClassReview.self, from: data)
            } else if http.statusCode == 409 {
                errorMessage = "Ya dejaste una review para esta sesión"
            } else if http.statusCode == 403 {
                errorMessage = "Solo puedes hacer review de sesiones a las que asististe"
            } else if http.statusCode == 400 {
                errorMessage = "La sesión aún no ha terminado"
            }
            return nil
        } catch {
            isLoading = false
            errorMessage = "Error al enviar review"
            print("❌ [ReviewService] createReview error: \(error)")
            return nil
        }
    }

    // MARK: - 3. Get My Review

    func getMyReview(sessionId: Int) async -> ClassReview? {
        guard let request = await makeRequest(path: "/session/\(sessionId)/my", method: "GET") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try configuredDecoder().decode(ClassReview.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - 4. Update Review

    func updateReview(reviewId: Int, rating: Int?, comment: String?) async -> ClassReview? {
        guard var request = await makeRequest(path: "/\(reviewId)", method: "PUT") else { return nil }

        let body = UpdateReviewRequest(rating: rating, comment: comment)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            isLoading = true
            let (data, response) = try await URLSession.shared.data(for: request)
            isLoading = false

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try configuredDecoder().decode(ClassReview.self, from: data)
        } catch {
            isLoading = false
            print("❌ [ReviewService] updateReview error: \(error)")
            return nil
        }
    }

    // MARK: - 5. Delete Review

    func deleteReview(reviewId: Int) async -> Bool {
        guard let request = await makeRequest(path: "/\(reviewId)", method: "DELETE") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 204
        } catch {
            print("❌ [ReviewService] deleteReview error: \(error)")
            return false
        }
    }

    // MARK: - 6. Session Reviews

    func getSessionReviews(sessionId: Int, skip: Int = 0, limit: Int = 20) async -> SessionReviewsResponse? {
        guard let request = await makeRequest(path: "/session/\(sessionId)?skip=\(skip)&limit=\(limit)", method: "GET") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try configuredDecoder().decode(SessionReviewsResponse.self, from: data)
        } catch {
            print("❌ [ReviewService] getSessionReviews error: \(error)")
            return nil
        }
    }

    // MARK: - 7. My Review History

    func getMyReviews(skip: Int = 0, limit: Int = 20) async -> [ClassReview] {
        guard let request = await makeRequest(path: "/my?skip=\(skip)&limit=\(limit)", method: "GET") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            return try configuredDecoder().decode([ClassReview].self, from: data)
        } catch {
            print("❌ [ReviewService] getMyReviews error: \(error)")
            return []
        }
    }

    // MARK: - 8. Stats

    func getTrainerStats(trainerId: Int) async -> ReviewStats? {
        guard let request = await makeRequest(path: "/stats/trainer/\(trainerId)", method: "GET") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try configuredDecoder().decode(ReviewStats.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Private Helpers

    private func makeRequest(path: String, method: String) async -> URLRequest? {
        guard let url = URL(string: baseURL + path) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        if let gymId = GymService.shared.currentGym?.id {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }

        if let token = await authService?.getValidAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ [ReviewService] No auth token available")
            return nil
        }

        return request
    }

    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            let formatters: [DateFormatter] = {
                let iso = DateFormatter()
                iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
                iso.locale = Locale(identifier: "en_US_POSIX")

                let iso2 = DateFormatter()
                iso2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                iso2.locale = Locale(identifier: "en_US_POSIX")

                let iso3 = DateFormatter()
                iso3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                iso3.locale = Locale(identifier: "en_US_POSIX")

                return [iso, iso2, iso3]
            }()

            for formatter in formatters {
                if let date = formatter.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return decoder
    }
}
