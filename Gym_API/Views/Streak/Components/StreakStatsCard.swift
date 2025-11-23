import SwiftUI

/// Reusable card component for displaying streak statistics
struct StreakStatsCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let theme: ThemeManager.AppTheme

    @State private var appear = false

    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        theme: ThemeManager.AppTheme
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.theme = theme
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon with circular background
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: theme).opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.dynamicAccent(theme: theme).opacity(0.2),
                                    Color.dynamicAccent(theme: theme).opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(theme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }
}

// MARK: - Convenience Initializers
extension StreakStatsCard {
    /// Creates a card for best streak stat
    static func bestStreak(_ days: Int, theme: ThemeManager.AppTheme) -> StreakStatsCard {
        StreakStatsCard(
            icon: "trophy.fill",
            title: "MEJOR RACHA",
            value: "\(days) días",
            subtitle: "Tu récord personal",
            theme: theme
        )
    }

    /// Creates a card for start date stat
    static func startDate(_ date: Date?, theme: ThemeManager.AppTheme) -> StreakStatsCard {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")

        let dateString = date != nil ? formatter.string(from: date!) : "No iniciada"

        return StreakStatsCard(
            icon: "calendar",
            title: "COMENZÓ",
            value: dateString,
            subtitle: date != nil ? timeAgo(from: date!) : nil,
            theme: theme
        )
    }

    /// Creates a card for streak level
    static func level(_ currentStreak: Int, theme: ThemeManager.AppTheme) -> StreakStatsCard {
        let level = StreakLevel.from(days: currentStreak)

        return StreakStatsCard(
            icon: level.icon,
            title: "NIVEL",
            value: level.displayName,
            subtitle: level.requirement,
            theme: theme
        )
    }

    /// Creates a card for total workouts
    static func totalWorkouts(_ count: Int, theme: ThemeManager.AppTheme) -> StreakStatsCard {
        StreakStatsCard(
            icon: "flame.fill",
            title: "ENTRENAMIENTOS",
            value: "\(count)",
            subtitle: "Total completados",
            theme: theme
        )
    }

    // MARK: - Helper Functions

    private static func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: date, to: now)

        if let days = components.day {
            if days == 0 {
                return "Hoy"
            } else if days == 1 {
                return "Hace 1 día"
            } else if days < 7 {
                return "Hace \(days) días"
            } else if days < 30 {
                let weeks = days / 7
                return "Hace \(weeks) semana\(weeks > 1 ? "s" : "")"
            } else {
                let months = days / 30
                return "Hace \(months) mes\(months > 1 ? "es" : "")"
            }
        }

        return ""
    }
}

// MARK: - Streak Level Enum
enum StreakLevel {
    case starter
    case committed
    case dedicated
    case champion
    case legend
    case immortal

    var displayName: String {
        switch self {
        case .starter: return "Principiante"
        case .committed: return "Comprometido"
        case .dedicated: return "Dedicado"
        case .champion: return "Campeón"
        case .legend: return "Leyenda"
        case .immortal: return "Inmortal"
        }
    }

    var icon: String {
        switch self {
        case .starter: return "🌱"
        case .committed: return "🔥"
        case .dedicated: return "💪"
        case .champion: return "🏆"
        case .legend: return "⚡"
        case .immortal: return "👑"
        }
    }

    var requirement: String {
        switch self {
        case .starter: return "0-6 días"
        case .committed: return "7-29 días"
        case .dedicated: return "30-89 días"
        case .champion: return "90-179 días"
        case .legend: return "180-364 días"
        case .immortal: return "365+ días"
        }
    }

    static func from(days: Int) -> StreakLevel {
        switch days {
        case 0...6:
            return .starter
        case 7...29:
            return .committed
        case 30...89:
            return .dedicated
        case 90...179:
            return .champion
        case 180...364:
            return .legend
        default:
            return .immortal
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        StreakStatsCard.bestStreak(156, theme: .dark)
        StreakStatsCard.startDate(Date().addingTimeInterval(-60*60*24*45), theme: .dark)
        StreakStatsCard.level(47, theme: .dark)
        StreakStatsCard.totalWorkouts(142, theme: .dark)
    }
    .padding()
    .background(Color.dynamicBackground(theme: .dark))
}
