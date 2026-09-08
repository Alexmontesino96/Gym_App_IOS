//
//  ProgramWeekCardView.swift
//  Gym_API
//
//  W4 · Program week (UX §4).
//
//  Sustituye a `ProgramPlaceholderCard`, que decía «tu entrenador todavía no ha publicado tu
//  programa» porque hasta ahora era verdad siempre.
//
//  Regla de la tarjeta: el estado de cada día se ve por su GLIFO, no por su color. Un check, un
//  guion, un punto, un círculo vacío y un punto medio. Quien no distingue el lima del gris sigue
//  sabiendo qué días entrenó (checklist §10.5).
//

import SwiftUI
import TrainingCore

struct ProgramWeekCardView: View {

    let program: MyProgramResponse?
    let state: LoadState
    /// Abre S12 en la semana que se está mirando.
    let onOpenWeek: () -> Void
    /// Abre S17 del día tocado. Los días de descanso sin `day_id` no llaman.
    let onOpenDay: (TrainingWeekDay) -> Void
    /// Salida del estado vacío: la lista de sesiones que ya existe.
    let onBrowseSessions: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var hasAppeared = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var week: TrainingWeek? { program?.week }

    private var blockLine: String? {
        guard let block = program?.current?.block else { return program?.program?.name }
        let number = max(1, block.orderIndex + 1)
        return "Block \(number) · \(block.name)"
    }

    private var weekLine: String? {
        guard let week, let total = program?.program?.durationWeeks else { return nil }
        return "Week \(week.weekNumber) of \(total)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let week {
                dayPills(week)
                progress(week)
                if state == .failed {
                    Text("Showing last synced week")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            } else if state == .loading || state == .idle {
                loadingPills
            } else {
                emptyState
            }
        }
        .trainingCard(theme: theme)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(containerLabel)
        .onAppear { hasAppeared = true }
    }

    // MARK: - Cabecera

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                guard week != nil else { return }
                HapticManager.shared.play(.selection)
                onOpenWeek()
            }) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("THIS WEEK")
                        .font(TrainingType.label())
                        .tracking(0.8)
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                    Spacer(minLength: 4)

                    if let weekLine {
                        HStack(spacing: 4) {
                            Text(weekLine)
                                .font(TrainingType.caption())
                                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            Image(systemName: "chevron.right")
                                .font(TrainingType.icon(11, weight: .semibold))
                                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        }
                    }
                }
                // 44 pt reales: la cabecera es el atajo a S12 y el checklist §10.6 no distingue
                // entre un botón y una fila que se puede tocar.
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(week == nil)
            .accessibilityLabel(weekLine.map { "This week. \($0)." } ?? "This week")
            .accessibilityHint(week == nil ? "" : "Opens your weekly program.")

            if let blockLine, week != nil {
                Text(blockLine)
                    .font(TrainingType.subhead())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Pills

    private func dayPills(_ week: TrainingWeek) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(week.days.enumerated()), id: \.element.dayNumber) { index, day in
                DayPill(
                    day: day,
                    index: index,
                    animate: hasAppeared && !reduceMotion,
                    onTap: {
                        HapticManager.shared.play(.selection)
                        onOpenDay(day)
                    }
                )
            }
        }
    }

    private var loadingPills: some View {
        HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { _ in
                VStack(spacing: 6) {
                    TrainingSkeletonBar(width: 12, height: 8, cornerRadius: 4)
                    TrainingSkeletonBar(width: 30, height: 30, cornerRadius: 15)
                    TrainingSkeletonBar(width: 14, height: 8, cornerRadius: 4)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .accessibilityHidden(true)
        .accessibilityLabel("Loading your week")
    }

    // MARK: - Progreso

    private func progress(_ week: TrainingWeek) -> some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                let planned = max(week.plannedCount, 1)
                let fraction = min(1, Double(week.doneCount) / Double(planned))
                ZStack(alignment: .leading) {
                    // El carril, no el relleno: en claro `surface/2` sobre la tarjeta es
                    // invisible y la barra parecía vacía siempre.
                    Capsule().fill(Color.dynamicBorder(theme: theme).opacity(0.35))
                    Capsule()
                        .fill(Color.dynamicAccent(theme: theme))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)

            Text("\(week.doneCount) of \(week.plannedCount) done")
                .font(TrainingType.caption())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(week.doneCount) of \(week.plannedCount) sessions done this week")
    }

    // MARK: - Vacío

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No program yet — your coach will add one.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onBrowseSessions) {
                Text("Browse sessions")
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

    // MARK: - Accesibilidad

    private var containerLabel: String {
        guard let week else { return "This week. No program yet." }
        var parts = ["This week."]
        if let blockLine { parts.append(blockLine.replacingOccurrences(of: "·", with: ",") + ".") }
        if let weekLine { parts.append(weekLine + ".") }
        parts.append("\(week.doneCount) of \(week.plannedCount) done.")
        return parts.joined(separator: " ")
    }
}

