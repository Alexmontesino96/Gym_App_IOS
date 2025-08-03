//
//  AuthStateIndicator.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Enhanced authentication state indicators with better user feedback

import SwiftUI

/// Enhanced authentication state indicator with detailed feedback
struct AuthStateIndicator: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @State private var animateConnecting = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            statusIcon
            
            // Status Text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
                
                if !statusSubtitle.isEmpty {
                    Text(statusSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Action Button (if applicable)
            if showActionButton {
                actionButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .onAppear {
            if authService.isLoading {
                startConnectingAnimation()
            }
        }
        .onChange(of: authService.isLoading) { isLoading in
            if isLoading {
                startConnectingAnimation()
            } else {
                stopConnectingAnimation()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            if authService.isLoading {
                // Loading state
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(animateConnecting ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: animateConnecting)
                
            } else if authService.isAuthenticated {
                // Authenticated
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
            } else if NetworkRetryService.shared.isCircuitBreakerOpen {
                // Network issues
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
            } else if authService.errorMessage != nil {
                // Error state
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                
            } else {
                // Not authenticated
                Image(systemName: "person.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }
    
    private var statusTitle: String {
        if authService.isLoading {
            if NetworkRetryService.shared.failureRate > 0.3 {
                return "Reintentando conexión..."
            } else {
                return "Conectando..."
            }
        } else if authService.isAuthenticated {
            return "Conectado"
        } else if NetworkRetryService.shared.isCircuitBreakerOpen {
            return "Servicio no disponible"
        } else if authService.errorMessage != nil {
            return "Error de conexión"
        } else {
            return "Desconectado"
        }
    }
    
    private var statusSubtitle: String {
        if authService.isLoading {
            let failureRate = NetworkRetryService.shared.failureRate
            if failureRate > 0.5 {
                return "Problemas de conexión detectados"
            } else if failureRate > 0.2 {
                return "Conexión inestable"
            } else {
                return "Iniciando sesión..."
            }
        } else if authService.isAuthenticated {
            if let user = authService.user {
                return "Hola, \(user.name)"
            } else {
                return "Sesión activa"
            }
        } else if NetworkRetryService.shared.isCircuitBreakerOpen {
            return "Intenta nuevamente en unos minutos"
        } else if let error = authService.errorMessage {
            return error
        } else {
            return "Toca para iniciar sesión"
        }
    }
    
    private var statusColor: Color {
        if authService.isLoading {
            return .blue
        } else if authService.isAuthenticated {
            return .green
        } else if NetworkRetryService.shared.isCircuitBreakerOpen {
            return .orange
        } else if authService.errorMessage != nil {
            return .red
        } else {
            return Color.dynamicText(theme: themeManager.currentTheme)
        }
    }
    
    private var backgroundColor: Color {
        if authService.isAuthenticated {
            return .green.opacity(0.1)
        } else if NetworkRetryService.shared.isCircuitBreakerOpen {
            return .orange.opacity(0.1)
        } else if authService.errorMessage != nil {
            return .red.opacity(0.1)
        } else {
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        }
    }
    
    private var borderColor: Color {
        return statusColor.opacity(0.3)
    }
    
    private var showActionButton: Bool {
        return !authService.isAuthenticated && !authService.isLoading
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if NetworkRetryService.shared.isCircuitBreakerOpen {
            Button("Reintentar") {
                NetworkRetryService.shared.resetCircuitBreaker()
                Task {
                    await authService.loginWithRetry()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
        } else if authService.errorMessage != nil {
            Button("Reintentar") {
                Task {
                    await authService.loginWithRetry()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Private Methods
    
    private func startConnectingAnimation() {
        withAnimation {
            animateConnecting = true
        }
    }
    
    private func stopConnectingAnimation() {
        withAnimation {
            animateConnecting = false
        }
    }
}

/// Biometric authentication button with enhanced feedback
struct BiometricAuthButton: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAttempting = false
    
    var body: some View {
        Button(action: attemptBiometricAuth) {
            HStack(spacing: 8) {
                if isAttempting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 16))
                }
                
                Text(buttonText)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue)
            )
        }
        .disabled(!authService.biometricAuthAvailable || !authService.biometricAuthEnabled || isAttempting)
        .opacity(authService.biometricAuthAvailable && authService.biometricAuthEnabled ? 1.0 : 0.6)
    }
    
    private var biometricIcon: String {
        switch authService.biometricTypeString {
        case "Face ID":
            return "faceid"
        case "Touch ID":
            return "touchid"
        case "Optic ID":
            return "opticid"
        default:
            return "person.badge.key"
        }
    }
    
    private var buttonText: String {
        if isAttempting {
            return "Verificando..."
        } else {
            return "Usar \(authService.biometricTypeString)"
        }
    }
    
    private func attemptBiometricAuth() {
        isAttempting = true
        
        Task {
            let success = await authService.attemptBiometricLogin()
            
            await MainActor.run {
                isAttempting = false
                
                if !success {
                    // Show haptic feedback for failed authentication
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
}

/// Network status indicator for debugging
struct NetworkStatusIndicator: View {
    @State private var showDetails = false
    
    var body: some View {
        Button(action: { showDetails.toggle() }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(NetworkRetryService.shared.isCircuitBreakerOpen ? .red : .green)
                    .frame(width: 8, height: 8)
                
                Text("Red")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showDetails) {
            NetworkStatusDetailView()
        }
    }
}

/// Detailed network status view for debugging
struct NetworkStatusDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                StatusRow(
                    title: "Circuit Breaker",
                    value: NetworkRetryService.shared.isCircuitBreakerOpen ? "Abierto" : "Cerrado",
                    color: NetworkRetryService.shared.isCircuitBreakerOpen ? .red : .green
                )
                
                StatusRow(
                    title: "Tasa de Fallos",
                    value: String(format: "%.1f%%", NetworkRetryService.shared.failureRate * 100),
                    color: NetworkRetryService.shared.failureRate > 0.5 ? .red : .green
                )
                
                if NetworkRetryService.shared.isCircuitBreakerOpen {
                    Button("Reiniciar Circuit Breaker") {
                        NetworkRetryService.shared.resetCircuitBreaker()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Estado de Red")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        AuthStateIndicator()
        BiometricAuthButton()
        NetworkStatusIndicator()
    }
    .padding()
    .environmentObject(AuthServiceDirect())
    .environmentObject(ThemeManager())
}