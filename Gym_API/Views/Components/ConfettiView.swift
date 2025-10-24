import SwiftUI

// MARK: - Confetti View

/// Vista reutilizable de confetti para celebraciones
struct ConfettiView: View {
    let particleCount: Int
    let colors: [Color]
    let duration: Double
    let spreadRadius: CGFloat

    @State private var isActive = false

    init(
        particleCount: Int = 30,
        colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink],
        duration: Double = 3.0,
        spreadRadius: CGFloat = 300
    ) {
        self.particleCount = particleCount
        self.colors = colors
        self.duration = duration
        self.spreadRadius = spreadRadius
    }

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                AnimatedConfettiParticle(
                    color: colors.randomElement() ?? .red,
                    delay: Double(index) * 0.05,
                    duration: duration,
                    spreadRadius: spreadRadius,
                    isActive: isActive
                )
            }
        }
        .onAppear {
            isActive = true
        }
    }
}

// MARK: - Animated Confetti Particle

/// Partícula individual de confetti con formas y animaciones personalizadas
struct AnimatedConfettiParticle: View {
    let color: Color
    let delay: Double
    let duration: Double
    let spreadRadius: CGFloat
    let isActive: Bool

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0

    private let particleSize: CGFloat = CGFloat.random(in: 6...12)
    private let particleShape: ParticleShape = ParticleShape.allCases.randomElement() ?? .rectangle

    enum ParticleShape: CaseIterable {
        case rectangle, circle, triangle, star

        @ViewBuilder
        func shape(size: CGFloat, color: Color) -> some View {
            switch self {
            case .rectangle:
                Rectangle()
                    .fill(color)
                    .frame(width: size, height: size)
            case .circle:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            case .triangle:
                Triangle()
                    .fill(color)
                    .frame(width: size, height: size)
            case .star:
                Star()
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
    }

    var body: some View {
        particleShape.shape(size: particleSize, color: color)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                if isActive {
                    animateParticle()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    animateParticle()
                }
            }
    }

    private func animateParticle() {
        withAnimation(
            .easeOut(duration: duration)
            .delay(delay)
        ) {
            // Trayectoria parabólica
            let angle = Double.random(in: -Double.pi...Double.pi)
            let distance = CGFloat.random(in: spreadRadius * 0.5...spreadRadius)

            offset = CGSize(
                width: cos(angle) * distance,
                height: sin(angle) * distance + CGFloat.random(in: 200...400) // Caída con gravedad
            )

            rotation = Double.random(in: 0...720) // 2 rotaciones completas
            opacity = 0.0
            scale = CGFloat.random(in: 0.3...0.8)
        }
    }
}

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5

        for i in 0..<points * 2 {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Burst (Explosión instantánea)

/// Efecto de explosión de confetti desde un punto
struct ConfettiBurst: View {
    let particleCount: Int
    let colors: [Color]
    let origin: CGPoint

    @State private var isActive = false

    init(
        particleCount: Int = 50,
        colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange],
        origin: CGPoint = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
    ) {
        self.particleCount = particleCount
        self.colors = colors
        self.origin = origin
    }

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                BurstParticle(
                    color: colors.randomElement() ?? .red,
                    origin: origin,
                    isActive: isActive
                )
            }
        }
        .onAppear {
            isActive = true
        }
    }
}

struct BurstParticle: View {
    let color: Color
    let origin: CGPoint
    let isActive: Bool

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 1.0

    private let angle = Double.random(in: 0...(2 * .pi))
    private let velocity = CGFloat.random(in: 150...300)

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .position(position)
            .opacity(opacity)
            .onAppear {
                position = origin
                if isActive {
                    animateBurst()
                }
            }
    }

    private func animateBurst() {
        withAnimation(.easeOut(duration: 1.5)) {
            let dx = cos(angle) * velocity
            let dy = sin(angle) * velocity

            position = CGPoint(
                x: origin.x + dx,
                y: origin.y + dy
            )
            opacity = 0.0
        }
    }
}

// MARK: - Confetti Rain (Lluvia continua)

/// Efecto de lluvia de confetti continua
struct ConfettiRain: View {
    let particleCount: Int
    let colors: [Color]
    let duration: Double

    @State private var particles: [RainParticle] = []

    struct RainParticle: Identifiable {
        let id = UUID()
        var xPosition: CGFloat
        var delay: Double
        var duration: Double
        var color: Color
    }

    init(
        particleCount: Int = 20,
        colors: [Color] = [.red, .blue, .green, .yellow, .purple],
        duration: Double = 3.0
    ) {
        self.particleCount = particleCount
        self.colors = colors
        self.duration = duration
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    FallingParticle(
                        color: particle.color,
                        xPosition: particle.xPosition,
                        height: geometry.size.height,
                        delay: particle.delay,
                        duration: particle.duration
                    )
                }
            }
            .onAppear {
                generateParticles(width: geometry.size.width)
            }
        }
    }

    private func generateParticles(width: CGFloat) {
        particles = (0..<particleCount).map { index in
            RainParticle(
                xPosition: CGFloat.random(in: 0...width),
                delay: Double(index) * 0.15,
                duration: Double.random(in: duration * 0.8...duration * 1.2),
                color: colors.randomElement() ?? .blue
            )
        }
    }
}

struct FallingParticle: View {
    let color: Color
    let xPosition: CGFloat
    let height: CGFloat
    let delay: Double
    let duration: Double

    @State private var yPosition: CGFloat = -20
    @State private var rotation: Double = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(rotation))
            .position(x: xPosition, y: yPosition)
            .onAppear {
                animateFall()
            }
    }

    private func animateFall() {
        withAnimation(
            .linear(duration: duration)
            .delay(delay)
        ) {
            yPosition = height + 20
            rotation = 720
        }
    }
}

// MARK: - Preview

#Preview {
    struct ConfettiPreview: View {
        @State private var showConfetti = false
        @State private var showBurst = false
        @State private var showRain = false

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    Text("Confetti Effects")
                        .font(.title)
                        .foregroundColor(.white)

                    Button("Show Confetti") {
                        showConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showConfetti = false
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Show Burst") {
                        showBurst = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showBurst = false
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Show Rain") {
                        showRain = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            showRain = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if showConfetti {
                    ConfettiView()
                }

                if showBurst {
                    ConfettiBurst()
                }

                if showRain {
                    ConfettiRain()
                }
            }
        }
    }

    return ConfettiPreview()
}
