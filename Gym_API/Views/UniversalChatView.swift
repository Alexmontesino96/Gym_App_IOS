import SwiftUI

struct UniversalChatView: View {
    let chatRoom: ChatRoom
    @ObservedObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    @ObservedObject private var chatService = ChatService.shared
    @ObservedObject private var streamChatService = StreamChatService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var streamToken: StreamTokenResponse?
    @State private var newMessage = ""
    @State private var hasLoadedChat = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Universal Chat Header
            UniversalChatHeaderView(
                chatRoom: chatRoom,
                isLoading: isLoading || streamChatService.isLoading,
                themeManager: themeManager,
                onBackPressed: {
                    dismiss()
                }
            )
            
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
        
        print("🚀 Iniciando loadChatRoom para chat \(chatRoom.id)")
        isLoading = true
        hasLoadedChat = true
        errorMessage = nil
        
        // Configurar el authService en el ChatService
        chatService.authService = authService
        
        Task {
            do {
                // Obtener token de Stream directamente
                if let streamTokenResponse = await chatService.getStreamToken() {
                    streamToken = streamTokenResponse
                    
                    print("✅ Token obtenido exitosamente")
                    print("🎫 Token obtenido para usuario ID: \(streamTokenResponse.internalUserId)")
                    print("💬 Canal: \(chatRoom.streamChannelId)")
                    let formattedUserId = "user_\(streamTokenResponse.internalUserId)"
                    print("🔍 User ID que enviaremos a Stream: \(formattedUserId)")
                    
                    // Conectar a Stream.io usando los datos del ChatRoom
                    streamChatService.connectToChat(
                        token: streamTokenResponse.token,
                        apiKey: streamTokenResponse.apiKey,
                        userId: formattedUserId,
                        channelId: chatRoom.streamChannelId
                    )
                    
                    isLoading = false
                    
                } else {
                    errorMessage = "No se pudo obtener el token de Stream"
                    print("⚠️ No se pudo obtener el token de Stream")
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

// MARK: - Universal Chat Header View
struct UniversalChatHeaderView: View {
    let chatRoom: ChatRoom
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
            
            // Chat Icon
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: chatRoom.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Chat Info
            VStack(alignment: .leading, spacing: 2) {
                Text(chatRoom.chatType.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(chatRoom.displayName)
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

// MARK: - Preview
#Preview {
    UniversalChatView(
        chatRoom: ChatRoom(
            id: 1,
            name: "Chat General",
            isDirect: false,
            eventId: nil,
            streamChannelId: "general_123",
            streamChannelType: "messaging",
            createdAt: Date()
        ),
        authService: AuthServiceDirect()
    )
}