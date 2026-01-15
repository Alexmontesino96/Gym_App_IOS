//
//  StoryInteractionBar.swift
//  Gym_API
//
//  Unified component for story reactions and messaging
//  Replaces: StoryReactionBar, InstagramStoryBottomBar, StoryReactionPicker
//  Design doc: STORY_REACTION_UX_REDESIGN.md
//
//  Created on December 2024
//

import SwiftUI

// MARK: - Design Tokens
/// Design tokens from UX spec for consistent styling
enum StoryInteractionTokens {

    // MARK: - Colors
    enum Colors {
        static let background = Color.black
        static let accent = Color(red: 217/255, green: 51/255, blue: 51/255) // #D93333
        static let accentLight = Color(red: 255/255, green: 107/255, blue: 107/255) // #FF6B6B

        static let glassSurface = Color.white.opacity(0.08)
        static let glassSurfaceHover = Color.white.opacity(0.12)
        static let glassSurfaceActive = Color.white.opacity(0.16)
        static let glassBorder = Color.white.opacity(0.15)

        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textPlaceholder = Color.white.opacity(0.5)

        static let success = Color(red: 76/255, green: 175/255, blue: 80/255) // #4CAF50
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Sizes
    enum Sizes {
        static let barHeight: CGFloat = 56
        static let inputHeight: CGFloat = 44
        static let buttonSize: CGFloat = 44
        static let avatarSmall: CGFloat = 28
        static let avatarLarge: CGFloat = 36
        static let emojiQuick: CGFloat = 22
        static let emojiTray: CGFloat = 32
        static let emojiPicker: CGFloat = 28
        static let emojiConfirmation: CGFloat = 80
        static let trayHeight: CGFloat = 64
    }

    // MARK: - Radius
    enum Radius {
        static let bar: CGFloat = 28
        static let input: CGFloat = 22
        static let picker: CGFloat = 16
    }

    // MARK: - Animations
    enum Animations {
        static let modeTransition = Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let buttonTap = Animation.spring(response: 0.25, dampingFraction: 0.6)
        static let traySlide = Animation.spring(response: 0.3, dampingFraction: 0.75)
    }
}

// MARK: - Interaction Mode
/// State modes for the interaction bar
enum StoryInteractionMode: Equatable {
    case quick       // Default: input placeholder + 3 reaction buttons
    case compose     // Expanded: emoji tray + input + send
    case picker      // Mini picker visible as overlay
    case reacted     // Temporary confirmation state
}

// MARK: - Contextual Emojis
/// Provides context-aware emoji suggestions based on story type
struct ContextualEmojis {

    /// Gets emojis relevant to the story type
    static func getEmojis(for storyType: StoryType) -> [String] {
        switch storyType {
        case .workout:
            return ["💪", "🔥", "👏", "🏆", "⚡", "💥", "🎯", "🙌"]
        case .achievement:
            return ["🏆", "⭐", "👏", "🔥", "💯", "🥇", "💪", "🙌"]
        case .image, .video:
            return ["🔥", "❤️", "👏", "😍", "💯", "💪", "👌", "🙌"]
        case .text:
            return ["👏", "💯", "🔥", "❤️", "💪", "😂", "🙌", "⚡"]
        }
    }

    /// Emojis for quick mode (always visible)
    static let quickModeEmojis: [String] = ["❤️", "🔥", "💪"]

    /// Categories for mini picker
    static let pickerCategories: [EmojiPickerCategory] = [
        EmojiPickerCategory(
            name: "Fitness",
            icon: "figure.strengthtraining.traditional",
            emojis: ["💪", "🔥", "🏋️", "🏃", "🚴", "🏆", "🥇", "⚡",
                     "💥", "🎯", "🙌", "👊", "✊", "🦵", "🏅", "🎽"]
        ),
        EmojiPickerCategory(
            name: "Expresiones",
            icon: "face.smiling",
            emojis: ["👏", "💯", "😍", "🤩", "😂", "😮", "🥹", "😎",
                     "🫡", "👌", "🤙", "✌️", "👍", "🙏", "💪", "🔥"]
        ),
        EmojiPickerCategory(
            name: "Corazones",
            icon: "heart.fill",
            emojis: ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "❤️‍🔥",
                     "💕", "💖", "💗", "💓", "💞", "💝", "💘", "💟"]
        )
    ]
}

