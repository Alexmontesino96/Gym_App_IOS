import SwiftUI

struct HeroClassCard: View {
    let gymClass: GymClass
    let onViewTapped: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isPressed = false

    // Gradiente según tipo de clase (WCAG Compliant)
    var gradient: LinearGradient {
        let colors: [Color]
        let className = gymClass.name.lowercased()

        if className.contains("strength") || className.contains("weight") {
            colors = [Color(hex: "#FF416C") ?? .red, Color(hex: "#FF4B2B") ?? .red] // Rojo-rosa
        } else if className.contains("cardio") || className.contains("run") || className.contains("hiit") {
            // Actualizado para WCAG - Naranja con mejor contraste (4.1:1) ✅
            colors = [Color.activityGradientStart, Color.activityGradientEnd]
        } else if className.contains("yoga") || className.contains("pilates") {
            colors = [Color(hex: "#4776E6") ?? .blue, Color(hex: "#8E54E9") ?? .purple] // Azul-púrpura
        } else if className.contains("crossfit") || className.contains("functional") {
            // Actualizado para diferenciarse de nutrición - Verde funcional (5.1:1) ✅
            colors = [Color.functionalGradientStart, Color.functionalGradientEnd]
        } else if className.contains("box") || className.contains("kick") || className.contains("striking") {
            colors = [Color(hex: "#D93333") ?? .red, Color(hex: "#8E2DE2") ?? .purple] // Rojo gym-púrpura
        } else {
            colors = [Color(hex: "#D93333") ?? .red, Color(hex: "#8E2DE2") ?? .purple] // Default: rojo gym
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card principal
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    // Ícono de categoría
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: categoryIcon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Spacer()
                }

                // Título
                Text(gymClass.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                // Horario y trainer
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(formatTime(gymClass.startTime))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.95))

                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                        Text(gymClass.instructor)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 180)
            .background(gradient)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
            .scaleEffect(isPressed ? 0.98 : 1.0)

            // Botón VIEW
            Button(action: {
                HapticManager.shared.buttonTap()
                withAnimation(.spring(response: 0.3)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3)) {
                        isPressed = false
                    }
                    onViewTapped()
                }
            }) {
                Text("VIEW")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .padding([.top, .trailing], 16)
        }
    }

    // MARK: - Helper Properties

    private var categoryIcon: String {
        let className = gymClass.name.lowercased()

        if className.contains("box") || className.contains("kick") || className.contains("striking") {
            return "figure.boxing"
        } else if className.contains("yoga") {
            return "figure.mind.and.body"
        } else if className.contains("run") || className.contains("cardio") || className.contains("hiit") {
            return "figure.run"
        } else if className.contains("strength") || className.contains("weight") {
            return "dumbbell.fill"
        } else if className.contains("dance") {
            return "figure.dance"
        } else if className.contains("cycle") || className.contains("spin") {
            return "figure.indoor.cycle"
        } else if className.contains("swim") {
            return "figure.pool.swim"
        } else if className.contains("climb") {
            return "figure.climbing"
        } else if className.contains("crossfit") || className.contains("functional") {
            return "figure.highintensity.intervaltraining"
        } else {
            return "figure.walk"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HeroClassCard(
            gymClass: GymClass(
                id: 1,
                name: "Striking Basics",
                description: "Aprende los fundamentos del striking",
                instructor: "Carlos Ruiz",
                trainerId: 1,
                startTime: Date().addingTimeInterval(7200), // En 2 horas
                endTime: Date().addingTimeInterval(10800), // 3 horas después
                maxParticipants: 20,
                currentParticipants: 12,
                difficulty: .intermediate,
                status: .available
            ),
            onViewTapped: {
                print("View tapped")
            }
        )
        .environmentObject(ThemeManager())
    }
}
