//
//  StoryReactionAnimations.swift
//  Gym_API
//
//  Reaction confirmation animations for stories
//  Includes: Large emoji confirmation, double-tap heart, send animation
//  Design doc: STORY_REACTION_UX_REDESIGN.md - Section 4.3, 6.5
//
//  Created on December 2024
//

import SwiftUI

// MARK: - Reaction Confirmation View
/// Large centered emoji animation when reaction is sent
/// Animation sequence from design doc section 4.3:
/// 1. Emoji appears large (80px) in center
/// 2. Scale up from 0.3 to 1.2 (spring animation)
/// 3. Pause 300ms
/// 4. Contracts and travels toward creator avatar
/// 5. Disappears with fade
struct StoryReactionConfirmation: View {
    // MARK: - Properties
    let emoji: String

    // MARK: - State
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 1.0
    @State private var offset: CGSize = .zero

    // MARK: - Body
    var body: some View {
        Text(emoji)
            .font(.system(size: StoryInteractionTokens.Sizes.emojiConfirmation))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .shadow(color: StoryInteractionTokens.Colors.accent.opacity(0.4), radius: 20, x: 0, y: 0)
            .onAppear {
                runAnimation()
            }
    }

    // MARK: - Animation Sequence
    private func runAnimation() {
        // Phase 1: Scale up with spring (0.3s)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.2
        }

        // Phase 2: Hold for 300ms, then Phase 3: Contract and move up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.4)) {
                scale = 0.0
                opacity = 0.0
                // Move toward top where avatar would be
                offset = CGSize(width: 0, height: -300)
            }
        }
    }
}

// MARK: - Double Tap Heart Animation
/// Large heart animation for double-tap gesture on story
/// Similar to Instagram's double-tap like animation
struct DoubleTapHeartAnimation: View {
    // MARK: - Properties
    let onComplete: () -> Void

    // MARK: - State
    @State private var scale: CGFloat = 0.0
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0

    // MARK: - Body
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 100, weight: .bold))
            .foregroundColor(StoryInteractionTokens.Colors.accent)
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .shadow(color: StoryInteractionTokens.Colors.accent.opacity(0.5), radius: 30, x: 0, y: 0)
            .onAppear {
                runAnimation()
            }
    }

    // MARK: - Animation Sequence
    private func runAnimation() {
        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Phase 1: Pop in with slight rotation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale = 1.3
            rotation = -10
        }

        // Phase 2: Settle to normal size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 1.0
                rotation = 0
            }
        }

        // Phase 3: Hold briefly then fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 0.8
                opacity = 0.0
            }
        }

        // Notify completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            onComplete()
        }
    }
}

// MARK: - Particle Explosion Effect
/// Small particle explosion around a reaction point
struct ReactionParticleExplosion: View {
    // MARK: - Properties
    let emoji: String
    let position: CGPoint

    // MARK: - State
    @State private var particles: [ReactionParticle] = []
    @State private var isAnimating = false

    // MARK: - Constants
    private let particleCount = 8
    private let explosionRadius: CGFloat = 60

    // MARK: - Body
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(emoji)
                    .font(.system(size: particle.size))
                    .opacity(particle.opacity)
                    .offset(x: particle.offset.width, y: particle.offset.height)
                    .rotationEffect(.degrees(particle.rotation))
            }
        }
        .position(position)
        .onAppear {
            createParticles()
            animateParticles()
        }
    }

    // MARK: - Particle Creation
    private func createParticles() {
        particles = (0..<particleCount).map { index in
            let angle = (Double(index) / Double(particleCount)) * 2 * .pi
            return ReactionParticle(
                angle: angle,
                size: CGFloat.random(in: 12...20),
                offset: .zero,
                opacity: 1.0,
                rotation: Double.random(in: -45...45)
            )
        }
    }

    // MARK: - Particle Animation
    private func animateParticles() {
        // Explode outward
        withAnimation(.easeOut(duration: 0.4)) {
            for index in particles.indices {
                let angle = particles[index].angle
                particles[index].offset = CGSize(
                    width: cos(angle) * explosionRadius,
                    height: sin(angle) * explosionRadius
                )
                particles[index].rotation += Double.random(in: -90...90)
            }
        }

        // Fade out
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            for index in particles.indices {
                particles[index].opacity = 0
                particles[index].size *= 0.5
            }
        }
    }
}

