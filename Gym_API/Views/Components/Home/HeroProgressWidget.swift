import SwiftUI

/// Interactive hero widget showing weekly workout progress with circular graphs and animations
struct HeroProgressWidget: View {
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var currentView: ProgressView = .weekly
    @State private var progressValue: Double = 0
    @State private var showParticles = false
    @State private var animateIn = false

    enum ProgressView: String, CaseIterable {
        case weekly = "Semanal"
        case monthly = "Mensual"
        case yearly = "Anual"

        var icon: String {
            switch self {
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar"
            case .yearly: return "chart.bar.fill"
            }
        }
    }

    private let fireGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.42, blue: 0.42),
            Color(red: 0.85, green: 0.2, blue: 0.2),
            Color(red: 0.55, green: 0.0, blue: 0.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        mainContent
            .padding(16)
            .background(cardBackground)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : -20)
            .gesture(swipeGesture)
            .onAppear(perform: onAppearAction)
            .onChange(of: currentView) { _ in
                updateProgress()
            }
            .onChange(of: progressValue, perform: onProgressChange)
    }

    // MARK: - Subviews

    private var mainContent: some View {
        VStack(spacing: 12) {
            headerSection
            HStack(spacing: 16) {
                circularProgressSection
                progressBarSection
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: currentView.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(fireGradient)

            Text("TU PROGRESO \(currentView.rawValue.uppercased())")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .tracking(1)

            Spacer()

            viewSwitcherDots
        }
    }

    private var viewSwitcherDots: some View {
        HStack(spacing: 6) {
            ForEach(ProgressView.allCases, id: \.self) { view in
                dotIndicator(for: view)
            }
        }
    }

    private func dotIndicator(for view: ProgressView) -> some View {
        let isSelected = currentView == view

        return Circle()
            .fill(isSelected ? AnyShapeStyle(fireGradient) : AnyShapeStyle(Color.dynamicTextSecondary(theme: themeManager.currentTheme).gradient))
            .frame(width: 6, height: 6)
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.spring(response: 0.3), value: currentView)
    }

    private var circularProgressSection: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2),
                    lineWidth: 8
                )
                .frame(width: 90, height: 90)

            // Progress circle
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(fireGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progressValue)

            // Particles effect when goal completed
            if showParticles {
                ParticleEffect(particleCount: 8, color: Color(red: 0.85, green: 0.2, blue: 0.2))
            }

            // Center stats
            VStack(spacing: 2) {
                Text("\(Int(currentProgress.completed))/\(Int(currentProgress.goal))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(fireGradient)

                Text("entrenamientos")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .frame(width: 90, height: 90)
    }

    private var progressBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentView.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .tracking(0.5)

            Text("\(Int(progressValue * 100))%")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(fireGradient)

            Text("completado")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            if progressValue >= 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(fireGradient)
                    Text("¡Meta cumplida!")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(fireGradient)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.buttonTap()
                // Navigate to detailed stats
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Ver detalles")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }

            Spacer()

            Button(action: {
                HapticManager.shared.buttonTap()
                // Navigate to class booking
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Agendar clase")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(fireGradient)
                )
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            .shadow(
                color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                radius: 12,
                x: 0,
                y: 4
            )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                handleSwipe(translation: value.translation.width)
            }
    }

    private func onAppearAction() {
        withAnimation(.easeOut(duration: 0.5)) {
            animateIn = true
        }
        updateProgress()
    }

    private func onProgressChange(_ newValue: Double) {
        if newValue >= 1.0 && !showParticles {
            HapticManager.shared.goalCompleted()
            withAnimation {
                showParticles = true
            }
        }
    }

    // MARK: - Computed Properties

    private var currentProgress: (completed: Double, goal: Double) {
        switch currentView {
        case .weekly:
            // Goal: 4 workouts per week
            let completed = min(Double(userStatsService.userStats.currentStreak), 4.0)
            return (completed, 4.0)
        case .monthly:
            // Goal: 16 workouts per month (4 per week * 4 weeks)
            let completed = min(Double(userStatsService.userStats.currentStreak), 16.0)
            return (completed, 16.0)
        case .yearly:
            // Goal: 200 workouts per year
            let completed = min(Double(userStatsService.userStats.totalStreak), 200.0)
            return (completed, 200.0)
        }
    }

    // MARK: - Helper Methods

    private func updateProgress() {
        let progress = currentProgress
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            progressValue = progress.completed / progress.goal
        }
    }

    private func handleSwipe(translation: CGFloat) {
        let currentIndex = ProgressView.allCases.firstIndex(of: currentView) ?? 0

        if translation > 0 {
            // Swipe right - previous view
            if currentIndex > 0 {
                HapticManager.shared.swipeDetected()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentView = ProgressView.allCases[currentIndex - 1]
                }
            }
        } else {
            // Swipe left - next view
            if currentIndex < ProgressView.allCases.count - 1 {
                HapticManager.shared.swipeDetected()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentView = ProgressView.allCases[currentIndex + 1]
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HeroProgressWidget()
        .withServiceContainer()
        .padding()
        .background(Color.dynamicBackground(theme: .dark))
}
