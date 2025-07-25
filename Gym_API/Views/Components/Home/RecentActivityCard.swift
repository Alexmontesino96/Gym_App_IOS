import SwiftUI

struct RecentActivityCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(recentActivities, id: \.id) { activity in
                HStack(spacing: 12) {
                    Image(systemName: activity.icon)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 32, height: 32)
                        .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text(activity.time)
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                }
                
                if activity.id != recentActivities.last?.id {
                    Divider()
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
    
    private var recentActivities: [RecentActivity] {
        [
            RecentActivity(
                id: 1,
                title: "Completed Boxing Class",
                time: "2 hours ago",
                icon: "checkmark.circle.fill"
            ),
            RecentActivity(
                id: 2,
                title: "New message from Carlos",
                time: "4 hours ago",
                icon: "message.fill"
            ),
            RecentActivity(
                id: 3,
                title: "Joined Community Event",
                time: "Yesterday",
                icon: "person.3.fill"
            )
        ]
    }
}

struct RecentActivity {
    let id: Int
    let title: String
    let time: String
    let icon: String
}

#Preview {
    RecentActivityCard()
        .environmentObject(ThemeManager())
}