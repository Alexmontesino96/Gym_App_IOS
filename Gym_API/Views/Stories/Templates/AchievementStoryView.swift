//
//  AchievementStoryView.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI

struct AchievementStoryView: View {
    let story: Story

    @State private var showConfetti = false
    @State private var trophyScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "FFD700")?.opacity(0.8) ?? Color.yellow.opacity(0.8),
                    Color(hex: "D93333") ?? Color.red,
                    Color(hex: "1A1A2E") ?? Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Particle effect background
            if showConfetti {
                StoryConfettiView()
            }

            VStack(spacing: 40) {
                Spacer()

                // Trophy with glow effect
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .opacity(glowOpacity)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: glowOpacity
                        )

                    // Trophy icon
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        .scaleEffect(trophyScale)
                        .rotationEffect(.degrees(showConfetti ? 360 : 0))
                }

                // Achievement text
                VStack(spacing: 16) {
                    Text("¡LOGRO DESBLOQUEADO!")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5)

                    // Achievement description from caption
                    if let caption = story.caption {
                        Text(caption)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    // Achievement badge
                    HStack(spacing: 8) {
                        ForEach(0..<3) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                }

                Spacer()

                // Motivational message
                VStack(spacing: 12) {
                    Text("¡SIGUE ASÍ CAMPEÓN!")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .tracking(2)

                    Text(Date(), style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                trophyScale = 1.0
                showConfetti = true
                glowOpacity = 1.0
            }
        }
    }
}

// MARK: - Confetti View
struct StoryConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
    }

    private func generateConfetti(in size: CGSize) {
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                startY: -50,
                endY: size.height + 50,
                color: [Color.red, Color.yellow, Color.green, Color.blue, Color.purple].randomElement()!,
                size: CGFloat.random(in: 8...16),
                duration: Double.random(in: 2...4)
            )
            confettiPieces.append(piece)
        }
    }
}

// MARK: - Confetti Piece Model
struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let duration: Double
}

// MARK: - Confetti Piece View
struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var yPosition: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 2)
            .position(x: piece.x, y: yPosition)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                yPosition = piece.startY
                withAnimation(
                    .linear(duration: piece.duration)
                    .repeatForever(autoreverses: false)
                ) {
                    yPosition = piece.endY
                    rotation = 360
                }
            }
    }
}

// MARK: - Preview
struct AchievementStoryView_Previews: PreviewProvider {
    static var previews: some View {
        let story = Story(
            id: 1,
            gymId: 1,
            userId: 1,
            storyType: .achievement,
            caption: "¡100 días consecutivos de entrenamiento!",
            privacy: .public,
            mediaUrl: nil,
            thumbnailUrl: nil,
            workoutData: nil,
            viewCount: 0,
            reactionCount: 0,
            isPinned: false,
            isExpired: false,
            isOwnStory: true,
            hasViewed: false,
            hasReacted: false,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400),
            userInfo: StoryUserInfo(id: 1, name: "Test User", avatar: nil)
        )

        AchievementStoryView(story: story)
    }
}