//
//  DirectMessageService.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/22/25.
//

import Foundation
import SwiftUI

// MARK: - Chat Room Models for API Response
struct ChatRoomResponse: Codable {
    let name: String
    let isDirect: Bool
    let eventId: Int?
    let id: Int
    let streamChannelId: String
    let streamChannelType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case isDirect = "is_direct"
        case eventId = "event_id"
        case id
        case streamChannelId = "stream_channel_id"
        case streamChannelType = "stream_channel_type"
        case createdAt = "created_at"
    }
}

// MARK: - Extension for ChatRoomResponse
extension ChatRoomResponse {
    /// Convierte la respuesta de la API en un ChatChannelData
    func toChatChannelData() -> ChatChannelData {
        let channelType = streamChannelId.getChannelType()
        
        // Usar el nombre de la API, que ya viene formateado correctamente
        let displayName = name
        
        // Extraer participantes del ID si es un chat directo
        var participants: [String] = []
        if isDirect {
            let parsed = streamChannelId.parseStreamChannelId()
            if let userId1 = parsed.metadata["userId1"], let userId2 = parsed.metadata["userId2"] {
                participants = [userId1, userId2]
            }
        }
        
        // Convertir fecha string a Date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        
        return ChatChannelData(
            id: streamChannelId,
            name: displayName,
            type: channelType,
            participants: participants,
            lastMessage: nil,
            lastMessageAt: nil,
            createdAt: createdDate,
            unreadCount: 0,
            isActive: true
        )
    }
}

@MainActor
class DirectMessageService: ObservableObject {
    @Published var isLoadingRoom = false
    @Published var errorMessage: String?
    @Published var allUsers: [UserProfile] = []
    @Published var isLoadingUsers = false
    @Published var usersErrorMessage: String?

    private let baseURL = apiBaseURL
    var authService: AuthServiceDirect?
    
    // MARK: - Direct Chat Room Creation/Retrieval
    
    func getOrCreateDirectChat(with otherUserId: Int, gymId: Int) async -> ChatRoomResponse? {
        print("🔗 DirectMessageService: Obteniendo/creando chat directo con usuario \(otherUserId)")
        
        guard let authService = authService,
              let accessToken = await authService.getValidAccessToken() else {
            print("❌ DirectMessageService: No se pudo obtener token de acceso")
            await MainActor.run {
                errorMessage = "No se pudo obtener token de acceso"
            }
            return nil
        }
        
        await MainActor.run {
            isLoadingRoom = true
            errorMessage = nil
        }
        
        print("🔗 DirectMessageService: Token obtenido, realizando petición...")
        
        do {
            let urlString = "\(baseURL)/chat/rooms/direct/\(otherUserId)"
            print("🌐 DirectMessageService: URL: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                print("❌ DirectMessageService: URL inválida: \(urlString)")
                throw DirectMessageError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            print("🔄 DirectMessageService: Enviando petición GET...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DirectMessageError.invalidResponse
            }
            
            print("📞 Response status for direct chat: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let chatRoom = try decoder.decode(ChatRoomResponse.self, from: data)
                
                print("✅ DirectMessageService: Chat room creado/obtenido: \(chatRoom.streamChannelId)")
                await MainActor.run {
                    isLoadingRoom = false
                }
                return chatRoom
            } else {
                let errorData = String(data: data, encoding: .utf8) ?? "Error desconocido"
                print("❌ DirectMessageService: Error HTTP \(httpResponse.statusCode) - \(errorData)")
                await MainActor.run {
                    errorMessage = "Error al obtener chat directo: \(httpResponse.statusCode)"
                    isLoadingRoom = false
                }
                return nil
            }
        } catch {
            print("❌ DirectMessageService: Error de conexión: \(error)")
            await MainActor.run {
                errorMessage = "Error de conexión: \(error.localizedDescription)"
                isLoadingRoom = false
            }
            return nil
        }
    }
    
    // MARK: - Load All Users
    
    func loadAllUsers() async {
        guard let authService = authService,
              let accessToken = await authService.getValidAccessToken() else {
            usersErrorMessage = "No se pudo obtener token de acceso"
            return
        }
        
        isLoadingUsers = true
        usersErrorMessage = nil
        
        do {
            // Usar el mismo endpoint que ClassService pero sin filtro de role
            guard let url = URL(string: "\(baseURL)/users/p/gym-participants?skip=0&limit=100") else {
                throw DirectMessageError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let gymId = GymService.shared.currentGymId ?? 4
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DirectMessageError.invalidResponse
            }
            
            print("📞 Response status for all users: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let usersResponse = try decoder.decode([UserProfile].self, from: data)
                self.allUsers = usersResponse
                
                print("✅ Loaded \(usersResponse.count) users")
            } else {
                let errorData = String(data: data, encoding: .utf8) ?? "Error desconocido"
                print("❌ Error loading users: \(httpResponse.statusCode) - \(errorData)")
                usersErrorMessage = "Error al cargar usuarios: \(httpResponse.statusCode)"
            }
        } catch {
            print("❌ Error fetching users: \(error)")
            usersErrorMessage = "Error de conexión: \(error.localizedDescription)"
        }
        
        isLoadingUsers = false
    }
}

// MARK: - Error Types

enum DirectMessageError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .decodingError:
            return "Error al procesar datos"
        case .networkError(let message):
            return "Error de red: \(message)"
        }
    }
}