//
//  RecordsView.swift
//  Gym_API
//
//  S16 · Records (UX §5).
//
//  Detalle que decide si esta pantalla es honesta: mientras la sesión que produjo una marca siga
//  en la cola de sincronización, la marca NO se llama «Personal record». El cálculo lo hace el
//  servidor (plan §4.5) y hasta que responda es «Best set so far».
//

import SwiftUI
import TrainingCore

struct RecordsView: View {

    /// Abre S15 del ejercicio desde la hoja de detalle.
    var onOpenHistory: ((String, String) -> Void)?
    /// Compartir la marca a una historia.
    var onShare: ((TrainingPersonalRecord) -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator

    @State private var filter: Filter = .all
    @State private var selected: TrainingPersonalRecord?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case thisYear = "This year"
        case mainLifts = "Main lifts"

        var id: String { rawValue }
    }

    /// Mientras haya algo sin sincronizar, ninguna marca reciente puede afirmarse.
    private var hasPendingSync: Bool {
        syncCoordinator.pendingCount > 0 || syncCoordinator.failedCount > 0
    }

    private var focusKeys: Set<String> {
        Set(trainingService.myProgram?.program?.focusExerciseKeys ?? [])
    }

    private var records: [TrainingPersonalRecord] {
        let all = trainingService.records
        switch filter {
        case .all:
            return all
        case .thisYear:
            let year = Calendar.current.component(.year, from: Date())
            return all.filter { record in
                guard let achieved = record.achievedAt else { return false }
                return Calendar.current.component(.year, from: achieved) == year
            }
        case .mainLifts:
            guard !focusKeys.isEmpty else { return all }
            return all.filter { focusKeys.contains($0.exerciseKey) }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                filters

                if hasPendingSync {
                    TrainingSyncChip()
                        .padding(.horizontal, 4)
                }

                if !records.isEmpty {
                    list
                } else if trainingService.recordsState == .loading {
                    loading
                } else if trainingService.recordsState == .failed {
                    TrainingRetryRow(
                        message: "Couldn't load your records.",
                        retryTitle: "Retry",
                        onRetry: { Task { await trainingService.fetchRecords() } }
                    )
                    .trainingCard(theme: theme)
                } else {
                    empty
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .task { await trainingService.fetchRecords() }
        .refreshable { await trainingService.fetchRecords() }
        .sheet(item: $selected) { record in
            RecordDetailSheet(
                record: record,
                isConfirmed: !hasPendingSync,
                onOpenHistory: onOpenHistory,
                onShare: onShare
            )
        }
    }

    // MARK: - Filtros

    private var filters: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { option in
                Button(action: {
                    HapticManager.shared.play(.selection)
                    filter = option
                }) {
                    Text(option.rawValue)
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(
                            filter == option
                                ? Color.dynamicText(theme: theme)
                                : Color.dynamicTextTertiary(theme: theme)
                        )
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(
                            Capsule().fill(
                                filter == option
                                    ? Color.dynamicSurface2(theme: theme)
                                    : Color.clear
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                Color.dynamicBorder(theme: theme).opacity(filter == option ? 0.4 : 0.2),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(filter == option ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Lista

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                RecordRow(
                    record: record,
                    unit: unit,
                    isConfirmed: !hasPendingSync,
                    onTap: { selected = record }
                )
                if index < records.count - 1 {
                    Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                }
            }
        }
        .trainingCard(theme: theme, padding: 0)
    }

    // MARK: - Estados

    private var loading: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    TrainingSkeletonBar(width: 14, height: 14, cornerRadius: 3)
                    VStack(alignment: .leading, spacing: 6) {
                        TrainingSkeletonBar(width: 130, height: 14)
                        TrainingSkeletonBar(width: 90, height: 10)
                    }
                    Spacer()
                    TrainingSkeletonBar(width: 50, height: 12)
                }
                .frame(minHeight: 60)
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your records")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "diamond")
                .font(TrainingType.icon(22, weight: .light))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .accessibilityHidden(true)

            Text("Records show up here after your first heavy set.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .trainingCard(theme: theme)
    }
}

// MARK: - Fila

private struct RecordRow: View {

    let record: TrainingPersonalRecord
    let unit: WeightUnit
    let isConfirmed: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var setText: String {
        guard let weight = record.bestWeightKg, let reps = record.bestReps else {
            if let reps = record.bestReps { return "\(reps) reps" }
            return NumberFormat.placeholder
        }
        return "\(Celebration.number(unit.loadValue(kilograms: weight))) × \(reps)"
    }

    private var deltaText: String {
        if record.isFirstRecord { return "first record" }
        guard let delta = record.deltaKg else { return "" }
        let value = unit.signedLoadLabel(kilograms: delta)
        return value
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isConfirmed ? "diamond.fill" : "diamond")
                    .font(TrainingType.icon(11, weight: .regular))
                    .foregroundColor(
                        isConfirmed
                            ? Color.dynamicAccentText(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )
                    .padding(.top, 3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.displayName)
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)

                    if let e1rm = record.bestE1RMKg {
                        Text("est. 1RM \(unit.loadLabel(kilograms: e1rm))")
                            .font(TrainingType.caption())
                            .monospacedDigit()
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(setText)
                            .font(TrainingType.monoM())
                            .monospacedDigit()
                            .foregroundColor(Color.dynamicText(theme: theme))

                        if let achieved = record.achievedAt {
                            Text(TrainingFormat.dayMonth(achieved))
                                .font(TrainingType.monoS())
                                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        }
                    }

                    if !deltaText.isEmpty {
                        Text(deltaText)
                            .font(TrainingType.caption())
                            .monospacedDigit()
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the record.")
    }

    private var accessibilityLabel: String {
        var parts: [String] = [isConfirmed ? PRBadge.confirmedText + "." : PRBadge.unconfirmedText + "."]
        parts.append(Celebration.spokenSet(
            exerciseName: record.displayName,
            weightKg: record.bestWeightKg,
            reps: record.bestReps ?? 1,
            unit: unit.trainingUnit
        ))
        if let e1rm = record.bestE1RMKg {
            parts.append("Estimated one rep max \(Celebration.loadText(kilograms: e1rm, unit: unit.trainingUnit)).")
        }
        if record.isFirstRecord {
            parts.append("First record.")
        } else if let delta = record.deltaKg, delta > 0 {
            let value = Celebration.number(unit.fromKilograms(delta))
            parts.append("Up \(value) \(unit == .pounds ? "pounds" : "kilograms") from your previous record.")
        }
        if let achieved = record.achievedAt {
            parts.append(TrainingFormat.dayMonth(achieved) + ".")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Hoja de detalle

private struct RecordDetailSheet: View {

    let record: TrainingPersonalRecord
    let isConfirmed: Bool
    let onOpenHistory: ((String, String) -> Void)?
    let onShare: ((TrainingPersonalRecord) -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    private var celebration: PersonalRecordCelebration {
        if isConfirmed {
            return Celebration.forConfirmedRecord(
                exerciseName: record.displayName,
                weightKg: record.bestWeightKg,
                reps: record.bestReps ?? 1,
                e1rmKg: record.bestE1RMKg,
                deltaKg: record.deltaKg,
                isFirstRecord: record.isFirstRecord,
                previousBestKg: record.bestWeightKg.flatMap { best in
                    record.deltaKg.map { best - $0 }
                },
                unit: unit.trainingUnit
            )
        }
        return Celebration.forLocalBestSet(
            exerciseName: record.displayName,
            best: BestSetSoFar(
                exerciseKey: record.exerciseKey,
                setNumber: record.set?.setNumber ?? 1,
                reps: record.bestReps ?? 1,
                weightKg: record.bestWeightKg,
                e1rmKg: record.bestE1RMKg
            ),
            unit: unit.trainingUnit
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    RecordCelebrationCard(celebration: celebration, playsCelebration: isConfirmed)

                    if record.coachCongratulated {
                        Text("Your coach congratulated you")
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    }

                    if let achieved = record.achievedAt {
                        Text(TrainingFormat.longDate(achieved))
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }

                    HStack(spacing: 10) {
                        if let onShare {
                            Button(action: {
                                HapticManager.shared.play(.light)
                                onShare(record)
                                dismiss()
                            }) {
                                Text("Share")
                                    .font(TrainingType.caption())
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.dynamicText(theme: theme))
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 44)
                                    .overlay(
                                        Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if let onOpenHistory {
                            Button(action: {
                                HapticManager.shared.play(.selection)
                                let name = record.displayName
                                let key = record.exerciseKey
                                dismiss()
                                onOpenHistory(key, name)
                            }) {
                                Text("View history")
                                    .font(TrainingType.caption())
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.dynamicText(theme: theme))
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 44)
                                    .overlay(
                                        Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(16)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(record.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
