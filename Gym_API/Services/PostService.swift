import Foundation
import UIKit

// MARK: - Post Service Protocol

/// Protocolo para el servicio de Posts del feed social
protocol PostServicing {
    // MARK: - Feeds
    func getTimeline(limit: Int, offset: Int) async throws -> PagedResponse<Post>
    func getExplore(limit: Int, offset: Int) async throws -> PagedResponse<Post>
    func getByLocation(_ location: String, limit: Int, offset: Int) async throws -> PagedResponse<Post>

    // MARK: - CRUD de Posts
    func createPost(caption: String?, location: String?, images: [UIImage]) async throws -> Post
    func getPost(id: Int) async throws -> Post
    func getUserPosts(userId: Int, limit: Int, offset: Int) async throws -> PagedResponse<Post>
    func updatePost(id: Int, caption: String?, location: String?) async throws -> Post
    func deletePost(id: Int) async throws

    // MARK: - Likes
    func toggleLike(postId: Int) async throws -> (liked: Bool, totalLikes: Int)
    func getLikes(postId: Int, limit: Int, offset: Int) async throws -> PagedResponse<LikeItem>

    // MARK: - Comentarios
    func addComment(postId: Int, text: String, mentionedUserIds: [Int]?) async throws -> Comment
    func getComments(postId: Int, limit: Int, offset: Int) async throws -> PagedResponse<Comment>
    func editComment(commentId: Int, text: String) async throws -> Comment
    func deleteComment(commentId: Int) async throws
    func toggleCommentLike(commentId: Int) async throws -> (liked: Bool, totalLikes: Int)

    // MARK: - Tags y Menciones
    func getByEvent(eventId: Int, limit: Int, offset: Int) async throws -> PagedResponse<Post>
    func getBySession(sessionId: Int, limit: Int, offset: Int) async throws -> PagedResponse<Post>
    func getMyMentions(limit: Int, offset: Int) async throws -> PagedResponse<Post>
    func reportPost(postId: Int, reason: String, description: String?) async throws
}

// MARK: - Post Service Implementation

/// Servicio para manejar la API de Posts del feed social
@MainActor
class PostService: ObservableObject, PostServicing {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let baseURL: URL
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    // MARK: - Singleton
    static let shared = PostService()

    // MARK: - Initialization
    init() {
        guard let url = URL(string: apiBaseURL) else {
            fatalError("Invalid base URL: \(apiBaseURL)")
        }
        self.baseURL = url
        self.httpClient = HTTPClient.shared
        self.decoder = Self.createDecoder()

        #if DEBUG
        print("✅ PostService initialized with base URL: \(apiBaseURL)")
        #endif
    }

    // MARK: - Decoder Configuration
    private static func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Feeds

    func getTimeline(limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let endpoint = baseURL.appendingPathComponent("posts/feed/timeline")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.moduleNotAvailable
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    func getExplore(limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let endpoint = baseURL.appendingPathComponent("posts/feed/explore")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    func getByLocation(_ location: String, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? location
        let endpoint = baseURL.appendingPathComponent("posts/feed/location/\(encodedLocation)")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    // MARK: - CRUD de Posts

    func getPost(id: Int) async throws -> Post {
        let endpoint = baseURL.appendingPathComponent("posts/\(id)")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.postNotFound
        }

        if httpResponse.statusCode == 403 {
            throw PostServiceError.forbidden
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(Post.self, from: data)
    }

    func createPost(caption: String? = nil, location: String? = nil, images: [UIImage]) async throws -> Post {
        guard !images.isEmpty else {
            throw PostServiceError.validationError("Se requiere al menos una imagen")
        }

        let endpoint = baseURL.appendingPathComponent("posts")
        let boundary = UUID().uuidString

        guard var request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            throw PostServiceError.unauthorized
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add caption
        if let caption = caption {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)
        }

        // Add post_type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"post_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("gallery\r\n".data(using: .utf8)!)

        // Add privacy
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"privacy\"\r\n\r\n".data(using: .utf8)!)
        body.append("public\r\n".data(using: .utf8)!)

        // Add location
        if let location = location {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"location\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(location)\r\n".data(using: .utf8)!)
        }

        // Add images
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error al crear el post")
        }

