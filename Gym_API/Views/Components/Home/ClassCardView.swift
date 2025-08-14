import SwiftUI
import UIKit

// MARK: - Class Action State Management
enum ClassActionState: Equatable {
    case available
    case registered
    case full 
    case live
    case completed(wasRegistered: Bool)
    case attended
    case cancelled
    
    struct ActionConfig {
        let text: String
        let icon: String
        let primaryColor: Color
        let backgroundColor: Color
        let isDisabled: Bool
        
        init(text: String, icon: String, primaryColor: Color, backgroundColor: Color? = nil, isDisabled: Bool = false) {
            self.text = text
            self.icon = icon
            self.primaryColor = primaryColor
            self.backgroundColor = backgroundColor ?? primaryColor.opacity(0.1)
            self.isDisabled = isDisabled
        }
    }
    
    func config(theme: ThemeManager.AppTheme) -> ActionConfig {
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
                primaryColor: Color.dynamicAccent(theme: theme),
                backgroundColor: Color.dynamicAccent(theme: theme).opacity(0.15),
                isDisabled: true
            )
        case .full:
            return ActionConfig(
                text: "Full",
                icon: "person.2.fill",
                primaryColor: Color.gray,
                isDisabled: true
            )
        case .live:
            return ActionConfig(
                text: "Live",
                icon: "dot.radiowaves.left.and.right",
                primaryColor: Color.dynamicAccent(theme: theme),
                isDisabled: true
            )
        case .attended:
            return ActionConfig(
                text: "Attended",
                icon: "checkmark.seal.fill",
                primaryColor: Color.dynamicAccent(theme: theme),
                backgroundColor: Color.dynamicAccent(theme: theme).opacity(0.15),
                isDisabled: false // Permitir ver estadísticas de la clase
            )
        case .completed(let wasRegistered):
            if wasRegistered {
                return ActionConfig(
                    text: "Great Job!",
                    icon: "trophy.fill",
                    primaryColor: Color.dynamicAccent(theme: theme),
                    backgroundColor: Color.dynamicAccent(theme: theme).opacity(0.15),
                    isDisabled: false // Permitir ver detalles/estadísticas
                )
            } else {
                return ActionConfig(
                    text: "Ended",
                    icon: "clock.badge.checkmark",
                    primaryColor: Color.dynamicTextSecondary(theme: theme),
                    backgroundColor: Color.dynamicTextSecondary(theme: theme).opacity(0.1),
                    isDisabled: true
                )
            }
        case .cancelled:
            return ActionConfig(
                text: "Cancelled",
                icon: "xmark.circle.fill",
                primaryColor: Color.red,
                isDisabled: true
            )
        }
    }
}

// MARK: - Reusable Components

/// Componente reutilizable para mostrar estadísticas en formato pill
struct StatsPill: View {
    let text: String
    let icon: String?
    let color: Color
    let theme: ThemeManager.AppTheme
    
    init(_ text: String, icon: String? = nil, color: Color, theme: ThemeManager.AppTheme) {
        self.text = text
        self.icon = icon
        self.color = color
        self.theme = theme
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Indicador Live con animación de pulso
struct LiveIndicator: View {
    let theme: ThemeManager.AppTheme
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.dynamicAccent(theme: theme))
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            
            Text("LIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
        }
        .onAppear {
            isPulsing = true
        }
    }
}

/// Iconos específicos para tipos de clases fitness
struct ClassTypeIcon: View {
    let className: String
    let theme: ThemeManager.AppTheme
    
