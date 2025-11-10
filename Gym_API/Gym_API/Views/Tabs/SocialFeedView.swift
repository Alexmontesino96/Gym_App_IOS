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

// MARK: - Social Feed View
/// Vista de página social del gym con tabs Feed/Mensajes
struct SocialFeedView: View {

    // MARK: - Environment Objects
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect

    // MARK: - State Objects
    @StateObject private var chatProviderManager = ChatProviderManager.shared
    @StateObject private var eventService = ServiceContainer.shared.eventService
    @StateObject private var activityService = ServiceContainer.shared.activityService
    @StateObject private var postService = ServiceContainer.shared.postService

    // MARK: - State Variables
    @State private var conversations: [ChatConversation] = []
    @State private var selectedConversation: ChatConversation?
    @State private var showingChat = false
    @State private var showingUserSelector = false
    @State private var showingMessagesSheet = false
    @State private var showingSearch = false
    @State private var isRefreshing = false
    @State private var isLoadingConversations = false
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
                    // Instagram-style header with stories
                    socialHeader

                    // Status indicators below header when needed
                    if !chatProviderManager.isInitialized || isUpdatingFromServer {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text(isUpdatingFromServer ? "Actualizando..." : "Conectando...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
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

                    // Social Feed Content (Instagram-style)
                    socialFeedContent
                }
            }
            .safeAreaPadding(.top, 16)
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
            .sheet(isPresented: $showingMessagesSheet) {
                messagesSheetView
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
        .animation(.easeInOut, value: showingMessagesSheet)
    }

    // MARK: - Instagram-Style Social Header
    private var socialHeader: some View {
        VStack(spacing: 8) {
            // Instagram-style minimal header
            HStack {
                Text("Social")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                // Instagram-style chat icon (paperplane)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showingMessagesSheet = true
                    }
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)

            // Stories bar directly below title
            InstagramStoriesBar()
                .environmentObject(ServiceContainer.shared.storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(ServiceContainer.shared.profileService)
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .overlay(
            Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 0.5)
            ,alignment: .bottom
        )
    }

