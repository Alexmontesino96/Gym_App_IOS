//
//  InvitationService.swift
//  Gym_API
//
//  Cliente de /api/v1/invitations.
//
//  Cubre los dos lados: el cliente que canjea un código y el entrenador que los genera.
//
//  Detalle del canje: los endpoints de token no exigen pertenencia al espacio, porque quien
//  canjea todavía no pertenece. Como además puede no tener ningún gimnasio seleccionado,
//  las peticiones van sin cabecera de gimnasio.
//

import Foundation
import Combine

@MainActor
final class InvitationService: ObservableObject {

    // MARK: - Singleton
    static let shared = InvitationService()
    private init() {}

    // MARK: - Published
    @Published var preview: InvitationPreview?
    @Published var invitations: [WorkspaceInvitation] = []
    @Published var isLoading = false
    @Published var isAccepting = false
    @Published var errorMessage: String?

    // MARK: - Dependencias
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?

    // MARK: - Privado
    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    private lazy var decoder = BackendJSON.decoder()
    private lazy var encoder = BackendJSON.encoder()

    func configure(authService: AuthServiceDirect?, gymService: GymService?) {
        self.authService = authService
        self.gymService = gymService
    }

    /// Normaliza lo que pega el usuario: acepta el código suelto o el enlace completo.
    static func normalizeToken(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Si han pegado una URL, el token es el último segmento con contenido.
        if value.contains("/") {
            value = value
                .split(separator: "/")
                .map(String.init)
                .last(where: { !$0.isEmpty }) ?? value
        }
        // Quita una posible query string.
        if let questionMark = value.firstIndex(of: "?") {
            value = String(value[value.startIndex..<questionMark])
        }
        return value
    }

    // MARK: - Lado del cliente

    /// Consulta a qué espacio lleva un código, sin aceptarlo todavía.
    func loadPreview(token rawToken: String) async {
        let token = Self.normalizeToken(rawToken)
        guard token.count >= 8 else {
            errorMessage = "That code looks incomplete"
            preview = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let data = await get("/invitations/token/\(token)") else {
            preview = nil
            return
        }
        do {
            preview = try decoder.decode(InvitationPreview.self, from: data)
        } catch {
            preview = nil
            errorMessage = "Could not read the invitation"
            Logger.shared.error("InvitationService decode preview: \(error)", category: .network)
        }
    }

    /// Canjea el código y refresca la lista de gimnasios para que la app enrute a la raíz correcta.
    @discardableResult
    func accept(token rawToken: String) async -> InvitationAcceptResult? {
        let token = Self.normalizeToken(rawToken)
        guard !isAccepting else { return nil }

        isAccepting = true
        errorMessage = nil
        defer { isAccepting = false }

        guard let data = await send("/invitations/token/\(token)/accept", method: "POST") else {
            return nil
        }

        let result: InvitationAcceptResult
        do {
            result = try decoder.decode(InvitationAcceptResult.self, from: data)
        } catch {
            errorMessage = "Could not complete the invitation"
            Logger.shared.error("InvitationService decode accept: \(error)", category: .network)
            return nil
        }

        // Sin esto el usuario se queda en la pantalla de "no perteneces a ningún espacio"
        // aunque el alta ya esté hecha en el servidor.
        await GymService.shared.getMyGyms(forceRefresh: true, autoSelectIfSingle: true)
        return result
    }

    // MARK: - Lado del entrenador

    func loadInvitations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let data = await get("/invitations?only_redeemable=true") else { return }
        do {
            invitations = try decoder.decode([WorkspaceInvitation].self, from: data)
        } catch {
            errorMessage = "Could not load invitations"
            Logger.shared.error("InvitationService decode list: \(error)", category: .network)
        }
    }

    /// Crea una invitación para un cliente. Devuelve la invitación lista para compartir.
    func createInvitation(email: String? = nil, expiresInDays: Int = 14) async -> WorkspaceInvitation? {
        let body = CreateInvitationRequest(email: email, expiresInDays: expiresInDays)
        guard let data = await send("/invitations", method: "POST", body: body) else { return nil }
        do {
            let created = try decoder.decode(WorkspaceInvitation.self, from: data)
            invitations.insert(created, at: 0)
            return created
        } catch {
            errorMessage = "Could not create the invitation"
            Logger.shared.error("InvitationService decode create: \(error)", category: .network)
            return nil
        }
    }

    @discardableResult
    func revoke(invitationId: Int) async -> Bool {
        guard await send("/invitations/\(invitationId)", method: "DELETE") != nil else { return false }
        invitations.removeAll { $0.id == invitationId }
        return true
    }

    // MARK: - Transporte

    private func get(_ path: String) async -> Data? {
        guard let url = URL(string: baseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            errorMessage = "Could not prepare the request"
            return nil
        }
        return await perform(request, path: path)
    }

    private func send<T: Encodable>(_ path: String, method: String, body: T? = nil) async -> Data? {
        guard let url = URL(string: baseURL + path),
              var request = await HTTPClient.shared.makeRequest(url: url, method: method) else {
            errorMessage = "Could not prepare the request"
            return nil
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                errorMessage = "Could not prepare the data"
                return nil
            }
        }
        return await perform(request, path: path)
    }

    private func send(_ path: String, method: String) async -> Data? {
        let empty: [String: String]? = nil
        return await send(path, method: method, body: empty)
    }

    private func perform(_ request: URLRequest, path: String) async -> Data? {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if (200...299).contains(http.statusCode) { return data }

            switch http.statusCode {
            case 401:
                errorMessage = "Your session has expired"
            case 403:
                errorMessage = detail(from: data) ?? "This invitation is for someone else"
            case 404:
                errorMessage = "That code does not exist or is no longer valid"
            case 410:
                errorMessage = "This invitation has already been used or has expired"
            default:
                errorMessage = detail(from: data) ?? "Server error (\(http.statusCode))"
            }
            Logger.shared.error("InvitationService \(path) -> \(http.statusCode)", category: .network)
            return nil
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return nil }
            errorMessage = "Could not connect"
            Logger.shared.error("InvitationService \(path): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func detail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = object["detail"] as? String { return text }
        if let dict = object["detail"] as? [String: Any], let message = dict["message"] as? String { return message }
        return nil
    }

    // MARK: - Ciclo de vida

    func clearData() {
        preview = nil
        invitations = []
        errorMessage = nil
        isLoading = false
        isAccepting = false
    }

    deinit {
        #if DEBUG
        print("🗑️ InvitationService deinitialized")
        #endif
    }
}
