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
    @State private var showSkipHint = false
    
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

        // Use real streak value from backend without artificial minimum
        self.targetStreak = userStatsService.userStats.currentStreak

        // Select motivational quote based on time and streak status
        let hour = Calendar.current.component(.hour, from: Date())
        let hasStreak = userStatsService.userStats.currentStreak > 0

        if !hasStreak {
            // Special quotes for users starting their journey
            switch hour {
            case 6..<12:
                self.motivationalQuote = "Hoy es el día perfecto para empezar 🌅"
            case 12..<17:
                self.motivationalQuote = "Tu primera clase te espera 💪"
            case 17..<22:
                self.motivationalQuote = "Comienza tu racha esta noche 🔥"
            default:
                self.motivationalQuote = "Mañana será un gran día 🌙"
            }
        } else {
            // Regular quotes for users with active streak
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
                
                // Streak Counter with Fire or Start Journey Card
                if targetStreak > 0 {
                    // Active Streak Display
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
                } else {
                    // Start Your Journey Card (for users with 0 streak)
                    VStack(spacing: 8) {
                        Text("🌟")
                            .font(.system(size: 40))
                            .scaleEffect(fireScale)

                        Text("¡Comienza tu racha!")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Reserva tu primera clase y empieza a acumular días")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 25)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.2)
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
                }
                
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
                
                // Skip Hint (aparece después de 1s)
                if showSkipHint {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Toca para continuar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
        }
        .onTapGesture {
            // Permitir skip con tap
            dismissAnimation()
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

            // Dismiss after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismissAnimation()
            }
            return
        }

        // Versión express optimizada con cascada refinada
        // Timeline total: 2 segundos con animaciones fluidas y escalonadas

        // === Fase 1: Entrada (0-0.5s) ===
        withAnimation(.easeIn(duration: 0.2)) {
            backgroundOpacity = 1.0
        }

        // Wave con spring suave
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.showWave = true
                self.waveRotation = 15 // Rotación inicial menor
            }
        }

        // === Fase 2: Avatar y contenido principal (0.3-0.8s) ===
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Avatar bounce
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.avatarScale = 1.15
            }

            // Wave vuelve a neutral
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                self.waveRotation = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Avatar settle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.avatarScale = 1.0
            }

            // Streak/Fire appear
            self.currentStreak = self.targetStreak
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.fireScale = 1.15
            }
        }

        // === Fase 3: Detalles secundarios (0.7-1.2s) ===
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // Fire settle
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.fireScale = 1.0
            }

            // Tip fade in
            withAnimation(.easeIn(duration: 0.3)) {
                self.tipOpacities[0] = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Quote appear (sin typewriter, fade directo)
            self.quoteText = self.motivationalQuote
            withAnimation(.easeIn(duration: 0.35)) {
                self.cursorOpacity = 1.0
            }
        }

        // === Fase 4: Skip hint (1.0s) ===
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.showSkipHint = true
            }
        }

        // === Auto dismiss (2.0s) ===
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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