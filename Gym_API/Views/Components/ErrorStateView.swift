import SwiftUI

/// Componente reutilizable para mostrar estados de error de manera amigable
struct ErrorStateView: View {
    let title: String
    let message: String
    let iconName: String
    let retryButtonText: String
    let onRetry: (() -> Void)?
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isRetryPressed = false
    
    init(
        title: String = "Something went wrong",
        message: String,
        iconName: String = "exclamationmark.triangle",
        retryButtonText: String = "Try Again",
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.retryButtonText = retryButtonText
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(errorBackgroundColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(errorIconColor)
                    .scaleEffect(animationScale)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: animationScale
                    )
            }
            .onAppear {
                animationScale = 1.1
            }
            
            // Error content
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            // Retry button
            if let onRetry = onRetry {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onRetry()
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(retryButtonText)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .shadow(
                                color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                    .scaleEffect(isRetryPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isRetryPressed)
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isRetryPressed = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isRetryPressed = false
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(40)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
    
    @State private var animationScale: CGFloat = 1.0
    
    // MARK: - Computed Properties
    private var errorIconColor: Color {
        switch iconName {
        case "wifi.slash", "antenna.radiowaves.left.and.right.slash":
            return .orange
        case "exclamationmark.triangle":
            return .red.opacity(0.8)
        case "xmark.circle":
            return .red
        default:
            return Color.dynamicTextSecondary(theme: themeManager.currentTheme)
        }
    }
    
    private var errorBackgroundColor: Color {
        switch iconName {
        case "wifi.slash", "antenna.radiowaves.left.and.right.slash":
            return .orange
        case "exclamationmark.triangle":
            return .red
        case "xmark.circle":
            return .red
        default:
            return Color.dynamicTextSecondary(theme: themeManager.currentTheme)
        }
    }
}

// MARK: - Convenience Extensions for Common Error Types
extension ErrorStateView {
    /// Error de conexión de red
    static func networkError(
        message: String = "Check your internet connection and try again",
        onRetry: (() -> Void)? = nil
    ) -> ErrorStateView {
        ErrorStateView(
            title: "No connection",
            message: message,
            iconName: "wifi.slash",
            retryButtonText: "Try Again",
            onRetry: onRetry
        )
    }
    
    /// Error de servidor
    static func serverError(
        message: String = "Our servers are experiencing issues. Please try again later",
        onRetry: (() -> Void)? = nil
    ) -> ErrorStateView {
        ErrorStateView(
            title: "Server Error",
            message: message,
            iconName: "exclamationmark.triangle",
            retryButtonText: "Retry",
            onRetry: onRetry
        )
    }
    
    /// Error de carga de datos
    static func loadingError(
        message: String = "We couldn't load your data. Please try again",
        onRetry: (() -> Void)? = nil
    ) -> ErrorStateView {
        ErrorStateView(
            title: "Failed to Load",
            message: message,
            iconName: "arrow.clockwise.circle",
            retryButtonText: "Reload",
            onRetry: onRetry
        )
    }
    
    /// Error de chat/mensajería
    static func chatError(
        message: String = "Unable to connect to chat. Check your connection and try again",
        onRetry: (() -> Void)? = nil
    ) -> ErrorStateView {
        ErrorStateView(
            title: "Chat Unavailable",
            message: message,
            iconName: "bubble.left.and.bubble.right.fill",
            retryButtonText: "Reconnect",
            onRetry: onRetry
        )
    }
}

/// Vista de error compacta para uso en headers o secciones pequeñas
struct CompactErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .lineLimit(2)
            
            Spacer()
            
            if let onRetry = onRetry {
                Button("Retry") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onRetry()
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 40) {
        ErrorStateView.networkError(
            message: "Please check your internet connection and try again. We're having trouble connecting to our servers.",
            onRetry: { print("Retry tapped") }
        )
        
        CompactErrorView(
            message: "Unable to load messages",
            onRetry: { print("Compact retry tapped") }
        )
    }
    .environmentObject(ThemeManager())
}