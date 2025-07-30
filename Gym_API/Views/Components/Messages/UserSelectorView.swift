import SwiftUI

struct UserSelectorView: View {
    let onUserSelected: (UserProfile) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var directMessageService = DirectMessageService()
    
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var users: [UserProfile] = []
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Text("New Message")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Button("Cancel") {
                        onCancel()
                    }
                    .opacity(0)
                    .disabled(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                
                Divider()
                    .background(Color.dynamicBorder(theme: themeManager.currentTheme))
                
                // Search Bar
                UserSelectorSearchBar(text: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                // Content
                if isLoading {
                    UserSelectorLoadingView()
                } else if let errorMessage = errorMessage {
                    UserSelectorErrorView(
                        message: errorMessage,
                        onRetry: loadUsers
                    )
                } else if filteredUsers.isEmpty && !searchText.isEmpty {
                    UserSelectorEmptySearchView()
                } else if users.isEmpty {
                    UserSelectorEmptyView()
                } else {
                    UserSelectorList(
                        users: filteredUsers,
                        onUserTap: onUserSelected
                    )
                }
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
        .onAppear {
            loadUsers()
        }
    }
    
    // MARK: - Computed Properties
    private var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.fullName.localizedCaseInsensitiveContains(searchText) ||
                user.displayRole.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadUsers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Configure directMessageService with authService
                directMessageService.authService = authService
                
                // Load gym users
                await directMessageService.loadAllUsers()
                
                await MainActor.run {
                    if !directMessageService.allUsers.isEmpty {
                        // Filter out current user
                        if let currentUserIdString = authService.user?.id,
                           let currentUserId = Int(currentUserIdString) {
                            self.users = directMessageService.allUsers.filter { $0.id != currentUserId }
                        } else {
                            self.users = directMessageService.allUsers
                        }
                        self.isLoading = false
                    } else {
                        self.errorMessage = directMessageService.usersErrorMessage ?? "No se pudieron cargar los usuarios"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    UserSelectorView(
        onUserSelected: { _ in },
        onCancel: { }
    )
    .environmentObject(ThemeManager())
    .environmentObject(AuthServiceDirect())
}