import SwiftUI
import Combine

// MARK: - Optimized Chat View
struct OptimizedChatView: View {
    let conversationId: String
    let conversationName: String

    @StateObject private var chatProviderManager = ChatProviderManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authService: AuthServiceDirect
    @Environment(\.dismiss) private var dismiss

    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var serverUpdateObserver: NSObjectProtocol?
    @State private var messageUpdatesCancellable: AnyCancellable?

    // ✅ LAZY CREATION: ID real del canal después de crearlo
    @State private var realChannelId: String?
    @State private var isCreatingChannel = false

    // MARK: - Moderación (guía 1.2 de App Store)
    @State private var otherUserId: String?
    @State private var blockedUserIds: Set<String> = []
    @State private var moderationNotice: String?

    // ✅ LAZY CREATION: Computed property para ID efectivo del canal
    private var effectiveChannelId: String {
        return realChannelId ?? conversationId
    }

    // ✅ LAZY CREATION: Detectar si es canal temporal
    private var isTemporaryChannel: Bool {
        return conversationId.hasPrefix("temp_direct_")
    }

    // ✅ NUEVO: Actor-based coordinator para prevenir race conditions
    private let loadingCoordinator = MessageLoadingCoordinator()

    // ✅ NUEVO: Message window para lazy loading y reducción de memoria
    private let messageWindow = MessageWindow()
    @State private var visibleMessages: [ChatMessage] = []

    // ✅ DEPRECATED: Serán reemplazados por loadingCoordinator
    @State private var messageLoadingTask: Task<Void, Never>?
    @State private var currentLoadingConversationId: String?

    // Computed property para mensajes ordenados (ahora usa window en vez de array completo)
    private var sortedMessages: [ChatMessage] {
        // Obtener mensajes del window en vez de array completo.
        //
        // El filtrado por gente bloqueada se hace AQUÍ a propósito: Stream persiste la lista de
        // bloqueados en el usuario actual pero no filtra por ella en las consultas del canal, así
        // que sin esto bloquear a alguien seguiría enseñando todo lo que escribe.
        return visibleMessages
            .filter { !blockedUserIds.contains($0.authorId) }
            .sorted { $0.timestamp < $1.timestamp }
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
        .navigationBarHidden(true)
        .task { await loadModerationContext() }
        .alert("Thanks for letting us know", isPresented: .constant(moderationNotice != nil)) {
            Button("OK") { moderationNotice = nil }
        } message: {
            Text(moderationNotice ?? "")
        }
        .onAppear {
            print("💬 ========================================")
            print("💬 ABRIENDO CHAT")
            print("💬 ========================================")
            print("💬 Conversation ID: \(conversationId)")
            print("💬 Conversation Name: \(conversationName)")
            print("💬 ChatProvider State: \(chatProviderManager.state.displayText)")
            print("💬 ChatProvider isReady: \(chatProviderManager.isReady)")
            print("💬 ChatProvider isInitialized: \(chatProviderManager.isInitialized)")

            // Log mensajes en caché si existen
            let cachedMessages = MessageCacheManager.shared.getCachedMessages(for: conversationId)
            if !cachedMessages.isEmpty {
                print("💬 📦 Mensajes en caché: \(cachedMessages.count)")
                print("💬 📦 Último mensaje: \(cachedMessages.last?.text ?? "N/A")")
            } else {
                print("💬 📦 No hay mensajes en caché")
            }

            print("💬 ========================================")

            loadMessages()
            // ✅ LAZY CREATION: No configurar listener para canales temporales hasta que se creen
            if !isTemporaryChannel {
                setupServerUpdateListener(for: conversationId)
            }
            setupMessageUpdatesListener()
            // Marcar como leído al entrar al chat
            markConversationAsRead()
        }
        .onDisappear {
            print("💬 👋 CERRANDO CHAT")

            // ✅ CRÍTICO: Cancelar coordinator para prevenir race conditions
            Task {
                await loadingCoordinator.cancel()
                print("💬 👋 🧹 MessageLoadingCoordinator cancelado")

                // ✅ CRÍTICO: Limpiar MessageWindow para liberar memoria
                await messageWindow.clear()
                print("💬 👋 🪟 MessageWindow limpiado")
            }

            // ✅ CRÍTICO: Liberar presupuesto de memoria
            let budgetKey = "messageCache_\(conversationId)"
            MemoryBudgetManager.shared.deallocate(for: budgetKey)
            print("💬 👋 💰 Presupuesto de memoria liberado para: \(conversationId)")

            // DEPRECATED: Mantener por ahora para compatibilidad
            messageLoadingTask?.cancel()
            messageLoadingTask = nil
            currentLoadingConversationId = nil

            // Limpiar observers para evitar memory leaks
            if let observer = serverUpdateObserver {
                NotificationCenter.default.removeObserver(observer)
                serverUpdateObserver = nil
            }

            // Cancelar suscripción a actualizaciones de mensajes
            messageUpdatesCancellable?.cancel()
            messageUpdatesCancellable = nil
            print("💬 👋 🧹 Observers y suscripciones canceladas")

            // Recortar mensajes para liberar memoria
            if messages.count > 50 {
                let recentMessages = Array(messages.sorted { $0.timestamp < $1.timestamp }.suffix(50))
                messages = recentMessages
                print("💬 👋 🧹 Mensajes recortados a 50 más recientes")
            }
        }
    }
    
