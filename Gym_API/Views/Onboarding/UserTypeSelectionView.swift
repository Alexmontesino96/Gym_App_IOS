//
//  UserTypeSelectionView.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Vista para seleccionar tipo de usuario (nuevo vs existente) con diseño moderno y animaciones

import SwiftUI

struct UserTypeSelectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authService: AuthServiceDirect
    @State private var showContent = false
    @State private var selectedType: OnboardingManager.UserType? = nil
    @State private var showLoginView = false
    @State private var buttonScale: [OnboardingManager.UserType: CGFloat] = [:]
    
    var body: some View {
        ZStack {
            // Dynamic background with subtle animation
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Illustration section
                illustrationSection
                
                // User type selection buttons
                selectionSection
                
                // Footer
                footerSection
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startInitialAnimation()
            initializeButtonScales()
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginViewDirect()
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            
            VStack(spacing: 16) {
                Text("Welcome to GYM API")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                
                Text("How would you like to get started?")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .animation(.easeOut(duration: 0.8).delay(0.4), value: showContent)
        }
    }
    
    // MARK: - Illustration Section
    
    private var illustrationSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background elements
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1 - Double(index) * 0.03))
                        .frame(width: 200 + CGFloat(index * 40), height: 200 + CGFloat(index * 40))
                        .scaleEffect(showContent ? 1.0 : 0.3)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6 + Double(index) * 0.1), value: showContent)
                }
                
                // Main illustration
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 80, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .scaleEffect(showContent ? 1.0 : 0.3)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.8), value: showContent)
                    
                    VStack(spacing: 6) {
                        Text("Join Our Community")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("Thousands of members trust us")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 30)
                    .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
                }
            }
            .frame(height: 280)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Selection Section
    
    private var selectionSection: some View {
        VStack(spacing: 20) {
            ForEach([OnboardingManager.UserType.newUser, OnboardingManager.UserType.existingUser], id: \.self) { userType in
                UserTypeButton(
                    userType: userType,
                    isSelected: selectedType == userType,
                    scale: buttonScale[userType] ?? 1.0
                ) {
                    selectUserType(userType)
                }
                .scaleEffect(showContent ? 1.0 : 0.8)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2 + (userType == .newUser ? 0 : 0.2)), value: showContent)
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Trust indicators
            HStack(spacing: 24) {
                TrustIndicator(
                    icon: "shield.checkered",
                    text: "Secure",
                    color: .green
                )
                
                TrustIndicator(
                    icon: "lock.fill",
                    text: "Private",
                    color: .blue
                )
                
                TrustIndicator(
                    icon: "star.fill",
                    text: "Trusted",
                    color: .orange
                )
            }
            .opacity(showContent ? 0.8 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(1.6), value: showContent)
            
            // Terms and privacy
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                HStack(spacing: 16) {
                    Button("Terms of Service") {
                        // Handle terms
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("•")
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Button("Privacy Policy") {
                        // Handle privacy
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .opacity(showContent ? 0.6 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(1.8), value: showContent)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Methods
    
    private func startInitialAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
            }
        }
    }
    
    private func initializeButtonScales() {
        buttonScale[.newUser] = 1.0
        buttonScale[.existingUser] = 1.0
    }
    
    private func selectUserType(_ type: OnboardingManager.UserType) {
        selectedType = type
        
        // Button animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            buttonScale[type] = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale[type] = 1.0
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Handle selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if type == .existingUser {
                showLoginView = true
            } else {
                onboardingManager.selectUserType(type)
            }
        }
    }
}

// MARK: - User Type Button Component

struct UserTypeButton: View {
    let userType: OnboardingManager.UserType
    let isSelected: Bool
    let scale: CGFloat
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: userType.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(userType.displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(userType.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: isSelected 
                            ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2)
                            : Color.black.opacity(0.1),
                        radius: isSelected ? 15 : 8,
                        x: 0,
                        y: isSelected ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected 
                            ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
                            : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .scaleEffect(scale)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Trust Indicator Component

struct TrustIndicator: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }
}

#Preview {
    UserTypeSelectionView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
        .environmentObject(AuthServiceDirect())
}