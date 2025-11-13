//
//  InstagramStoriesBar.swift
//  Gym_API
//
//  Instagram-style Stories Bar implementation
//  Enhanced with Stream Figma design tokens and smooth animations
//

import SwiftUI

struct InstagramStoriesBar: View {
    @StateObject private var storyUIState = StoryUIState()
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var userProfileService: UserProfileService

    @State private var showingStoryViewer = false
    @State private var showingStoryCreator = false
    @State private var selectedUserIndex = 0
    @State private var showingMyStories = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Instagram-style stories bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StoryDesignTokens.avatarSpacing) {
                    // "Tu historia" - Instagram style
                    InstagramMyStoryButton(
                        hasActiveStory: hasMyActiveStory,
                        onTap: {
                            print("DEBUG:🖱️ Botón 'Tu historia' presionado")
                            print("DEBUG:📊 hasMyActiveStory: \(hasMyActiveStory)")
                            print("DEBUG:📊 myStories.count: \(storyService.myStories.count)")
                            print("DEBUG:📊 Active stories count: \(storyService.myStories.filter { $0.isActive }.count)")

                            StoryHaptics.avatarTap()

                            if hasMyActiveStory {
                                print("DEBUG:👤 Stories: Abriendo mis stories")
                                showingMyStories = true
                            } else {
                                print("DEBUG:➕ Stories: Abriendo creador (no hay stories activas)")
                                showingStoryCreator = true
                            }
                        },
                        onAdd: {
                            print("DEBUG:➕ Stories: Add button tapped - abrir creador")
                            showingStoryCreator = true
                        }
                    )

                    // Otras historias con animación de entrada escalonada
                    // Filtrar para excluir al usuario actual
                    let _ = print("DEBUG:🔍 ForEach - sortedOtherUsersStories.count: \(sortedOtherUsersStories.count)")
                    ForEach(Array(sortedOtherUsersStories.enumerated()), id: \.element.id) { index, userStory in
                        let _ = print("DEBUG:🎨 Renderizando story avatar para: \(userStory.userName)")
                        InstagramStoryAvatar(
                            userStory: userStory,
                            theme: themeManager.currentTheme,
                            onTap: {
                                print("DEBUG: 👆 Story avatar tapped - User: \(userStory.userName), Index: \(index)")
                                print("DEBUG: 📊 Total stories: \(userStory.stories.count)")
                                print("DEBUG: 📊 Active stories: \(userStory.activeStories.count)")
                                print("DEBUG: 📊 Feed stories count: \(sortedOtherUsersStories.count)")

                                // Log each story's active status
                                for (storyIndex, story) in userStory.stories.enumerated() {
                                    print("DEBUG: 📸 Story[\(storyIndex)] - ID: \(story.id), Active: \(story.isActive), ExpiresAt: \(story.expiresAt)")
                                }

                                StoryHaptics.avatarTap()
                                selectedUserIndex = index
                                showingStoryViewer = true
                                print("DEBUG: 🎬 showingStoryViewer set to: \(showingStoryViewer)")
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        storyUIState.avatarFramesByUserId[userStory.userId] = geo.frame(in: .global)
                                    }
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            StoryAnimations.storyEntry.delay(Double(index) * 0.05),
                            value: otherUsersStories.count
                        )
                    }
                }
                .padding(.horizontal, StoryDesignTokens.barHorizontalPadding)
                // Enable iOS 17 snapping when available
                .modifier(EnableSnappingIfAvailable())
                .padding(.vertical, 10)
            }
            .id(storyService.feedStories.map { String($0.userId) }.joined(separator: ","))
            .frame(height: StoryDesignTokens.barHeight)
            .modifier(EnableViewAlignedBehaviorIfAvailable())
            .background(
                Color.dynamicBackground(theme: themeManager.currentTheme)
            )
            .overlay(
                Group {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            Text("Cargando historias...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(StoryDesignTokens.cornerRadius)
                    }
                }
            )

            // Línea divisora sutil como Instagram
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
        .onAppear {
            print("DEBUG:🟢 InstagramStoriesBar.onAppear()")
            loadStoriesIfNeeded()

            // IMPORTANTE: Sincronizar myStories desde el feed existente
            // Esto es necesario porque loadStoriesIfNeeded() puede salir temprano
            // si ya hay stories cargadas (del caché), sin ejecutar syncMyStoriesFromFeed()
            if !storyService.feedStories.isEmpty {
                print("DEBUG:🔄 Feed ya tiene stories, ejecutando syncMyStoriesFromFeed()")
                syncMyStoriesFromFeed()
            }
        }
        .refreshable {
            print("DEBUG:🔄 Stories: Actualizando feed")
            await refreshStories()
        }
        .fullScreenCover(isPresented: $showingStoryViewer) {
            Group {
                if !sortedOtherUsersStories.isEmpty {
                    StoryViewerContainer(
                        userStories: sortedOtherUsersStories,
                        initialUserIndex: selectedUserIndex
                    )
                    .environmentObject(storyService)
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                    .environmentObject(storyUIState)
                    .onAppear {
                        print("DEBUG: 🎥 StoryViewerContainer appeared!")
                        print("DEBUG: 📊 otherUsersStories count: \(otherUsersStories.count)")
                        print("DEBUG: 📊 selectedUserIndex: \(selectedUserIndex)")
                    }
                } else {
                    Text("No hay historias disponibles")
                        .foregroundColor(.white)
                        .onAppear {
                            print("DEBUG: ❌ otherUsersStories is empty, showing fallback")
                        }
                }
            }
            .onAppear {
                print("DEBUG: 🎬 fullScreenCover content appeared!")
                print("DEBUG: 📊 otherUsersStories.isEmpty: \(otherUsersStories.isEmpty)")
                print("DEBUG: 📊 otherUsersStories.count: \(otherUsersStories.count)")
                print("DEBUG: 📊 selectedUserIndex: \(selectedUserIndex)")
            }
        }
        .onChange(of: showingStoryViewer) { newValue in
            print("DEBUG: 🎬 showingStoryViewer changed to: \(newValue)")
            if newValue {
                print("DEBUG: 📊 feedStories.isEmpty: \(storyService.feedStories.isEmpty)")
                print("DEBUG: 📊 feedStories count: \(storyService.feedStories.count)")
                print("DEBUG: 📊 selectedUserIndex: \(selectedUserIndex)")
            } else {
                // Ensure the bar is fully interactive again after dismiss
                // and refresh any state that could have changed while viewing
                selectedUserIndex = 0
                DispatchQueue.main.async {
                    withAnimation { isLoading = false }
                }
                Task { @MainActor in
                    // Lightweight refresh to update hasViewed rings without removing avatars
                    await storyService.fetchStoriesFeed(forceRefresh: false)
                }
            }
        }
        .fullScreenCover(isPresented: $showingMyStories) {
            if let myUserStory = createMyUserStory() {
                StoryViewerContainer(
                    userStories: [myUserStory],
                    initialUserIndex: 0
                )
                .environmentObject(storyService)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(storyUIState)
            }
        }
        .sheet(isPresented: $showingStoryCreator) {
            StoryCreatorView()
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .environmentObject(storyUIState)
    }

    // MARK: - Helper Methods

    // Filtrar historias para excluir al usuario actual
    private var otherUsersStories: [UserStoryGroup] {
        // Intentar obtener el user ID de múltiples fuentes para robustez
        var currentUserIdInt: Int?

        // Fuente 1: UserProfile (preferida)
        if let userProfileId = userProfileService.userProfile?.id {
            currentUserIdInt = userProfileId
            print("DEBUG:👤 User ID desde UserProfile: \(userProfileId)")
        }

        // Fuente 2: AuthService (fallback)
        if currentUserIdInt == nil, let authUser = authService.user {
            // Extraer el ID numérico del auth user ID (formato: "user_10" o "auth0|...")
            let cleanId = authUser.id
                .replacingOccurrences(of: "user_", with: "")
                .replacingOccurrences(of: "auth0|", with: "")
            if let parsedId = Int(cleanId) {
                currentUserIdInt = parsedId
                print("DEBUG:👤 User ID desde AuthService: \(parsedId)")
            }
        }

        guard let currentUserId = currentUserIdInt else {
            print("DEBUG:⚠️ No se pudo obtener el ID del usuario actual de ninguna fuente")
            print("DEBUG:⚠️ UserProfile disponible: \(userProfileService.userProfile != nil)")
            print("DEBUG:⚠️ AuthUser disponible: \(authService.user != nil)")
            // Sin filtrar si no tenemos el user ID - mostrar todas las stories
            return storyService.feedStories
        }

        print("DEBUG:📊 otherUsersStories - Total stories en feed: \(storyService.feedStories.count)")
        print("DEBUG:👤 otherUsersStories - Current user ID confirmado: \(currentUserId)")

        // Log cada usuario en el feed
        for userStory in storyService.feedStories {
            let isCurrentUser = userStory.userId == currentUserId
            print("DEBUG:📸 Story user: \(userStory.userName) (ID: \(userStory.userId)) \(isCurrentUser ? "⚠️ ES EL USUARIO ACTUAL" : "")")
        }

        // Filtrar para remover al usuario actual del feed (sin mutar estado aquí)
        let filtered = storyService.feedStories.filter { $0.userId != currentUserId }

        print("DEBUG:✅ otherUsersStories - Stories después del filtro: \(filtered.count)")

        if filtered.count == storyService.feedStories.count {
            print("DEBUG:⚠️ ADVERTENCIA: El filtro no eliminó ninguna story. Verificar que el user ID coincida.")
        }

        return filtered
    }

    // Stories ordenadas: primero con no vistas, luego por más recientes
    private var sortedOtherUsersStories: [UserStoryGroup] {
        let base = otherUsersStories
        return base.sorted { a, b in
            if a.hasUnseen != b.hasUnseen {
                return a.hasUnseen && !b.hasUnseen
            }
            let da = a.mostRecentStory?.createdAt ?? .distantPast
            let db = b.mostRecentStory?.createdAt ?? .distantPast
            return da > db
        }
    }

    private func loadStoriesIfNeeded() {
        print("DEBUG:📸 Stories: loadStoriesIfNeeded called")
        print("DEBUG:📊 feedStories.isEmpty: \(storyService.feedStories.isEmpty)")
        guard storyService.feedStories.isEmpty else {
            print("DEBUG:✅ Stories already loaded, skipping")
            return
        }
        print("DEBUG:📸 Stories: Cargando feed inicial (forceRefresh=true)")
        isLoading = true
        Task {
            await storyService.fetchStoriesFeed(forceRefresh: true)
            await MainActor.run { syncMyStoriesFromFeed() }
            await MainActor.run {
                print("DEBUG:📊 After fetch - feedStories count: \(storyService.feedStories.count)")
                withAnimation {
                    isLoading = false
                }
            }
        }
    }

    private func refreshStories() async {
        await storyService.fetchStoriesFeed(forceRefresh: true)
        await MainActor.run { syncMyStoriesFromFeed() }
        StoryHaptics.reactionSent()
    }

    /// Actualiza myStories una vez por ciclo de fetch para evitar efectos secundarios en propiedades computadas
    private func syncMyStoriesFromFeed() {
        print("DEBUG:🔄 syncMyStoriesFromFeed() llamado")

        guard let currentUserIdInt = userProfileService.userProfile?.id else {
            print("DEBUG:⚠️ syncMyStoriesFromFeed - No se pudo obtener user ID")
            return
        }

        print("DEBUG:👤 syncMyStoriesFromFeed - Buscando stories para user ID: \(currentUserIdInt)")
        print("DEBUG:📊 syncMyStoriesFromFeed - Total usuarios en feed: \(storyService.feedStories.count)")

        // Log todos los usuarios en el feed
        for userGroup in storyService.feedStories {
            print("DEBUG:📸 Feed contiene: \(userGroup.userName) (ID: \(userGroup.userId)), stories: \(userGroup.stories.count)")
        }

        if let myStoryGroup = storyService.feedStories.first(where: { $0.userId == currentUserIdInt }) {
            print("DEBUG:✅ Encontradas mis stories! Total: \(myStoryGroup.stories.count)")
            let currentIds = storyService.myStories.map { $0.id }
            let newIds = myStoryGroup.stories.map { $0.id }
            if currentIds != newIds {
                storyService.myStories = myStoryGroup.stories
                print("DEBUG:💾 myStories actualizado con \(myStoryGroup.stories.count) stories")
            } else {
                print("DEBUG:✓ myStories ya está actualizado")
            }
        } else {
            print("DEBUG:⚠️ NO se encontraron mis stories en el feed")
            if !storyService.myStories.isEmpty {
                print("DEBUG:🗑️ Limpiando myStories porque no están en el feed")
                storyService.myStories = []
            }
        }

        print("DEBUG:📊 Estado final - myStories count: \(storyService.myStories.count)")
    }

    private var hasMyActiveStory: Bool {
        let hasActive = !storyService.myStories.filter { $0.isActive }.isEmpty
        print("DEBUG:🎯 hasMyActiveStory = \(hasActive), myStories count: \(storyService.myStories.count)")
        return hasActive
    }

    private func createMyUserStory() -> UserStoryGroup? {
        print("DEBUG:🎬 createMyUserStory() llamado")
        print("DEBUG:   - currentUser: \(authService.user?.name ?? "nil")")
        print("DEBUG:   - userProfile: \(userProfileService.userProfile?.id ?? 0)")
        print("DEBUG:   - myStories.isEmpty: \(storyService.myStories.isEmpty)")

        guard let currentUser = authService.user,
              let userProfile = userProfileService.userProfile,
              !storyService.myStories.isEmpty else {
            print("DEBUG:❌ createMyUserStory - No se puede crear (faltan datos)")
            return nil
        }

        let userStory = UserStoryGroup(
            userId: userProfile.id,
            userName: currentUser.name,
            userAvatar: currentUser.picture,
            hasUnseen: false,
            stories: storyService.myStories
        )

        print("DEBUG:✅ createMyUserStory - Creado con \(storyService.myStories.count) stories")
        return userStory
    }
}

