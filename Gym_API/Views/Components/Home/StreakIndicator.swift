import SwiftUI

// MARK: - Streak Indicator Component
/// Componente mejorado para mostrar rachas de días consecutivos de entrenamiento
/// Rediseñado para perfecta integración con ambos temas de la app (claro/oscuro)
/// Compatible con colores #D93333 y sistema de accesibilidad WCAG 2.1 AA
struct StreakIndicator: View {
    let streakCount: Int
    let theme: ThemeManager.AppTheme
    
    @State private var isAnimating = false
    @State private var glowPulse = false
    @State private var shimmerOffset: CGFloat = -50
    
    // Mensajes personalizados basados en el número de días
    private var streakMessage: String {
        switch streakCount {
        case 1: return "¡Primer día!"
        case 2: return "¡2 días seguidos!"
        case 3: return "¡3 day streak! Keep it up!"
        case 4...6: return "¡\(streakCount) días increíbles!"
        case 7...13: return "¡Una semana completa!"
        case 14...29: return "¡\(streakCount) días imparable!"
        case 30...: return "¡Leyenda de \(streakCount) días!"
        default: return "¡Sigue así!"
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Icono de fuego con efectos mejorados
            streakIcon
            
            // Texto del mensaje con mejor tipografía
            streakText
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(modernStreakBackground)
        .clipShape(Capsule())
        .overlay(shimmerOverlay)
        .shadow(
            color: Color.dynamicAccent(theme: theme).opacity(theme == .dark ? 0.4 : 0.2),
            radius: theme == .dark ? 6 : 4,
            x: 0,
            y: 3
        )
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak indicator: \(streakMessage)")
        .accessibilityHint("Your current workout streak")
        .onAppear {
            startModernAnimations()
        }
    }
    
    // MARK: - Subcomponents Mejorados
    
    private var streakIcon: some View {
        ZStack {
            // Glow effect adaptado al tema
            if glowPulse {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
                    .blur(radius: 3)
                    .opacity(theme == .dark ? 0.8 : 0.5)
                    .scaleEffect(1.15)
            }
            
            // Icono principal con mejor contraste
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
                .rotationEffect(.degrees(isAnimating ? 3 : -3))
        }
    }
    
    private var streakText: some View {
        Text(streakMessage)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(Color.dynamicAccent(theme: theme))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    
    // Fondo moderno con glassmorphism mejorado
    private var modernStreakBackground: some View {
        ZStack {
            // Base glassmorphism
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, theme == .dark ? .dark : .light)
            
            // Overlay de color temático
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.dynamicAccent(theme: theme).opacity(theme == .dark ? 0.15 : 0.08), location: 0.0),
                            .init(color: Color.dynamicAccent(theme: theme).opacity(theme == .dark ? 0.08 : 0.12), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Borde sutil
            Capsule()
                .stroke(
                    Color.dynamicAccent(theme: theme).opacity(theme == .dark ? 0.3 : 0.2),
                    lineWidth: 1
                )
        }
    }
    
    // Efecto shimmer para dar vida al componente
    private var shimmerOverlay: some View {
        Capsule()
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.white.opacity(theme == .dark ? 0.15 : 0.25), location: 0.5),
                        .init(color: Color.clear, location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: shimmerOffset)
            .clipped()
    }
    
    // MARK: - Animaciones Modernas
    
    private func startModernAnimations() {
        // Animación de entrada más sutil
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            isAnimating = true
        }
        
        // Glow pulsante más suave
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            glowPulse = true
        }
        
        // Efecto shimmer periódico
        withAnimation(
            .linear(duration: 2.5)
            .repeatForever(autoreverses: false)
            .delay(1.0)
        ) {
            shimmerOffset = 100
        }
        
        // Resetear animación de escala después de un momento
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                isAnimating = false
            }
        }
    }
}

// MARK: - Enhanced Streak Indicator
/// Versión premium del indicador de rachas con efectos adicionales
struct EnhancedStreakIndicator: View {
    let streakCount: Int
    let theme: ThemeManager.AppTheme
    
    @State private var showParticles = false
    @State private var trophyBounce = false
    @State private var shimmerOffset: CGFloat = -100
    
