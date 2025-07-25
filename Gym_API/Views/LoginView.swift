//
//  LoginView.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fondo dinámico
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header con logo/título
                    headerSection
                        .frame(height: geometry.size.height * 0.4)
                    
                    // Formulario de login
                    loginFormSection
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 24)
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
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
            Text("Train with the best")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Spacer()
        }
    }
    
    private var loginFormSection: some View {
        VStack(spacing: 24) {
            // Campos de entrada
            VStack(spacing: 16) {
                // Email
                CustomTextField(
                    text: $email,
                    placeholder: "Email",
                    icon: "envelope",
                    isSecure: false,
                    isFocused: $isEmailFocused
                )
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                
                // Password
                CustomTextField(
                    text: $password,
                    placeholder: "Password",
                    icon: "lock",
                    isSecure: !showPassword,
                    isFocused: $isPasswordFocused,
                    trailingIcon: showPassword ? "eye.slash" : "eye",
                    trailingAction: {
                        showPassword.toggle()
                    }
                )
            }
            
            // Botón de login
            Button(action: {
                Task {
                    await authService.login(email: email, password: password)
                }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Log In")
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
            .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
            .opacity(authService.isLoading || email.isEmpty || password.isEmpty ? 0.7 : 1.0)
            
            // Mensaje de error
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            // Enlace de registro
            HStack {
                Text("Don't have an account?")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Button("Sign Up") {
                    // Acción de registro
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.top, 32)
    }
}

struct CustomTextField: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var text: String
    let placeholder: String
    let icon: String
    let isSecure: Bool
    @FocusState.Binding var isFocused: Bool
    let trailingIcon: String?
    let trailingAction: (() -> Void)?
    
    init(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isSecure: Bool,
        isFocused: FocusState<Bool>.Binding,
        trailingIcon: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
        self._isFocused = isFocused
        self.trailingIcon = trailingIcon
        self.trailingAction = trailingAction
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono principal
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .frame(width: 20)
            
            // Campo de texto
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .focused($isFocused)
            
            // Icono trailing (opcional)
            if let trailingIcon = trailingIcon {
                Button(action: trailingAction ?? {}) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
                .stroke(
                    isFocused ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicBorder(theme: themeManager.currentTheme),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Color Extensions
extension Color {
    // MARK: - Primary Colors
    static let gymRed = Color(red: 0.85, green: 0.2, blue: 0.2) // #D93333
    static let gymRedLight = Color(red: 0.93, green: 0.35, blue: 0.35) // #ED5959
    static let gymRedDark = Color(red: 0.75, green: 0.15, blue: 0.15) // #BF2626
    
    // MARK: - Background Colors (Dark Theme)
    static let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D - Fondo principal
    static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.08) // #141414 - Fondo secundario
    static let backgroundTertiary = Color(red: 0.12, green: 0.12, blue: 0.12) // #1F1F1F - Fondo terciario
    
    // MARK: - Surface Colors (Cards, Components)
    static let surfacePrimary = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626 - Superficies principales
    static let surfaceSecondary = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E - Superficies secundarias
    static let surfaceElevated = Color(red: 0.22, green: 0.22, blue: 0.22) // #383838 - Superficies elevadas
    
    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2 - Texto principal
    static let textSecondary = Color(red: 0.75, green: 0.75, blue: 0.75) // #BFBFBF - Texto secundario
    static let textTertiary = Color(red: 0.55, green: 0.55, blue: 0.55) // #8C8C8C - Texto terciario
    static let textDisabled = Color(red: 0.35, green: 0.35, blue: 0.35) // #595959 - Texto deshabilitado
    
    // MARK: - Border Colors
    static let borderPrimary = Color(red: 0.25, green: 0.25, blue: 0.25) // #404040 - Bordes principales
    static let borderSecondary = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E - Bordes secundarios
    static let borderSubtle = Color(red: 0.12, green: 0.12, blue: 0.12) // #1F1F1F - Bordes sutiles
    
    // MARK: - Accent Colors
    static let accentBlue = Color(red: 0.20, green: 0.60, blue: 0.86) // #3399DB - Azul para información
    static let accentGreen = Color(red: 0.30, green: 0.70, blue: 0.40) // #4DB366 - Verde para éxito
    static let accentYellow = Color(red: 0.95, green: 0.75, blue: 0.25) // #F2BF40 - Amarillo para advertencias
    static let accentOrange = Color(red: 0.95, green: 0.50, blue: 0.25) // #F28040 - Naranja para alertas
    
    // MARK: - Semantic Colors
    static let successColor = Color(red: 0.25, green: 0.75, blue: 0.35) // #40BF59
    static let warningColor = Color(red: 0.95, green: 0.65, blue: 0.15) // #F2A626
    static let errorColor = Color(red: 0.90, green: 0.25, blue: 0.25) // #E64040
    static let infoColor = Color(red: 0.25, green: 0.55, blue: 0.85) // #408CD9
    
    // MARK: - Glassmorphism Effects
    static let glassPrimary = Color.white.opacity(0.08) // Para efectos de cristal principales
    static let glassSecondary = Color.white.opacity(0.05) // Para efectos de cristal secundarios
    static let glassElevated = Color.white.opacity(0.12) // Para efectos de cristal elevados
    
    // MARK: - Shadow Colors
    static let shadowLight = Color.black.opacity(0.15) // Sombras suaves
    static let shadowMedium = Color.black.opacity(0.25) // Sombras medianas
    static let shadowDark = Color.black.opacity(0.40) // Sombras oscuras
    
    // MARK: - Gradients
    static let gradientPrimary = LinearGradient(
        gradient: Gradient(colors: [gymRed, gymRedLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientSecondary = LinearGradient(
        gradient: Gradient(colors: [surfacePrimary, surfaceSecondary]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientBackground = LinearGradient(
        gradient: Gradient(colors: [backgroundPrimary, backgroundSecondary]),
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Keyboard Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
        .environmentObject(ThemeManager())
} 