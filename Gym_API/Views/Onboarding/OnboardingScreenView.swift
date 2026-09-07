//
//  OnboardingScreenView.swift
//  Gym_API
//
//  Landing page pixel-perfect del diseño HTML
//  Pantalla principal para usuarios no autenticados
//

import SwiftUI

// MARK: - Design Tokens (forced dark mode for auth screens)
enum AuthDesign {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.04) // #0A0A0A
    static let surface = Color.darkSurfacePrimary // #1A1A1A
    static let surface2 = Color.darkSurfaceSecondary // #232323
    static let ink = Color.darkTextPrimary // #F5F5F0
    static let ink2 = Color.darkTextSecondary // #C4C4C0
    static let ink3 = Color.darkTextTertiary // #8A8A86
    static let ink4 = Color(red: 0.35, green: 0.35, blue: 0.34) // #5A5A56
    static let accent = Color.darkAccentPrimary // #D4FF3F
    static let accentInk = Color.accentInk // #0A0A0A
    static let border = Color.white.opacity(0.08)
    static let borderStrong = Color.white.opacity(0.14)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.35) // #FF5A5A
    static let warn = Color(red: 1.0, green: 0.70, blue: 0.28) // #FFB347
    static let success = Color.successGreen // #4ADE80
}

struct OnboardingScreenView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSlider = true
    @State private var showLoginScreen = false
    @State private var isAuthenticating = false

    var body: some View {
        if showSlider {
            OnboardingSliderView(
                onFinish: { withAnimation { showSlider = false } },
                onSkip: { withAnimation { showSlider = false } }
            )
        } else {
            landingContent
        }
    }

    private var landingContent: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let contentTop = safeTop + 28
            let buttonsBottom = max(28, safeBottom + 12)

            ZStack {
                // Layer 1: Dark background
                AuthDesign.bg.ignoresSafeArea()

                // Layer 2: Accent radial gradients
                accentGradients

                // Layer 3: Decorative grid
                decorativeGrid

                // Layer 4: Central glow
                centralGlow

                // Layer 5: Content
                VStack(spacing: 0) {
                    // Logo + text block
                    logoBlock
                        .padding(.top, contentTop)
                        .padding(.bottom, 24)

                    Spacer(minLength: 32)

                    // Bottom buttons
                    buttonsBlock
                        .padding(.bottom, buttonsBottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Loading overlay
                if isAuthenticating {
                    authLoadingOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showLoginScreen) {
            LoginScreenView(onBack: { showLoginScreen = false })
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
    }


    // MARK: - Accent Gradients

    private var accentGradients: some View {
        ZStack {
            // Top gradient
            RadialGradient(
                colors: [AuthDesign.accent.opacity(0.18), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            // Bottom-right gradient
            RadialGradient(
                colors: [AuthDesign.accent.opacity(0.10), .clear],
                center: UnitPoint(x: 1.0, y: 1.0),
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Decorative Grid

    private var decorativeGrid: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 32
            let gridHeight: CGFloat = 380

            // Vertical lines
            var x: CGFloat = 0
            while x <= size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: gridHeight))
                context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
                x += gridSize
            }

            // Horizontal lines
            var y: CGFloat = 0
            while y <= gridHeight {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
                y += gridSize
            }
        }
        .frame(height: 380)
        .mask(
            RadialGradient(
                colors: [.black, .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 60,
                endRadius: 260
            )
        )
        .opacity(0.5)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .drawingGroup()
    }

    // MARK: - Central Glow

    private var centralGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [AuthDesign.accent, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 120
                )
            )
            .frame(width: 240, height: 240)
            .blur(radius: 40)
            .opacity(0.35)
            .offset(y: -180)
            .allowsHitTesting(false)
    }

    // MARK: - Logo Block

    private var logoBlock: some View {
        VStack(spacing: 16) {
            // Logo square
            RoundedRectangle(cornerRadius: 24)
                .fill(AuthDesign.accent)
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(AuthDesign.accentInk)
                )
                .shadow(color: AuthDesign.accent.opacity(0.5), radius: 30, y: 10)

            // Micro label
            Text("GYM API")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.2)
                .foregroundColor(AuthDesign.accent)
                .textCase(.uppercase)
                .padding(.top, 8)

            // Display title
            Text("Your gym,\nin your pocket.")
                .font(.system(size: 44, weight: .bold))
                .tracking(-1.76)
                .lineSpacing(-8)
                .multilineTextAlignment(.center)
                .foregroundColor(AuthDesign.ink)

            // Subtitle
            Text("Book classes, scan your meals and stay close to your community. All in one app.")
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.075)
                .foregroundColor(AuthDesign.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Legal Notice

    private var legalNotice: some View {
        VStack(spacing: 2) {
            Text("By continuing you agree to our")
                .font(.system(size: 11))
                .foregroundColor(AuthDesign.ink3)

            HStack(spacing: 4) {
                Button {
                    open(SupportConfig.termsURL)
                } label: {
                    Text("Terms of Service")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AuthDesign.ink2)
                        .underline()
                }

                Text("and")
                    .font(.system(size: 11))
                    .foregroundColor(AuthDesign.ink3)

                Button {
                    open(SupportConfig.privacyURL)
                } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AuthDesign.ink2)
                        .underline()
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 6)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Buttons Block

    private var buttonsBlock: some View {
        VStack(spacing: 10) {
            // Los botones de Apple y Google se quitaron a propósito.
            //
            // Los tres llamaban a la MISMA función y abrían la pantalla genérica de Auth0, así que
            // un botón con el logotipo de Apple no ejecutaba Sign in with Apple. Eso son dos
            // problemas de revisión a la vez: la guía 4.8, que obliga a ofrecer Sign in with Apple
            // de verdad junto a cualquier otro proveedor, y la 2.3.1 por representar la app de
            // forma inexacta. Se entra por correo, que es la única conexión que se ofrece.
            Button(action: { triggerAuth(mode: .signup) }) {
                Text("Continue with email")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.16)
                    .foregroundColor(AuthDesign.accentInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Capsule().fill(AuthDesign.ink))
            }

            // Aceptación de las condiciones.
            //
            // Continuar ES el acto de aceptación, que es el patrón que Apple admite y el que menos
            // fricción mete. Lo que no vale es lo que había: dos botones de «Terms» y «Privacy»
            // con el closure vacío, en pantallas que además no se alcanzaban.
            legalNotice

            // Already a member
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AuthDesign.ink3)

                Button(action: { showLoginScreen = true }) {
                    Text("Sign in")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AuthDesign.ink3)
                        .underline()
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Loading Overlay

    private var authLoadingOverlay: some View {
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
    OnboardingScreenView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}