/// Emoji picker category structure
struct EmojiPickerCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String  // SF Symbol
    let emojis: [String]
}

// MARK: - State Manager
/// Manages interaction bar state transitions
@MainActor
class StoryInteractionBarState: ObservableObject {
    @Published var mode: StoryInteractionMode = .quick
    @Published var messageText: String = ""
    @Published var lastReaction: String? = nil
    @Published var showConfirmation: Bool = false
    @Published var isPaused: Bool = false

    /// Transition to compose mode
    func startComposing() {
        withAnimation(StoryInteractionTokens.Animations.modeTransition) {
            mode = .compose
            isPaused = true
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Cancel composing and return to quick mode
    func cancelComposing() {
        withAnimation(StoryInteractionTokens.Animations.modeTransition) {
            mode = .quick
            messageText = ""
            isPaused = false
        }
    }

    /// Send a reaction with confirmation animation
    func sendReaction(_ emoji: String) {
        lastReaction = emoji
        showConfirmation = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Reset confirmation after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            withAnimation {
                self?.showConfirmation = false
                self?.mode = .quick
                self?.isPaused = false
            }
        }

        // Clear last reaction indicator after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.lastReaction = nil
        }
    }

    /// Open the mini picker overlay
    func openPicker() {
        withAnimation(StoryInteractionTokens.Animations.traySlide) {
            mode = .picker
        }
    }

    /// Close picker and return to compose mode
    func closePicker() {
        withAnimation(StoryInteractionTokens.Animations.traySlide) {
            mode = .compose
        }
    }

    /// Reset to initial state
    func reset() {
        mode = .quick
        messageText = ""
        lastReaction = nil
        showConfirmation = false
        isPaused = false
    }

    #if DEBUG
    deinit {
        print("StoryInteractionBarState deinit")
    }
    #endif
}

// MARK: - Main Component
/// Unified story interaction bar component
/// Provides reactions, messaging, and emoji picker functionality
struct StoryInteractionBar: View {
    // MARK: - Properties
    let story: Story
    let userAvatar: String?
    let onSendMessage: (String) -> Void
    let onSendReaction: (String) -> Void
    @Binding var isPaused: Bool

    // MARK: - State
    @StateObject private var state = StoryInteractionBarState()
    @FocusState private var isInputFocused: Bool

    // MARK: - Computed Properties
    private var contextualEmojis: [String] {
        ContextualEmojis.getEmojis(for: story.storyType)
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // Confirmation overlay (centered on screen)
            if state.showConfirmation, let emoji = state.lastReaction {
                StoryReactionConfirmation(emoji: emoji)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }

            VStack(spacing: 0) {
                // Mini picker (when mode == .picker)
                if state.mode == .picker {
                    StoryReactionMiniPicker(
                        categories: ContextualEmojis.pickerCategories,
                        onSelect: { emoji in
                            handleReaction(emoji)
                        },
                        onClose: {
                            state.closePicker()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, StoryInteractionTokens.Spacing.sm)
                }

                // Reaction tray (when mode == .compose or .picker)
                if state.mode == .compose || state.mode == .picker {
                    StoryReactionTray(
                        emojis: contextualEmojis,
                        onSelect: { emoji in
                            handleReaction(emoji)
                        },
                        onMoreTapped: {
                            state.openPicker()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, StoryInteractionTokens.Spacing.sm)
                }

                // Main interaction bar
                mainBar
            }
        }
        .onChange(of: state.isPaused) { _, newValue in
            isPaused = newValue
        }
        .onChange(of: state.mode) { _, newMode in
            // Auto-focus when entering compose mode
            if newMode == .compose {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isInputFocused = true
                }
            } else if newMode == .quick {
                isInputFocused = false
            }
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused && state.mode == .quick {
                state.startComposing()
            }
        }
    }

