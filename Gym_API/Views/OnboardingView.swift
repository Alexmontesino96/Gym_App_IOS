import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var currentStep = 0
    @State private var showGymsView = false
    @State private var showLogin = false
    @State private var showContent = false
    @State private var pageOffset: CGFloat = 0
    
    private let onboardingSteps = [
        OnboardingStep(
            title: "Welcome to Your Fitness Journey",
            subtitle: "Discover local gyms, connect with your tribe, and stay motivated.",
            benefits: [
                "Access to premium gyms",
                "Real-time community chat",
                "Professional trainer support"
            ]
        ),
        OnboardingStep(
            title: "Find Your Perfect Gym",
            subtitle: "Explore gyms in your area and find the one that matches your style",
            benefits: [
                "Location-based gym discovery",
                "Detailed gym information",
                "User reviews and ratings"
            ]
        ),
        OnboardingStep(
            title: "Join the Community",
            subtitle: "Connect with trainers, join classes, and achieve your fitness goals",
            benefits: [
                "Book classes instantly",
                "Track your progress",
                "Connect with like-minded people"
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            // Enhanced dynamic background with particles
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.dynamicBackground(theme: themeManager.currentTheme),
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.08)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Floating particles background
                ForEach(0..<8, id: \.self) { index in
                    OnboardingFloatingParticle(
                        color: Color.dynamicAccent(theme: themeManager.currentTheme),
                        delay: Double(index) * 0.5
                    )
                }
            }
            
            VStack(spacing: 0) {
                // Header with back button and progress
                headerSection
                
                // Content area
                TabView(selection: $currentStep) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        EnhancedOnboardingPageView(
                            step: onboardingSteps[index],
                            pageIndex: index,
                            isActive: index == currentStep
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(showContent ? 1.0 : 0.0)
                .scaleEffect(showContent ? 1.0 : 0.9)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: showContent)
                
                // Enhanced bottom section
                bottomSection
            }
        }
        .onAppear {
            startInitialAnimation()
        }
        .fullScreenCover(isPresented: $showGymsView) {
            AvailableGymsView()
                .environmentObject(themeManager)
                .environmentObject(gymService)
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginViewDirect()
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    onboardingManager.previousStep()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                }
                
                Spacer()
                
                Button("Skip") {
                    onboardingManager.nextStep()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            
            // Progress bar
            OnboardingProgressBar(
                currentStep: currentStep,
                totalSteps: onboardingSteps.count
            )
            .padding(.horizontal, 24)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
        }
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 24) {
            // Enhanced page indicators
            HStack(spacing: 12) {
                ForEach(0..<onboardingSteps.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentStep = index
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                index == currentStep 
                                    ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                    : Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3)
                            )
                            .frame(
                                width: index == currentStep ? 24 : 8,
                                height: 8
                            )
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
                    }
                }
            }
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            
            // Enhanced continue button
            Button {
                if currentStep < onboardingSteps.count - 1 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    onboardingManager.nextStep()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(currentStep < onboardingSteps.count - 1 ? "Continue" : "Get Started")
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
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: showContent)
            .padding(.horizontal, 32)
            
            // Enhanced login button
            Button {
                showLogin = true
            } label: {
                Text("Already have an account? Log In")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .opacity(showContent ? 0.8 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
        }
        .padding(.bottom, 60)
    }
    
    private func startInitialAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
            }
        }
    }
}

// MARK: - Enhanced Onboarding Page View

struct EnhancedOnboardingPageView: View {
    let step: OnboardingStep
    let pageIndex: Int
    let isActive: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showContent = false
    @State private var iconScale: CGFloat = 1.0
    @State private var parallaxOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                // Enhanced illustration section
                illustrationSection
                
                // Enhanced text content
                textContentSection
                
                // Benefits list
                benefitsSection
                
                Spacer()
            }
            .offset(y: parallaxOffset)
            .onAppear {
                startContentAnimation()
            }
            .onChange(of: isActive) { active in
                if active {
                    startContentAnimation()
                } else {
                    hideContent()
                }
            }
        }
    }
    
    private var illustrationSection: some View {
        ZStack {
            // Animated background elements
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1 - Double(index) * 0.03))
                    .frame(width: 200 + CGFloat(index * 30), height: 200 + CGFloat(index * 30))
                    .scaleEffect(showContent ? 1.0 : 0.3)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(Double(index) * 0.1), value: showContent)
            }
            
            // Main illustration
            Group {
                if pageIndex == 0 {
                    // Page 1 - Welcome
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 80, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .scaleEffect(iconScale)
                            .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 20)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        .font(.system(size: 16))
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: showContent)
                    }
                    
                } else if pageIndex == 1 {
                    // Page 2 - Find Gym
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.system(size: 60, weight: .medium))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Image(systemName: "location.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .offset(x: 25, y: -25)
                                .opacity(showContent ? 1.0 : 0.0)
                                .scaleEffect(showContent ? 1.0 : 0.3)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: showContent)
                        }
                        .scaleEffect(iconScale)
                        
                        Text("50+ Locations")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                            )
                            .opacity(showContent ? 1.0 : 0.0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: showContent)
                    }
                    
                } else {
                    // Page 3 - Community
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 60, weight: .medium))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .offset(x: 30, y: -30)
                                .opacity(showContent ? 1.0 : 0.0)
                                .scaleEffect(showContent ? 1.0 : 0.3)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: showContent)
                        }
                        .scaleEffect(iconScale)
                        
                        Text("10k+ Members")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                            )
                            .opacity(showContent ? 1.0 : 0.0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: showContent)
                    }
                }
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .opacity(showContent ? 1.0 : 0.0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconScale = 1.1
                    }
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconScale = 1.1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        iconScale = 1.0
                    }
                }
            }
        }
        .frame(height: 220)
        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4), value: showContent)
    }
    
    private var textContentSection: some View {
        VStack(spacing: 20) {
            Text(step.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 30)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
            
            Text(step.subtitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 30)
    }
    
    private var benefitsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(step.benefits.enumerated()), id: \.offset) { index, benefit in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text(benefit)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(x: showContent ? 0 : -50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6 + Double(index) * 0.1), value: showContent)
            }
        }
        .padding(.horizontal, 32)
    }
    
    private func startContentAnimation() {
        withAnimation {
            showContent = true
        }
    }
    
    private func hideContent() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showContent = false
        }
    }
}

// MARK: - Supporting Components

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    @EnvironmentObject var themeManager: ThemeManager
    
    var progress: Double {
        return Double(currentStep) / Double(max(totalSteps - 1, 1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

struct OnboardingFloatingParticle: View {
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0.0
    let color: Color
    let delay: Double
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.2))
            .frame(width: 6, height: 6)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 4...8))
                    .delay(delay)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = CGSize(
                        width: Double.random(in: -100...100),
                        height: Double.random(in: -150...150)
                    )
                    opacity = Double.random(in: 0.3...0.8)
                }
            }
    }
}

struct OnboardingStep {
    let title: String
    let subtitle: String
    let benefits: [String]
}

#Preview {
    OnboardingView()
        .environmentObject(ThemeManager())
        .environmentObject(GymService.shared)
        .environmentObject(OnboardingManager())
}