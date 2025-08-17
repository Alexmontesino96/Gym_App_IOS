import SwiftUI

// MARK: - Improved Class Action State Configuration
extension ClassActionState {
    
    /// Configuración mejorada que mantiene coherencia con el tema de la app
    func improvedConfig(theme: ThemeManager.AppTheme) -> ActionConfig {
        switch self {
        case .available:
            return ActionConfig(
                text: "Join",
                icon: "plus.circle.fill",
                primaryColor: Color.dynamicAccent(theme: theme)
            )
            
        case .registered:
            return ActionConfig(
                text: "Joined",
                icon: "checkmark.circle.fill",
                primaryColor: Color.dynamicAccent(theme: theme).opacity(0.8),
                backgroundColor: Color.dynamicAccent(theme: theme).opacity(0.1),
                isDisabled: false
            )
            
        case .full:
            return ActionConfig(
                text: "Full",
                icon: "person.2.fill",
                primaryColor: Color.dynamicTextSecondary(theme: theme),
                backgroundColor: Color.dynamicSurface(theme: theme),
                isDisabled: true
            )
            
        case .live:
            return ActionConfig(
                text: "Live",
                icon: "dot.radiowaves.left.and.right",
                primaryColor: Color.dynamicAccent(theme: theme),
                backgroundColor: Color.dynamicAccent(theme: theme).opacity(0.15),
                isDisabled: true
            )
            
        case .attended:
            // Opción 1: Mantener acento rojo con variación premium
            return ActionConfig(
                text: "Completed",
                icon: "checkmark.seal.fill",
                primaryColor: Color.dynamicAccent(theme: theme),
                backgroundColor: createPremiumGradientBackground(theme: theme),
                isDisabled: false
            )
            
        case .completed(let wasRegistered):
            if wasRegistered {
                // DISEÑO MEJORADO: Great Job con estilo premium cohesivo
                return ActionConfig(
                    text: "Great Job!",
                    icon: "trophy.fill",
                    primaryColor: .white,
                    backgroundColor: createSuccessGradientBackground(theme: theme),
                    isDisabled: false
                )
            } else {
                return ActionConfig(
                    text: "Ended",
                    icon: "clock.badge.checkmark",
                    primaryColor: Color.dynamicTextSecondary(theme: theme),
                    backgroundColor: Color.dynamicSurface(theme: theme),
                    isDisabled: true
                )
            }
            
        case .cancelled:
            return ActionConfig(
                text: "Cancelled",
                icon: "xmark.circle.fill",
                primaryColor: Color.dynamicTextSecondary(theme: theme).opacity(0.6),
                backgroundColor: Color.dynamicSurface(theme: theme),
                isDisabled: true
            )
        }
    }
    
    /// Crea un fondo degradado premium para estados de éxito
    private func createSuccessGradientBackground(theme: ThemeManager.AppTheme) -> Color {
        // Usamos el color accent principal con variaciones para mantener coherencia
        return Color.clear // Se aplicará como gradiente en la vista
    }
    
    /// Crea un fondo degradado premium para estados completados
    private func createPremiumGradientBackground(theme: ThemeManager.AppTheme) -> Color {
        return Color.clear // Se aplicará como gradiente en la vista
    }
}

// MARK: - Improved Great Job Button
struct ImprovedGreatJobButton: View {
    let theme: ThemeManager.AppTheme
    @State private var isAnimating = false
    @State private var particleAnimation = false
    @State private var trophyRotation: Double = 0
    
    var body: some View {
        HStack(spacing: 10) {
            // Trophy icon con animación sutil
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(trophyRotation))
            
            Text("Great Job!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Fondo principal con gradiente premium
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                // Gradiente basado en el color accent rojo
                                .init(color: Color.dynamicAccent(theme: theme), location: 0.0),
                                .init(color: Color.dynamicAccent(theme: theme).opacity(0.85), location: 0.5),
                                .init(color: adjustedAccentColor(theme: theme), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Overlay sutil para dar profundidad
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Efecto de brillo sutil (sin pulsación agresiva)
                if isAnimating {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 5,
                                endRadius: 50
                            )
                        )
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .opacity(isAnimating ? 0.0 : 0.8)
                        .animation(
                            .easeOut(duration: 1.5),
                            value: isAnimating
                        )
                }
            }
        )
        .onAppear {
            // Animación inicial sutil
            withAnimation(.easeInOut(duration: 0.6)) {
                isAnimating = true
            }
            
            // Rotación sutil del trofeo
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                trophyRotation = 5
            }
        }
    }
    
    /// Color accent ajustado para crear variación en el gradiente
    private func adjustedAccentColor(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .dark:
            // Para tema oscuro, oscurecemos ligeramente el rojo
            return Color(red: 0.75, green: 0.15, blue: 0.15)
        case .light:
            // Para tema claro, usamos una variación del color accent
            return Color(red: 0, green: 0.6, blue: 0.58)
        }
    }
}

// MARK: - Alternative Monochrome Design
struct MonochromeGreatJobButton: View {
    let theme: ThemeManager.AppTheme
    @State private var shimmerOffset: CGFloat = -100
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .bold))
            
            Text("Great Job!")
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(Color.dynamicText(theme: theme))
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Fondo con patrón de textura sutil
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: theme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.dynamicAccent(theme: theme),
                                lineWidth: 2
                            )
                    )
                
                // Efecto shimmer sutil
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.dynamicAccent(theme: theme).opacity(0.1),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50)
                .offset(x: shimmerOffset)
                .mask(RoundedRectangle(cornerRadius: 12))
            }
        )
        .onAppear {
            withAnimation(
                .linear(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 200
            }
        }
    }
}

// MARK: - Premium Badge Design
struct PremiumCompletedBadge: View {
    let theme: ThemeManager.AppTheme
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Glow exterior sutil
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.dynamicAccent(theme: theme).opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .opacity(pulseAnimation ? 0.5 : 0.8)
            
            // Badge principal
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.dynamicAccent(theme: theme),
                                Color.dynamicAccent(theme: theme).opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                // Borde metálico
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 40, height: 40)
                
                // Icono
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Preview
#Preview("Button Designs") {
    VStack(spacing: 40) {
        Text("Improved Great Job Button")
            .font(.headline)
        ImprovedGreatJobButton(theme: .dark)
        
        Text("Monochrome Alternative")
            .font(.headline)
        MonochromeGreatJobButton(theme: .dark)
        
        Text("Premium Badge")
            .font(.headline)
        PremiumCompletedBadge(theme: .dark)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.dynamicBackground(theme: .dark))
}