// MARK: - Reaction Particle Model
struct ReactionParticle: Identifiable {
    let id = UUID()
    var angle: Double
    var size: CGFloat
    var offset: CGSize
    var opacity: Double
    var rotation: Double
}

// MARK: - Message Sent Animation
/// Brief animation shown when a message is successfully sent
struct MessageSentAnimation: View {
    // MARK: - Properties
    let onComplete: () -> Void

    // MARK: - State
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0
    @State private var offset: CGFloat = 0

    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(StoryInteractionTokens.Colors.success)

            Text("Enviado")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(StoryInteractionTokens.Colors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(StoryInteractionTokens.Colors.glassSurfaceActive)
                .overlay(
                    Capsule()
                        .stroke(StoryInteractionTokens.Colors.success.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            runAnimation()
        }
    }

    // MARK: - Animation
    private func runAnimation() {
        // Pop in
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            scale = 1.0
        }

        // Move up slightly and fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                offset = -20
                opacity = 0
            }
        }

        // Notify completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            onComplete()
        }
    }
}

// MARK: - Reaction Overlay Container
/// Container view that manages reaction animations overlaid on story
struct StoryReactionOverlay: View {
    // MARK: - Properties
    @Binding var showDoubleTapHeart: Bool
    @Binding var showReactionConfirmation: Bool
    @Binding var confirmationEmoji: String?
    @Binding var showMessageSent: Bool
    let onReactionSent: (String) -> Void

    // MARK: - Body
    var body: some View {
        ZStack {
            // Double-tap heart
            if showDoubleTapHeart {
                DoubleTapHeartAnimation {
                    showDoubleTapHeart = false
                }
            }

            // Reaction confirmation
            if showReactionConfirmation, let emoji = confirmationEmoji {
                StoryReactionConfirmation(emoji: emoji)
                    .onAppear {
                        onReactionSent(emoji)

                        // Auto-dismiss after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showReactionConfirmation = false
                            confirmationEmoji = nil
                        }
                    }
            }

            // Message sent confirmation
            if showMessageSent {
                MessageSentAnimation {
                    showMessageSent = false
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Previews
#Preview("Reaction Confirmation") {
    ZStack {
        Color.black.ignoresSafeArea()

        StoryReactionConfirmation(emoji: "🔥")
    }
}

#Preview("Double Tap Heart") {
    ZStack {
        // Simulated story background
        LinearGradient(
            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        DoubleTapHeartAnimation {
            print("Animation complete")
        }
    }
}

#Preview("Message Sent") {
    ZStack {
        Color.black.ignoresSafeArea()

        MessageSentAnimation {
            print("Animation complete")
        }
    }
}

#Preview("Particle Explosion") {
    ZStack {
        Color.black.ignoresSafeArea()

        ReactionParticleExplosion(
            emoji: "🔥",
            position: CGPoint(x: 200, y: 400)
        )
    }
}

#Preview("Full Overlay") {
    struct PreviewWrapper: View {
        @State private var showHeart = false
        @State private var showReaction = false
        @State private var emoji: String? = nil
        @State private var showMessage = false

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Button("Show Heart") {
                        showHeart = true
                    }

                    Button("Show Fire Reaction") {
                        emoji = "🔥"
                        showReaction = true
                    }

                    Button("Show Message Sent") {
                        showMessage = true
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)

                StoryReactionOverlay(
                    showDoubleTapHeart: $showHeart,
                    showReactionConfirmation: $showReaction,
                    confirmationEmoji: $emoji,
                    showMessageSent: $showMessage,
                    onReactionSent: { emoji in
                        print("Reaction sent: \(emoji)")
                    }
                )
            }
        }
    }

    return PreviewWrapper()
}
