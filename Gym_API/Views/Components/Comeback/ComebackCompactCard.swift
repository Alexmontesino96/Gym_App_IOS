import SwiftUI

// MARK: - Comeback Compact Card
/// Versión compacta del indicador de comeback para HomeView
/// Se muestra en lugar del StreakIndicator cuando la racha está en 0
struct ComebackCompactCard: View {
    let daysInactive: Int
    let theme: ThemeManager.AppTheme

    @State private var isAnimating = false
    @State private var pulseAnimation = false

    // MARK: - Computed Properties

    private var message: String {
        switch daysInactive {
        case 1:
            return "Te extrañamos 💙 · Tap para agendar"
        case 2...3:
            return "\(daysInactive) días sin verte 😢"
        case 4...7:
            return "¡Es hora de volver! 🔥"
        case 8...14:
            return "Llevas \(daysInactive) días fuera..."
        case 15...30:
            return "¿Volvemos juntos? 💪"
        default:
            return "¡Empecemos hoy! 🌟"
        }
    }

    private var urgency: ComebackMessage.UrgencyLevel {
        switch daysInactive {
        case 1...3:
            return .medium
        case 4...7:
            return .high
        default:
            return .critical
        }
    }

    private var backgroundColor: Color {
        switch urgency {
        case .medium:
            return Color.dynamicSurface(theme: theme)
        case .high:
            return (Color(hex: "#FF6B6B") ?? Color.dynamicAccent(theme: theme)).opacity(0.1)
        case .critical:
            return (Color(hex: "#FF8C42") ?? Color.dynamicAccent(theme: theme)).opacity(0.1)
        default:
            return Color.dynamicSurface(theme: theme)
        }
    }

    private var borderColor: Color {
        switch urgency {
        case .medium:
            return Color.dynamicAccent(theme: theme).opacity(0.3)
        case .high:
            return (Color(hex: "#FF6B6B") ?? Color.dynamicAccent(theme: theme)).opacity(0.5)
        case .critical:
            return (Color(hex: "#FF8C42") ?? Color.dynamicAccent(theme: theme)).opacity(0.5)
        default:
            return Color.dynamicBorder(theme: theme)
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Icono con animación
            iconView

            // Mensaje
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            // Icono de chevron
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color.dynamicAccent(theme: theme).opacity(0.6))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(backgroundColor)
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1.5)
                )
        )
        .scaleEffect(isAnimating ? 1.0 : 0.95)
        .opacity(isAnimating ? 1.0 : 0.0)
        .onAppear {
            startAnimations()
        }
        .accessibilityLabel("Mensaje de comeback: \(message)")
        .accessibilityHint("Toca para ver más detalles y agendar tu clase")
    }

    // MARK: - Subviews

    private var iconView: some View {
        ZStack {
            // Pulse effect para urgencia alta/crítica
            if urgency == .high || urgency == .critical {
                Circle()
                    .fill(Color.dynamicAccent(theme: theme).opacity(0.3))
                    .frame(width: 32, height: 32)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                    .opacity(pulseAnimation ? 0.0 : 0.6)
            }

            // Icono principal
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
                .rotationEffect(.degrees(isAnimating ? 3 : -3))
        }
        .frame(width: 32, height: 32)
    }

    private var iconName: String {
        switch daysInactive {
        case 1...3:
            return "heart.fill"
        case 4...7:
            return "flame.fill"
        case 8...14:
            return "clock.arrow.circlepath"
        default:
            return "star.fill"
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Animación de entrada
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            isAnimating = true
        }

        // Animación de rotación del icono - iniciar después de la entrada
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }

        // Pulse animation para urgencia alta - iniciar después de la entrada
        if urgency == .high || urgency == .critical {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    pulseAnimation = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Text("Tema Oscuro")
            .font(.title2)

        // 1 día inactivo
        ComebackCompactCard(daysInactive: 1, theme: .dark)

        // 5 días inactivos
        ComebackCompactCard(daysInactive: 5, theme: .dark)

        // 10 días inactivos
        ComebackCompactCard(daysInactive: 10, theme: .dark)

        // 20 días inactivos
        ComebackCompactCard(daysInactive: 20, theme: .dark)

        Divider()

        Text("Tema Claro")
            .font(.title2)

        ComebackCompactCard(daysInactive: 5, theme: .light)
    }
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.dynamicBackground(theme: .dark), location: 0.0),
                .init(color: Color.dynamicBackground(theme: .light), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
