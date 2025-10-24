import SwiftUI

// MARK: - Last Activity Card
/// Card que muestra la última clase asistida y la mejor racha del usuario
struct LastActivityCard: View {
    let lastClass: String?
    let daysAgo: Int
    let bestStreak: Int
    let theme: ThemeManager.AppTheme

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            // Última clase asistida
            if let lastClass = lastClass, daysAgo > 0 {
                lastClassSection
            }

            // Mejor racha histórica
            if bestStreak > 0 {
                bestStreakSection
            }

            // Si no hay datos
            if lastClass == nil && bestStreak == 0 {
                emptyStateSection
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.dynamicBorder(theme: theme), lineWidth: 1)
                )
        )
        .opacity(isAnimating ? 1.0 : 0.0)
        .offset(y: isAnimating ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Subviews

    private var lastClassSection: some View {
        HStack(spacing: 12) {
            // Icono
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: theme).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "figure.run")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
            }

            // Texto
            VStack(alignment: .leading, spacing: 4) {
                Text("Tu última clase")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                Text(lastClass ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)

                Text(daysAgoText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }

            Spacer()
        }
    }

    private var bestStreakSection: some View {
        HStack(spacing: 12) {
            // Icono de fuego
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
            }

            // Texto
            VStack(alignment: .leading, spacing: 4) {
                Text("Tu mejor racha")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                HStack(spacing: 6) {
                    Text("\(bestStreak)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color.dynamicText(theme: theme))

                    Text("días")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .padding(.top, 4)
                }
            }

            Spacer()

            // Badge de logro
            if bestStreak >= 7 {
                Image(systemName: bestStreak >= 30 ? "crown.fill" : "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
            }
        }
    }

    private var emptyStateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))

            Text("Es hora de empezar tu primera clase")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var daysAgoText: String {
        if daysAgo == 0 {
            return "Hoy"
        } else if daysAgo == 1 {
            return "Ayer"
        } else {
            return "Hace \(daysAgo) días"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Con datos completos
        LastActivityCard(
            lastClass: "Spinning Avanzado",
            daysAgo: 5,
            bestStreak: 12,
            theme: .dark
        )
        .padding()
        .background(Color.dynamicBackground(theme: .dark))

        // Solo con mejor racha
        LastActivityCard(
            lastClass: nil,
            daysAgo: 0,
            bestStreak: 30,
            theme: .light
        )
        .padding()
        .background(Color.dynamicBackground(theme: .light))

        // Estado vacío
        LastActivityCard(
            lastClass: nil,
            daysAgo: 0,
            bestStreak: 0,
            theme: .dark
        )
        .padding()
        .background(Color.dynamicBackground(theme: .dark))
    }
}
