//
//  WeeklyCheckInStatusCardView.swift
//  Gym_API
//
//  Widget 7 del diseño: peso actual, variación respecto a la semana pasada y estado del check-in.
//
//  Datos reales de GET /health/measurements/weight-history. Si el cliente no se ha pesado
//  nunca, la tarjeta lo dice en vez de enseñar un cero.
//
//  Ojo con el color de la variación: bajar de peso no siempre es bueno. El signo se pinta en
//  gris salvo que se sepa hacia dónde va el objetivo del cliente.
//
//  Los valores llegan en kilos, que es lo que guarda el servidor, y se convierten al abrir a la
//  unidad del país de quien mira. En Estados Unidos, libras.
//

import SwiftUI

struct WeeklyCheckInStatusCardView: View {
    let history: WeightHistory
    let currentWeight: Double?
    let weeklyChange: Double?
    let hasCheckedInThisWeek: Bool
    let state: LoadState
    let onCheckIn: () -> Void
    let onRetry: () -> Void

    /// Media columna, junto a la tarjeta de fuerza, como en el diseño. En compacto la tarjeta
    /// entera es el botón y se cae la serie: a media anchura una gráfica de doce puntos no
    /// dice nada que la cifra y la variación no digan mejor.
    var compact: Bool = false

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    /// `currentWeight` y `weeklyChange` vienen en kilos; esto es lo único que decide qué se ve.
    private let unit = WeightUnit.preferred

    private var weightText: String {
        guard let weight = currentWeight else { return NumberFormat.placeholder }
        return NumberFormat.decimal(unit.fromKilograms(weight))
    }

    private var changeText: String? {
        // El umbral se mide sobre el valor guardado para que no dependa de la unidad mostrada.
        guard let change = weeklyChange, abs(change) >= 0.05 else { return nil }
        return "\(NumberFormat.signedDecimal(unit.fromKilograms(change))) \(unit.symbol)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch state {
            case .loading, .idle where currentWeight == nil:
                SkeletonView(width: 120, height: 36, cornerRadius: 8)
            case .failed where currentWeight == nil:
                // Un fallo de red NO se pinta como «nunca te has pesado»: son cosas distintas.
                errorBody
            default:
                if currentWeight == nil { emptyBody } else { filledBody }
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
        .modifier(TapToCheckIn(enabled: compact, action: onCheckIn))
    }

    // MARK: - Partes

    private var header: some View {
        HStack {
            Text("WEEKLY CHECK-IN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            Spacer()
            Image(systemName: "figure.stand")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: theme))
        }
    }

    private var filledBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weightText)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .tracking(-1.5)
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text(unit.symbol)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                if let changeText {
                    Text(changeText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.35), lineWidth: 1)
                        )
                        .padding(.leading, 2)
                }
            }

            if !compact, history.values.count >= 2 {
                SparklineView(values: Array(history.values.suffix(12)), showsLastPoint: true)
                    .frame(height: 40)
            }

            statusRow
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(hasCheckedInThisWeek ? Color.successGreen : Color.warningYellow)
                .frame(width: 6, height: 6)

            Text(hasCheckedInThisWeek ? "Logged this week" : "Due this week")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(hasCheckedInThisWeek
                                 ? Color.dynamicTextTertiary(theme: theme)
                                 : Color.warningYellow)

            Spacer(minLength: 8)

            if !hasCheckedInThisWeek, !compact {
                Button(action: onCheckIn) {
                    Text("Weigh in")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.accentInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var errorBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Could not load your data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))

            Text("Check your connection and try again.")
                .font(.system(size: 13))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))

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

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You have not logged your weight yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))

            Text("The first entry sets your baseline. From there you see the change week over week.")
                .font(.system(size: 13))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onCheckIn) {
                Text("Log my weight")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.accentInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Toque en toda la tarjeta

/// En compacto la tarjeta entera lleva al check-in, como en el diseño, y se anuncia como
/// botón. En ancho completo NO se toca nada: ahí el destino es el botón «Weigh in», y poner
/// una etiqueta de accesibilidad vacía sobre la tarjeta le robaría a VoiceOver el contenido
/// que sí sabe leer.
private struct TapToCheckIn: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .contentShape(RoundedRectangle(cornerRadius: 22))
                .onTapGesture(perform: action)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("Opens the weekly check-in"))
        } else {
            content
        }
    }
}