    private var fitnessIcon: String {
        let lowercaseName = className.lowercased()
        
        if lowercaseName.contains("box") {
            return "figure.boxing"
        } else if lowercaseName.contains("yoga") {
            return "figure.mind.and.body"
        } else if lowercaseName.contains("run") || lowercaseName.contains("cardio") {
            return "figure.run"
        } else if lowercaseName.contains("strength") || lowercaseName.contains("weight") {
            return "dumbbell.fill"
        } else if lowercaseName.contains("dance") {
            return "figure.dance"
        } else if lowercaseName.contains("cycle") || lowercaseName.contains("spin") {
            return "figure.indoor.cycle"
        } else if lowercaseName.contains("swim") {
            return "figure.pool.swim"
        } else if lowercaseName.contains("climb") {
            return "figure.climbing"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
    
    var body: some View {
        Image(systemName: fitnessIcon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color.dynamicAccent(theme: theme))
            .frame(width: 24, height: 24)
    }
}

/// Botón adaptivo que cambia de estado inteligentemente
struct AdaptiveClassButton: View {
    let gymClass: GymClass
    let currentState: ClassActionState
    let isLoading: Bool
    let onJoin: () -> Void
    let onCancel: () -> Void
    let theme: ThemeManager.AppTheme
    
    @State private var showHint = false
    @State private var showActionSheet = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var animationDirection: AnimationDirection = .idle
    @State private var isPreloading = false
    @State private var glowAnimation = false
    
    enum AnimationDirection {
        case joining
        case canceling
        case idle
    }
    
    var body: some View {
        // Para estados especiales (completed y attended), usar diseños especiales
        switch currentState {
        case .completed(let wasRegistered):
            completedButton(wasRegistered: wasRegistered)
        case .attended:
            attendedButton
        default:
            standardButton
        }
    }
    
    private var attendedButton: some View {
        let config = currentState.config(theme: theme)
        
        return HStack(spacing: 10) {
            Image(systemName: config.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(glowAnimation ? 3 : -3))
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: glowAnimation
                )
            
            Text(config.text)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Glow effect sutil para attended
                RoundedRectangle(cornerRadius: 12)
                    .fill(config.primaryColor)
                    .blur(radius: 6)
                    .opacity(glowAnimation ? 0.5 : 0.2)
                    .scaleEffect(glowAnimation ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: glowAnimation
                    )
                
                // Main background con gradiente
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                config.primaryColor,
                                config.primaryColor.opacity(0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .scaleEffect(buttonScale)
        .onAppear {
            withAnimation {
                glowAnimation = true
            }
        }
        .onTapGesture {
            // Animación de tap suave
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                buttonScale = 0.97
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    buttonScale = 1.0
                }
            }
            
            // Haptic feedback suave
            if #available(iOS 13.0, *) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            
            // Aquí se puede agregar navegación a estadísticas de la clase
        }
    }
    
    private func completedButton(wasRegistered: Bool) -> some View {
        let config = currentState.config(theme: theme)
        
        return HStack(spacing: 8) {
            Image(systemName: config.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(wasRegistered && glowAnimation ? 5 : -5))
                .animation(
                    wasRegistered ? 
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : nil,
                    value: glowAnimation
                )
            
            Text(config.text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Glow effect solo para usuarios que asistieron
                if wasRegistered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(config.primaryColor)
                        .blur(radius: 8)
                        .opacity(glowAnimation ? 0.6 : 0.3)
                        .scaleEffect(glowAnimation ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: glowAnimation
                        )
                }
                
                // Main background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                config.primaryColor,
                                config.primaryColor.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .scaleEffect(buttonScale)
        .onAppear {
            if wasRegistered {
                withAnimation {
                    glowAnimation = true
                }
            }
        }
        .onTapGesture {
            // Animación de tap
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                buttonScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    buttonScale = 1.0
                }
            }
            
            // Haptic feedback
            if #available(iOS 13.0, *) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    private var standardButton: some View {
        Button(action: handleTap) {
            buttonContent
        }
        .buttonStyle(CustomButtonStyle())
        .scaleEffect(buttonScale)
        .disabled(isLoading || isPreloading)
        .modifier(ButtonAnimationsModifier(
            currentState: currentState,
            showHint: showHint,
            buttonScale: buttonScale,
            isLoading: isLoading,
            isPreloading: isPreloading,
            animationForCurrentDirection: animationForCurrentDirection
        ))
        .modifier(ButtonLifecycleModifier(
            currentState: currentState,
            animationDirection: animationDirection,
            showHint: $showHint
        ))
        .confirmationDialog("Manage Registration", isPresented: $showActionSheet, titleVisibility: .visible) {
            dialogButtons
        } message: {
            Text("What would you like to do with this class?")
        }
    }
    
    private var buttonContent: some View {
        HStack(spacing: 8) {
            buttonIcon
            buttonTextContent
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(buttonBackground)
        .foregroundColor(buttonForegroundColor)
    }
    
    private var buttonIcon: some View {
        Group {
            if isLoading || isPreloading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(buttonForegroundColor)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: currentState.config(theme: theme).icon)
                    .font(.system(size: 16, weight: .semibold))
                    .scaleEffect(currentState == .registered ? 1.0 : 0.9)
            }
        }
        .frame(width: 16, height: 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPreloading)
    }
    
    private var buttonTextContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            buttonMainText
            buttonHint
        }
    }
    
    private var buttonMainText: some View {
        Text(isLoading || isPreloading ? "Joining..." : currentState.config(theme: theme).text)
            .font(.system(size: 16, weight: .semibold))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPreloading)
    }
    
    @ViewBuilder
    private var buttonHint: some View {
        if currentState == .registered && showHint {
            Text("Tap to manage")
                .font(.system(size: 11, weight: .regular))
                .opacity(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale.combined(with: .opacity).combined(with: .move(edge: .top))
                ))
        }
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(buttonBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(buttonBorderColor, lineWidth: buttonBorderWidth)
            )
    }
    
    @ViewBuilder
    private var dialogButtons: some View {
        Button("Cancel Registration", role: .destructive) {
            handleCancelWithAnimation()
        }
        Button("Add Reminder") {
            print("Add reminder tapped")
        }
        Button("View Details") {
            print("View details tapped")
        }
        Button("Cancel", role: .cancel) { }
    }
}

// MARK: - Button Helper Modifiers and Styles
struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ButtonAnimationsModifier: ViewModifier {
    let currentState: ClassActionState
    let showHint: Bool
    let buttonScale: CGFloat
    let isLoading: Bool
    let isPreloading: Bool
    let animationForCurrentDirection: Animation
    
    func body(content: Content) -> some View {
        content
            .animation(animationForCurrentDirection, value: currentState)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showHint)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: buttonScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPreloading)
    }
}

