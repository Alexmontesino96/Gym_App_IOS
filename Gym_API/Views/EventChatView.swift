import SwiftUI

struct EventChatView: View {
    let eventId: String
    let eventTitle: String
    @ObservedObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    @ObservedObject private var chatService = ChatService.shared
    @ObservedObject private var streamChatService = StreamChatService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var streamToken: StreamTokenResponse?
    @State private var chatRoom: ChatRoomSchema?
    @State private var newMessage = ""
    @State private var hasLoadedChat = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern Chat Header
            ChatHeaderView(eventTitle: eventTitle, isLoading: isLoading || streamChatService.isLoading, themeManager: themeManager, onBackPressed: {
                dismiss()
            })
            
            // Chat Content
            if isLoading || streamChatService.isLoading {
                LoadingChatView(themeManager: themeManager)
            } else if let errorMessage = errorMessage ?? streamChatService.errorMessage {
                ErrorChatView(message: errorMessage, themeManager: themeManager, onRetry: loadChatRoom)
            } else if streamChatService.isConnected {
                // Stream.io Chat Interface
                StreamChatInterface(
                    messages: streamChatService.messages,
                    newMessage: $newMessage,
                    onSendMessage: sendStreamMessage,
                    onTypingStart: streamChatService.startTyping,
                    onTypingStop: streamChatService.stopTyping,
                    typingUsers: streamChatService.typingUsers,
                    themeManager: themeManager
                )
            } else {
                // Fallback Interface
                VStack {
                    Spacer()
                    Text("Conectando al chat...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Spacer()
                }
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarHidden(true)
        .onAppear {
            loadChatRoom()
        }
        .onDisappear {
            // Reset del flag y desconectar del chat cuando se cierre la vista
            hasLoadedChat = false
            Task {
                await streamChatService.disconnect()
            }
        }
    }
    
    // MARK: - Functions
    private func loadChatRoom() {
        // Solo verificar si ya estamos cargando este mismo chat o ya se cargó
        if isLoading || hasLoadedChat {
            print("⚠️ Chat ya está cargando o ya fue cargado, saltando loadChatRoom")
            return
        }
        
        print("🚀 Iniciando loadChatRoom para evento \(eventId)")
        isLoading = true
        hasLoadedChat = true
        errorMessage = nil
        
        // Configurar el authService en el ChatService
        chatService.authService = authService
        
        Task {
            do {
                // Convertir eventId de String a Int
                guard let eventIdInt = Int(eventId) else {
                    errorMessage = "ID de evento inválido"
                    isLoading = false
                    return
                }
                
                // Obtener datos del chat desde la API
                if let chatData = await chatService.getChatDataForEvent(eventId: eventIdInt) {
                    streamToken = chatData.token
                    chatRoom = chatData.room
                    
                    print("✅ Chat cargado exitosamente")
                    print("🎫 Token obtenido para usuario ID: \(chatData.token.internalUserId)")
                    print("💬 Canal: \(chatData.room.streamChannelId)")
                    let formattedUserId = "user_\(chatData.token.internalUserId)"
                    print("🔍 User ID que enviaremos a Stream: \(formattedUserId)")
                    
                    // Conectar a Stream.io con los datos reales
                    streamChatService.connectToChat(
                        token: chatData.token.token,
                        apiKey: chatData.token.apiKey,
                        userId: formattedUserId,
                        channelId: chatData.room.streamChannelId
                    )
                    
                    // No cambiar isLoading aquí - se maneja en la UI basado en streamChatService.isLoading
                    isLoading = false
                    
                } else {
                    errorMessage = "No se pudieron obtener datos del chat"
                    print("⚠️ No se pudieron obtener datos del chat")
                    isLoading = false
                }
                
            } catch {
                isLoading = false
                errorMessage = "Error al cargar el chat: \(error.localizedDescription)"
                print("❌ Error cargando chat: \(error)")
            }
        }
    }
    
    
    private func sendStreamMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enviar mensaje a Stream.io
        streamChatService.sendMessage(messageToSend)
        
        // Limpiar input
        newMessage = ""
    }
}

