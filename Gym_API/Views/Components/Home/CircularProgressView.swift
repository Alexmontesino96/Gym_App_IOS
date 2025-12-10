import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0.0 - 1.0
    let current: Int
    let goal: Int
    let title: String
    let emoji: String
    let gradientColors: [Color]
    var theme: ThemeManager.AppTheme = .dark

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(
                        Color.dynamicTextSecondary(theme: theme).opacity(0.2),
                        lineWidth: 6
                    )
                    .frame(width: 70, height: 70)

                // Progress circle with gradient
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270 * animatedProgress - 90)
                        ),
                        style: StrokeStyle(
                            lineWidth: 6,
                            lineCap: .round
                        )
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text(emoji)
                        .font(.title2)
                    Text("\(current)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }

            // Label
            VStack(spacing: 2) {
                Text("\(current)/\(goal)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme).opacity(0.9))

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }
        }
        .frame(width: 85)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}

#Preview {
    ZStack {
        Color.dynamicBackground(theme: .dark).ignoresSafeArea()

        HStack(spacing: 24) {
            CircularProgressView(
                progress: 0.71,
                current: 5,
                goal: 7,
                title: "Streak",
                emoji: "🔥",
                gradientColors: [.orange, .red],
                theme: .dark
            )

            CircularProgressView(
                progress: 0.75,
                current: 3,
                goal: 4,
                title: "Workouts",
                emoji: "💪",
                gradientColors: [.pink, .purple],
                theme: .dark
            )

            CircularProgressView(
                progress: 0.67,
                current: 8,
                goal: 12,
                title: "Classes",
                emoji: "📅",
                gradientColors: [.blue, .purple],
                theme: .dark
            )
        }
    }
}