    // MARK: - Header
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(conversationName.prefix(1).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                Text(conversationName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                // Aquí había un punto verde y la palabra «Online», pintados siempre y para
                // cualquier conversación, sin consultar presencia a nadie. Era información falsa
                // sobre otra persona. Vuelve cuando se lea la presencia de verdad.
                EmptyView()
            }
            
            Spacer()
            
            // Denunciar y bloquear. La App Store lo exige en cualquier app con contenido de
            // otras personas, y el chat es la única superficie de contenido ajeno que le queda al
            // cliente de un entrenador personal.
            Menu {
                Button(role: .destructive) {
                    Task { await report() }
                } label: {
                    Label("Report conversation", systemImage: "flag")
                }

                if let otherUserId, blockedUserIds.contains(otherUserId) {
                    Button {
                        Task { await setBlocked(false) }
                    } label: {
                        Label("Unblock", systemImage: "person.crop.circle.badge.checkmark")
                    }
                } else {
                    Button(role: .destructive) {
                        Task { await setBlocked(true) }
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .rotationEffect(.degrees(90))
            }
            .disabled(otherUserId == nil)
        }
        .padding()
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
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
                                .contextMenu {
                                    if !message.isFromCurrentUser {
                                        Button(role: .destructive) {
                                            Task { await reportMessage(message) }
                                        } label: {
                                            Label("Report message", systemImage: "flag")
                                        }
                                    }
                                }
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
            // Text input field - Simplified design
            TextField("Escribe un mensaje...", text: $messageText, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1...4) // Allow up to 4 lines
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            themeManager.currentTheme == .dark ?
                            Color(white: 0.15) :
                            Color(white: 0.95)
                        )
                )
            
