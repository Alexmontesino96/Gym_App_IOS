//
//  RecordCelebrationCard.swift
//  Gym_API
//
//  La tarjeta de marca de S18 y S16 (UX §7).
//
//  Cuatro reglas que no se negocian:
//
//  1. **Nunca fondo lima sólido.** Borde de acento al 40 % sobre `surface/2`; un rectángulo lima
//     a pantalla completa aplasta todo lo demás de la pantalla (UX §5, S18).
//  2. **La celebración no cubre ningún CTA ni hay que descartarla.** Vive DENTRO de la tarjeta,
//     no es un overlay de pantalla completa (checklist §10.13).
//  3. **Con Reduce Motion no hay partículas, ni morph, ni conteo**: fundido de 150 ms y el mismo
//     texto. El háptico se conserva, que no es motion (UX §7).
//  4. **El texto manda.** La animación es un adorno; lo que informa es «NEW RECORD» y la cifra.
//

import SwiftUI
import TrainingCore

struct RecordCelebrationCard: View {

    let celebration: PersonalRecordCelebration
    /// `false` en modo lectura: se pinta igual, sin animación ni háptico.
    var playsCelebration: Bool = true
    /// Sugerencia de compartir del nivel 3. Nula si la pantalla no puede compartir.
    var onShare: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.trainingReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var borderProgress: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var showsParticles = false
    @State private var hasPlayed = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: celebration.isConfirmed ? "diamond.fill" : "diamond")
                    .font(.system(size: 11))
                    .foregroundColor(
                        celebration.isConfirmed
                            ? Color.dynamicAccent(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )

                Text(celebration.title)
                    .font(TrainingType.label())
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicText(theme: theme))
            }

            Text(celebration.headline)
                .font(TrainingType.headline())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            if let detail = celebration.detail {
                Text(detail)
                    .font(TrainingType.caption())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if celebration.level.suggestsSharing, let onShare {
                Button(action: {
                    HapticManager.shared.play(.light)
                    onShare()
                }) {
                    Text(Celebration.shareSuggestion)
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .opacity(contentOpacity)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(borderOverlay)
        .overlay(particles)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(celebration.accessibilityLabel)
        .onAppear(perform: play)
    }

    // MARK: - Fondo y borde

    @ViewBuilder
    private var background: some View {
        // Con Reduce Transparency el cristal pasa a superficie sólida (UX §7).
        if reduceTransparency {
            Color.dynamicSurface2(theme: theme)
        } else {
            Color.dynamicSurface2(theme: theme)
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 22)
            .trim(from: 0, to: borderProgress)
            .stroke(
                Color.dynamicAccent(theme: theme).opacity(celebration.isConfirmed ? 0.4 : 0.2),
                lineWidth: 1.5
            )
    }

    @ViewBuilder
    private var particles: some View {
        if showsParticles {
            ConfettiView(
                particleCount: celebration.level.particleCount,
                colors: [Color.dynamicAccent(theme: theme)],
                duration: celebration.level.durationSeconds,
                spreadRadius: 160
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Celebración

    private func play() {
        guard !hasPlayed else { return }
        hasPlayed = true

        guard playsCelebration, !reduceMotion else {
            borderProgress = 1
            contentOpacity = 1
            if playsCelebration { haptic() }
            return
        }

        withAnimation(.easeOut(duration: 0.2)) { contentOpacity = 1 }
        withAnimation(.easeInOut(duration: min(0.6, celebration.level.durationSeconds))) {
            borderProgress = 1
        }
        if celebration.level.usesParticles {
            showsParticles = true
        }
        haptic()
    }

    private func haptic() {
        switch celebration.level {
        case .none: break
        case .recognition: HapticManager.shared.play(.light)
        case .record, .milestone: HapticManager.shared.play(.success)
        }
    }
}