    // MARK: - Messages Sheet View
    private var messagesSheetView: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar in messages sheet
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        showingMessagesSheet = false
                    }
                }

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

    // MARK: - Social Feed Content
    private var socialFeedContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Events Carousel Section
                EventsCarouselSection()
                    .environmentObject(themeManager)
                    .environmentObject(eventService)

                // Past Events Gallery Section
                PastEventsGallerySection()
                    .environmentObject(themeManager)
                    .environmentObject(eventService)

                // Posts Feed Section
                PostsFeedSection()
                    .environmentObject(themeManager)
                    .environmentObject(postService)

                // Achievements Section
                AchievementsSection(achievements: activityService.achievements, themeManager: themeManager)

                // Placeholder for other sections (will be implemented in next phases)
                placeholderSections
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Placeholder Sections
    private var placeholderSections: some View {
        VStack(spacing: 20) {
            Divider()
                .padding(.horizontal, 16)

            Text("Próximamente")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.2.badge.gearshape")
                    Text("Nuevos miembros")
                }
            }
            .font(.system(size: 14))
            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            .padding()
        }
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
                    print("🔙 Usuario salió del chat de: \\(selectedConversation?.name ?? \"N/A\")")
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
        CoachSelectorView(
            isPresented: $showingUserSelector,
            onCoachSelected: { selectedCoach in
                print("🏃‍♂️ Coach seleccionado: \(selectedCoach.fullName)")

                // Start loading state
                isUpdatingFromServer = true

                // Create direct chat with selected coach
                Task {
                    let chatService = ChatService.shared
                    chatService.authService = authService
                    if let user = authService.user {
                        chatService.setCurrentUserIdFromString(user.id)
                    }

                    if let directChatRoom = await chatService.getDirectChatWithCoach(selectedCoach) {
                            print("✅ Chat directo creado exitosamente con \(selectedCoach.fullName)")

                            // Convert ChatRoom to ChatConversation for navigation
                            // Pre-populate members with the coach and the current user (when available)
                            var provisionalMembers: [ChatUser] = []
                            let coachUser = ChatUser(
                                id: "user_\(selectedCoach.id)",
                                name: selectedCoach.fullName,
                                avatarURL: selectedCoach.picture
                            )
                            provisionalMembers.append(coachUser)
                            if let providerUserId = (chatProviderManager.currentProvider as? GetStreamChatProvider)?.currentUserId {
                                provisionalMembers.append(ChatUser(id: providerUserId, name: authService.user?.name ?? "Me", avatarURL: authService.user?.picture))
                            }

                            let conversation = ChatConversation(
                                id: directChatRoom.streamChannelId,
                                name: selectedCoach.fullName,
                                type: .direct,
                                members: provisionalMembers,
                                lastMessage: nil,
                                lastActivity: directChatRoom.effectiveDate,
                                unreadCount: 0,
                                metadata: [
                                    "coach_id": selectedCoach.id,
                                    "coach_name": selectedCoach.fullName,
                                    "room_id": directChatRoom.id
                                ]
                            )

                            await MainActor.run {
                                // Update conversations list if this is a new conversation
                                if !conversations.contains(where: { $0.id == conversation.id }) {
                                    conversations.insert(conversation, at: 0)
                                    saveConversationsToCache(conversations)
                                }

                                // Navigate to chat
                                selectedConversation = conversation
                                showingChat = true
                                isUpdatingFromServer = false

                                print("📱 Navegando a chat con coach: \(selectedCoach.fullName)")
                            }

                        } else {
                            await MainActor.run {
                                errorMessage = "No se pudo crear el chat con \(selectedCoach.fullName)"
                                isUpdatingFromServer = false
                            }
                            print("❌ No se pudo crear chat directo con \(selectedCoach.fullName)")
                    }
                }
            }
        )
        .environmentObject(themeManager)
        .environmentObject(authService)
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

        // Pasar authService al inicializar el provider
        await chatProviderManager.initializeProvider(authService: authService)

        // Configurar ChatService con el ID del usuario autenticado
        if let user = authService.user {
            let chatService = ChatService.shared
            chatService.authService = authService
            chatService.setCurrentUserIdFromString(user.id)
            print("👤 SocialFeedView: ChatService configurado con userId: \(user.id)")

            // Obtener token real desde la API
            await obtenerCredencialesReales(user: user)

            // Precargar miembros del gym para enriquecer avatares en conversaciones
            await chatService.loadGymMembers()
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
                        // Avatar real del usuario
                        let normalizedId = otherUser.id.replacingOccurrences(of: "user_", with: "")
                        imagesToPreload.append((url: avatarURL, cacheKey: "avatar_user_\(normalizedId)"))
                    } else {
                        // Avatar generado con UI Avatars
                        let encodedName = otherUser.name.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) ?? "User"
                        let normalizedId = otherUser.id.replacingOccurrences(of: "user_", with: "")
                        let colorHash = abs(normalizedId.hashValue) % 16777215
                        let backgroundColor = String(format: "%06X", colorHash)
                        let avatarServiceURL = "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=\(backgroundColor)&color=fff&format=png"
                        imagesToPreload.append((url: avatarServiceURL, cacheKey: "uiavatar_\(normalizedId)"))
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
        saveCacheDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    @State private var saveCacheDebounceWorkItem: DispatchWorkItem?

    private func refreshConversations() async {
        // Do not refresh if a server update is already in progress
        if isLoadingConversations { return }
        await MainActor.run { isRefreshing = true }
        await loadConversations()
        await MainActor.run { isRefreshing = false }
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
        // Reordenar priorizando conversaciones con historias no vistas, luego por actividad
        await MainActor.run {
            conversations = conversations.sorted { a, b in
                let aPriority = storyPriority(for: a)
                let bPriority = storyPriority(for: b)
                if aPriority != bPriority { return aPriority > bPriority }
                return a.lastActivity > b.lastActivity
            }
        }
    }

    private func storyPriority(for conversation: ChatConversation) -> Int {
        // Priorizar direct chats cuyo otro usuario tiene historias no vistas
        guard conversation.type == .direct else { return 0 }
        // Map other user id similar to ConversationAvatarView
        let other: ChatUser?
        if let currentUserId = (chatProviderManager.currentProvider as? GetStreamChatProvider)?.currentUserId ?? authService.user?.id {
            other = conversation.members.first { user in
                let normalizedMember = user.id.replacingOccurrences(of: "user_", with: "")
                let normalizedCurrent = currentUserId.replacingOccurrences(of: "user_", with: "")
                return normalizedMember != normalizedCurrent && user.id != currentUserId
            }
        } else {
            other = conversation.members.first
        }
        guard let otherUser = other else { return 0 }
        let normalizedId = otherUser.id.replacingOccurrences(of: "user_", with: "")
        guard let userIdInt = Int(normalizedId) else { return 0 }
        let unseen = ServiceContainer.shared.storyService.unseenCount(for: userIdInt)
        return unseen > 0 ? 1 : 0
    }
}

// MARK: - Enhanced Conversation Row
struct ConversationRow: View {
    let conversation: ChatConversation
    let themeManager: ThemeManager
    let currentUserId: String?
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
            // Enhanced Avatar with Profile Photos
            ConversationAvatarView(
                conversation: conversation,
                themeManager: themeManager,
                size: 56,
                currentUserId: currentUserId
            )
            .environmentObject(ServiceContainer.shared.storyService)
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

                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(formatDate(conversation.lastActivity))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                            // Unread dot (Instagram-like)
                            if conversation.unreadCount > 0 {
                                Circle()
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .frame(width: 8, height: 8)
                                    .transition(.scale)
                            }
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
        .padding(.vertical, 10)
        .frame(minHeight: 72)
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
extension SocialFeedView {
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

