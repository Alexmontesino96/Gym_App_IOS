//
//  ClientProgramsView.swift
//  Gym_API
//
//  S20 · Client programs (UX §6).
//
//  La pantalla desde la que un entrenador gobierna el plan de una persona: qué programa tiene,
//  cómo lo está siguiendo, qué le toca cada día de la semana y por dónde se entra a cambiarlo.
//
//  De dónde sale cada dato, que aquí no es obvio:
//
//  - El programa, la adherencia y la semana EN CURSO vienen de `GET /clients/{id}/programs`, que
//    es lo único que sabe el estado real de cada día (hecho, hoy, saltado).
//  - Cualquier OTRA semana viene de `GET /programs/{id}/days?week=`, que devuelve siempre siete
//    días con sus ejercicios pero sin estado. Por eso una semana futura dice «Planned» y no
//    inventa un «Logged» que no puede saber.
//  - Los dos endpoints se piden a la vez: el editor de día necesita el día real (con su `id`, o
//    con `id` nulo si todavía no existe) venga la semana de donde venga.
//

import SwiftUI
import TrainingCore

struct ClientProgramsView: View {

    let client: TrainingClientRef
    /// Abre S22 sobre un registro concreto.
    var onOpenLog: (Int) -> Void = { _ in }

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService

    @State private var selectedWeek: Int?
    @State private var sheet: TrainerTrainingSheet?
    @State private var showsCopyWeek = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var summary: ClientProgramSummary? { trainingService.clientPrograms?.active }
    private var program: TrainingProgram? { summary?.program }

    /// La semana que se está mirando. Arranca en la del cliente, no en la 1.
    private var week: Int {
        selectedWeek ?? summary?.currentWeek ?? 1
    }

    private var isCurrentWeek: Bool { week == summary?.currentWeek }

