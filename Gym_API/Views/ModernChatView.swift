import SwiftUI

// MARK: - Modern Chat View with Custom Colors
struct ModernChatView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var streamChatService = StreamChatService.shared
    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            ChatHeader(themeManager: themeManager, onBackPressed: {
                dismiss()
            })
            
            // Stream Chat Interface
            if streamChatService.isConnected {
                StreamChatInterface(
                    messages: streamChatService.messages,
                    newMessage: $messageText,
                    onSendMessage: sendMessage,
                    onTypingStart: streamChatService.startTyping,
                    onTypingStop: streamChatService.stopTyping,
                    typingUsers: streamChatService.typingUsers,
                    themeManager: themeManager
                )
            } else if streamChatService.isLoading {
                LoadingChatView(themeManager: themeManager)
            } else if let errorMessage = streamChatService.errorMessage {
                ErrorChatView(message: errorMessage, themeManager: themeManager, onRetry: {})
            } else {
                VStack {
                    Spacer()
                    Text("No hay chat activo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Spacer()
                }
            }
            
            // Message Input
            MessageInput(text: $messageText, onSend: sendMessage, themeManager: themeManager)
        }
        .background(Color.backgroundPrimary)
        .navigationBarHidden(true)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enviar mensaje a Stream.io
        streamChatService.sendMessage(messageToSend)
        
        // Limpiar input
        messageText = ""
    }
}

// MARK: - Chat Header
struct ChatHeader: View {
    let themeManager: ThemeManager
    let onBackPressed: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: {
                onBackPressed()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
            }
            
            // Profile Image
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("GYM")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.textPrimary)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Gym Community")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("En línea")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.successColor)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "video")
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                }
                
                Button(action: {}) {
                    Image(systemName: "phone")
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfacePrimary)
        .overlay(
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.surfaceSecondary)
                        )
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                
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

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.textTertiary)
                        .frame(width: 8, height: 8)
                        .opacity(animationPhase == index ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.surfaceSecondary)
            )
            
            Spacer(minLength: 50)
        }
        .onAppear {
            withAnimation {
                animationPhase = 2
            }
        }
    }
}

// MARK: - Message Input
struct MessageInput: View {
    @Binding var text: String
    let onSend: () -> Void
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.surfaceSecondary)
                        )
                }
                
                // Text Input
                HStack(spacing: 8) {
                    TextField("Escribe un mensaje...", text: $text, axis: .vertical)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1...4)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    // Emoji Button
                    Button(action: {}) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.surfaceSecondary)
                )
                
                // Send Button
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3) : Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.smooth(duration: 0.2), value: text.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.surfacePrimary)
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Preview
struct ModernChatView_Previews: PreviewProvider {
    static var previews: some View {
        ModernChatView()
    }
} 