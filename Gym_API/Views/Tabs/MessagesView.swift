import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var directMessageService = DirectMessageService()
    @State private var searchText = ""
    
    private var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return directMessageService.allUsers
        } else {
            return directMessageService.allUsers.filter { user in
                user.fullName.localizedCaseInsensitiveContains(searchText) ||
                user.displayRole.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack {
                    UserSelectorSearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    if directMessageService.isLoadingUsers {
                        UserSelectorLoadingView()
                    } else if let errorMessage = directMessageService.usersErrorMessage {
                        UserSelectorErrorView(
                            message: errorMessage,
                            onRetry: {
                                Task {
                                    await directMessageService.loadAllUsers()
                                }
                            }
                        )
                    } else if filteredUsers.isEmpty {
                        if searchText.isEmpty {
                            UserSelectorEmptyView()
                        } else {
                            UserSelectorEmptySearchView()
                        }
                    } else {
                        UserSelectorList(
                            users: filteredUsers,
                            onUserTap: { user in
                                handleUserTap(user)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await directMessageService.loadAllUsers()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .onAppear {
            setupDirectMessageService()
            Task {
                await directMessageService.loadAllUsers()
            }
        }
        .onChange(of: searchText) { _, newValue in
            // TODO: Implement local search filtering
        }
    }
    
    private func setupDirectMessageService() {
        directMessageService.authService = authService
    }
    
    private func handleUserTap(_ user: UserProfile) {
        print("👤 Navegando a chat con usuario: \(user.fullName)")
        // Implementar navegación a chat directo
    }
}

#Preview {
    MessagesView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}