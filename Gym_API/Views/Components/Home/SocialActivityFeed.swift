import SwiftUI

/// Real-time social activity feed showing gym member achievements and activities
struct SocialActivityFeed: View {
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var activities: [GymActivity] = []
    @State private var animateIn = false

    // Simulated activity types for now - will be replaced with real data from PostService
    enum ActivityType {
        case completedWorkout
        case newRecord
        case milestone
        case joined

        var icon: String {
            switch self {
            case .completedWorkout: return "figure.run"
            case .newRecord: return "trophy.fill"
            case .milestone: return "star.fill"
            case .joined: return "person.badge.plus.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .completedWorkout: return .blue
            case .newRecord: return .orange
            case .milestone: return .yellow
            case .joined: return .green
            }
        }
    }

    struct GymActivity: Identifiable {
        let id = UUID()
        let type: ActivityType
        let userName: String
        let userAvatar: String?
        let message: String
        let timestamp: Date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                Text("ACTIVIDAD DEL GYM")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .tracking(1)

                Spacer()

                Text("HOY")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Activity list
            if activities.isEmpty {
                emptyStateView
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
            loadMockActivities()
        }
    }

    // MARK: - Activity List

    private var activityListView: some View {
        VStack(spacing: 12) {
            ForEach(Array(activities.prefix(5).enumerated()), id: \.element.id) { index, activity in
                ActivityRow(activity: activity, theme: themeManager.currentTheme)
                    .staggeredAppear(index: index, delay: 0.1)
                    .onTapGesture {
                        HapticManager.shared.buttonTap()
                        // TODO: Navigate to user profile or activity detail
                    }
            }

            // View all button
            if activities.count > 5 {
                Button(action: {
                    HapticManager.shared.buttonTap()
                    // TODO: Navigate to full activity feed
                }) {
                    Text("Ver todas las actividades")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))

            Text("No hay actividad reciente")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Text("Sé el primero en entrenar hoy")
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Helper Methods

    private func loadMockActivities() {
        // TODO: Replace with real data from PostService or backend
        activities = [
            GymActivity(
                type: .completedWorkout,
                userName: "María González",
                userAvatar: nil,
                message: "completó una sesión de Yoga",
                timestamp: Date().addingTimeInterval(-300)
            ),
            GymActivity(
                type: .newRecord,
                userName: "Carlos Ruiz",
                userAvatar: nil,
                message: "batió su récord en CrossFit",
                timestamp: Date().addingTimeInterval(-900)
            ),
            GymActivity(
                type: .milestone,
                userName: "Ana Torres",
                userAvatar: nil,
                message: "alcanzó 50 entrenamientos",
                timestamp: Date().addingTimeInterval(-1800)
            ),
            GymActivity(
                type: .completedWorkout,
                userName: "Luis Fernández",
                userAvatar: nil,
                message: "completó una sesión de HIIT",
                timestamp: Date().addingTimeInterval(-2700)
            ),
            GymActivity(
                type: .joined,
                userName: "Sofia Martínez",
                userAvatar: nil,
                message: "se unió al gym",
                timestamp: Date().addingTimeInterval(-3600)
            )
        ]
    }
}

// MARK: - Activity Row Component

struct ActivityRow: View {
    let activity: SocialActivityFeed.GymActivity
    let theme: ThemeManager.AppTheme

    @State private var liked = false
    @State private var showHearts = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with activity type badge
            ZStack(alignment: .bottomTrailing) {
                // Avatar
                if let avatarUrl = activity.userAvatar, let url = URL(string: avatarUrl) {
                    CustomImageView(url: avatarUrl, cacheKey: "activity_\(activity.id)", size: 44) {
                        AnyView(placeholderAvatar)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    placeholderAvatar
                        .frame(width: 44, height: 44)
                }

                // Activity type badge
                Circle()
                    .fill(activity.type.iconColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: activity.type.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 2, y: 2)
            }

            // Activity text
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(activity.userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: theme))

                    Text(activity.message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
                .lineLimit(2)

                Text(timeAgo(from: activity.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme).opacity(0.7))
            }

            Spacer(minLength: 0)

            // Like button with animation
            Button(action: {
                HapticManager.shared.buttonTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    liked.toggle()
                }
                if liked {
                    showHearts = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showHearts = false
                    }
                }
            }) {
                ZStack {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(liked ? .red : Color.dynamicTextSecondary(theme: theme))
                        .scaleEffect(liked ? 1.2 : 1.0)

                    if showHearts {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                                .offset(
                                    x: CGFloat.random(in: -20...20),
                                    y: CGFloat.random(in: -30...(-10))
                                )
                                .opacity(0)
                                .animation(
                                    .easeOut(duration: 1.0)
                                    .delay(Double(index) * 0.1),
                                    value: showHearts
                                )
                        }
                    }
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.dynamicAccent(theme: theme).opacity(0.3),
                        Color.dynamicAccent(theme: theme).opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            )
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "Hace un momento"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "Hace \(minutes)m"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "Hace \(hours)h"
        } else {
            let days = seconds / 86400
            return "Hace \(days)d"
        }
    }
}

// MARK: - Preview

#Preview {
    SocialActivityFeed()
        .withServiceContainer()
        .padding()
        .background(Color.dynamicBackground(theme: .dark))
}
