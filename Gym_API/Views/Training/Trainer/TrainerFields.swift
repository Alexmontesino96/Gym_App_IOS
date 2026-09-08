//
//  TrainerFields.swift
//  Gym_API
//
//  Los controles que el editor de día repite quince veces (UX §6, S21) y el nombre del día de
//  la semana que usan S20 y S21.
//
//  Existen aquí, y no como `NumericStepperFieldView`, por lo mismo que decidió WP4 para la fila
//  de serie: en modo compacto los botones de ese componente miden 32 × 36 pt y el checklist §10.6
//  pide 44 × 44 reales. Estos los cumplen sin agrandar el dibujo.
//

import SwiftUI
import TrainingCore

// MARK: - Días de la semana

enum TrainingWeekday {

    /// «Monday»… «Sunday» a partir de la posición 1-7 dentro de la semana del programa.
    ///
    /// Los nombres salen del calendario del dispositivo (`standaloneWeekdaySymbols`, que empieza
    /// en domingo) reordenados para empezar en lunes, que es como se numeran los días del
    /// programa (plan §4.2).
    static func name(index: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard symbols.count == 7 else { return "Day \(index)" }
        let mondayFirst = Array(symbols[1...]) + [symbols[0]]
        let position = min(max(1, index), 7) - 1
        return mondayFirst[position].capitalized
    }

    /// «MON»… «SUN», para las filas apretadas de S20.
    static func shortName(index: Int) -> String {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return "D\(index)" }
        let mondayFirst = Array(symbols[1...]) + [symbols[0]]
        let position = min(max(1, index), 7) - 1
        return mondayFirst[position].uppercased()
    }

    /// El día de la semana de un `day_number` del programa.
    static func name(forDayNumber dayNumber: Int) -> String {
        name(index: WeekMath.weekdayIndex(forDayNumber: dayNumber))
    }

    static func shortName(forDayNumber dayNumber: Int) -> String {
        shortName(index: WeekMath.weekdayIndex(forDayNumber: dayNumber))
    }
}

// MARK: - Mensajes de estado

extension View {

    /// Anuncia por VoiceOver un mensaje que aparece **sin mover el foco**.
    ///
    /// Es el caso de todos los errores y confirmaciones del panel: se pulsa «Save», falla la
    /// petición y el texto sale en otro sitio de la pantalla. Quien ve la pantalla lo lee; quien
    /// la escucha se queda con el foco en un botón que vuelve a estar habilitado y sin nada que
    /// le diga que ha pasado algo (WCAG 4.1.3).
    func trainingAnnouncement(_ message: String?) -> some View {
        onChange(of: message) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            UIAccessibility.post(notification: .announcement, argument: newValue)
        }
    }
}

/// Aplica `accessibilityAdjustableAction` solo cuando de verdad hay algo que ajustar.
///
/// Adjuntarlo siempre y neutralizarlo con un `guard` dentro deja el elemento anunciado como
/// «ajustable»: VoiceOver invita a deslizar, el gesto se gasta y no pasa nada.
struct TrainerAdjustable: ViewModifier {

    let isActive: Bool
    let action: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if isActive {
            content.accessibilityAdjustableAction(action)
        } else {
            content
        }
    }
}

// MARK: - Stepper con etiqueta

/// `Sets ‹ 4 ›`. Etiqueta encima, valor monoespaciado y dos objetivos de 44 pt.
struct TrainerStepperField: View {

