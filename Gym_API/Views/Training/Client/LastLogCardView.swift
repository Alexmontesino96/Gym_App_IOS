//
//  LastLogCardView.swift
//  Gym_API
//
//  W8 · Last log (UX §4).
//
//  Tres columnas del mismo peso, porque las tres cifras valen lo mismo: cuánto duró, cuántas
//  series y cuánto volumen. El rombo de la marca es lo único con acento, y el texto que lo
//  acompaña se queda en tinta normal para que no parezca un aviso.
//

import SwiftUI
import TrainingCore

struct LastLogCardView: View {

    let log: TrainingWorkoutLogSummary?
    let state: LoadState
    /// Contexto del programa: «Block 2 · Week 3». Nulo en un entreno libre.
    var contextNote: String?
    /// Abre S18 en modo lectura.
    let onOpen: () -> Void
    /// Salida del estado vacío.
    let onStartWorkout: () -> Void
    /// Acciones del menú largo. `onViewProgramDay` es nulo si el registro no cuelga de un día.
    var onShareToStory: (() -> Void)?
    var onShareToFeed: (() -> Void)?
    var onViewProgramDay: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    var body: some View {
        Group {
            if let log {
                content(log)
            } else if state == .loading || state == .idle {
                loading
            } else {
                empty
            }
        }
        .trainingCard(theme: theme)
    }

    // MARK: - Con registro

    private func content(_ log: TrainingWorkoutLogSummary) -> some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onOpen()
        }) {
            VStack(alignment: .leading, spacing: 14) {
                header(log)

                if let title = titleLine(log) {
                    Text(title)
                        .font(TrainingType.subhead())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }

                metrics(log)

                if let record = log.topPR, log.prCount > 0 {
                    recordLine(log: log, record: record)
                }

                if log.isPartial {
                    Text("Partial session saved")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenuItems }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(log))
        .accessibilityHint("Opens the session summary.")
        .accessibilityAction(named: Text("Share to story")) { onShareToStory?() }
        .accessibilityAction(named: Text("Share to feed")) { onShareToFeed?() }
        .accessibilityAction(named: Text("View program day")) { onViewProgramDay?() }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if let onShareToStory {
            Button {
                HapticManager.shared.play(.light)
                onShareToStory()
            } label: {
                Label("Share to story", systemImage: "sparkles")
            }
        }
        if let onShareToFeed {
            Button {
                HapticManager.shared.play(.light)
                onShareToFeed()
            } label: {
                Label("Share to feed", systemImage: "square.and.arrow.up")
            }
        }
        if let onViewProgramDay {
            Button {
                HapticManager.shared.play(.light)
                onViewProgramDay()
            } label: {
                Label("View program day", systemImage: "calendar")
            }
        }
    }

    private func header(_ log: TrainingWorkoutLogSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("LAST LOG")
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

            Spacer(minLength: 4)

            if syncCoordinator.pendingCount > 0 || syncCoordinator.failedCount > 0 {
                TrainingSyncChip(compact: true)
            } else if let date = log.completedAt {
                HStack(spacing: 4) {
                    Text(TrainingFormat.shortDate(date))
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            }
        }
    }

    private func titleLine(_ log: TrainingWorkoutLogSummary) -> String? {
        guard let contextNote, !contextNote.isEmpty else { return log.title }
        return "\(log.title) · \(contextNote)"
    }

    private func metrics(_ log: TrainingWorkoutLogSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            TrainingMetricView(
                value: TrainingFormat.duration(log.durationSeconds ?? 0),
                label: "duration",
                spoken: "\(TrainingFormat.spokenDuration(log.durationSeconds ?? 0)), duration"
            )
            TrainingMetricView(
                value: "\(log.totalSets)",
                label: "sets",
                spoken: "\(log.totalSets) sets"
            )
            TrainingMetricView(
                value: unit.volumeLabel(kilograms: log.totalVolumeKg),
                label: "volume",
                spoken: "\(unit.volumeLabel(kilograms: log.totalVolumeKg)) of volume"
            )
        }
    }

    private func recordLine(log: TrainingWorkoutLogSummary, record: TrainingTopRecord) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicAccent(theme: theme))

            Text(recordText(log: log, record: record))
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }

    private func recordText(log: TrainingWorkoutLogSummary, record: TrainingTopRecord) -> String {
        let count = "\(log.prCount) record\(log.prCount == 1 ? "" : "s")"
        var detail = record.exerciseName
        if let weight = record.weightKg, let reps = record.reps {
            detail += " \(Celebration.number(unit.fromKilograms(weight))) × \(reps)"
        }
        return "\(count) · \(detail)"
    }

    // MARK: - Vacío y carga

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            TrainingEyebrow(text: "Last log")

            Text("Nothing logged yet. Your first session is the hard one.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                HapticManager.shared.play(.light)
                onStartWorkout()
            }) {
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

    private var loading: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrainingEyebrow(text: "Last log")
            TrainingSkeletonBar(width: 160, height: 14)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        TrainingSkeletonBar(width: 60, height: 20)
                        TrainingSkeletonBar(width: 40, height: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your last log")
    }

    // MARK: - Accesibilidad

    private func accessibilityLabel(_ log: TrainingWorkoutLogSummary) -> String {
        var parts: [String] = ["Last log"]
        if let date = log.completedAt { parts.append(TrainingFormat.shortDate(date)) }
        parts.append(titleLine(log) ?? log.title)
        parts.append(TrainingFormat.spokenDuration(log.durationSeconds ?? 0))
        parts.append("\(log.totalSets) sets")
        parts.append("\(unit.volumeLabel(kilograms: log.totalVolumeKg)) of volume")
        if log.prCount > 0, let record = log.topPR {
            let spoken = Celebration.spokenSet(
                exerciseName: record.exerciseName,
                weightKg: record.weightKg,
                reps: record.reps ?? 1,
                unit: unit.trainingUnit
            )
            parts.append("\(log.prCount) personal record\(log.prCount == 1 ? "" : "s"): \(spoken)")
        }
        if log.isPartial { parts.append("Partial session saved") }
        return parts.joined(separator: ". ")
    }
}
