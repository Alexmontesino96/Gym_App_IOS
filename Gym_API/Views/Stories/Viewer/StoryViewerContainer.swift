//
//  StoryViewerContainer.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI
import Combine
import UIKit

struct StoryViewerContainer: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storyUIState: StoryUIState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var viewMarkTask: Task<Void, Never>? = nil
    @State private var pendingViewedStoryId: Int? = nil

    // Gesture tracking
    @State private var dragOffset: CGFloat = 0
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var activeAxis: DragAxis = .none

    // Avatar-targeted dismiss animation state
    @State private var isAvatarDismiss: Bool = false
    @State private var avatarDismissOffset: CGSize = .zero
    @State private var avatarDismissScale: CGFloat = 1.0
    @State private var avatarDismissCornerRadius: CGFloat = 0
    @State private var openProgress: CGFloat = 0.0

    private enum DragAxis { case none, vertical, horizontal }

    private let storyDuration: TimeInterval = 5.0 // 5 seconds per story

    // Transient drag translation captured via @GestureState to avoid per-frame state writes
    @GestureState private var dragTranslation: CGSize = .zero

    init(userStories: [UserStoryGroup], initialUserIndex: Int) {
        self.userStories = userStories
        self.initialUserIndex = initialUserIndex
        self._currentUserIndex = State(initialValue: initialUserIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Controlled dim overlay (fades during drag). Underlying view shows through when this hits 0
                Rectangle()
                    .fill(Color.black)
                    .opacity(max(0, 1.0 - min(dragOffset / (geometry.size.height * 0.5), 1.0)))
                    .ignoresSafeArea()

                // Story Content
                if let currentUser = currentUserStory,
                   let currentStory = currentStory {
                    StoryContentView(story: currentStory, isPaused: $isPaused)
                        .ignoresSafeArea()

                    // Overlay UI
                    VStack(spacing: 0) {
                        // Top section with progress bars and user info
                        VStack(spacing: 8) {
                            // Progress bars (Core Animation version)
                            CAStoryProgressBars(
                                storiesCount: currentUser.activeStories.count,
                                currentIndex: currentStoryIndex,
                                durations: currentUser.activeStories.defaultDurations(),
                                isPaused: isPaused,
                                barHeight: 3,
                                barSpacing: 4,
                                onSegmentComplete: {
                                    // When a segment completes, advance to next story
                                    nextStory()
                                }
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
                    TapArea(side: .left) {
                        previousStory()
                    }
                    .frame(width: geometry.size.width * 0.35)

                    Spacer()

                    // Next story tap area
                    TapArea(side: .right) {
                        nextStory()
                    }
                    .frame(width: geometry.size.width * 0.35)
                }
            }
            // Apply transformations to the entire container (computed with gesture state)
            .offset(x: isAvatarDismiss ? avatarDismissOffset.width : effectiveHorizontalOffset(totalWidth: geometry.size.width))
            .offset(y: isAvatarDismiss ? avatarDismissOffset.height : effectiveVerticalOffset(totalHeight: geometry.size.height))
            .scaleEffect((isAvatarDismiss ? avatarDismissScale : calculateScale(dragOffset: displayedVerticalOffset(totalHeight: geometry.size.height), screenHeight: geometry.size.height)) * openingScale)
            .opacity(totalOpacity(screenHeight: geometry.size.height))
            .clipShape(RoundedRectangle(cornerRadius: isAvatarDismiss ? avatarDismissCornerRadius : calculateCornerRadius(dragOffset: displayedVerticalOffset(totalHeight: geometry.size.height), screenHeight: geometry.size.height)))
            // Opción 1: Spring más responsivo durante drag interactivo
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.86), value: isDragging)
            // Make fullScreenCover background transparent to avoid black flash beneath during dismiss
            .background(ClearFullscreenBackgroundView())
        .gesture(
            DragGesture(minimumDistance: 10)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                    .onChanged { value in
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)

                        // Only start responding after minimum distance to avoid conflicts with taps
                        guard horizontalAmount > 5 || verticalAmount > 5 else { return }

                        // Pause story when dragging starts
                        // Use DispatchQueue.main.async to avoid modifying state during view update
                        if !isDragging {
                            DispatchQueue.main.async {
                                isDragging = true
                                pauseStory()
                            }
                        }

                        // Determine drag direction based on initial gesture
                        if activeAxis == .none {
                            if verticalAmount > horizontalAmount * 1.2 {
                                DispatchQueue.main.async { activeAxis = .vertical }
                            }
                            else if horizontalAmount > verticalAmount * 1.2 {
                                DispatchQueue.main.async { activeAxis = .horizontal }
                            }
                        }
                        // No per-frame state writes; visuals are derived from dragTranslation
                    }
                    .onEnded { value in
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)

                        // Calculate velocity based on predicted end vs current position
                        let velocityX = value.predictedEndTranslation.width - value.translation.width
                        let velocityY = value.predictedEndTranslation.height - value.translation.height

                        // Determine which gesture was being performed
                        if activeAxis == .vertical || verticalAmount > horizontalAmount * 1.5 {
                            // Vertical swipe - dismiss
                            // Instagram-style: threshold sensible y directo
                            let dismissThreshold: CGFloat = 120  // Más sensible que 150pt (estilo Instagram)
                            let shouldDismiss = value.translation.height > dismissThreshold || velocityY > 800

                            if shouldDismiss {
                                // Dismiss to avatar if available (current user's or corresponding user avatar)
                                if let avatar = targetAvatarFrame {
                                    let screen = UIScreen.main.bounds
                                    let currentCenter = CGPoint(x: screen.midX, y: screen.midY)
                                    let targetCenter = CGPoint(x: avatar.midX, y: avatar.midY)
                                    let dx = targetCenter.x - currentCenter.x
                                    let dy = targetCenter.y - currentCenter.y
                                    // Compute target scale based on avatar diameter vs screen min dimension
                                    let avatarDiameter = min(avatar.width, avatar.height)
                                    let base = min(screen.width, screen.height)
                                    let targetScale = max(0.2, min(0.6, avatarDiameter / base))

                                    // Opción 1: Animación consistente con spring interactivo
                                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                        isAvatarDismiss = true
                                        avatarDismissOffset = CGSize(width: dx, height: dy)
                                        avatarDismissScale = targetScale
                                        avatarDismissCornerRadius = avatarDiameter / 2
                                        contentOpacity = 0.95
                                    }
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    // Opción 1: Ajustado para nueva duración de animación (0.28s)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.29) {
                                        dismiss()
                                        isAvatarDismiss = false
                                        avatarDismissOffset = .zero
                                        avatarDismissScale = 1.0
                                        avatarDismissCornerRadius = 0
                                    }
                                } else {
                                    // Opción 1: Consistencia con spring interactivo
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.86)) {
                                        dragOffset = geometry.size.height
                                        contentOpacity = 0
                                    }
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    // Opción 1: Ajustado para nueva duración de animación (0.3s)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
                                        dismiss()
                                    }
                                }
                            } else {
                                // Opción 1: Spring más refinado para retorno suave
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    dragOffset = 0
                                    horizontalDragOffset = 0
                                    contentOpacity = 1.0
                                    isDragging = false
                                    activeAxis = .none
                                }
                                resumeStory()
                            }
                        } else if activeAxis == .horizontal || horizontalAmount > verticalAmount * 1.5 {
                            // Horizontal swipe - navigate between users
                            // Softer physics: 18% threshold OR predicted end beyond 25% of width
                            let swipeThreshold = geometry.size.width * 0.18
                            let predicted = value.predictedEndTranslation.width
                            let predictedBeyond = abs(predicted) > geometry.size.width * 0.25

                            // Previous user
                            if value.translation.width > swipeThreshold || (predicted > 0 && predictedBeyond) {
                                // Previous user
                                if currentUserIndex > 0 {
                                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                        horizontalDragOffset = geometry.size.width
                                    }

                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        previousUser()
                                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                        horizontalDragOffset = 0
                                        isDragging = false
                                    }
                                    }
                                } else {
                                    // Can't go previous, elastic bounce back with improved spring
                                    // Using interactiveSpring for more natural edge bounce feel
                                    let impactFeedback = UINotificationFeedbackGenerator()
                                    impactFeedback.notificationOccurred(.warning)

                                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.72)) {
                                        horizontalDragOffset = 0
                                        dragOffset = 0
                                        contentOpacity = 1.0
                                        isDragging = false
                                        activeAxis = .none
                                    }
                                    resumeStory()
                                }
                            } else if value.translation.width < -swipeThreshold || (predicted < 0 && predictedBeyond) {
                                // Next user
                                if currentUserIndex < userStories.count - 1 {
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        nextUser()
                                        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                            horizontalDragOffset = 0
                                            isDragging = false
                                        }
                                    }
                                } else {
                                    // At last user, dismiss
                                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                        horizontalDragOffset = -geometry.size.width
                                    }

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        dismiss()
                                    }
                                }
                            } else {
                                // Didn't meet threshold, reset with improved spring animation
                                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                    horizontalDragOffset = 0
                                    dragOffset = 0
                                    isDragging = false
                                    activeAxis = .none
                                }
                                resumeStory()
                            }
                        } else {
                            // Ambiguous gesture or very small drag, just reset
                            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                horizontalDragOffset = 0
                                dragOffset = 0
                                isDragging = false
                                activeAxis = .none
                            }
                            resumeStory()
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.15)
                    .onChanged { _ in
                        if !isPaused { pauseStory() }
                    }
                    .onEnded { _ in
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

                // Interactive opening animation
                if reduceMotion {
                    openProgress = 1.0
                } else {
                    openProgress = 0.0
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                        openProgress = 1.0
                    }
                }

                startStoryTimer()
                scheduleMarkViewedForCurrentStory()
                preloadNextStories()
            }
            .onDisappear {
                stopTimer()
            }
            .onChange(of: currentStoryIndex) { _, _ in
                scheduleMarkViewedForCurrentStory()
            }
            .onChange(of: currentUserIndex) { _, _ in
                scheduleMarkViewedForCurrentStory()
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
    private func displayedVerticalOffset(totalHeight: CGFloat) -> CGFloat {
        // Rubber-band the dragTranslation.y; keep persistent dragOffset for end animations
        let y = dragTranslation.height
        guard y > 0 else { return dragOffset }
        let t1: CGFloat = 160
        let rubber: CGFloat = y <= t1 ? y * 0.9 : (t1 * 0.9 + (y - t1) * 0.5)
        return dragOffset + rubber
    }

    private func effectiveVerticalOffset(totalHeight: CGFloat) -> CGFloat {
        return isDragging ? displayedVerticalOffset(totalHeight: totalHeight) : dragOffset
    }

    private func effectiveHorizontalOffset(totalWidth: CGFloat) -> CGFloat {
        // Apply subtle resistance to horizontal drag
        let maxDrag = totalWidth
        let normalized = max(-maxDrag, min(maxDrag, dragTranslation.width))
        let progress = abs(normalized) / maxDrag
        let resisted = normalized * (1 - progress * 0.15)
        return horizontalDragOffset + resisted
    }
    private var currentUserStory: UserStoryGroup? {
        guard currentUserIndex < userStories.count else { return nil }
        return userStories[currentUserIndex]
    }

    private var currentStory: Story? {
        guard let user = currentUserStory,
              currentStoryIndex < user.activeStories.count else { return nil }
        return user.activeStories[currentStoryIndex]
    }

    // Frame de avatar destino para el cierre: si es propia, usa el avatar propio; si es de otro, usa el de ese usuario.
    private var targetAvatarFrame: CGRect? {
        guard let user = currentUserStory else { return storyUIState.myAvatarFrame }
        if let cs = currentStory, isOwnStory(userGroup: user, story: cs) {
            return storyUIState.myAvatarFrame
        }
        return storyUIState.avatarFramesByUserId[user.userId] ?? storyUIState.myAvatarFrame
    }

    // MARK: - Instagram-style Dismiss Animation

    /// Calcula la escala basada en el drag (efecto de "shrinking" hacia círculo)
    private func calculateScale(dragOffset: CGFloat, screenHeight: CGFloat) -> CGFloat {
        // Instagram-style: sin transformación de escala durante drag
        // La transformación solo ocurre en la animación final de cierre
        return 1.0
    }

    /// Calcula el corner radius basado en el drag (efecto de convertirse en círculo)
    private func calculateCornerRadius(dragOffset: CGFloat, screenHeight: CGFloat) -> CGFloat {
        // Instagram-style: sin corner radius durante drag
        // La ventana mantiene sus esquinas rectangulares durante el movimiento
        return 0
    }

    // Combined opacity factoring opening animation (Instagram-style)
    private func totalOpacity(screenHeight: CGFloat) -> Double {
        // Instagram-style: sin dimming durante drag
        // Mantener opacidad completa, solo considerar estados base y de apertura
        return Double(contentOpacity) * openingOpacity
    }

    // MARK: - Opening animation helpers
    private var openingScale: CGFloat {
        if reduceMotion { return 1.0 }
        // Scale from 0.94 to 1.0 by openProgress
        return 0.94 + (0.06 * openProgress)
    }

    private var openingOpacity: Double {
        if reduceMotion { return 1.0 }
        return Double(openProgress)
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

    // MARK: - Timer Management (replaced by CA progress)
    private func startStoryTimer() {}
    private func resetProgress() {}
    private func stopTimer() {}

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

    // MARK: - Delayed mark-as-viewed (threshold) to update UI ring early
    private func scheduleMarkViewedForCurrentStory(delaySeconds: Double = 1.5) {
        viewMarkTask?.cancel()
        pendingViewedStoryId = currentStory?.id
        guard let story = currentStory, !story.hasViewed else { return }
        let id = story.id
        viewMarkTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            if Task.isCancelled { return }
            if pendingViewedStoryId == id {
                await storyService.markAsViewed(storyId: id, duration: Int(delaySeconds))
            }
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

// Helper to force the fullScreenCover background to be transparent, so the underlying feed shows during dismiss animation
private struct ClearFullscreenBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        DispatchQueue.main.async {
            // Try to clear superviews in the hierarchy
            v.superview?.backgroundColor = .clear
            v.superview?.superview?.backgroundColor = .clear
        }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
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
    @Binding var isPaused: Bool

    var body: some View {
        GeometryReader { proxy in
        ZStack {
            switch story.storyType {
            case .image:
                if let mediaUrl = story.mediaUrl, !mediaUrl.isEmpty {
                    StoryImageWithError(url: mediaUrl)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .id(story.id) // Force view recreation when story changes
                        .onAppear {
                            print("DEBUG: 🖼️ Loading story image for Story ID: \(story.id)")
                            print("DEBUG: 🖼️ Full Media URL: \(mediaUrl)")
                            print("DEBUG: 🖼️ URL suffix: \(mediaUrl.suffix(80))")
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
                if let mediaUrl = story.mediaUrl, let url = URL(string: mediaUrl) {
                    VideoStoryView(url: url, isPaused: $isPaused)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .id(story.id)
                } else {
                    Color.black
                }

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

// MARK: - Tap Area Component
struct TapArea: View {
    enum Side {
        case left, right
    }

    let side: Side
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay(
                // Subtle flash effect on tap (like Instagram)
                Rectangle()
                    .fill(.white.opacity(isPressed ? 0.1 : 0))
                    .allowsHitTesting(false)
            )
            .onTapGesture {
                // Subtle visual flash
                withAnimation(.easeOut(duration: 0.08)) {
                    isPressed = true
                }

                // Subtle haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                impactFeedback.impactOccurred()

                // Execute action
                action()

                // Reset quickly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeIn(duration: 0.08)) {
                        isPressed = false
                    }
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
