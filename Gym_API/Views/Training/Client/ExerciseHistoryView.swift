//
//  ExerciseHistoryView.swift
//  Gym_API
//
//  S15 · Exercise history (UX §5).
//
//  El gráfico se puede arrastrar para leer punto a punto y, para quien no ve la pantalla, expone
//  un descriptor de audio-gráfico: la misma curva, oída. El rombo de una marca nunca es la única
//  señal — la etiqueta dice «Personal record» con todas sus letras.
//

import SwiftUI
import TrainingCore

struct ExerciseHistoryView: View {

    let exerciseKey: String
    let exerciseName: String
    /// Abre S18 de una sesión del historial.
    var onOpenLog: ((Int) -> Void)?
    /// Salida del estado vacío.
    var onStartWorkout: (() -> Void)?
    var onChangeUnits: (() -> Void)?
    var onShareProgress: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService

    @State private var range: Range = .eightWeeks

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    enum Range: String, CaseIterable, Identifiable {
        case eightWeeks = "8w"
        case sixMonths = "6m"
        case all = "all"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .eightWeeks: return "8 weeks"
            case .sixMonths: return "6 months"
            case .all: return "All"
            }
        }
    }

    private var history: ExerciseHistory? {
        guard let history = trainingService.exerciseHistory, history.exerciseKey == exerciseKey else { return nil }
        return history
    }

    private var points: [StrengthSummaryPoint] { history?.points ?? [] }

    private var currentE1RM: Double? { points.last?.e1rmKg }

    private var delta: Double? {
        guard let first = points.first?.e1rmKg, let last = points.last?.e1rmKg, points.count >= 2 else { return nil }
        return last - first
    }

    private var deltaText: String? {
        guard let delta, let text = Celebration.deltaText(kilograms: delta, unit: unit.trainingUnit) else { return nil }
        let capitalized = text.prefix(1).uppercased() + text.dropFirst()
        return "\(capitalized) · \(range.title)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if points.count >= 2 {
                    summary
                    StrengthChartView(
                        points: points,
                        unit: unit,
                        exerciseName: exerciseName,
                        allowsScrub: true,
                        height: 120,
                        summary: deltaText
                    )
                    rangePicker
                } else if points.count == 1 {
                    summary
                    Text("One session logged. The trend appears after the second.")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                    rangePicker
                } else if trainingService.exerciseHistoryState == .loading {
                    loading
                } else if trainingService.exerciseHistoryState == .failed {
                    TrainingRetryRow(
                        message: "Couldn't load this history.",
                        retryTitle: "Retry",
                        onRetry: { Task { await load() } }
                    )
                    .trainingCard(theme: theme)
                } else {
                    empty
                }

                if let history, !history.bestSets.isEmpty {
                    bestSets(history.bestSets)
                }

                if let history, !history.sessions.isEmpty {
                    sessions(history.sessions)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let onChangeUnits {
                        Button("Change unit", action: onChangeUnits)
                    }
                    if let onShareProgress {
                        Button("Share progress", action: onShareProgress)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .trainingTouchTarget()
                }
                .accessibilityLabel("More options")
            }
        }
        .task { await load() }
    }

    private func load() async {
        await trainingService.fetchExerciseHistory(exerciseKey: exerciseKey, range: range.rawValue)
    }

    // MARK: - Cabecera

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentE1RM.map { unit.loadLabel(kilograms: $0) } ?? NumberFormat.placeholder)
                    .font(TrainingType.monoXL())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("est. 1RM (Epley)")
                    .font(TrainingType.label())
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }

            Spacer(minLength: 8)

            if let deltaText, let delta {
                Text(deltaText)
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(delta >= 0 ? Color.successGreen : Color.warningYellow)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryLabel)
    }

    private var summaryLabel: String {
        var text = "\(exerciseName) estimated one rep max"
        if let currentE1RM {
            text += ", \(Celebration.loadText(kilograms: currentE1RM, unit: unit.trainingUnit))"
        }
        if let deltaText { text += ". \(deltaText)" }
        return text + "."
    }

    // MARK: - Rango

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(Range.allCases) { option in
                Button(action: {
                    HapticManager.shared.play(.selection)
                    range = option
                    Task { await load() }
                }) {
                    Text(option.title)
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(
                            range == option
                                ? Color.dynamicText(theme: theme)
                                : Color.dynamicTextTertiary(theme: theme)
                        )
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(
                            Capsule().fill(range == option ? Color.dynamicSurface2(theme: theme) : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(
                                Color.dynamicBorder(theme: theme).opacity(range == option ? 0.4 : 0.2),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(range == option ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Mejores series

    private func bestSets(_ sets: [TrainingSetLog]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Best sets")

            VStack(spacing: 0) {
                ForEach(Array(sets.enumerated()), id: \.element.clientUUID) { index, set in
                    bestSetRow(set)
                    if index < sets.count - 1 {
                        Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                    }
                }
            }
            .trainingCard(theme: theme, padding: 0)
        }
    }

    private func bestSetRow(_ set: TrainingSetLog) -> some View {
        HStack(spacing: 12) {
            Text("\(Celebration.number(unit.loadValue(kilograms: set.weightKg ?? 0))) × \(set.reps)")
                .font(TrainingType.monoM())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(width: 92, alignment: .leading)

            if let date = set.completedAt {
                Text(TrainingFormat.dayMonth(date))
                    .font(TrainingType.monoS())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .frame(width: 62, alignment: .leading)
            }

            if let e1rm = set.e1rmKg {
                Text("est. \(unit.loadLabel(kilograms: e1rm))")
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }

            Spacer(minLength: 4)

            if set.isPR {
                PRBadge(isConfirmed: true, showsText: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bestSetLabel(set))
    }

    private func bestSetLabel(_ set: TrainingSetLog) -> String {
        var parts: [String] = [
            Celebration.spokenSet(
                exerciseName: exerciseName,
                weightKg: set.weightKg,
                reps: set.reps,
                unit: unit.trainingUnit
            )
        ]
        if let date = set.completedAt { parts.append(TrainingFormat.dayMonth(date) + ".") }
        if let e1rm = set.e1rmKg {
            parts.append("Estimated one rep max \(Celebration.loadText(kilograms: e1rm, unit: unit.trainingUnit)).")
        }
        if set.isPR { parts.append(PRBadge.confirmedText + ".") }
        return parts.joined(separator: " ")
    }

    // MARK: - Historial

    private func sessions(_ sessions: [ExerciseHistorySession]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "History")

            VStack(spacing: 0) {
                ForEach(Array(sessions.enumerated()), id: \.element.logId) { index, session in
                    sessionRow(session)
                    if index < sessions.count - 1 {
                        Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                    }
                }
            }
            .trainingCard(theme: theme, padding: 0)
        }
    }

    private func sessionRow(_ session: ExerciseHistorySession) -> some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onOpenLog?(session.logId)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(sessionTitle(session))
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Text(setsLine(session))
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onOpenLog == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sessionTitle(session)). \(spokenSets(session))")
        .accessibilityHint(onOpenLog == nil ? "" : "Opens that session.")
    }

    private func sessionTitle(_ session: ExerciseHistorySession) -> String {
        var parts: [String] = []
        if let date = session.date {
            parts.append(TrainingFormat.dayMonth(date.startOfDay(in: .current)))
        } else if let completed = session.completedAt {
            parts.append(TrainingFormat.dayMonth(completed))
        }
        if let title = session.title, !title.isEmpty { parts.append(title) }
        return parts.joined(separator: " · ")
    }

    private func setsLine(_ session: ExerciseHistorySession) -> String {
        session.sets
            .map { set in
                guard let weight = set.weightKg else { return "\(set.reps)" }
                return "\(Celebration.number(unit.loadValue(kilograms: weight)))×\(set.reps)"
            }
            .joined(separator: "   ")
    }

    private func spokenSets(_ session: ExerciseHistorySession) -> String {
        session.sets
            .map { set in
                Celebration.spokenSet(
                    exerciseName: exerciseName,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    unit: unit.trainingUnit
                )
            }
            .joined(separator: " ")
    }

    // MARK: - Estados

    private var loading: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrainingSkeletonBar(width: 140, height: 34)
            TrainingSkeletonBar(width: nil, height: 100, cornerRadius: 12)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    TrainingSkeletonBar(width: 74, height: 32, cornerRadius: 16)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading history")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No history yet for \(exerciseName.lowercased()).")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            if let onStartWorkout {
                Button(action: onStartWorkout) {
                    Text("Start a workout")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .trainingCard(theme: theme)
    }
}
