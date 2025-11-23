import SwiftUI

/// Emoji volador para animaciones de reacciones
struct FlyingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var offset: CGSize
    var opacity: Double
    var scale: CGFloat
    var rotation: Double
}

/// Vista de animación para emojis voladores en stories
struct StoryReactionAnimation: View {
    @Binding var reactions: [FlyingEmoji]

    var body: some View {
        ZStack {
            ForEach(reactions) { reaction in
                Text(reaction.emoji)
                    .font(.system(size: 40))
                    .opacity(reaction.opacity)
                    .scaleEffect(reaction.scale)
                    .rotationEffect(.degrees(reaction.rotation))
                    .offset(reaction.offset)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Manager para controlar las animaciones de emojis voladores
@MainActor
class ReactionAnimationManager: ObservableObject {
    @Published var flyingEmojis: [FlyingEmoji] = []

    /// Agrega un nuevo emoji volador con animación
    func addReaction(_ emoji: String, startPosition: CGPoint = CGPoint(x: 0, y: 0)) {
        // Crear emoji en posición inicial
        let newEmoji = FlyingEmoji(
            emoji: emoji,
            offset: CGSize(width: startPosition.x, height: startPosition.y),
            opacity: 1.0,
            scale: 0.1,
            rotation: 0
        )

        flyingEmojis.append(newEmoji)

        // Animar aparición
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if let index = flyingEmojis.firstIndex(where: { $0.id == newEmoji.id }) {
                flyingEmojis[index].scale = 1.2
            }
        }

        // Generar trayectoria aleatoria
        let randomX = CGFloat.random(in: -80...80)
        let randomY = CGFloat.random(in: -200...(-100))
        let randomRotation = Double.random(in: -45...45)

        // Animar movimiento hacia arriba
        withAnimation(.easeOut(duration: 1.5)) {
            if let index = flyingEmojis.firstIndex(where: { $0.id == newEmoji.id }) {
                flyingEmojis[index].offset = CGSize(
                    width: startPosition.x + randomX,
                    height: startPosition.y + randomY
                )
                flyingEmojis[index].rotation = randomRotation
            }
        }

        // Animar fade out
        withAnimation(.easeIn(duration: 0.8).delay(0.7)) {
            if let index = flyingEmojis.firstIndex(where: { $0.id == newEmoji.id }) {
                flyingEmojis[index].opacity = 0
                flyingEmojis[index].scale = 0.5
            }
        }

        // Eliminar después de la animación
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000) // 1.6 segundos
            await MainActor.run {
                flyingEmojis.removeAll { $0.id == newEmoji.id }
            }
        }
    }

    /// Limpia todas las animaciones
    func clearAllReactions() {
        flyingEmojis.removeAll()
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var animationManager = ReactionAnimationManager()

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                // Animaciones
                StoryReactionAnimation(reactions: $animationManager.flyingEmojis)

                VStack {
                    Spacer()

                    // Botones de prueba
                    HStack(spacing: 20) {
                        ForEach(["🔥", "😍", "👏", "😂", "😮", "💯"], id: \.self) { emoji in
                            Button(action: {
                                animationManager.addReaction(emoji, startPosition: CGPoint(x: 0, y: 300))
                            }) {
                                Text(emoji)
                                    .font(.system(size: 32))
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }

    return PreviewWrapper()
}