// MARK: - Instagram Style My Story Button
struct InstagramMyStoryButton: View {
    let hasActiveStory: Bool
    let onTap: () -> Void
    let onAdd: () -> Void
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var storyUIState: StoryUIState

    @State private var isPressed = false
    @State private var isPulsing = false

    private var activeStoriesCount: Int {
        storyService.myStories.filter { $0.isActive }.count
    }

    private var ownUnseenCount: Int {
        storyService.myStories.filter { $0.isActive && !$0.hasViewed }.count
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                // Story ring: gradient if there are unseen own stories; white if viewed
                if hasActiveStory {
                    if ownUnseenCount > 0 {
                        Circle()
                            .strokeBorder(
                                StoryDesignTokens.instagramUnseenGradient,
                                lineWidth: StoryDesignTokens.ringWidth
                            )
                            .frame(
                                width: StoryDesignTokens.avatarRingSize,
                                height: StoryDesignTokens.avatarRingSize
                            )
                            .scaleEffect(isPulsing ? 1.05 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                value: isPulsing
                            )
                            .onAppear { isPulsing = true }
                    } else {
                        Circle()
                            .stroke(StoryDesignTokens.seenRingColor, lineWidth: 2)
                            .frame(
                                width: StoryDesignTokens.avatarRingSize,
                                height: StoryDesignTokens.avatarRingSize
                            )
                    }
                }

                // Avatar con padding interno (usando sistema robusto de HomeView)
                Group {
                    if let urlString = resolvedAvatarURL(authService: authService),
                       !urlString.isEmpty,
                       let user = authService.user {
                        let normalizedId = user.id
                            .replacingOccurrences(of: "user_", with: "")
                            .replacingOccurrences(of: "auth0|", with: "")

                        CustomImageView(
                            url: urlString,
                            cacheKey: "avatar_self_\(normalizedId)",
                            size: CGFloat(StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory))
                        ) {
                            AnyView(
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(
                                        width: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory),
                                        height: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory)
                                    )
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                    )
                            )
                        }
                        .frame(
                            width: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory),
                            height: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory)
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.dynamicBackground(theme: themeManager.currentTheme),
                                    lineWidth: hasActiveStory ? 3 : 0
                                )
                        )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(
                                width: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory),
                                height: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory)
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(
                    width: StoryDesignTokens.avatarRingSize,
                    height: StoryDesignTokens.avatarRingSize
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                storyUIState.myAvatarFrame = geo.frame(in: .global)
                            }
                    }
                )

                // Botón + azul Instagram (siempre visible para permitir añadir nuevas historias)
                Button(action: onAdd) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: StoryDesignTokens.addButtonSize, height: StoryDesignTokens.addButtonSize)
                        .overlay(
                            Circle()
                                .fill(StoryDesignTokens.instagramBlue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: 2, y: 2)
                }

                // Sin badge numérico para mantener estilo minimalista
            }

            Text("Tu historia")
                .font(StoryDesignTokens.usernameFont)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1)
                .frame(width: StoryDesignTokens.avatarRingSize - 10)
        }
        .frame(width: StoryDesignTokens.avatarRingSize)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(StoryAnimations.tapScale, value: isPressed)
        .onTapGesture {
            withAnimation(StoryAnimations.tapScale) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(StoryAnimations.tapScale) {
                    isPressed = false
                }
                onTap()
            }
        }
    }
}

