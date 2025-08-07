import SwiftUI
import Auth0

// MARK: - Cached Conversation Model
struct CachedConversation: Codable {
    let id: String
    let name: String?
    let type: String
    let lastActivity: Date
    let lastMessageText: String?
    let lastMessageAuthor: String?
    let unreadCount: Int
}

// MARK: - Unified Messages View
/// Nueva implementación usando el sistema optimizado de chat
struct UnifiedMessagesView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    
    // MARK: - State Objects
    @StateObject private var chatProviderManager = ChatProviderManager.shared
    
    // MARK: - State Variables
    @State private var conversations: [ChatConversation] = []
    @State private var selectedConversation: ChatConversation?
    @State private var showingChat = false
    @State private var showingUserSelector = false
    @State private var showingSearch = false
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var hasInitialized = false
    @State private var errorMessage: String?
    @State private var isLoadingFromCache = false
    @State private var isUpdatingFromServer = false
    @State private var messageUpdateObserver: NSObjectProtocol?
    @State private var searchButtonPressed = false
    @State private var newMessageButtonPressed = false
    
    // MARK: - Computed Properties
    private var filteredConversations: [ChatConversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.name?.localizedCaseInsensitiveContains(searchText) == true ||
                conversation.lastMessage?.text.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Search Bar (if showing)
                    if showingSearch {
                        searchBarView
                    }
                    
                    // Content
                    contentView
                }
            }
            .onAppear {
                initializeIfNeeded()
                setupMessageUpdateListener()
            }
            .onDisappear {
                if let observer = messageUpdateObserver {
                    NotificationCenter.default.removeObserver(observer)
                    messageUpdateObserver = nil
                }
                
                // Limpiar conversaciones en exceso para liberar memoria
                if conversations.count > 30 {
                    conversations = Array(conversations.prefix(30))
                    print("🧹 Conversaciones recortadas a 30 para liberar memoria")
                }
            }
            .refreshable {
                await refreshConversations()
            }
            .sheet(isPresented: $showingUserSelector) {
                userSelectorSheet
            }
            .navigationDestination(isPresented: $showingChat) {
                chatDestination
            }
            .onChange(of: showingChat) { isShowing in
                print("🔄 showingChat cambió a: \(isShowing)")
                if isShowing {
                    print("📱 Intentando navegar a chat con conversación: \(selectedConversation?.id ?? "nil")")
                }
            }
        }
        .animation(.easeInOut, value: showingSearch)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Title and buttons
            HStack {
                Text("Messages")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Search button
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showingSearch.toggle()
                        }
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .scaleEffect(searchButtonPressed ? 0.9 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: searchButtonPressed)
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            searchButtonPressed = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                searchButtonPressed = false
                            }
                        }
                    }
                    
                    // New message button
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showingUserSelector = true
                        }
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .scaleEffect(newMessageButtonPressed ? 0.9 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: newMessageButtonPressed)
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            newMessageButtonPressed = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                newMessageButtonPressed = false
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Status indicators
            if !chatProviderManager.isInitialized || isUpdatingFromServer {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(isUpdatingFromServer ? "Actualizando..." : "Conectando...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            if let error = errorMessage {
                CompactErrorView(
                    message: error,
                    onRetry: {
                        errorMessage = nil
                        Task { await loadConversations() }
                    }
                )
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Search Bar View
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Buscar conversaciones...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            if isLoadingFromCache && conversations.isEmpty {
                // Show skeleton while loading from cache
                ScrollView {
                    ConversationListSkeleton(count: 8)
                }
            } else if filteredConversations.isEmpty && !isUpdatingFromServer {
                emptyStateView
            } else if filteredConversations.isEmpty && isUpdatingFromServer {
                // Show skeleton while updating from server
                ScrollView {
                    ConversationListSkeleton(count: 5)
                }
            } else {
                conversationsList
            }
        }
    }
    
    // MARK: - Conversations List
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredConversations) { conversation in
                    SwipeableConversationRow.withStandardActions(
                        conversation: conversation,
                        themeManager: themeManager,
                        onTap: {
                            print("🔘 Tap detectado en conversación: \(conversation.name ?? conversation.id)")
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedConversation = conversation
                                showingChat = true
                            }
                            print("📱 Navegando a chat con conversación: \(selectedConversation?.id ?? "nil")")
                            print("🔄 showingChat = \(showingChat)")
                        },
                        onMute: {
                            muteConversation(conversation)
                        },
                        onArchive: {
                            archiveConversation(conversation)
                        },
                        onDelete: {
                            deleteConversation(conversation)
                        }
                    )
                    .onChange(of: showingChat) { isShowing in
                        if !isShowing {
                            // Cuando volvemos del chat, NO reordenar automáticamente
                            // Solo reordenamos si hay cambios reales en lastActivity
                            print("🔙 Usuario salió del chat de: \\(selectedConversation?.name ?? \"N/A\")")
                            print("📋 Manteniendo orden actual de conversaciones")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .scaleEffect(emptyStateAnimationScale)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: emptyStateAnimationScale
                    )
            }
            .onAppear {
                emptyStateAnimationScale = 1.1
            }
            
            // Content
            VStack(spacing: 12) {
                Text("No conversations yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Start your first conversation with other gym members. Connect, share experiences, and stay motivated together!")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            // Action button
            Button(action: { 
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingUserSelector = true
                }
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Start a conversation")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
                .scaleEffect(emptyStateButtonPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: emptyStateButtonPressed)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    emptyStateButtonPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        emptyStateButtonPressed = false
                    }
                }
            }
            
            Spacer()
        }
        .padding(40)
    }
    
    @State private var emptyStateAnimationScale: CGFloat = 1.0
    @State private var emptyStateButtonPressed = false
    
    // MARK: - Chat Destination
    @ViewBuilder
    private var chatDestination: some View {
        if let conversation = selectedConversation {
            OptimizedChatView(
                conversationId: conversation.id,
                conversationName: conversation.name ?? "Chat"
            )
            .environmentObject(themeManager)
            .environmentObject(authService)
            .onAppear {
                print("✅ OptimizedChatView apareció para conversación: \(conversation.id)")
            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - User Selector Sheet
    private var userSelectorSheet: some View {
        NavigationView {
            VStack {
                Text("Seleccionar usuario para chat")
                    .font(.headline)
                    .padding()
                
                // TODO: Implementar selector de usuarios
                Text("Funcionalidad de selección de usuarios pendiente")
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Nuevo Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        showingUserSelector = false
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // Show skeleton if no cached data
        if conversations.isEmpty {
            isLoadingFromCache = true
        }
        
        // Cargar primero desde caché de forma síncrona
        loadConversationsFromCache()
        
        // Luego inicializar el sistema de chat y cargar desde GetStream
        Task {
            isUpdatingFromServer = true
            await initializeChatSystem()
            await loadConversations()
            isUpdatingFromServer = false
            isLoadingFromCache = false
        }
    }
    
    private func loadConversationsFromCache() {
        print("📦 Cargando conversaciones desde caché...")
        
        // Intentar cargar conversaciones desde caché
        if let data = UserDefaults.standard.data(forKey: "CachedConversations"),
           let cachedConversations = try? JSONDecoder().decode([CachedConversation].self, from: data) {
            
            print("✅ Conversaciones desde caché: \(cachedConversations.count)")
            
            // Convertir a ChatConversation
            self.conversations = cachedConversations.map { cached in
                ChatConversation(
                    id: cached.id,
                    name: cached.name,
                    type: ChatConversation.ConversationType(rawValue: cached.type) ?? .general,
                    members: [],
                    lastMessage: nil,
                    lastActivity: cached.lastActivity,
                    unreadCount: 0,
                    metadata: [:]
                )
            }.sorted { $0.lastActivity > $1.lastActivity }
        } else {
            print("📦 No hay conversaciones en caché")
        }
    }
    
    private func initializeChatSystem() async {
        guard !chatProviderManager.isInitialized else { return }
        
        do {
            // Pasar authService al inicializar el provider
            await chatProviderManager.initializeProvider(authService: authService)
            
            // Configurar credenciales si hay usuario autenticado
            if let user = authService.user {
                // Obtener token real desde la API
                await obtenerCredencialesReales(user: user)
            }
        } catch {
            errorMessage = "Error de conexión: \(error.localizedDescription)"
            print("❌ Error inicializando chat: \(error)")
        }
    }
    
    private func loadConversations() async {
        guard chatProviderManager.isInitialized else { return }
        
        do {
            let loadedConversations = try await chatProviderManager.getConversations()
            
            await MainActor.run {
                self.conversations = loadedConversations.sorted { conversation1, conversation2 in
                    conversation1.lastActivity > conversation2.lastActivity
                }
                self.errorMessage = nil
                
                // Guardar en caché para próxima vez
                self.saveConversationsToCache(loadedConversations)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error cargando conversaciones: \(error.localizedDescription)"
            }
            print("❌ Error cargando conversaciones: \(error)")
        }
    }
    
    private func saveConversationsToCache(_ conversations: [ChatConversation]) {
        let cachedConversations = conversations.map { conversation in
            CachedConversation(
                id: conversation.id,
                name: conversation.name,
                type: conversation.type.rawValue,
                lastActivity: conversation.lastActivity,
                lastMessageText: conversation.lastMessage?.text,
                lastMessageAuthor: conversation.lastMessage?.authorName,
                unreadCount: conversation.unreadCount
            )
        }
        
        do {
            let data = try JSONEncoder().encode(cachedConversations)
            UserDefaults.standard.set(data, forKey: "CachedConversations")
            print("💾 Conversaciones guardadas en caché: \(cachedConversations.count)")
        } catch {
            print("❌ Error guardando conversaciones en caché: \(error)")
        }
    }
    
    private func refreshConversations() async {
        isRefreshing = true
        await loadConversations()
        isRefreshing = false
    }
    
    private func setupMessageUpdateListener() {
        // Escuchar actualizaciones de mensajes
        messageUpdateObserver = NotificationCenter.default.addObserver(
            forName: .chatMessageUpdate,
            object: nil,
            queue: .main
        ) { [self] notification in
            guard let update = notification.userInfo?["update"] as? MessageUpdate else { return }
            
            print("🔔 Message update recibido - tipo: \\(update.type), conversación: \\(update.conversationId)")
            
            // Solo mover al top si es un mensaje realmente NUEVO y no es del usuario actual viendo el chat
            if update.type == .new && !isCurrentlyViewingConversation(update.conversationId) {
                print("📈 Moviendo conversación al top por mensaje nuevo de otro usuario")
                moveConversationToTop(conversationId: update.conversationId)
            } else if update.type == .new {
                print("📱 Mensaje nuevo pero el usuario está viendo esa conversación, no mover")
            }
        }
    }
    
    /// Verifica si el usuario está actualmente viendo una conversación específica
    private func isCurrentlyViewingConversation(_ conversationId: String) -> Bool {
        return showingChat && selectedConversation?.id == conversationId
    }
    
    private func moveConversationToTop(conversationId: String) {
        // Buscar la conversación
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        // Si ya está en la primera posición, no hacer nada
        if index == 0 { return }
        
        print("📈 Moviendo conversación \\(conversationId) al top por nuevo mensaje")
        
        // Mover la conversación al principio
        var updatedConversations = conversations
        let conversation = updatedConversations.remove(at: index)
        
        // Actualizar la fecha de última actividad SOLO si realmente hay un nuevo mensaje
        let updatedConversation = ChatConversation(
            id: conversation.id,
            name: conversation.name,
            type: conversation.type,
            members: conversation.members,
            lastMessage: conversation.lastMessage,
            lastActivity: Date(), // Actualizar a la fecha actual por el nuevo mensaje
            unreadCount: conversation.unreadCount,
            metadata: conversation.metadata
        )
        
        updatedConversations.insert(updatedConversation, at: 0)
        conversations = updatedConversations
        
        // Actualizar caché
        saveConversationsToCache(conversations)
    }
    
    private func refreshConversationsOrder() async {
        // Solo reordenar las conversaciones existentes por fecha
        await MainActor.run {
            conversations = conversations.sorted { $0.lastActivity > $1.lastActivity }
        }
    }
}

// MARK: - Enhanced Conversation Row
struct ConversationRow: View {
    let conversation: ChatConversation
    let themeManager: ThemeManager
    @State private var isPressed = false
    
    private var avatarColors: [Color] {
        let colors = [
            Color.dynamicAccent(theme: themeManager.currentTheme),
            Color.blue,
            Color.green,
            Color.orange,
            Color.purple,
            Color.pink,
            Color.cyan
        ]
        
        // Use conversation ID to consistently pick a color
        let index = abs(conversation.id.hashValue) % colors.count
        return [colors[index], colors[(index + 1) % colors.count]]
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced Avatar
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: avatarColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                
                // Initial or icon
                if let name = conversation.name, !name.isEmpty {
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: conversationIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Online indicator (if needed)
                if conversation.type == .direct {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.dynamicBackground(theme: themeManager.currentTheme), lineWidth: 2)
                        )
                        .offset(x: 20, y: 20)
                }
            }
            .shadow(
                color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                radius: 4,
                x: 0,
                y: 2
            )
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Top row: Name and time
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.name ?? "Chat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(1)
                        
                        // Conversation type indicator
                        if conversation.type != .direct {
                            HStack(spacing: 4) {
                                Image(systemName: conversationTypeIcon)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text(conversationTypeText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDate(conversation.lastActivity))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        // Unread count badge
                        if conversation.unreadCount > 0 {
                            Text("\(min(conversation.unreadCount, 99))\(conversation.unreadCount > 99 ? "+" : "")")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .clipShape(Capsule())
                                .scaleEffect(conversation.unreadCount > 0 ? 1.0 : 0.8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: conversation.unreadCount)
                        }
                    }
                }
                
                // Bottom row: Last message preview
                if let lastMessage = conversation.lastMessage {
                    HStack(spacing: 8) {
                        // Message preview with author info
                        HStack(spacing: 4) {
                            if !lastMessage.isFromCurrentUser && conversation.type != .direct {
                                Text("\(lastMessage.authorName):")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .lineLimit(1)
                            }
                            
                            Text(lastMessage.text)
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Message status for own messages
                        if lastMessage.isFromCurrentUser {
                            messageStatusIcon(for: lastMessage.syncStatus)
                        }
                    }
                } else {
                    Text("Sin mensajes")
                        .font(.system(size: 14))
                        .italic()
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .opacity(isPressed ? 0.5 : 0.001)
        )
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    // MARK: - Computed Properties
    private var conversationIcon: String {
        switch conversation.type {
        case .direct:
            return "person.circle"
        case .group:
            return "person.3"
        case .general:
            return "bubble.left.and.bubble.right"
        case .channel:
            return "calendar.circle"
        }
    }
    
    private var conversationTypeIcon: String {
        switch conversation.type {
        case .group:
            return "person.3.fill"
        case .channel:
            return "calendar"
        default:
            return "bubble.left"
        }
    }
    
    private var conversationTypeText: String {
        switch conversation.type {
        case .group:
            return "Grupo"
        case .channel:
            return "Canal"
        default:
            return ""
        }
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
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            formatter.setLocalizedDateFormatFromTemplate("E")
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    @ViewBuilder
    private func messageStatusIcon(for status: MessageSyncStatus?) -> some View {
        if let status = status {
            switch status {
            case .pending, .sending:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicTextSecondary(theme: themeManager.currentTheme)))
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            case .synced:
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green.opacity(0.8))
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Extension for Chat Credentials
extension UnifiedMessagesView {
    private func obtenerCredencialesReales(user: AuthUser) async {
        print("🔑 Obteniendo credenciales reales para el chat...")
        print("👤 Usuario: \(user.id) - \(user.name)")
        
        do {
            // Usar ChatService para obtener el token real
            let chatService = ChatService.shared
            chatService.authService = authService
            
            guard let tokenResponse = await chatService.getStreamToken() else {
                print("❌ No se pudo obtener token de GetStream")
                await MainActor.run {
                    errorMessage = "No se pudo obtener el token de chat"
                }
                return
            }
            
            print("✅ Token real obtenido para UnifiedMessagesView")
            print("   - Token: \(tokenResponse.token.prefix(20))...")
            print("   - API Key: \(tokenResponse.apiKey)")
            print("   - Internal User ID: \(tokenResponse.internalUserId)")
            
            // IMPORTANTE: El userId debe coincidir con el user_id del token JWT
            let userId = "user_\(tokenResponse.internalUserId)"
            
            let credentials = ChatCredentials(
                token: tokenResponse.token,
                apiKey: tokenResponse.apiKey,
                userId: userId,
                userInfo: ChatUser(
                    id: userId,
                    name: user.name,
                    avatarURL: user.picture
                )
            )
            
            print("🔌 Conectando a GetStream con credenciales reales...")
            try await chatProviderManager.connect(credentials: credentials)
            print("✅ Conectado exitosamente al chat")
            
            // Cargar conversaciones después de conectar
            await loadConversations()
            
        } catch {
            await MainActor.run {
                errorMessage = "Error obteniendo credenciales: \(error.localizedDescription)"
            }
            print("❌ Error obteniendo credenciales reales: \(error)")
        }
    }
    
    // MARK: - Swipe Actions
    private func muteConversation(_ conversation: ChatConversation) {
        print("🔇 Silenciando conversación: \(conversation.name ?? conversation.id)")
        
        // TODO: Implement actual mute functionality
        // For now, just show a success message
        
        // Update UI to show muted state
        // This would typically involve updating the conversation's metadata
        // and potentially storing the muted state locally or on the server
        
        // Show temporary feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // You could show a toast or banner here
        print("✅ Conversation muted successfully")
    }
    
    private func archiveConversation(_ conversation: ChatConversation) {
        print("📦 Archivando conversación: \(conversation.name ?? conversation.id)")
        
        // Remove from current list with animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            conversations.removeAll { $0.id == conversation.id }
        }
        
        // TODO: Implement actual archive functionality
        // This would typically involve:
        // 1. Marking the conversation as archived on the server
        // 2. Moving it to an archived conversations list
        // 3. Updating local storage
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("✅ Conversation archived successfully")
    }
    
    private func deleteConversation(_ conversation: ChatConversation) {
        print("🗑️ Eliminando conversación: \(conversation.name ?? conversation.id)")
        
        // Remove from current list with animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            conversations.removeAll { $0.id == conversation.id }
        }
        
        // TODO: Implement actual delete functionality with backend API
        // For now, just remove from local list and update cache
        saveConversationsToCache(conversations)
        print("✅ Conversation deleted locally (backend integration pending)")
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}