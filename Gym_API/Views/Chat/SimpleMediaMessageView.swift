//
//  SimpleMediaMessageView.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Vista simplificada para mensajes con indicadores multimedia

import SwiftUI

struct SimpleMediaMessageView: View {
    let message: StreamChatMessage
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // User name (for others' messages)
                if !message.isFromCurrentUser {
                    Text(message.user.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 12)
                }
                
                // Message with media indicator
                HStack(spacing: 4) {
                    if let mediaType = detectMediaType(in: message.text) {
                        Image(systemName: mediaType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.9) : 
                                          Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    
                    Text(message.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(message.isFromCurrentUser ? .white : 
                                      Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isFromCurrentUser ? 
                              Color.dynamicAccent(theme: themeManager.currentTheme) :
                              Color.dynamicSurface(theme: themeManager.currentTheme))
                )
                
                // Timestamp
                Text(formatMessageTime(message.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                    .padding(.horizontal, 12)
            }
            
            if !message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func detectMediaType(in text: String) -> MediaTypeIndicator? {
        if text.contains("📷") || text.contains("Imagen") {
            return .image
        } else if text.contains("🎥") || text.contains("Video") {
            return .video
        } else if text.contains("🎤") || text.contains("Mensaje de voz") {
            return .voice
        }
        return nil
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum MediaTypeIndicator {
    case image
    case video
    case voice
    
    var icon: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .voice:
            return "mic"
        }
    }
}