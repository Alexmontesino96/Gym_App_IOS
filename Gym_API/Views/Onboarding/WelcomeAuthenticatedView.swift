//
//  WelcomeAuthenticatedView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-10-26
//
//  Post-authentication welcome screen with personalization options

import SwiftUI

struct WelcomeAuthenticatedView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authService: AuthServiceDirect
    @State private var showContent = false
    @State private var celebrationScale: CGFloat = 0.5
    @State private var confettiOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Celebration Animation
                ZStack {
                    // Pulsing circles
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                            .frame(width: 150 + CGFloat(index * 40), height: 150 + CGFloat(index * 40))
                            .scaleEffect(celebrationScale)
                            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: celebrationScale)
                    }

                    // Checkmark icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .scaleEffect(showContent ? 1.0 : 0.3)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: showContent)
                }
                .padding(.bottom, 40)

                // Welcome Message
                VStack(spacing: 16) {
                    Text("Welcome, \(getUserFirstName())! 👋")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.6), value: showContent)

                    Text("You're all set! Let's personalize your experience")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: showContent)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Features Preview
                VStack(spacing: 12) {
                    OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Monitor your fitness journey")
                    OnboardingFeatureRow(icon: "calendar.badge.clock", title: "Book Classes", description: "Never miss a workout")
                    OnboardingFeatureRow(icon: "message.circle", title: "Connect", description: "Chat with trainers & members")
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(1.0), value: showContent)

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    // Primary: Personalize
                    Button(action: {
                        onboardingManager.nextStep() // → ProfileEnhancement
                    }) {
                        HStack {
                            Text("Personalize My Experience")
                                .font(.system(size: 18, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                    }

                    // Secondary: Skip
                    Button(action: {
                        // Skip profile enhancement, go to permissions
                        onboardingManager.skipProfileEnhancement()
                    }) {
                        Text("Skip for Now")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(1.2), value: showContent)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        showContent = true
        celebrationScale = 1.2
        confettiOpacity = 1.0
    }

    private func getUserFirstName() -> String {
        if !onboardingManager.userProfile.firstName.isEmpty {
            return onboardingManager.userProfile.firstName
        } else if let name = authService.user?.name {
            return name.components(separatedBy: " ").first ?? "there"
        } else {
            return "there"
        }
    }
}

// MARK: - Onboarding Feature Row Component

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}