    /// Estado por número de día, cuando la semana en curso lo trae.
    private var statusByDayNumber: [Int: TrainingWeekDay] {
        guard isCurrentWeek, let days = summary?.week?.days else { return [:] }
        return Dictionary(days.map { ($0.dayNumber, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var days: [TrainingDay] {
        trainingService.programDays.filter { $0.weekNumber == week }
    }

    private var lastLogId: Int? { trainingService.clientLogs.first?.id }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                switch trainingService.clientProgramsState {
                case .idle, .loading:
                    loading
                case .failed:
                    TrainingRetryRow(
                        message: "Couldn't load \(client.firstName)'s programs.",
                        retryTitle: "Retry",
                        onRetry: { Task { await load() } }
                    )
                    .trainingCard(theme: theme)
                case .loaded:
                    if summary != nil {
                        activeProgramCard
                        weekSection
                    } else {
                        emptyState
                    }
                    pastPrograms
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 90)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if summary != nil { bottomActions }
        }
        .navigationTitle("\(client.firstName) · Programs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .assignProgram(client: client) } label: {
                    Image(systemName: "plus")
                        .font(TrainingType.icon(15, weight: .semibold))
                        .foregroundColor(Color.dynamicAccentText(theme: theme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Assign a program")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: week) { _, newValue in
            guard let programId = program?.id else { return }
            Task { await trainingService.fetchProgramDays(programId: programId, week: newValue) }
        }
        .sheet(item: $sheet) { item in
            sheetView(item)
        }
        .sheet(isPresented: $showsCopyWeek) {
            WeekTargetPickerSheet(
                title: "Copy week \(week) to…",
                sourceLabel: "week \(week)",
                sourceWeek: week,
                durationWeeks: program?.durationWeeks ?? week,
                keepLoadsTitle: "Keep prescribed loads",
                onCopy: { weeks, keepLoads in
                    guard let programId = program?.id else { return false }
                    let result = await trainingService.duplicateWeek(
                        programId: programId,
                        week: week,
                        DuplicateWeekRequest(targetWeeks: weeks, keepLoads: keepLoads)
                    )
                    if result != nil { await reloadWeek() }
                    return result != nil
                }
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Programa activo

    @ViewBuilder
    private var activeProgramCard: some View {
        if let summary {
            let program = summary.program
            VStack(alignment: .leading, spacing: 10) {
                TrainingEyebrow(text: "Active")

                Text(program.name)
                    .font(TrainingType.title2())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(programSubtitle(summary))
                    .font(TrainingType.subhead())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)

                adherenceRow(summary)

                if let missed = summary.missedText {
                    Text(missed)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .trainingCard(theme: theme)
        }
    }

    /// «12 weeks · Week 3 · Block 2 · Upper strength»
    private func programSubtitle(_ summary: ClientProgramSummary) -> String {
        var parts = ["\(summary.program.durationWeeks) week\(summary.program.durationWeeks == 1 ? "" : "s")"]
        if let current = summary.currentWeek { parts.append("Week \(current)") }
        if let block = summary.currentBlock {
            parts.append(block.focus.map { "\(block.name) · \($0)" } ?? block.name)
        }
        if summary.assignment.mode == .shared { parts.append("Shared") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func adherenceRow(_ summary: ClientProgramSummary) -> some View {
        if let adherence = summary.adherencePct {
            let fraction = min(max(0, adherence / 100), 1)
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.dynamicBorder(theme: theme).opacity(0.35))
                        Capsule()
                            .fill(Color.dynamicAccent(theme: theme))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 4)

                Text("Adherence \(NumberFormat.trimmedDecimal(adherence))%")
                    .font(TrainingType.caption())
                    .monospacedDigit()
                    .foregroundColor(
                        summary.isAdherenceLow
                            ? Color.warningYellow
                            : Color.dynamicTextTertiary(theme: theme)
                    )
                    .lineLimit(1)
                    .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Adherence \(NumberFormat.trimmedDecimal(adherence)) percent")
        } else {
            Text("Adherence shows up after the first training day.")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Semana

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            weekHeader

            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))

            switch trainingService.programDaysState {
            case .idle, .loading:
                VStack(spacing: 10) {
                    ForEach(0..<7, id: \.self) { _ in
                        HStack(spacing: 12) {
                            TrainingSkeletonBar(width: 40, height: 12)
                            TrainingSkeletonBar(width: 120, height: 14)
                            Spacer()
                            TrainingSkeletonBar(width: 60, height: 12)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .padding(.top, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading week \(week)")
            case .failed:
                TrainingRetryRow(
                    message: "Couldn't load week \(week).",
                    retryTitle: "Retry",
                    onRetry: { Task { await reloadWeek() } }
                )
                .padding(.top, 10)
            case .loaded:
                dayList
            }
        }
        .trainingCard(theme: theme, padding: 14)
    }

    private var weekHeader: some View {
        HStack(spacing: 4) {
            weekArrow(systemName: "chevron.left", enabled: week > 1) {
                selectedWeek = WeekMath.clampWeek(week - 1, durationWeeks: program?.durationWeeks ?? week)
            }

            Text("WEEK \(week)")
                .font(TrainingType.label())
                .tracking(0.8)
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(minWidth: 68)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("Week \(week) of \(program?.durationWeeks ?? week)")

            weekArrow(systemName: "chevron.right", enabled: week < (program?.durationWeeks ?? week)) {
                selectedWeek = WeekMath.clampWeek(week + 1, durationWeeks: program?.durationWeeks ?? week)
            }

            Spacer(minLength: 8)

            Button {
                HapticManager.shared.play(.selection)
                showsCopyWeek = true
            } label: {
                HStack(spacing: 5) {
                    Text("Duplicate")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                    Image(systemName: "square.on.square")
                        .font(TrainingType.icon(11))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Duplicate week \(week)")
        }
    }

    private func weekArrow(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.play(.selection)
            action()
        } label: {
            Image(systemName: systemName)
                .font(TrainingType.icon(13, weight: .semibold))
                .foregroundColor(
                    enabled
                        ? Color.dynamicTextSecondary(theme: theme)
                        : Color.dynamicTextTertiary(theme: theme).opacity(0.4)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous week" : "Next week")
    }

    private var dayList: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.dayNumber) { index, day in
                dayRow(day)
                if index < days.count - 1 {
                    Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                }
            }
        }
    }

    private func dayRow(_ day: TrainingDay) -> some View {
        let weekDay = statusByDayNumber[day.dayNumber]
        let exerciseCount = day.exercises.isEmpty ? (weekDay?.exerciseCount ?? 0) : day.exercises.count

        return Button {
            HapticManager.shared.play(.selection)
            openEditor(for: day)
        } label: {
            HStack(spacing: 12) {
                Text(TrainingWeekday.shortName(forDayNumber: day.dayNumber))
                    .font(TrainingType.label())
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .frame(width: 38, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(day.isRest ? "Rest" : (day.name ?? weekDay?.name ?? "Session"))
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if !day.isRest, exerciseCount > 0 {
                        Text("\(exerciseCount) ex.")
                            .font(TrainingType.caption())
                            .monospacedDigit()
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                }

                Spacer(minLength: 8)

                statusLabel(day: day, weekDay: weekDay)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenDay(day: day, weekDay: weekDay, exerciseCount: exerciseCount))
        .accessibilityHint("Opens the day editor.")
        .accessibilityActions {
            Button("Edit day") { openEditor(for: day) }
        }
    }

    /// El estado nunca es solo un color: cada uno lleva su palabra y, el hecho, además su glifo.
    @ViewBuilder
    private func statusLabel(day: TrainingDay, weekDay: TrainingWeekDay?) -> some View {
        let status = weekDay?.status ?? (day.isRest ? .rest : (isCurrentWeek ? .pending : .pending))

        HStack(spacing: 5) {
            switch status {
            case .done:
                Text("Logged")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                Image(systemName: "checkmark")
                    .font(TrainingType.icon(10, weight: .semibold))
                    .foregroundColor(Color.dynamicAccentText(theme: theme))
            case .today:
                Text("Today")
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: theme))
            case .rest:
                Text(NumberFormat.placeholder)
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            case .skipped:
                Text("Missed")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            case .pending:
                Text(day.isRest ? NumberFormat.placeholder : "Planned")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func spokenDay(day: TrainingDay, weekDay: TrainingWeekDay?, exerciseCount: Int) -> String {
        let weekday = TrainingWeekday.name(forDayNumber: day.dayNumber)
        if day.isRest { return "\(weekday), rest day." }

        let title = day.name ?? weekDay?.name ?? "Session"
        var text = "\(weekday), \(title), \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
        switch weekDay?.status {
        case .done: text += ", logged"
        case .today: text += ", today"
        case .skipped: text += ", missed"
        default: text += ", planned"
        }
        return text + "."
    }

    private func openEditor(for day: TrainingDay) {
        guard let programId = program?.id else { return }
        sheet = .dayEditor(programId: programId, dayNumber: day.dayNumber, client: client)
    }

    // MARK: - Acciones de abajo

    private var bottomActions: some View {
        HStack(spacing: 10) {
            outlineButton(title: "Note for today") {
                sheet = .dayNote(client: client, date: WeekMath.today(in: .current))
            }

            outlineButton(title: "Review last log", enabled: lastLogId != nil) {
                if let lastLogId { onOpenLog(lastLogId) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.dynamicBackground(theme: theme).opacity(0.96))
    }

    private func outlineButton(title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.play(.selection)
            action()
        } label: {
            Text(title)
                .font(TrainingType.caption())
                .fontWeight(.semibold)
                .foregroundColor(
                    enabled ? Color.dynamicText(theme: theme) : Color.dynamicTextTertiary(theme: theme)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(
                    Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Vacío y pasados

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(client.firstName) has no program yet.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.shared.play(.medium)
                sheet = .assignProgram(client: client)
            } label: {
                Text("Assign program")
                    .font(TrainingType.headline())
                    .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
            }
            .buttonStyle(.plain)
        }
        .trainingCard(theme: theme)
    }

    @ViewBuilder
    private var pastPrograms: some View {
        let past = trainingService.clientPrograms?.past ?? []
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                TrainingEyebrow(text: "Past")

                ForEach(past) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.program.name)
                            .font(TrainingType.headline())
                            .foregroundColor(Color.dynamicText(theme: theme))
                            .lineLimit(1)

                        Text(pastSubtitle(item))
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .trainingCard(theme: theme)
        }
    }

    private func pastSubtitle(_ item: ClientProgramSummary) -> String {
        let start = item.assignment.startDate.startOfDay(in: .current)
        var text = TrainingFormat.dayMonth(start)
        if let end = item.assignment.endDate {
            text += " – \(TrainingFormat.dayMonth(end.startOfDay(in: .current)))"
        }
        return text
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                TrainingSkeletonBar(width: 70, height: 10)
                TrainingSkeletonBar(width: 200, height: 20)
                TrainingSkeletonBar(width: 160, height: 12)
                TrainingSkeletonBar(height: 4)
            }
            .trainingCard(theme: theme)

            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 12) {
                        TrainingSkeletonBar(width: 38, height: 12)
                        TrainingSkeletonBar(width: 120, height: 14)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
            }
            .trainingCard(theme: theme, padding: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading \(client.firstName)'s programs")
    }

    // MARK: - Hojas

    @ViewBuilder
    private func sheetView(_ item: TrainerTrainingSheet) -> some View {
        switch item {
        case .dayEditor(let programId, let dayNumber, let editorClient):
            DayEditorView(
                day: days.first { $0.dayNumber == dayNumber },
                programId: programId,
                dayNumber: dayNumber,
                client: editorClient,
                onSaved: { Task { await load() } }
            )
            .environmentObject(themeManager)
            .environmentObject(trainingService)

        case .dayNote(let noteClient, let date):
            DayNoteSheet(client: noteClient, date: date)
                .environmentObject(themeManager)
                .environmentObject(trainingService)

        case .assignProgram(let assignClient):
            AssignProgramSheet(client: assignClient, onAssigned: { Task { await load() } })
                .environmentObject(themeManager)
                .environmentObject(trainingService)

        }
    }

    // MARK: - Datos

    private func load() async {
        await trainingService.fetchClientPrograms(userId: client.id)
        async let logs: Void = trainingService.fetchClientLogs(userId: client.id, limit: 5)
        async let days: Void = reloadWeek()
        _ = await (logs, days)
    }

    private func reloadWeek() async {
        guard let programId = program?.id else { return }
        await trainingService.fetchProgramDays(programId: programId, week: week)
    }
}
