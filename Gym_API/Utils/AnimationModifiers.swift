import SwiftUI

// MARK: - Shimmer Effect (for loading skeletons)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Breathing Effect

struct BreathingModifier: ViewModifier {
    @State private var isAnimating = false
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 2.0) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? maxScale : minScale)
            .animation(
                .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func breathingEffect(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 2.0) -> some View {
        modifier(BreathingModifier(minScale: minScale, maxScale: maxScale, duration: duration))
    }
}

// MARK: - Pulse Effect

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    let maxScale: CGFloat
    let duration: Double

    init(color: Color = .red, maxScale: CGFloat = 1.3, duration: Double = 1.5) {
        self.color = color
        self.maxScale = maxScale
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .opacity(isPulsing ? 0 : 0.6)
                    .scaleEffect(isPulsing ? maxScale : 1)
                    .animation(
                        .easeOut(duration: duration).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulseEffect(color: Color = .red, maxScale: CGFloat = 1.3, duration: Double = 1.5) -> some View {
        modifier(PulseModifier(color: color, maxScale: maxScale, duration: duration))
    }
}

// MARK: - 3D Rotation Effect

struct Rotation3DModifier: ViewModifier {
    let isPressed: Bool
    let degrees: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isPressed ? degrees : 0),
                axis: axis,
                perspective: 1
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(radius: isPressed ? 2 : 8, y: isPressed ? 2 : 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

extension View {
    func rotation3DPress(isPressed: Bool, degrees: Double = 10, axis: (x: CGFloat, y: CGFloat, z: CGFloat) = (1, 0, 0)) -> some View {
        modifier(Rotation3DModifier(isPressed: isPressed, degrees: degrees, axis: axis))
    }
}

// MARK: - Particle Effect (simplified version)

struct ParticleView: View {
    let index: Int
    let color: Color
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(y: offset)
            .opacity(opacity)
            .rotationEffect(.degrees(Double(index) * 45))
            .offset(particlePosition)
            .onAppear {
                startAnimation()
            }
    }

    private var particlePosition: CGSize {
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180
        let radius: CGFloat = 60
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }

    private func startAnimation() {
        withAnimation(
            .easeOut(duration: Double.random(in: 1.0...2.0))
            .delay(Double(index) * 0.1)
        ) {
            offset = -100
            opacity = 0
        }
    }
}

struct ParticleEffect: View {
    let particleCount: Int
    let color: Color

    init(particleCount: Int = 8, color: Color = .white) {
        self.particleCount = particleCount
        self.color = color
    }

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                ParticleView(index: index, color: color)
            }
        }
    }
}

// MARK: - Stagger Animation Modifier

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(Double(index) * delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, delay: Double = 0.1) -> some View {
        modifier(StaggeredAppearModifier(index: index, delay: delay))
    }
}

// MARK: - Spring Press Effect

struct SpringPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

extension View {
    func springPress(isPressed: Bool) -> some View {
        modifier(SpringPressModifier(isPressed: isPressed))
    }
}

// MARK: - Floating Animation

struct FloatingModifier: ViewModifier {
    @State private var isFloating = false
    let amplitude: CGFloat
    let duration: Double

    init(amplitude: CGFloat = 10, duration: Double = 2.0) {
        self.amplitude = amplitude
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amplitude : amplitude)
            .animation(
                .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

extension View {
    func floating(amplitude: CGFloat = 10, duration: Double = 2.0) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, duration: duration))
    }
}

// MARK: - Liquid Morph Effect (Peloton-style)

struct LiquidMorphModifier: ViewModifier {
    let isActive: Bool
    @State private var morphPhase: CGFloat = 0
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let maxDeformation: CGFloat = 0.05 // 5% máxima deformación
    private let animationDuration: Double = 0.6

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: calculateXScale(),
                y: calculateYScale()
            )
            .rotation3DEffect(
                .degrees(isActive && !reduceMotion ? Foundation.sin(morphPhase * 2) * 2 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 1.0
            )
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3),
                value: isActive
            )
            .onChange(of: isActive) { _, newValue in
                if newValue && !reduceMotion {
                    startMorphAnimation()
                } else {
                    stopMorphAnimation()
                }
            }
    }

    private func calculateXScale() -> CGFloat {
        guard !reduceMotion else { return 1.0 }

        if isActive && isAnimating {
            // Deformación orgánica usando funciones trigonométricas
            let baseScale: CGFloat = 1.0
            let morphFactor = sin(morphPhase) * maxDeformation
            let elasticFactor = cos(morphPhase * 1.5) * (maxDeformation * 0.3)
            return baseScale + morphFactor + elasticFactor
        }
        return 1.0
    }

    private func calculateYScale() -> CGFloat {
        guard !reduceMotion else { return 1.0 }

        if isActive && isAnimating {
            // Deformación inversa para mantener el volumen visual
            let baseScale: CGFloat = 1.0
            let morphFactor = cos(morphPhase) * maxDeformation
            let elasticFactor = sin(morphPhase * 1.5) * (maxDeformation * 0.3)
            return baseScale + morphFactor - elasticFactor
        }
        return 1.0
    }

    private func startMorphAnimation() {
        isAnimating = true
        morphPhase = 0

        // Animación principal con interpolación de Bézier simulada
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: animationDuration)) {
            morphPhase = .pi * 2 // Ciclo completo
        }

        // Animación secundaria para efecto más orgánico
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
            morphPhase = .pi * 2.5
        }

        // Reset suave al final
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            withAnimation(.easeOut(duration: 0.2)) {
                morphPhase = 0
                isAnimating = false
            }
        }
    }

    private func stopMorphAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            morphPhase = 0
            isAnimating = false
        }
    }
}