        return try decoder.decode(Post.self, from: data)
    }

    func getUserPosts(userId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let endpoint = baseURL.appendingPathComponent("posts/user/\(userId)")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    func updatePost(id: Int, caption: String? = nil, location: String? = nil) async throws -> Post {
        let endpoint = baseURL.appendingPathComponent("posts/\(id)")

        var requestBody: [String: Any?] = [:]
        if let caption = caption { requestBody["caption"] = caption }
        if let location = location { requestBody["location"] = location }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody.compactMapValues { $0 })

        guard var request = await httpClient.makeRequest(url: endpoint, method: "PUT") else {
            throw PostServiceError.unauthorized
        }

        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.postNotFound
        }

        if httpResponse.statusCode == 403 {
            throw PostServiceError.forbidden
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(Post.self, from: data)
    }

    func deletePost(id: Int) async throws {
        let endpoint = baseURL.appendingPathComponent("posts/\(id)")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "DELETE") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.postNotFound
        }

        if httpResponse.statusCode == 403 {
            throw PostServiceError.forbidden
        }

        // 204 No Content es éxito
        guard httpResponse.statusCode == 204 || (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }
    }

    // MARK: - Likes

    func toggleLike(postId: Int) async throws -> (liked: Bool, totalLikes: Int) {
        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/like")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.postNotFound
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        let result = try decoder.decode(ToggleLikeResponse.self, from: data)
        return (liked: result.action == "liked", totalLikes: result.totalLikes)
    }

    func getLikes(postId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<LikeItem> {
        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/likes")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<LikeItem>.self, from: data)
    }

    // MARK: - Comentarios

    func addComment(postId: Int, text: String, mentionedUserIds: [Int]? = nil) async throws -> Comment {
        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/comment")

        var requestBody: [String: Any] = ["text": text]
        if let mentionedUserIds = mentionedUserIds {
            requestBody["mentioned_user_ids"] = mentionedUserIds
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        guard var request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            throw PostServiceError.unauthorized
        }

        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.postNotFound
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        let result = try decoder.decode(CreateCommentResponse.self, from: data)
        return result.comment
    }

    func getComments(postId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Comment> {
        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/comments")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Comment>.self, from: data)
    }

    func editComment(commentId: Int, text: String) async throws -> Comment {
        let endpoint = baseURL.appendingPathComponent("posts/comments/\(commentId)")

        let requestBody = ["text": text]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        guard var request = await httpClient.makeRequest(url: endpoint, method: "PUT") else {
            throw PostServiceError.unauthorized
        }

        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw CommentError.notFound
        }

        if httpResponse.statusCode == 403 {
            throw CommentError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(Comment.self, from: data)
    }

    func deleteComment(commentId: Int) async throws {
        let endpoint = baseURL.appendingPathComponent("posts/comments/\(commentId)")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "DELETE") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw CommentError.notFound
        }

        if httpResponse.statusCode == 403 {
            throw CommentError.unauthorized
        }

        // 204 No Content es éxito
        guard httpResponse.statusCode == 204 || (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }
    }

    func toggleCommentLike(commentId: Int) async throws -> (liked: Bool, totalLikes: Int) {
        let endpoint = baseURL.appendingPathComponent("posts/comments/\(commentId)/like")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw CommentError.notFound
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        let result = try decoder.decode(ToggleCommentLikeResponse.self, from: data)
        return (liked: result.action == "liked", totalLikes: result.totalLikes)
    }

    // MARK: - Tags y Menciones

    func getByEvent(eventId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let endpoint = baseURL.appendingPathComponent("posts/events/\(eventId)")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    func getBySession(sessionId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let endpoint = baseURL.appendingPathComponent("posts/sessions/\(sessionId)")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    func getMyMentions(limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        let endpoint = baseURL.appendingPathComponent("posts/mentions/me")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            throw PostServiceError.invalidURL
        }

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            throw PostServiceError.unauthorized
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        return try decoder.decode(PagedResponse<Post>.self, from: data)
    }

    // MARK: - Report

    func reportPost(postId: Int, reason: String, description: String? = nil) async throws {
        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/report")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            throw PostServiceError.unauthorized
        }

        var urlRequest = request
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PostServiceError.postNotFound
        }

        if httpResponse.statusCode == 403 {
            throw PostServiceError.forbidden
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            throw PostServiceError.serverError(error?.detail ?? "Error al reportar post")
        }
    }

    // MARK: - Deinit
    deinit {
        #if DEBUG
        print("🗑️ PostService deinitialized")
        #endif
    }
}

// MARK: - Error Handling

enum PostServiceError: LocalizedError {
    case invalidURL
    case unauthorized
    case invalidResponse
    case postNotFound
    case forbidden
    case moduleNotAvailable
    case validationError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .unauthorized:
            return "No autorizado. Por favor inicia sesión nuevamente"
        case .validationError(let message):
            return message
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .postNotFound:
            return "Post no encontrado"
        case .forbidden:
            return "No tienes permiso para realizar esta acción"
        case .moduleNotAvailable:
            return "Módulo de posts no disponible"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let detail: String
}
