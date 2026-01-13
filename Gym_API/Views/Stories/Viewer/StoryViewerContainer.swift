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
    @State private var showingDeleteConfirmation = false
    @State private var storyToDelete: Story? = nil
    @State private var showDeleteSuccessMessage = false

    // Reaction animations
    @StateObject private var reactionAnimationManager = ReactionAnimationManager()

    // Gesture tracking - simplified system
    @State private var verticalDragOffset: CGFloat = 0
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var activeAxis: DragAxis = .none
    @State private var openProgress: CGFloat = 0.0

    private enum DragAxis { case none, vertical, horizontal }

    private let storyDuration: TimeInterval = 5.0 // 5 seconds per story

    init(userStories: [UserStoryGroup], initialUserIndex: Int) {
        self.userStories = userStories
        self.initialUserIndex = initialUserIndex
        self._currentUserIndex = State(initialValue: initialUserIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView(geometry: geometry)
                storyContentView(geometry: geometry)
            }
            .gesture(dragGesture(geometry: geometry))
        }
        .onAppear(perform: onAppear)
        .onChange(of: currentUserIndex, perform: handleUserIndexChange)
        .sheet(isPresented: $showingViewersSheet) {
            if let storyId = viewersStoryId {
                StoryViewersListView(storyId: storyId)
                    .presentationDetents([.medium, .large])
            }
        }
        .confirmationDialog(
            "¿Eliminar esta historia?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let story = storyToDelete {
                    Task { await deleteCurrentStory(story) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: - Background View
    private func backgroundView(geometry: GeometryProxy) -> some View {
        Color.black
            .opacity(backgroundOpacity(screenHeight: geometry.size.height))
            .ignoresSafeArea()
    }

    // MARK: - Story Content View
    @ViewBuilder
    private func storyContentView(geometry: GeometryProxy) -> some View {
        if let currentUser = currentUserStory,
           let currentStory = currentStory {
            ZStack {
                // Fondo negro para toda la pantalla
                Color.black.ignoresSafeArea()

                // Contenido de la story con aspect ratio 9:16 (Instagram Stories)
                StoryContentView(story: currentStory, isPaused: $isPaused)
                    .ignoresSafeArea()

                // Overlay con header y footer sobre la imagen
                storyOverlay(currentUser: currentUser, currentStory: currentStory, geometry: geometry)
                tapAreas(geometry: geometry)
                reactionAnimations()
            }
            .offset(y: verticalDragOffset)
        }
    }

    // MARK: - Story Overlay
    @ViewBuilder
    private func storyOverlay(currentUser: UserStoryGroup, currentStory: Story, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topSection(currentUser: currentUser, currentStory: currentStory)
            Spacer()
            bottomSection(currentStory: currentStory, geometry: geometry)
        }
    }

    // MARK: - Top Section
    @ViewBuilder
    private func topSection(currentUser: UserStoryGroup, currentStory: Story) -> some View {
        VStack(spacing: 8) {
            progressBars(currentUser: currentUser)
            userHeader(currentUser: currentUser, currentStory: currentStory)
        }
        .background(topGradient)
    }

    private func progressBars(currentUser: UserStoryGroup) -> some View {
        CAStoryProgressBars(
            storiesCount: currentUser.activeStories.count,
            currentIndex: currentStoryIndex,
            durations: currentUser.activeStories.defaultDurations(),
            isPaused: isPaused,
            barHeight: 3,
            barSpacing: 4,
            onSegmentComplete: { nextStory() }
        )
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func userHeader(currentUser: UserStoryGroup, currentStory: Story) -> some View {
        StoryHeaderView(
            userStory: currentUser,
            story: currentStory,
            canShowViewers: isOwnStory(userGroup: currentUser, story: currentStory),
            onClose: { dismiss() },
            onViewersTap: {
                viewersStoryId = currentStory.id
                showingViewersSheet = true
            },
            onDelete: {
                storyToDelete = currentStory
                showingDeleteConfirmation = true
            }
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var topGradient: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.8),
                Color.black.opacity(0.5),
                Color.black.opacity(0.2),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 200)
    }

    // MARK: - Bottom Section
    @ViewBuilder
    private func bottomSection(currentStory: Story, geometry: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            if let caption = currentStory.caption, !caption.isEmpty {
                captionView(caption: caption)
            }

            if !(currentStory.isOwnStory ?? false) {
                interactionBar(currentStory: currentStory)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
        .background(bottomGradient)
    }

    private func captionView(caption: String) -> some View {
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

    private func interactionBar(currentStory: Story) -> some View {
        StoryInteractionBar(
            story: currentStory,
            userAvatar: nil,
            onSendMessage: { message in
                print("DEBUG: Send story message -> id: \(currentStory.id), text: \(message)")
            },
            onSendReaction: { emoji in
                reactionAnimationManager.addReaction(emoji, startPosition: CGPoint(x: 0, y: 300))
                Task { await storyService.addReaction(storyId: currentStory.id, emoji: emoji) }
            },
            isPaused: $isPaused
        )
    }

    private var bottomGradient: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.2),
                Color.black.opacity(0.5),
                Color.black.opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 200)
    }

    // MARK: - Tap Areas
    @ViewBuilder
    private func tapAreas(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Empty space for header (progress bars + user info + buttons)
            Color.clear
                .frame(height: 100)
                .allowsHitTesting(false)

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
    }

    // MARK: - Reaction Animations
    @ViewBuilder
    private func reactionAnimations() -> some View {
        // Animaciones de reacciones flotantes
        EmptyView()
    }

    // MARK: - Drag Gesture
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)

                // Only start responding after minimum distance
                guard horizontalAmount > 5 || verticalAmount > 5 else { return }

                // Pause story when dragging starts
                if !isDragging {
                    isDragging = true
                    pauseStory()
                }

                // Determine drag direction based on initial gesture
                if activeAxis == .none {
                    if verticalAmount > horizontalAmount * 1.2 {
                        activeAxis = .vertical
                    } else if horizontalAmount > verticalAmount * 1.2 {
                        activeAxis = .horizontal
                    }
                }

                // Update offset based on axis
                if activeAxis == .vertical {
                    // Only allow downward drag with rubber-band effect
                    let y = value.translation.height
                    if y > 0 {
                        // Rubber-band: diminishing returns as user drags further
                        let rubberBanded = y * 0.6
                        verticalDragOffset = rubberBanded
                    } else {
                        // Slight resistance for upward drag
                        verticalDragOffset = y * 0.3
                    }
                } else if activeAxis == .horizontal {
                    // Horizontal drag with slight resistance
                    horizontalDragOffset = value.translation.width * 0.8
                }
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
                    let screenHeight = geometry.size.height
                    let dismissThreshold: CGFloat = 80
                    let shouldDismiss = verticalDragOffset > dismissThreshold || velocityY > 600

                    if shouldDismiss {
                        withAnimation(.easeOut(duration: 0.3)) {
                            verticalDragOffset = screenHeight + 100
                            contentOpacity = 0
                        }

                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            verticalDragOffset = 0
                            horizontalDragOffset = 0
                        }
                        resumeStory()
                    }
                    isDragging = false
                    activeAxis = .none
                } else if activeAxis == .horizontal || horizontalAmount > verticalAmount * 1.5 {
                    // Horizontal swipe - navigate between users
                    let swipeThreshold = geometry.size.width * 0.18
                    let predicted = value.predictedEndTranslation.width
                    let predictedBeyond = abs(predicted) > geometry.size.width * 0.25

                    if value.translation.width > swipeThreshold || (predicted > 0 && predictedBeyond) {
                        // Previous user
                        if currentUserIndex > 0 {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                horizontalDragOffset = geometry.size.width
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                previousUser()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    horizontalDragOffset = 0
                                }
                            }
                        } else {
                            let impactFeedback = UINotificationFeedbackGenerator()
                            impactFeedback.notificationOccurred(.warning)

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                horizontalDragOffset = 0
                            }
                            resumeStory()
                        }
                    } else if value.translation.width < -swipeThreshold || (predicted < 0 && predictedBeyond) {
                        // Next user
                        if currentUserIndex < userStories.count - 1 {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                horizontalDragOffset = -geometry.size.width
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                nextUser()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    horizontalDragOffset = 0
                                }
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                horizontalDragOffset = -geometry.size.width
                                contentOpacity = 0
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            horizontalDragOffset = 0
                        }
                        resumeStory()
                    }
                    isDragging = false
                    activeAxis = .none
                } else {
                    // Ambiguous gesture, reset
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        horizontalDragOffset = 0
                        verticalDragOffset = 0
                    }
                    isDragging = false
                    activeAxis = .none
                    resumeStory()
                }
            }
    }

    // MARK: - Lifecycle Methods
    private func onAppear() {
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

    private func handleUserIndexChange(_ newIndex: Int) {
        scheduleMarkViewedForCurrentStory()
    }

    // MARK: - Computed Properties

    /// Background opacity - fades as user drags down
    private func backgroundOpacity(screenHeight: CGFloat) -> Double {
        let maxDragForFade = screenHeight * 0.4
        let fadeProgress = min(verticalDragOffset / maxDragForFade, 1.0)
        return max(0, 1.0 - fadeProgress * 0.5) * openingOpacity
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

    // MARK: - Story Deletion
    private func deleteCurrentStory(_ story: Story) {
        print("DEBUG: 🗑️ ============================================")
        print("DEBUG: 🗑️ INICIANDO ELIMINACIÓN DE STORY")
        print("DEBUG: 🗑️ Story ID: \(story.id)")
        print("DEBUG: 🗑️ Story Type: \(story.storyType)")
        print("DEBUG: 🗑️ Current User Index: \(currentUserIndex)")
        print("DEBUG: 🗑️ Current Story Index: \(currentStoryIndex)")

        if let currentUser = currentUserStory {
            print("DEBUG: 🗑️ Usuario actual: \(currentUser.userName)")
            print("DEBUG: 🗑️ Total de stories activas del usuario: \(currentUser.activeStories.count)")
        }

        // Pausar la story actual
        pauseStory()
        print("DEBUG: 🗑️ Story pausada, llamando a deleteStory()...")

        Task {
            let success = await storyService.deleteStory(storyId: story.id)

            await MainActor.run {
                storyToDelete = nil

                if success {
                    print("DEBUG: ✅ Story eliminada exitosamente del backend")
                    print("DEBUG: ✅ Mostrando mensaje de confirmación al usuario")

                    // Mostrar mensaje de confirmación
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showDeleteSuccessMessage = true
                    }

                    // Ocultar mensaje después de 2 segundos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showDeleteSuccessMessage = false
                        }
                    }

                    // Determinar qué hacer después de la eliminación
                    guard let currentUser = currentUserStory else {
                        print("DEBUG: 🗑️ No hay usuario actual, cerrando viewer")
                        dismiss()
                        return
                    }

                    let remainingStories = currentUser.activeStories.filter { $0.id != story.id }
                    print("DEBUG: 🗑️ Stories restantes del usuario: \(remainingStories.count)")

                    if remainingStories.isEmpty {
                        print("DEBUG: 🗑️ No quedan más stories del usuario actual")
                        // No hay más stories del usuario actual
                        if currentUserIndex < userStories.count - 1 {
                            print("DEBUG: 🗑️ Avanzando al siguiente usuario...")
                            // Avanzar al siguiente usuario
                            nextUser()
                        } else if currentUserIndex > 0 {
                            print("DEBUG: 🗑️ Retrocediendo al usuario anterior...")
                            // Retroceder al usuario anterior
                            previousUser()
                        } else {
                            print("DEBUG: 🗑️ Era la última/única story, cerrando viewer")
                            // Era la única story, cerrar el viewer
                            dismiss()
                        }
                    } else {
                        print("DEBUG: 🗑️ Hay más stories del mismo usuario, continuando...")
                        // Hay más stories del mismo usuario
                        if currentStoryIndex >= remainingStories.count {
                            // Si el índice está fuera de rango, ajustar
                            print("DEBUG: 🗑️ Ajustando índice de \(currentStoryIndex) a \(remainingStories.count - 1)")
                            currentStoryIndex = remainingStories.count - 1
                        }
                        // Continuar con la siguiente story del mismo usuario
                        resetProgress()
                        markCurrentStoryAsViewed()
                        preloadNextStories()
                        resumeStory()
                    }
                    print("DEBUG: 🗑️ ============================================")
                } else {
                    print("DEBUG: ❌ ERROR: Falló la eliminación de la story")
                    print("DEBUG: ❌ Reanudando la story actual")
                    // En caso de error, reanudar la story
                    resumeStory()
                    print("DEBUG: 🗑️ ============================================")
                }
            }
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
    private func scheduleMarkViewedForCurrentStory(delaySeconds: Double = 0.3) {
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
            // Fondo negro para áreas vacías cuando la imagen no llena todo
            Color.black

            switch story.storyType {
            case .image:
                if let mediaUrl = story.mediaUrl, !mediaUrl.isEmpty {
                    // Instagram Stories usa 9:16 aspect ratio con scaledToFill
                    StoryImageWithError(url: mediaUrl)
                        .aspectRatio(9/16, contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped() // Importante: recorta el contenido que se sale
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
                        .aspectRatio(9/16, contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped() // Importante: recorta el contenido que se sale
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
    @EnvironmentObject var authService: AuthServiceDirect

    let userStory: UserStoryGroup
    let story: Story
    let canShowViewers: Bool
    let onClose: () -> Void
    var onViewersTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            if let avatarUrl = resolvedAvatarURL(), !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    case .failure(_):
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 16))
                            )
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            )
                    @unknown default:
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                    }
                }
                .onAppear {
                    print("DEBUG: 🖼️ Cargando avatar del header: \(avatarUrl)")
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

            // Delete button (solo para propias stories)
            if canShowViewers, let deleteAction = onDelete {
                Button(action: {
                    print("DEBUG: 🗑️ Botón de eliminar tocado en StoryHeaderView")
                    deleteAction()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .accessibilityLabel("Eliminar historia")
                .onAppear {
                    print("DEBUG: 🗑️ Botón de eliminar renderizado")
                }
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

    /// Resuelve el avatar URL correcto priorizando el backend para el usuario actual
    @MainActor
    private func resolvedAvatarURL() -> String? {
        // Verificar si esta story es del usuario actual
        let isCurrentUser = isOwnStory()

        if isCurrentUser {
            // Para el usuario actual, priorizar imagen del backend
            if let profilePic = UserProfileService.shared.userProfile?.picture, !profilePic.isEmpty {
                return cleanAvatarURL(profilePic)
            }

            // Fallback a la imagen de Auth0
            if let userPic = authService.user?.picture, !userPic.isEmpty {
                return cleanAvatarURL(userPic)
            }

            // Último recurso: generar avatar con UI Avatars
            guard let user = authService.user else { return userStory.userAvatar }
            let encodedName = user.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User"
            let normalizedId = user.id
                .replacingOccurrences(of: "user_", with: "")
                .replacingOccurrences(of: "auth0|", with: "")

            let colorHash = abs(normalizedId.hashValue) % 16777215
            let backgroundColor = String(format: "%06X", colorHash)

            return "https://ui-avatars.com/api/?name=\(encodedName)&size=128&background=\(backgroundColor)&color=fff&format=png"
        } else {
            // Para otros usuarios, usar el avatar que viene del backend en UserStoryGroup
            return userStory.userAvatar.flatMap(cleanAvatarURL)
        }
    }

    /// Verifica si la story es del usuario actual
    private func isOwnStory() -> Bool {
        if let own = story.isOwnStory { return own }
        if let userIdStr = authService.user?.id, let userId = Int(userIdStr) {
            return userStory.userId == userId
        }
        return false
    }

    /// Limpia URLs de avatar problemáticas
    private func cleanAvatarURL(_ urlString: String) -> String {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remover '?' al final que algunos proveedores agregan
        while s.hasSuffix("?") { s.removeLast() }
        return s
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
