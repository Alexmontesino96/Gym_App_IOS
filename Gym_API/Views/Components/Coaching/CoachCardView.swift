//
//  CoachCardView.swift
//  Gym_API
//
//  Widget 5 del diseño, en su versión de fase 2: quién es tu entrenador y cómo escribirle.
//
//  La "nota del día" del diseño ya está: es el último mensaje que el entrenador ha escrito en
//  la conversación 1:1, leído del canal de Stream porque el esquema del backend no lo
//  devuelve. Si no hay nota, o el chat todavía no está conectado, la tarjeta se queda en
//  identidad más llamada a la acción, que es lo que había antes.
//

import SwiftUI

struct CoachCardView: View {
    let coach: CoachSummary?
    let state: LoadState
    let onMessageCoach: () -> Void
    let onRetry: () -> Void

    /// Último mensaje del entrenador. Cuando existe, la tarjeta pasa de ficha de contacto a
    /// nota, que es lo que el diseño pide.
    var note: CoachNote? = nil

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(note == nil ? "YOUR TRAINER" : "NOTE FROM YOUR TRAINER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Spacer(minLength: 8)

                if let note {
                    Text(note.relativeAge)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            }

            if let coach {
                coachRow(coach)
            } else {
                switch state {
                case .loading, .idle:
                    loadingRow
                case .failed:
                    // Afirmar que no hay entrenador cuando la consulta se cayó es falso: en un
                    // espacio de entrenador personal siempre hay uno.
                    errorRow
                case .loaded:
                    emptyRow
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Estados

    private func coachRow(_ coach: CoachSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                avatar(for: coach)

                VStack(alignment: .leading, spacing: 3) {
                    Text(coach.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)

                    if let bio = coach.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .lineLimit(2)
                    } else {
                        Text("Personal trainer")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                }

                Spacer(minLength: 0)
            }

            if let note {
                Text(note.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onMessageCoach) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 13, weight: .semibold))
                    Text(note == nil ? "Message \(coach.firstName)" : "Reply")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.accentInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
            }
            .buttonStyle(.plain)
        }
    }

    private func avatar(for coach: CoachSummary) -> some View {
        Group {
            if let picture = coach.pictureURL, !picture.isEmpty {
                OptimizedAsyncImage(
                    url: picture,
                    displaySize: CGSize(width: 48, height: 48),
                    placeholder: { AnyView(initialsCircle(coach.initials)) },
                    errorView: { AnyView(initialsCircle(coach.initials)) }
                )
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                initialsCircle(coach.initials)
            }
        }
    }

    private func initialsCircle(_ initials: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.dynamicAccent(theme: theme))
            Text(initials)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.accentInk)
        }
        .frame(width: 48, height: 48)
    }

    private var loadingRow: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 48, height: 48, cornerRadius: 24)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 140, height: 14, cornerRadius: 4)
                SkeletonView(width: 90, height: 11, cornerRadius: 4)
            }
            Spacer(minLength: 0)
        }
    }

    private var errorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Could not load your trainer")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Try again")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.dynamicAccent(theme: theme))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyRow: some View {
        Text("No trainer is assigned to this space yet.")
            .font(.system(size: 14))
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            .fixedSize(horizontal: false, vertical: true)
    }
}
