import SwiftUI

// MARK: - Comeback CTA Section
/// Sección de Call-to-Action para la vista de comeback con botón primario y opción de posponer
struct ComebackCTASection: View {
    let theme: ThemeManager.AppTheme
    let urgency: ComebackMessage.UrgencyLevel
    let onScheduleClass: () -> Void
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var isPrimaryPressed = false
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(spacing: 20) {
            // CTA Primario: VER CLASES DISPONIBLES
            primaryButton

            // CTA Secundario: Recordarme después
            tertiaryButton
        }
        .padding(.vertical, 8)
        .opacity(isAnimating ? 1.0 : 0.0)
        .offset(y: isAnimating ? 0 : 30)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
                isAnimating = true
            }

            // Iniciar shimmer después de que termine la animación de entrada
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = 400
                }
            }
        }
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            onScheduleClass()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 18, weight: .semibold))

                Text("VER CLASES DISPONIBLES")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    // Gradient background basado en urgencia (WCAG Compliant)
                    LinearGradient(
                        gradient: Gradient(colors: Color.urgencyGradientColors(for: urgency)),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Shimmer effect sutil
                    if urgency == .high || urgency == .critical {
                        shimmerOverlay
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: Color.urgencyGradientColors(for: urgency).first?.opacity(0.4) ?? Color.dynamicAccent(theme: theme).opacity(0.4),
                radius: isPrimaryPressed ? 4 : 12,
                x: 0,
                y: isPrimaryPressed ? 2 : 6
            )
            .scaleEffect(isPrimaryPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPrimaryPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPrimaryPressed = false
                    }
                }
        )
        .accessibilityLabel("Ver clases disponibles")
        .accessibilityHint("Abre el listado de clases para agendar")
    }

    // MARK: - Tertiary Button

    private var tertiaryButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()

            onDismiss()
        }) {
            Text("Recordarme después")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Recordarme después")
        .accessibilityHint("Cierra esta pantalla y muestra un recordatorio más tarde")
    }

    // MARK: - Shimmer Overlay

    private var shimmerOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.white.opacity(0.3), location: 0.5),
                        .init(color: Color.clear, location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: shimmerOffset)
            .clipped()
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        // Urgencia media - Tema oscuro
        ComebackCTASection(
            theme: .dark,
            urgency: .medium,
            onScheduleClass: { print("Schedule tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
        .background(Color.dynamicBackground(theme: .dark))

        // Urgencia crítica - Tema claro
        ComebackCTASection(
            theme: .light,
            urgency: .critical,
            onScheduleClass: { print("Schedule tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
        .background(Color.dynamicBackground(theme: .light))
    }
}
