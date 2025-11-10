import Foundation

/// Centralized HTTP client to build authenticated requests consistently.
@MainActor
class HTTPClient {
    static let shared = HTTPClient()
    private init() {}

    weak var authService: AuthServiceDirect?

    /// Builds an authenticated `URLRequest` with Authorization and optional X-Gym-ID header.
    func makeRequest(url: URL, method: String = "GET", includeGymHeader: Bool = true, accept: String = "application/json") async -> URLRequest? {
        guard let token = await authService?.getValidAccessToken() else {
            Logger.shared.error("HTTPClient: no valid access token", category: .security)
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")

        if includeGymHeader, let gymId = GymService.shared.currentGymId {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        }
        return request
    }
}
