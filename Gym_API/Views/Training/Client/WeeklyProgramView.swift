//
//  WeeklyProgramView.swift
//  Gym_API
//
//  S12 · Weekly program (UX §5).
//
//  La semana se cambia con flechas Y con swipe. Nunca solo con gesto: un gesto oculto es una
//  función que no existe para quien navega con VoiceOver o con Control por botón (UX §5, S12).
//

import SwiftUI
import TrainingCore

struct WeeklyProgramView: View {

    /// Semana inicial. Nula abre la que esté en curso según `/me/program`.
    let initialWeek: Int?
    let onOpenDay: (Int) -> Void
    let onStartSession: (Int) -> Void
    let onMessageCoach: () -> Void
    let onChangeUnits: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var selectedWeek: Int?
    @State private var showsProgramDetails = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var program: TrainingProgram? { trainingService.myProgram?.program }
    private var totalWeeks: Int { max(program?.durationWeeks ?? 1, 1) }
    private var week: TrainingWeek? { trainingService.week }

    private var currentWeekNumber: Int {
        selectedWeek ?? trainingService.myProgram?.current?.weekNumber ?? 1
    }

    private var block: TrainingBlock? {
        guard let blocks = trainingService.myProgram?.current?.block else { return nil }
        return blocks.contains(week: currentWeekNumber) ? blocks : nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if trainingService.hasActiveProgram {
                    programHeader
                    weekSwitcher
                    dayList
                } else if trainingService.programState == .loading {
                    loading
                } else if trainingService.programState == .failed {
                    errorState
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Change units", action: onChangeUnits)
                    Button("Program details") { showsProgramDetails = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .trainingTouchTarget()
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showsProgramDetails) {
            ProgramDetailsSheet(program: program, assignment: trainingService.myProgram?.assignment)
        }
        .task {
            if selectedWeek == nil { selectedWeek = initialWeek }
            await loadWeek(currentWeekNumber)
        }
        .refreshable {
            await trainingService.fetchMyProgram()
            await loadWeek(currentWeekNumber)
        }
    }

    // MARK: - Cabecera

    private var programHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(program?.name ?? "Your program")
                .font(TrainingType.title1())
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                GeometryReader { geo in
                    let fraction = min(1, Double(currentWeekNumber) / Double(totalWeeks))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.dynamicSurface2(theme: theme))
                        Capsule()
                            .fill(Color.dynamicAccent(theme: theme))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 4)

