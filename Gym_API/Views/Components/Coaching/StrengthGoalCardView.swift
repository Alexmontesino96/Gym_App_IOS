//
//  StrengthGoalCardView.swift
//  Gym_API
//
//  Widget 6 del diseño, en su versión de fase 2: progreso hacia el objetivo de fuerza.
//
//  El diseño pide un 1RM estimado con serie de ocho puntos. Eso necesita el registro de series,
//  que llega con el módulo de entrenamiento. Mientras tanto se pinta lo que sí existe: un
//  objetivo de tipo `strength` de GET /health/goals, con su valor actual, su meta y la mejora
//  sobre el punto de partida.
//
//  La tarjeta no aparece si no hay objetivo: un widget que fabrica una cifra es peor que uno
//  que no está.
//

import SwiftUI

struct StrengthGoalCardView: View {
    let goal: HealthGoal

    /// Media columna, como en el diseño, que coloca fuerza y check-in uno al lado del otro.
    /// En compacto se cae el pie de partida y meta: no cabe sin apretujar la cifra, que es
    /// lo que la tarjeta viene a decir.
    var compact: Bool = false

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var improvement: Double? { goal.improvementPercentage }

    /// Formatea sin pasar nunca por `Int`: el backend no acota `target_value` ni `current_value`,
    /// y `Int(Double)` con un valor enorme, infinito o NaN cierra la app.
    ///
    /// La unidad NO se convierte: `goal.unit` es texto libre que eligió el entrenador al crear
    /// el objetivo ("kg", "lbs", "reps"), así que traducirlo a otra escala falsearía su cifra.
    private func format(_ value: Double) -> String {
        NumberFormat.trimmedDecimal(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            Text(compact ? goal.title.uppercased() : "STRENGTH · \(goal.title.uppercased())")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(goal.currentValue))
                    .font(.system(size: compact ? 26 : 30, weight: .bold, design: .monospaced))
                    .tracking(-1.0)
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(goal.unit)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                Spacer(minLength: 8)

                if !compact, let improvement, improvement.isFinite, abs(improvement) >= 0.5 {
                    trendChip(improvement)
                }
            }

            if compact, let improvement, improvement.isFinite, abs(improvement) >= 0.5 {
                trendChip(improvement)
            }

            progressBar

            if !compact {
                HStack {
                    if let start = goal.startValue {
                        Text("Start \(format(start)) \(goal.unit)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                    Spacer()
                    Text("Goal \(format(goal.targetValue)) \(goal.unit)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            } else {
                Text("Goal \(format(goal.targetValue)) \(goal.unit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .padding(16)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    private func trendChip(_ improvement: Double) -> some View {
        let positive = improvement > 0
        let color = positive ? Color.successGreen : Color.errorRed
        return HStack(spacing: 4) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
            Text("\(positive ? "+" : "−")\(String(format: "%.0f", min(abs(improvement), 9999)))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let fraction = max(0, min(1, goal.progressPercentage / 100))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.dynamicSurface2(theme: theme))
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.dynamicAccent(theme: theme))
                    .frame(width: geo.size.width * fraction)
                    .animation(.easeOut(duration: 0.4), value: fraction)
            }
        }
        .frame(height: 4)
    }
}
