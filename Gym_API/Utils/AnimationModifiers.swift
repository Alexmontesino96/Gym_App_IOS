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