// MARK: - Un día

private struct DayPill: View {

    let day: TrainingWeekDay
    let index: Int
    let animate: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    @State private var opacity: Double = 0
    @State private var pulse: CGFloat = 1

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var isOpenable: Bool { day.dayId != nil }

    /// Inicial del día de la semana en la posición: M T W T F S S.
    private var weekdayInitial: String {
        let initials = ["M", "T", "W", "T", "F", "S", "S"]
        let position = WeekMath.weekdayIndex(forDayNumber: day.dayNumber) - 1
        guard initials.indices.contains(position) else { return "" }
        return initials[position]
    }

    private var dayOfMonth: String {
        guard let date = day.date else { return "" }
        return String(date.day)
    }

    var body: some View {
        Button(action: { if isOpenable { onTap() } }) {
            VStack(spacing: 5) {
                Text(weekdayInitial)
                    .font(TrainingType.label())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                glyph
                    .frame(width: 30, height: 30)
                    .background(background)
                    .overlay(border)
                    .clipShape(Circle())
                    .scaleEffect(pulse)

                Text(dayOfMonth)
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(
                        day.status == .today
                            ? Color.dynamicText(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isOpenable)
        .opacity(opacity)
        .accessibilityLabel(label)
        .accessibilityHint(isOpenable ? "Opens the day." : "")
        .onAppear { appear() }
    }

    // MARK: Glifo por estado (nunca solo color)

    @ViewBuilder
    private var glyph: some View {
        switch day.status {
        case .done:
            Image(systemName: "checkmark")
                .font(TrainingType.icon(13, weight: .bold))
                .foregroundColor(Color.dynamicAccentText(theme: theme))
        case .today:
            Circle()
                .fill(Color.dynamicAccentText(theme: theme))
                .frame(width: 8, height: 8)
        case .rest:
            Text("–")
                .font(TrainingType.monoS())
                .foregroundColor(Color.dynamicTextTertiary(theme: theme).opacity(0.7))
        case .skipped:
            Text("·")
                .font(TrainingType.icon(17, weight: .bold))
                .foregroundColor(Color.dynamicWarningText(theme: theme))
        case .pending:
            Color.clear
        }
    }

    @ViewBuilder
    private var background: some View {
        switch day.status {
        case .done:
            Circle().fill(Color.dynamicSurface2(theme: theme))
        case .today:
            Circle().fill(Color.dynamicSurface2(theme: theme))
        default:
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        switch day.status {
        case .today:
            Circle().stroke(Color.dynamicAccentText(theme: theme), lineWidth: 1.5)
        case .pending:
            Circle().stroke(Color.dynamicBorder(theme: theme).opacity(0.5), lineWidth: 1)
        case .skipped:
            Circle().stroke(Color.dynamicWarningText(theme: theme).opacity(0.4), lineWidth: 1)
        default:
            Circle().stroke(Color.clear, lineWidth: 0)
        }
    }

    // MARK: Motion

    private func appear() {
        guard opacity == 0 else { return }
        if animate {
            withAnimation(.easeOut(duration: 0.2).delay(Double(index) * 0.02)) {
                opacity = 1
            }
            if day.status == .today {
                withAnimation(.easeInOut(duration: 0.12).delay(0.24)) { pulse = 1.04 }
                withAnimation(.easeInOut(duration: 0.12).delay(0.36)) { pulse = 1.0 }
            }
        } else {
            opacity = 1
        }
    }

    // MARK: Accesibilidad

    /// «Thursday 12. Today. Upper B. Not started.»
    private var label: String {
        var parts: [String] = []
        if let date = day.date {
            let weekday = DateFormatter.localized(template: "EEEE")
                .string(from: date.startOfDay(in: .current))
            parts.append("\(weekday) \(date.day).")
        }
        switch day.status {
        case .today: parts.append("Today.")
        case .done: parts.append("Done.")
        case .rest: parts.append("Rest day.")
        case .skipped: parts.append("Not logged.")
        case .pending: parts.append("Planned.")
        }
        if let name = day.name, !name.isEmpty { parts.append("\(name).") }
        if day.status != .done && day.status != .rest && !day.isRest {
            parts.append("Not started.")
        }
        return parts.joined(separator: " ")
    }
}
