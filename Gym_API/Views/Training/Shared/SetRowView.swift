//
//  SetRowView.swift
//  Gym_API
//
//  La fila de una serie en S11 (UX §5).
//
//  Es el elemento que se toca veinte veces por sesión, así que manda sobre todo lo demás:
//
//  - **Un toque para marcar.** El círculo es el único elemento con relleno de acento de la
//    pantalla, y solo lo lleva la serie que toca ahora. Las ya marcadas pasan a superficie con el
//    check en acento, que las deja legibles sin competir por la mirada.
//  - **Editar es de la fila activa.** Los steppers aparecen bajo la serie en curso, con 44 pt
//    reales por botón. `NumericStepperFieldView` no vale aquí: en modo compacto sus botones miden
//    32 × 36 y el checklist §10.6 pide 44 × 44.
//  - **A partir de `accessibility1` la fila se apila** en dos líneas, como pide UX §3.
//

import SwiftUI
import TrainingCore

struct SetRowView: View {

    let exercise: SessionExercise
    let set: SessionSet
    let state: SetRowState
    let unit: WeightUnit

    let onToggle: () -> Void
    let onChangeWeight: (Double?) -> Void
    let onChangeReps: (Int) -> Void
    let onEditRPE: () -> Void
    let onRemove: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.trainingReduceMotion) private var reduceMotion

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    private var weightText: String {
        guard let weight = set.weightKg else { return "—" }
        return unit.loadLabel(kilograms: weight)
    }

    private var rpeText: String {
        guard let rpe = set.rpe else { return "–" }
        return Celebration.number(rpe)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isStacked {
                stackedRow
            } else {
                inlineRow
            }

            if state == .active {
                editingBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: TrainingType.rowHeight())
        .background(state == .active ? Color.dynamicSurface2(theme: theme).opacity(0.5) : Color.clear)
        .opacity(state == .done ? 0.6 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exercise.rowLabel(forSetNumber: set.setNumber))
        .accessibilityValue("\(exercise.rowValue(for: set, unit: unit.trainingUnit)). \(state.spokenState)")
        .accessibilityAction(named: Text(set.isDone ? "Undo" : "Mark done"), onToggle)
        .accessibilityAction(named: Text("Set RPE"), onEditRPE)
        .accessibilityAction(named: Text("Remove set"), onRemove)
        .accessibilityAdjustableAction { direction in
            // Con VoiceOver, deslizar arriba y abajo cambia el peso al escalón de la unidad.
            let step = unit.loadStep
            let current = set.weightKg.map { unit.fromKilograms($0) } ?? 0
            let updated = direction == .increment ? current + step : max(0, current - step)
            onChangeWeight(unit.kilograms(fromLoad: updated))
        }
    }

    // MARK: - Una línea

    private var inlineRow: some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(TrainingType.monoM())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .frame(width: 22, alignment: .leading)

            Text(weightText)
                .font(TrainingType.monoM())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(set.reps)")
                .font(TrainingType.monoM())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(width: 44, alignment: .trailing)

            Text(rpeText)
                .font(TrainingType.monoM())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .frame(width: 34, alignment: .trailing)

            checkButton
        }
    }

    // MARK: - Dos líneas (Dynamic Type grande)

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(set.setNumber)")
                    .font(TrainingType.monoM())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Text("\(weightText) × \(set.reps)")
                    .font(TrainingType.monoM())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Text("RPE \(rpeText)")
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                Spacer(minLength: 0)

                checkButton
            }
        }
    }

    // MARK: - Check

    private var checkButton: some View {
        Button(action: {
            onToggle()
        }) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .overlay(
                        Circle().stroke(strokeColor, lineWidth: state == .active ? 0 : 1)
                    )
                    .frame(width: 30, height: 30)

                if set.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                } else if state == .active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                        .opacity(0.55)
                }
            }
            .trainingTouchTarget()
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .easeInOut(duration: 0.1) : .spring(response: 0.22, dampingFraction: 0.7), value: set.isDone)
        .accessibilityHidden(true)
    }

    private var fillColor: Color {
        if set.isDone { return Color.dynamicSurface2(theme: theme) }
        if state == .active { return Color.dynamicAccent(theme: theme) }
        return Color.clear
    }

    private var strokeColor: Color {
        // `self.` no es decorativo: una propiedad calculada que empieza por `set` la lee el
        // compilador como el setter de la propiedad.
        self.set.isDone
            ? Color.dynamicBorder(theme: theme).opacity(0.2)
            : Color.dynamicBorder(theme: theme).opacity(0.5)
    }

    // MARK: - Edición de la serie activa

    private var editingBar: some View {
        HStack(spacing: 10) {
            stepper(
                label: "Weight",
                value: weightText,
                onDecrease: { changeWeight(by: -unit.loadStep) },
                onIncrease: { changeWeight(by: unit.loadStep) }
            )

            stepper(
                label: "Reps",
                value: "\(set.reps)",
                onDecrease: { onChangeReps(max(0, set.reps - 1)) },
                onIncrease: { onChangeReps(set.reps + 1) }
            )

            Button(action: onEditRPE) {
                VStack(spacing: 1) {
                    Text("RPE")
                        .font(TrainingType.label())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    Text(rpeText)
                        .font(TrainingType.monoS())
                        .monospacedDigit()
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                .frame(minWidth: 44, minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.dynamicBorder(theme: theme).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set RPE")

            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func changeWeight(by delta: Double) {
        let current = set.weightKg.map { unit.fromKilograms($0) } ?? 0
        let updated = max(0, current + delta)
        onChangeWeight(updated == 0 ? nil : unit.kilograms(fromLoad: updated))
    }

    private func stepper(
        label: String,
        value: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: {
                HapticManager.shared.play(.selection)
                onDecrease()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease \(label.lowercased())")

            Text(value)
                .font(TrainingType.monoS())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(minWidth: 52)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button(action: {
                HapticManager.shared.play(.selection)
                onIncrease()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase \(label.lowercased())")
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Cabecera de la tabla

struct SetTableHeader: View {

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 8) {
                Text("SET")
                    .frame(width: 22, alignment: .leading)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("REPS")
                    .frame(width: 44, alignment: .trailing)
                Text("RPE")
                    .frame(width: 34, alignment: .trailing)
                Color.clear.frame(width: 44, height: 1)
            }
            .font(TrainingType.label())
            .tracking(0.8)
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .padding(.horizontal, 16)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - RPE

/// La escala 1-10 en cinco columnas (UX §5). `ScaleSelectorView` está fijada a 1-5 y la usa el
/// check-in semanal; parametrizarla desde aquí tocaría una pantalla que no es de este paquete.
struct RPEPickerSheet: View {

    let current: Double?
    let onSelect: (Double?) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("How hard was that set?")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...10, id: \.self) { value in
                        Button(action: {
                            HapticManager.shared.play(.selection)
                            onSelect(Double(value))
                            dismiss()
                        }) {
                            Text("\(value)")
                                .font(TrainingType.monoM())
                                .monospacedDigit()
                                .foregroundColor(
                                    Int(current ?? 0) == value
                                        ? Color.dynamicText(theme: theme)
                                        : Color.dynamicTextSecondary(theme: theme)
                                )
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12).fill(
                                        Int(current ?? 0) == value
                                            ? Color.dynamicSurface2(theme: theme)
                                            : Color.clear
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(
                                        Color.dynamicBorder(theme: theme).opacity(Int(current ?? 0) == value ? 0.5 : 0.2),
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("RPE \(value)")
                        .accessibilityAddTraits(Int(current ?? 0) == value ? [.isButton, .isSelected] : .isButton)
                    }
                }

                Button(action: {
                    onSelect(nil)
                    dismiss()
                }) {
                    Text("Clear")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("RPE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
