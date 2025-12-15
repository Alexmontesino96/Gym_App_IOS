//
//  ChatManagementService.swift
//  Gym_API
//
//  Servicio para gestión de chats estilo WhatsApp
//  Funcionalidades: Ocultar chats, salir de grupos, eliminar grupos (admin)
//

import Foundation

// MARK: - Chat Management Errors

enum ChatManagementError: LocalizedError {
    case notDirectChat
    case notGroupChat
    case notAMember
    case groupNotEmpty(membersCount: Int)
    case noPermission
    case notFound
    case conflict(String)
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notDirectChat:
            return "Solo puedes ocultar chats directos 1-to-1. Para grupos, debes salir primero."
        case .notGroupChat:
            return "No puedes salir de un chat directo 1-to-1. Usa la opción 'ocultar'."
        case .notAMember:
            return "No eres miembro de este chat."
        case .groupNotEmpty(let count):
            return "Debes remover a todos los miembros (\(count) restantes) antes de eliminar el grupo."
        case .noPermission:
            return "No tienes permisos para realizar esta acción."
        case .notFound:
            return "Chat no encontrado."
        case .conflict(let message):
            return message
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Models

struct ChatHideResponse: Codable {
    let success: Bool
    let message: String
    let roomId: Int
    let isHidden: Bool

    enum CodingKeys: String, CodingKey {
        case success, message
        case roomId = "room_id"
        case isHidden = "is_hidden"
    }
}

struct ChatLeaveResponse: Codable {
    let success: Bool
    let message: String
    let roomId: Int
    let remainingMembers: Int
    let groupDeleted: Bool
    let autoHidden: Bool

    enum CodingKeys: String, CodingKey {
        case success, message
        case roomId = "room_id"
        case remainingMembers = "remaining_members"
        case groupDeleted = "group_deleted"
        case autoHidden = "auto_hidden"
    }
}

struct ChatDeleteResponse: Codable {
    let success: Bool
    let message: String
    let roomId: Int
    let deletedFromStream: Bool

    enum CodingKeys: String, CodingKey {
        case success, message
        case roomId = "room_id"
        case deletedFromStream = "deleted_from_stream"
    }
}

struct ChatDeleteConversationResponse: Codable {
    let success: Bool
    let message: String
    let roomId: Int
    let messagesDeleted: Int

    enum CodingKeys: String, CodingKey {
        case success, message
        case roomId = "room_id"
        case messagesDeleted = "messages_deleted"
    }
}

struct DeleteOrphanChannelResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Error Response

struct ChatErrorResponse: Codable {
    let detail: String
}

// MARK: - Chat Management Service

@MainActor
class ChatManagementService: ObservableObject {

    // MARK: - Singleton
    static let shared = ChatManagementService()

    // MARK: - Properties
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1/chat"

    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        print("🎯 ChatManagementService initialized")
    }

    // MARK: - Private Helper Methods

