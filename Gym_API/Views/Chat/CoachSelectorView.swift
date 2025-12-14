import SwiftUI
import Auth0

// MARK: - User Selector View (anteriormente Coach Selector)
/// Vista para seleccionar usuarios para iniciar chat
/// TRAINER/ADMIN/OWNER: Pueden seleccionar cualquier miembro
/// MEMBER: Solo pueden seleccionar coaches
struct CoachSelectorView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect

    // MARK: - State Objects
    @StateObject private var chatService = ChatService.shared
    @StateObject private var gymService = GymService.shared

    // MARK: - Bindings
    @Binding var isPresented: Bool

    // MARK: - Completion Handler
    let onCoachSelected: (UserProfile) -> Void

    // MARK: - State Variables
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var users: [UserProfile] = []
    @State private var errorMessage: String?
    @State private var hasInitialized = false

    // MARK: - Computed Properties

    /// Verifica si el usuario actual puede chatear con cualquier miembro
    private var canMessageAnyUser: Bool {
        // Verificar rol del gym actual (fuente principal de verdad)
        if let gymRole = gymService.currentGym?.userRoleInGym {
            return RolePermissions.canMessageAnyUser(gymRole)
        }
        // Fallback: si no hay gym role, asumir que es MEMBER (no puede mensajear a todos)
        // Esto es seguro porque los roles privilegiados siempre tendrán gymRole
        return false
    }

    /// Título dinámico según permisos
    private var viewTitle: String {
        canMessageAnyUser ? "Seleccionar Usuario" : "Seleccionar Coach"
    }

    /// Placeholder de búsqueda dinámico
    private var searchPlaceholder: String {
        canMessageAnyUser ? "Buscar usuarios..." : "Buscar coaches..."
    }

    /// Mensaje de empty state dinámico
    private var emptyStateTitle: String {
        if searchText.isEmpty {
            return canMessageAnyUser ? "No hay usuarios disponibles" : "No hay coaches disponibles"
        } else {
            return canMessageAnyUser ? "No se encontraron usuarios" : "No se encontraron coaches"
        }
    }

    private var emptyStateMessage: String {
        if searchText.isEmpty {
            return canMessageAnyUser ?
                "No hay miembros disponibles en tu gimnasio en este momento." :
                "No hay coaches disponibles en tu gimnasio en este momento."
        } else {
            return "Intenta ajustar tus términos de búsqueda."
        }
    }

    private var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.fullName.localizedCaseInsensitiveContains(searchText) ||
                (user.role.localizedCaseInsensitiveContains(searchText)) ||
                (user.gymRole?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBarView

                    // Content
                    contentView
                }
            }
            .navigationTitle(viewTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .onAppear {
                initializeIfNeeded()
            }
        }
    }

    // MARK: - Search Bar View
    private var searchBarView: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))

            // Search field
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocorrectionDisabled()

            // Clear button
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .stroke(
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Content View
    private var contentView: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if filteredUsers.isEmpty {
                emptyStateView
            } else {
                usersList
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(
                    tint: Color.dynamicAccent(theme: themeManager.currentTheme)
                ))
                .scaleEffect(1.2)

            Text(canMessageAnyUser ? "Cargando usuarios..." : "Cargando coaches...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.orange)

            Text(canMessageAnyUser ? "Error al cargar usuarios" : "Error al cargar coaches")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: {
                Task { await loadUsers() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Reintentar")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: searchText.isEmpty ? "person.badge.shield.checkmark" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

            VStack(spacing: 12) {
                Text(emptyStateTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(emptyStateMessage)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                        Text("Limpiar búsqueda")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 1.5)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Users List
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredUsers) { user in
                    UserRow(user: user) {
                        onCoachSelected(user)
                        isPresented = false
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Methods
    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        Task {
            await loadUsers()
        }
    }

    private func loadUsers() async {
        print("👥 Iniciando carga de usuarios...")
        print("   - Permiso canMessageAnyUser: \(canMessageAnyUser)")

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Configure authService
        chatService.authService = authService

        // Load gym members
        await chatService.loadGymMembers()

        // Get users based on permissions
        let loadedUsers: [UserProfile]
        if canMessageAnyUser {
            // TRAINER/ADMIN/OWNER: Cargar TODOS los miembros
            print("   - Cargando TODOS los miembros del gimnasio")
            loadedUsers = await chatService.getAllGymMembers()
        } else {
            // MEMBER: Solo cargar coaches
            print("   - Cargando solo coaches")
            loadedUsers = await chatService.getAvailableCoaches()
        }

        await MainActor.run {
            self.users = loadedUsers
            self.isLoading = false

            print("✅ Usuarios cargados: \(self.users.count)")
            for user in self.users.prefix(5) {
                print("   - \(user.fullName) (\(user.role)) - Gym Role: \(user.gymRole ?? "N/A")")
            }
            if self.users.count > 5 {
                print("   ... y \(self.users.count - 5) más")
            }
        }
    }
}

// MARK: - User Row View
struct UserRow: View {
    let user: UserProfile
    let onSelect: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Avatar
                if let pictureURL = user.picture,
                   let url = URL(string: pictureURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text("\(user.firstName.prefix(1))\(user.lastName.prefix(1))".uppercased())
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Circle()
                        .fill(Color(hex: user.color ?? "#D93333") ?? Color.gray)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text("\(user.firstName.prefix(1))\(user.lastName.prefix(1))".uppercased())
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }

                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    HStack(spacing: 8) {
                        // Role badge
                        Text(user.displayGymRole ?? user.displayRole)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                            )

                        // Status
                        if user.isActive ?? true {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Activo")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    CoachSelectorView(
        isPresented: .constant(true),
        onCoachSelected: { _ in }
    )
    .environmentObject(ThemeManager())
    .environmentObject(AuthServiceDirect())
}
