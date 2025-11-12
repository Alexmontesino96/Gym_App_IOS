//
//  StoriesBar.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI

struct StoriesBar: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingStoryViewer = false
    @State private var showingStoryCreator = false
    @State private var selectedUserIndex = 0
    @State private var showingMyStories = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // My Story / Add Story Button
                MyStoryButton(
                    hasActiveStory: hasMyActiveStory,
                    onTap: {
                        print("DEBUG:🔵 MyStoryButton tapped!")
                        print("DEBUG:🔵 hasMyActiveStory: \(hasMyActiveStory)")
                        print("DEBUG:🔵 Current showingStoryCreator state: \(showingStoryCreator)")

                        if hasMyActiveStory {
                            print("DEBUG:👤 StoriesBar: Abriendo mis stories activas")
                            showingMyStories = true
                        } else {
                            print("DEBUG:➕ StoriesBar: Abriendo creador de stories")
                            showingStoryCreator = true
                            print("DEBUG:➕ showingStoryCreator set to: \(showingStoryCreator)")
                        }
                    }
                )

                // Divider
                if !storyService.feedStories.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 50)
                }

                // Other Users' Stories
                ForEach(Array(storyService.feedStories.enumerated()), id: \.element.id) { index, userStory in
                    StoryAvatar(
                        userStory: userStory,
                        theme: themeManager.currentTheme
                    )
                    .onTapGesture {
                        selectedUserIndex = index
                        showingStoryViewer = true
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 100)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.5))
        .onAppear {
            print("DEBUG:📸 StoriesBar: Vista apareció, obteniendo feed")
            Task {
                await storyService.fetchStoriesFeed()
            }
        }
        .refreshable {
            print("DEBUG:🔄 StoriesBar: Actualizando feed de stories")
            await storyService.fetchStoriesFeed(forceRefresh: true)
        }
        .fullScreenCover(isPresented: $showingStoryViewer) {
            if !storyService.feedStories.isEmpty {
                StoryViewerContainer(
                    userStories: storyService.feedStories,
                    initialUserIndex: selectedUserIndex
                )
                .environmentObject(storyService)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .presentationBackground(.clear)
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
                .presentationBackground(.clear)
            }
        }
        .fullScreenCover(isPresented: $showingStoryCreator) {
            StoryCreatorView()
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
                .onAppear {
                    print("DEBUG:🎬 StoryCreatorView appeared!")
                }
        }
    }

    private var hasMyActiveStory: Bool {
        !storyService.myStories.filter { $0.isActive }.isEmpty
    }

    private func createMyUserStory() -> UserStoryGroup? {
        guard let currentUser = authService.user,
              !storyService.myStories.isEmpty else { return nil }

        return UserStoryGroup(
            userId: Int(currentUser.id) ?? 0,  // Convert string ID to Int
            userName: currentUser.name,
            userAvatar: currentUser.picture,
            hasUnseen: false,
            stories: storyService.myStories
        )
    }
}

// MARK: - My Story Button Component
struct MyStoryButton: View {
    let hasActiveStory: Bool
    let onTap: () -> Void
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Border ring
                if hasActiveStory {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D93333") ?? Color.red, Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 68, height: 68)
                } else {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .foregroundColor(.gray.opacity(0.5))
                        .frame(width: 68, height: 68)
                }

                // Avatar or Add Icon
                ZStack {
                    if let imageUrl = authService.user?.picture,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            )
                    }

                    // Add button overlay
                    if !hasActiveStory {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .frame(width: 60, height: 60)
                    }
                }
            }

            Text(hasActiveStory ? "Tu Historia" : "Agregar")
                .font(.caption)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .frame(width: 72)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Story Avatar Component
struct StoryAvatar: View {
    let userStory: UserStoryGroup
    let theme: ThemeManager.AppTheme

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Gradient ring for unseen stories
                if userStory.hasUnseen {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D93333") ?? Color.red, Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 68, height: 68)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 68, height: 68)
                }

                // Avatar
                if let avatarUrl = userStory.userAvatar,
                   let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                }

                // Removed numeric badge for multiple stories to keep UI minimal
            }

            // Username
            Text(userStory.userName)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(Color.dynamicText(theme: theme))
        }
        .frame(width: 72)
    }
}

// MARK: - Preview
struct StoriesBar_Previews: PreviewProvider {
    static var previews: some View {
        StoriesBar()
            .environmentObject(StoryService())
            .environmentObject(AuthServiceDirect())
            .environmentObject(ThemeManager())
    }
}
