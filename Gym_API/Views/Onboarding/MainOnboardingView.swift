//
//  MainOnboardingView.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Vista principal que orquesta todo el flujo de onboarding renovado
//  Maneja la navegación entre todas las pantallas según el estado del OnboardingManager

import SwiftUI

struct MainOnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var gymService: GymService
    @State private var showTransition = false
    
    var body: some View {
        ZStack {
            // Main onboarding flow
            Group {
                switch onboardingManager.currentFlow {
                case .splash:
                    SplashView()
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .benefits:
                    BenefitsCarouselView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .userTypeSelection:
                    UserTypeSelectionView()
                        .environmentObject(authService)
                        .environmentObject(themeManager)
                        .environmentObject(onboardingManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .profileSetup:
                    ProfileSetupView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .permissions:
                    PermissionsSetupView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .complete:
                    CompletionView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: onboardingManager.currentFlow)
            
            // Global onboarding overlay for debug (only in DEBUG builds)
            #if DEBUG
            if onboardingManager.showOnboarding {
                OnboardingDebugOverlay()
            }
            #endif
        }
        .environmentObject(onboardingManager)
        .environmentObject(themeManager)
        .environmentObject(authService)
        .environmentObject(gymService)
        .onAppear {
            // Ensure onboarding status is checked
            onboardingManager.checkOnboardingStatus()
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showContent = false
    @State private var celebrationScale: CGFloat = 1.0
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            // Celebration background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15),
                    Color.dynamicBackground(theme: themeManager.currentTheme)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Confetti particles
            if showConfetti {
                ForEach(0..<20, id: \.self) { index in
                    ConfettiParticle(
                        delay: Double(index) * 0.1,
                        color: [Color.red, Color.blue, Color.green, Color.yellow, Color.purple].randomElement() ?? Color.red
                    )
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Celebration animation
                VStack(spacing: 30) {
                    ZStack {
                        // Pulsing circles
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1 - Double(index) * 0.03))
                                .frame(width: 200 + CGFloat(index * 40), height: 200 + CGFloat(index * 40))
                                .scaleEffect(celebrationScale)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(index) * 0.3), value: celebrationScale)
                        }
                        
                        // Main celebration icon
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80, weight: .medium))
                                .foregroundColor(.green)
                                .scaleEffect(showContent ? 1.0 : 0.3)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.5), value: showContent)
                            
                            VStack(spacing: 8) {
                                Text("🎉")
                                    .font(.system(size: 40))
                                    .scaleEffect(showContent ? 1.0 : 0.3)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.8), value: showContent)
                                
                                Text("Welcome to the Gym Community!")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                    .opacity(showContent ? 1.0 : 0.0)
                                    .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
                            }
                        }
                    }
                    
                    // Welcome message
                    VStack(spacing: 20) {
                        Text("You're All Set!")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1.0 : 0.0)
                            .scaleEffect(showContent ? 1.0 : 0.8)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
                        
                        VStack(spacing: 12) {
                            Text("Thanks for setting up your profile!")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.center)
                            
                            let userFullName = onboardingManager.userProfile.fullName
                            if !userFullName.isEmpty {
                                Text("Ready to start your fitness journey, \(userFullName)?")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.6), value: showContent)
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Next steps preview
                VStack(spacing: 16) {
                    Text("What's Next:")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    VStack(spacing: 12) {
                        NextStepItem(
                            icon: "building.2.crop.circle.fill",
                            title: "Find Gyms Near You",
                            subtitle: "Discover partner locations"
                        )
                        
                        NextStepItem(
                            icon: "person.3.fill",
                            title: "Join the Community",
                            subtitle: "Connect with trainers and members"
                        )
                        
                        NextStepItem(
                            icon: "calendar.badge.plus",
                            title: "Book Your First Class",
                            subtitle: "Start your fitness journey"
                        )
                    }
                }
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(1.2), value: showContent)
                .padding(.horizontal, 32)
                
                // Continue button
                Button(action: {
                    // This will be handled by the main app navigation
                    // For now, just mark onboarding as complete
                    completeOnboardingFlow()
                }) {
                    HStack(spacing: 12) {
                        Text("Start Exploring")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .shadow(
                                color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                radius: 20, x: 0, y: 10
                            )
                    )
                }
                .scaleEffect(showContent ? 1.0 : 0.8)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4), value: showContent)
                .padding(.horizontal, 32)
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startCelebrationAnimation()
        }
    }
    
    private func startCelebrationAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
                celebrationScale = 1.1
                showConfetti = true
            }
        }
    }
    
    private func completeOnboardingFlow() {
        // This will hide the onboarding flow and show the main app
        withAnimation(.easeInOut(duration: 0.8)) {
            onboardingManager.showOnboarding = false
        }
    }
}

// MARK: - Supporting Components

struct NextStepItem: View {
    let icon: String
    let title: String
    let subtitle: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

struct ConfettiParticle: View {
    let delay: Double
    let color: Color
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 3.0)
                    .delay(delay)
                ) {
                    offset = CGSize(
                        width: Double.random(in: -200...200),
                        height: Double.random(in: 300...600)
                    )
                    rotation = Double.random(in: 0...360)
                    opacity = 0.0
                }
            }
    }
}

// MARK: - Debug Overlay (DEBUG only)

#if DEBUG
struct OnboardingDebugOverlay: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showDebugPanel = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: {
                    showDebugPanel.toggle()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 60)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showDebugPanel) {
            OnboardingDebugPanel()
        }
    }
}

struct OnboardingDebugPanel: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Flow: \(onboardingManager.currentFlow.title)")
                        .font(.headline)
                    
                    Text("Progress: \(Int(onboardingManager.currentFlow.progressPercentage * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("User Type: \(onboardingManager.userType?.displayName ?? "Not Selected")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Steps:")
                        .font(.headline)
                    
                    ForEach(Array(onboardingManager.completedSteps), id: \.self) { step in
                        Text("• \(step.displayName)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                VStack(spacing: 12) {
                    Button("Reset Onboarding") {
                        onboardingManager.resetOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Complete Onboarding") {
                        onboardingManager.completeOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Skip to Next Step") {
                        onboardingManager.nextStep()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Onboarding Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif

#Preview {
    MainOnboardingView()
        .environmentObject(OnboardingManager())
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(GymService.shared)
}