            print("✅ Token real obtenido para SocialFeedView")
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

// MARK: - Conversation Avatar View
struct ConversationAvatarView: View {
    let conversation: ChatConversation
    let themeManager: ThemeManager
    let size: CGFloat
    let currentUserId: String?
    @EnvironmentObject var storyService: StoryService

    @State private var refreshID = UUID()

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

    private var otherUser: ChatUser? {
        // For direct conversations, get the other user (not current user)
        if conversation.type == .direct {
            // Filter to get the other user
            if let currentUserId = currentUserId {
                return conversation.members.first { user in
                    !isCurrentUser(userId: user.id, currentUserId: currentUserId)
                }
            } else {
                // Fallback to first member if we don't have current user ID
                return conversation.members.first
            }
        }
        return nil
    }

    /// Determines if a given member userId refers to the current user, accounting for different ID formats.
    private func isCurrentUser(userId: String, currentUserId: String) -> Bool {
        // Common formats:
        // - Stream member id: "user_123"
        // - Current user id from provider: "user_123"
        // - Current user id from Auth0: "auth0|abc" (fallback path)
        if userId == currentUserId { return true }
        // Normalize: remove leading "user_" if present
        let normalizedMember = userId.replacingOccurrences(of: "user_", with: "")
        let normalizedCurrent = currentUserId.replacingOccurrences(of: "user_", with: "")
        if normalizedMember == normalizedCurrent { return true }
        // Also match if member equals "user_\(normalizedCurrent)"
        if userId == "user_\(normalizedCurrent)" { return true }
        return false
    }

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

    var body: some View {
        let (hasUnseen, unseenCount) = storyStateForDirectChat()
        ZStack {
            // Story ring (outer)
            if hasUnseen {
                Circle()
                    .strokeBorder(
                        StoryDesignTokens.instagramUnseenGradient,
                        lineWidth: StoryDesignTokens.ringWidth
                    )
                    .frame(width: size + 6, height: size + 6)
            } else {
                Circle()
                    .stroke(StoryDesignTokens.seenRingColor, lineWidth: 1)
                    .frame(width: size + 6, height: size + 6)
            }

            // Avatar content (inner)
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: avatarColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: size, height: size)
                .clipShape(Circle())

                // Profile photo or fallback
                Group {
                    if let user = otherUser, let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                        let normalizedId = user.id.replacingOccurrences(of: "user_", with: "")
                        CustomImageView(url: avatarURL, cacheKey: "avatar_user_\(normalizedId)", size: size) {
                            AnyView(fallbackContent)
                        }
                    } else if let user = otherUser {
                        let encodedName = user.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User"
                        let normalizedId = user.id.replacingOccurrences(of: "user_", with: "")
                        let colorHash = abs(normalizedId.hashValue) % 16777215
                        let backgroundColor = String(format: "%06X", colorHash)
                        let avatarServiceURL = "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=\(backgroundColor)&color=fff&format=png"
                        CustomImageView(url: avatarServiceURL, cacheKey: "uiavatar_\(normalizedId)", size: size) {
                            AnyView(fallbackContent)
                        }
                    } else {
                        fallbackContent
                    }
                }

                // Unseen badge for multiple stories
                if hasUnseen && unseenCount > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(unseenCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.red))
                        }
                        Spacer()
                    }
                    .frame(width: size, height: size)
                }
            }

            // Online indicator for direct chats
            if conversation.type == .direct {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .stroke(Color.dynamicBackground(theme: themeManager.currentTheme), lineWidth: 2)
                    )
                    .offset(x: size * 0.35, y: size * 0.35)
            }
        }
        .id(refreshID) // Force refresh when avatar updates
        .onReceive(NotificationCenter.default.publisher(for: .profileImageUpdated)) { notification in
            // Refresh avatar if this is a direct chat and the user matches
            if conversation.type == .direct,
               let notificationUserId = notification.userInfo?["userId"] as? String,
               let otherUser = otherUser,
               otherUser.id.contains(notificationUserId) || otherUser.id == "user_\(notificationUserId)" {
                refreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .streamChatAvatarUpdated)) { notification in
            // Refresh avatar for Stream Chat updates
            if conversation.type == .direct,
               let notificationUserId = notification.userInfo?["userId"] as? String,
               let otherUser = otherUser,
               otherUser.id.contains(notificationUserId) || otherUser.id == "user_\(notificationUserId)" {
                refreshID = UUID()
            }
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        if let name = conversation.name, !name.isEmpty {
            Text(name.prefix(1).uppercased())
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(.white)
        } else {
            Image(systemName: conversationIcon)
                .font(.system(size: size * 0.43, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - Story helpers for direct chats
    private func storyStateForDirectChat() -> (Bool, Int) {
        guard conversation.type == .direct, let other = otherUser else { return (false, 0) }
        let normalizedId = other.id.replacingOccurrences(of: "user_", with: "")
        guard let userIdInt = Int(normalizedId) else { return (false, 0) }
        let unseen = storyService.unseenCount(for: userIdInt)
        return (unseen > 0, unseen)
    }
}
