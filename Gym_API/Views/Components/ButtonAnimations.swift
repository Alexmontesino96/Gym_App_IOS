//
//  ButtonAnimations.swift
//  Gym_API
//
//  Modern button animations and effects for class registration
//

import SwiftUI

// MARK: - Particle for celebration effects
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGSize
    var color: Color
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    var rotation: Angle = .zero
}

// MARK: - Glow Modifier
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                content
                    .foregroundColor(color)
                    .blur(radius: radius)
                    .opacity(opacity)
                    .scaleEffect(1.2)
            )
    }
}

// MARK: - Elastic Transform Modifier
struct ElasticTransformModifier: AnimatableModifier {
    var stretchX: CGFloat
    var stretchY: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(stretchX, stretchY) }
        set {
            stretchX = newValue.first
            stretchY = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: stretchX, y: stretchY)
    }
}

// MARK: - Wave Shape for liquid effects
struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat = 5
    var frequency: CGFloat = 2

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let midHeight = rect.height / 2
        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: CGFloat(0), through: rect.width, by: 1) {
            let relativeX = x / rect.width
            let sine = sin(relativeX * .pi * frequency + phase)
            let y = midHeight + amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Shimmer Effect View
struct ShimmerView: View {
    @State private var shimmerPosition: CGFloat = -1
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0),
                    color.opacity(0.5),
                    color.opacity(0),
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.3)
            .offset(x: geometry.size.width * shimmerPosition)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPosition = 2
                }
            }
        }
        .maskToShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Extensions
extension View {
    func glow(color: Color, radius: CGFloat, opacity: Double = 0.8) -> some View {
        self.modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }

    func elasticTransform(stretchX: CGFloat, stretchY: CGFloat) -> some View {
        self.modifier(ElasticTransformModifier(stretchX: stretchX, stretchY: stretchY))
    }

    func maskToShape<T: Shape>(_ shape: T) -> some View {
        self.mask(shape)
    }
}

// MARK: - Haptic Pattern Generator
struct HapticPattern {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func elasticBounce() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()

        // Initial impact
        generator.impactOccurred(intensity: 0.7)

        // Bounce effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.impactOccurred(intensity: 1.0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.impactOccurred(intensity: 0.5)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            generator.impactOccurred(intensity: 0.3)
        }
    }

    static func celebration() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: .light)
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                impact.impactOccurred(intensity: 0.3 + (Double(i) * 0.1))
            }
        }
    }
}