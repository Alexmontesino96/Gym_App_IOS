//
//  StoryViewerContainer.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI
import Combine

struct StoryViewerContainer: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @Environment(\.dismiss) var dismiss

    let userStories: [UserStoryGroup]
    let initialUserIndex: Int

    @State private var currentUserIndex: Int
    @State private var currentStoryIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var showingReactionPicker = false
    @State private var contentOpacity: Double = 1.0
    @State private var showingViewersSheet = false
    @State private var viewersStoryId: Int?

    private let storyDuration: TimeInterval = 5.0 // 5 seconds per story

    init(userStories: [UserStoryGroup], initialUserIndex: Int) {
        self.userStories = userStories
        self.initialUserIndex = initialUserIndex
        self._currentUserIndex = State(initialValue: initialUserIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Story Content
                if let currentUser = currentUserStory,
                   let currentStory = currentStory {
                    StoryContentView(story: currentStory)
                        .ignoresSafeArea()
                        .opacity(contentOpacity)

                    // Overlay UI
                    VStack(spacing: 0) {
                        // Top section with progress bars and user info
                        VStack(spacing: 8) {
                            // Progress bars
                            StoryProgressBars(
                                stories: currentUser.activeStories,
                                currentIndex: currentStoryIndex,
                                progress: progress
                            )
                            .padding(.horizontal, 8)
                            .padding(.top, 8)

                            // User header
                            StoryHeaderView(
                                userStory: currentUser,
                                story: currentStory,
                                canShowViewers: isOwnStory(userGroup: currentUser, story: currentStory),
                                onClose: { dismiss() },
                                onViewersTap: {
                                    viewersStoryId = currentStory.id
                                    showingViewersSheet = true
                                }
                            )
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.7), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Spacer()

                        // Bottom area handled via overlay pinned to bottom
                    }
                }

                // Tap areas for navigation
                HStack(spacing: 0) {
                    // Previous story tap area
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            previousStory()
                        }
                        .frame(width: geometry.size.width * 0.3)

                    Spacer()

                    // Next story tap area
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            nextStory()
                        }
                        .frame(width: geometry.size.width * 0.3)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if abs(value.translation.width) > 50 || abs(value.translation.height) > 50 {
                            pauseStory()
                        }
                    }
                    .onEnded { value in
                        // Swipe down to dismiss
                        if value.translation.height > 150 {
                            dismiss()
                        }
                        // Swipe left/right to change user
                        else if value.translation.width > 100 {
                            previousUser()
                        } else if value.translation.width < -100 {
                            nextUser()
                        }
                        resumeStory()
                    }
            )
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                if pressing {
                    pauseStory()
                    withAnimation(.easeOut(duration: 0.15)) {
                        contentOpacity = 0.7
                    }
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } else {
                    resumeStory()
                    withAnimation(.easeIn(duration: 0.15)) {
                        contentOpacity = 1.0
                    }
                }
            }, perform: {})
            // Bottom overlay: caption (if any) + Instagram-style bottom bar pinned to bottom
            .overlay(alignment: .bottom) {
                if let currentUser = currentUserStory, let s = currentStory {
                    VStack(spacing: 10) {
                        if let caption = s.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                )
                        }

                        // Only show reply bar if it's NOT own story
                        if !(s.isOwnStory ?? false) {
                            InstagramStoryBottomBar(
                                story: s,
                                onSendMessage: { message in
                                    // TODO: Wire to backend direct message or chat
                                    print("DEBUG: Send story message -> id: \(s.id), text: \(message)")
                                },
                                onReact: { emoji in
                                    Task { await storyService.addReaction(storyId: s.id, emoji: emoji) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                }
            }
            .onAppear {
                print("DEBUG: 🎥 StoryViewerContainer onAppear")
                print("DEBUG: 📊 userStories count: \(userStories.count)")
                print("DEBUG: 📊 currentUserIndex: \(currentUserIndex)")
                print("DEBUG: 📊 currentStoryIndex: \(currentStoryIndex)")
                if let user = currentUserStory {
                    print("DEBUG: 👤 Current user: \(user.userName)")
                    print("DEBUG: 📊 User stories count: \(user.stories.count)")
                    print("DEBUG: 📊 User activeStories count: \(user.activeStories.count)")

                    // Log all stories in detail
                    for (index, story) in user.stories.enumerated() {
                        print("DEBUG: 📸 Story[\(index)] - ID: \(story.id), Active: \(story.isActive), Type: \(story.storyType)")
                    }
                } else {
                    print("DEBUG: ❌ currentUserStory is NIL!")
                }

                if let story = currentStory {
                    print("DEBUG: 📸 Current story ID: \(story.id)")
                    print("DEBUG: 📸 Story type: \(story.storyType)")
                    print("DEBUG: 📸 Media URL: \(story.mediaUrl ?? "nil")")
                } else {
                    print("DEBUG: ❌ currentStory is NIL!")
                }

                startStoryTimer()
                markCurrentStoryAsViewed()
                preloadNextStories()
            }
            .onDisappear {
                stopTimer()
            }
            .sheet(isPresented: $showingViewersSheet) {
                if let storyId = viewersStoryId {
                    StoryViewersListView(storyId: storyId)
                        .environmentObject(storyService)
                        .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var currentUserStory: UserStoryGroup? {
        guard currentUserIndex < userStories.count else { return nil }
        return userStories[currentUserIndex]
    }

    private var currentStory: Story? {
        guard let user = currentUserStory,
              currentStoryIndex < user.activeStories.count else { return nil }
        return user.activeStories[currentStoryIndex]
    }

    // MARK: - Navigation Methods
    private func nextStory() {
        guard let user = currentUserStory else { return }

        if currentStoryIndex < user.activeStories.count - 1 {
            currentStoryIndex += 1
            resetProgress()
            markCurrentStoryAsViewed()
            preloadNextStories()
        } else {
            nextUser()
        }
    }

    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            resetProgress()
            markCurrentStoryAsViewed()
            preloadNextStories()
        } else {
            previousUser()
        }
    }

    private func nextUser() {
        if currentUserIndex < userStories.count - 1 {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            currentUserIndex += 1
            currentStoryIndex = 0
            resetProgress()
            markCurrentStoryAsViewed()
            preloadNextStories()
        } else {
            dismiss()
        }
    }

    private func previousUser() {
        if currentUserIndex > 0 {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            currentUserIndex -= 1
            currentStoryIndex = 0
            resetProgress()
            markCurrentStoryAsViewed()
            preloadNextStories()
        }
    }

    // MARK: - Timer Management
    private func startStoryTimer() {
        stopTimer()
        progress = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !isPaused {
                let increment = CGFloat(0.05 / storyDuration)

                withAnimation(.linear(duration: 0.05)) {
                    progress = min(progress + increment, 1.0)
                }

                // Check if we've reached the end
                if progress >= 0.99 {
                    stopTimer()
                    nextStory()
                }
            }
        }
    }

    private func resetProgress() {
        stopTimer()
        progress = 0
        startStoryTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func pauseStory() {
        isPaused = true
    }

    private func resumeStory() {
        isPaused = false
    }

    // MARK: - Story Tracking
    private func markCurrentStoryAsViewed() {
        guard let story = currentStory, !story.hasViewed else { return }

        Task {
            await storyService.markAsViewed(
                storyId: story.id,
                duration: Int(storyDuration)
            )
        }
    }

    // MARK: - Preloading
    private func preloadNextStories() {
        var urlsToPreload: [String] = []

        // Preload next story in current user's stories
        if let user = currentUserStory,
           currentStoryIndex + 1 < user.activeStories.count {
            let nextStory = user.activeStories[currentStoryIndex + 1]
            if nextStory.storyType == .image, let url = nextStory.mediaUrl {
                urlsToPreload.append(url)
            }
        }

        // Preload first story of next user
        if currentUserIndex + 1 < userStories.count {
            let nextUser = userStories[currentUserIndex + 1]
            if let firstStory = nextUser.activeStories.first,
               firstStory.storyType == .image,
               let url = firstStory.mediaUrl {
                urlsToPreload.append(url)
            }
        }

        // Preload avatar of next user
        if currentUserIndex + 1 < userStories.count {
            let nextUser = userStories[currentUserIndex + 1]
            if let avatarUrl = nextUser.userAvatar, !avatarUrl.isEmpty {
                urlsToPreload.append(avatarUrl)
            }
        }

        if !urlsToPreload.isEmpty {
            print("DEBUG: 🔄 Preloading \(urlsToPreload.count) images for next stories")
            ImageCacheManager.shared.preloadImages(urlsToPreload)
        }
    }
}

// MARK: - Ownership helper
extension StoryViewerContainer {
    fileprivate func isOwnStory(userGroup: UserStoryGroup, story: Story) -> Bool {
        if let own = story.isOwnStory { return own }
        if storyService.myStories.contains(where: { $0.id == story.id }) { return true }
        if let userIdStr = authService.user?.id, let userId = Int(userIdStr) {
            return userGroup.userId == userId
        }
        return false
    }
}

// MARK: - Story Content View
struct StoryContentView: View {
    let story: Story

    var body: some View {
        GeometryReader { proxy in
        ZStack {
            switch story.storyType {
            case .image:
                if let mediaUrl = story.mediaUrl, !mediaUrl.isEmpty {
                    StoryImageWithError(url: mediaUrl)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .onAppear {
                            print("DEBUG: 🖼️ Loading story image: \(mediaUrl.suffix(50))")
                        }
                } else {
                    Color.gray
                        .overlay(
                            VStack {
                                Image(systemName: "photo.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                Text("URL de imagen no disponible")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        )
                        .onAppear {
                            print("DEBUG: ❌ No media URL for story ID: \(story.id)")
                        }
                }

            case .video:
                // TODO: Implement video player
                Color.gray
                    .overlay(
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("Video support coming soon")
                                .foregroundColor(.white)
                        }
                    )

            case .text:
                LinearGradient(
                    colors: [Color(hex: "D93333") ?? Color.red, Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text(story.caption ?? "")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(40)
                )

            case .workout:
                WorkoutStoryView(workoutData: story.workoutData)

            case .achievement:
                AchievementStoryView(story: story)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
        .contentShape(Rectangle())
        }
    }
}

// MARK: - Story Header View
struct StoryHeaderView: View {
    let userStory: UserStoryGroup
    let story: Story
    let canShowViewers: Bool
    let onClose: () -> Void
    var onViewersTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            if let avatarUrl = userStory.userAvatar, !avatarUrl.isEmpty {
                CachedAsyncImage(url: avatarUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 32, height: 32)
                }
            }

            // User name and time
            VStack(alignment: .leading, spacing: 2) {
                Text(userStory.userName)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(story.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Story info
            if canShowViewers {
                Button(action: { onViewersTap?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                        Text(story.formattedViewCount)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .accessibilityLabel("Visto por \(story.viewCount) personas. Tocar para ver la lista de espectadores")
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
    }
}

// MARK: - Preview
struct StoryViewerContainer_Previews: PreviewProvider {
    static var previews: some View {
        StoryViewerContainer(
            userStories: [],
            initialUserIndex: 0
        )
        .environmentObject(StoryService())
        .environmentObject(ThemeManager())
    }
}