    // MARK: - Main Bar View
    private var mainBar: some View {
        HStack(spacing: 12) {
            // Avatar (only in quick mode)
            if state.mode == .quick {
                StoryAvatarView(url: userAvatar, size: StoryInteractionTokens.Sizes.avatarSmall)
            }

            // Camera button (only in compose mode)
            if state.mode == .compose || state.mode == .picker {
                Button(action: { /* TODO: Camera reply */ }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(StoryInteractionTokens.Colors.textPrimary)
                        .frame(width: StoryInteractionTokens.Sizes.buttonSize, height: StoryInteractionTokens.Sizes.buttonSize)
                        .background(
                            Circle()
                                .fill(StoryInteractionTokens.Colors.glassSurface)
                        )
                }
                .accessibilityLabel("Camara")
            }

            // Input field
            inputField

            // Action buttons
            if state.mode == .quick {
                quickReactionButtons
            } else {
                sendButton
            }
        }
        .padding(.horizontal, 14)      // Menos padding
        .padding(.vertical, 6)         // Menos padding vertical
        .frame(height: 48)             // Altura reducida (era 56)
        .background(
            RoundedRectangle(cornerRadius: 22)  // Menos redondeado (era 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: .black.opacity(0.12),  // Más sutil (era 0.25)
                    radius: 8,                     // Menos difuso (era 16)
                    x: 0,
                    y: -2                          // Menos offset (era -4)
                )
        )
    }

    // MARK: - Input Field
    private var inputField: some View {
        HStack(spacing: StoryInteractionTokens.Spacing.sm) {
            ZStack(alignment: .leading) {
                // Placeholder when in quick mode
                if state.mode == .quick {
                    Text("Enviar mensaje...")
                        .font(.system(size: 15))
                        .foregroundColor(StoryInteractionTokens.Colors.textPlaceholder)
                }

                // TextField always present but invisible in quick mode
                TextField("Escribe tu respuesta...", text: $state.messageText)
                    .font(.system(size: 15))
                    .foregroundColor(StoryInteractionTokens.Colors.textPrimary)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }
                    .opacity(state.mode == .quick ? 0.01 : 1.0)
                    .disabled(state.mode == .quick)
            }

            Spacer()
        }
        .padding(.horizontal, StoryInteractionTokens.Spacing.lg)
        .padding(.vertical, StoryInteractionTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(state.mode == .quick ? StoryInteractionTokens.Colors.glassSurface : StoryInteractionTokens.Colors.glassSurfaceHover)
                .overlay(
                    Capsule()
                        .stroke(
                            state.mode != .quick ? StoryInteractionTokens.Colors.accent : StoryInteractionTokens.Colors.glassBorder,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Capsule())
        .onTapGesture {
            // Close picker if open
            if state.mode == .picker {
                state.closePicker()
                return
            }

            // Activate input field in quick mode
            if state.mode == .quick {
                state.startComposing()
                // Focus is handled automatically by onChange(of: state.mode)
            } else {
                // If already in compose mode, try to focus manually
                isInputFocused = true
            }
        }
        .accessibilityLabel("Campo de mensaje")
        .accessibilityHint(state.mode == .quick ? "Toca para escribir un mensaje" : "Escribe tu respuesta")
    }

    // MARK: - Quick Reaction Buttons
    private var quickReactionButtons: some View {
        HStack(spacing: StoryInteractionTokens.Spacing.sm) {
            // Show last emoji sent or default buttons
            if let lastEmoji = state.lastReaction {
                // Show checkmark with sent emoji
                ZStack {
                    Circle()
                        .fill(StoryInteractionTokens.Colors.accent.opacity(0.2))
                        .frame(width: StoryInteractionTokens.Sizes.buttonSize, height: StoryInteractionTokens.Sizes.buttonSize)

                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(StoryInteractionTokens.Colors.accent)
                        Text(lastEmoji)
                            .font(.system(size: 16))
                    }
                }
                .accessibilityLabel("Reaccion enviada: \(lastEmoji)")
            } else {
                // Quick reaction buttons
                ForEach(ContextualEmojis.quickModeEmojis, id: \.self) { emoji in
                    QuickReactionButton(
                        emoji: emoji,
                        isHeart: emoji == "❤️"
                    ) {
                        handleReaction(emoji)
                    }
                }
            }
        }
    }

    // MARK: - Send Button
    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(StoryInteractionTokens.Colors.textPrimary)
                .frame(width: StoryInteractionTokens.Sizes.buttonSize, height: StoryInteractionTokens.Sizes.buttonSize)
                .background(
                    Circle()
                        .fill(
                            state.messageText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? StoryInteractionTokens.Colors.glassSurface
                            : StoryInteractionTokens.Colors.accent
                        )
                )
        }
        .disabled(state.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        .accessibilityLabel("Enviar mensaje")
    }

    // MARK: - Actions
    private func handleReaction(_ emoji: String) {
        state.sendReaction(emoji)
        onSendReaction(emoji)
    }

    private func sendMessage() {
        let text = state.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        onSendMessage(text)
        state.messageText = ""
        state.cancelComposing()
        isInputFocused = false
    }
}

