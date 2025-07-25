import SwiftUI

struct EventChatView: View {
    let eventId: String
    let eventTitle: String
    @ObservedObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        // Usar la nueva implementación iMessage
        SimpleiMessageChatView(
            eventId: eventId,
            eventTitle: eventTitle,
            authService: authService
        )
        .environmentObject(themeManager)
    }
}

// MARK: - Modern Chat Header View
struct ChatHeaderView: View {
    let eventTitle: String
    let isLoading: Bool
    let themeManager: ThemeManager
    let onBackPressed: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: onBackPressed) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            // Event Icon
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Event Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Chat del Evento")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(eventTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Loading or Action Buttons
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .overlay(
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Loading Chat View
struct LoadingChatView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)
            
            Text("Cargando chat...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
}

// MARK: - Error Chat View
struct ErrorChatView: View {
    let message: String
    let themeManager: ThemeManager
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme == .dark ? .orange : .red)
            
            Text("Error al cargar el chat")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
}

// MARK: - Preview
#Preview {
    EventChatView(
        eventId: "608",
        eventTitle: "Torneo Interno",
        authService: AuthServiceDirect()
    )
    .environmentObject(ThemeManager())
} 