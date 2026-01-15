//
//  FeedTabsView.swift
//  Gym_API
//
//  Created by Claude Code
//  Minimal Instagram-style social feed with stories
//  NOTA: La versión anterior está guardada en FeedTabsView_Old.swift
//

import SwiftUI

// MARK: - Cached Conversation Model
struct CachedConversation: Codable {
    let id: String
    let name: String?
    let type: String
    let lastActivity: Date
    let lastMessageText: String?
    let lastMessageAuthor: String?
    let lastMessageTimestamp: Date?  // ✅ NUEVO: Timestamp del último mensaje
    let lastMessageId: String?       // ✅ NUEVO: ID del último mensaje
    let unreadCount: Int
    let members: [CachedChatUser]    // ✅ NUEVO: Array de miembros con avatares
}

// MARK: - Cached Chat User Model
struct CachedChatUser: Codable {
    let id: String
    let name: String
    let avatarURL: String?
}

/// Vista principal del feed social rediseñada - Minimalista estilo Instagram
struct FeedTabsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var storyService = StoryService()  // Story service for feed
    @StateObject private var storyUIState = StoryUIState()
    @StateObject private var profileService = UserProfileService.shared

    @State private var showCreatePost = false
    @State private var showMessagesPage = false
    @State private var selectedStoryGroup: UserStoryGroup?  // For story viewer navigation
    @State private var showStoryCreator = false  // For story creation

    // MARK: - Chat State Variables
    @StateObject private var chatProviderManager = ChatProviderManager.shared
    @State private var conversations: [ChatConversation] = []
    @State private var selectedConversation: ChatConversation?
    @State private var showingChat = false
    @State private var showingUserSelector = false
    @State private var showingSearch = false
    @State private var isLoadingConversations = false
    @State private var searchText = ""
    @State private var hasInitialized = false
    @State private var errorMessage: String?
    @State private var isLoadingFromCache = false
    @State private var isUpdatingFromServer = false
    @State private var messageUpdateObserver: NSObjectProtocol?
    @State private var saveCacheDebounceWorkItem: DispatchWorkItem?
    @State private var emptyStateAnimationScale: CGFloat = 1.0
    @State private var emptyStateButtonPressed = false

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

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Navigation Bar
                    customNavigationBar

                    // Feed Content (solo Timeline, sin tabs)
                    TimelineFeedContent()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                initializeIfNeeded()
                setupMessageUpdateListener()

                // Setup story service
                storyService.authService = authService
                print("📲 DEBUG: StoryService authService configured")

                // Load stories feed
                Task {
                    print("📲 DEBUG: Fetching stories feed...")
                    await storyService.fetchStoriesFeed()
                    print("📲 DEBUG: Stories feed loaded - Count: \(storyService.feedStories.count)")

                    if !storyService.feedStories.isEmpty {
                        print("📲 DEBUG: First story user: \(storyService.feedStories[0].userName)")
                        print("📲 DEBUG: First story count: \(storyService.feedStories[0].stories.count)")
                    } else {
                        print("⚠️ DEBUG: No stories in feed!")
                    }
                }
            }
            .onDisappear {
                if let observer = messageUpdateObserver {
                    NotificationCenter.default.removeObserver(observer)
                    messageUpdateObserver = nil
                }
                if conversations.count > 30 {
                    conversations = Array(conversations.prefix(30))
                }
            }
            .navigationDestination(isPresented: $showMessagesPage) {
                messagesPageView
            }
        }
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(themeManager)
                .environmentObject(postService)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingUserSelector) {
            userSelectorSheet
        }
        .fullScreenCover(item: $selectedStoryGroup) { userGroup in
            let _ = print("🎭 DEBUG: fullScreenCover triggered for user: \(userGroup.userName)")
            let _ = print("🎭 DEBUG: Stories count: \(userGroup.stories.count)")
            let _ = print("🎭 DEBUG: All stories owners count: \(storyService.feedStories.count)")

            let initialIndex = storyService.feedStories.firstIndex { $0.userId == userGroup.userId } ?? 0

            StoryViewerContainer(
                userStories: storyService.feedStories,
                initialUserIndex: initialIndex
            )
            .environmentObject(storyService)
            .environmentObject(themeManager)
            .environmentObject(authService)
            .environmentObject(storyUIState)
        }
        .fullScreenCover(isPresented: $showStoryCreator) {
            StoryCreatorView()
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
                .onAppear {
                    print("DEBUG:🎬 StoryCreatorView appeared from FeedTabs")
                }
        }
    }

    // MARK: - Custom Navigation Bar

    private var customNavigationBar: some View {
        HStack(spacing: 20) {
            // Logo/Title
            Text("Social")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()

            // Action Button - Create Post
            Button(action: {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                showCreatePost = true
            }) {
                Image(systemName: "plus.square")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            // Action Button - Messages (Instagram style)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showMessagesPage = true
                }
            }) {
                Image(systemName: "paperplane")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }

    // MARK: - Messages Page View (Full page navigation)
    private var messagesPageView: some View {
        ZStack {
            Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar in messages page
                if showingSearch {
                    searchBarView
                }

                // Messages content
                messagesContent
            }
        }
        .navigationTitle("Mensajes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showingSearch.toggle()
                        }
                    }) {
                        Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }

                    Button(action: {
                        showingUserSelector = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingChat) {
            chatDestination
        }
    }

    // MARK: - Search Bar View
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Buscar", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.12))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Messages Content
    private var messagesContent: some View {
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
        OptimizedList(
            items: filteredConversations,
            spacing: 1,
            showDividers: false,
            preloadThreshold: 5,
            onRefresh: refreshConversations
        ) { conversation in
            SwipeableConversationRow.withStandardActions(
                conversation: conversation,
                themeManager: themeManager,
                currentUserId: (chatProviderManager.currentProvider as? GetStreamChatProvider)?.currentUserId ?? authService.user?.id,
                onTap: {
                    print("🔘 Tap detectado en conversación: \(conversation.name ?? conversation.id)")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedConversation = conversation
                        showingChat = true
                    }
                    // Marcar localmente como leído para refrescar el badge en la lista
                    if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
                        let c = conversations[idx]
                        let updated = ChatConversation(
                            id: c.id,
                            name: c.name,
                            type: c.type,
                            members: c.members,
                            lastMessage: c.lastMessage,
                            lastActivity: c.lastActivity,
                            unreadCount: 0,
                            metadata: c.metadata
                        )
                        conversations[idx] = updated
                        saveConversationsToCache(conversations)
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
                    let conversationName = selectedConversation?.name ?? "N/A"
                    print("🔙 Usuario salió del chat de: \(conversationName)")
                    print("📋 Manteniendo orden actual de conversaciones")
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

    // MARK: - Chat Destination
    @ViewBuilder
    private var chatDestination: some View {
        if let conversation = selectedConversation {
            OptimizedChatView(
                conversationId: conversation.id,
                conversationName: conversation.name ?? "Chat"
            )
            .id(conversation.id) // ✅ CRÍTICO: Fuerza recrear la vista cuando cambia conversationId
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
        CoachSelectorView(
            isPresented: $showingUserSelector,
            onCoachSelected: { selectedCoach in
                print("🏃‍♂️ Coach seleccionado: \(selectedCoach.fullName)")
                print("✨ LAZY CREATION: Creando conversación temporal SIN llamar al backend")

                // ✅ PATRÓN CORRECTO: Crear conversación TEMPORAL sin llamar al backend
                // El canal real se creará cuando el usuario envíe el primer mensaje

                var provisionalMembers: [ChatUser] = []
                let coachUser = ChatUser(
                    id: "user_\(selectedCoach.id)",
                    name: selectedCoach.fullName,
                    avatarURL: selectedCoach.picture
                )
                provisionalMembers.append(coachUser)

                if let providerUserId = (chatProviderManager.currentProvider as? GetStreamChatProvider)?.currentUserId {
                    provisionalMembers.append(ChatUser(
                        id: providerUserId,
                        name: authService.user?.name ?? "Me",
                        avatarURL: authService.user?.picture
                    ))
                }

                // ID temporal que indica que el canal NO ha sido creado aún
                let temporalId = "temp_direct_\(selectedCoach.id)"

                let provisionalConversation = ChatConversation(
                    id: temporalId,
                    name: selectedCoach.fullName,
                    type: .direct,
                    members: provisionalMembers,
                    lastMessage: nil,
                    lastActivity: Date(),
                    unreadCount: 0,
                    metadata: [
                        "coach_id": selectedCoach.id,
                        "coach_name": selectedCoach.fullName,
                        "is_temporary": true,  // ✅ Marca como temporal
                        "needs_creation": true  // ✅ Indica que necesita crearse al enviar mensaje
                    ]
                )

                // Navegar inmediatamente sin crear el canal
                selectedConversation = provisionalConversation
                showingChat = true

                print("✅ Navegando a chat temporal con \(selectedCoach.fullName)")
                print("💡 Canal se creará cuando se envíe el primer mensaje")
            }
        )
        .environmentObject(themeManager)
        .environmentObject(authService)
    }

    // MARK: - Methods

    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        // 1. Mostrar skeleton si no hay datos en caché
        if conversations.isEmpty {
            isLoadingFromCache = true
        }

        // 2. Cargar desde caché INMEDIATAMENTE
        loadConversationsFromCache()

        // 3. Inicializar en background CON ORDEN CORRECTO
        Task {
            isUpdatingFromServer = true

            // ✅ PASO 1: Asegurar que ChatProvider esté listo
            await ensureChatProviderReady()

            // ✅ PASO 2: Inicializar sistema de chat
            await initializeChatSystem()

            // Conversaciones y miembros se cargan dentro de initializeChatSystem()
            // para asegurar que haya auth y conexión listas

            isUpdatingFromServer = false
            isLoadingFromCache = false
        }
    }

    // ✅ NUEVO: Asegurar que ChatProvider esté listo antes de continuar
    private func ensureChatProviderReady() async {
        let maxRetries = 10
        var retries = 0

        while !chatProviderManager.isReady && retries < maxRetries {
            print("⏳ Esperando ChatProvider... intento \(retries + 1)/\(maxRetries)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            retries += 1
        }

        if chatProviderManager.isReady {
            print("✅ ChatProvider listo - Estado: \(chatProviderManager.state.displayText)")
        } else {
            print("⚠️ ChatProvider no se inicializó a tiempo - Estado: \(chatProviderManager.state.displayText)")
        }
    }

    // ✅ NUEVO: Precargar miembros del gym para enriquecer avatares
    private func preloadGymMembers() async {
        // Asegurar que ChatService tenga auth configurado antes de llamar a la API
        let chatService = ChatService.shared
        if chatService.authService == nil {
            chatService.authService = authService
            if let uid = authService.user?.id {
                chatService.setCurrentUserIdFromString(uid)
            }
        }
        await chatService.loadGymMembers()
        print("✅ Gym members precargados para avatares")
    }

    private func loadConversationsFromCache() {
        print("📦 Cargando conversaciones desde caché...")

        // Intentar cargar conversaciones desde caché
        if let data = UserDefaults.standard.data(forKey: "CachedConversations"),
           let cachedConversations = try? JSONDecoder().decode([CachedConversation].self, from: data) {

            print("✅ Conversaciones desde caché: \(cachedConversations.count)")

            // Convertir a ChatConversation con datos completos
            self.conversations = cachedConversations.map { cached in
                // ✅ Reconstruir members desde el caché
                let members = cached.members.map { cachedMember in
                    ChatUser(
                        id: cachedMember.id,
                        name: cachedMember.name,
                        avatarURL: cachedMember.avatarURL
                    )
                }

                // ✅ Reconstruir lastMessage si existe
                let lastMessage: ChatMessage?
                if let id = cached.lastMessageId, let text = cached.lastMessageText {
                    lastMessage = ChatMessage(
                        id: id,
                        conversationId: cached.id,
                        text: text,
                        authorId: "",  // No crítico para preview
                        authorName: cached.lastMessageAuthor ?? "Usuario",
                        timestamp: cached.lastMessageTimestamp ?? cached.lastActivity,
                        isFromCurrentUser: false,
                        attachments: []
                    )
                } else {
                    lastMessage = nil
                }

                return ChatConversation(
                    id: cached.id,
                    name: cached.name,
                    type: ChatConversation.ConversationType(rawValue: cached.type) ?? .general,
                    members: members,           // ✅ CON DATOS
                    lastMessage: lastMessage,   // ✅ CON DATOS
                    lastActivity: cached.lastActivity,
                    unreadCount: cached.unreadCount,
                    metadata: [:]
                )
            }.sorted { $0.lastActivity > $1.lastActivity }

            print("DEBUG: Cargadas \(conversations.count) conversaciones desde caché con members y lastMessage completos")
        } else {
            print("📦 No hay conversaciones en caché")
        }
    }

    private func initializeChatSystem() async {
        // Configurar ChatService SIEMPRE (incluso si ya está inicializado)
        if let user = authService.user {
            let chatService = ChatService.shared
            chatService.authService = authService
            chatService.setCurrentUserIdFromString(user.id)
            print("👤 FeedTabsView: ChatService configurado con userId: \(user.id)")

            // ✅ CRÍTICO: Cargar ChatRooms SIEMPRE, incluso si chatProvider ya está inicializado
            print("🔄 [DEBUG] Llamando a chatService.getMyRooms()...")
            await chatService.getMyRooms()
            print("✅ [DEBUG] getMyRooms() completado. ChatRooms count: \(chatService.chatRooms.count)")

            // Log de cada room para debugging
            for (index, room) in chatService.chatRooms.enumerated() {
                print("   [DEBUG] Room[\(index)]: id=\(room.id), streamId=\(room.streamChannelId), name=\(room.name ?? "sin nombre")")
            }
        }

        // Solo inicializar el provider si no está inicializado
        guard !chatProviderManager.isInitialized else {
            print("⚠️ ChatProvider ya inicializado, saltando inicialización pero ChatRooms ya cargados")
            return
        }

        // Pasar authService al inicializar el provider
        await chatProviderManager.initializeProvider(authService: authService)

        // Configurar credenciales y conversaciones solo en primera inicialización
        if let user = authService.user {
            // Obtener token real desde la API
            await obtenerCredencialesReales(user: user)

            // Precargar miembros del gym para enriquecer avatares en conversaciones
            await ChatService.shared.loadGymMembers()
        }
    }

    private func loadConversations() async {
        guard chatProviderManager.isInitialized else { return }
        // Prevent overlapping loads
        var shouldReturn = false
        await MainActor.run {
            if isLoadingConversations { shouldReturn = true } else { isLoadingConversations = true }
        }
        if shouldReturn { return }

        do {
            let loadedConversations = try await chatProviderManager.getConversations()

            await MainActor.run {
                self.conversations = loadedConversations.sorted { conversation1, conversation2 in
                    conversation1.lastActivity > conversation2.lastActivity
                }
                self.errorMessage = nil

                // Precargar imágenes de avatar para mejorar performance
                self.preloadAvatarImages(for: loadedConversations)

                // Guardar en caché para próxima vez
                self.saveConversationsToCache(loadedConversations)
                self.isLoadingConversations = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error cargando conversaciones: \(error.localizedDescription)"
                self.isLoadingConversations = false
            }
            print("❌ Error cargando conversaciones: \(error)")
        }
    }

    private func preloadAvatarImages(for conversations: [ChatConversation]) {
        var imagesToPreload: [(url: String, cacheKey: String?)] = []
        let currentUserId = authService.user?.id ?? ""

        for conversation in conversations {
            if conversation.type == .direct {
                // Obtener el otro usuario de los miembros
                let otherUser = conversation.members.first { $0.id != currentUserId }

                if let otherUser = otherUser {
                    if let avatarURL = otherUser.avatarURL, !avatarURL.isEmpty {
                        // Avatar real del usuario - ✅ FIX: Usar userAvatarCacheKey()
                        imagesToPreload.append((url: avatarURL, cacheKey: otherUser.id.userAvatarCacheKey()))
                    } else {
                        // Avatar generado con UI Avatars
                        let encodedName = otherUser.name.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) ?? "User"
                        let numericId = otherUser.id.extractNumericUserId()
                        let colorHash = abs(numericId.hashValue) % 16777215
                        let backgroundColor = String(format: "%06X", colorHash)
                        let avatarServiceURL = "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=\(backgroundColor)&color=fff&format=png"
                        // ✅ FIX: Usar uiAvatarCacheKey()
                        imagesToPreload.append((url: avatarServiceURL, cacheKey: otherUser.id.uiAvatarCacheKey()))
                    }
                }
            }
        }

        // Precargar en background
        if !imagesToPreload.isEmpty {
            DispatchQueue.global(qos: .background).async {
                ImageLoaderService.preloadImages(urls: imagesToPreload)
            }
        }
    }

    private func saveConversationsToCache(_ conversations: [ChatConversation]) {
        // Debounce guardado para evitar escrituras frecuentes
        saveCacheDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [conversations] in
            let cachedConversations = conversations.map { conversation in
                CachedConversation(
                    id: conversation.id,
                    name: conversation.name,
                    type: conversation.type.rawValue,
                    lastActivity: conversation.lastActivity,
                    lastMessageText: conversation.lastMessage?.text,
                    lastMessageAuthor: conversation.lastMessage?.authorName,
                    lastMessageTimestamp: conversation.lastMessage?.timestamp,  // ✅ NUEVO
                    lastMessageId: conversation.lastMessage?.id,                // ✅ NUEVO
                    unreadCount: conversation.unreadCount,
                    members: conversation.members.map { member in               // ✅ NUEVO: Serializar members
                        CachedChatUser(
                            id: member.id,
                            name: member.name,
                            avatarURL: member.avatarURL
                        )
                    }
                )
            }
            do {
                let data = try JSONEncoder().encode(cachedConversations)
                UserDefaults.standard.set(data, forKey: "CachedConversations")
                print("💾 Conversaciones guardadas en caché: \(cachedConversations.count) con members completos")
            } catch {
                print("❌ Error guardando conversaciones en caché: \(error)")
            }
        }
        saveCacheDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func refreshConversations() async {
        // Do not refresh if a server update is already in progress
        if isLoadingConversations { return }
        await loadConversations()
    }

    private func setupMessageUpdateListener() {
        // Escuchar actualizaciones de mensajes
        messageUpdateObserver = NotificationCenter.default.addObserver(
            forName: .chatMessageUpdate,
            object: nil,
            queue: .main
        ) { [self] notification in
            guard let update = notification.userInfo?["update"] as? MessageUpdate else { return }

            print("🔔 Message update recibido - tipo: \(update.type), conversación: \(update.conversationId)")

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

        print("📈 Moviendo conversación \(conversationId) al top por nuevo mensaje")

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

    private func obtenerCredencialesReales(user: AuthUser) async {
        print("🔑 Obteniendo credenciales reales para el chat...")
        print("👤 Usuario: \(user.id) - \(user.name)")

        do {
            // Usar ChatService para obtener el token real
            let chatService = ChatService.shared
            chatService.authService = authService
            chatService.setCurrentUserIdFromString(user.id)

            guard let tokenResponse = await chatService.getStreamToken() else {
                print("❌ No se pudo obtener token de GetStream")
                await MainActor.run {
                    errorMessage = "No se pudo obtener el token de chat"
                }
                return
            }

            print("✅ Token real obtenido para FeedTabsView")
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
            // Configurar currentUserId interno con el valor del backend para evitar logs con subject Auth0
            ChatService.shared.setCurrentUserId(tokenResponse.internalUserId)

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
        print("🔍 Buscando ChatRoom con streamChannelId: \(conversation.id)")
        print("📋 Total de ChatRooms cargados: \(ChatService.shared.chatRooms.count)")

        // Log todos los streamChannelIds disponibles
        for (index, room) in ChatService.shared.chatRooms.enumerated() {
            print("   [\(index)] roomId: \(room.id), streamChannelId: \(room.streamChannelId)")
        }

        // Buscar ChatRoom correspondiente usando streamChannelId
        if let chatRoom = ChatService.shared.chatRooms.first(where: { $0.streamChannelId == conversation.id }) {
            print("✅ ChatRoom encontrado! roomId: \(chatRoom.id), streamChannelId: \(chatRoom.streamChannelId)")
            // ✅ Tenemos el roomId, eliminar del backend
            Task {
                do {
                    let response = try await ServiceContainer.shared.chatManagementService.deleteConversation(room: chatRoom)
                    print("✅ Conversación eliminada del backend: \(response.messagesDeleted) mensajes borrados")

                    // Remove from UI with animation
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            conversations.removeAll { $0.id == conversation.id }
                        }
                        saveConversationsToCache(conversations)

                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    }
                } catch {
                    print("❌ Error al eliminar conversación del backend: \(error.localizedDescription)")

                    // Aún así eliminar localmente
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            conversations.removeAll { $0.id == conversation.id }
                        }
                        saveConversationsToCache(conversations)

                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        } else {
            // ⚠️ No encontramos el ChatRoom en la lista cargada
            print("❌ ChatRoom NO encontrado en lista local para streamChannelId: '\(conversation.id)'")
            print("🔍 Buscando en backend con include_hidden=true...")

            // Buscar en el backend incluyendo chats ocultos
            Task {
                if let hiddenChatRoom = await ChatService.shared.findChatRoom(byStreamChannelId: conversation.id) {
                    // ✅ Encontrado! Puede estar oculto
                    print("✅ ChatRoom encontrado en backend (isHidden=\(hiddenChatRoom.isHidden))")

                    do {
                        let response = try await ServiceContainer.shared.chatManagementService.deleteConversation(room: hiddenChatRoom)
                        print("✅ Conversación eliminada del backend: \(response.messagesDeleted) mensajes borrados")

                        // Eliminar de la UI local
                        await MainActor.run {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                conversations.removeAll { $0.id == conversation.id }
                            }
                            saveConversationsToCache(conversations)

                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                        }

                    } catch {
                        print("❌ Error al eliminar conversación: \(error.localizedDescription)")

                        // Aún así eliminar localmente
                        await MainActor.run {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                conversations.removeAll { $0.id == conversation.id }
                            }
                            saveConversationsToCache(conversations)

                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                        }
                    }

                } else {
                    // ❌ No existe ni siquiera con include_hidden=true → es huérfano
                    print("❌ ChatRoom NO existe en backend (verificado con include_hidden=true)")
                    print("🔒 Eliminando canal huérfano usando endpoint seguro del backend...")

                    do {
                        // Usar el endpoint seguro que valida gym_id, permisos, etc.
                        let response = try await ServiceContainer.shared.chatManagementService.deleteOrphanChannel(channelId: conversation.id)
                        print("✅ Canal huérfano eliminado correctamente: \(response.message)")

                        // Eliminar de la UI local
                        await MainActor.run {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                conversations.removeAll { $0.id == conversation.id }
                            }
                            saveConversationsToCache(conversations)

                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                        }

                    } catch ChatManagementError.noPermission, ChatManagementError.notAMember {
                        // El usuario no es el creador del canal huérfano o no es miembro
                        print("⚠️ No puedes eliminar este canal huérfano (no eres el creador)")
                        print("ℹ️ El canal será eliminado solo de tu vista local")
                        print("ℹ️ Nota: Solo el creador del canal puede eliminarlo permanentemente del servidor")

                        // Eliminar solo de la UI local
                        await MainActor.run {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                conversations.removeAll { $0.id == conversation.id }
                            }
                            saveConversationsToCache(conversations)

                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                        }

                    } catch {
                        print("⚠️ Error eliminando canal: \(error.localizedDescription)")
                        print("ℹ️ Eliminando solo de la vista local")

                        // Aún así eliminar localmente para limpiar la UI
                        await MainActor.run {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                conversations.removeAll { $0.id == conversation.id }
                            }
                            saveConversationsToCache(conversations)

                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
            }

            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }

}

// MARK: - Timeline Feed Content

struct TimelineFeedContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var profileService: UserProfileService
    @StateObject private var viewModel = SocialFeedViewModel(feedType: .timeline)

    var body: some View {
        MinimalFeedContent(viewModel: viewModel, feedType: .timeline)
            .environmentObject(themeManager)
            .environmentObject(storyService)
            .environmentObject(authService)
            .environmentObject(profileService)
            .task {
                if viewModel.posts.isEmpty {
                    await viewModel.loadInitial()
                }
            }
    }
}

// MARK: - Minimal Feed Content

struct MinimalFeedContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var profileService: UserProfileService
    @ObservedObject var viewModel: SocialFeedViewModel
    let feedType: SocialEmptyStateView.FeedType
    @State private var showCreatePost = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                loadingView
            } else if viewModel.shouldShowEmptyState {
                SocialEmptyStateView(
                    feedType: feedType,
                    theme: themeManager.currentTheme,
                    onCreatePost: { showCreatePost = true }
                )
            } else if viewModel.shouldShowError {
                errorView
            } else {
                postsScrollView
            }
        }
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(themeManager)
        }
    }

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    PostCardSkeleton()
                        .environmentObject(themeManager)
                }
            }
        }
    }

    private var postsScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Stories Bar con fade al hacer scroll
                InstagramStoriesBar()
                    .frame(height: 110)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .environmentObject(storyService)
                    .environmentObject(authService)
                    .environmentObject(themeManager)
                    .environmentObject(profileService)
                    .opacity(storiesOpacity)
                    .animation(.easeOut(duration: 0.2), value: storiesOpacity)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geometry.frame(in: .named("scroll")).minY
                                )
                        }
                    )
                    .onAppear {
                        print("📊 DEBUG: InstagramStoriesBar apareció en feed")
                        print("📊 DEBUG: Feed stories count: \(storyService.feedStories.count)")
                        print("📊 DEBUG: Stories opacity: \(storiesOpacity)")
                    }

                ForEach(viewModel.posts) { post in
                    PostCard(post: post)
                        .onAppear {
                            if post.id == viewModel.posts.last?.id {
                                loadMoreIfNeeded()
                            }
                        }
                }

                // Loading More Indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .padding(.vertical, 20)
                        Spacer()
                    }
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // Calcula la opacidad basada en el scroll offset
    private var storiesOpacity: Double {
        let fadeStart: CGFloat = 0
        let fadeEnd: CGFloat = 100

        if scrollOffset >= fadeStart {
            return 1.0
        } else if scrollOffset <= fadeEnd {
            return 0.0
        } else {
            return Double((scrollOffset - fadeEnd) / (fadeStart - fadeEnd))
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(Color.errorRed)

            Text("Error al cargar posts")
                .font(Typography.titleMedium)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.bodyMedium)
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Text("Reintentar")
                    .font(Typography.button)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .cornerRadius(VisualEffects.cornerRadiusSmall)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func loadMoreIfNeeded() {
        guard !viewModel.isLoadingMore, viewModel.hasMore else { return }

        Task {
            await viewModel.loadMore()
        }
    }
}

// MARK: - Post Card Skeleton

struct PostCardSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 10)
                }

                Spacer()
            }

            // Image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 300)

            // Caption lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 10)
            }

            // Actions
            HStack(spacing: 20) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(16)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        FeedTabsView()
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
            .environmentObject(AuthServiceDirect())
    }
}