// MARK: - Instagram Style Story Avatar
struct InstagramStoryAvatar: View {
    let userStory: UserStoryGroup
    let theme: ThemeManager.AppTheme
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Gradiente Instagram para historias no vistas con animación
                if userStory.hasUnseen {
                    Circle()
                        .strokeBorder(
                            StoryDesignTokens.instagramUnseenGradient,
                            lineWidth: StoryDesignTokens.ringWidth
                        )
                        .frame(
                            width: StoryDesignTokens.avatarRingSize,
                            height: StoryDesignTokens.avatarRingSize
                        )
                        .scaleEffect(isPulsing ? 1.03 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                        .onAppear {
                            isPulsing = true
                        }
                } else {
                    // Historias vistas - borde gris sutil
                    Circle()
                        .stroke(StoryDesignTokens.seenRingColor, lineWidth: 2)
                        .frame(
                            width: StoryDesignTokens.avatarRingSize,
                            height: StoryDesignTokens.avatarRingSize
                        )
                }

                // Avatar adaptado completamente al círculo (usando sistema mejorado)
                Group {
                    if let avatarUrlString = resolvedUserAvatarURL(userStory: userStory),
                       !avatarUrlString.isEmpty {
                        CustomImageView(
                            url: avatarUrlString,
                            cacheKey: "avatar_user_\(userStory.userId)",
                            size: CGFloat(StoryDesignTokens.avatarImageSize)
                        ) {
                            AnyView(
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(
                                        width: StoryDesignTokens.avatarImageSize,
                                        height: StoryDesignTokens.avatarImageSize
                                    )
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                    )
                            )
                        }
                        .frame(
                            width: StoryDesignTokens.avatarImageSize,
                            height: StoryDesignTokens.avatarImageSize
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.dynamicBackground(theme: theme),
                                    lineWidth: userStory.hasUnseen ? 3 : 0
                                )
                        )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(
                                width: StoryDesignTokens.avatarImageSize,
                                height: StoryDesignTokens.avatarImageSize
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(
                    width: StoryDesignTokens.avatarRingSize,
                    height: StoryDesignTokens.avatarRingSize
                )

                // Sin badge numérico para mantener estilo minimalista
            }

            // Username
            Text(userStory.userName)
                .font(StoryDesignTokens.usernameFont)
                .foregroundColor(Color.dynamicText(theme: theme))
                .fontWeight(userStory.hasUnseen ? .semibold : .regular)
                .lineLimit(1)
                .frame(width: StoryDesignTokens.avatarRingSize - 10)
        }
        .frame(width: StoryDesignTokens.avatarRingSize)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(StoryAnimations.tapScale, value: isPressed)
        .onTapGesture {
            print("DEBUG: 🎯 InstagramStoryAvatar tap detected!")
            withAnimation(StoryAnimations.tapScale) {
                isPressed = true
            }
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(StoryAnimations.tapScale) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Preview
struct InstagramStoriesBar_Previews: PreviewProvider {
    static var previews: some View {
        InstagramStoriesBar()
            .environmentObject(StoryService())
            .environmentObject(AuthServiceDirect())
            .environmentObject(ThemeManager())
            .environmentObject(UserProfileService.shared)
    }
}

// MARK: - Helpers
private struct EnableSnappingIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}

private struct EnableViewAlignedBehaviorIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollTargetBehavior(.viewAligned)
        } else {
            content
        }
    }
}

