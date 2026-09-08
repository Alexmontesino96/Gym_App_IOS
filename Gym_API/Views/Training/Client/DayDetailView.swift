//
//  DayDetailView.swift
//  Gym_API
//
//  S17 · Day detail (UX §5).
//
//  Lo que esta pantalla tiene que dejar claro antes de que nadie toque «Start session»: qué toca
//  hoy, qué dijo el entrenador y qué va con qué. Las superseries no se explican con un color: se
//  numeran 3a/3b, comparten filete y lo dicen con la palabra «superset».
//

import SwiftUI
import TrainingCore

/// El nombre lleva prefijo porque `DayDetailView` ya existe en el mapa de rachas
/// (`Views/Streak/Components/StreakCalendarHeatmap.swift`), que es otra cosa.
struct TrainingDayDetailView: View {

    let dayId: Int
    /// Abre S11 con este día.
    let onStartSession: (Int) -> Void
    /// Abre S11 en modo entreno libre (día de descanso).
    let onStartFreeWorkout: () -> Void
    /// Abre S18 del registro de ese día, si ya existe.
    let onViewLog: (Int) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    private var day: TrainingDay? {
        guard let day = trainingService.day, day.id == dayId else { return nil }
        return day
    }

    /// El estado del día lo sabe la semana, no el día: `/me/days/{id}` no lo trae.
    private var weekDay: TrainingWeekDay? {
        let candidates = (trainingService.week?.days ?? []) + (trainingService.myProgram?.week?.days ?? [])
        return candidates.first { $0.dayId == dayId }
    }

    private var exercises: [TrainingDayExercise] { day?.exercisesInOrder ?? [] }
    private var positionLabels: [String] { TrainingPrescription.positionLabels(for: exercises) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let day {
                    header(day)

                    if let note = day.coachNote {
                        coachNote(note)
                    }

                    if day.isRest {
                        restDay
                    } else {
                        exerciseList
                    }
                } else if trainingService.dayState == .failed {
                    TrainingRetryRow(
                        message: "Couldn't load this day.",
                        retryTitle: "Retry",
                        onRetry: { Task { await trainingService.fetchDay(dayId) } }
                    )
                    .trainingCard(theme: theme)
                } else {
                    loading
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 80)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if let day, !day.isRest {
                primaryAction(day)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.dynamicBackground(theme: theme).opacity(0.96))
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await trainingService.fetchDay(dayId) }
    }

    private var navigationTitle: String {
        guard let date = weekDay?.date else { return day?.displayName ?? "Day" }
        return TrainingFormat.longDate(date.startOfDay(in: .current))
    }

    // MARK: - Cabecera

    private func header(_ day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.displayName)
                .font(TrainingType.title1())
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            if let context = contextLine(day) {
                Text(context)
                    .font(TrainingType.subhead())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func contextLine(_ day: TrainingDay) -> String? {
        var parts: [String] = []
        if let block = trainingService.myProgram?.current?.block, block.contains(week: day.weekNumber) {
            parts.append("Block \(max(1, block.orderIndex + 1))")
        }
        parts.append("Week \(day.weekNumber)")
        if let focus = day.focus, !focus.isEmpty { parts.insert(focus, at: 0) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Nota del coach

    private func coachNote(_ note: TrainingClientDayNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                avatar(for: note.author)
                Text("Note from \(note.author?.name.components(separatedBy: " ").first ?? "your coach")")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
            }

            Text("“\(note.text)”")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .trainingCard(theme: theme)
        .accessibilityElement(children: .combine)
    }

    /// Cara del entrenador cuando el endpoint la manda. El backend real envía la nota como
    /// cadena, sin autor: en ese caso un círculo con «?» sería peor que una comilla.
    private func avatar(for person: TrainingPerson?) -> some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            if let person {
                Text(person.initials)
                    .font(TrainingType.label())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            } else {
                Image(systemName: "quote.opening")
                    .font(TrainingType.icon(11, weight: .regular))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    // MARK: - Ejercicios

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRow(
                    exercise: exercise,
                    position: positionLabels.indices.contains(index) ? positionLabels[index] : "\(index + 1)",
                    index: index,
                    total: exercises.count,
                    partners: TrainingPrescription.supersetPartnerNames(of: exercise, in: exercises),
                    unit: unit
                )
                if index < exercises.count - 1 {
                    Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                }
            }
        }
        .trainingCard(theme: theme, padding: 0)
    }

    // MARK: - Descanso

    private var restDay: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rest day")
                .font(TrainingType.title2())
                .foregroundColor(Color.dynamicText(theme: theme))

            Button(action: {
                HapticManager.shared.play(.medium)
                onStartFreeWorkout()
            }) {
                Text("Log a free workout")
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
        .trainingCard(theme: theme)
    }

    // MARK: - CTA

    @ViewBuilder
    private func primaryAction(_ day: TrainingDay) -> some View {
        let status = weekDay?.status ?? .today

        VStack(spacing: 6) {
            if status == .done, let logId = weekDay?.logId {
                actionButton(title: "View log", filled: false) { onViewLog(logId) }
            } else if status == .skipped {
                actionButton(title: "Log this session", filled: true) { onStartSession(day.id) }
                Text("Logged late — that's fine.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            } else {
                actionButton(title: "Start session", filled: true) { onStartSession(day.id) }
            }
        }
    }

    private func actionButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.play(.medium)
            action()
        }) {
            Text(title)
                .font(TrainingType.headline())
                .foregroundColor(
                    filled
                        ? ThemeManager.accentInkForCurrentAccent(theme: theme)
                        : Color.dynamicText(theme: theme)
                )
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    Group {
                        if filled {
                            Capsule().fill(Color.dynamicAccent(theme: theme))
                        } else {
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.5), lineWidth: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Carga

    private var loading: some View {
        VStack(alignment: .leading, spacing: 12) {
            TrainingSkeletonBar(width: 180, height: 24)
            TrainingSkeletonBar(width: 140, height: 14)
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    TrainingSkeletonBar(width: 22, height: 14)
                    VStack(alignment: .leading, spacing: 6) {
                        TrainingSkeletonBar(width: 150, height: 14)
                        TrainingSkeletonBar(width: 100, height: 10)
                    }
                    Spacer()
                }
                .frame(minHeight: 56)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading the day")
    }
}

// MARK: - Fila de ejercicio

private struct ExerciseRow: View {

    let exercise: TrainingDayExercise
    let position: String
    let index: Int
    let total: Int
    let partners: [String]
    let unit: WeightUnit

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var isSuperset: Bool { !partners.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isSuperset {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.dynamicAccent(theme: theme).opacity(0.3))
                    .frame(width: 2)
                    .accessibilityHidden(true)
            }

            Text(position)
                .font(TrainingType.monoS())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .frame(width: 24, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exerciseName)
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(TrainingPrescription.text(for: exercise, unit: unit))
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)

                if isSuperset {
                    Text("superset")
                        .font(TrainingType.label())
                        .tracking(0.8)
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }

                if let notes = exercise.notes, !notes.isEmpty {
                    Text("“\(notes)”")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var text = "Exercise \(index + 1) of \(total). \(exercise.exerciseName). "
        text += TrainingPrescription.spoken(for: exercise, unit: unit)
        if !partners.isEmpty {
            text += " Superset with \(partners.joined(separator: " and "))."
        }
        if let notes = exercise.notes, !notes.isEmpty {
            text += " Note: \(notes)"
        }
        return text
    }
}