    private func createURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = queryItems
        return components?.url
    }

    private func handleResponse<T: Codable>(
        data: Data,
        response: URLResponse,
        type: T.Type
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatManagementError.serverError("Respuesta inválida del servidor")
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            // No usar .convertFromSnakeCase porque tenemos CodingKeys manuales
            return try decoder.decode(T.self, from: data)

        case 400:
            if let errorResponse = try? JSONDecoder().decode(ChatErrorResponse.self, from: data) {
                // Detectar tipo de error específico por el mensaje
                if errorResponse.detail.contains("Solo puedes ocultar chats directos") {
                    throw ChatManagementError.notDirectChat
                } else if errorResponse.detail.contains("No puedes salir de un chat directo") {
                    throw ChatManagementError.notGroupChat
                } else if errorResponse.detail.contains("Debes remover a todos los miembros") {
                    // Extraer número de miembros del mensaje
                    let count = extractMemberCount(from: errorResponse.detail)
                    throw ChatManagementError.groupNotEmpty(membersCount: count)
                }
                throw ChatManagementError.serverError(errorResponse.detail)
            }
            throw ChatManagementError.serverError("Bad request")

        case 403:
            if let errorResponse = try? JSONDecoder().decode(ChatErrorResponse.self, from: data) {
                if errorResponse.detail.contains("No eres miembro") {
                    throw ChatManagementError.notAMember
                }
                throw ChatManagementError.noPermission
            }
            throw ChatManagementError.noPermission

        case 404:
            throw ChatManagementError.notFound

        case 409:
            if let errorResponse = try? JSONDecoder().decode(ChatErrorResponse.self, from: data) {
                throw ChatManagementError.conflict(errorResponse.detail)
            }
            throw ChatManagementError.conflict("Conflicto al eliminar el canal")

        default:
            throw ChatManagementError.serverError("Error del servidor (\(httpResponse.statusCode))")
        }
    }

    private func extractMemberCount(from message: String) -> Int {
        // Buscar patrón "X restantes" o "X miembros"
        let pattern = #"(\d+)\s+(restantes|miembros)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range(at: 1), in: message),
           let count = Int(message[range]) {
            return count
        }
        return 0
    }

    // MARK: - Public API Methods

    /// Oculta un chat 1-to-1 para el usuario actual
    /// - Parameter roomId: ID de la sala de chat
    /// - Returns: Respuesta con el resultado
    /// - Throws: ChatManagementError si falla
    func hideChat(roomId: Int) async throws -> ChatHideResponse {
        print("🔄 Ocultando chat: \(roomId)")

        guard let url = createURL(path: "/rooms/\(roomId)/hide") else {
            throw ChatManagementError.serverError("URL inválida")
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
            throw ChatManagementError.serverError("No se pudo crear la solicitud")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log respuesta del backend
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Respuesta del backend (Hide): \(responseString)")
            }

            let result: ChatHideResponse = try handleResponse(data: data, response: response, type: ChatHideResponse.self)
            print("✅ Chat ocultado exitosamente: \(roomId)")
            print("   📊 Resultado: success=\(result.success), isHidden=\(result.isHidden)")
            return result
        } catch let error as ChatManagementError {
            throw error
        } catch {
            throw ChatManagementError.networkError(error)
        }
    }

    /// Muestra un chat previamente ocultado
    /// - Parameter roomId: ID de la sala de chat
    /// - Returns: Respuesta con el resultado
    /// - Throws: ChatManagementError si falla
    func showChat(roomId: Int) async throws -> ChatHideResponse {
        print("🔄 Mostrando chat: \(roomId)")

        guard let url = createURL(path: "/rooms/\(roomId)/show") else {
            throw ChatManagementError.serverError("URL inválida")
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
            throw ChatManagementError.serverError("No se pudo crear la solicitud")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log respuesta del backend
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Respuesta del backend (Show): \(responseString)")
            }

            let result: ChatHideResponse = try handleResponse(data: data, response: response, type: ChatHideResponse.self)
            print("✅ Chat mostrado exitosamente: \(roomId)")
            print("   📊 Resultado: success=\(result.success), isHidden=\(result.isHidden)")
            return result
        } catch let error as ChatManagementError {
            throw error
        } catch {
            throw ChatManagementError.networkError(error)
        }
    }

    /// Permite al usuario salir de un grupo
    /// - Parameters:
    ///   - roomId: ID del grupo
    ///   - autoHide: Si debe ocultarse automáticamente (default: true)
    /// - Returns: Respuesta con información de miembros restantes
    /// - Throws: ChatManagementError si falla
    func leaveGroup(roomId: Int, autoHide: Bool = true) async throws -> ChatLeaveResponse {
        print("🔄 Saliendo del grupo: \(roomId)")

        let queryItems = [URLQueryItem(name: "auto_hide", value: String(autoHide))]
        guard let url = createURL(path: "/rooms/\(roomId)/leave", queryItems: queryItems) else {
            throw ChatManagementError.serverError("URL inválida")
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
            throw ChatManagementError.serverError("No se pudo crear la solicitud")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log respuesta del backend
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Respuesta del backend (Leave Group): \(responseString)")
            }

            let result: ChatLeaveResponse = try handleResponse(data: data, response: response, type: ChatLeaveResponse.self)

            if result.groupDeleted {
                print("✅ Saliste del grupo y fue eliminado (último miembro): \(roomId)")
            } else {
                print("✅ Saliste del grupo exitosamente: \(roomId), quedan \(result.remainingMembers) miembros")
            }
            print("   📊 Resultado: success=\(result.success), groupDeleted=\(result.groupDeleted), autoHidden=\(result.autoHidden)")

            return result
        } catch let error as ChatManagementError {
            throw error
        } catch {
            throw ChatManagementError.networkError(error)
        }
    }

    /// Elimina todos los mensajes de una conversación 1-to-1 solo para el usuario actual (Delete For Me)
    /// - Parameter roomId: ID de la conversación 1-to-1
    /// - Returns: Respuesta con el número de mensajes eliminados
    /// - Throws: ChatManagementError si falla
    /// - Note: Equivalente a "Eliminar Para Mí" de WhatsApp. El otro usuario mantiene su historial.
    func deleteConversation(roomId: Int) async throws -> ChatDeleteConversationResponse {
        print("🔄 Eliminando conversación (Delete For Me): \(roomId)")

        guard let url = createURL(path: "/rooms/\(roomId)/conversation") else {
            throw ChatManagementError.serverError("URL inválida")
        }

        print("📍 URL construida: \(url.absoluteString)")

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "DELETE") else {
            throw ChatManagementError.serverError("No se pudo crear la solicitud")
        }

        print("📤 Enviando DELETE request a: \(request.url?.absoluteString ?? "N/A")")
        print("📤 Headers: \(request.allHTTPHeaderFields ?? [:])")

        do {
            print("⏳ Ejecutando URLSession.shared.data()...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ Response recibida del servidor")

            // Log respuesta del backend
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Respuesta del backend (Delete Conversation): \(responseString)")
            }

            let result: ChatDeleteConversationResponse = try handleResponse(data: data, response: response, type: ChatDeleteConversationResponse.self)
            print("✅ Conversación eliminada: \(result.messagesDeleted) mensajes borrados")
            print("   📊 Resultado: success=\(result.success), messagesDeleted=\(result.messagesDeleted)")
            return result
        } catch let error as ChatManagementError {
            throw error
        } catch {
            throw ChatManagementError.networkError(error)
        }
    }

    /// Elimina un grupo completamente (solo admin/creador)
    /// - Parameters:
    ///   - roomId: ID del grupo a eliminar
    ///   - hardDelete: Si debe eliminarse de Stream Chat (default: false)
    /// - Returns: Respuesta con el resultado
    /// - Throws: ChatManagementError si falla
    func deleteGroup(roomId: Int, hardDelete: Bool = false) async throws -> ChatDeleteResponse {
        print("🔄 Eliminando grupo: \(roomId), hardDelete: \(hardDelete)")

        let queryItems = [URLQueryItem(name: "hard_delete", value: String(hardDelete))]
        guard let url = createURL(path: "/rooms/\(roomId)", queryItems: queryItems) else {
            throw ChatManagementError.serverError("URL inválida")
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "DELETE") else {
            throw ChatManagementError.serverError("No se pudo crear la solicitud")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log respuesta del backend
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Respuesta del backend (Delete Group): \(responseString)")
            }

            let result: ChatDeleteResponse = try handleResponse(data: data, response: response, type: ChatDeleteResponse.self)

            if result.deletedFromStream {
                print("✅ Grupo eliminado permanentemente de Stream: \(roomId)")
            } else {
                print("✅ Grupo eliminado (soft delete): \(roomId)")
            }
            print("   📊 Resultado: success=\(result.success), deletedFromStream=\(result.deletedFromStream)")

            return result
        } catch let error as ChatManagementError {
            throw error
        } catch {
            throw ChatManagementError.networkError(error)
        }
    }

    /// Elimina un canal huérfano (que NO existe en la base de datos pero sí en Stream)
    /// - Parameter channelId: ID del canal en Stream (puede incluir o no el prefijo "messaging:")
    /// - Returns: Respuesta con el resultado
    /// - Throws: ChatManagementError si falla
    /// - Note: Solo el creador (owner) puede eliminar canales huérfanos
    func deleteOrphanChannel(channelId: String) async throws -> DeleteOrphanChannelResponse {
        print("🔄 Eliminando canal huérfano: \(channelId)")

        guard let url = createURL(path: "/channels/orphan/\(channelId)") else {
            throw ChatManagementError.serverError("URL inválida")
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "DELETE") else {
            throw ChatManagementError.serverError("No se pudo crear la solicitud")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log respuesta del backend
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Respuesta del backend (Delete Orphan Channel): \(responseString)")
            }

            let result: DeleteOrphanChannelResponse = try handleResponse(data: data, response: response, type: DeleteOrphanChannelResponse.self)
            print("✅ Canal huérfano eliminado: \(channelId)")
            print("   📊 Resultado: success=\(result.success), message=\(result.message)")

            return result
        } catch let error as ChatManagementError {
            throw error
        } catch {
            throw ChatManagementError.networkError(error)
        }
    }

    /// Elimina un grupo con fallback automático a canal huérfano
    /// - Parameters:
    ///   - roomId: ID del grupo en la base de datos
    ///   - channelId: ID del canal en Stream (para fallback si el grupo no existe en BD)
    ///   - hardDelete: Si debe eliminarse de Stream Chat (default: true)
    /// - Returns: Mensaje de éxito
    /// - Throws: ChatManagementError si falla
    /// - Note: Primero intenta eliminar como grupo normal. Si retorna 404, intenta como huérfano.
    func deleteGroupSmart(roomId: Int, channelId: String, hardDelete: Bool = true) async throws -> String {
        print("🔄 Eliminando grupo con fallback inteligente: roomId=\(roomId), channelId=\(channelId)")

        do {
            // Paso 1: Intentar eliminación normal
            let response = try await deleteGroup(roomId: roomId, hardDelete: hardDelete)
            print("✅ Grupo eliminado correctamente (existía en BD)")
            return response.message

        } catch ChatManagementError.notFound {
            // Paso 2: Si 404, el grupo no existe en BD → intentar como huérfano
            print("⚠️ Grupo no encontrado en BD, intentando eliminar como canal huérfano...")

            do {
                let orphanResponse = try await deleteOrphanChannel(channelId: channelId)
                print("✅ Canal huérfano eliminado correctamente")
                return orphanResponse.message

            } catch ChatManagementError.conflict(let message) {
                // El backend dice que SÍ existe en BD (inconsistencia)
                print("❌ Conflicto: el backend indica que el canal existe en BD")
                throw ChatManagementError.conflict(message)

            } catch {
                // Otros errores del endpoint de huérfanos
                print("❌ Error eliminando como huérfano: \(error)")
                throw error
            }

        } catch {
            // Otros errores del endpoint normal (403, 400, etc.)
            print("❌ Error eliminando grupo: \(error)")
            throw error
        }
    }

    // MARK: - Deinit
    deinit {
        print("💀 ChatManagementService deinitialized")
    }
}