// MARK: - Liquid Morph Extension

extension View {
    /// Aplica el efecto Liquid Morph (estilo Peloton) con deformación orgánica
    /// - Parameter isActive: Activa o desactiva la animación
    /// - Returns: Vista con el efecto aplicado
    func liquidMorph(isActive: Bool) -> some View {
        modifier(LiquidMorphModifier(isActive: isActive))
    }
}

// MARK: - Neon Pulse Effect (for LIVE classes)

struct NeonPulseModifier: ViewModifier {
    @State private var pulsePhase: CGFloat = 0
    @State private var trailPosition: CGFloat = 0
    @State private var glowIntensity: Double = 0.3
    @State private var borderWidth: CGFloat = 2
    @State private var isAnimating: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let isLive: Bool
    @State private var gradientColors: [Color] = []
    @State private var trailOpacity: Double = 0

    // Colores del gradiente neón
    private let baseColor = Color(red: 217/255, green: 51/255, blue: 51/255) // #D93333
    private let pinkColor = Color(red: 255/255, green: 105/255, blue: 180/255)
    private let orangeColor = Color(red: 255/255, green: 140/255, blue: 90/255)

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isLive && !reduceMotion && isAnimating {
                        // Borde neón con gradiente animado
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: gradientColors),
                                    center: .center,
                                    startAngle: .degrees(trailPosition),
                                    endAngle: .degrees(trailPosition + 360)
                                ),
                                lineWidth: borderWidth
                            )
                            .blur(radius: 6 + glowIntensity * 2)
                            .opacity(0.9)
                            .animation(.easeInOut(duration: 0.3), value: borderWidth)

                        // Trail de luz secundario
                        RoundedRectangle(cornerRadius: 22)
                            .trim(from: 0, to: 0.3)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        pinkColor.opacity(trailOpacity),
                                        orangeColor.opacity(trailOpacity * 0.5),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: borderWidth + 1
                            )
                            .rotationEffect(.degrees(trailPosition))
                            .blur(radius: 8)
                    } else if isLive && reduceMotion {
                        // Fallback estático para accesibilidad
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [baseColor, pinkColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .opacity(0.6)
                    }
                }
            )
            .shadow(
                color: isLive && isAnimating ? baseColor.opacity(glowIntensity * 0.4) : Color.clear,
                radius: isLive ? (10 + glowIntensity * 5) : 0
            )
            .onAppear {
                setupGradientColors()
                if isLive && !reduceMotion {
                    startNeonAnimation()
                }
            }
            .onChange(of: isLive) { _, newValue in
                if newValue && !reduceMotion {
                    startNeonAnimation()
                } else {
                    stopNeonAnimation()
                }
            }
            .onDisappear {
                stopNeonAnimation()
            }
    }

    private func setupGradientColors() {
        // Configurar gradiente animado con transición suave
        gradientColors = [
            baseColor,
            baseColor.opacity(0.8),
            pinkColor,
            pinkColor.opacity(0.9),
            orangeColor,
            orangeColor.opacity(0.8),
            baseColor
        ]
    }

    private func startNeonAnimation() {
        isAnimating = true

        // Fase 1: Expansión del glow (0-0.5s)
        withAnimation(.easeIn(duration: 0.5)) {
            glowIntensity = 0.8
            borderWidth = 3.5
        }

        // Fase 2: Trail de luz recorre el borde (0.5-1.0s)
        withAnimation(.linear(duration: 1.0).delay(0.5)) {
            trailPosition = 360
            trailOpacity = 0.8
        }

        // Fase 3: Fade out suave (1.0-1.5s)
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            glowIntensity = 0.3
            borderWidth = 2
            trailOpacity = 0
        }

        // Repetir el ciclo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if isAnimating && isLive {
                // Reset valores para el siguiente ciclo
                trailPosition = 0
                startNeonAnimation()
            }
        }
    }

    private func stopNeonAnimation() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.3)) {
            glowIntensity = 0
            borderWidth = 2
            trailOpacity = 0
            trailPosition = 0
        }
    }
}

// MARK: - Neon Pulse Extension

extension View {
    /// Aplica el efecto Neon Pulse para clases LIVE
    /// - Parameter isLive: Si la clase está en vivo
    /// - Returns: Vista con el efecto neón pulsante
    func neonPulse(isLive: Bool) -> some View {
        modifier(NeonPulseModifier(isLive: isLive))
    }
}