// MARK: - Modern Chat Header View
struct ChatHeaderView: View {
    let eventTitle: String
    let isLoading: Bool
    let themeManager: ThemeManager
    let onBackPressed: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: onBackPressed) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            // Event Icon
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Event Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Chat del Evento")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(eventTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Loading or Action Buttons
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .overlay(
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Loading Chat View
struct LoadingChatView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)
            
            Text("Cargando chat...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
}

// MARK: - Error Chat View
struct ErrorChatView: View {
    let message: String
    let themeManager: ThemeManager
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme == .dark ? .orange : .red)
            
            Text("Error al cargar el chat")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: onRetry) {
                Text("Reintentar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
}

// MARK: - Modern Chat Interface
struct ModernChatInterface: View {
    @Binding var messages: [String]
    @Binding var newMessage: String
    let onSendMessage: () -> Void
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            ModernMessageBubble(
                                message: message,
                                isFromUser: index % 2 == 0,
                                timestamp: Date(),
                                themeManager: themeManager
                            )
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.backgroundPrimary)
                .onChange(of: messages.count) { _, _ in
                    if !messages.isEmpty {
                        withAnimation(.smooth(duration: 0.3)) {
                            proxy.scrollTo(messages.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input
            ModernMessageInput(
                text: $newMessage,
                onSend: onSendMessage,
                themeManager: themeManager
            )
        }
    }
}

// MARK: - Modern Message Bubble
struct ModernMessageBubble: View {
    let message: String
    let isFromUser: Bool
    let timestamp: Date
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                    
                    Text(formatMessageTime(timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.surfaceSecondary)
                        )
                    
                    Text(formatMessageTime(timestamp))
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

// MARK: - Modern Message Input
struct ModernMessageInput: View {
    @Binding var text: String
    let onSend: () -> Void
    let onTypingStart: (() -> Void)?
    let onTypingStop: (() -> Void)?
    let themeManager: ThemeManager
    
    init(text: Binding<String>, onSend: @escaping () -> Void, onTypingStart: (() -> Void)? = nil, onTypingStop: (() -> Void)? = nil, themeManager: ThemeManager) {
        self._text = text
        self.onSend = onSend
        self.onTypingStart = onTypingStart
        self.onTypingStop = onTypingStop
        self.themeManager = themeManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                }
                
                // Text Input
                HStack(spacing: 8) {
                    TextField("Escribe un mensaje...", text: $text, axis: .vertical)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1...4)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            onSend()
                        }
                        .onChange(of: text) { _, newValue in
                            if !newValue.isEmpty {
                                onTypingStart?()
                            } else {
                                onTypingStop?()
                            }
                        }
                    
                    // Emoji Button
                    Button(action: {}) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
                
                // Send Button
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
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
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        }
    }
}

// MARK: - Stream Chat Interface
struct StreamChatInterface: View {
    let messages: [StreamChatMessage]
    @Binding var newMessage: String
    let onSendMessage: () -> Void
    let onTypingStart: () -> Void
    let onTypingStop: () -> Void
    let typingUsers: [String]
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            StreamMessageBubble(message: message, themeManager: themeManager)
                                .id(message.id)
                        }
                        
                        // Typing Indicator
                        if !typingUsers.isEmpty {
                            StreamTypingIndicator(typingUsers: typingUsers, themeManager: themeManager)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation(.smooth(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input
            ModernMessageInput(
                text: $newMessage,
                onSend: onSendMessage,
                onTypingStart: onTypingStart,
                onTypingStop: onTypingStop,
                themeManager: themeManager
            )
        }
    }
}

// MARK: - Stream Message Bubble
struct StreamMessageBubble: View {
    let message: StreamChatMessage
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // User name
                    Text(message.user.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 16)
                    
                    Text(message.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                        .padding(.horizontal, 16)
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

// MARK: - Stream Typing Indicator
struct StreamTypingIndicator: View {
    let typingUsers: [String]
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(typingUsers.joined(separator: ", ")) está escribiendo...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .padding(.horizontal, 16)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .frame(width: 6, height: 6)
                            .opacity(0.3)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: Date())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }
            
            Spacer(minLength: 50)
        }
    }
}


// MARK: - Preview
#Preview {
    EventChatView(
        eventId: "608",
        eventTitle: "Torneo Interno",
        authService: AuthServiceDirect()
    )
} 