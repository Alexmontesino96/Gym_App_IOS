//
//  AuthGateView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-10-26
//
//  Auth-first onboarding screen: Users authenticate BEFORE profile setup
//  This eliminates duplicate authentication and improves conversion

import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authService: AuthServiceDirect
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var selectedButton: AuthButtonType?

    enum AuthButtonType {
        case signup, signin
    }

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
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

                Spacer()

                // Brand Section
                VStack(spacing: 20) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 20)

                    VStack(spacing: 8) {
                        Text("Ready to Transform?")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)

                        Text("Create your account to get started")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Auth Buttons
                VStack(spacing: 16) {
                    // Sign Up Button (Primary)
                    AuthButton(
                        title: "Create Account",
                        subtitle: "Start your fitness journey",
                        icon: "person.badge.plus",
                        isPrimary: true,
                        isLoading: isAuthenticating && selectedButton == .signup
                    ) {
                        authenticateUser(mode: .signup, type: .signup)
                    }

                    // Sign In Button (Secondary)
                    AuthButton(
                        title: "Sign In",
                        subtitle: "Welcome back!",
                        icon: "person.badge.key",
                        isPrimary: false,
                        isLoading: isAuthenticating && selectedButton == .signin
                    ) {
                        authenticateUser(mode: .signin, type: .signin)
                    }
                }
                .padding(.horizontal, 32)
                .disabled(isAuthenticating)

                // Error Message
                if let error = authError {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                // Legal Footer
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    HStack(spacing: 4) {
                        Button("Terms") { }
                            .font(.system(size: 12, weight: .semibold))
                        Text("and")
                            .font(.system(size: 12))
                        Button("Privacy Policy") { }
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .padding(.bottom, 40)
            }

            // Loading Overlay
            if isAuthenticating {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.dynamicAccent(theme: themeManager.currentTheme))

                    Text("Connecting to Auth0...")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(radius: 20)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func authenticateUser(mode: AuthMode, type: AuthButtonType) {
        selectedButton = type
        isAuthenticating = true
        authError = nil

        Task {
            do {
                await authService.loginWithRetry(mode: mode)

                // Verificar si autenticación fue exitosa
                await MainActor.run {
                    if authService.isAuthenticated, let user = authService.user {
                        print("✅ AuthGateView: Autenticación exitosa")
                        onboardingManager.handleAuthenticationSuccess(user: user)
                    } else {
                        authError = "Authentication failed. Please try again."
                        print("❌ AuthGateView: Autenticación falló")
                    }
                    isAuthenticating = false
                    selectedButton = nil
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    isAuthenticating = false
                    selectedButton = nil
                    print("❌ AuthGateView: Error - \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Auth Button Component

struct AuthButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isPrimary: Bool
    let isLoading: Bool
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isPrimary ? .white : Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isPrimary ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3) : Color.dynamicSurface(theme: themeManager.currentTheme))
                    )

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isPrimary ? .white : Color.dynamicText(theme: themeManager.currentTheme))

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isPrimary ? .white.opacity(0.8) : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                // Arrow or Loading
                if isLoading {
                    ProgressView()
                        .tint(isPrimary ? .white : Color.dynamicAccent(theme: themeManager.currentTheme))
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isPrimary ? .white : Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPrimary ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
    }
}