struct ButtonLifecycleModifier: ViewModifier {
    let currentState: ClassActionState
    let animationDirection: AdaptiveClassButton.AnimationDirection
    @Binding var showHint: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if currentState == .registered {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showHint = true
                        }
                    }
                }
            }
            .onChange(of: currentState) { _, newState in
                handleStateChange(newState)
            }
    }
    
    private func handleStateChange(_ newState: ClassActionState) {
        if newState == .registered {
            if animationDirection == .joining {
                if #available(iOS 13.0, *) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showHint = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showHint = true
                }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showHint = false
            }
        }
    }
}

extension AdaptiveClassButton {
    private var buttonBackgroundColor: Color {
        switch currentState {
        case .registered:
            return Color.dynamicSurface(theme: theme) // Color de fondo de la tarjeta
        default:
            return Color.dynamicAccent(theme: theme) // Rojo marca
        }
    }
    
    private var buttonBorderColor: Color {
        switch currentState {
        case .registered:
            return Color.dynamicAccent(theme: theme) // Borde rojo de resaltado
        default:
            return Color.clear // Sin borde para estado normal
        }
    }
    
    private var buttonBorderWidth: CGFloat {
        switch currentState {
        case .registered:
            return 1.5 // Borde visible para estado registered
        default:
            return 0 // Sin borde para estado normal
        }
    }
    
    private var buttonForegroundColor: Color {
        switch currentState {
        case .registered:
            return Color.dynamicAccent(theme: theme) // Texto rojo de resaltado
        default:
            return Color.white // Texto blanco para estado normal
        }
    }
    
    private var animationForCurrentDirection: Animation {
        switch animationDirection {
        case .joining:
            return .spring(response: 0.4, dampingFraction: 0.8)
        case .canceling:
            return .spring(response: 0.3, dampingFraction: 0.85)
        case .idle:
            return .spring(response: 0.35, dampingFraction: 0.9)
        }
    }
    
    private func handleTap() {
        // Verificar si el botón está deshabilitado según la configuración del estado
        let config = currentState.config(theme: theme)
        if config.isDisabled {
            // No hacer nada si el botón está deshabilitado (live, full, etc.)
            return
        }
        
        if currentState == .registered {
            // Si ya está registrado, mostrar action sheet
            showActionSheet = true
        } else {
            // Si no está registrado y el botón está habilitado, hacer join con animación mejorada
            animationDirection = .joining
            
            // Fase 1: Comprimir ligeramente el botón y activar preloading
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                buttonScale = 0.96
                isPreloading = true
            }
            
            // Fase 2: Expandir, cambiar a loading real y ejecutar acción
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    buttonScale = 1.0
                    isPreloading = false
                }
                
                // Llamar a onJoin que debería activar isLoading
                onJoin()
            }
        }
    }
    
    private func handleCancelWithAnimation() {
        // Animación de preparación para cancelar
        animationDirection = .canceling
        
        // Fase 1: Preparación - ligera compresión
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            buttonScale = 0.97
            showHint = false
        }
        
        // Fase 2: Transición principal - cambio de estado
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(animationForCurrentDirection) {
                buttonScale = 1.0
            }
            
            // Haptic feedback al cancelar
            if #available(iOS 13.0, *) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            
            onCancel()
        }
        
        // Fase 3: Cleanup - resetear dirección de animación
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            animationDirection = .idle
        }
    }
}

/// Badge de completado con animación y diferenciación visual
struct CompletedBadge: View {
    let theme: ThemeManager.AppTheme
    let wasUserRegistered: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Fondo con efecto glow para clases completadas con éxito
            if wasUserRegistered {
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
                    .blur(radius: 8)
                    .opacity(isAnimating ? 0.6 : 0.3)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            // Badge principal
            ZStack {
                Circle()
                    .fill(wasUserRegistered ? 
                        Color.dynamicAccent(theme: theme).opacity(0.8) :
                        Color.dynamicTextSecondary(theme: theme).opacity(0.3)
                    )
                    .frame(width: 32, height: 32)
                
                Circle()
                    .stroke(
                        wasUserRegistered ?
                        Color.dynamicAccent(theme: theme).opacity(0.6) :
                        Color.dynamicTextSecondary(theme: theme).opacity(0.5),
                        lineWidth: 1.5
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: wasUserRegistered ? "checkmark.seal.fill" : "clock.badge.checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(wasUserRegistered && isAnimating ? 5 : 0))
                    .animation(
                        wasUserRegistered ? 
                        .easeInOut(duration: 0.15)
                        .repeatForever(autoreverses: true) : nil,
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            if wasUserRegistered {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnimating = true
                }
            }
        }
    }
}

/// Animación de celebración para cuando se completa una clase
struct CompletedCelebrationView: View {
    @Binding var show: Bool
    let wasUserRegistered: Bool
    let theme: ThemeManager.AppTheme
    @State private var particleOpacity: Double = 0
    @State private var particleScale: CGFloat = 0.5
    @State private var checkScale: CGFloat = 0.3
    @State private var textOpacity: Double = 0
    
