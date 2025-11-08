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
    @Environment(\.dismiss) var dismiss

    let userStories: [UserStoryGroup]
    let initialUserIndex: Int

    @State private var currentUserIndex: Int
    @State private var currentStoryIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var isPaused = false
    @State private var dragOffset: CGSize = .zero
    @State private var timer: Timer?
    @State private var showingReactionPicker = false

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
                            .padding(.top, geometry.safeAreaInsets.top + 8)

                            // User header
                            StoryHeaderView(
                                userStory: currentUser,
                                story: currentStory,
                                onClose: { dismiss() }
                            )
                            .padding(.horizontal, 16)
                        }

                        Spacer()

                        // Bottom section with reactions
                        VStack(spacing: 16) {
                            // Caption if exists
                            if let caption = currentStory.caption, !caption.isEmpty {
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

                            // Reaction bar
                            StoryReactionBar(
                                story: currentStory,
                                onReaction: { emoji in
                                    Task {
                                        await storyService.addReaction(
                                            storyId: currentStory.id,
                                            emoji: emoji
                                        )
                                    }
                                },
                                onMessage: {
                                    // TODO: Implement message functionality
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
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
                        dragOffset = value.translation
                        if abs(value.translation.width) > 50 || abs(value.translation.height) > 50 {
                            pauseStory()
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            // Swipe down to dismiss
                            if value.translation.height > 100 {
                                dismiss()
                            }
                            // Swipe left/right to change user
                            else if value.translation.width > 100 {
                                previousUser()
                            } else if value.translation.width < -100 {
                                nextUser()
                            }

                            dragOffset = .zero
                        }
                        resumeStory()
                    }
            )
            .offset(dragOffset)
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                if pressing {
                    pauseStory()
                } else {
                    resumeStory()
                }
            }, perform: {})
            .onAppear {
                startStoryTimer()
                markCurrentStoryAsViewed()
            }
            .onDisappear {
                stopTimer()
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
        } else {
            nextUser()
        }
    }

    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            resetProgress()
            markCurrentStoryAsViewed()
        } else {
            previousUser()
        }
    }

    private func nextUser() {
        if currentUserIndex < userStories.count - 1 {
            currentUserIndex += 1
            currentStoryIndex = 0
            resetProgress()
            markCurrentStoryAsViewed()
        } else {
            dismiss()
        }
    }

    private func previousUser() {
        if currentUserIndex > 0 {
            currentUserIndex -= 1
            currentStoryIndex = 0
            resetProgress()
            markCurrentStoryAsViewed()
        }
    }

    // MARK: - Timer Management
    private func startStoryTimer() {
        stopTimer()
        progress = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !isPaused {
                withAnimation(.linear(duration: 0.05)) {
                    progress += CGFloat(0.05 / storyDuration)
                }

                if progress >= 1 {
                    nextStory()
                }
            }
        }
    }

    private func resetProgress() {
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
}

// MARK: - Story Content View
struct StoryContentView: View {
    let story: Story

    var body: some View {
        ZStack {
            switch story.storyType {
            case .image:
                if let mediaUrl = story.mediaUrl,
                   let url = URL(string: mediaUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
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
    }
}

// MARK: - Story Header View
struct StoryHeaderView: View {
    let userStory: UserStoryGroup
    let story: Story
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            if let avatarUrl = userStory.userAvatar,
               let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
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
            if story.isOwnStory {
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