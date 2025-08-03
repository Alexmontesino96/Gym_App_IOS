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
        NavigationView {
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
            .background(
                NavigationLink(
                    destination: chatDestination,
                    isActive: $showingChat,
                    label: { EmptyView() }
                )
            )
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
                    Button(action: { showingSearch.toggle() }) {
                        Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    
                    // New message button
                    Button(action: { showingUserSelector = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
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
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Reintentar") {
                        Task { await loadConversations() }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
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
            if filteredConversations.isEmpty {
                emptyStateView
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
                    ConversationRow(
                        conversation: conversation,
                        themeManager: themeManager
                    )
                    .onTapGesture {
                        selectedConversation = conversation
                        showingChat = true
                    }
                    .onChange(of: showingChat) { isShowing in
                        if !isShowing {
                            // Cuando volvemos del chat, reordenar si es necesario
                            Task {
                                await refreshConversationsOrder()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            VStack(spacing: 8) {
                Text("No hay conversaciones")
                    .font(.headline)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Inicia una nueva conversación tocando el botón de arriba")
                    .font(.subheadline)
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingUserSelector = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Nueva conversación")
                }
                .padding()
                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Chat Destination
    @ViewBuilder
    private var chatDestination: some View {
        if let conversation = selectedConversation {
            OptimizedChatView(
                conversationId: conversation.id,
                conversationName: conversation.name ?? "Chat"
            )
            .environmentObject(themeManager)
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
        
        // Cargar primero desde caché de forma síncrona
        loadConversationsFromCache()
        
        // Luego inicializar el sistema de chat y cargar desde GetStream
        Task {
            isUpdatingFromServer = true
            await initializeChatSystem()
            await loadConversations()
            isUpdatingFromServer = false
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
            
            // Cuando se envía un nuevo mensaje, actualizar el orden de las conversaciones
            if update.type == .new {
                moveConversationToTop(conversationId: update.conversationId)
            }
        }
    }
    
    private func moveConversationToTop(conversationId: String) {
        // Buscar la conversación
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        // Si ya está en la primera posición, no hacer nada
        if index == 0 { return }
        
        // Mover la conversación al principio
        var updatedConversations = conversations
        let conversation = updatedConversations.remove(at: index)
        
        // Actualizar la fecha de última actividad
        let updatedConversation = ChatConversation(
            id: conversation.id,
            name: conversation.name,
            type: conversation.type,
            members: conversation.members,
            lastMessage: conversation.lastMessage,
            lastActivity: Date(), // Actualizar a la fecha actual
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

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: ChatConversation
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(conversation.name?.prefix(1).uppercased() ?? "?")
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name ?? "Chat")
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Text(formatDate(conversation.lastActivity))
                        .font(.caption)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                if let lastMessage = conversation.lastMessage {
                    HStack {
                        Text(lastMessage.text)
                            .font(.subheadline)
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .contentShape(Rectangle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if Calendar.current.isDateInYesterday(date) {
            return "Ayer"
        } else {
            formatter.dateStyle = .short
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Extension for Chat Credentials
extension UnifiedMessagesView {
    private func obtenerCredencialesReales(user: User) async {
        print("🔑 Obteniendo credenciales reales para el chat...")
        print("👤 Usuario: \(user.id) - \(user.name ?? "Sin nombre")")
        
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
                    name: user.name ?? "Usuario",
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
}