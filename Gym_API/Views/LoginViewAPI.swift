//
//  LoginViewAPI.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//
//  Vista de login que usa el AuthServiceAPI
//  Flujo: botón → backend → Auth0 → navegador → código → token

import SwiftUI

struct LoginViewAPI: View {
    @EnvironmentObject var authService: AuthServiceAPI
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
            Text("Entrena con los mejores")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Spacer()
        }
    }
    
    private var loginButtonSection: some View {
        VStack(spacing: 24) {
            // Descripción del proceso
            VStack(spacing: 8) {
                Text("Secure Authentication")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("We will redirect you to the secure login page")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            
            // Botón de login
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
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                        Text("Log In with Auth0")
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
            
            // Botones de debug (temporal)
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await authService.testConnectivity()
                    }
                }) {
                    HStack {
                        Image(systemName: "wifi")
                            .font(.system(size: 10))
                        Text("Red")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme == .dark ? Color.blue.opacity(0.8) : Color.blue.opacity(0.6))
                    )
                    .foregroundColor(.white)
                }
                
                Button(action: {
                    Task {
                        await authService.testAPIEndpoint()
                    }
                }) {
                    HStack {
                        Image(systemName: "wrench")
                            .font(.system(size: 10))
                        Text("API")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme == .dark ? Color.orange.opacity(0.8) : Color.orange.opacity(0.6))
                    )
                    .foregroundColor(.white)
                }
                
                Button(action: {
                    Task {
                        await authService.simulateLogin()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 10))
                        Text("Demo")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme == .dark ? Color.green.opacity(0.8) : Color.green.opacity(0.6))
                    )
                    .foregroundColor(.white)
                }
            }
            .padding(.top, 8)

            // Mensaje de error
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            // Información del flujo
            VStack(spacing: 8) {
                Text("🔐 Flujo de Autenticación Seguro")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Obtenemos URL segura del servidor")
                    Text("2. Abrimos navegador para Auth0")
                    Text("3. Intercambiamos código por token")
                    Text("4. Guardamos sesión de forma segura")
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
    LoginViewAPI()
        .environmentObject(AuthServiceAPI())
        .environmentObject(ThemeManager())
} 