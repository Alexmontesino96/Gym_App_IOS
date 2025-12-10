import SwiftUI

/// Live pulse banner showing realtime gym activity
/// Displays number of people training and peak time indicator
struct LivePulseBanner: View {
    @EnvironmentObject var activityService: ActivityService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isExpanded = true
    @State private var pulseAnimation = false
    @State private var insightIndex = 0

    private let insightRotationInterval: TimeInterval = 5.0

    var body: some View {
        Group {
            if activityService.totalTraining > 0 || activityService.topInsight != nil {
                bannerContent
            }
        }
        .onAppear {
            startPulseAnimation()
            startInsightRotation()
        }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Pulse indicator
                pulseIndicator

                if isExpanded {
                    // Main content
                    expandedContent
                }

                Spacer(minLength: 0)

                // Peak time badge
                if activityService.isPeakTime && isExpanded {
                    peakTimeBadge
                }

                // Collapse indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isExpanded ? 12 : 8)
            .background(bannerBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Toca para expandir o colapsar")
    }

    // MARK: - Pulse Indicator

    private var pulseIndicator: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)
                .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                .opacity(pulseAnimation ? 0 : 0.7)

            // Inner dot
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Training count
            HStack(spacing: 6) {
                Text("\(activityService.totalTraining)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("entrenando ahora")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Rotating insight (if available)
            if !activityService.insights.isEmpty {
                Text(currentInsightMessage)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.8))
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id("insight_\(insightIndex)")
            }
        }
    }

    // MARK: - Peak Time Badge

    private var peakTimeBadge: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 12))

            Text("Hora pico")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange,
                            Color.dynamicAccent(theme: themeManager.currentTheme)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }

    // MARK: - Background

    private var bannerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
    }

    // MARK: - Helper Properties

    private var currentInsightMessage: String {
        guard !activityService.insights.isEmpty else { return "" }
        let safeIndex = insightIndex % activityService.insights.count
        return activityService.insights[safeIndex].message
    }

    private var accessibilityText: String {
        var text = "\(activityService.totalTraining) personas entrenando ahora"
        if activityService.isPeakTime {
            text += ", hora pico activa"
        }
        return text
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            pulseAnimation = true
        }
    }

    private func startInsightRotation() {
        guard !activityService.insights.isEmpty else { return }

        Timer.scheduledTimer(withTimeInterval: insightRotationInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                insightIndex = (insightIndex + 1) % max(1, activityService.insights.count)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        LivePulseBanner()
            .padding()
    }
    .background(Color.black)
    .withServiceContainer()
}
