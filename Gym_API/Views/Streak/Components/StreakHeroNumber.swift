import SwiftUI

/// Hero number component for streak display with fire animations
struct StreakHeroNumber: View {
    let count: Int
    let theme: ThemeManager.AppTheme

    @State private var fireScale = 1.0
    @State private var numberScale = 1.0
    @State private var glowIntensity = 0.5
    @State private var showParticles = false
    @State private var particleOpacity = 0.0

    // Fire gradient colors
    private let fireGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.42, blue: 0.42),  // #FF6B6B
            Color(red: 0.85, green: 0.2, blue: 0.2),   // #D93333
            Color(red: 0.55, green: 0.0, blue: 0.0)    // #8B0000
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(fireGradient)
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .opacity(glowIntensity * 0.6)
                    .scaleEffect(fireScale)

                // Floating particles
                if showParticles {
                    ForEach(0..<8, id: \.self) { index in
                        FloatingParticle(
                            index: index,
                            opacity: particleOpacity
                        )
                    }
                }

                // Main number with gradient
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(fireGradient)
                        .scaleEffect(numberScale)
                        .shadow(color: Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.5), radius: 10)

                    Text("DÍAS")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .tracking(4)
                }
            }
            .frame(height: 220)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Number entrance animation
        numberScale = 0.5
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            numberScale = 1.0
        }

        // Continuous fire pulse
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            fireScale = 1.1
            glowIntensity = 0.8
        }

        // Show particles with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showParticles = true
            withAnimation(.easeIn(duration: 0.5)) {
                particleOpacity = 1.0
            }
        }
    }
}

// MARK: - Floating Particle Component
private struct FloatingParticle: View {
    let index: Int
    let opacity: Double

    @State private var offset: CGFloat = 0
    @State private var particleOpacity: Double = 0.8

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(
                Color(
                    red: 1.0,
                    green: Double.random(in: 0.4...0.6),
                    blue: Double.random(in: 0.2...0.4)
                )
            )
            .offset(y: offset)
            .opacity(particleOpacity * opacity)
            .rotationEffect(.degrees(Double(index) * 45))
            .offset(particlePosition)
            .onAppear {
                startFloating()
            }
    }

    private var particlePosition: CGSize {
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180
        let radius: CGFloat = 80
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }

    private func startFloating() {
        withAnimation(
            .easeInOut(duration: Double.random(in: 2.0...3.0))
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.2)
        ) {
            offset = -20
            particleOpacity = 0.3
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        StreakHeroNumber(count: 47, theme: .dark)
            .padding()
            .background(Color.dynamicBackground(theme: .dark))
    }
}
