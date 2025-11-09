//
//  InstagramStoriesBar.swift
//  Gym_API
//
//  Instagram-style Stories Bar implementation
//  Enhanced with Stream Figma design tokens and smooth animations
//

import SwiftUI

struct InstagramStoriesBar: View {
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
                            StoryHaptics.avatarTap()

                            if hasMyActiveStory {
                                print("DEBUG:👤 Stories: Abriendo mis stories")
                                showingMyStories = true
                            } else {
                                print("DEBUG:➕ Stories: Abriendo creador")
                                showingStoryCreator = true
                            }
                        }
                    )

                    // Otras historias con animación de entrada escalonada
                    // Filtrar para excluir al usuario actual
                    ForEach(Array(otherUsersStories.enumerated()), id: \.element.id) { index, userStory in
                        InstagramStoryAvatar(
                            userStory: userStory,
                            theme: themeManager.currentTheme,
                            onTap: {
                                print("DEBUG: 👆 Story avatar tapped - User: \(userStory.userName), Index: \(index)")
                                print("DEBUG: 📊 Total stories: \(userStory.stories.count)")
                                print("DEBUG: 📊 Active stories: \(userStory.activeStories.count)")
                                print("DEBUG: 📊 Feed stories count: \(otherUsersStories.count)")

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
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            StoryAnimations.storyEntry.delay(Double(index) * 0.05),
                            value: otherUsersStories.count
                        )
                    }
                }
                .padding(.horizontal, StoryDesignTokens.barHorizontalPadding)
                .padding(.vertical, 10)
            }
            .frame(height: StoryDesignTokens.barHeight)
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
            loadStoriesIfNeeded()
        }
        .refreshable {
            print("DEBUG:🔄 Stories: Actualizando feed")
            await refreshStories()
        }
        .fullScreenCover(isPresented: $showingStoryViewer) {
            Group {
                if !otherUsersStories.isEmpty {
                    StoryViewerContainer(
                        userStories: otherUsersStories,
                        initialUserIndex: selectedUserIndex
                    )
                    .environmentObject(storyService)
                    .environmentObject(themeManager)
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
            }
        }
        .sheet(isPresented: $showingStoryCreator) {
            StoryCreatorView()
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
    }

    // MARK: - Helper Methods

    // Filtrar historias para excluir al usuario actual
    private var otherUsersStories: [UserStoryGroup] {
        guard let currentUserIdInt = userProfileService.userProfile?.id else {
            print("DEBUG:⚠️ No se pudo obtener el ID del usuario actual del UserProfile")
            print("DEBUG:⚠️ userProfile: \(userProfileService.userProfile?.email ?? "nil")")
            return storyService.feedStories
        }

        print("DEBUG:🔍 Filtrando historias - Usuario actual ID: \(currentUserIdInt)")
        print("DEBUG:🔍 Feed total: \(storyService.feedStories.count) grupos de historias")

        // PRIMERO: Extraer historias del usuario actual y guardarlas en myStories
        if let myStoryGroup = storyService.feedStories.first(where: { $0.userId == currentUserIdInt }) {
            print("DEBUG:✅ Encontradas historias del usuario actual: \(myStoryGroup.stories.count) historias")
            // Actualizar myStories en el servicio de manera sincrónica
            // Comparar por IDs para evitar actualizaciones innecesarias
            let currentIds = storyService.myStories.map { $0.id }
            let newIds = myStoryGroup.stories.map { $0.id }
            if currentIds != newIds {
                print("DEBUG:🔄 Actualizando myStories con nuevas historias")
                storyService.myStories = myStoryGroup.stories
            }
        } else {
            print("DEBUG:⚠️ No se encontraron historias del usuario actual en el feed")
            // Limpiar myStories si no hay historias del usuario
            if !storyService.myStories.isEmpty {
                print("DEBUG:🧹 Limpiando myStories vacías")
                storyService.myStories = []
            }
        }

        // Log de todos los IDs en el feed
        for (index, userStory) in storyService.feedStories.enumerated() {
            print("DEBUG:🔍 Feed[\(index)] - UserID: \(userStory.userId), Nombre: \(userStory.userName)")
        }

        // SEGUNDO: Filtrar para remover al usuario actual del feed
        let filtered = storyService.feedStories.filter { userStory in
            let shouldKeep = userStory.userId != currentUserIdInt
            print("DEBUG:🔍 UserID \(userStory.userId) vs CurrentUserID \(currentUserIdInt) - Mantener: \(shouldKeep)")
            return shouldKeep
        }

        print("DEBUG:✅ Historias filtradas: \(filtered.count) grupos")
        return filtered
    }

    private func loadStoriesIfNeeded() {
        print("DEBUG:📸 Stories: loadStoriesIfNeeded called")
        print("DEBUG:📊 feedStories.isEmpty: \(storyService.feedStories.isEmpty)")
        guard storyService.feedStories.isEmpty else {
            print("DEBUG:✅ Stories already loaded, skipping")
            return
        }
        print("DEBUG:📸 Stories: Cargando feed inicial")
        isLoading = true
        Task {
            await storyService.fetchStoriesFeed()
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
        StoryHaptics.reactionSent()
    }

    private var hasMyActiveStory: Bool {
        !storyService.myStories.filter { $0.isActive }.isEmpty
    }

    private func createMyUserStory() -> UserStoryGroup? {
        guard let currentUser = authService.user,
              let userProfile = userProfileService.userProfile,
              !storyService.myStories.isEmpty else { return nil }

        return UserStoryGroup(
            userId: userProfile.id,
            userName: currentUser.name,
            userAvatar: currentUser.picture,
            hasUnseen: false,
            stories: storyService.myStories
        )
    }
}

// MARK: - Instagram Style My Story Button
struct InstagramMyStoryButton: View {
    let hasActiveStory: Bool
    let onTap: () -> Void
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storyService: StoryService

    @State private var isPressed = false
    @State private var isPulsing = false

    private var activeStoriesCount: Int {
        storyService.myStories.filter { $0.isActive }.count
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                // Story ring si tiene historia activa
                if hasActiveStory {
                    // Gradiente Instagram para historias activas con pulso
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
                        .onAppear {
                            isPulsing = true
                        }
                }

                // Avatar con padding interno
                Group {
                    if let imageUrl = authService.user?.picture,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
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
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(
                                    width: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory),
                                    height: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory)
                                )
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(
                                width: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory),
                                height: StoryDesignTokens.innerAvatarSize(hasRing: hasActiveStory)
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(
                    width: StoryDesignTokens.avatarRingSize,
                    height: StoryDesignTokens.avatarRingSize
                )

                // Botón + azul Instagram (solo si no tiene historia)
                if !hasActiveStory {
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

                // Badge para múltiples stories (solo si tiene más de 1 historia activa)
                if activeStoriesCount > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(activeStoriesCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 64, height: 64)
                }
            }

            Text("Tu historia")
                .font(StoryDesignTokens.usernameFont)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1)
        }
        .frame(width: 72)
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
                            width: StoryDesignTokens.avatarRingSize - 4,
                            height: StoryDesignTokens.avatarRingSize - 4
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
                        .stroke(StoryDesignTokens.seenRingColor, lineWidth: 1)
                        .frame(
                            width: StoryDesignTokens.avatarRingSize - 4,
                            height: StoryDesignTokens.avatarRingSize - 4
                        )
                }

                // Avatar con padding interno
                Group {
                    if let avatarUrl = userStory.userAvatar,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.dynamicBackground(theme: theme),
                                            lineWidth: userStory.hasUnseen ? 3 : 0
                                        )
                                )
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(
                    width: StoryDesignTokens.avatarRingSize - 4,
                    height: StoryDesignTokens.avatarRingSize - 4
                )

                // Badge para múltiples stories
                if userStory.activeStories.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(userStory.activeStories.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 64, height: 64)
                }
            }

            // Username
            Text(userStory.userName)
                .font(StoryDesignTokens.usernameFont)
                .foregroundColor(Color.dynamicText(theme: theme))
                .fontWeight(userStory.hasUnseen ? .semibold : .regular)
                .lineLimit(1)
                .frame(width: 64)
        }
        .frame(width: 72)
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