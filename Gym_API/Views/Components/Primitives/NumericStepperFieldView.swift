//
//  NumericStepperFieldView.swift
//  Gym_API
//
//  Campo numérico con menos y más, tematizado.
//
//  El `Stepper` nativo solo se usa en dos formularios de administración, no se puede tematizar
//  y no cabe en una fila de series. Este sirve para el peso del check-in (modo grande) y, más
//  adelante, para las repeticiones y la carga del registro de sesión (modo compacto).
//
//  Sobre el mantener pulsado: el gesto tiene que tener un final de contacto explícito.
//  `LongPressGesture.onEnded` se dispara al ALCANZAR el umbral, no al levantar el dedo, así que
//  apoyarse solo en él dejaba el temporizador corriendo y el valor seguía subiendo después de
//  soltar. Aquí se usa `onPressingChanged`, que sí avisa de la soltada.
//

import SwiftUI

struct NumericStepperFieldView: View {
    @Binding var value: Double
    var step: Double = 0.1
    var range: ClosedRange<Double> = 0...500
    var unit: String? = nil
    var decimals: Int = 1
    var compact: Bool = false

    @EnvironmentObject var themeManager: ThemeManager
    @State private var repeatTimer: Timer?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var height: CGFloat { compact ? 36 : 56 }
    private var buttonWidth: CGFloat { compact ? 32 : 48 }
    private var valueSize: CGFloat { compact ? 15 : 36 }
    private var corner: CGFloat { compact ? 10 : 16 }

    /// Tope de seguridad por si el sistema no entrega el fin de contacto: 8 s a 0,08 s por paso.
    private let maxTicks = 100

    private var formatted: String {
        NumberFormat.decimal(value, digits: decimals)
    }

    private var canDecrease: Bool { value - step >= range.lowerBound - 0.0001 }
    private var canIncrease: Bool { value + step <= range.upperBound + 0.0001 }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", enabled: canDecrease, delta: -step)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatted)
                    .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                    .tracking(compact ? 0 : -1.5)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundColor(Color.dynamicText(theme: theme))
                if let unit {
                    Text(unit)
                        .font(.system(size: compact ? 10 : 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.15), value: value)

            stepButton(systemName: "plus", enabled: canIncrease, delta: step)
        }
        .frame(height: height)
        .background(Color.dynamicSurface2(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .onDisappear { stopRepeating() }
    }

    private func stepButton(systemName: String, enabled: Bool, delta: Double) -> some View {
        Image(systemName: systemName)
            .font(.system(size: compact ? 12 : 16, weight: .bold))
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            .frame(width: buttonWidth, height: height)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.3)
            .onTapGesture {
                guard enabled else { return }
                adjust(by: delta)
            }
            .onLongPressGesture(
                minimumDuration: 0.4,
                perform: {
                    guard enabled else { return }
                    startRepeating(delta: delta)
                },
                onPressingChanged: { pressing in
                    // Se dispara con false al levantar el dedo, que es lo que faltaba.
                    if !pressing { stopRepeating() }
                }
            )
            .accessibilityLabel(systemName == "plus" ? "Increase" : "Decrease")
    }

    private func adjust(by delta: Double) {
        let next = ((value + delta) * 100).rounded() / 100
        guard next.isFinite, next >= range.lowerBound, next <= range.upperBound else {
            stopRepeating()
            return
        }
        value = next
        HapticManager.shared.play(.selection)
    }

    private func startRepeating(delta: Double) {
        stopRepeating()
        var ticks = 0
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            ticks += 1
            if ticks > maxTicks {
                timer.invalidate()
                return
            }
            Task { @MainActor in adjust(by: delta) }
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
