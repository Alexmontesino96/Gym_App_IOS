import SwiftUI

// MARK: - Press Effect Modifier

/// ViewModifier que agrega efecto de press con scale y haptic feedback
struct PressEffectModifier: ViewModifier {
    let intensity: PressIntensity
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let enableHaptic: Bool

    @State private var isPressed = false

    enum PressIntensity {
        case subtle  // 0.98
        case normal  // 0.96
        case strong  // 0.94

        var scale: CGFloat {
            switch self {
            case .subtle: return 0.98
            case .normal: return 0.96
            case .strong: return 0.94
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? intensity.scale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            if enableHaptic {
                                let generator = UIImpactFeedbackGenerator(style: hapticStyle)
                                generator.impactOccurred()
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    /// Agrega efecto de press con scale y haptic feedback
    /// - Parameters:
    ///   - intensity: Intensidad del efecto (subtle, normal, strong)
    ///   - hapticStyle: Estilo del haptic feedback
    ///   - enableHaptic: Si debe usar haptic feedback
    func pressEffect(
        intensity: PressEffectModifier.PressIntensity = .normal,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        enableHaptic: Bool = true
    ) -> some View {
        modifier(PressEffectModifier(
            intensity: intensity,
            hapticStyle: hapticStyle,
            enableHaptic: enableHaptic
        ))
    }
}

// MARK: - Bounce Effect Modifier

/// ViewModifier que agrega efecto de bounce al aparecer
struct BounceEffectModifier: ViewModifier {
    let delay: Double
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared ? 1.0 : 0.8)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        hasAppeared = true
                    }
                }
            }
    }
}

extension View {
    /// Agrega efecto de bounce al aparecer
    /// - Parameter delay: Delay antes de la animación
    func bounceOnAppear(delay: Double = 0.0) -> some View {
        modifier(BounceEffectModifier(delay: delay))
    }
}

// MARK: - Slide In Effect Modifier

/// ViewModifier que agrega efecto de slide desde un edge
struct SlideInEffectModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .offset(x: hasAppeared ? 0 : offsetForEdge.width,
                   y: hasAppeared ? 0 : offsetForEdge.height)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        hasAppeared = true
                    }
                }
            }
    }

    private var offsetForEdge: CGSize {
        switch edge {
        case .leading: return CGSize(width: -50, height: 0)
        case .trailing: return CGSize(width: 50, height: 0)
        case .top: return CGSize(width: 0, height: -50)
        case .bottom: return CGSize(width: 0, height: 50)
        }
    }
}

extension View {
    /// Agrega efecto de slide in desde un edge
    /// - Parameters:
    ///   - edge: Edge desde donde aparece
    ///   - delay: Delay antes de la animación
    func slideIn(from edge: Edge = .bottom, delay: Double = 0.0) -> some View {
        modifier(SlideInEffectModifier(edge: edge, delay: delay))
    }
}

// MARK: - Ripple Effect Button Style

/// ButtonStyle que agrega efecto ripple al presionar
struct RippleButtonStyle: ButtonStyle {
    let color: Color
    @State private var rippleProgress: CGFloat = 0.0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                GeometryReader { geometry in
                    ZStack {
                        if configuration.isPressed {
                            Circle()
                                .fill(color.opacity(0.3))
                                .frame(
                                    width: geometry.size.width * 2,
                                    height: geometry.size.width * 2
                                )
                                .scaleEffect(rippleProgress)
                                .animation(
                                    .easeOut(duration: 0.6),
                                    value: rippleProgress
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    rippleProgress = 0.0
                    withAnimation {
                        rippleProgress = 1.0
                    }

                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } else {
                    rippleProgress = 0.0
                }
            }
    }
}

extension ButtonStyle where Self == RippleButtonStyle {
    /// Estilo de botón con efecto ripple
    /// - Parameter color: Color del ripple
    static func ripple(color: Color = .blue) -> RippleButtonStyle {
        RippleButtonStyle(color: color)
    }
}

// MARK: - Shimmer Effect Modifier

/// ViewModifier que agrega efecto shimmer continuo
struct ShimmerEffectModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(opacity),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 400
                }
            }
    }
}

extension View {
    /// Agrega efecto shimmer continuo
    /// - Parameters:
    ///   - duration: Duración de la animación
    ///   - opacity: Opacidad del shimmer
    func shimmer(duration: Double = 2.0, opacity: Double = 0.3) -> some View {
        modifier(ShimmerEffectModifier(duration: duration, opacity: opacity))
    }
}

// MARK: - Shake Effect Modifier

/// ViewModifier que agrega efecto de shake (útil para errores)
struct ShakeEffectModifier: ViewModifier {
    let shakes: Int
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? shakeOffset : 0)
            .animation(
                trigger ? Animation.default.repeatCount(shakes, autoreverses: true).speed(6) : .default,
                value: trigger
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        trigger = false
                    }

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
    }

    private var shakeOffset: CGFloat {
        return 10
    }
}

extension View {
    /// Agrega efecto de shake (útil para mostrar errores)
    /// - Parameters:
    ///   - trigger: Binding que activa el shake
    ///   - shakes: Número de sacudidas
    func shake(trigger: Binding<Bool>, shakes: Int = 3) -> some View {
        modifier(ShakeEffectModifier(shakes: shakes, trigger: trigger))
    }
}

// MARK: - Usage Examples

#Preview {
    struct MicroInteractionsPreview: View {
        @State private var shakeError = false

        var body: some View {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Micro-interacciones")
                        .font(.title)
                        .padding()

                    // Press effect
                    VStack(spacing: 12) {
                        Text("Press Effects")
                            .font(.headline)

                        HStack(spacing: 16) {
                            cardExample("Subtle", intensity: .subtle)
                            cardExample("Normal", intensity: .normal)
                            cardExample("Strong", intensity: .strong)
                        }
                    }

                    Divider()

                    // Slide in effects
                    VStack(spacing: 12) {
                        Text("Slide In Effects")
                            .font(.headline)

                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(.blue)
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                                .slideIn(from: .leading, delay: 0.2)

                            Rectangle()
                                .fill(.green)
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                                .slideIn(from: .top, delay: 0.4)

                            Rectangle()
                                .fill(.orange)
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                                .slideIn(from: .trailing, delay: 0.6)
                        }
                    }

                    Divider()

                    // Bounce effect
                    Rectangle()
                        .fill(.purple)
                        .frame(width: 200, height: 100)
                        .cornerRadius(16)
                        .overlay(
                            Text("Bounce Effect")
                                .foregroundColor(.white)
                        )
                        .bounceOnAppear(delay: 0.8)

                    Divider()

                    // Ripple button
                    Button("Ripple Button") {
                        print("Tapped!")
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .buttonStyle(.ripple(color: .white))

                    Divider()

                    // Shake effect
                    VStack(spacing: 12) {
                        Text("Shake Effect")
                            .font(.headline)

                        Text("❌ Error Message")
                            .foregroundColor(.red)
                            .shake(trigger: $shakeError)

                        Button("Trigger Shake") {
                            shakeError = true
                        }
                    }
                }
                .padding()
            }
        }

        func cardExample(_ title: String, intensity: PressEffectModifier.PressIntensity) -> some View {
            VStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.blue)
                    )
                    .pressEffect(intensity: intensity)
            }
        }
    }

    return MicroInteractionsPreview()
}