            // Send button - Simple arrow design
            Button(action: {
                sendMessage()
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                            ? Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.4)
                            : Color.dynamicAccent(theme: themeManager.currentTheme)
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.clear
                                    : Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                            )
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.dynamicBackground(theme: themeManager.currentTheme)
        )
    }
    
    // MARK: - Actions
    
    /// Carga mensajes usando estrategia cache-first para experiencia instantánea
    /// ✅ OPTIMIZADO: Usa MessageLoadingCoordinator actor para prevenir race conditions
    /// ✅ OPTIMIZADO: Background JSON decoding para no bloquear UI
    /// ✅ OPTIMIZADO: MessageWindow para lazy loading y reducción de memoria
    /// ✅ LAZY CREATION: Usa effectiveChannelId para soportar canales creados dinámicamente
    // MARK: - Moderación

    /// Resuelve con quién se habla y qué gente hay bloqueada.
    ///
    /// Sin el identificador de la otra persona no se puede ni denunciar ni bloquear, así que el
    /// menú se queda deshabilitado hasta que esto termina.
    private func loadModerationContext() async {
        guard let provider = chatProviderManager.currentProvider else { return }
        blockedUserIds = provider.blockedUserIds
        guard otherUserId == nil else { return }
        do {
            let participants = try await provider.getUsers(in: effectiveChannelId)
            otherUserId = participants
                .map(\.id)
                .first(where: { $0 != currentStreamUserId })
        } catch {
            Logger.shared.error("Chat: no se pudo resolver el otro participante: \(error.localizedDescription)", category: .network)
        }
    }

    /// Identificador propio en Stream, para saber quién es «el otro».
    private var currentStreamUserId: String? {
        (chatProviderManager.currentProvider as? GetStreamChatProvider)?.currentUserId
    }

    private func reportMessage(_ message: ChatMessage) async {
        guard let provider = chatProviderManager.currentProvider else { return }
        do {
            try await provider.flagMessage(message.id, in: effectiveChannelId)
            moderationNotice = "The message has been reported. We review reports and take action on what breaks our rules."
            HapticManager.shared.play(.warning)
        } catch {
            moderationNotice = "We could not send the report. Please try again."
        }
    }

    private func report() async {
        guard let provider = chatProviderManager.currentProvider, let otherUserId else { return }
        do {
            try await provider.flagUser(otherUserId)
            moderationNotice = "This conversation has been reported. We review reports and take action on what breaks our rules."
            HapticManager.shared.play(.warning)
        } catch {
            moderationNotice = "We could not send the report. Please try again."
        }
    }

    private func setBlocked(_ blocked: Bool) async {
        guard let provider = chatProviderManager.currentProvider, let otherUserId else { return }
        do {
            if blocked {
                try await provider.blockUser(otherUserId)
                // Se actualiza en local además de en el servidor: el filtrado de la lista de
                // mensajes lee de aquí, y esperar al siguiente refresco dejaría el bloqueo sin
                // efecto visible.
                blockedUserIds.insert(otherUserId)
                moderationNotice = "Blocked. You will not see their messages any more."
            } else {
                try await provider.unblockUser(otherUserId)
                blockedUserIds.remove(otherUserId)
                moderationNotice = "Unblocked."
            }
            HapticManager.shared.play(.warning)
        } catch {
            moderationNotice = "We could not complete that. Please try again."
        }
    }

    private func loadMessages() {
        // ✅ LAZY CREATION: Si es canal temporal y aún no se ha creado, no cargar mensajes
        if isTemporaryChannel && realChannelId == nil {
            print("✨ LAZY CREATION: Canal temporal sin crear - no hay mensajes que cargar")
            return
        }

        let channelId = effectiveChannelId
        print("💬 📦 loadMessages() para: \(channelId)")

        // 1. Usar coordinator para carga segura (previene race conditions)
        Task {
            // Cargar caché en background (no bloquea UI)
            let cachedMessages = await MessageCacheManager.shared.getCachedMessagesAsync(for: channelId)

            if !cachedMessages.isEmpty {
                // Inicializar window con mensajes del caché
                let messageIds = cachedMessages.sorted { $0.timestamp < $1.timestamp }.map { $0.id }
                await messageWindow.initialize(with: messageIds)
                await messageWindow.loadMessages(cachedMessages)

                // Obtener mensajes visibles del window
                let windowedMessages = await messageWindow.getVisibleMessages()

                await MainActor.run {
                    self.visibleMessages = windowedMessages
                    self.messages = cachedMessages  // Mantener para compatibilidad
                    print("💬 📦 [Background] Caché cargado: \(cachedMessages.count) mensajes total, \(windowedMessages.count) visibles")
                }
            } else {
                await MainActor.run { isLoading = true }
            }

            do {
                // El coordinator garantiza que solo la última request se completa
                let freshMessages = try await loadingCoordinator.loadMessages(
                    conversationId: channelId
                ) {
                    // Closure de fetch real
                    if let streamProvider = chatProviderManager.currentProvider as? GetStreamChatProvider {
                        return try await streamProvider.getMessagesWithCache(for: channelId)
                    } else {
                        return try await chatProviderManager.getMessages(for: channelId)
                    }
                }

                // Inicializar window con mensajes frescos
                let messageIds = freshMessages.sorted { $0.timestamp < $1.timestamp }.map { $0.id }
                await messageWindow.initialize(with: messageIds)
                await messageWindow.loadMessages(freshMessages)

                // Obtener mensajes visibles del window
                let windowedMessages = await messageWindow.getVisibleMessages()

                // Actualizar UI - el coordinator ya garantizó que es la conversación correcta
                await MainActor.run {
                    if cachedMessages.isEmpty || !messagesAreEqual(freshMessages, messages) {
                        self.messages = freshMessages  // Mantener para compatibilidad
                        self.visibleMessages = windowedMessages
                        print("💬 ✅ UI actualizada con \(freshMessages.count) mensajes total, \(windowedMessages.count) visibles")

                        #if DEBUG
                        Task {
                            await messageWindow.debugPrintStatus()
                        }
                        #endif
                    }

                    isLoading = false
                    errorMessage = nil
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    print("💬 ❌ Error: \(error)")
                }
            }
        }
    }
    
    /// Envía mensaje con UI optimista - aparece inmediatamente
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            print("💬 📤 Intento de envío cancelado - mensaje vacío")
            return
        }

        print("💬 📤 ========================================")
        print("💬 📤 ENVIANDO MENSAJE")
        print("💬 📤 Conversación: \(conversationId)")
        print("💬 📤 Es temporal: \(isTemporaryChannel)")
        print("💬 📤 Texto: \(text.prefix(50))...")
        print("💬 📤 Longitud: \(text.count) caracteres")

        messageText = ""

        Task {
            do {
                // ✅ LAZY CREATION: Si es canal temporal, crear primero en backend
                let targetChannelId: String
                if isTemporaryChannel && realChannelId == nil {
                    print("✨ LAZY CREATION: Canal temporal detectado - creando en backend...")
                    await MainActor.run {
                        isCreatingChannel = true
                    }

                    // Extraer userId del ID temporal: temp_direct_{userId}
                    let userIdString = conversationId.replacingOccurrences(of: "temp_direct_", with: "")
                    guard let userId = Int(userIdString) else {
                        throw NSError(domain: "OptimizedChatView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID from temporal conversation ID"])
                    }

                    print("✨ Extrayendo userId: \(userId)")

                    // Crear canal real en backend
                    let chatService = ChatService.shared
                    chatService.authService = authService
                    if let user = authService.user {
                        chatService.setCurrentUserIdFromString(user.id)
                    }

                    guard let chatRoom = await chatService.getDirectChat(withUserId: userId) else {
                        throw NSError(domain: "OptimizedChatView", code: -2, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el canal directo"])
                    }

                    print("✅ LAZY CREATION: Canal creado exitosamente: \(chatRoom.streamChannelId)")

                    await MainActor.run {
                        realChannelId = chatRoom.streamChannelId
                        isCreatingChannel = false

                        // ✅ Configurar listener ahora que tenemos el canal real
                        setupServerUpdateListener(for: chatRoom.streamChannelId)
                    }

                    targetChannelId = chatRoom.streamChannelId
                    print("✅ LAZY CREATION: Usando ID real: \(targetChannelId)")
                } else {
                    targetChannelId = effectiveChannelId
                    print("📋 Usando canal existente: \(targetChannelId)")
                }

                // Usar un ID temporal específico para poder rastrearlo
                let tempId = "temp_\(UUID().uuidString)"
                print("💬 📤 ID temporal asignado: \(tempId)")

                let optimisticMessage = ChatMessage(
                    id: tempId,
                    conversationId: targetChannelId,
                    text: text,
                    authorId: "current_user",
                    authorName: "Current User",
                    authorAvatarURL: nil,
                    timestamp: Date(),
                    isFromCurrentUser: true,
                    syncStatus: .sending
                )

                // Agregar inmediatamente a la UI
                await MainActor.run {
                    messages.append(optimisticMessage)
                    print("💬 📤 ✅ Mensaje agregado optimistamente a la UI")
                    print("💬 📤 Total de mensajes en UI: \(messages.count)")
                }

                print("💬 📤 🌐 Enviando al servidor...")
                let _ = try await chatProviderManager.sendMessage(optimisticMessage, to: targetChannelId)
                print("💬 📤 ✅ Mensaje enviado exitosamente al servidor")
                print("💬 📤 ========================================")

            } catch {
                print("💬 📤 ❌ Error al enviar mensaje: \(error.localizedDescription)")

                await MainActor.run {
                    isCreatingChannel = false
                    self.errorMessage = error.localizedDescription
                    print("💬 📤 ========================================")
                }
            }
        }
    }
    
    /// Configura listener para actualizaciones desde servidor en background
    /// ✅ MEJORADO: Con validación de conversationId para prevenir race conditions
    /// ✅ LAZY CREATION: Acepta channelId como parámetro para soportar canales creados dinámicamente
    private func setupServerUpdateListener(for channelId: String) {
        // Limpiar listener anterior si existe
        if let observer = serverUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        let targetConversationId = channelId

        serverUpdateObserver = NotificationCenter.default.addObserver(
            forName: .messagesUpdatedFromServer,
            object: nil,
            queue: .main
        ) { [self] notification in

            // ✅ Verificar que el update es para esta conversación
            guard let updateConversationId = notification.userInfo?["conversationId"] as? String,
                  updateConversationId == targetConversationId else {
                return
            }

            guard let freshMessages = notification.userInfo?["messages"] as? [ChatMessage] else {
                return
            }

            if !messagesAreEqual(messages, freshMessages) {
                messages = freshMessages
                print("🔄 Mensajes actualizados desde servidor para canal: \(channelId)")
            }
        }
    }
    
    /// Configura listener para actualizaciones individuales de mensajes (estado de sync)
    /// ✅ MEJORADO: Con doble verificación de conversationId para prevenir race conditions
    private func setupMessageUpdatesListener() {
        guard let provider = chatProviderManager.currentProvider else {
            print("⚠️ No hay provider disponible")
            return
        }

        // ✅ Capturar conversationId actual
        let targetConversationId = conversationId

        print("📡 Configurando listener para: \(targetConversationId)")

        messageUpdatesCancellable = provider.messageUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] update in

                // ✅ FILTRO CRÍTICO 1: Verificar conversationId del update
                guard update.conversationId == targetConversationId else {
                    return
                }

                // ✅ FILTRO CRÍTICO 2: Verificar que la vista sigue en esa conversación
                guard conversationId == targetConversationId else {
                    print("⚠️ Vista cambió de conversación, ignorando update")
                    return
                }

                print("📨 Update recibido para conversación actual: \(update.type)")

                switch update.type {
                case .new:
                    // Usar smart merge para prevenir duplicados optimistas
                    handleNewMessage(update.message)

                case .updated:
                    if let index = messages.firstIndex(where: { $0.id == update.message.id }) {
                        messages[index] = update.message
                        print("✅ Mensaje actualizado")
                    }

                case .deleted:
                    messages.removeAll { $0.id == update.message.id }
                    print("✅ Mensaje eliminado")
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

    /// Maneja nuevo mensaje con smart merge para eliminar duplicados optimistas
    /// Busca mensajes optimistas con mismo fingerprint y los promociona al ID real
    /// ✅ OPTIMIZADO: Actualiza tanto el array messages como el MessageWindow
    private func handleNewMessage(_ message: ChatMessage) {
        // 1. Crear fingerprint del mensaje entrante
        let fingerprint = MessageFingerprint(from: message)

        // 2. Buscar mensaje optimista con mismo fingerprint
        if let optimisticIndex = messages.firstIndex(where: { msg in
            msg.id.hasPrefix("temp_") &&
            MessageFingerprint(from: msg) == fingerprint
        }) {
            // 3. Reemplazar mensaje optimista con confirmado
            var confirmed = message
            confirmed.syncStatus = .synced
            messages[optimisticIndex] = confirmed
            print("✅ Mensaje optimista promovido: \(optimisticIndex) -> ID real \(message.id)")

        } else if !messages.contains(where: { $0.id == message.id }) {
            // 4. Es mensaje nuevo de otro usuario (no optimista)
            messages.append(message)
            print("📨 Mensaje nuevo recibido: \(message.id)")

            // Agregar al window
            Task {
                await messageWindow.appendMessage(message)

                // Actualizar mensajes visibles
                let windowedMessages = await messageWindow.getVisibleMessages()
                await MainActor.run {
                    self.visibleMessages = windowedMessages
                }
            }
        } else {
            print("⏭️ Mensaje ya existe (ID duplicado ignorado): \(message.id)")
        }
    }

    /// Marca la conversación como leída en el proveedor (GetStream)
    private func markConversationAsRead() {
        // ✅ LAZY CREATION: No marcar como leído canales temporales
        if isTemporaryChannel {
            print("✨ LAZY CREATION: Canal temporal - no hay nada que marcar como leído")
            return
        }

        let lastMessageId = sortedMessages.last?.id ?? ""
        Task {
            guard let provider = chatProviderManager.currentProvider else { return }
            do {
                try await provider.markAsRead(messagesUpTo: lastMessageId, in: effectiveChannelId)
                print("✅ Conversación marcada como leída: \(effectiveChannelId)")
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
            // Avatar for received messages
            if !message.isFromCurrentUser {
                if let avatarURL = message.authorAvatarURL, !avatarURL.isEmpty {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        // Show initials while loading or as fallback
                        initialAvatar
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    // Show initials if no avatar URL
                    initialAvatar
                        .frame(width: 32, height: 32)
                }
            }
            
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Author name for received messages
                if !message.isFromCurrentUser {
                    Text(message.authorName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 4)
                }
                
                // Message bubble with improved design
                VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    HStack {
                        if message.isFromCurrentUser { Spacer() }
                        
                        Text(message.text)
                            .font(.system(size: 16))
                            .foregroundColor(bubbleTextColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(bubbleBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        
                        if !message.isFromCurrentUser { Spacer() }
                    }
                    
                    // Timestamp - positioned outside bubble
                    HStack(spacing: 4) {
                        if message.isFromCurrentUser { Spacer() }
                        
                        Text(formatDate(message.timestamp))
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.6))
                            
                        
                        if message.isFromCurrentUser {
                            syncStatusIcon(for: message.syncStatus)
                        }
                        
                        if !message.isFromCurrentUser { Spacer() }
                    }
                    .padding(.horizontal, 14)
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
                        
                        Button("Try again") {
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
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    private var bubbleTextColor: Color {
        if message.isFromCurrentUser {
            return .white
        } else {
            return themeManager.currentTheme == .dark ? .white : Color.dynamicText(theme: themeManager.currentTheme)
        }
    }
    
    private var initialAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
            
            Text(getInitials(from: message.authorName))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
        return initials.uppercased()
    }
    
    private var bubbleBackground: Color {
        if message.isFromCurrentUser {
            // Usar el color del tema actual dinámicamente
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
            // Gris oscuro para mensajes recibidos (como en el diseño)
            return themeManager.currentTheme == .dark ? 
                Color(white: 0.15) : 
                Color(white: 0.92)
        }
    }
    
    private var bubbleBorderColor: Color {
        return Color.clear // Sin bordes para diseño más limpio
    }
    
    private var bubbleBorderWidth: CGFloat {
        0 // Sin bordes
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
