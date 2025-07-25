//
//  LoginViewAPI_Safe.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//
//  VERSIÓN SEGURA para evitar crashes SIGTERM
//  Usar esta versión si hay problemas con LoginViewAPI.swift

import SwiftUI

struct LoginViewAPI_Safe: View {
    @EnvironmentObject var authService: AuthServiceAPI_Safe
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fondo dinámico
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header con logo/título
                    headerSection
                        .frame(height: geometry.size.height * 0.5)
                    
                    // Botón de login
                    loginButtonSection
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Icono de guantes de boxeo
            Image(systemName: "figure.boxing")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            
            // Título
            Text("GYM API")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Subtítulo
            Text("Modo Seguro - Demo")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Spacer()
        }
    }
    
    private var loginButtonSection: some View {
        VStack(spacing: 24) {
            // Descripción del proceso
            VStack(spacing: 8) {
                Text("Modo Seguro Activado")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Authentication simulation without connectivity")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            
            // Botón de login principal
            Button(action: {
                Task {
                    await authService.login()
                }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 16))
                        Text("Iniciar Demo")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .foregroundColor(.white)
            }
            .disabled(authService.isLoading)
            .opacity(authService.isLoading ? 0.7 : 1.0)
            
            // Mensaje de error
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            // Información del modo seguro
            VStack(spacing: 8) {
                Text("🛡️ Modo Seguro")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• No network connectivity required")
                    Text("• Full functionality simulated")
                    Text("• Sample data preloaded")
                    Text("• Full navigation available")
                }
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding(.top, 32)
    }
}

#Preview {
    LoginViewAPI_Safe()
        .environmentObject(AuthServiceAPI_Safe())
        .environmentObject(ThemeManager())
} 