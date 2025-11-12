//
//  StoryViewerView.swift
//  Gym_API
//
//  Full-screen Instagram-style story viewer with profile, controls and interactions
//  Validates against: Flutter story_page_for_mobile.dart (lines 1-350)
//

import SwiftUI

// MARK: - Story Viewer View (Main Container)
/// Full-screen story viewer that manages multiple user stories
/// Flutter equivalent: StoryPageForMobile (lines 18-70)
struct StoryViewerView: View {
    // MARK: - Properties
    /// Initial user whose stories to show
    let initialUser: UserStoryGroup

    /// All users with stories
    let storiesOwners: [UserStoryGroup]

    /// Dismiss callback
    let onDismiss: () -> Void

    /// Hero animation tag (optional)
    let heroTag: String?

    // MARK: - Environment
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - State
    @State private var currentUserIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    init(
        initialUser: UserStoryGroup,
        storiesOwners: [UserStoryGroup],
        heroTag: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.initialUser = initialUser
        self.storiesOwners = storiesOwners
        self.heroTag = heroTag
        self.onDismiss = onDismiss

        // Set initial index
        if let index = storiesOwners.firstIndex(where: { $0.id == initialUser.id }) {
            _currentUserIndex = State(initialValue: index)
        }
    }

    var body: some View {
        ZStack {
            Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

            // Story page view with swipe between users
            StoryPageView(
                storiesOwners: storiesOwners,
                currentIndex: $currentUserIndex,
                heroTag: heroTag,
                onComplete: {
                    // Move to next user or dismiss
                    if currentUserIndex < storiesOwners.count - 1 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            currentUserIndex += 1
                        }
                    } else {
                        onDismiss()
                    }
                },
                onDismiss: onDismiss
            )
        }
        .statusBar(hidden: true)
    }
}

// MARK: - Story Page View (Horizontal Swipe Container)
/// Container that allows swiping between different users' stories with cube transition
/// Flutter equivalent: StorySwipe widget (story_swipe.dart lines 6-56)
struct StoryPageView: View {
    let storiesOwners: [UserStoryGroup]
    @Binding var currentIndex: Int
    let heroTag: String?
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isHorizontalDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(storiesOwners.enumerated()), id: \.element.id) { index, userGroup in
                    SingleUserStoryView(
                        userGroup: userGroup,
                        heroTag: index == currentIndex ? heroTag : nil,
                        isHorizontalDragging: $isHorizontalDragging,
                        onComplete: {
                            // Auto-advance to next user
                            if index < storiesOwners.count - 1 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    currentIndex = index + 1
                                }
                            } else {
                                onDismiss()
                            }
                        },
                        onDismiss: onDismiss
                    )
                    .frame(width: geometry.size.width)
                    .rotation3DEffect(
                        .degrees(cubeRotation(for: index, width: geometry.size.width)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: anchorPoint(for: index),
                        perspective: 0.5
                    )
                }
            }
            .offset(x: totalOffset(width: geometry.size.width))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { value in
                        // Start horizontal drag when threshold is crossed
                        // Use DispatchQueue.main.async to avoid modifying state during view update
                        if !isHorizontalDragging && abs(value.translation.width) > 10 {
                            DispatchQueue.main.async {
                                isHorizontalDragging = true
                                print("🔄 Horizontal drag started - pausing stories")
                            }
                        }
                    }
                    .onEnded { value in
                        print("🔄 Horizontal drag ended - resuming stories")

                        let threshold: CGFloat = geometry.size.width * 0.25
                        var newIndex = currentIndex

                        if value.translation.width < -threshold && currentIndex < storiesOwners.count - 1 {
                            newIndex = currentIndex + 1
                        } else if value.translation.width > threshold && currentIndex > 0 {
                            newIndex = currentIndex - 1
                        }

                        withAnimation(.easeOut(duration: 0.3)) {
                            currentIndex = newIndex
                            isHorizontalDragging = false
                        }
                    }
            )
        }
    }

    // Calculate total offset including drag
    private func totalOffset(width: CGFloat) -> CGFloat {
        return -CGFloat(currentIndex) * width + dragOffset
    }

    // Calculate cube rotation angle for each page
    private func cubeRotation(for index: Int, width: CGFloat) -> Double {
        let pageOffset = (totalOffset(width: width) + CGFloat(index) * width) / width
        return Double(pageOffset * 90) // 90 degrees rotation
    }

    // Determine anchor point for rotation
    private func anchorPoint(for index: Int) -> UnitPoint {
        let pageOffset = totalOffset(width: UIScreen.main.bounds.width) + CGFloat(index) * UIScreen.main.bounds.width

        if pageOffset < 0 {
            return .trailing // Rotating out to the left
        } else if pageOffset > 0 {
            return .leading // Rotating in from the right
        } else {
            return .center // Current page
        }
    }
}

