//
//  ScaleSelectorView.swift
//  Gym_API
//
//  Escala de 1 a 5, la del check-in semanal del diseño.
//
//  Cinco botones y no un deslizador: en una escala tan corta, el deslizador obliga a apuntar y
//  además no deja claro cuántos escalones hay. Con cinco botones el rango se ve de un vistazo y
//  se elige de un toque.
//
//  El valor es opcional a propósito. Nadie está obligado a puntuar cómo ha dormido, y una escala
//  que arranca en 3 por defecto mete un dato que su entrenador leería como si lo hubiera dicho
//  la persona.
//

import SwiftUI

struct ScaleSelectorView: View {
    let title: String
    /// Extremos de la escala, para que 1 y 5 signifiquen algo.
    let lowLabel: String
    let highLabel: String
    @Binding var value: Int?

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Spacer()

                Text(value.map { "\($0)/5" } ?? "—")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        value == nil
                            ? Color.dynamicTextTertiary(theme: theme)
                            : Color.dynamicText(theme: theme)
                    )
            }

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { step in
                    stepButton(step)
                }
            }

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.system(size: 10))
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    private func stepButton(_ step: Int) -> some View {
        let isFilled = (value ?? 0) >= step

        return Button {
            HapticManager.shared.play(.selection)
            // Volver a tocar el valor elegido lo borra. Es la única forma de deshacer una
            // puntuación sin cerrar la hoja, y sin ella un toque accidental queda para siempre.
            value = (value == step) ? nil : step
        } label: {
            Text("\(step)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(isFilled ? Color.accentInk : Color.dynamicTextTertiary(theme: theme))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isFilled
                              ? Color.dynamicAccent(theme: theme)
                              : Color.dynamicSurface2(theme: theme))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(step) of 5")
        .accessibilityAddTraits(value == step ? [.isSelected] : [])
    }
}
