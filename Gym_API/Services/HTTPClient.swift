import Foundation

/// Centralized HTTP client to build authenticated requests consistently.
@MainActor
class HTTPClient {
    static let shared = HTTPClient()
    private init() {}

    weak var authService: AuthServiceDirect?

    /// Builds an authenticated `URLRequest` with Authorization and optional X-Gym-ID header.
    ///
    /// - Parameter gymId: espacio al que va la petición. Por defecto, el seleccionado. Se pasa
    ///   explícitamente cuando el dato NO es del espacio actual: el outbox de entrenamiento
    ///   guarda registros hechos en un gimnasio y los envía cuando hay red, que puede ser
    ///   después de haber cambiado a otro. Sin esto, el entreno se atribuiría al espacio
    ///   equivocado y nadie se enteraría.
    func makeRequest(
        url: URL,
        method: String = "GET",
        includeGymHeader: Bool = true,
        accept: String = "application/json",
        gymId: Int? = nil
    ) async -> URLRequest? {
        guard let token = await authService?.getValidAccessToken() else {
            Logger.shared.error("HTTPClient: no valid access token", category: .security)
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")

        if includeGymHeader, let resolved = gymId ?? GymService.shared.currentGymId {
            request.setValue("\(resolved)", forHTTPHeaderField: "X-Gym-ID")
        }
        return request
    }
}
