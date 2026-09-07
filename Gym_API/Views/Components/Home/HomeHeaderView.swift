import SwiftUI

// MARK: - Home Header View
/// Compact header with time-based greeting, user name, notification bell, and avatar
struct HomeHeaderView: View {
    let userName: String
    let userInitials: String
    /// Foto de perfil, si se conoce. Opcional con valor por defecto porque esta cabecera la
    /// comparte la home del gimnasio, que no la pasa. `UserProfileService.userProfile.picture`
    /// ya la tiene cargada; lo unico que faltaba era este parametro.
    var pictureURL: String? = nil
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

                // Avatar. Con foto cuando la hay; si no, las iniciales sobre el acento del tema.
                // El degradado naranja-violeta que habia aqui estaba cableado y era el unico
                // color de la pantalla que no respetaba lo que el usuario habia elegido.
                Button(action: onAvatarTap) {
                    Group {
                        if let pictureURL, !pictureURL.isEmpty {
                            CustomImageView(url: pictureURL, cacheKey: pictureURL, size: 40) {
                                AnyView(initialsAvatar)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            initialsAvatar
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var initialsAvatar: some View {
        Text(userInitials)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: themeManager.currentTheme))
            .frame(width: 40, height: 40)
            .background(Color.dynamicAccent(theme: themeManager.currentTheme))
            .clipShape(Circle())
    }
}
