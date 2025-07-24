//
//  EnhancedMessageBubble.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Burbuja de mensaje mejorada con soporte multimedia

import SwiftUI

struct EnhancedMessageBubble: View {
    let message: StreamChatMessage
    let themeManager: ThemeManager
    @ObservedObject private var streamService = StreamChatService.shared
    
    private var mediaContent: MediaContentType? {
        streamService.detectMediaContent(in: message)
    }
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // User name (for others)
                if !message.isFromCurrentUser {
                    Text(message.user.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 12)
                }
                
                // Message content
                if let media = mediaContent {
                    MediaContentView(
                        mediaType: media,
                        isFromCurrentUser: message.isFromCurrentUser,
                        themeManager: themeManager
                    )
                } else {
                    // Regular text message
                    Text(message.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(message.isFromCurrentUser ? .white : 
                                      Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(message.isFromCurrentUser ? 
                                      Color.dynamicAccent(theme: themeManager.currentTheme) :
                                      Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                }
                
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
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Media Content View
struct MediaContentView: View {
    let mediaType: MediaContentType
    let isFromCurrentUser: Bool
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media indicator
            HStack(spacing: 12) {
                // Icon
                Image(systemName: mediaType.displayIcon)
                    .font(.system(size: 24))
                    .foregroundColor(isFromCurrentUser ? .white : 
                                  Color.dynamicAccent(theme: themeManager.currentTheme))
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(getMediaTitle())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFromCurrentUser ? .white : 
                                      Color.dynamicText(theme: themeManager.currentTheme))
                    
                    if let subtitle = getMediaSubtitle() {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : 
                                          Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isFromCurrentUser ? 
                          Color.dynamicAccent(theme: themeManager.currentTheme) :
                          Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFromCurrentUser ? 
                                   Color.white.opacity(0.2) :
                                   Color.dynamicBorder(theme: themeManager.currentTheme),
                                   lineWidth: 1)
                    )
            )
            
            // Description if any
            if let description = getDescription(), !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.9) : 
                                  Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 200)
    }
    
    private func getMediaTitle() -> String {
        switch mediaType {
        case .image:
            return "Imagen"
        case .video:
            return "Video"
        case .voice:
            return "Mensaje de voz"
        }
    }
    
    private func getMediaSubtitle() -> String? {
        switch mediaType {
        case .image, .video:
            return "Toca para ver cuando esté disponible"
        case .voice(let duration):
            return duration
        }
    }
    
    private func getDescription() -> String? {
        switch mediaType {
        case .image(let desc), .video(let desc):
            return desc
        case .voice:
            return nil
        }
    }
}

// MARK: - Preview Provider
struct EnhancedMessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EnhancedMessageBubble(
                message: StreamChatMessage(
                    id: "1",
                    text: "Hola, ¿cómo estás?",
                    user: MessageUser(id: "1", name: "Juan", avatarURL: nil),
                    timestamp: Date(),
                    isFromCurrentUser: false
                ),
                themeManager: ThemeManager()
            )
            
            EnhancedMessageBubble(
                message: StreamChatMessage(
                    id: "2",
                    text: "📷 Imagen: Mi progreso de hoy",
                    user: MessageUser(id: "2", name: "Tú", avatarURL: nil),
                    timestamp: Date(),
                    isFromCurrentUser: true
                ),
                themeManager: ThemeManager()
            )
            
            EnhancedMessageBubble(
                message: StreamChatMessage(
                    id: "3",
                    text: "🎤 Mensaje de voz (0:45)",
                    user: MessageUser(id: "1", name: "Entrenador", avatarURL: nil),
                    timestamp: Date(),
                    isFromCurrentUser: false
                ),
                themeManager: ThemeManager()
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}