// MARK: - Convenience Extensions

extension ChatManagementService {

    /// Oculta un ChatRoom completo (valida que sea chat directo)
    func hideChat(room: ChatRoom) async throws -> ChatHideResponse {
        guard room.isDirect else {
            throw ChatManagementError.notDirectChat
        }
        return try await hideChat(roomId: room.id)
    }

    /// Muestra un ChatRoom oculto
    func showChat(room: ChatRoom) async throws -> ChatHideResponse {
        return try await showChat(roomId: room.id)
    }

    /// Sale de un grupo (valida que NO sea chat directo)
    func leaveGroup(room: ChatRoom, autoHide: Bool = true) async throws -> ChatLeaveResponse {
        guard !room.isDirect else {
            throw ChatManagementError.notGroupChat
        }

        // Validar que no sea chat de evento
        if room.eventId != nil {
            throw ChatManagementError.serverError("Los chats de eventos se cierran automáticamente")
        }

        return try await leaveGroup(roomId: room.id, autoHide: autoHide)
    }

    /// Elimina un grupo (solo admin)
    func deleteGroup(room: ChatRoom, hardDelete: Bool = false) async throws -> ChatDeleteResponse {
        guard !room.isDirect else {
            throw ChatManagementError.serverError("No puedes eliminar un chat directo")
        }

        return try await deleteGroup(roomId: room.id, hardDelete: hardDelete)
    }

