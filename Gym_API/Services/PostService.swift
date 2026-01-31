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
    func createPost(caption: String?, location: String?, images: [UIImage], sessionId: Int?) async throws -> Post
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
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Intentar múltiples formatos de fecha
            // 1. ISO8601 con microsegundos (lo que envía el backend)
            let microsecondsFormatter = DateFormatter()
            microsecondsFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            microsecondsFormatter.locale = Locale(identifier: "en_US_POSIX")
            microsecondsFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = microsecondsFormatter.date(from: dateString) {
                return date
            }

            // 2. ISO8601 con milisegundos
            let millisecondsFormatter = DateFormatter()
            millisecondsFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            millisecondsFormatter.locale = Locale(identifier: "en_US_POSIX")
            millisecondsFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = millisecondsFormatter.date(from: dateString) {
                return date
            }

            // 3. ISO8601 sin fracción de segundo
            let noFractionFormatter = DateFormatter()
            noFractionFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            noFractionFormatter.locale = Locale(identifier: "en_US_POSIX")
            noFractionFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = noFractionFormatter.date(from: dateString) {
                return date
            }

            // 4. ISO8601 estándar con timezone
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // 5. ISO8601 estándar sin fracción
            let iso8601NoFractionFormatter = ISO8601DateFormatter()
            if let date = iso8601NoFractionFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }
        return decoder
    }

    // MARK: - Feeds

    func getTimeline(limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        print("🌐 [PostService] getTimeline() - limit: \(limit), offset: \(offset)")

        let endpoint = baseURL.appendingPathComponent("posts/feed/timeline")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            print("❌ [PostService] URL inválida")
            throw PostServiceError.invalidURL
        }

        print("🔗 [PostService] URL: \(url.absoluteString)")

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            print("❌ [PostService] No autorizado - makeRequest falló")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response: \(responseString.prefix(1000))")
        }

        if httpResponse.statusCode == 404 {
            print("❌ [PostService] Módulo no disponible (404)")
            throw PostServiceError.moduleNotAvailable
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor: \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando PagedResponse<Post>...")
        do {
            let pagedResponse = try decoder.decode(PagedResponse<Post>.self, from: data)
            print("✅ [PostService] Timeline cargado - Posts: \(pagedResponse.posts?.count ?? 0)")
            return pagedResponse
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ [PostService] Key '\(key.stringValue)' no encontrado")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ [PostService] Type mismatch para tipo \(type)")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.typeMismatch(type, context)
        } catch let DecodingError.valueNotFound(type, context) {
            print("❌ [PostService] Value not found para tipo \(type)")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.valueNotFound(type, context)
        } catch let DecodingError.dataCorrupted(context) {
            print("❌ [PostService] Data corrupted")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.dataCorrupted(context)
        } catch {
            print("❌ [PostService] Error desconocido decodificando: \(error)")
            throw error
        }
    }

    func getExplore(limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        print("🌐 [PostService] getExplore() - limit: \(limit), offset: \(offset)")

        let endpoint = baseURL.appendingPathComponent("posts/feed/explore")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            print("❌ [PostService] URL inválida (explore)")
            throw PostServiceError.invalidURL
        }

        print("🔗 [PostService] URL (explore): \(url.absoluteString)")

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            print("❌ [PostService] No autorizado - makeRequest falló (explore)")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request (explore)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (explore)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (explore)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (explore): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (explore): \(responseString.prefix(1000))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                print("❌ [PostService] Módulo no disponible (404) - explore")
            }
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (explore): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando PagedResponse<Post> (explore)...")
        let result = try decoder.decode(PagedResponse<Post>.self, from: data)
        print("✅ [PostService] Explore cargado - Posts: \(result.posts?.count ?? 0)")
        return result
    }

    func getByLocation(_ location: String, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        print("🌐 [PostService] getByLocation() - location: \(location), limit: \(limit), offset: \(offset)")

        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? location
        let endpoint = baseURL.appendingPathComponent("posts/feed/location/\(encodedLocation)")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            print("❌ [PostService] URL inválida (location)")
            throw PostServiceError.invalidURL
        }

        print("🔗 [PostService] URL (location): \(url.absoluteString)")

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            print("❌ [PostService] No autorizado - makeRequest falló (location)")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request (location)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (location)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (location)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (location): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (location): \(responseString.prefix(1000))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                print("❌ [PostService] Módulo no disponible (404) - location")
            }
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (location): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando PagedResponse<Post> (location)...")
        let result = try decoder.decode(PagedResponse<Post>.self, from: data)
        print("✅ [PostService] Location cargado - Posts: \(result.posts?.count ?? 0)")
        return result
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

    func createPost(caption: String? = nil, location: String? = nil, images: [UIImage], sessionId: Int? = nil) async throws -> Post {
        print("🌐 [PostService] createPost() llamado")
        print("📊 [PostService] - Caption: '\(caption ?? "nil")'")
        print("📊 [PostService] - Location: '\(location ?? "nil")'")
        print("📊 [PostService] - Images count: \(images.count)")
        print("📊 [PostService] - Session ID: \(sessionId != nil ? "\(sessionId!)" : "nil")")

        guard !images.isEmpty else {
            print("❌ [PostService] No hay imágenes")
            throw PostServiceError.validationError("Se requiere al menos una imagen")
        }

        let endpoint = baseURL.appendingPathComponent("posts")
        print("🔗 [PostService] Endpoint: \(endpoint.absoluteString)")

        let boundary = UUID().uuidString
        print("🔑 [PostService] Boundary: \(boundary)")

        guard var request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            print("❌ [PostService] No se pudo crear request - No autorizado")
            throw PostServiceError.unauthorized
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        print("📤 [PostService] Content-Type configurado: multipart/form-data")

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

        // Add sessionId for tagging
        if let sessionId = sessionId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(sessionId)\r\n".data(using: .utf8)!)
            print("📌 [PostService] Etiquetando sesión ID: \(sessionId)")
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

        let bodySize = Double(body.count) / 1024.0 / 1024.0
        print("📦 [PostService] Tamaño del body: \(String(format: "%.2f", bodySize)) MB")
        print("🚀 [PostService] Enviando request al servidor...")

        let (data, response) = try await URLSession.shared.data(for: request)

        print("📥 [PostService] Respuesta recibida")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta inválida - No es HTTPURLResponse")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response body: \(responseString.prefix(500))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor: \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error al crear el post")
        }

        print("🔄 [PostService] Decodificando CreatePostResponse...")
        let responseObj = try decoder.decode(CreatePostResponse.self, from: data)
        print("✅ [PostService] Post decodificado exitosamente - ID: \(responseObj.post.id)")
        return responseObj.post
    }

    func getUserPosts(userId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Post> {
        print("🌐 [PostService] getUserPosts() - userId: \(userId), limit: \(limit), offset: \(offset)")

        let endpoint = baseURL.appendingPathComponent("posts/user/\(userId)")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            print("❌ [PostService] URL inválida (user posts)")
            throw PostServiceError.invalidURL
        }

        print("🔗 [PostService] URL (user posts): \(url.absoluteString)")

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            print("❌ [PostService] No autorizado - makeRequest falló (user posts)")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request (user posts)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (user posts)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (user posts)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (user posts): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (user posts): \(responseString.prefix(1000))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (user posts): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando PagedResponse<Post> (user posts)...")
        let result = try decoder.decode(PagedResponse<Post>.self, from: data)
        print("✅ [PostService] User posts cargado - Posts: \(result.posts?.count ?? 0)")
        return result
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
        print("🌐 [PostService] addComment() - postId: \(postId)")
        print("📝 [PostService] Comment text: '\(text.prefix(100))'")

        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/comment")
        print("🔗 [PostService] URL (addComment): \(endpoint.absoluteString)")

        var requestBody: [String: Any] = ["comment_text": text]
        if let mentionedUserIds = mentionedUserIds {
            requestBody["mentioned_user_ids"] = mentionedUserIds
            print("👥 [PostService] Mentioned users: \(mentionedUserIds)")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // Log del request body
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 [PostService] Request body: \(jsonString)")
        }

        guard var request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            print("❌ [PostService] No autorizado - makeRequest falló (addComment)")
            throw PostServiceError.unauthorized
        }

        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("📤 [PostService] Enviando request (addComment)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (addComment)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (addComment)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (addComment): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (addComment): \(responseString)")
        }

        if httpResponse.statusCode == 404 {
            print("❌ [PostService] Post no encontrado (addComment)")
            throw PostServiceError.postNotFound
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (addComment): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando CreateCommentResponse...")
        do {
            let result = try decoder.decode(CreateCommentResponse.self, from: data)
            print("✅ [PostService] Comentario creado exitosamente")
            print("   ID: \(result.comment.id)")
            print("   User: \(result.comment.user.fullName)")
            print("   Text: \(result.comment.commentText)")
            return result.comment
        } catch {
            print("❌ [PostService] Error decodificando CreateCommentResponse: \(error)")
            throw error
        }
    }

    func getComments(postId: Int, limit: Int = 20, offset: Int = 0) async throws -> PagedResponse<Comment> {
        print("🌐 [PostService] getComments() - postId: \(postId), limit: \(limit), offset: \(offset)")

        let endpoint = baseURL.appendingPathComponent("posts/\(postId)/comments")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else {
            print("❌ [PostService] URL inválida (getComments)")
            throw PostServiceError.invalidURL
        }

        print("🔗 [PostService] URL (getComments): \(url.absoluteString)")

        guard let request = await httpClient.makeRequest(url: url, method: "GET") else {
            print("❌ [PostService] No autorizado - makeRequest falló (getComments)")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request (getComments)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (getComments)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (getComments)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (getComments): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (getComments): \(responseString.prefix(1000))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (getComments): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando PagedResponse<Comment>...")
        do {
            let result = try decoder.decode(PagedResponse<Comment>.self, from: data)
            print("✅ [PostService] Comentarios cargados - Total: \(result.comments?.count ?? 0)")

            // Log detallado de cada comentario
            if let comments = result.comments {
                for (index, comment) in comments.enumerated() {
                    print("   📝 Comentario #\(index + 1):")
                    print("      ID: \(comment.id)")
                    print("      User: \(comment.user.fullName)")
                    print("      Text: \(comment.commentText.prefix(50))...")
                    print("      Likes: \(comment.likeCount)")
                }
            }

            return result
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ [PostService] Key '\(key.stringValue)' no encontrado (getComments)")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ [PostService] Type mismatch para tipo \(type) (getComments)")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.typeMismatch(type, context)
        } catch let DecodingError.valueNotFound(type, context) {
            print("❌ [PostService] Value not found para tipo \(type) (getComments)")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.valueNotFound(type, context)
        } catch let DecodingError.dataCorrupted(context) {
            print("❌ [PostService] Data corrupted (getComments)")
            print("   Context: \(context.debugDescription)")
            print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            throw DecodingError.dataCorrupted(context)
        } catch {
            print("❌ [PostService] Error desconocido decodificando (getComments): \(error)")
            throw error
        }
    }

    func editComment(commentId: Int, text: String) async throws -> Comment {
        print("🌐 [PostService] editComment() - commentId: \(commentId)")
        print("📝 [PostService] New text: '\(text.prefix(100))'")

        let endpoint = baseURL.appendingPathComponent("posts/comments/\(commentId)")
        print("🔗 [PostService] URL (editComment): \(endpoint.absoluteString)")

        let requestBody = ["comment_text": text]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // Log del request body
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 [PostService] Request body: \(jsonString)")
        }

        guard var request = await httpClient.makeRequest(url: endpoint, method: "PUT") else {
            print("❌ [PostService] No autorizado - makeRequest falló (editComment)")
            throw PostServiceError.unauthorized
        }

        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("📤 [PostService] Enviando request (editComment)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (editComment)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (editComment)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (editComment): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (editComment): \(responseString)")
        }

        if httpResponse.statusCode == 404 {
            print("❌ [PostService] Comentario no encontrado (editComment)")
            throw CommentError.notFound
        }

        if httpResponse.statusCode == 403 {
            print("❌ [PostService] No autorizado para editar este comentario (editComment)")
            throw CommentError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (editComment): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando Comment...")
        do {
            let comment = try decoder.decode(Comment.self, from: data)
            print("✅ [PostService] Comentario editado exitosamente")
            print("   ID: \(comment.id)")
            print("   New text: \(comment.commentText)")
            print("   Is edited: \(comment.isEdited)")
            return comment
        } catch {
            print("❌ [PostService] Error decodificando Comment: \(error)")
            throw error
        }
    }

    func deleteComment(commentId: Int) async throws {
        print("🌐 [PostService] deleteComment() - commentId: \(commentId)")

        let endpoint = baseURL.appendingPathComponent("posts/comments/\(commentId)")
        print("🔗 [PostService] URL (deleteComment): \(endpoint.absoluteString)")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "DELETE") else {
            print("❌ [PostService] No autorizado - makeRequest falló (deleteComment)")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request (deleteComment)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (deleteComment)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (deleteComment)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (deleteComment): \(httpResponse.statusCode)")

        if httpResponse.statusCode == 404 {
            print("❌ [PostService] Comentario no encontrado (deleteComment)")
            throw CommentError.notFound
        }

        if httpResponse.statusCode == 403 {
            print("❌ [PostService] No autorizado para eliminar este comentario (deleteComment)")
            throw CommentError.unauthorized
        }

        // 204 No Content es éxito
        guard httpResponse.statusCode == 204 || (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (deleteComment): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("✅ [PostService] Comentario eliminado exitosamente")
    }

    func toggleCommentLike(commentId: Int) async throws -> (liked: Bool, totalLikes: Int) {
        print("🌐 [PostService] toggleCommentLike() - commentId: \(commentId)")

        let endpoint = baseURL.appendingPathComponent("posts/comments/\(commentId)/like")
        print("🔗 [PostService] URL (toggleCommentLike): \(endpoint.absoluteString)")

        guard let request = await httpClient.makeRequest(url: endpoint, method: "POST") else {
            print("❌ [PostService] No autorizado - makeRequest falló (toggleCommentLike)")
            throw PostServiceError.unauthorized
        }

        print("📤 [PostService] Enviando request (toggleCommentLike)...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📥 [PostService] Respuesta recibida (toggleCommentLike)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PostService] Respuesta no es HTTPURLResponse (toggleCommentLike)")
            throw PostServiceError.invalidResponse
        }

        print("📊 [PostService] Status code (toggleCommentLike): \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [PostService] Response (toggleCommentLike): \(responseString)")
        }

        if httpResponse.statusCode == 404 {
            print("❌ [PostService] Comentario no encontrado (toggleCommentLike)")
            throw CommentError.notFound
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(ErrorResponse.self, from: data)
            print("❌ [PostService] Error del servidor (toggleCommentLike): \(error?.detail ?? "desconocido")")
            throw PostServiceError.serverError(error?.detail ?? "Error desconocido")
        }

        print("🔄 [PostService] Decodificando ToggleCommentLikeResponse...")
        let result = try decoder.decode(ToggleCommentLikeResponse.self, from: data)
        print("✅ [PostService] Like toggled exitosamente")
        print("   Action: \(result.action)")
        print("   Total likes: \(result.totalLikes)")
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