    var body: some View {
        if show && wasUserRegistered {
            ZStack {
                // Partículas de celebración
                ForEach(0..<8, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                        .opacity(particleOpacity)
                        .scaleEffect(particleScale)
                        .offset(particleOffset(for: index))
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.6)
                            .delay(Double(index) * 0.05),
                            value: particleScale
                        )
                }
                
                // Contenido principal
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.dynamicAccent(theme: theme),
                                        Color.dynamicAccent(theme: theme).opacity(0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkScale)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Class Completed!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.dynamicAccent(theme: theme))
                        
                        Text("Great job on finishing the class")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.gray)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(textOpacity)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.dynamicAccent(theme: theme).opacity(0.2), lineWidth: 1)
                        )
                )
                .scaleEffect(show ? 1.0 : 0.8)
                .opacity(show ? 1.0 : 0)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    checkScale = 1.0
                    particleOpacity = 1.0
                    particleScale = 1.5
                }
                
                withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
                    textOpacity = 1.0
                }
                
                // Auto-ocultar después de 3 segundos
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        show = false
                    }
                }
            }
        }
    }
    
    private func particleOffset(for index: Int) -> CGSize {
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180
        let radius: CGFloat = 60
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }
}


// MARK: - Main Class Card View
struct ClassCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let gymClass: GymClass
    @EnvironmentObject var classService: ClassService
    @State private var trainerImageURL: String = ""
    @State private var cardPressed = false
    @State private var cachedActionState: ClassActionState = .available
    @State private var lastStateUpdateTime: Date = Date()
    @State private var needsStateUpdate: Bool = false
    @State private var showSuccessAnimation = false
    @State private var wasRegisteredBefore = false
    // @State private var showCompletedAnimation = false // Reemplazado por NotificationManager
    @State private var hasShownCompletedAnimation = false
    @State private var notificationShownForStates: Set<String> = [] // Track para evitar duplicados
    
    // Identificador único para esta instancia de la tarjeta
    private let cardInstanceId = UUID().uuidString
    
    var body: some View {
        cardContent
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(statusBadge, alignment: .topTrailing)
            .overlay(successAnimation)
            // .overlay(completedCelebration) // Reemplazado por NotificationManager
            .scaleEffect(cardPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: cardPressed)
            .onAppear {
                print("🔍 ClassCardView onAppear - Clase: \(gymClass.name)")
                print("🔍 AuthService configurado: \(classService.authService != nil)")
                print("🔍 Trainers en cache: \(classService.trainers.count)")
                
                // Inicializar wasRegisteredBefore para evitar animación en primera carga
                let currentRegistrationStatus = classService.userRegistrationStatus[gymClass.id] ?? false
                wasRegisteredBefore = currentRegistrationStatus
                
                // Inicializar estado de acción
                updateActionStateAsync()
                
                // Cargar trainers si no están cargados o hay error de autenticación
                if classService.trainers.isEmpty || classService.authenticationError {
                    print("🔍 Cargando trainers porque el cache está vacío o hay error de auth")
                    // Solo cargar si no está ya cargando para evitar requests duplicados
                    if !classService.isLoadingTrainers {
                        Task {
                            await classService.loadTrainers()
                            updateTrainerImage()
                        }
                    } else {
                        // Si ya está cargando, solo esperar y actualizar cuando termine
                        print("🔄 Ya se están cargando los trainers, esperando...")
                    }
                } else {
                    print("🔍 Usando trainers del cache")
                    updateTrainerImage()
                }
            }
            .onChange(of: classService.trainers.count) { _, _ in
                updateTrainerImage()
            }
            .onChange(of: classService.trainersLastUpdated) { _, _ in
                // Actualizar cuando se refresquen los trainers
                updateTrainerImage()
            }
            .onChange(of: classService.userRegistrationStatus) { oldValue, newValue in
                // Detectar cuando el usuario se registra exitosamente
                let wasRegistered = oldValue[gymClass.id] ?? false
                let isNowRegistered = newValue[gymClass.id] ?? false
                
                if !wasRegistered && isNowRegistered && !wasRegisteredBefore {
                    // Mostrar animación de éxito con mismo timing que botón
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccessAnimation = true
                    }
                    
                    // Haptic feedback
                    if #available(iOS 13.0, *) {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    
                    // Auto-hide después de 2 segundos con misma animación
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSuccessAnimation = false
                        }
                    }
                    
                    wasRegisteredBefore = true
                }
                
                updateActionStateAsync()
            }
            .onChange(of: classService.joiningClassIds.count) { _, _ in
                // Solo actualizar si esta clase específica terminó su operación
                if !classService.joiningClassIds.contains(gymClass.id) && !needsStateUpdate {
                    debounceStateUpdate()
                }
            }
            .onTapGesture {
                // Micro-animación de tap
                withAnimation(.easeInOut(duration: 0.1)) {
                    cardPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        cardPressed = false
                    }
                }
                
                // Si hay error de autenticación, intentar recargar trainers
                if classService.authenticationError {
                    print("🔄 Reintentando cargar trainers después de tap en tarjeta con error de auth")
                    Task {
                        await classService.loadTrainers()
                    }
                }
            }
    }
    
    // MARK: - Card Content Components
    
    private var cardContent: some View {
        HStack(spacing: 0) {
            accentLine
            mainContent
        }
    }
    
    private var accentLine: some View {
        Rectangle()
            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
            .frame(width: 6)
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            liveIndicatorHeader
            contentBody
        }
    }
    
    @ViewBuilder
    private var liveIndicatorHeader: some View {
        if currentActionState == .live {
            HStack {
                LiveIndicator(theme: themeManager.currentTheme)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
    
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            classHeader
            statsPills
            bottomSection
        }
        .padding(.horizontal, 24)
        .padding(.top, currentActionState == .live ? 12 : 20)
        .padding(.bottom, 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentActionState)
    }
    
    private var classHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Título con icono alineado
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ClassTypeIcon(className: gymClass.name, theme: themeManager.currentTheme)
                
                Text(gymClass.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                    .accessibilityLabel("Class name: \(gymClass.name)")
                
                Spacer()
            }
            
            // Información de tiempo separada
            timeInfo
                .padding(.leading, 36) // Alinear con el texto (12 spacing + 24 icon width)
        }
    }
    
    private var timeInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            Text(formattedTimeWithDuration)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
    }
    
    private var statsPills: some View {
        HStack(spacing: 8) {
            StatsPill(
                "\(duration)min",
                icon: "timer",
                color: Color.dynamicTextSecondary(theme: themeManager.currentTheme),
                theme: themeManager.currentTheme
            )
            
            StatsPill(
                spotsText,
                icon: availableSpots > 0 ? "person.2" : "person.2.fill",
                color: spotsColor,
                theme: themeManager.currentTheme
            )
            
            StatsPill(
                difficultyText,
                color: difficultyColor,
                theme: themeManager.currentTheme
            )
            
            Spacer()
        }
    }
    
    private var bottomSection: some View {
        HStack(spacing: 8) { // Reducido el spacing para dar más espacio
            instructorInfo
                .layoutPriority(1) // INVERTIDO: Prioridad menor para que se adapte al botón
                .frame(maxWidth: .infinity, alignment: .leading) // Usar espacio restante
                .clipped() // Evitar desbordamiento
            
            actionButtonsArea
                .layoutPriority(2) // INVERTIDO: Prioridad ALTA para el botón - nunca se compromete
                .fixedSize(horizontal: true, vertical: false) // Mantener tamaño natural del botón
        }
        .frame(maxWidth: .infinity) // Asegurar que use todo el ancho disponible
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentActionState)
    }
    
    private var instructorInfo: some View {
        HStack(spacing: 6) { // Reducido el spacing
            instructorImage
                .frame(width: 28, height: 28) // Ligeramente más pequeño para ahorrar espacio
            instructorName
                .layoutPriority(1) // El texto se adapta al espacio disponible
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading) // Rango más flexible
        }
        .fixedSize(horizontal: false, vertical: true) // Mantener altura fija
        .frame(maxWidth: .infinity, alignment: .leading) // Usar espacio restante
    }
    
    private var instructorImage: some View {
        AsyncImage(url: URL(string: trainerImageURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: trainerImageURL)
            case .failure(_), .empty:
                instructorPlaceholder
            @unknown default:
                instructorPlaceholder
            }
        }
        .frame(width: 28, height: 28) // Frame fijo para evitar cambios de layout
    }
    
    private var instructorPlaceholder: some View {
        Circle()
            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            .frame(width: 28, height: 28)
            .overlay(instructorPlaceholderContent)
    }
    
    @ViewBuilder
    private var instructorPlaceholderContent: some View {
        if classService.isLoadingTrainers {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .scaleEffect(0.8)
        } else if classService.authenticationError {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
    }
    
    private var instructorName: some View {
        Text(instructorDisplayName)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(
                classService.authenticationError ? 
                .orange : Color.dynamicText(theme: themeManager.currentTheme)
            )
            .lineLimit(1)
            .truncationMode(.tail) // Truncar agresivamente si es necesario
            .minimumScaleFactor(0.85) // Permitir reducción del texto si es necesario
            .fixedSize(horizontal: false, vertical: true) // Altura fija
            .frame(maxWidth: .infinity, alignment: .leading) // Usar espacio disponible
            .clipped() // Evitar desbordamiento
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: instructorDisplayName)
    }
    
    private var actionButtonsArea: some View {
        AdaptiveClassButton(
            gymClass: gymClass,
            currentState: currentActionState,
            isLoading: isLoadingAction,
            onJoin: joinAction,
            onCancel: cancelAction,
            theme: themeManager.currentTheme
        )
    }
    
    private func joinAction() {
        print("🔴 Intentando unirse a la clase \(gymClass.id): \(gymClass.name)")
        Task {
            await classService.joinClass(classId: gymClass.id)
            print("✅ Proceso de unirse a clase completado para \(gymClass.id)")
        }
    }
    
    private func cancelAction() {
        print("🔴 Cancelando registro para clase \(gymClass.id): \(gymClass.name)")
        Task {
            await classService.cancelClassRegistration(classId: gymClass.id, reason: "User cancelled from app")
            print("✅ Proceso de cancelación completado para \(gymClass.id)")
        }
    }
    
    // MARK: - Background and Overlays
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            .overlay(cardBorder)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        switch currentActionState {
        case .live:
            return Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
        case .completed(let wasRegistered) where wasRegistered:
            return Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
        default:
            return Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.1)
        }
    }
    
    private var borderWidth: CGFloat {
        switch currentActionState {
        case .live: 
            return 1.5
        case .completed(let wasRegistered) where wasRegistered: 
            return 1.0
        default: 
            return 0.5
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        ZStack {
            // Badge para estado registered
            if currentActionState == .registered {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 12, height: 12)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Badge especial para estado attended  
            if currentActionState == .attended {
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.3).combined(with: .opacity),
                    removal: .scale(scale: 0.3).combined(with: .opacity)
                ))
                .accessibilityLabel("Class attendance verified")
                .accessibilityHint("You have attended this completed class")
            }
            
            // Badge mejorado para estado completed
            if case .completed(let wasRegistered) = currentActionState {
                CompletedBadge(theme: themeManager.currentTheme, wasUserRegistered: wasRegistered)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    ))
                    .accessibilityLabel(wasRegistered ? "Class completion verified" : "Class ended")
                    .accessibilityHint(wasRegistered ? "You completed this class successfully" : "This class has ended but you were not registered")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentActionState)
    }
    
    
    @ViewBuilder
    private var successAnimation: some View {
        if showSuccessAnimation {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                Text("You're In!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(16)
            .background(successAnimationBackground)
            .scaleEffect(showSuccessAnimation ? 1.0 : 0.3)
            .opacity(showSuccessAnimation ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccessAnimation)
        }
    }
    
    // Comentado - Reemplazado por NotificationManager
    // @ViewBuilder
    // private var completedCelebration: some View {
    //     CompletedCelebrationView(
    //         show: $showCompletedAnimation,
    //         wasUserRegistered: wasUserRegisteredForClass,
    //         theme: themeManager.currentTheme
    //     )
    // }
    
    private var successAnimationBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Computed Properties
    
    /// Obtiene el estado actual (solo lectura, sin modificaciones)
    private var currentActionState: ClassActionState {
        // Verificar si necesitamos actualización asíncrona
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastStateUpdateTime)
        let shouldRecalculate = timeSinceLastUpdate > 2.0 || 
                               (cachedActionState != .registered && classService.isUserRegistered(classId: gymClass.id)) ||
                               (cachedActionState == .registered && !classService.isUserRegistered(classId: gymClass.id))
        
        if shouldRecalculate && !needsStateUpdate {
            // Programar actualización asíncrona para evitar modificar estado durante view update
            DispatchQueue.main.async {
                self.updateActionStateAsync()
            }
        }
        
        return cachedActionState
    }
    
    /// Calcula el estado actual de la clase para la UI (optimizado con nuevos estados)
    private func calculateActionState() -> ClassActionState {
        let now = Date()
        let sessionId = gymClass.id
        
        // Verificar si está cancelada
        if gymClass.status == .cancelled {
            return .cancelled
        }
        
        // Usar datos optimizados si están disponibles y son recientes
        if classService.shouldUseOptimizedParticipationData(),
           let participationStatus = classService.getParticipationStatus(sessionId: sessionId) {
            
            // Verificar si está completada o ha terminado
            if gymClass.status == .completed || now > gymClass.endTime {
                
                switch participationStatus {
                case .attended:
                    // Usuario asistió - mostrar estado especial "attended"
                    return .attended
                    
                case .registered:
                    // Usuario estaba registrado pero no se marcó asistencia - mostrar como completed
                    let notificationKey = "completed_opt_\(self.gymClass.id)"
                    if !notificationShownForStates.contains(notificationKey) {
                        print("🎉 [OPTIMIZED] Requesting completed notification for class \(self.gymClass.id) (\(self.gymClass.name)) - Card: \(self.cardInstanceId) - Key: \(notificationKey)")
                        notificationShownForStates.insert(notificationKey)
                        DispatchQueue.main.async {
                            // NotificationManager maneja la consolidación y deduplicación
                            NotificationManager.shared.showClassCompletedNotification(classId: self.gymClass.id, className: self.gymClass.name, theme: self.themeManager.currentTheme)
                            self.hasShownCompletedAnimation = true
                            
                            if #available(iOS 13.0, *) {
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.success)
                            }
                        }
                    }
                    return .completed(wasRegistered: true)
                    
                case .cancelled:
                    // Usuario canceló - mostrar como completed pero sin éxito
                    return .completed(wasRegistered: false)
                }
            }
            
            // Verificar si está en vivo - PRIORIDAD ALTA: Si está live, siempre mostrar live
            if now >= gymClass.startTime && now <= gymClass.endTime {
                return .live
            }
            
            // Estados basados en participación optimizada (solo si NO está live)
            switch participationStatus {
            case .registered:
                return .registered
            case .attended:
                // Esto no debería pasar para clases que no han terminado, pero por seguridad
                return .registered
            case .cancelled:
                // Usuario canceló, mostrar como disponible si hay espacio
                if gymClass.currentParticipants >= gymClass.maxParticipants {
                    return .full
                }
                return .available
            }
        }
        
        // Si llegamos aquí con datos optimizados válidos, no ejecutar fallback
        if classService.shouldUseOptimizedParticipationData(),
           let participationStatus = classService.getParticipationStatus(sessionId: sessionId) {
            print("🛡️ [OPTIMIZED] Preventing fallback execution for class \(self.gymClass.id) - Card: \(self.cardInstanceId)")
            // Los casos no manejados arriba deberían mostrar como disponible por defecto
            if gymClass.currentParticipants >= gymClass.maxParticipants {
                return .full
            }
            return .available
        }
        
        // Fallback al comportamiento anterior si no hay datos optimizados
        
        // Verificar si está completada o ha terminado
        if gymClass.status == .completed || now > gymClass.endTime {
            if wasUserRegisteredForClass {
                let notificationKey = "completed_fallback_\(self.gymClass.id)"
                if !notificationShownForStates.contains(notificationKey) {
                    print("🎉 [FALLBACK] Requesting completed notification for class \(self.gymClass.id) (\(self.gymClass.name)) - Card: \(self.cardInstanceId) - Key: \(notificationKey)")
                    notificationShownForStates.insert(notificationKey)
                    DispatchQueue.main.async {
                        // NotificationManager maneja la consolidación y deduplicación
                        NotificationManager.shared.showClassCompletedNotification(classId: self.gymClass.id, className: self.gymClass.name, theme: self.themeManager.currentTheme)
                        self.hasShownCompletedAnimation = true
                        
                        if #available(iOS 13.0, *) {
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                        }
                    }
                }
            }
            return .completed(wasRegistered: wasUserRegisteredForClass)
        }
        
        // Verificar si está en vivo - PRIORIDAD ALTA: Si está live, siempre mostrar live
        if now >= gymClass.startTime && now <= gymClass.endTime {
            return .live
        }
        
        // Verificar si está registrado (método legacy) - solo si NO está live
        let isRegistered = classService.isUserRegistered(classId: gymClass.id)
        print("🔍 Usuario registrado en clase \(gymClass.id): \(isRegistered)")
        if isRegistered {
            return .registered
        }
        
        // Verificar si está llena
        if gymClass.currentParticipants >= gymClass.maxParticipants {
            return .full
        }
        
        // Por defecto, disponible
        return .available
    }
    
    /// Estado de carga para acciones
    private var isLoadingAction: Bool {
        let isLoading = classService.joiningClassIds.contains(gymClass.id)
        if isLoading {
            print("🔄 Clase \(gymClass.id) está en proceso de join")
        }
        return isLoading
    }
    
    /// Duración de la clase en minutos
    private var duration: Int {
        let duration = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        return Int(duration / 60)
    }
    
    /// Plazas disponibles
    private var availableSpots: Int {
        return gymClass.maxParticipants - gymClass.currentParticipants
    }
    
    /// Hora formateada con duración
    private var formattedTimeWithDuration: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Obtener las zonas horarias
        let userTimezone = TimeZone.current
        let gymTimezoneString = gymClass.gymTimezone ?? "America/New_York"
        let gymTimezone = TimeZone(identifier: gymTimezoneString) ?? TimeZone.current
        
        // Si las zonas horarias son iguales, no hacer conversión
        if userTimezone.identifier == gymTimezone.identifier {
            formatter.timeZone = TimeZone.current
        } else {
            // Si son diferentes, usar la zona horaria del gimnasio
            formatter.timeZone = gymTimezone
        }
        
        return formatter.string(from: gymClass.startTime)
    }
    
    /// Nombre del instructor con manejo de errores
    private var instructorDisplayName: String {
        if classService.authenticationError {
            return "Login required"
        } else if classService.isLoadingTrainers {
            return "Loading..."
        } else if classService.trainersErrorMessage != nil {
            return "Error loading"
        } else {
            return gymClass.instructor
        }
    }
    
    /// Actualiza el estado de acción de forma asíncrona
    private func updateActionStateAsync() {
        guard !needsStateUpdate else { return }
        needsStateUpdate = true
        
        let newState = calculateActionState()
        let now = Date()
        
        // Usar un pequeño delay para evitar múltiples actualizaciones rápidas
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.cachedActionState != newState {
                print("🔄 Estado recalculado para clase \(self.gymClass.id): \(self.cachedActionState) -> \(newState)")
                self.cachedActionState = newState
            }
            self.lastStateUpdateTime = now
            self.needsStateUpdate = false
        }
    }
    
    /// Debounce para evitar actualizaciones muy frecuentes
    private func debounceStateUpdate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateActionStateAsync()
        }
    }
    
    /// Actualiza la imagen del trainer desde el servicio
    private func updateTrainerImage() {
        print("🔍 Actualizando imagen del trainer ID: \(gymClass.trainerId)")
        print("🔍 Trainers disponibles: \(classService.trainers.count)")
        
        if let trainer = classService.getTrainer(trainerId: gymClass.trainerId) {
            let pictureURL = trainer.picture ?? ""
            print("✅ Trainer encontrado: \(trainer.fullName)")
            print("🔍 Picture URL original: '\(pictureURL)'")
            
            // Validar que la URL no esté vacía y sea válida
            if !pictureURL.isEmpty, URL(string: pictureURL) != nil {
                print("✅ URL válida, actualizando imagen")
                // Solo actualizar si la URL cambió para evitar recargas innecesarias
                if trainerImageURL != pictureURL {
                    DispatchQueue.main.async {
                        self.trainerImageURL = pictureURL
                    }
                }
            } else {
                print("⚠️ URL inválida o vacía, usando placeholder")
                if !trainerImageURL.isEmpty {
                    DispatchQueue.main.async {
                        self.trainerImageURL = ""
                    }
                }
            }
        } else {
            print("❌ Trainer no encontrado para ID: \(gymClass.trainerId)")
            print("🔍 Trainers en cache: \(classService.trainers.map { "ID: \($0.id), Name: \($0.fullName)" }.joined(separator: ", "))")
            if !trainerImageURL.isEmpty {
                DispatchQueue.main.async {
                    self.trainerImageURL = ""
                }
            }
        }
    }
    
    /// Texto de dificultad
    private var difficultyText: String {
        switch gymClass.difficulty {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate" 
        case .advanced: return "Advanced"
        }
    }
    
    /// Color de dificultad
    private var difficultyColor: Color {
        switch gymClass.difficulty {
        case .beginner: return Color(red: 0.22, green: 0.78, blue: 0.22) // Verde
        case .intermediate: return Color(red: 0.96, green: 0.62, blue: 0.04) // Naranja
        case .advanced: return Color(red: 0.94, green: 0.27, blue: 0.27) // Rojo
        }
    }
    
    /// Texto de plazas disponibles
    private var spotsText: String {
        if availableSpots <= 0 {
            return "Full"
        } else if availableSpots == 1 {
            return "1 spot"
        } else {
            return "\(availableSpots) spots"
        }
    }
    
    /// Color para plazas disponibles
    private var spotsColor: Color {
        if availableSpots <= 0 {
            return Color.gray
        } else if availableSpots <= 3 {
            return Color(red: 0.94, green: 0.27, blue: 0.27) // Rojo - pocas plazas
        } else {
            return Color(red: 0.96, green: 0.62, blue: 0.04) // Naranja - disponible
        }
    }
    
    /// Detecta si el usuario estaba registrado en la clase (para mostrar como completada con éxito)
    private var wasUserRegisteredForClass: Bool {
        // Verificar en el estado de registro actual
        let isCurrentlyRegistered = classService.userRegistrationStatus[gymClass.id] ?? false
        
        // Si la clase ya terminó y el usuario estaba/está registrado, asumimos que asistió
        let now = Date()
        let classHasEnded = now > gymClass.endTime || gymClass.status == .completed
        
        return isCurrentlyRegistered || (wasRegisteredBefore && classHasEnded)
    }
}

