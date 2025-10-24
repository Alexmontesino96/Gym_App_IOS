import SwiftUI

// MARK: - Comeback Hero Section
/// Sección hero para la vista de comeback con mensaje emocional y animación
struct ComebackHeroSection: View {
    let message: ComebackMessage
    let userName: String
    let theme: ThemeManager.AppTheme

    @State private var isAnimating = false
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            // Emoji animado grande
            emojiSection

            // Título principal
            Text(message.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.dynamicText(theme: theme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Mensaje personalizado
            Text(message.message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .scaleEffect(isAnimating ? 1.0 : 0.9)
        .opacity(isAnimating ? 1.0 : 0.0)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Subviews

    private var emojiSection: some View {
        ZStack {
            // Glow effect basado en urgencia
            if message.urgency == .high || message.urgency == .critical {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                (Color(hex: message.urgency.color) ?? Color.dynamicAccent(theme: theme)).opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.0 : 0.5)
            }

            // Emoji principal
            Text(message.emoji)
                .font(.system(size: 80))
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .rotationEffect(.degrees(isAnimating ? 0 : -10))
        }
        .frame(height: 120)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Entrada principal con spring animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isAnimating = true
        }

        // Pulse animation para urgencia alta - iniciar después de la entrada
        if message.urgency == .high || message.urgency == .critical {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseAnimation = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        // Tema oscuro - Urgencia baja
        ComebackHeroSection(
            message: ComebackMessage(
                emoji: "🌟",
                title: "¡Hoy es el día!",
                message: "Tu cuerpo te está esperando, Alex",
                tone: .encouraging,
                urgency: .medium
            ),
            userName: "Alex",
            theme: .dark
        )
        .background(Color.dynamicBackground(theme: .dark))

        Divider()

        // Tema claro - Urgencia alta
        ComebackHeroSection(
            message: ComebackMessage(
                emoji: "🔥",
                title: "¡Enciende tu fuego interior!",
                message: "Llevas 10 días fuera. Recuerda tu racha de antes.",
                tone: .challenging,
                urgency: .high
            ),
            userName: "Alex",
            theme: .light
        )
        .background(Color.dynamicBackground(theme: .light))
    }
    .padding()
}