// MARK: - Quick Reaction Button
/// Individual reaction button with press animation
struct QuickReactionButton: View {
    let emoji: String
    let isHeart: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(StoryInteractionTokens.Animations.buttonTap) {
                isPressed = true
            }

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Reset and execute action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation {
                    isPressed = false
                }
                onTap()
            }
        }) {
            Group {
                if isHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(StoryInteractionTokens.Colors.accent)
                } else {
                    Text(emoji)
                        .font(.system(size: StoryInteractionTokens.Sizes.emojiQuick))
                }
            }
            .frame(width: StoryInteractionTokens.Sizes.buttonSize, height: StoryInteractionTokens.Sizes.buttonSize)
            .background(
                Circle()
                    .fill(
                        isHeart
                        ? StoryInteractionTokens.Colors.accent.opacity(0.15)
                        : StoryInteractionTokens.Colors.glassSurface
                    )
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isHeart ? "Corazon" : emoji)
    }
}

// MARK: - Reaction Tray
/// Horizontal scrollable tray of emoji reactions
struct StoryReactionTray: View {
    let emojis: [String]
    let onSelect: (String) -> Void
    let onMoreTapped: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StoryInteractionTokens.Spacing.lg) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: StoryInteractionTokens.Sizes.emojiTray))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(StoryInteractionTokens.Colors.glassBorder, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.scale(0.9))
                    .accessibilityLabel(emoji)
                }

                // More button
                Button(action: onMoreTapped) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(StoryInteractionTokens.Colors.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(StoryInteractionTokens.Colors.glassSurface)
                                .overlay(
                                    Circle()
                                        .stroke(StoryInteractionTokens.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.scale(0.9))
                .accessibilityLabel("Mas emojis")
            }
            .padding(.horizontal, StoryInteractionTokens.Spacing.lg)
        }
        .frame(height: StoryInteractionTokens.Sizes.trayHeight)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Scale Button Style
// ScaleButtonStyle moved to Views/Components/ButtonStyles.swift to avoid duplication

// MARK: - Avatar View
/// Simple avatar display component
struct StoryAvatarView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = url, let imageUrl = URL(string: urlString) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: size * 0.4))
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: size * 0.4))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Preview
#Preview("Story Interaction Bar") {
    struct PreviewWrapper: View {
        @State private var isPaused = false

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    Spacer()

                    Text("isPaused: \(isPaused ? "Yes" : "No")")
                        .foregroundColor(.white)
                        .padding()

                    Spacer()

                    StoryInteractionBar(
                        story: Story(
                            id: 1,
                            gymId: 1,
                            userId: 1,
                            storyType: .workout,
                            caption: "Test story",
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
                        ),
                        userAvatar: nil,
                        onSendMessage: { message in
                            print("Message sent: \(message)")
                        },
                        onSendReaction: { emoji in
                            print("Reaction sent: \(emoji)")
                        },
                        isPaused: $isPaused
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
            }
        }
    }

    return PreviewWrapper()
}