                Text("Week \(currentWeekNumber) of \(totalWeeks)")
                    .font(TrainingType.caption())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Week \(currentWeekNumber) of \(totalWeeks)")
        }
    }

    // MARK: - Cambio de semana

    private var weekSwitcher: some View {
        HStack(spacing: 8) {
            Button(action: { move(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .trainingTouchTarget()
            }
            .buttonStyle(.plain)
            .disabled(currentWeekNumber <= 1)
            .accessibilityLabel("Previous week")

            Text(blockTitle)
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)

            Button(action: { move(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .trainingTouchTarget()
            }
            .buttonStyle(.plain)
            .disabled(currentWeekNumber >= totalWeeks)
            .accessibilityLabel("Next week")
        }
        .padding(.vertical, 4)
        .trainingCard(theme: theme, padding: 8)
    }

    private var blockTitle: String {
        guard let block else { return "WEEK \(currentWeekNumber)" }
        let number = max(1, block.orderIndex + 1)
        return "BLOCK \(number) · \(block.name.uppercased()) · WEEKS \(block.weekStart)–\(block.weekEnd)"
    }

    private func move(by delta: Int) {
        let target = currentWeekNumber + delta
        guard target >= 1, target <= totalWeeks else {
            HapticManager.shared.boundaryReached()
            return
        }
        HapticManager.shared.play(.selection)
        selectedWeek = target
        Task { await loadWeek(target) }
    }

    // MARK: - Días

    private var dayList: some View {
        VStack(spacing: 0) {
            if trainingService.weekState == .loading && week == nil {
                loading
            } else if trainingService.weekState == .failed && week == nil {
                errorState
            } else if let week {
                ForEach(Array(week.days.enumerated()), id: \.element.dayNumber) { index, day in
                    DayRow(
                        day: day,
                        onOpen: { if let id = day.dayId { onOpenDay(id) } },
                        onStart: { if let id = day.dayId { onStartSession(id) } }
                    )
                    if index < week.days.count - 1 {
                        Divider()
                            .background(Color.dynamicBorder(theme: theme).opacity(0.15))
                    }
                }
            }
        }
        .trainingCard(theme: theme, padding: 0)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    move(by: value.translation.width < 0 ? 1 : -1)
                }
        )
        .animation(reduceMotion ? .easeInOut(duration: 0.12) : .interactiveSpring(response: 0.28), value: currentWeekNumber)
    }

    // MARK: - Estados

    private var loading: some View {
        VStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    TrainingSkeletonBar(width: 54, height: 12)
                    TrainingSkeletonBar(width: 120, height: 14)
                    Spacer()
                    TrainingSkeletonBar(width: 40, height: 12)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your program")
    }

    private var errorState: some View {
        TrainingRetryRow(
            message: "Couldn't load your program.",
            retryTitle: "Retry",
            onRetry: {
                Task {
                    await trainingService.fetchMyProgram()
                    await loadWeek(currentWeekNumber)
                }
            }
        )
        .trainingCard(theme: theme)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your coach hasn't published a program yet.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onMessageCoach) {
                Text(messageCoachTitle)
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

    private var messageCoachTitle: String {
        guard let name = trainingService.coach?.name.components(separatedBy: " ").first else {
            return "Message your coach"
        }
        return "Message \(name)"
    }

    // MARK: - Carga

    private func loadWeek(_ number: Int) async {
        await trainingService.fetchWeek(number)
    }
}

// MARK: - Fila de un día

private struct DayRow: View {

    let day: TrainingWeekDay
    let onOpen: () -> Void
    let onStart: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var dayLabel: String {
        guard let date = day.date else { return "" }
        let weekday = DateFormatter.localized(template: "EEE")
            .string(from: date.startOfDay(in: .current))
            .uppercased()
        return "\(weekday) \(date.day)"
    }

    private var preview: String? {
        guard !day.exercisePreview.isEmpty else { return nil }
        let shown = day.exercisePreview.prefix(3).joined(separator: " · ")
        let rest = day.exerciseCount - min(3, day.exercisePreview.count)
        return rest > 0 ? "\(shown) · \(rest) more" : shown
    }

    var body: some View {
        Button(action: { if day.dayId != nil { onOpen() } }) {
            HStack(alignment: .top, spacing: 12) {
                Text(dayLabel)
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .frame(width: 62, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(day.isRest ? "Rest" : (day.name ?? "Session"))
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)

                    if let preview, !day.isRest {
                        Text(preview)
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                            .lineLimit(1)
                    }

                    if day.status == .today, day.dayId != nil {
                        startButton
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 8)

                statusBadge
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(day.status == .today ? Color.dynamicSurface2(theme: theme) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day.dayId == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(day.dayId == nil ? "" : "Opens the day.")
        .accessibilityAction(named: Text("Start session")) {
            if day.status == .today, day.dayId != nil { onStart() }
        }
    }

    private var startButton: some View {
        Button(action: {
            HapticManager.shared.play(.light)
            onStart()
        }) {
            Text("Start")
                .font(TrainingType.caption())
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start session")
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch day.status {
        case .done:
            HStack(spacing: 4) {
                Text("Done")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
            }
        case .today:
            Text("Today")
                .font(TrainingType.caption())
                .fontWeight(.semibold)
                .foregroundColor(Color.dynamicText(theme: theme))
        case .skipped:
            Text("Not logged")
                .font(TrainingType.caption())
                .foregroundColor(Color.warningYellow)
        case .rest, .pending:
            EmptyView()
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let date = day.date {
            let weekday = DateFormatter.localized(template: "EEEE")
                .string(from: date.startOfDay(in: .current))
            parts.append("\(weekday) \(date.day).")
        }
        parts.append(day.isRest ? "Rest." : "\(day.name ?? "Session").")
        switch day.status {
        case .today: parts.append("Today.")
        case .done: parts.append("Done.")
        case .skipped: parts.append("Not logged.")
        case .pending: parts.append("Planned.")
        case .rest: break
        }
        if !day.isRest, day.exerciseCount > 0 {
            parts.append("\(day.exerciseCount) exercises.")
        }
        if day.status != .done && !day.isRest {
            parts.append("Not started.")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Detalles del programa

private struct ProgramDetailsSheet: View {

    let program: TrainingProgram?
    let assignment: TrainingAssignment?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let name = program?.name {
                        Text(name)
                            .font(TrainingType.title2())
                            .foregroundColor(Color.dynamicText(theme: theme))
                    }
                    if let description = program?.description, !description.isEmpty {
                        Text(description)
                            .font(TrainingType.body())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let weeks = program?.durationWeeks {
                        detailRow(label: "Length", value: "\(weeks) weeks")
                    }
                    if let goal = program?.goal, !goal.isEmpty {
                        detailRow(label: "Goal", value: goal.capitalized)
                    }
                    if let start = assignment?.startDate {
                        detailRow(
                            label: "Started",
                            value: TrainingFormat.dayMonth(start.startOfDay(in: .current))
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Program details")
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

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            Spacer()
            Text(value)
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicText(theme: theme))
        }
        .accessibilityElement(children: .combine)
    }
}
