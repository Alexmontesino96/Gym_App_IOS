import SwiftUI

// MARK: - FeedEndMarker
/// "Estás al día" marker at the end of the feed

struct FeedEndMarker: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            // Checkmark circle
            Image(systemName: "checkmark")
                .font(.system(size: 18))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                .frame(width: 40, height: 40)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text("Estás al día")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Text("Has visto todos los posts nuevos")
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
    }
}