// MARK: - Preview
#Preview {
    let sampleClasses = [
        GymClass(
            id: 1,
            name: "Boxing Fundamentals",
            description: "Learn the basics of boxing",
            instructor: "Coach Mike",
            trainerId: 1,
            startTime: Date().addingTimeInterval(3600), // En 1 hora
            endTime: Date().addingTimeInterval(7200), // 2 horas
            maxParticipants: 15,
            currentParticipants: 8,
            difficulty: .beginner,
            status: .available
        ),
        GymClass(
            id: 2,
            name: "Advanced Yoga Flow",
            description: "Dynamic yoga session",
            instructor: "Sarah Johnson",
            trainerId: 2,
            startTime: Date().addingTimeInterval(-1800), // Hace 30 min (en vivo)
            endTime: Date().addingTimeInterval(1800), // En 30 min
            maxParticipants: 12,
            currentParticipants: 7,
            difficulty: .advanced,
            status: .available
        ),
        GymClass(
            id: 3,
            name: "HIIT Training",
            description: "High intensity workout",
            instructor: "Coach Alex",
            trainerId: 3,
            startTime: Date().addingTimeInterval(1800), // En 30 min
            endTime: Date().addingTimeInterval(5400), // 1.5 horas
            maxParticipants: 10,
            currentParticipants: 10, // Llena
            difficulty: .intermediate,
            status: .available
        )
    ]
    
    VStack(spacing: 16) {
        ForEach(sampleClasses) { gymClass in
            ClassCardView(gymClass: gymClass)
        }
    }
    .padding()
    .background(Color.dynamicBackground(theme: .dark))
    .environmentObject(ThemeManager())
    .environmentObject(ClassService())
}