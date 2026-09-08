//
//  AccountService.swift
//  Gym_API
//
//  Borrado de la propia cuenta.
//
//  Apple exige que una app que deja crear una cuenta deje borrarla desde dentro, y hasta
//  ahora no había forma: la API solo tenía el borrado por gimnasio y el de superadministrador.
//  Este cliente habla con DELETE /api/v1/users/me.
//
//  El servidor no borra la fila del usuario, la anonimiza: hay decenas de claves foráneas
//  apuntando a ella y borrarla se llevaría por delante mensajes y sesiones que también son de
//  otras personas. Lo que sí se borra de verdad es la cuenta de Auth0, que es lo que impide
//  volver a entrar, y las medidas de salud.
//

import Foundation
import Combine

struct AccountDeletionResult: Codable {
    let deleted: Bool
    let alreadyDeleted: Bool
    let archivedWorkspaces: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case deleted
        case alreadyDeleted = "already_deleted"
        case archivedWorkspaces = "archived_workspaces"
        case message
    }
}

@MainActor
final class AccountService: ObservableObject {

    // MARK: - Singleton
    static let shared = AccountService()
    private init() {}

    // MARK: - Published
    @Published var isDeleting = false
    @Published var errorMessage: String?

    // MARK: - Dependencias
    weak var authService: AuthServiceDirect?

    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    private lazy var decoder = BackendJSON.decoder()

    func configure(authService: AuthServiceDirect?) {
        self.authService = authService
    }

    /// Borra la cuenta. Devuelve el resultado o nil si algo falló, con el motivo en
    /// `errorMessage`.
    ///
    /// La confirmación viaja en el cuerpo porque el servidor la exige: un DELETE suelto,
    /// disparado por un reintento automático, no debe llevarse una cuenta por delante.
    func deleteAccount() async -> AccountDeletionResult? {
        guard !isDeleting else { return nil }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        guard let url = URL(string: baseURL + "/users/me"),
              var request = await HTTPClient.shared.makeRequest(url: url, method: "DELETE") else {
            errorMessage = "Could not prepare the request"
            return nil
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = #"{"confirm":true}"#.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Could not connect"
                return nil
            }

            guard (200...299).contains(http.statusCode) else {
                switch http.statusCode {
                case 401:
                    errorMessage = "Your session has expired. Sign in again and retry."
                case 429:
                    errorMessage = "Too many attempts. Try again later."
                default:
                    errorMessage = detail(from: data) ?? "Could not delete your account (\(http.statusCode))"
                }
                Logger.shared.error("AccountService delete -> \(http.statusCode)", category: .network)
                return nil
            }

            // La cuenta ya no existe: los entrenos que quedaran sin sincronizar tampoco tienen
            // a dónde ir. Es el ÚNICO sitio donde se vacía el outbox; cerrar sesión no lo toca.
            if let userId = UserProfileService.shared.userProfile?.id {
                await TrainingSyncCoordinator.shared.eraseAllData(userId: userId)
            }

            return try decoder.decode(AccountDeletionResult.self, from: data)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return nil }
            errorMessage = "Could not delete your account. Check your connection and try again."
            Logger.shared.error("AccountService delete: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func detail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = object["detail"] as? String { return text }
        if let dict = object["detail"] as? [String: Any], let message = dict["message"] as? String { return message }
        return nil
    }

    func clearData() {
        errorMessage = nil
        isDeleting = false
    }

    deinit {
        #if DEBUG
        print("🗑️ AccountService deinitialized")
        #endif
    }
}
