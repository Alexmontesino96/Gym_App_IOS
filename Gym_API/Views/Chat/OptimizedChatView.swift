import SwiftUI
import Combine

// MARK: - Optimized Chat View
struct OptimizedChatView: View {
    let conversationId: String
    let conversationName: String
    
    @StateObject private var chatProviderManager = ChatProviderManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var serverUpdateObserver: NSObjectProtocol?
    
    // Computed property para mensajes ordenados (cacheado con límite para memoria)
    private var sortedMessages: [ChatMessage] {
        let sorted = messages.sorted { $0.timestamp < $1.timestamp }
        // Limitar en UI a máximo 100 mensajes para evitar memory issues
        return Array(sorted.suffix(100))
    }
    
    init(conversationId: String, conversationName: String) {
        self.conversationId = conversationId
        self.conversationName = conversationName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
            messagesView
            
            // Input
            messageInputView
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .onAppear {
            loadMessages()
            setupServerUpdateListener()
        }
        .onDisappear {
            // Limpiar observers para evitar memory leaks
            if let observer = serverUpdateObserver {
                NotificationCenter.default.removeObserver(observer)
                serverUpdateObserver = nil
            }
            
            // Limpiar mensajes antiguos para liberar memoria
            if messages.count > 50 {
                let recentMessages = Array(messages.sorted { $0.timestamp < $1.timestamp }.suffix(50))
                messages = recentMessages
                print("🧹 Mensajes recortados a 50 más recientes para liberar memoria")
            }
        }
    }
    
    // MARK: - Header
    private var chatHeader: some View {
        HStack {
            Text(conversationName)
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }
    
    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    // Mostrar mensajes en orden cronológico (más antiguos arriba)
                    ForEach(sortedMessages) { message in
                        MessageBubble(message: message, themeManager: themeManager)
                            .padding(.horizontal)
                            .id(message.id)
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: messages.count) { _ in
                // Scroll al último mensaje cuando se agregan nuevos mensajes
                if let lastMessage = sortedMessages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll al último mensaje al cargar la vista
                if let lastMessage = sortedMessages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Message Input
    private var messageInputView: some View {
        HStack {
            TextField("Escribe un mensaje...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Enviar") {
                sendMessage()
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }
    
    // MARK: - Actions
    
    /// Carga mensajes usando estrategia cache-first para experiencia instantánea
    private func loadMessages() {
        print("📱 Cargando mensajes para conversación: \(conversationId)")
        
        // 1. Cargar desde caché inmediatamente (sin loading state)
        let cachedMessages = MessageCacheManager.shared.getCachedMessages(for: conversationId)
        
        if !cachedMessages.isEmpty {
            self.messages = cachedMessages
            print("📦 Mostrando \(cachedMessages.count) mensajes desde caché")
        }
        
        // 2. Cargar mensajes frescos solo si no hay caché o en background
        if cachedMessages.isEmpty {
            isLoading = true
        }
        
        Task {
            do {
                // Usar el nuevo método con caché si está disponible
                let freshMessages: [ChatMessage]
                if let streamProvider = chatProviderManager.currentProvider as? GetStreamChatProvider {
                    freshMessages = try await streamProvider.getMessagesWithCache(for: conversationId)
                } else {
                    // Fallback al método original
                    freshMessages = try await chatProviderManager.getMessages(for: conversationId)
                }
                
                await MainActor.run {
                    // Solo actualizar si hay diferencias o si no había caché
                    if cachedMessages.isEmpty || !messagesAreEqual(freshMessages, self.messages) {
                        self.messages = freshMessages
                        print("🔄 Mensajes actualizados: \(freshMessages.count)")
                    } else {
                        print("✅ Mensajes ya están actualizados")
                    }
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    // Si había caché, mantener los mensajes y solo mostrar error
                    if cachedMessages.isEmpty {
                        self.errorMessage = error.localizedDescription
                    } else {
                        print("⚠️ Error actualizando mensajes, manteniendo caché: \(error)")
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Envía mensaje con UI optimista - aparece inmediatamente
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        
        let optimisticMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            text: text,
            authorId: "current_user", // TODO: Get actual user ID
            authorName: "Current User", // TODO: Get actual user name
            timestamp: Date(),
            isFromCurrentUser: true,
            syncStatus: .sending // Marcar como enviando
        )
        
        // Agregar inmediatamente a la UI (al final de la lista)
        messages.append(optimisticMessage)
        print("📝 Mensaje agregado optimistamente a la UI")
        
        Task {
            do {
                let _ = try await chatProviderManager.sendMessage(optimisticMessage, to: conversationId)
                print("✅ Mensaje enviado exitosamente")
                // El mensaje se actualizará automáticamente a través del caché
                
            } catch {
                await MainActor.run {
                    // Marcar mensaje como fallido en UI
                    if let index = self.messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                        var failedMessage = optimisticMessage
                        failedMessage.syncStatus = .failed
                        self.messages[index] = failedMessage
                        print("❌ Mensaje marcado como fallido en UI")
                    }
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Configura listener para actualizaciones desde servidor en background
    private func setupServerUpdateListener() {
        serverUpdateObserver = NotificationCenter.default.addObserver(
            forName: .messagesUpdatedFromServer,
            object: nil,
            queue: .main
        ) { [self] notification in
            guard let notificationConversationId = notification.userInfo?["conversationId"] as? String,
                  notificationConversationId == self.conversationId,
                  let freshMessages = notification.userInfo?["messages"] as? [ChatMessage] else { return }
            
            print("🔄 Actualizando mensajes desde servidor en background")
            
            // Solo actualizar si hay diferencias reales
            if !messagesAreEqual(freshMessages, self.messages) {
                self.messages = freshMessages
                print("✅ UI actualizada con mensajes frescos del servidor")
            }
        }
    }
    
    /// Compara dos arrays de mensajes para detectar diferencias
    private func messagesAreEqual(_ messages1: [ChatMessage], _ messages2: [ChatMessage]) -> Bool {
        guard messages1.count == messages2.count else { return false }
        
        for i in 0..<min(messages1.count, messages2.count) {
            if messages1[i].id != messages2[i].id || 
               messages1[i].text != messages2[i].text ||
               messages1[i].syncStatus != messages2[i].syncStatus {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading) {
                HStack {
                    Text(message.text)
                        .padding()
                        .background(
                            message.isFromCurrentUser 
                                ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(message.syncStatus == .failed ? 0.5 : 1.0)
                                : Color.dynamicSurface(theme: themeManager.currentTheme)
                        )
                        .foregroundColor(
                            message.isFromCurrentUser 
                                ? .white 
                                : Color.dynamicText(theme: themeManager.currentTheme)
                        )
                        .cornerRadius(16)
                    
                    // Indicador de estado de sincronización
                    if message.isFromCurrentUser {
                        syncStatusIcon(for: message.syncStatus)
                    }
                }
                
                HStack {
                    Text(formatDate(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    if message.isFromCurrentUser && message.syncStatus == .failed {
                        Text("Error al enviar")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func syncStatusIcon(for status: MessageSyncStatus) -> some View {
        switch status {
        case .pending, .sending:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        case .synced:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Preview
#Preview {
    OptimizedChatView(
        conversationId: "test_conversation",
        conversationName: "Chat de Prueba"
    )
    .environmentObject(ThemeManager())
}