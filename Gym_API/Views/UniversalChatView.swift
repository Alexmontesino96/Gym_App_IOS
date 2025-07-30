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
    @State private var showContent = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let _ = print("🎨 UniversalChatView body rendering - Chat: \(chatRoom.streamChannelId)")
        let _ = print("🎨 ChatRoom name: \(chatRoom.name ?? "nil")")
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
                // Enhanced loading state
                ZStack {
                    Color.dynamicBackground(theme: themeManager.currentTheme)
                    
                    VStack(spacing: 24) {
                        // Enhanced loading animation
                        EnhancedLoadingView(
                            message: getLoadingMessage(),
                            themeManager: themeManager
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage ?? streamChatService.errorMessage {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text("Error")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Retry") {
                        // Reset states para permitir retry
                        self.errorMessage = nil
                        self.streamChatService.errorMessage = nil
                        self.streamChatService.isConnected = false
                        self.hasLoadedChat = false
                        loadChatRoom()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            } else if streamChatService.isConnected || (!streamChatService.isLoading && streamToken != nil) {
                // Nueva interfaz de chat estilo iMessage con transición
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
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.95)
                .animation(.easeOut(duration: 0.3), value: showContent)
            } else {
                // Fallback Interface - mejorado
                ZStack {
                    Color.dynamicBackground(theme: themeManager.currentTheme)
                    
                    VStack(spacing: 20) {
                        // Pulse loading animation
                        PulseLoadingView(
                            message: "Connecting to chat...",
                            themeManager: themeManager
                        )
                        
                        // Subtle status text
                        Text(getConnectionStatus())
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                            .transition(.opacity)
                        
                        // Only show retry button after some time
                        if hasLoadedChat {
                            Button(action: {
                                // Reset completo y reintentar
                                streamChatService.disconnect()
                                errorMessage = nil
                                streamChatService.errorMessage = nil
                                hasLoadedChat = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    loadChatRoom()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14))
                                    Text("Retry")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 1)
                                )
                            }
                            .transition(.scale.combined(with: .opacity))
                            .padding(.top, 12)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: hasLoadedChat)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarHidden(true)
        .onAppear {
            print("👀 UniversalChatView onAppear - Chat: \(chatRoom.streamChannelId)")
            if !hasLoadedChat {
                hasLoadedChat = true
                loadChatRoom()
            }
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
                    
                    // Esperar un momento para la conexión y luego marcar como no cargando
                    await MainActor.run {
                        isLoading = false
                        // Activar transición suave
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showContent = true
                            }
                        }
                    }
                    print("🔧 Token procesado, esperando conexión de StreamChatService...")
                    
                } else {
                    await MainActor.run {
                        errorMessage = chatService.errorMessage ?? "No se pudo obtener el token de Stream"
                        print("⚠️ No se pudo obtener el token de Stream: \(errorMessage ?? "Error desconocido")")
                        isLoading = false
                        hasLoadedChat = false // Permitir reintentos
                    }
                }
                
                // Cancelar el timeout si terminamos antes
                timeoutTask.cancel()
                
            } catch {
                print("❌ Error en loadChatRoom: \(error)")
                await MainActor.run {
                    errorMessage = "Error al cargar el chat: \(error.localizedDescription)"
                    isLoading = false
                    hasLoadedChat = false // Permitir reintentos
                }
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
        if isLoading { return "Securing connection..." }
        if streamChatService.isLoading { return "Joining chat..." }
        if streamChatService.isConnected { return "Connected" }
        if streamChatService.errorMessage != nil { return "Connection issue" }
        if errorMessage != nil { return "Authentication issue" }
        return "Initializing..."
    }
    
    private func getLoadingMessage() -> String {
        if isLoading { 
            return "Setting up chat..."
        } else if streamChatService.isLoading {
            return "Joining conversation..."
        }
        return "Loading messages..."
    }
}

// MARK: - Universal Chat Header View
struct UniversalChatHeaderView: View {
    let chatRoom: ChatRoom
    let isLoading: Bool
    let themeManager: ThemeManager
    let onBackPressed: () -> Void
    @ObservedObject private var chatService = ChatService.shared
    
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
                if chatRoom.chatType == .direct {
                    // Para chats directos, mostrar solo el nombre del otro usuario
                    Text(chatService.getResolvedDisplayName(for: chatRoom))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                    
                    Text("Direct Message")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                } else {
                    // Para otros tipos de chat, mantener el comportamiento original
                    Text(chatRoom.chatType.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(chatRoom.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Loading or Action Buttons
            if isLoading {
                // Mini pulse animation in header
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isLoading ? 1.2 : 0.8)
                    .opacity(isLoading ? 0.6 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isLoading
                    )
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