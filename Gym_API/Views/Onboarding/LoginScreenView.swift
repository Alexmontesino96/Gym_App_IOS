//
//  LoginScreenView.swift
//  Gym_API
//
//  Pantalla de Sign In simplificada - un solo botón que abre Auth0
//  Mismo estilo visual del diseño HTML sin formulario email/password
//

import SwiftUI

struct LoginScreenView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAuthenticating = false

    var onBack: () -> Void

    var body: some View {
        ZStack {
            // Background
            AuthDesign.bg.ignoresSafeArea()

            // Soft accent radial at top
            RadialGradient(
                colors: [AuthDesign.accent.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 300
            )
            .frame(height: 360)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Back button
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AuthDesign.ink)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(AuthDesign.surface)
                                    .overlay(
                                        Circle().stroke(AuthDesign.border, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 20)

                    // Logo + Title
                    VStack(alignment: .leading, spacing: 0) {
                        // Small logo
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AuthDesign.accent)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(AuthDesign.accentInk)
                            )
                            .padding(.bottom, 24)

                        // Title
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.12)
                            .foregroundColor(AuthDesign.ink)
                            .padding(.bottom, 8)

                        // Subtitle
                        Text("Sign in to pick up where you left off")
                            .font(.system(size: 15, weight: .regular))
                            .tracking(-0.075)
                            .foregroundColor(AuthDesign.ink2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 32)

                    // Sign In button
                    Button(action: { triggerAuth(mode: .signin) }) {
                        HStack(spacing: 8) {
                            Text("Sign in")
                                .font(.system(size: 16, weight: .semibold))
                                .tracking(-0.16)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(AuthDesign.accentInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Capsule().fill(AuthDesign.accent))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Los botones de Apple y Google, y el separador «or continue with», se
                    // quitaron con el resto del inicio de sesión social. Ver la nota en
                    // OnboardingScreenView.
                    Spacer().frame(height: 8)

                    // Footer
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AuthDesign.ink2)
                        Button(action: onBack) {
                            Text("Sign up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AuthDesign.accent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Loading overlay
            if isAuthenticating {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AuthDesign.accent)
                        Text("Connecting…")
                            .foregroundColor(AuthDesign.ink)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AuthDesign.surface)
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func triggerAuth(mode: AuthMode) {
        isAuthenticating = true
        Task {
            await authService.loginWithRetry(mode: mode)
            await MainActor.run {
                isAuthenticating = false
            }
        }
    }
}

#Preview {
    LoginScreenView(onBack: {})
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}
