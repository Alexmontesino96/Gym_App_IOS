//
//  StrengthProgressCardView.swift
//  Gym_API
//
//  W6 · Strength progress (UX §4).
//
//  Es la tarjeta que `StrengthGoalCardView` prometía en su cabecera: «el diseño pide un 1RM
//  estimado con serie de ocho puntos». Ahora esa serie existe, así que esta tarjeta la sustituye
//  cuando `strength-summary` trae datos y la de objetivo se queda para cuando no.
//
//  El delta nunca se pinta en rojo: bajar de 1RM una semana no es un error, es entrenar. Sube en
//  `success`, plano en terciario, baja en `warn` (UX §4).
//

import SwiftUI
import TrainingCore

struct StrengthProgressCardView: View {

    let item: StrengthSummaryItem
    var state: LoadState = .loaded
    /// Abre S15 con el historial del ejercicio.
    let onOpenHistory: () -> Void
    /// Abre S16 desde la línea «Last PR».
    let onOpenRecords: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    private var hasTrend: Bool { item.hasEnoughDataForChart }

    private var deltaColor: Color {
        guard let delta = item.deltaKg else { return Color.dynamicTextTertiary(theme: theme) }
        if delta > 0.1 { return Color.successGreen }
        if delta < -0.1 { return Color.warningYellow }
        return Color.dynamicTextTertiary(theme: theme)
    }

    /// «Up 10 lb · 6 weeks». Sin flecha suelta: la palabra ya dice la dirección.
    private var deltaText: String? {
        guard let delta = item.deltaKg,
              let text = Celebration.deltaText(kilograms: delta, unit: unit.trainingUnit)
        else { return nil }
        let capitalized = text.prefix(1).uppercased() + text.dropFirst()
        guard let weeks = item.deltaWeeks, weeks > 0 else { return capitalized }
        return "\(capitalized) · \(weeks) week\(weeks == 1 ? "" : "s")"
    }

    private var summarySentence: String? {
        guard let delta = item.deltaKg,
              let text = Celebration.deltaText(kilograms: delta, unit: unit.trainingUnit)
        else { return nil }
        guard let weeks = item.deltaWeeks, weeks > 0 else { return text.prefix(1).uppercased() + text.dropFirst() }
        return "\(text.prefix(1).uppercased() + text.dropFirst()) over \(weeks) week\(weeks == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onOpenHistory()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                TrainingEyebrow(text: "Strength · \(item.exerciseName)")

                currentValue

                if hasTrend {
                    StrengthChartView(
                        points: item.points,
                        unit: unit,
                        exerciseName: item.exerciseName,
                        allowsScrub: false,
                        height: 72,
                        summary: summarySentence
                    )
                } else {
                    notEnoughData
                }

                if state == .failed {
                    Text("Couldn't refresh. Showing your last saved data.")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if item.lastPR != nil || item.lastPRDate != nil {
                    lastRecordRow(item.lastPR)
                }
            }
            .trainingCard(theme: theme)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Con `.contain` y sin etiqueta propia, VoiceOver anunciaba el botón exterior sin decir
        // qué abre; es la única entrada a S15 desde la home.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(currentValueLabel)
        .accessibilityHint("Opens the full history for \(item.exerciseName).")
    }

    // MARK: - Cifra

    private var currentValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.currentE1RMKg.map { unit.loadLabel(kilograms: $0) } ?? NumberFormat.placeholder)
                    .font(TrainingType.monoXL())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("est. 1RM")
                    .font(TrainingType.label())
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }

            Spacer(minLength: 8)

            if let deltaText {
                Text(deltaText)
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(deltaColor)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentValueLabel)
    }

    private var currentValueLabel: String {
        var text = "\(item.exerciseName) estimated one rep max"
        if let current = item.currentE1RMKg {
            text += ", \(Celebration.number(unit.fromKilograms(current))) \(unit == .pounds ? "pounds" : "kilograms")"
        } else {
            text += ", not available yet"
        }
        if let summarySentence { text += ". \(summarySentence)" }
        return text + "."
    }

    // MARK: - Sin tendencia

    private var notEnoughData: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .foregroundColor(Color.dynamicBorder(theme: theme).opacity(0.4))
                .frame(height: 1)
                .accessibilityHidden(true)

            Text("Log two sessions to see your trend.")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Última marca

    /// El backend real manda `last_pr` como fecha; el contrato del plan, como serie completa.
    /// Con la serie se pinta «185 × 5 · Sep 8»; con la fecha sola, «Sep 8».
    private func lastRecordRow(_ record: TrainingTopRecord?) -> some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onOpenRecords()
        }) {
            HStack(spacing: 6) {
                Text("Last PR")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Text("·")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .accessibilityHidden(true)

                Text(recordText(record))
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Last personal record. \(spokenRecord(record))")
        .accessibilityHint("Opens your records.")
    }

    private func recordText(_ record: TrainingTopRecord?) -> String {
        var parts: [String] = []
        if let record {
            if let weight = record.weightKg, let reps = record.reps {
                parts.append("\(Celebration.number(unit.loadValue(kilograms: weight))) × \(reps)")
            } else if let reps = record.reps {
                parts.append("\(reps) reps")
            }
        }
        if let achieved = lastRecordDate {
            parts.append(TrainingFormat.dayMonth(achieved))
        }
        return parts.isEmpty ? NumberFormat.placeholder : parts.joined(separator: " · ")
    }

    /// La fecha del último punto es la de la sesión donde se hizo la marca; si el backend manda
    /// `last_pr` como fecha, esa gana.
    private var lastRecordDate: Date? {
        item.lastPRDate ?? item.points.last?.date?.startOfDay(in: .current)
    }

    private func spokenRecord(_ record: TrainingTopRecord?) -> String {
        guard let record else {
            guard let date = lastRecordDate else { return "Date not available." }
            return "\(TrainingFormat.dayMonth(date))."
        }
        return Celebration.spokenSet(
            exerciseName: record.exerciseName,
            weightKg: record.weightKg,
            reps: record.reps ?? 1,
            unit: unit.trainingUnit
        )
    }
}
