//
//  SplashView.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Splash screen mejorado con animaciones fluidas y transición suave al onboarding

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0.0
    @State private var titleOffset: CGFloat = 50
    @State private var titleOpacity: Double = 0.0
    @State private var progressValue: Double = 0.0
    @State private var showProgressText: Bool = false
    @State private var gradientPhase: Double = 0.0
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                    Color.dynamicBackground(theme: themeManager.currentTheme)
                ]),
                startPoint: UnitPoint(x: 0.5 + 0.3 * cos(gradientPhase), 
                                    y: 0.5 + 0.3 * sin(gradientPhase)),
                endPoint: UnitPoint(x: 0.5 - 0.3 * cos(gradientPhase), 
                                  y: 0.5 - 0.3 * sin(gradientPhase))
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    gradientPhase = 2 * .pi
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and brand section
                VStack(spacing: 24) {
                    // Animated logo
                    ZStack {
                        // Pulsing background circle
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                            .frame(width: 160, height: 160)
                            .scaleEffect(logoScale * 1.2)
                            .opacity(logoOpacity * 0.5)
                        
                        // Main logo icon
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), 
                                   radius: 20, x: 0, y: 0)
                    }
                    
                    // App title
                    VStack(spacing: 8) {
                        Text("GYM API")
                            .font(.system(size: 42, weight: .bold, design: .default))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .offset(y: titleOffset)
                            .opacity(titleOpacity)
                        
                        Text("Your Fitness Journey Starts Here")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .offset(y: titleOffset)
                            .opacity(titleOpacity * 0.8)
                    }
                }
                
                Spacer()
                
                // Loading section
                VStack(spacing: 20) {
                    // Progress indicator
                    VStack(spacing: 12) {
                        // Custom progress bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .frame(width: 200 * progressValue, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: progressValue)
                        }
                        .frame(width: 200)
                        .opacity(showProgressText ? 1.0 : 0.0)
                        
                        // Loading text
                        Text(getLoadingText())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .opacity(showProgressText ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.5), value: showProgressText)
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startSplashAnimation()
        }
    }
    
    // MARK: - Animation Logic
    
    private func startSplashAnimation() {
        // Versión optimizada sin delays artificiales

        // Phase 1: Logo animation (0-0.5 seconds)
        withAnimation(.easeOut(duration: 0.5)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Phase 2: Title animation (0.2-0.7 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
        }

        // Phase 3: Show loading indicator (0.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showProgressText = true
                progressValue = 0.5
            }
        }

        // Phase 4: Complete rápidamente (1.0 segundo total)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                progressValue = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completeOnboarding()
        }
    }
    
    private func getLoadingText() -> String {
        if progressValue < 0.5 {
            return "Cargando..."
        } else {
            return "Casi listo..."
        }
    }
    
    private func completeOnboarding() {
        // Mark splash as viewed and continue to next step
        onboardingManager.nextStep()
    }
}

// MARK: - Animated Components

struct PulsingCircle: View {
    @State private var isPulsing = false
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.1))
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

struct SplashFloatingParticle: View {
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0.0
    let color: Color
    let delay: Double
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 4, height: 4)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3.0)
                    .delay(delay)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = CGSize(
                        width: Double.random(in: -50...50),
                        height: Double.random(in: -100...100)
                    )
                    opacity = 1.0
                }
            }
    }
}

#Preview {
    SplashView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
}