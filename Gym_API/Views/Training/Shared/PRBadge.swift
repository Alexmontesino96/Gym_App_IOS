//
//  PRBadge.swift
//  Gym_API
//
//  El rombo de una marca (UX §5, S15 y S16).
//
//  El rombo NUNCA va solo: siempre lleva al lado la palabra o, cuando no cabe, la etiqueta de
//  VoiceOver que lo dice. Un glifo de color no es información para quien no distingue el color
//  (checklist §10.5) ni para quien escucha la pantalla.
//
//  Y hay dos palabras distintas a propósito: «Personal record» solo cuando el servidor lo ha
//  confirmado; mientras la sesión sigue en la cola, «Best set so far» (plan §4.5).
//

import SwiftUI

struct PRBadge: View {

    /// `false` mientras el registro no haya sincronizado.
    var isConfirmed: Bool = true
    /// Enseña el texto además del rombo. En listas apretadas se apaga y queda en la etiqueta.
    var showsText: Bool = true

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    static let confirmedText = "Personal record"
    static let unconfirmedText = "Best set so far"

    private var text: String { isConfirmed ? Self.confirmedText : Self.unconfirmedText }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isConfirmed ? "diamond.fill" : "diamond")
                .font(.system(size: 10))
                .foregroundColor(
                    isConfirmed
                        ? Color.dynamicAccent(theme: theme)
                        : Color.dynamicTextTertiary(theme: theme)
                )

            if showsText {
                Text(text)
                    .font(TrainingType.label())
                    .tracking(0.8)
                    .foregroundColor(
                        isConfirmed
                            ? Color.dynamicText(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