// MARK: - Single User Story View
/// Displays all stories from a single user
/// Flutter equivalent: StoryWidget (lines 72-285)
struct SingleUserStoryView: View {
    // MARK: - Properties
    let userGroup: UserStoryGroup
    let heroTag: String?
    @Binding var isHorizontalDragging: Bool
    let onComplete: () -> Void
    let onDismiss: () -> Void

    // MARK: - State
    @StateObject private var controller = StoryController()
    @State private var storyItems: [StoryItem] = []
    @State private var opacityLevel: Double = 1.0
    @State private var currentStory: Story?
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissing: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // Story viewer with gestures
            // Flutter equivalent: StoryView wrapper with gestures (lines 150-194)
            StoryView(
                storyItems: $storyItems,
                controller: controller,
                opacityLevel: $opacityLevel,
                isHorizontalDragging: $isHorizontalDragging,
                onComplete: onComplete,
                onVerticalDragChanged: { offset in
                    // Update offset during drag
                    dismissOffset = offset
                },
                onVerticalSwipeComplete: { direction in
                    if direction == .up || direction == .down {
                        print("✅ Dismiss completed - direction: \(direction)")
                        // Start dismiss animation
                        isDismissing = true
                        let targetOffset: CGFloat = direction == .down ? UIScreen.main.bounds.height : -UIScreen.main.bounds.height

                        withAnimation(.easeOut(duration: 0.2)) {
                            dismissOffset = targetOffset
                            opacityLevel = 0
                        }

                        // Call dismiss after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDismiss()
                        }
                    } else {
                        // Cancelled - reset offset
                        dismissOffset = 0
                    }
                },
                onStoryShow: { item in
                    currentStory = item.story
                },
                progressPosition: .top
            )
            .allowsHitTesting(!isHorizontalDragging && !isDismissing)  // Block gestures during horizontal drag or dismiss

            // Profile header overlay
            // Flutter equivalent: ProfileWidget (lines 196-206)
            if let story = currentStory {
                VStack(spacing: 0) {
                    StoryProfileHeader(
                        userGroup: userGroup,
                        story: story,
                        heroTag: heroTag
                    )
                    .opacity(opacityLevel)
                    .animation(.easeInOut(duration: 0.25), value: opacityLevel)

                    Spacer()

                    // Bottom interaction controls
                    StoryInteractionControls(
                        userGroup: userGroup,
                        controller: controller
                    )
                    .opacity(opacityLevel)
                    .animation(.easeInOut(duration: 0.25), value: opacityLevel)
                }
                .padding(.top, 50) // Space for progress bars
            }
        }
        .offset(y: dismissOffset)  // Apply offset to ENTIRE container including header
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dismissOffset)  // Smooth spring animation
        .allowsHitTesting(!isDismissing)  // Block all gestures during dismiss animation
        .onAppear {
            loadStoryItems()
        }
    }

    // MARK: - Helper Methods
    /// Load story items from user group
    /// Flutter equivalent: addStoryItems() (lines 99-114)
    private func loadStoryItems() {
        print("📸 DEBUG: Loading story items for user: \(userGroup.userName)")
        print("📸 DEBUG: Active stories count: \(userGroup.activeStories.count)")

        storyItems = userGroup.activeStories.map { story in
            print("📸 DEBUG: Creating StoryItem for story \(story.id) - Type: \(story.storyType)")
            return StoryItem.from(story: story)
        }

        print("📸 DEBUG: StoryItems created: \(storyItems.count)")

        // Set first story as current
        currentStory = userGroup.activeStories.first

        if let first = currentStory {
            print("📸 DEBUG: First story set - ID: \(first.id), Type: \(first.storyType)")
        } else {
            print("⚠️ DEBUG: No first story found!")
        }
    }
}

