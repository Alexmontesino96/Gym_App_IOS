//
//  LoginViewDirect.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//
//  Vista de login directa con Auth0 SDK oficial
//  Más simple: solo un botón para iniciar Auth0

import SwiftUI

struct LoginViewDirect: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Fondo degradado dinámico
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo y título
                VStack(spacing: 20) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("GYM API")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Bienvenido a tu gimnasio")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                // Indicador de estado de autenticación
                AuthStateIndicator()
                    .padding(.horizontal, 32)
                
                // Botón biométrico (si está disponible)
                if authService.biometricAuthAvailable && authService.biometricAuthEnabled {
                    BiometricAuthButton()
                        .padding(.bottom, 16)
                }
                
                // Botón de login con Auth0
                VStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await authService.loginWithRetry()
                        }
                    }) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "person.badge.key")
                                    .font(.system(size: 20))
                            }
                            
                            Text(getButtonText())
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                        .disabled(authService.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    // Network status indicator (solo en DEBUG)
                    #if DEBUG
                    if !authService.isAuthenticated {
                        NetworkStatusIndicator()
                            .padding(.top, 16)
                    }
                    #endif
                }
                
                Spacer()
                
                // Información del flujo mejorada
                VStack(spacing: 12) {
                    Text("🔐 Secure Authentication")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("✅ No passwords to remember")
                        Text("✅ Encrypted token storage")
                        Text("✅ Automatic retry on connection issues")
                        if authService.biometricAuthAvailable {
                            Text("✅ \(authService.biometricTypeString) support")
                        }
                        Text("✅ Persistent secure session")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
    }
    
    private func getButtonText() -> String {
        if authService.isLoading {
            if let errorMessage = authService.errorMessage,
               errorMessage.contains("Conexión perdida") || errorMessage.contains("Timeout") {
                return "Activando modo offline..."
            } else {
                return "Iniciando sesión..."
            }
        } else {
            return "Iniciar sesión con Auth0"
        }
    }
}

#Preview {
    LoginViewDirect()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
} 