import SwiftUI

// MARK: - Home Header View
/// Compact header with time-based greeting, user name, notification bell, and avatar
struct HomeHeaderView: View {
    let userName: String
    let userInitials: String
    let onNotificationTap: () -> Void
    let onAvatarTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 19 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            // Left: Greeting + Name
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting),")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))

                Text(userName)
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .tracking(-0.5)
            }

            Spacer()

            // Right: Bell + Avatar
            HStack(spacing: 8) {
                // Notification bell
                Button(action: onNotificationTap) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .frame(width: 40, height: 40)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 1)
                            )

                        // Red dot indicator
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2)
                            )
                            .offset(x: -6, y: 6)
                    }
                }

                // Avatar
                Button(action: onAvatarTap) {
                    Text(userInitials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#FF5A1F")!, Color(hex: "#A78BFA")!],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 4)
    }
}