// MARK: - Story Profile Header
/// Profile information displayed at the top of story
/// Flutter equivalent: ProfileWidget (lines 287-349)
struct StoryProfileHeader: View {
    let userGroup: UserStoryGroup
    let story: Story
    let heroTag: String?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with optional Hero animation
            // Flutter equivalent: CircleAvatarOfProfileImage (lines 341-347)
            Group {
                if let tag = heroTag, !tag.isEmpty {
                    ProfileAvatarView(
                        avatarUrl: userGroup.userAvatar,
                        size: 40
                    )
                    .matchedGeometryEffect(id: tag, in: namespace)
                } else {
                    ProfileAvatarView(
                        avatarUrl: userGroup.userAvatar,
                        size: 40
                    )
                }
            }

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(userGroup.userName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                // Time ago
                // Flutter equivalent: DateReformat.oneDigitFormat (line 330)
                Text(story.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Close button
            Button(action: {
                // Dismiss would be handled by parent
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @Namespace private var namespace
}

// MARK: - Profile Avatar View
struct ProfileAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Story Interaction Controls
/// Bottom controls for story interaction (reply, like, share)
/// Flutter equivalent: Bottom controls section (lines 210-275)
struct StoryInteractionControls: View {
    let userGroup: UserStoryGroup
    @ObservedObject var controller: StoryController

    @State private var replyText: String = ""
    @FocusState private var isReplyFieldFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Reply input field
            // Flutter equivalent: TextFormField (lines 236-254)
            HStack(spacing: 8) {
                TextField("Send message", text: $replyText)
                    .focused($isReplyFieldFocused)
                    .foregroundColor(.white)
                    .tint(.teal)
                    .onTapGesture {
                        controller.pause()
                    }
                    .onChange(of: isReplyFieldFocused) { _, isFocused in
                        if !isFocused {
                            controller.play()
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(Color.white, lineWidth: 0.5)
            )

            // Like button
            // Flutter equivalent: loveIcon (lines 258-264)
            Button(action: {
                // Handle like
            }) {
                Image(systemName: "heart")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // Share/Send button
            // Flutter equivalent: send2Icon (lines 266-270)
            Button(action: {
                // Handle share
            }) {
                Image(systemName: "paperplane")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Previews
struct StoryViewerView_Previews: PreviewProvider {
    static var previews: some View {
        StoryViewerView(
            initialUser: UserStoryGroup(
                userId: 1,
                userName: "John Doe",
                userAvatar: nil,
                hasUnseen: true,
                stories: [
                    Story(
                        id: 1,
                        gymId: 1,
                        userId: 1,
                        storyType: .text,
                        caption: "Mi primera historia",
                        privacy: .public,
                        mediaUrl: nil,
                        thumbnailUrl: nil,
                        workoutData: nil,
                        viewCount: 10,
                        reactionCount: 5,
                        isPinned: false,
                        isExpired: false,
                        isOwnStory: false,
                        hasViewed: false,
                        hasReacted: false,
                        createdAt: Date(),
                        expiresAt: Date().addingTimeInterval(86400),
                        userInfo: nil
                    )
                ]
            ),
            storiesOwners: [],
            onDismiss: {}
        )
    }
}
