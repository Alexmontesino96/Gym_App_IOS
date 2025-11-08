//
//  StoryReactionBar.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI

struct StoryReactionBar: View {
    let story: Story
    let onReaction: (String) -> Void
    let onMessage: () -> Void

    @State private var showingAllReactions = false
    @State private var selectedReaction: String?
    @State private var showReactionAnimation = false

    // Quick reactions to show
    private let quickReactions = ["🔥", "💪", "👏", "❤️", "💯"]

    var body: some View {
        HStack(spacing: 16) {
            // Quick reaction buttons
            HStack(spacing: 12) {
                ForEach(quickReactions, id: \.self) { emoji in
                    ReactionButton(
                        emoji: emoji,
                        isSelected: selectedReaction == emoji,
                        onTap: {
                            sendReaction(emoji)
                        }
                    )
                }

                // More reactions button
                Button(action: { showingAllReactions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
            }

            Spacer()

            // Message button
            if !story.isOwnStory {
                Button(action: onMessage) {
                    HStack(spacing: 8) {
                        Image(systemName: "message")
                        Text("Responder")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
        .sheet(isPresented: $showingAllReactions) {
            AllReactionsView(onSelect: sendReaction)
                .presentationDetents([.height(200)])
        }
        .overlay(
            // Reaction animation overlay
            Group {
                if showReactionAnimation, let reaction = selectedReaction {
                    FloatingReaction(emoji: reaction)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showReactionAnimation = false
                                selectedReaction = nil
                            }
                        }
                }
            }
        )
    }

    private func sendReaction(_ emoji: String) {
        selectedReaction = emoji
        showReactionAnimation = true
        onReaction(emoji)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Reaction Button
struct ReactionButton: View {
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(emoji)
            .font(.system(size: 24))
            .scaleEffect(isPressed ? 1.3 : (isSelected ? 1.1 : 1.0))
            .opacity(isSelected ? 1 : 0.9)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.clear)
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isPressed = true
                }
                onTap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        isPressed = false
                    }
                }
            }
    }
}

// MARK: - All Reactions View
struct AllReactionsView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Reacciones")
                .font(.headline)
                .padding(.top)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                ForEach(FitnessEmoji.allCases, id: \.rawValue) { reaction in
                    VStack(spacing: 4) {
                        Text(reaction.rawValue)
                            .font(.system(size: 32))
                            .onTapGesture {
                                onSelect(reaction.rawValue)
                                dismiss()
                            }

                        Text(reaction.meaning)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - Floating Reaction Animation
struct FloatingReaction: View {
    let emoji: String
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text(emoji)
            .font(.system(size: 50))
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    offset = -150
                    opacity = 0
                }
            }
    }
}