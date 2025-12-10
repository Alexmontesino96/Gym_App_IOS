//
//  InstagramStoryBottomBar_Legacy.swift
//  Gym_API
//
//  DEPRECATED - Use StoryInteractionBar instead
//  This file is kept for reference and potential rollback.
//  See STORY_REACTION_UX_REDESIGN.md for migration details.
//

import SwiftUI

// MARK: - DEPRECATED: Use StoryInteractionBar
/// Legacy Instagram-style bottom bar component
/// @available(*, deprecated, message: "Use StoryInteractionBar instead")
struct InstagramStoryBottomBar_Legacy: View {
    let story: Story
    let onSendMessage: (String) -> Void
    let onReact: (String) -> Void
    @Binding var isPaused: Bool  // Pause story when interacting

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isComposing = false
    @State private var messageText: String = ""
    @State private var showReactionPicker = false
    @FocusState private var isTextFocused: Bool

    private let quickReactions = ["🔥", "😍", "👏", "😂", "😮", "😢"]

    var body: some View {
        mainContent
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if isComposing {
                quickReactionsRow
            }

            inputBar
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showReactionPicker) {
            StoryReactionPicker_Legacy(isPresented: $showReactionPicker) { emoji in
                handleReaction(emoji)
            }
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: isComposing) { _, newValue in
            isPaused = newValue
        }
        .onChange(of: isTextFocused) { _, newValue in
            isPaused = newValue
        }
        .onChange(of: showReactionPicker) { _, newValue in
            if newValue {
                isPaused = true
            }
        }
    }

    private var quickReactionsRow: some View {
        HStack(spacing: 12) {
                    ForEach(quickReactions, id: \.self) { emoji in
                        Button {
                            handleReaction(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // More emojis button
                    Button {
                        isTextFocused = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showReactionPicker = true
                        }
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            if isComposing {
                // Camera icon (Instagram style)
                Button(action: { /* TODO: open camera reply */ }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .leading) {
                // Placeholder when not composing
                if !isComposing {
                    HStack(spacing: 8) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Enviar mensaje")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                // Text input when composing
                if isComposing {
                    TextField("Enviar mensaje", text: $messageText)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .submitLabel(.send)
                        .focused($isTextFocused)
                        .onSubmit { sendMessage() }
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isComposing else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isComposing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFocused = true
                }
            }

            if isComposing {
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Group {
                                if messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                } else {
                                    Circle()
                                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                // Heart quick reaction (like Instagram)
                Button {
                    handleReaction("❤️")
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.red)
                                .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: -4)
        )
    }

    private func handleReaction(_ emoji: String) {
        onReact(emoji)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        onSendMessage(text)
        messageText = ""

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isComposing = false
        }
        isTextFocused = false

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}