    let label: String
    /// El valor ya formateado. Se pasa hecho porque cada campo tiene su formato (mm:ss, RPE, %).
    let value: String
    var isEnabled: Bool = true
    /// Lo que dice VoiceOver al ajustar. Sin él, «4» no significa nada.
    var spokenValue: String?
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 0) {
                chevron("chevron.left", action: onDecrement)

                Text(value)
                    .font(TrainingType.monoM())
                    .monospacedDigit()
                    .foregroundColor(
                        isEnabled
                            ? Color.dynamicText(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                chevron("chevron.right", action: onIncrement)
            }
            .background(Color.dynamicSurface2(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue ?? value)
        // El contenedor es el elemento que lee VoiceOver: sin esto seguía anunciándose como
        // ajustable aunque el modo de carga no llevara número.
        .disabled(!isEnabled)
        .modifier(TrainerAdjustable(isActive: isEnabled) { direction in
            switch direction {
            case .increment: onIncrement()
            case .decrement: onDecrement()
            @unknown default: break
            }
        })
    }

    private func chevron(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            action()
        }) {
            Image(systemName: systemName)
                .font(TrainingType.icon(12))
                .foregroundColor(
                    isEnabled
                        ? Color.dynamicTextSecondary(theme: theme)
                        : Color.dynamicTextTertiary(theme: theme).opacity(0.5)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // El stepper entero es un solo elemento para VoiceOver, que lo ajusta por deslizamiento.
        .accessibilityHidden(true)
    }
}

// MARK: - Campo de texto con etiqueta

/// `Reps ‹ 8-10 ›`: texto libre del contrato ("5", "8-10", "AMRAP") con steppers que solo
/// funcionan cuando el valor es un número.
struct TrainerTextField: View {

    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var spokenValue: String?
    /// Centrado y en mayúsculas para las cifras («5», «AMRAP»); alineado a la izquierda y en
    /// frases para lo que se escribe leyendo («Upper B», «Strict press.»).
    var isPrescriptionValue: Bool = true
    /// Steppers opcionales: nulos, el campo es solo texto.
    var onDecrement: (() -> Void)?
    var onIncrement: (() -> Void)?
    var steppersEnabled: Bool = true

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // La etiqueta viaja en el propio campo; leerla dos veces no ayuda a nadie.
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                if let onDecrement {
                    chevron("chevron.left", action: onDecrement)
                }

                TextField(placeholder, text: $text)
                    .font(isPrescriptionValue ? TrainingType.monoM() : TrainingType.body())
                    .monospacedDigit()
                    .multilineTextAlignment(isPrescriptionValue ? .center : .leading)
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .autocorrectionDisabled(isPrescriptionValue)
                    .textInputAutocapitalization(isPrescriptionValue ? .characters : .sentences)
                    .padding(.horizontal, isPrescriptionValue ? 0 : 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    // El campo NO se agrupa con `children: .combine`: agrupar un control
                    // editable puede convertirlo en una etiqueta de solo lectura para VoiceOver,
                    // y estos son los únicos sitios del módulo donde se escribe texto libre.
                    .accessibilityLabel(label)
                    .accessibilityValue(spokenValue ?? (text.isEmpty ? "Empty" : text))
                    .modifier(TrainerAdjustable(isActive: isAdjustable) { direction in
                        switch direction {
                        case .increment: onIncrement?()
                        case .decrement: onDecrement?()
                        @unknown default: break
                        }
                    })

                if let onIncrement {
                    chevron("chevron.right", action: onIncrement)
                }
            }
            .background(Color.dynamicSurface2(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Solo es ajustable si hay steppers **y** están activos: «Day name» y «Note» no los tienen,
    /// y «Reps» los apaga con «AMRAP».
    private var isAdjustable: Bool {
        steppersEnabled && (onDecrement != nil || onIncrement != nil)
    }

    private func chevron(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            action()
        }) {
            Image(systemName: systemName)
                .font(TrainingType.icon(12))
                .foregroundColor(
                    steppersEnabled
                        ? Color.dynamicTextSecondary(theme: theme)
                        : Color.dynamicTextTertiary(theme: theme).opacity(0.5)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!steppersEnabled)
        .accessibilityHidden(true)
    }
}

// MARK: - Menú con etiqueta

/// `Load ‹ RPE ▾ ›`: un menú que se lee como los steppers de al lado.
struct TrainerMenuField<Content: View>: View {

    let label: String
    let value: String
    @ViewBuilder let content: () -> Content

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Image(systemName: "chevron.down")
                        .font(TrainingType.icon(9))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.dynamicSurface2(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel(label)
            .accessibilityValue(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Umbral de apilado

extension DynamicTypeSize {

    /// A partir de aquí una fila de dos columnas deja de caber y hay que apilarla.
    ///
    /// **No** es `isAccessibilitySize`: ese empieza en `accessibility1`, y el checklist §10.8 se
    /// verifica en `xxxLarge`, que es el último tamaño NO de accesibilidad. Con el umbral en
    /// accesibilidad, «9,566 lb» ya se cortaba en la captura de `xxxLarge`.
    var stacksTrainerRows: Bool { self >= .xxxLarge }
}

// MARK: - Fila de campos que se apila en tamaños de accesibilidad

/// Dos o tres campos en horizontal; en `accessibility1` y más grandes, uno debajo de otro.
///
/// Sin esto, tres steppers en una fila de 350 pt a tamaño xxxLarge dejan cada cifra en 40 pt y
/// «AMRAP» deja de caber (checklist §10.8).
struct TrainerFieldRow<Content: View>: View {

    @ViewBuilder let content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.stacksTrainerRows {
            VStack(alignment: .leading, spacing: 10, content: content)
        } else {
            HStack(alignment: .top, spacing: 10, content: content)
        }
    }
}
