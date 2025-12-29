import SwiftUI

/// Real-time activity stream showing gym member activities from the backend
struct GymActivityStream: View {
    @EnvironmentObject var activityService: ActivityService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var animateIn = false
    @State private var showAllActivities = false
    @State private var greenDotOpacity: Double = 1.0

    private let maxVisibleActivities = 5

    var body: some View {
        Group {
            // Solo mostrar el widget si hay actividades
            // Cuando está vacío, no ocupa espacio en absoluto
            if !activityService.activities.isEmpty {
                mainContent
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            // Activity list o loading
            if activityService.isLoading && activityService.activities.isEmpty {
                loadingView
            } else {
                activityListView
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                Text("ACTIVIDAD DEL GYM")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .tracking(1)

                // Live indicator dot with opacity breathing
                if !activityService.activities.isEmpty {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(greenDotOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                greenDotOpacity = 0.3
                            }
                        }
                }
            }

            Spacer()

            Text("EN VIVO")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                )
        }
    }

    // MARK: - Activity List

    private var activityListView: some View {
        VStack(spacing: 8) {
            let visibleActivities = showAllActivities
                ? activityService.activities
                : Array(activityService.activities.prefix(maxVisibleActivities))

            ForEach(Array(visibleActivities.enumerated()), id: \.element.id) { index, activity in
                ActivityStreamRow(activity: activity, theme: themeManager.currentTheme)
                    .staggeredAppear(index: index, delay: 0.08)
            }

            // View more button
            if activityService.activities.count > maxVisibleActivities {
                viewMoreButton
            }
        }
    }

    // MARK: - View More Button

    private var viewMoreButton: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAllActivities.toggle()
            }
            // Load more if expanding and has more
            if showAllActivities && activityService.hasMoreActivities {
                Task {
                    await activityService.loadMoreActivities()
                }
            }
        }) {
            HStack(spacing: 6) {
                Text(showAllActivities ? "Ver menos" : "Ver más actividad")
                    .font(.system(size: 13, weight: .semibold))

                Image(systemName: showAllActivities ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                ActivityStreamRowSkeleton(theme: themeManager.currentTheme)
            }
        }
    }

}

// MARK: - Activity Stream Row

struct ActivityStreamRow: View {
    let activity: FeedActivity
    let theme: ThemeManager.AppTheme

    @State private var showCelebration = false
    @State private var isBreathing = false
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            // Emoji icon with background and breathing animation
            activityIcon

            // Message and timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let timeAgo = activity.timeAgo {
                    Text(timeAgo)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme).opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            // Celebrate button for achievements
            if isAchievementType {
                celebrateButton
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color.dynamicAccent(theme: theme).opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .overlay(
            // Celebration confetti overlay
            showCelebration ? celebrationOverlay : nil
        )
    }

    // MARK: - Activity Icon

    private var activityIcon: some View {
        ZStack {
            // Anillo de pulso que se expande
            Circle()
                .stroke(iconBackgroundColor.opacity(0.4), lineWidth: 2)
                .frame(width: 44, height: 44)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)
                .animation(
                    .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // Fondo del icono
            Circle()
                .fill(iconBackgroundColor.opacity(0.15))
                .frame(width: 44, height: 44)

            // Icono con breathing
            Text(activity.icon)
                .font(.system(size: 20))
                .scaleEffect(isBreathing ? 1.05 : 0.95)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isBreathing
                )
        }
        .onAppear {
            isBreathing = true
            isPulsing = true
        }
    }

    // MARK: - Celebrate Button

    private var celebrateButton: some View {
        Button(action: {
            HapticManager.shared.play(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                showCelebration = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCelebration = false
            }
        }) {
            Text("🎉")
                .font(.system(size: 20))
                .scaleEffect(showCelebration ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showCelebration)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Celebrar logro")
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        GeometryReader { geometry in
            ForEach(0..<8, id: \.self) { index in
                Text(["🎉", "⭐", "🔥", "💪"][index % 4])
                    .font(.system(size: 16))
                    .offset(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: -40...0)
                    )
                    .opacity(showCelebration ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).delay(Double(index) * 0.1),
                        value: showCelebration
                    )
            }
        }
    }

    // MARK: - Helper Properties

    private var isAchievementType: Bool {
        ["achievement_unlocked", "milestone", "pr_broken", "streak_milestone", "goal_completed"]
            .contains(activity.type) ||
        ["achievement_unlocked", "milestone", "pr_broken", "streak_milestone", "goal_completed"]
            .contains(activity.subtype ?? "")
    }

    private var iconBackgroundColor: Color {
        switch activity.type {
        case "realtime": return .blue
        case "achievement_unlocked", "milestone": return .yellow
        case "pr_broken": return .orange
        case "streak_milestone": return .red
        case "class_completed": return .green
        case "motivational": return .purple
        default: return Color.dynamicAccent(theme: theme)
        }
    }
}

// MARK: - Skeleton Row

struct ActivityStreamRowSkeleton: View {
    let theme: ThemeManager.AppTheme
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.dynamicSurface(theme: theme))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.dynamicSurface(theme: theme))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.dynamicSurface(theme: theme))
                    .frame(width: 80, height: 10)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color.dynamicAccent(theme: theme).opacity(0.1),
                    lineWidth: 1
                )
        )
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        GymActivityStream()
            .padding()
    }
    .background(Color.black)
    .withServiceContainer()
}
