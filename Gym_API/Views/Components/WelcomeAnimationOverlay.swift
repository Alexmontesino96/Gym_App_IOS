import SwiftUI

struct WelcomeAnimationOverlay: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @ObservedObject var userStatsService: UserStatsService
    
    @Binding var isVisible: Bool
    
    // Animation states
    @State private var showWave = false
    @State private var waveRotation = -30.0
    @State private var avatarScale = 0.5
    @State private var avatarBounce = false
    @State private var currentStreak = 0
    @State private var fireScale = 1.0
    @State private var tipOpacities: [Double] = [0, 0, 0]
    @State private var quoteText = ""
    @State private var cursorOpacity = 1.0
    @State private var backgroundOpacity = 0.0
    
    private let userName: String
    private let userAvatar: String?
    private let targetStreak: Int
    private let motivationalQuote: String
    private let dailyTips = [
        "💡 Recuerda hidratarte durante el entrenamiento",
        "💡 Registra tu progreso para ver mejoras",
        "💡 Prueba una clase nueva esta semana"
    ]
    
    init(isVisible: Binding<Bool>, userStatsService: UserStatsService, authService: AuthServiceDirect? = nil) {
        self._isVisible = isVisible
        self.userStatsService = userStatsService
        
        // Get user info from authService (will be injected via environment)
        let auth = authService ?? AuthServiceDirect()
        self.userName = auth.user?.name.components(separatedBy: " ").first ?? "Atleta"
        self.userAvatar = auth.user?.picture
        self.targetStreak = max(userStatsService.userStats.currentStreak, 3)
        
        // Select motivational quote based on time
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            self.motivationalQuote = "El éxito comienza con el primer paso 🌅"
        case 12..<17:
            self.motivationalQuote = "Tu única competencia eres tú mismo 💪"
        case 17..<22:
            self.motivationalQuote = "Cada gota de sudor cuenta 💧"
        default:
            self.motivationalQuote = "El descanso también es progreso 🌙"
        }
    }
    
    var body: some View {
        ZStack {
            // Dark background with blur effect
            Color.black
                .opacity(backgroundOpacity * 0.9)
                .ignoresSafeArea()
                .background(
                    .ultraThinMaterial
                )
                .onTapGesture {
                    dismissAnimation()
                }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Wave and Welcome Message
                HStack(spacing: 20) {
                    Text("👋")
                        .font(.system(size: 60))
                        .rotationEffect(.degrees(waveRotation))
                        .opacity(showWave ? 1 : 0)
                        .scaleEffect(showWave ? 1 : 0.5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("¡Hola, \(userName)!")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Bienvenido de vuelta")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .opacity(showWave ? 1 : 0)
                
                // User Avatar with Bounce
                if let avatarURL = userAvatar {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white, .white.opacity(0.5)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .scaleEffect(avatarScale)
                    .shadow(color: .white.opacity(0.3), radius: 10)
                }
                
                // Streak Counter with Fire
                HStack(spacing: 12) {
                    Text("🔥")
                        .font(.system(size: 40))
                        .scaleEffect(fireScale)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Racha actual")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(currentStreak)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("días")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.3),
                                    Color.red.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                // Daily Tips
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<dailyTips.count, id: \.self) { index in
                        Text(dailyTips[index])
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .opacity(tipOpacities[index])
                            .offset(x: tipOpacities[index] == 0 ? -20 : 0)
                    }
                }
                .padding(.horizontal, 30)
                
                // Motivational Quote with Typewriter Effect
                HStack {
                    Text(quoteText)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(.white)
                        .italic()
                    
                    if quoteText.count < motivationalQuote.count {
                        Text("|")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(cursorOpacity)
                    }
                }
                .padding(.horizontal, 30)
                .frame(minHeight: 50)
                
                Spacer()
                
                // Skip Button
                Button(action: dismissAnimation) {
                    Text("Continuar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .opacity(backgroundOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Check if reduce motion is enabled
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        
        if reduceMotion {
            // Show everything immediately without animations
            showWave = true
            avatarScale = 1.0
            currentStreak = targetStreak
            tipOpacities = [1, 1, 1]
            quoteText = motivationalQuote
            backgroundOpacity = 1.0
            
            // Dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismissAnimation()
            }
            return
        }
        
        // Background fade in
        withAnimation(.easeIn(duration: 0.3)) {
            backgroundOpacity = 1.0
        }
        
        // Wave animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            showWave = true
        }
        
        // Wave rotation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.3)) {
            waveRotation = 30
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.7)) {
            waveRotation = 0
        }
        
        // Avatar bounce
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.5)) {
            avatarScale = 1.2
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.9)) {
            avatarScale = 1.0
        }
        
        // Streak counter animation
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if currentStreak < targetStreak {
                currentStreak += 1
                
                // Fire pulse on each increment
                withAnimation(.easeInOut(duration: 0.1)) {
                    fireScale = 1.2
                }
                withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
                    fireScale = 1.0
                }
            } else {
                timer.invalidate()
            }
        }
        
        // Tips fade in sequentially
        for index in 0..<dailyTips.count {
            withAnimation(.easeIn(duration: 0.5).delay(Double(index) * 0.3 + 1.5)) {
                tipOpacities[index] = 1.0
            }
        }
        
        // Typewriter effect for quote
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if quoteText.count < motivationalQuote.count {
                let nextIndex = motivationalQuote.index(motivationalQuote.startIndex, offsetBy: quoteText.count)
                quoteText.append(motivationalQuote[nextIndex])
            } else {
                timer.invalidate()
            }
        }
        
        // Cursor blink
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                cursorOpacity = cursorOpacity == 1.0 ? 0.0 : 1.0
            }
        }
        
        // Auto dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            dismissAnimation()
        }
    }
    
    private func dismissAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }
}

// MARK: - Preview
struct WelcomeAnimationOverlay_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeAnimationOverlay(
            isVisible: .constant(true),
            userStatsService: UserStatsService.shared,
            authService: AuthServiceDirect()
        )
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
    }
}