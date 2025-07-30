import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @ObservedObject private var chatService = ChatService.shared
    @StateObject private var directMessageService = DirectMessageService()
    @State private var selectedChatType: ChatType? = nil
    @State private var showingChat = false
    @State private var selectedChatRoom: ChatRoom? = nil
    @State private var showingUserSelector = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header personalizado con título y botones
                    VStack(spacing: 16) {
                        // Título y botones
                        HStack {
                            Text("Messages")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                // Botón de refresh
                                Button(action: {
                                    Task {
                                        await refreshLastMessages()
                                    }
                                }) {
                                    if chatService.isRefreshingMessages {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 18))
                                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    }
                                }
                                .disabled(chatService.isRefreshingMessages)
                                
                                // Botón de nuevo chat
                                Button(action: {
                                    showingUserSelector = true
                                }) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Indicador de estado
                        if chatService.isRefreshingMessages {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                                    .scaleEffect(0.7)
                                
                                Text("Actualizando mensajes...")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        } else if !chatService.chatRooms.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.badge")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text("Mostrando datos guardados")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    
                    // Contenido principal
                    if chatService.chatRooms.isEmpty && !chatService.isRefreshingMessages {
                        EmptyMessagesView()
                    } else {
                        VStack(spacing: 0) {
                            // Filtros de chat
                            ChatFilterHeader(selectedChatType: $selectedChatType, themeManager: themeManager)
                                .padding(.vertical, 12)
                            
                            // Lista de chats
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredChatRooms) { chatRoom in
                                        ChatRoomRow(
                                            chatRoom: chatRoom,
                                            themeManager: themeManager,
                                            onTap: {
                                                handleChatSelection(chatRoom)
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                }
                                .padding(.vertical, 16)
                            }
                        }
                    }
                }
            }
            .onAppear {
                setupChatService()
                loadChatRooms()
            }
            .sheet(isPresented: $showingUserSelector) {
                UserSelectorView(
                    onUserSelected: { user in
                        showingUserSelector = false
                        startDirectChat(with: user)
                    },
                    onCancel: {
                        showingUserSelector = false
                    }
                )
                .environmentObject(authService)
                .environmentObject(themeManager)
            }
            .background(
                NavigationLink(
                    destination: selectedChatRoom != nil ? 
                        AnyView(UniversalChatView(chatRoom: selectedChatRoom!, authService: authService)
                            .environmentObject(themeManager)
                            .navigationBarHidden(true)) :
                        AnyView(EmptyView()),
                    isActive: $showingChat,
                    label: { EmptyView() }
                )
            )
        }
    }
    
    // MARK: - Computed Properties
    private var filteredChatRooms: [ChatRoom] {
        var rooms = chatService.chatRooms
        
        print("🔍 MessagesView: Calculando filteredChatRooms")
        print("📊 Total chatRooms desde servicio: \(rooms.count)")
        
        if let selectedType = selectedChatType {
            rooms = rooms.filter { $0.chatType == selectedType }
            print("🔽 Filtrado por tipo \(selectedType.displayName): \(rooms.count) chats")
        }
        
        // Si no hay salas de chat desde el servicio, usar las salas simuladas del directMessageService
        if rooms.isEmpty {
            rooms = chatService.chatRooms
            print("⚠️ Rooms estaba vacío, restaurando desde chatService: \(rooms.count)")
        }
        
        // Log antes del ordenamiento
        print("📝 Estado antes del ordenamiento en MessagesView:")
        for (i, room) in rooms.enumerated() {
            print("   \(i): \(room.name ?? "Sin nombre") - \(room.effectiveDate)")
        }
        
        // Ordenar por fecha del último mensaje (más reciente primero)
        let sortedRooms = rooms.sorted { room1, room2 in
            room1.effectiveDate > room2.effectiveDate
        }
        
        // Log después del ordenamiento
        print("✅ Estado después del ordenamiento en MessagesView:")
        for (i, room) in sortedRooms.enumerated() {
            print("   \(i): \(room.name ?? "Sin nombre") - \(room.effectiveDate)")
        }
        
        return sortedRooms
    }
    
    // MARK: - Private Methods
    private func setupChatService() {
        chatService.authService = authService
        // El gym ID se obtiene dinámicamente desde GymService.shared.currentGym
        // No necesitamos configurarlo manualmente ya que es una computed property
    }
    
    private func loadChatRooms() {
        Task {
            // Cargar miembros del gym primero para tener nombres disponibles
            await chatService.loadGymMembers()
            
            // Cargar chat rooms desde el backend
            await chatService.getMyRooms()
            
            // Una vez cargados, refrescar con datos de Stream.io
            await refreshLastMessages()
        }
    }
    
    private func refreshLastMessages() async {
        // Refrescar los últimos mensajes usando Stream.io
        await chatService.refreshLastMessages()
    }
    
    private func startDirectChat(with user: UserProfile) {
        print("🚀 MessagesView: Iniciando chat directo con \(user.fullName)")
        
        Task {
            let directChatRoom = await chatService.getDirectChat(withUserId: user.id)
            
            if let directChatRoom = directChatRoom {
                await MainActor.run {
                    selectedChatRoom = directChatRoom
                    showingChat = true
                    print("✅ MessagesView: Chat room configurado para navegación")
                }
            } else {
                print("❌ MessagesView: Error obteniendo chat room")
            }
        }
    }
    
    private func handleChatSelection(_ chatRoom: ChatRoom) {
        print("📱 Chat seleccionado: \(chatRoom.name ?? "Sin nombre") - Tipo: \(chatRoom.chatType)")
        selectedChatRoom = chatRoom
        showingChat = true
    }
}

// MARK: - Supporting Views
struct EmptyMessagesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.circle")
                .font(.system(size: 64))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No messages yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Start a conversation with someone")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChatFilterHeader: View {
    @Binding var selectedChatType: ChatType?
    let themeManager: ThemeManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Opción "Todos"
                ChatFilterButton(
                    title: "All",
                    isSelected: selectedChatType == nil,
                    themeManager: themeManager
                ) {
                    selectedChatType = nil
                }
                
                // Filtros por tipo
                ForEach(ChatType.allCases, id: \.self) { chatType in
                    ChatFilterButton(
                        title: chatType.displayName,
                        isSelected: selectedChatType == chatType,
                        themeManager: themeManager
                    ) {
                        selectedChatType = chatType
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct ChatFilterButton: View {
    let title: String
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicSurface(theme: themeManager.currentTheme))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChatRoomRow: View {
    let chatRoom: ChatRoom
    let themeManager: ThemeManager
    let onTap: () -> Void
    @ObservedObject private var chatService = ChatService.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar del chat
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(chatRoom.displayInitials)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    // Título del chat (permitir más líneas para eventos)
                    Text(chatService.getResolvedDisplayName(for: chatRoom))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let lastMessage = chatRoom.lastMessage {
                        Text(lastMessage)
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                // Fecha y indicador
                VStack(alignment: .trailing, spacing: 4) {
                    Text(chatRoom.lastMessageFormattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 80)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MessagesView()
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
}