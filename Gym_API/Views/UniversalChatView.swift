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
        let _ = print("🎨 UniversalChatView body rendering - Chat: \(chatRoom.streamChannelId)")
        let _ = print("🎨 Estado actual: isLoading=\(isLoading), streamService.isLoading=\(streamChatService.isLoading), streamService.isConnected=\(streamChatService.isConnected)")
        let _ = print("🎨 Errores: local=\(errorMessage ?? "nil"), stream=\(streamChatService.errorMessage ?? "nil")")
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
                ErrorChatView(message: errorMessage, themeManager: themeManager, onRetry: {
                    // Reset states para permitir retry
                    self.errorMessage = nil
                    self.streamChatService.errorMessage = nil
                    self.streamChatService.isConnected = false
                    self.hasLoadedChat = false
                    loadChatRoom()
                })
            } else if streamChatService.isConnected {
                // Nueva interfaz de chat estilo iMessage
                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(streamChatService.messages) { message in
                                    MessageBubbleView(message: message, themeManager: themeManager)
                                        .id(message.id)
                                }
                                
                                // Typing Indicator
                                if !streamChatService.typingUsers.isEmpty {
                                    TypingIndicatorView(typingUsers: streamChatService.typingUsers, themeManager: themeManager)
                                        .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                        .onChange(of: streamChatService.messages.count) { _, _ in
                            if let lastMessage = streamChatService.messages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Simple Input View
                    SimpleInputView(
                        newMessage: $newMessage,
                        onSendMessage: sendStreamMessage,
                        onTypingStart: streamChatService.startTyping,
                        onTypingStop: streamChatService.stopTyping,
                        themeManager: themeManager
                    )
                }
            } else {
                // Fallback Interface con debugging
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                        .scaleEffect(1.2)
                    
                    VStack(spacing: 8) {
                        Text("Conectando al chat...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("Estado: \(getConnectionStatus())")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        // Debugging detallado
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Debug Info:")
                                .font(.system(size: 10, weight: .bold))
                            Text("• isLoading: \(isLoading)")
                                .font(.system(size: 9))
                            Text("• streamService.isLoading: \(streamChatService.isLoading)")
                                .font(.system(size: 9))
                            Text("• streamService.isConnected: \(streamChatService.isConnected)")
                                .font(.system(size: 9))
                            Text("• hasLoadedChat: \(hasLoadedChat)")
                                .font(.system(size: 9))
                            Text("• streamToken: \(streamToken != nil ? "✓" : "✗")")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.top, 8)
                    }
                    
                    Button("Force reconnection") {
                        // Reset completo y reintentar
                        streamChatService.disconnect()
                        errorMessage = nil
                        streamChatService.errorMessage = nil
                        hasLoadedChat = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            loadChatRoom()
                        }
                    }
                    .padding(.top, 16)
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .padding()
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarHidden(true)
        .onAppear {
            print("👀 UniversalChatView onAppear - Chat: \(chatRoom.streamChannelId)")
            loadChatRoom()
        }
        .onDisappear {
            // Reset del flag y desconectar del chat cuando se cierre la vista
            hasLoadedChat = false
            Task {
                streamChatService.disconnect()
            }
        }
    }
    
    // MARK: - Functions
    private func loadChatRoom() {
        // Solo verificar si ya estamos cargando este mismo chat
        if isLoading {
            print("⚠️ Chat ya está cargando, saltando loadChatRoom")
            return
        }
        
        print("🚀 Iniciando loadChatRoom para chat \(chatRoom.id)")
        isLoading = true
        errorMessage = nil
        
        // Configurar el authService en el ChatService
        chatService.authService = authService
        
        Task {
            // Timeout de 30 segundos para toda la operación
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 segundos
                if isLoading {
                    print("⏱️ Timeout alcanzado en loadChatRoom")
                    await MainActor.run {
                        errorMessage = "Tiempo de espera agotado. Por favor intenta de nuevo."
                        isLoading = false
                        hasLoadedChat = false // Permitir reintentos
                    }
                }
            }
            
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
                    print("🔧 Iniciando conexión a Stream.io...")
                    streamChatService.connectToChat(
                        token: streamTokenResponse.token,
                        apiKey: streamTokenResponse.apiKey,
                        userId: formattedUserId,
                        channelId: chatRoom.streamChannelId
                    )
                    
                    // NO marcar como cargado aquí - dejar que StreamChatService maneje el estado
                    isLoading = false
                    print("🔧 Token procesado, esperando conexión de StreamChatService...")
                    
                } else {
                    errorMessage = chatService.errorMessage ?? "No se pudo obtener el token de Stream"
                    print("⚠️ No se pudo obtener el token de Stream: \(errorMessage ?? "Error desconocido")")
                    isLoading = false
                    hasLoadedChat = false // Permitir reintentos
                }
                
                // Cancelar el timeout si terminamos antes
                timeoutTask.cancel()
                
            } catch {
                print("❌ Error en loadChatRoom: \(error)")
                errorMessage = "Error al cargar el chat: \(error.localizedDescription)"
                isLoading = false
                hasLoadedChat = false // Permitir reintentos
                timeoutTask.cancel()
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
    
    private func getConnectionStatus() -> String {
        if isLoading { return "Cargando token..." }
        if streamChatService.isLoading { return "Conectando a Stream..." }
        if streamChatService.isConnected { return "Conectado" }
        if streamChatService.errorMessage != nil { return "Error de conexión" }
        if errorMessage != nil { return "Error de token" }
        return "Inicializando..."
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
            createdAt: Date(),
            lastMessageAt: nil,
            lastMessageText: nil
        ),
        authService: AuthServiceDirect()
    )
}