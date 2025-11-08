//
//  InstagramStoriesBar.swift
//  Gym_API
//
//  Instagram-style Stories Bar implementation
//

import SwiftUI

struct InstagramStoriesBar: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingStoryViewer = false
    @State private var showingStoryCreator = false
    @State private var selectedUserIndex = 0
    @State private var showingMyStories = false

    var body: some View {
        VStack(spacing: 0) {
            // Instagram-style fixed header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // "Tu historia" - Instagram style
                    InstagramMyStoryButton(
                        hasActiveStory: hasMyActiveStory,
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()

                            if hasMyActiveStory {
                                print("DEBUG:👤 Stories: Abriendo mis stories")
                                showingMyStories = true
                            } else {
                                print("DEBUG:➕ Stories: Abriendo creador")
                                showingStoryCreator = true
                            }
                        }
                    )

                    // Otras historias
                    ForEach(Array(storyService.feedStories.enumerated()), id: \.element.id) { index, userStory in
                        InstagramStoryAvatar(
                            userStory: userStory,
                            theme: themeManager.currentTheme
                        )
                        .onTapGesture {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            selectedUserIndex = index
                            showingStoryViewer = true
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .frame(height: 98)
            .background(
                Color.dynamicBackground(theme: themeManager.currentTheme)
            )

            // Línea divisora sutil como Instagram
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
        .onAppear {
            print("DEBUG:📸 Stories: Cargando feed")
            Task {
                await storyService.fetchStoriesFeed()
            }
        }
        .fullScreenCover(isPresented: $showingStoryViewer) {
            if !storyService.feedStories.isEmpty {
                StoryViewerContainer(
                    userStories: storyService.feedStories,
                    initialUserIndex: selectedUserIndex
                )
                .environmentObject(storyService)
                .environmentObject(themeManager)
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

    private var hasMyActiveStory: Bool {
        !storyService.myStories.filter { $0.isActive }.isEmpty
    }

    private func createMyUserStory() -> UserStoryGroup? {
        guard let currentUser = authService.user,
              !storyService.myStories.isEmpty else { return nil }

        return UserStoryGroup(
            userId: Int(currentUser.id) ?? 0,
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

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                // Story ring si tiene historia activa
                if hasActiveStory {
                    // Gradiente Instagram para historias activas
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 193/255, green: 53/255, blue: 132/255),
                                    Color(red: 253/255, green: 29/255, blue: 29/255),
                                    Color(red: 252/255, green: 176/255, blue: 69/255)
                                ]),
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 66, height: 66)
                }

                // Avatar con padding interno
                Group {
                    if let imageUrl = authService.user?.picture,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: hasActiveStory ? 58 : 62, height: hasActiveStory ? 58 : 62)
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
                                .frame(width: hasActiveStory ? 58 : 62, height: hasActiveStory ? 58 : 62)
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: hasActiveStory ? 58 : 62, height: hasActiveStory ? 58 : 62)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 66, height: 66)

                // Botón + azul Instagram (solo si no tiene historia)
                if !hasActiveStory {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .fill(Color(red: 0/255, green: 149/255, blue: 246/255))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        )
                        .offset(x: 2, y: 2)
                }
            }

            Text("Tu historia")
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1)
        }
        .frame(width: 72)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: .infinity,
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

// MARK: - Instagram Style Story Avatar
struct InstagramStoryAvatar: View {
    let userStory: UserStoryGroup
    let theme: ThemeManager.AppTheme
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Gradiente Instagram para historias no vistas
                if userStory.hasUnseen {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 193/255, green: 53/255, blue: 132/255),
                                    Color(red: 253/255, green: 29/255, blue: 29/255),
                                    Color(red: 252/255, green: 176/255, blue: 69/255)
                                ]),
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 64, height: 64)
                } else {
                    // Historias vistas - borde gris sutil
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 64, height: 64)
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
                .frame(width: 64, height: 64)
            }

            // Username
            Text(userStory.userName)
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(1)
                .frame(width: 64)
        }
        .frame(width: 72)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Preview
struct InstagramStoriesBar_Previews: PreviewProvider {
    static var previews: some View {
        InstagramStoriesBar()
            .environmentObject(StoryService())
            .environmentObject(AuthServiceDirect())
            .environmentObject(ThemeManager())
    }
}