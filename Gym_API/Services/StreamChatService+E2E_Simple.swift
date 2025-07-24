//
//  StreamChatService+E2E_Simple.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Extensión simplificada para E2E - versión inicial

import Foundation
import StreamChat

extension StreamChatService {
    
    // MARK: - Enviar Mensaje Encriptado (Simplificado)
    
    /// Envía un mensaje con indicador de que debería estar encriptado
    /// NOTA: La encriptación real se implementará cuando tengamos los endpoints del backend
    func sendEncryptedMessage(
        to channelId: String,
        text: String,
        recipientUserId: Int? = nil
    ) async throws {
        // Por ahora, solo agregar un prefijo para indicar que es un mensaje "seguro"
        let secureMessage = "🔐 " + text
        
        // Usar el método normal de envío
        sendMessage(secureMessage)
        
        print("📤 Mensaje enviado con indicador de seguridad")
    }
    
    // MARK: - Helpers para UI
    
    /// Verifica si un canal es elegible para E2E
    func isE2EEligible(channelId: String) -> Bool {
        // Por ahora, solo chats directos son elegibles
        return channelController?.channel?.isDirectMessageChannel ?? false
    }
    
    /// Obtiene el ID del otro usuario en un chat directo
    func getOtherUserId(in channelId: String) -> String? {
        guard let channel = channelController?.channel,
              channel.isDirectMessageChannel,
              let currentUserId = chatClient?.currentUserId else {
            return nil
        }
        
        // Buscar el otro miembro que no sea el usuario actual
        for member in channel.lastActiveMembers {
            if member.id != currentUserId {
                return member.id
            }
        }
        
        return nil
    }
}

// MARK: - Indicadores visuales para E2E
extension StreamChatMessage {
    /// Indica si el mensaje parece estar encriptado (basado en el prefijo)
    var hasEncryptionIndicator: Bool {
        return text.hasPrefix("🔐")
    }
    
    /// Texto sin el indicador de encriptación
    var textWithoutIndicator: String {
        if hasEncryptionIndicator {
            return String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return text
    }
}