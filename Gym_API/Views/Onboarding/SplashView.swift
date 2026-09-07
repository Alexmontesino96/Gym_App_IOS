import SwiftUI

// MARK: - Splash View (Prototype V1 "Saludo")
/// Pantalla de carga con saludo personal, frases amigables rotando, y loading bar sutil

struct SplashView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @StateObject private var profileService = UserProfileService.shared

    // Animation states
    @State private var avatarScale: CGFloat = 0.3
    @State private var avatarOpacity: Double = 0
    @State private var greetingOpacity: Double = 0
    @State private var greetingOffset: CGFloat = 20
    @State private var nameOpacity: Double = 0
    @State private var nameOffset: CGFloat = 20
    @State private var phraseIndex = 0
    @State private var phraseOpacity: Double = 0
    @State private var loadingOpacity: Double = 0
    @State private var haloScale: CGFloat = 0.8
    @State private var haloOpacity: Double = 0

    private let accentColor = Color(hex: "#D4FF3F")!

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Buenos días," }
        if hour < 19 { return "Buenas tardes," }
        return "Buenas noches,"
    }

    private var userName: String {
        if let profile = profileService.userProfile {
            return profile.firstName
        }
        return "Alex"
    }

    private var userInitial: String {
        String(userName.prefix(1)).uppercased()
    }

    private let phrases = [
        "Preparando tu experiencia",
        "Cargando tus datos",
        "Tu cuerpo está listo",
        "Hoy es un buen día para moverte",
        "Casi listo...",
    ]

    var body: some View {
        ZStack {
            // Background
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()

            // Halo radial suave
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)
                .blur(radius: 40)
                .offset(y: -120)

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF5A1F")!, Color(hex: "#A78BFA")!],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay(
                        Text(userInitial)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                    .scaleEffect(avatarScale)
                    .opacity(avatarOpacity)
                    .padding(.bottom, 28)

                // Greeting
                Text(greeting)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    .opacity(greetingOpacity)
                    .offset(y: greetingOffset)
                    .padding(.bottom, 6)

                // Name
                Text(userName)
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-1.8)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .opacity(nameOpacity)
                    .offset(y: nameOffset)
                    .padding(.bottom, 28)

                // Rotating phrase pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)

                    Text(phrases[phraseIndex])
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .opacity(phraseOpacity)
                .id("phrase_\(phraseIndex)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

                Spacer()

                // Loading bar at bottom
                VStack(spacing: 12) {
                    // Sliding bar
                    ZStack {
                        RoundedRectangle(cornerRadius: 100)
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08))
                            .frame(width: 56, height: 3)

                        SlidingLoadingBar(color: accentColor)
                            .frame(width: 56, height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                    }

                    Text("Preparando tu día")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.3)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))
                }
                .opacity(loadingOpacity)
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Phase 1: Halo glow
        withAnimation(.easeOut(duration: 1.0)) {
            haloScale = 1.0
            haloOpacity = 1.0
        }

        // Phase 2: Avatar pop
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.05)) {
            avatarScale = 1.0
            avatarOpacity = 1.0
        }

        // Phase 3: Greeting
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            greetingOpacity = 1.0
            greetingOffset = 0
        }

        // Phase 4: Name
        withAnimation(.easeOut(duration: 0.5).delay(0.22)) {
            nameOpacity = 1.0
            nameOffset = 0
        }

        // Phase 5: Phrase pill
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                phraseOpacity = 1.0
            }
        }

        // Phase 6: Loading bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                loadingOpacity = 1.0
            }
        }

        // Phase 7: Rotate phrases
        startPhraseRotation()

        // Phase 8: Complete after ~2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onboardingManager.nextStep()
        }
    }

    private func startPhraseRotation() {
        Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.35)) {
                phraseIndex = (phraseIndex + 1) % phrases.count
            }

            // Stop rotating after splash ends
            if phraseIndex >= phrases.count - 1 {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Sliding Loading Bar

private struct SlidingLoadingBar: View {
    let color: Color
    @State private var offset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 100)
                .fill(color)
                .frame(width: geo.size.width * 0.4)
                .offset(x: geo.size.width * offset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                    ) {
                        offset = 1.5
                    }
                }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
}