    /// Elimina todos los mensajes de una conversación 1-to-1 (Delete For Me)
    /// - Parameter room: ChatRoom de la conversación
    /// - Returns: Respuesta con el número de mensajes eliminados
    /// - Throws: ChatManagementError si falla
    /// - Note: Solo funciona con chats 1-to-1. El otro usuario mantiene su historial intacto.
    func deleteConversation(room: ChatRoom) async throws -> ChatDeleteConversationResponse {
        guard room.isDirect else {
            throw ChatManagementError.serverError("Solo puedes eliminar conversaciones 1-to-1. Para grupos, usa 'salir del grupo'.")
        }

        return try await deleteConversation(roomId: room.id)
    }
}

// MARK: - Retry Logic Extension

extension ChatManagementService {

    /// Reintenta una operación hasta 3 veces en caso de error de red
    private func retryOperation<T>(
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as ChatManagementError {
                // No reintentar errores de lógica de negocio
                throw error
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    // Esperar antes de reintentar (exponential backoff)
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000) // nanoseconds
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? ChatManagementError.serverError("Error desconocido")
    }

    /// Oculta chat con retry automático
    func hideChatWithRetry(roomId: Int) async throws -> ChatHideResponse {
        return try await retryOperation {
            try await self.hideChat(roomId: roomId)
        }
    }
}