// MARK: - Helper Functions

/// Resuelve la URL del avatar del usuario autenticado
/// - Returns: URL del avatar o nil si no está disponible
@MainActor
private func resolvedAvatarURL(authService: AuthServiceDirect) -> String? {
    guard let user = authService.user else { return nil }

    // Intentar obtener de user.picture
    if let picture = user.picture, !picture.isEmpty {
        return picture
    }

    // Generar avatar con UI Avatars como fallback
    let encodedName = user.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "User"
    let normalizedId = user.id
        .replacingOccurrences(of: "user_", with: "")
        .replacingOccurrences(of: "auth0|", with: "")

    let colorHash = abs(normalizedId.hashValue) % 16777215
    let backgroundColor = String(format: "%06X", colorHash)

    return "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=\(backgroundColor)&color=fff&format=png"
}

/// Resuelve la URL del avatar de un UserStoryGroup
/// - Returns: URL del avatar o avatar generado
private func resolvedUserAvatarURL(userStory: UserStoryGroup) -> String? {
    // Intentar usar el avatar existente
    if let avatar = userStory.userAvatar, !avatar.isEmpty {
        return avatar
    }

    // Generar avatar con UI Avatars como fallback
    let encodedName = userStory.userName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "User"
    let colorHash = abs(userStory.userId.hashValue) % 16777215
    let backgroundColor = String(format: "%06X", colorHash)

    return "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=\(backgroundColor)&color=fff&format=png"
}
