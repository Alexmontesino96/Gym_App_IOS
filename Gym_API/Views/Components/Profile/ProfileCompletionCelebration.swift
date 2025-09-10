import SwiftUI

// MARK: - Profile Completion Celebration
struct ProfileCompletionCelebration: View {
    @Binding var isShowing: Bool
    let theme: ThemeManager.AppTheme
    
    @State private var scale = 0.3
    @State private var opacity = 0.0
    @State private var confettiOpacity = 0.0
    @State private var trophyRotation = -30.0
    @State private var sparklePositions: [CGPoint] = []
    @State private var messageScale = 0.0
    @State private var badgeScale = 0.0
    @State private var glowIntensity = 0.0
    
    private let confettiEmojis = ["🎊", "🎉", "✨", "⭐", "🌟", "💫", "🎯", "🏆"]
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black
                .opacity(opacity * 0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCelebration()
                }
            
            // Confetti particles
            ForEach(0..<20, id: \.self) { index in
                Text(confettiEmojis[index % confettiEmojis.count])
                    .font(.system(size: CGFloat.random(in: 20...40)))
                    .opacity(confettiOpacity)
                    .offset(confettiOffset(for: index))
                    .rotationEffect(.degrees(Double.random(in: -180...180)))
            }
            
            // Main celebration content
            VStack(spacing: 32) {
                // Trophy with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.yellow.opacity(glowIntensity),
                                    Color.orange.opacity(glowIntensity * 0.5),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                    
                    // Sparkles around trophy
                    ForEach(0..<8, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.yellow)
                            .opacity(confettiOpacity)
                            .offset(sparkleOffset(for: index))
                            .rotationEffect(.degrees(Double(index) * 45))
                    }
                    
                    // Trophy icon
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.yellow, .orange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(trophyRotation))
                        .scaleEffect(scale)
                        .shadow(color: .orange.opacity(0.6), radius: 20, x: 0, y: 10)
                }
                
                // Congratulations message
                VStack(spacing: 16) {
                    Text("¡Perfil Completo!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.white, .white.opacity(0.9)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(messageScale)
                    
                    Text("Has completado todos tus datos")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .scaleEffect(messageScale)
                    
                    // Achievement badge
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        Text("Profile Master")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.dynamicAccent(theme: theme),
                                        Color.dynamicAccent(theme: theme).opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .scaleEffect(badgeScale)
                    .shadow(color: Color.dynamicAccent(theme: theme).opacity(0.5), radius: 10, x: 0, y: 5)
                }
                
                // Motivational text
                Text("¡Sigue así! 💪")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .scaleEffect(messageScale)
            }
            .padding(40)
        }
        .onAppear {
            startCelebrationAnimation()
        }
    }
    
    private func startCelebrationAnimation() {
        // Check reduce motion
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        
        if reduceMotion {
            scale = 1.0
            opacity = 1.0
            messageScale = 1.0
            badgeScale = 1.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismissCelebration()
            }
            return
        }
        
        // Background fade in
        withAnimation(.easeIn(duration: 0.3)) {
            opacity = 1.0
        }
        
        // Trophy entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            scale = 1.0
            trophyRotation = 0
        }
        
        // Trophy bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.8)) {
            trophyRotation = 10
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.3)) {
            trophyRotation = 0
        }
        
        // Glow pulse
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
            glowIntensity = 0.8
        }
        
        // Confetti fall
        withAnimation(.easeOut(duration: 2.0).delay(0.5)) {
            confettiOpacity = 1.0
        }
        
        // Message and badge
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            messageScale = 1.0
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.9)) {
            badgeScale = 1.0
        }
        
        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissCelebration()
        }
    }
    
    private func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0.0
            scale = 0.8
            messageScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
        }
    }
    
    private func confettiOffset(for index: Int) -> CGSize {
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        
        let startX = CGFloat.random(in: -screenWidth/2...screenWidth/2)
        let startY = -screenHeight/2 - 100
        
        let endY = confettiOpacity > 0 ? screenHeight : startY
        let drift = CGFloat.random(in: -50...50)
        
        return CGSize(
            width: startX + (confettiOpacity > 0 ? drift : 0),
            height: startY + (confettiOpacity > 0 ? endY : 0)
        )
    }
    
    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = Double(index) * 45.0 * .pi / 180.0
        let distance: CGFloat = 80
        
        return CGSize(
            width: cos(angle) * distance * confettiOpacity,
            height: sin(angle) * distance * confettiOpacity
        )
    }
}

// MARK: - Simplified Celebration Badge
struct ProfileCompletionBadge: View {
    let theme: ThemeManager.AppTheme
    @State private var scale = 0.0
    @State private var shine = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)
            
            Text("Profile Complete")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green,
                            Color.green.opacity(0.8)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white.opacity(shine ? 0.6 : 0), location: shine ? 0.0 : -0.3),
                                    .init(color: .white.opacity(0), location: shine ? 1.0 : 0.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        )
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.5)) {
                shine = true
            }
        }
    }
}

// MARK: - Preview
struct ProfileCompletionCelebration_Previews: PreviewProvider {
    static var previews: some View {
        ProfileCompletionCelebration(
            isShowing: .constant(true),
            theme: .light
        )
    }
}