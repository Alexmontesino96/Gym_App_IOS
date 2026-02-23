import SwiftUI

// MARK: - DayCompleteCelebrationView

/// Celebración full-screen cuando el usuario completa todas las comidas del día
/// Muestra confetti, racha actual, y progreso en el challenge
struct DayCompleteCelebrationView: View {
    // MARK: - Properties

    let currentStreak: Int
    let currentDay: Int
    let totalDays: Int
    let onContinue: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    @State private var showConfetti = false
    @State private var scaleAnimation: CGFloat = 0.5
    @State private var opacityAnimation: Double = 0
    @State private var streakBounce: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacityAnimation)

            // Main celebration card
            VStack(spacing: 32) {
                Spacer()

                celebrationCard

                Spacer()

                // Continue button
                continueButton
            }
            .padding(24)
            .scaleEffect(scaleAnimation)
            .opacity(opacityAnimation)

            // Confetti overlay
            if showConfetti {
                ConfettiView(particleCount: 60)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            performAnimations()
        }
    }

    // MARK: - Celebration Card

    private var celebrationCard: some View {
        VStack(spacing: 28) {
            // Trophy icon with pulse
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFD700") ?? .yellow,
                                Color(hex: "#FFA500") ?? .orange
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .yellow.opacity(0.5), radius: 20)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .scaleEffect(streakBounce)

            // Congratulations text
            VStack(spacing: 8) {
                Text("¡Día Completado!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("Has terminado todas tus comidas del día")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }

            // Streak display
            if currentStreak > 0 {
                streakBadge
            }

            // Progress in challenge
            challengeProgressSection
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        )
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 24))
                .foregroundColor(streakColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("RACHA")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .tracking(1)

                Text("\(currentStreak) \(currentStreak == 1 ? "día" : "días") consecutivos")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()

            Text(streakEmoji)
                .font(.system(size: 32))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(streakColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(streakColor.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Challenge Progress Section

    private var challengeProgressSection: some View {
        VStack(spacing: 12) {
            // Progress text
            HStack {
                Text("PROGRESO DEL CHALLENGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .tracking(1)

                Spacer()

                Text("Día \(currentDay) de \(totalDays)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dynamicAccent(theme: themeManager.currentTheme),
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage)
                }
            }
            .frame(height: 12)

            // Percentage text
            Text("\(Int(progressPercentage * 100))% completado")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.top, 8)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            withAnimation(.easeOut(duration: 0.2)) {
                opacityAnimation = 0
                scaleAnimation = 0.9
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onContinue()
            }
        }) {
            HStack(spacing: 8) {
                Text("Continuar")
                    .font(.system(size: 17, weight: .semibold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
            )
        }
    }

    // MARK: - Computed Properties

    private var progressPercentage: CGFloat {
        guard totalDays > 0 else { return 0 }
        return CGFloat(currentDay) / CGFloat(totalDays)
    }

    private var streakColor: Color {
        switch currentStreak {
        case 1...3: return Color(hex: "#FFB300") ?? .orange
        case 4...6: return Color(hex: "#FF6B00") ?? .orange
        case 7...13: return Color(hex: "#FF5722") ?? .red
        case 14...: return Color(hex: "#D32F2F") ?? .red
        default: return .orange
        }
    }

    private var streakEmoji: String {
        switch currentStreak {
        case 1...3: return "🔥"
        case 4...6: return "🔥🔥"
        case 7...13: return "🔥🔥🔥"
        case 14...: return "⚡️"
        default: return "🔥"
        }
    }

    // MARK: - Animations

    private func performAnimations() {
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        // Show confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showConfetti = true
            }
        }

        // Card entrance animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scaleAnimation = 1.0
            opacityAnimation = 1.0
        }

        // Trophy bounce
        withAnimation(
            .spring(response: 0.4, dampingFraction: 0.5)
                .repeatCount(3, autoreverses: true)
                .delay(0.4)
        ) {
            streakBounce = 1.2
        }

        // Reset bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                streakBounce = 1.0
            }
        }

        // Hide confetti after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showConfetti = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Día 7 - Racha 7") {
    ZStack {
        Color.black.ignoresSafeArea()

        DayCompleteCelebrationView(
            currentStreak: 7,
            currentDay: 7,
            totalDays: 21,
            onContinue: {}
        )
        .environmentObject(ThemeManager())
    }
}

#Preview("Día 1 - Primera vez") {
    ZStack {
        Color.black.ignoresSafeArea()

        DayCompleteCelebrationView(
            currentStreak: 1,
            currentDay: 1,
            totalDays: 21,
            onContinue: {}
        )
        .environmentObject(ThemeManager())
    }
}

#Preview("Día 15 - Racha larga") {
    ZStack {
        Color.black.ignoresSafeArea()

        DayCompleteCelebrationView(
            currentStreak: 15,
            currentDay: 15,
            totalDays: 21,
            onContinue: {}
        )
        .environmentObject(ThemeManager())
    }
}

#Preview("Dark Mode") {
    ZStack {
        Color.black.ignoresSafeArea()

        DayCompleteCelebrationView(
            currentStreak: 10,
            currentDay: 10,
            totalDays: 21,
            onContinue: {}
        )
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
    }
}
