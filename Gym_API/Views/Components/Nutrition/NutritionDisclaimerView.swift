//
//  NutritionDisclaimerView.swift
//  Gym_API
//
//  Aviso médico para las pantallas de nutrición.
//
//  La app reparte planes con calorías y macronutrientes, y hasta ahora no había ni una línea que
//  dijera lo que eso no es. La guía 1.4.1 de la App Store, sobre daño físico, lo pide para
//  cualquier app de dieta, y con el lanzamiento en Estados Unidos es de las primeras cosas que
//  mira un revisor en esta categoría.
//
//  Se pinta como aviso discreto y persistente, no como una alerta que se cierra: el objetivo es
//  que esté presente mientras se lee el plan, no que alguien la despache de un toque.
//

import SwiftUI

struct NutritionDisclaimerView: View {
    @EnvironmentObject var themeManager: ThemeManager

    /// Versión de una línea, para cabeceras de lista donde no cabe el párrafo.
    var compact: Bool = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var message: String {
        compact
            ? "Nutrition plans are general guidance, not medical advice."
            : "Nutrition plans in this app are general guidance and not medical advice. Talk to your doctor before starting one, especially if you are pregnant, nursing, or have a health condition."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
