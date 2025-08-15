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
    @State private var messageUpdatesCancellable: AnyCancellable?
    
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
            setupMessageUpdatesListener()
            // Marcar como leído al entrar al chat
            markConversationAsRead()
        }
        .onDisappear {
            // Limpiar observers para evitar memory leaks
            if let observer = serverUpdateObserver {
                NotificationCenter.default.removeObserver(observer)
                serverUpdateObserver = nil
            }
            
            // Cancelar suscripción a actualizaciones de mensajes
            messageUpdatesCancellable?.cancel()
            messageUpdatesCancellable = nil
            
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
                if isLoading && messages.isEmpty {
                    // Show skeleton while loading
                    MessageListSkeleton(count: 8)
                        .padding(.top, 20)
                } else {
                    LazyVStack {
                        // Mostrar mensajes en orden cronológico (más antiguos arriba)
                        ForEach(sortedMessages) { message in
                            MessageBubble(message: message, themeManager: themeManager)
                                .padding(.horizontal)
                                .id(message.id)
                        }
                        
                        // Show loading skeleton at the bottom if updating
                        if isLoading && !messages.isEmpty {
                            MessageListSkeleton(count: 3)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.bottom, 8)
                }
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
    
    // MARK: - Enhanced Message Input
    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Text input field
            HStack(spacing: 8) {
                TextField("Escribe un mensaje...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1...4) // Allow up to 4 lines
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        messageText.isEmpty 
                                            ? Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3)
                                            : Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
                
                // Additional action buttons (optional)
                if messageText.isEmpty {
                    HStack(spacing: 8) {
                        Button(action: {
                            // TODO: Add attachment functionality
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.trailing, 8)
                }
            }
            
            // Send button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    sendMessage()
                }
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                            ? Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5)
                            : Color.dynamicAccent(theme: themeManager.currentTheme)
                    )
                    .scaleEffect(sendButtonPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: sendButtonPressed)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    sendButtonPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        sendButtonPressed = false
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.dynamicSurface(theme: themeManager.currentTheme)
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: -2
                )
        )
        .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
    }
    
    @State private var sendButtonPressed = false
    
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
        
        // Usar un ID temporal específico para poder rastrearlo
        let tempId = "temp_\(UUID().uuidString)"
        
        let optimisticMessage = ChatMessage(
            id: tempId,
            conversationId: conversationId,
            text: text,
            authorId: "current_user", // TODO: Get actual user ID
            authorName: "Current User", // TODO: Get actual user name
            authorAvatarURL: nil, // TODO: Get current user avatar URL
            timestamp: Date(),
            isFromCurrentUser: true,
            syncStatus: .sending // Marcar como enviando
        )
        
        // Agregar inmediatamente a la UI (al final de la lista)
        messages.append(optimisticMessage)
        print("📝 Mensaje agregado optimistamente a la UI con ID temporal: \(tempId)")
        
        Task {
            do {
                let _ = try await chatProviderManager.sendMessage(optimisticMessage, to: conversationId)
                print("✅ Mensaje enviado exitosamente")
                
                // Cuando llegue el mensaje real del servidor con el ID correcto,
                // se detectará como duplicado y no se agregará de nuevo
                
            } catch {
                await MainActor.run {
                    // Marcar mensaje como fallido en UI
                    if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
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
    
    /// Configura listener para actualizaciones individuales de mensajes (estado de sync)
    private func setupMessageUpdatesListener() {
        guard let provider = chatProviderManager.currentProvider else { return }
        
        let currentConversationId = conversationId
        
        messageUpdatesCancellable = provider.messageUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { update in
                guard update.conversationId == currentConversationId else { return }
                
                switch update.type {
                case .updated:
                    // Actualizar el mensaje en el array local
                    if let index = self.messages.firstIndex(where: { $0.id == update.message.id }) {
                        self.messages[index] = update.message
                        print("✅ Mensaje actualizado: \(update.message.id) - Estado: \(update.message.syncStatus)")
                    }
                    
                case .new:
                    // Verificar si es un mensaje que acabamos de enviar (evitar duplicados)
                    // Los mensajes optimistas tienen syncStatus .sending o .synced y son del usuario actual
                    let isDuplicate = update.message.isFromCurrentUser && 
                                     self.messages.contains(where: { msg in
                                         msg.isFromCurrentUser && 
                                         msg.text == update.message.text &&
                                         abs(msg.timestamp.timeIntervalSince(update.message.timestamp)) < 5 // Dentro de 5 segundos
                                     })
                    
                    if !isDuplicate {
                        self.messages.append(update.message)
                        print("➕ Nuevo mensaje agregado: \(update.message.id)")
                        // Si estamos viendo este chat y el mensaje es de otro usuario, marcar leído
                        if !update.message.isFromCurrentUser {
                            markConversationAsRead()
                        }
                    } else {
                        print("⚠️ Ignorando mensaje duplicado: \(update.message.text.prefix(20))...")
                    }
                    
                case .deleted:
                    self.messages.removeAll { $0.id == update.message.id }
                    print("🗑️ Mensaje eliminado: \(update.message.id)")
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

    /// Marca la conversación como leída en el proveedor (GetStream)
    private func markConversationAsRead() {
        let lastMessageId = sortedMessages.last?.id ?? ""
        Task {
            guard let provider = chatProviderManager.currentProvider else { return }
            do {
                try await provider.markAsRead(messagesUpTo: lastMessageId, in: conversationId)
                print("✅ Conversación marcada como leída: \(conversationId)")
            } catch {
                print("❌ Error al marcar como leído: \(error)")
            }
        }
    }
}

// MARK: - Enhanced Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    let themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Avatar for received messages
                MessageAvatarView(
                    authorName: message.authorName,
                    avatarURL: message.authorAvatarURL,
                    size: 32
                )
                .opacity(0.8)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Author name for received messages
                if !message.isFromCurrentUser {
                    Text(message.authorName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 4)
                }
                
                // Message bubble
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 0) {
                        Text(message.text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(bubbleTextColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(bubbleBackground)
                            .clipShape(BubbleShape(isFromCurrentUser: message.isFromCurrentUser))
                            .overlay(
                                BubbleShape(isFromCurrentUser: message.isFromCurrentUser)
                                    .stroke(bubbleBorderColor, lineWidth: bubbleBorderWidth)
                            )
                            .scaleEffect(isPressed ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isPressed)
                        
                        // Timestamp and status
                        HStack(spacing: 4) {
                            Text(formatDate(message.timestamp))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                            
                            if message.isFromCurrentUser {
                                syncStatusIcon(for: message.syncStatus)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                }
                
                // Error message
                if message.isFromCurrentUser && message.syncStatus == .failed {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        
                        Text("No se pudo enviar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                        
                        Button("Reintentar") {
                            // TODO: Implement retry functionality
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            }
            
            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var bubbleTextColor: Color {
        if message.isFromCurrentUser {
            return .white
        } else {
            return Color.dynamicText(theme: themeManager.currentTheme)
        }
    }
    
    private var bubbleBackground: Color {
        if message.isFromCurrentUser {
            let baseColor = Color.dynamicAccent(theme: themeManager.currentTheme)
            switch message.syncStatus {
            case .failed:
                return baseColor.opacity(0.6)
            case .sending, .pending:
                return baseColor.opacity(0.8)
            case .synced:
                return baseColor
            }
        } else {
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        }
    }
    
    private var bubbleBorderColor: Color {
        if message.isFromCurrentUser {
            return Color.clear
        } else {
            return Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.2)
        }
    }
    
    private var bubbleBorderWidth: CGFloat {
        message.isFromCurrentUser ? 0 : 1
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    @ViewBuilder
    private func syncStatusIcon(for status: MessageSyncStatus) -> some View {
        switch status {
        case .pending, .sending:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicTextSecondary(theme: themeManager.currentTheme)))
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green.opacity(0.8))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red.opacity(0.8))
        }
    }
}

// MARK: - Custom Bubble Shape
struct BubbleShape: Shape {
    let isFromCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromCurrentUser ? 
                [.topLeft, .topRight, .bottomLeft] : 
                [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Message Avatar View
struct MessageAvatarView: View {
    let authorName: String
    let avatarURL: String?
    let size: CGFloat
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .red]
        let index = abs(authorName.hashValue) % colors.count
        return colors[index]
    }
    
    private var initials: String {
        let components = authorName.components(separatedBy: .whitespaces)
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return "\(authorName.prefix(1))".uppercased()
        }
    }
    
    private var generatedAvatarFallback: some View {
        // Try UI Avatars service first, fallback to initials
        let encodedName = authorName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User"
        let avatarServiceURL = "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=random&color=fff&format=png"
        
        if let serviceURL = URL(string: avatarServiceURL) {
            return AnyView(
                AsyncImage(url: serviceURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundColor(.white)
                    @unknown default:
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            )
        } else {
            return AnyView(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(avatarColor)
                .frame(width: size, height: size)
            
            // Profile photo or initials
            Group {
                if let avatarURL = avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        case .failure(_), .empty:
                            generatedAvatarFallback
                        @unknown default:
                            generatedAvatarFallback
                        }
                    }
                } else {
                    generatedAvatarFallback
                }
            }
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
