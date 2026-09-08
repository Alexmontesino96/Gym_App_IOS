//
//  KudosSheet.swift
//  Gym_API
//
//  Hoja de kudos de un miembro del grupo (UX §4, «Your group today»).
//
//  Un kudos por persona y día: cuando ya está dado, el botón desaparece y queda la confirmación.
//  El servidor responde 409 si se repite, y esta hoja no permite llegar ahí dos veces.
//

import SwiftUI
import TrainingCore

struct KudosSheet: View {

    let member: GroupTodayMember
    /// `POST /logs/{id}/kudos`. Devuelve `false` si el servidor lo rechazó.
    let onSend: (Int) async -> Bool

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var isSending = false
    @State private var isSent = false
    @State private var errorMessage: String?
    @State private var showsParticles = false
    @State private var ringOpacity: Double = 0

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var initials: String {
        let parts = member.name.components(separatedBy: " ").prefix(2).compactMap { $0.first }
        let text = parts.map { String($0).uppercased() }.joined()
        return text.isEmpty ? "?" : text
    }

    private var alreadySent: Bool { member.kudosGiven || isSent }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                avatar
                    .padding(.top, 24)

                VStack(spacing: 4) {
                    Text(member.name)
                        .font(TrainingType.title2())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(TrainingType.subhead())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)

                if let errorMessage {
                    Text(errorMessage)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if alreadySent {
                    Text("Kudos sent")
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .frame(minHeight: 50)
                } else {
                    sendButton
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    private var subtitle: String {
        guard let dayName = member.dayName, !dayName.isEmpty else { return "Trained today" }
        return "Trained today · \(dayName)"
    }

    // MARK: - Avatar y celebración

    private var avatar: some View {
        ZStack {
            if let url = member.pictureURL, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsCircle
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.dynamicAccentText(theme: theme), lineWidth: 2)
                .opacity(alreadySent ? 1 : ringOpacity)
        )
        .overlay {
            if showsParticles {
                ConfettiView(
                    particleCount: 12,
                    colors: [Color.dynamicAccent(theme: theme)],
                    duration: 0.5,
                    spreadRadius: 90
                )
                .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(initials)
                .font(TrainingType.title2())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
    }

    // MARK: - Enviar

    private var sendButton: some View {
        Button(action: send) {
            HStack(spacing: 8) {
                if isSending { ProgressView().tint(Color.dynamicText(theme: theme)) }
                Text("Send kudos")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay(
                Capsule().stroke(Color.dynamicAccentText(theme: theme), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSending || member.logId == nil)
        .accessibilityLabel("Send kudos to \(member.name)")
    }

    private func send() {
        guard let logId = member.logId, !isSending else { return }
        isSending = true
        errorMessage = nil

        Task {
            let ok = await onSend(logId)
            isSending = false
            if ok {
                isSent = true
                HapticManager.shared.play(.success)
                if reduceMotion {
                    // Sin partículas: el anillo aparece con un fundido y el texto lo dice.
                    withAnimation(.easeOut(duration: 0.15)) { ringOpacity = 1 }
                } else {
                    showsParticles = true
                    withAnimation(.easeOut(duration: 0.2)) { ringOpacity = 1 }
                }
            } else {
                errorMessage = "Couldn't send. Tap to retry."
            }
        }
    }
}