    var streakMessage: String {
        switch streakCount {
        case 1: return "¡Primer día! 🔥"
        case 2: return "¡2 días seguidos! 💪"
        case 3: return "¡Racha de 3 días!"
        case 4...6: return "¡\(streakCount) días increíbles!"
        case 7...13: return "¡Una semana completa! 🏆"
        case 14...29: return "¡\(streakCount) días imparable!"
        case 30...: return "¡Leyenda de \(streakCount) días!"
        default: return "¡Sigue así!"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono especial basado en la racha
            streakIconEnhanced
            
            VStack(alignment: .leading, spacing: 2) {
                // Número de días
                Text("\(streakCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
                
                // Mensaje motivacional
                Text(streakMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(enhancedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(shimmerOverlay)
        .shadow(
            color: Color.dynamicAccent(theme: theme).opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
        .onAppear {
            startEnhancedAnimations()
        }
    }
    
    private var streakIconEnhanced: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.dynamicAccent(theme: theme).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.dynamicAccent(theme: theme).opacity(0.3), lineWidth: 1)
                )
            
            // Icon based on streak count
            Group {
                if streakCount >= 30 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                } else if streakCount >= 7 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .bold))
                } else if streakCount >= 3 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .bold))
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundColor(Color.dynamicAccent(theme: theme))
            .scaleEffect(trophyBounce ? 1.1 : 1.0)
        }
    }
    
    private var enhancedBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.dynamicSurface(theme: theme), location: 0.0),
                        .init(color: Color.dynamicSurface(theme: theme).opacity(0.95), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.dynamicAccent(theme: theme).opacity(0.3),
                                Color.dynamicAccent(theme: theme).opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
    
    private var shimmerOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.white.opacity(0.1), location: 0.5),
                        .init(color: Color.clear, location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: shimmerOffset)
            .clipped()
    }
    
    private func startEnhancedAnimations() {
        // Bounce animation for icon
        withAnimation(
            .spring(response: 0.6, dampingFraction: 0.5)
            .repeatForever(autoreverses: true)
        ) {
            trophyBounce = true
        }
        
        // Shimmer effect
        withAnimation(
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 300
        }
    }
}

// MARK: - Great Job Achievement Badge
/// Badge especial para celebrar logros importantes
struct GreatJobAchievementBadge: View {
    let achievementType: AchievementType
    let theme: ThemeManager.AppTheme
    
    @State private var celebrationAnimation = false
    @State private var sparkleAnimation = false
    @State private var rotationAnimation = false
    
    enum AchievementType {
        case classCompleted
        case weekStreak
        case monthStreak
        case personalRecord
        
        var title: String {
            switch self {
            case .classCompleted: return "¡Clase Completada!"
            case .weekStreak: return "¡7 Días Seguidos!"
            case .monthStreak: return "¡Un Mes Completo!"
            case .personalRecord: return "¡Nuevo Récord!"
            }
        }
        
        var icon: String {
            switch self {
            case .classCompleted: return "checkmark.seal.fill"
            case .weekStreak: return "flame.fill"
            case .monthStreak: return "trophy.fill"
            case .personalRecord: return "star.fill"
            }
        }
        
        var subtitle: String {
            switch self {
            case .classCompleted: return "Sigue así"
            case .weekStreak: return "¡Increíble dedicación!"
            case .monthStreak: return "¡Eres una leyenda!"
            case .personalRecord: return "¡Superaste tus límites!"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Achievement icon with sparkle effect
            ZStack {
                // Sparkle particles
                if sparkleAnimation {
                    ForEach(0..<6, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.dynamicAccent(theme: theme).opacity(0.8))
                            .offset(sparkleOffset(for: index))
                            .opacity(sparkleAnimation ? 1.0 : 0.0)
                            .scaleEffect(sparkleAnimation ? 1.0 : 0.3)
                    }
                }
                
                // Main achievement icon
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: theme))
                        .frame(width: 60, height: 60)
                        .shadow(
                            color: Color.dynamicAccent(theme: theme).opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    
                    Image(systemName: achievementType.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotationAnimation ? 5 : -5))
                }
                .scaleEffect(celebrationAnimation ? 1.1 : 1.0)
            }
            
            // Achievement text
            VStack(spacing: 4) {
                Text(achievementType.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .multilineTextAlignment(.center)
                
                Text(achievementType.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.dynamicAccent(theme: theme).opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(theme == .dark ? 0.3 : 0.1),
            radius: 12,
            x: 0,
            y: 6
        )
        .onAppear {
            startCelebrationAnimation()
        }
    }
    
    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = Double(index) * (360.0 / 6.0) * .pi / 180
        let radius: CGFloat = 50
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }
    
    private func startCelebrationAnimation() {
        // Celebration bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            celebrationAnimation = true
        }
        
        // Sparkle animation
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            sparkleAnimation = true
        }
        
        // Rotation animation
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            rotationAnimation = true
        }
    }
}

// MARK: - Usage Examples and Preview
#Preview {
    VStack(spacing: 24) {
        Text("Tema Oscuro")
            .font(.title2)
            .foregroundColor(Color.dynamicText(theme: .dark))
        
        // Streak indicators en tema oscuro
        StreakIndicator(streakCount: 3, theme: .dark)
        EnhancedStreakIndicator(streakCount: 7, theme: .dark)
        
        Divider()
        
        Text("Tema Claro")
            .font(.title2)
            .foregroundColor(Color.dynamicText(theme: .light))
        
        // Streak indicators en tema claro
        StreakIndicator(streakCount: 3, theme: .light)
        EnhancedStreakIndicator(streakCount: 7, theme: .light)
        
        // Achievement badges
        GreatJobAchievementBadge(achievementType: .classCompleted, theme: .dark)
    }
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.dynamicBackground(theme: .dark), location: 0.0),
                .init(color: Color.dynamicBackground(theme: .light), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    )
}