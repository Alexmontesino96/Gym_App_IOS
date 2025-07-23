//
//  DirectMessagesView.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/22/25.
//

import SwiftUI

struct DirectMessagesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var directMessageService = DirectMessageService()
    @StateObject private var eventService = EventService() // Usar EventService para obtener perfiles de usuario
    
    private var chatService: ChatService {
        ChatService.shared
    }
    @State private var showingNewMessageSheet = false
    @State private var selectedUserId: Int?
    @State private var showingChat = false
    @State private var chatRoom: ChatRoom?
    @State private var searchText = ""
    
    var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return directMessageService.allUsers
        } else {
            return directMessageService.allUsers.filter { user in
                user.fullName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    if directMessageService.isLoadingUsers {
                        LoadingView()
                    } else if let errorMessage = directMessageService.usersErrorMessage {
                        ErrorView(
                            message: errorMessage,
                            onRetry: {
                                Task {
                                    await directMessageService.loadAllUsers()
                                }
                            }
                        )
                    } else if filteredUsers.isEmpty && !searchText.isEmpty {
                        EmptySearchView()
                    } else if directMessageService.allUsers.isEmpty {
                        EmptyUsersView()
                    } else {
                        UsersList(
                            users: filteredUsers,
                            onUserTap: { user in
                                startDirectChat(with: user)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Direct Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: 
                Button(action: {
                    Task {
                        await directMessageService.loadAllUsers()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            )
        }
        .onAppear {
            directMessageService.authService = authService
            chatService.authService = authService
            eventService.authService = authService
            Task {
                await directMessageService.loadAllUsers()
            }
        }
        .fullScreenCover(isPresented: $showingChat) {
            if let chatRoom = chatRoom {
                UniversalChatView(
                    chatRoom: chatRoom,
                    authService: authService
                )
            }
        }
    }
    
    private func startDirectChat(with user: UserProfile) {
        print("🧪 === PROBANDO CHAT DIRECTO ===")
        print("🚀 Iniciando chat directo con usuario: \(user.fullName) (ID: \(user.id))")
        print("🔧 Usando ChatService.shared")
        
        // Forzar recompilación limpiando todo el cache
        Task {
            // Intentar con una petición simple primero
            print("🔄 Limpiando estado previo del ChatService...")
            
            let directChatRoom = await chatService.getDirectChat(withUserId: user.id)
            
            if let directChatRoom = directChatRoom {
                print("✅ Chat room creado/obtenido: \(directChatRoom.streamChannelId)")
                await MainActor.run {
                    chatRoom = directChatRoom
                    showingChat = true
                    print("🔄 Estado actualizado - showingChat: \(showingChat)")
                }
            } else {
                print("❌ No se pudo crear/obtener el chat room")
                if let errorMessage = chatService.roomsErrorMessage {
                    print("❌ Error ChatService: \(errorMessage)")
                }
                
                // Fallback: intentar crear directamente con URLSession
                print("🔄 Intentando fallback con URLSession directo...")
                await testDirectChatFallback(userId: user.id)
            }
        }
    }
    
    // Método fallback para debuggear
    private func testDirectChatFallback(userId: Int) async {
        let urlString = "https://gymapi-eh6m.onrender.com/api/v1/chat/rooms/direct/\(userId)"
        print("🧪 Fallback URL: \(urlString)")
        
        guard let url = URL(string: urlString),
              let accessToken = await authService.getValidAccessToken() else {
            print("❌ No se pudo crear URL o token para fallback")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("🧪 Fallback response: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("✅ Fallback funcionó - el endpoint existe")
                    let responseString = String(data: data, encoding: .utf8) ?? "No data"
                    print("📄 Response data: \(responseString)")
                } else {
                    print("❌ Fallback falló con status: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Fallback error: \(error)")
        }
    }
    
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            TextField("Buscar usuarios...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Users List

struct UsersList: View {
    let users: [UserProfile]
    let onUserTap: (UserProfile) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(users) { user in
                    UserRow(
                        user: user,
                        onTap: { onUserTap(user) }
                    )
                    
                    if user.id != users.last?.id {
                        Divider()
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2))
                            .padding(.leading, 72)
                    }
                }
            }
        }
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: UserProfile
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            AsyncImage(url: URL(string: user.picture)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                
                Text(user.displayRole)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            
            Spacer()
            
            Image(systemName: "message.circle")
                .font(.system(size: 24))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.dynamicSurface(theme: themeManager.currentTheme)
                .opacity(isPressed ? 0.1 : 0.001)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            print("👆 UserRow: Tap detectado en \(user.fullName)")
            onTap()
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Empty States and Loading Views

struct LoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)
            
            Text("Cargando usuarios...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Error")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Reintentar")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                .clipShape(Capsule())
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyUsersView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3")
                .font(.system(size: 64))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No hay usuarios disponibles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Vuelve a intentar más tarde")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptySearchView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
            
            Text("No se encontraron usuarios")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("Prueba con otros términos de búsqueda")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DirectMessagesView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}