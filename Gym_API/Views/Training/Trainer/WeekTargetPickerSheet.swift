//
//  WeekTargetPickerSheet.swift
//  Gym_API
//
//  «Copy week 3 to…» (S20) y «Duplicate this day to…» (S21).
//
//  Una sola hoja para las dos porque la pregunta es idéntica —¿a qué semanas?— y la única
//  diferencia real es el interruptor «Keep prescribed loads», que solo tiene sentido copiando
//  una semana entera.
//
//  La semana de origen no aparece en la lista: duplicar sobre uno mismo responde 422
//  (WP2-informe §4.3), y ofrecer una opción que va a fallar es peor que no ofrecerla.
//

import SwiftUI
import TrainingCore

struct WeekTargetPickerSheet: View {

    let title: String
    /// La semana o el día de origen, ya en palabras: «Week 3», «Thursday · Upper B».
    let sourceLabel: String
    let sourceWeek: Int
    let durationWeeks: Int
    /// `nil` esconde el interruptor de cargas: duplicar un día siempre las conserva.
    var keepLoadsTitle: String?
    /// Devuelve `true` si la copia salió bien; la hoja se cierra sola en ese caso.
    let onCopy: ([Int], Bool) async -> Bool

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<Int> = []
    @State private var keepLoads = true
    @State private var isCopying = false
    @State private var errorMessage: String?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var targets: [Int] {
        WeekMath.duplicableWeeks(from: sourceWeek, durationWeeks: durationWeeks)
    }

    private var canCopy: Bool {
        !isCopying && WeekMath.isValidDuplication(
            targets: Array(selected),
            from: sourceWeek,
            limit: durationWeeks
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Copying \(sourceLabel). Anything already in the target week is replaced.")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)

                    if targets.isEmpty {
                        Text("This program has only one week, so there is nowhere to copy it.")
                            .font(TrainingType.body())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                            .trainingCard(theme: theme)
                    } else {
                        weekList
                    }

                    if let keepLoadsTitle, !targets.isEmpty {
                        keepLoadsToggle(keepLoadsTitle)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Copy") { Task { await copy() } }
                        .fontWeight(.semibold)
                        .foregroundColor(
                            canCopy
                                ? Color.dynamicAccentText(theme: theme)
                                : Color.dynamicTextTertiary(theme: theme)
                        )
                        .disabled(!canCopy)
                }
            }
            .trainingAnnouncement(errorMessage)
        }
    }

    // MARK: - Semanas

    private var weekList: some View {
        VStack(spacing: 0) {
            ForEach(Array(targets.enumerated()), id: \.element) { index, week in
                Button {
                    HapticManager.shared.play(.selection)
                    if selected.contains(week) {
                        selected.remove(week)
                    } else {
                        selected.insert(week)
                    }
                    errorMessage = nil
                } label: {
                    HStack(spacing: 12) {
                        // El estado no depende del color: el glifo cambia de forma.
                        Image(systemName: selected.contains(week) ? "checkmark.circle.fill" : "circle")
                            .font(TrainingType.icon(18, weight: .regular))
                            .foregroundColor(
                                selected.contains(week)
                                    ? Color.dynamicAccentText(theme: theme)
                                    : Color.dynamicTextTertiary(theme: theme)
                            )

                        Text("Week \(week)")
                            .font(TrainingType.headline())
                            .foregroundColor(Color.dynamicText(theme: theme))

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Week \(week)")
                .accessibilityAddTraits(selected.contains(week) ? [.isSelected] : [])
                .accessibilityValue(selected.contains(week) ? "Selected" : "Not selected")

                if index < targets.count - 1 {
                    Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                }
            }
        }
        .trainingCard(theme: theme, padding: 14)
    }

    private func keepLoadsToggle(_ title: String) -> some View {
        Toggle(isOn: $keepLoads) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text("Off clears the weight so you can write next week's.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color.dynamicAccent(theme: theme))
        .frame(minHeight: 44)
        .trainingCard(theme: theme, padding: 14)
    }

    // MARK: - Copiar

    private func copy() async {
        guard canCopy else { return }
        isCopying = true
        errorMessage = nil
        defer { isCopying = false }

        let ok = await onCopy(selected.sorted(), keepLoads)
        if ok {
            dismiss()
        } else {
            errorMessage = "Couldn't copy. Nothing changed."
        }
    }
}
