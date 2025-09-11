import SwiftUI
import Foundation

// MARK: - Animated Profile Metric
struct AnimatedProfileMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let delay: Double
    let theme: ThemeManager.AppTheme
    
    @State private var isVisible = false
    @State private var iconRotation = 0.0
    @State private var scale = 0.3
    @State private var sparkleOpacity = 0.0
    @State private var glowIntensity = 0.0
    @State private var currentValue = 0
    @State private var bounceOffset: CGFloat = 0
    
    // Parse numeric value for animation
    private var numericValue: Int {
        // Extract number from strings like "63 kg" or "179 cm"
        let numbers = value.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        return Int(numbers) ?? 0
    }
    
    private var valueSuffix: String {
        // Extract suffix like "kg" or "cm"
        let components = value.components(separatedBy: " ")
        return components.count > 1 ? components[1] : ""
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Label at the top
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .opacity(isVisible ? 1 : 0)
                .lineLimit(1)
            
            // Animated icon in the middle (bigger)
            ZStack {
                // Sparkles
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: 3, height: 3)
                        .opacity(sparkleOpacity)
                        .offset(sparkleOffset(for: index))
                        .scaleEffect(sparkleOpacity)
                }
                
                // Icon container with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.2),
                                color.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                
                // Animated icon - bigger
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(iconRotation))
                    .offset(y: bounceOffset)
            }
            .scaleEffect(scale)
            
            // Animated value at the bottom
            HStack(spacing: 2) {
                if numericValue > 0 {
                    Text("\(currentValue)")
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundColor(Color.dynamicText(theme: theme))
                    
                    if !valueSuffix.isEmpty {
                        Text(valueSuffix)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: theme))
                    }
                } else {
                    Text(value)
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    private func animateEntrance() {
        // Staggered entrance based on delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Scale and visibility
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                isVisible = true
            }
            
            // Icon rotation based on type
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                switch icon {
                case "dumbbell.fill":
                    iconRotation = 360
                case "scalemass.fill":
                    iconRotation = -15
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            iconRotation = 15
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                iconRotation = 0
                            }
                        }
                    }
                case "arrow.up.and.down":
                    // Bounce animation for height
                    withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                        bounceOffset = -8
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.6)) {
                        bounceOffset = 0
                    }
                default:
                    iconRotation = 360
                }
            }
            
            // Sparkle effect
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                sparkleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                sparkleOpacity = 0.0
            }
            
            // Counter animation for numeric values
            if numericValue > 0 {
                animateCounter()
            }
        }
    }
    
    private func animateCounter() {
        let duration = 1.0
        let steps = 30
        let stepDuration = duration / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration + 0.3) {
                currentValue = Int(Double(numericValue) * Double(step) / Double(steps))
            }
        }
    }
    
    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = Double(index) * 60.0 * .pi / 180.0
        let distance: CGFloat = 30
        return CGSize(
            width: CGFloat(cos(angle)) * distance,
            height: CGFloat(sin(angle)) * distance
        )
    }
}

// MARK: - Preview
struct AnimatedProfileMetric_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 40) {
            AnimatedProfileMetric(
                icon: "dumbbell.fill",
                value: "15",
                label: "Workouts",
                color: .orange,
                delay: 0,
                theme: .light
            )
            
            AnimatedProfileMetric(
                icon: "scalemass.fill",
                value: "75 kg",
                label: "Weight",
                color: .blue,
                delay: 0.2,
                theme: .light
            )
            
            AnimatedProfileMetric(
                icon: "arrow.up.and.down",
                value: "180 cm",
                label: "Height",
                color: .green,
                delay: 0.4,
                theme: .light
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}