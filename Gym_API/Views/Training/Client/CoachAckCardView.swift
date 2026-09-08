//
//  CoachAckCardView.swift
//  Gym_API
//
//  Acuse del entrenador (UX §4, «Coach acknowledgement»).
//
//  Dos reglas de esta tarjeta, y las dos son de producto, no de dibujo:
//
//  1. **Si no hay acuse, la tarjeta no existe.** Nunca «Your coach hasn't looked yet»: eso es una
//     acusación contra alguien que a lo mejor está dando una clase.
//  2. **«Thanks» es optimista y reversible.** Se rellena en el momento; si el envío falla, vuelve
//     con una línea que dice cómo reintentar. Nadie espera a un servidor para dar las gracias.
//

import SwiftUI
import TrainingCore

struct CoachAckCardView: View {

    let activity: TrainingCoachActivity
    /// Abre el chat con el coach y el mensaje citado.
    let onReply: () -> Void
    /// `POST /logs/{id}/thank`. Devuelve `false` si el servidor lo rechazó.
    let onThank: () async -> Bool

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var isThanked = false
    @State private var isSending = false
    @State private var failed = false
    @State private var heartScale: CGFloat = 1

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var coachName: String { activity.coach?.name.components(separatedBy: " ").first ?? "Your coach" }

    /// «Marcus saw Tuesday's log». El día viene de la revisión, no de hoy.
    private var headline: String {
        guard let reviewedAt = activity.reviewedAt else { return "\(coachName) saw your log" }
        let weekday = DateFormatter.localized(template: "EEEE").string(from: reviewedAt)
        return "\(coachName) saw \(weekday)'s log"
    }

    private var thanked: Bool { isThanked || activity.clientThanked }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(headline)
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    if let reviewedAt = activity.reviewedAt {
                        Text(TrainingFormat.relative(reviewedAt))
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                            .fixedSize()
                    }
                }
                .accessibilityElement(children: .combine)

                if let comment = activity.comment, !comment.isEmpty {
                    Text("“\(comment)”")
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if activity.congratulated {
                    Text("\(coachName) congratulated you")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }

                actions

                if failed {
                    Text("Couldn't send. Tap to retry.")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
        }
        .trainingCard(theme: theme)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Avatar

    private var avatar: some View {
        Group {
            if let url = activity.coach?.pictureURL, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsCircle
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(activity.coach?.initials ?? "?")
                .font(TrainingType.caption())
                .fontWeight(.semibold)
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
    }

    // MARK: - Acciones

    private var actions: some View {
        HStack(spacing: 12) {
            if activity.comment?.isEmpty == false {
                Button(action: {
                    HapticManager.shared.play(.selection)
                    onReply()
                }) {
                    Text("Reply")
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
                .accessibilityLabel("Reply to \(coachName)")
                .accessibilityHint("Opens the chat with the message quoted.")
            }

            Spacer(minLength: 0)

            thanksButton
        }
    }

    private var thanksButton: some View {
        Button(action: sendThanks) {
            HStack(spacing: 6) {
                Image(systemName: thanked ? "heart.fill" : "heart")
                    .font(TrainingType.icon(15, weight: .semibold))
                    .foregroundColor(
                        thanked
                            ? Color.dynamicAccentText(theme: theme)
                            : Color.dynamicTextSecondary(theme: theme)
                    )
                    .scaleEffect(heartScale)

                Text("Thanks")
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: theme))
            }
            .padding(.horizontal, 8)
            .trainingTouchTarget()
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityLabel("Thank \(coachName)")
        .accessibilityValue(thanked ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    private func sendThanks() {
        guard !isSending, !thanked else { return }
        isSending = true
        failed = false
        // Optimista: el corazón se rellena antes de saber nada del servidor.
        isThanked = true
        HapticManager.shared.play(.light)

        if reduceMotion {
            heartScale = 1
        } else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.6)) { heartScale = 1.25 }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.6).delay(0.13)) { heartScale = 1 }
        }

        Task {
            let ok = await onThank()
            isSending = false
            if !ok {
                isThanked = false
                failed = true
            }
        }
    }
}
