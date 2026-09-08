//
//  ClientDetailView.swift
//  Gym_API
//
//  Ficha de cliente del entrenador (plan §8.2).
//
//  Hasta ahora la app del entrenador no tenía detalle de cliente: la lista era el final del
//  camino. Esta pantalla es la puerta a todo lo demás del módulo —el programa, los registros, la
//  nota del día— y por eso lo primero que enseña es la persona, no una tabla.
//
//  Qué se pinta y de dónde sale:
//
//  - Programa activo: `GET /clients/{id}/programs`. Es un resumen; el detalle está en S20.
//  - Registros recientes: `GET /clients/{id}/logs`, con el estado de revisión, que es lo que
//    convierte la lista en una cola de trabajo y no en un archivo.
//  - Check-ins: los que ya carga `CoachingService` para el panel, filtrados por esta persona.
//    No se pide nada nuevo: el dato ya está en memoria.
//

import SwiftUI
import TrainingCore

struct ClientDetailView: View {

    let client: TrainingClientRef
    /// Lleva a la pestaña de mensajes, que es donde vive el chat.
    var onMessage: () -> Void = {}
    var onOpenPrograms: () -> Void = {}
    var onOpenLog: (Int) -> Void = { _ in }

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var coachingService: CoachingService

    @State private var sheet: TrainerTrainingSheet?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    private var summary: ClientProgramSummary? { trainingService.clientPrograms?.active }

    private var checkIns: [ClientCheckIn] {
        coachingService.recentCheckIns.filter { $0.client.id == client.id }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                programSection
                logsSection
                checkInsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 60)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $sheet) { item in
            sheetView(item)
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(TrainingType.title2())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticManager.shared.play(.selection)
                    onMessage()
                } label: {
                    Text("Message")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your chat with \(client.firstName).")
            }

            Spacer(minLength: 0)
        }
    }

    private var avatar: some View {
        Group {
            if let picture = client.pictureURL, !picture.isEmpty {
                OptimizedAsyncImage(
                    url: picture,
                    displaySize: CGSize(width: 56, height: 56),
                    placeholder: { AnyView(initialsCircle) },
                    errorView: { AnyView(initialsCircle) }
                )
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                initialsCircle
            }
        }
        .accessibilityHidden(true)
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(client.initials)
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
        .frame(width: 56, height: 56)
    }

    // MARK: - Programas

    private var programSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Programs")

            if trainingService.clientPrograms != nil {
                if let summary {
                    activeCard(summary)
                } else {
                    noProgramCard
                }
            } else if trainingService.clientProgramsState == .failed {
                TrainingRetryRow(
                    message: "Couldn't load the program.",
                    retryTitle: "Retry",
                    onRetry: { Task { await trainingService.fetchClientPrograms(userId: client.id) } }
                )
                .trainingCard(theme: theme)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TrainingSkeletonBar(width: 180, height: 18)
                    TrainingSkeletonBar(width: 140, height: 12)
                    TrainingSkeletonBar(height: 4)
                }
                .trainingCard(theme: theme)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading programs")
            }
        }
    }

    private func activeCard(_ summary: ClientProgramSummary) -> some View {
        Button {
            HapticManager.shared.play(.selection)
            onOpenPrograms()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary.program.name)
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(TrainingType.icon(11, weight: .semibold))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }

                Text(subtitle(summary))
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let adherence = summary.adherencePct {
                    adherenceBar(adherence, isLow: summary.isAdherenceLow)
                }

                if let missed = summary.missedText {
                    Text(missed)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            }
            .trainingCard(theme: theme)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenProgram(summary))
        .accessibilityHint("Opens the weekly plan.")
        .accessibilityAddTraits(.isButton)
    }

    private func subtitle(_ summary: ClientProgramSummary) -> String {
        var parts: [String] = []
        if let week = summary.currentWeek {
            parts.append("Week \(week) of \(summary.program.durationWeeks)")
        } else {
            parts.append("\(summary.program.durationWeeks) weeks")
        }
        if let block = summary.currentBlock { parts.append(block.name) }
        return parts.joined(separator: " · ")
    }

    private func spokenProgram(_ summary: ClientProgramSummary) -> String {
        var text = "\(summary.program.name). \(subtitle(summary))."
        if let adherence = summary.adherencePct {
            text += " Adherence \(NumberFormat.trimmedDecimal(adherence)) percent."
        }
        if let missed = summary.missedText { text += " \(missed)." }
        return text
    }

    private func adherenceBar(_ adherence: Double, isLow: Bool) -> some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dynamicBorder(theme: theme).opacity(0.35))
                    Capsule()
                        .fill(Color.dynamicAccent(theme: theme))
                        .frame(width: geo.size.width * min(max(0, adherence / 100), 1))
                }
            }
            .frame(height: 4)

            Text("Adherence \(NumberFormat.trimmedDecimal(adherence))%")
                .font(TrainingType.caption())
                .monospacedDigit()
                .foregroundColor(isLow ? Color.dynamicWarningText(theme: theme) : Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var noProgramCard: some View {
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

    // MARK: - Registros recientes

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Recent logs")

            if trainingService.clientLogsState == .failed && trainingService.clientLogs.isEmpty {
                TrainingRetryRow(
                    message: "Couldn't load the recent logs.",
                    retryTitle: "Retry",
                    onRetry: { Task { await trainingService.fetchClientLogs(userId: client.id, limit: 10) } }
                )
                .trainingCard(theme: theme)
            } else if trainingService.clientLogsState == .idle || trainingService.clientLogsState == .loading,
                      trainingService.clientLogs.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                TrainingSkeletonBar(width: 140, height: 14)
                                TrainingSkeletonBar(width: 180, height: 11)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 56)
                    }
                }
                .trainingCard(theme: theme, padding: 14)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading recent logs")
            } else {
                if trainingService.clientLogs.isEmpty {
                    Text("\(client.firstName) hasn't logged a session yet.")
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                        .trainingCard(theme: theme)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(trainingService.clientLogs.enumerated()), id: \.element.id) { index, log in
                            TrainerLogRow(log: log, unit: unit, showsName: false) {
                                onOpenLog(log.id)
                            }
                            if index < trainingService.clientLogs.count - 1 {
                                Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                            }
                        }
                    }
                    .trainingCard(theme: theme, padding: 14)
                }
            }
        }
    }

    // MARK: - Check-ins

    @ViewBuilder
    private var checkInsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Check-ins")

            if checkIns.isEmpty {
                Text("No check-ins from \(client.firstName) this week.")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
                    .trainingCard(theme: theme)
            } else {
                ForEach(checkIns) { item in
                    checkInCard(item)
                }
            }
        }
    }

    private func checkInCard(_ item: ClientCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week of \(TrainingFormat.dayMonth(item.checkIn.weekStart))")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Spacer(minLength: 8)

                if let kilograms = item.checkIn.weight {
                    Text(unit.loadLabel(kilograms: kilograms))
                        .font(TrainingType.monoS())
                        .monospacedDigit()
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }

            if let note = item.checkIn.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text("“\(note)”")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                scalePill("Energy", item.checkIn.energy, lowIsBad: true)
                scalePill("Sleep", item.checkIn.sleep, lowIsBad: true)
                scalePill("Soreness", item.checkIn.soreness, lowIsBad: false)
            }
        }
        .trainingCard(theme: theme, padding: 14)
        .accessibilityElement(children: .combine)
    }

    /// Lo que merece un vistazo lleva el mismo `▲` que las desviaciones de S22.
    ///
    /// La cifra y la palabra están siempre, pero eso no basta: «Sleep 2» y «Sleep 4» se escriben
    /// igual, y lo que distingue a uno del otro —que este merece que preguntes— viajaba SOLO en
    /// el color, tanto en pantalla como en VoiceOver, que decía «Sleep 2 out of 5» y nada más.
    /// Es el punto 5 del checklist, el mismo que obliga a que `▲` nunca vaya solo en S22: aquí
    /// pasaba lo contrario, que la palabra iba sin el triángulo.
    @ViewBuilder
    private func scalePill(_ label: String, _ value: Int?, lowIsBad: Bool) -> some View {
        if let value {
            let alert = lowIsBad ? value <= 2 : value >= 4
            HStack(spacing: 4) {
                if alert {
                    Image(systemName: "triangle.fill")
                        .font(TrainingType.icon(8, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(TrainingType.label())
                Text("\(value)")
                    .font(TrainingType.monoS())
                    .monospacedDigit()
            }
            .foregroundColor(alert ? Color.dynamicWarningText(theme: theme) : Color.dynamicTextSecondary(theme: theme))
            .padding(.horizontal, 9)
            .frame(minHeight: 28)
            .background(
                Capsule().fill(
                    alert
                        ? Color.dynamicWarningText(theme: theme).opacity(0.14)
                        : Color.dynamicSurface2(theme: theme)
                )
            )
            .accessibilityLabel(
                alert
                    ? "\(label) \(value) out of 5, worth a look"
                    : "\(label) \(value) out of 5"
            )
        }
    }

    // MARK: - Hojas

    @ViewBuilder
    private func sheetView(_ item: TrainerTrainingSheet) -> some View {
        switch item {
        case .assignProgram(let assignClient):
            AssignProgramSheet(client: assignClient, onAssigned: { Task { await load() } })
                .environmentObject(themeManager)
                .environmentObject(trainingService)
        case .dayNote(let noteClient, let date):
            DayNoteSheet(client: noteClient, date: date)
                .environmentObject(themeManager)
                .environmentObject(trainingService)
        case .dayEditor:
            EmptyView()
        }
    }

    // MARK: - Datos

    private func load() async {
        async let programs: Void = trainingService.fetchClientPrograms(userId: client.id)
        async let logs: Void = trainingService.fetchClientLogs(userId: client.id, limit: 10)
        _ = await (programs, logs)

        // Los check-ins ya los carga el panel; si aún no se han pedido en esta sesión, se piden.
        if coachingService.recentCheckIns.isEmpty && coachingService.checkInsState != .loading {
            await coachingService.loadRecentCheckIns()
        }
    }
}

// MARK: - Fila de registro

/// Una sesión registrada, tal y como la ve el entrenador: qué fue, cuánto, y si ya la miró.
///
/// La comparten la ficha del cliente y el buzón «To review» del panel, que enseñan lo mismo con
/// la única diferencia del nombre de quien entrenó.
struct TrainerLogRow: View {

    let log: TrainingWorkoutLogSummary
    let unit: WeightUnit
    /// El buzón mezcla clientes y necesita el nombre; la ficha de uno solo, no.
    var showsName: Bool = true
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        Button {
            HapticManager.shared.play(.selection)
            action()
        } label: {
            content
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint("Opens the session.")
        .accessibilityAddTraits(.isButton)
    }

    /// A tamaños de accesibilidad la fila se apila: en horizontal, «9,566 lb» se queda en
    /// «9,566…» y la unidad —que es la mitad del dato— desaparece.
    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.stacksTrainerRows {
            VStack(alignment: .leading, spacing: 6) {
                titleLine
                metricsLine
                statusLabel
            }
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    titleLine
                    metricsLine
                }
                Spacer(minLength: 8)
                statusLabel
            }
        }
    }

    private var titleLine: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(dynamicTypeSize.stacksTrainerRows ? 2 : 1)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.8)

            if log.prCount > 0 {
                PRBadge(isConfirmed: true, showsText: false)
            }
        }
    }

    private var metricsLine: some View {
        Text(metrics)
            .font(TrainingType.monoS())
            .monospacedDigit()
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .lineLimit(dynamicTypeSize.stacksTrainerRows ? 3 : 1)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// «To review» / «Reviewed» es texto, no un punto de color.
    private var statusLabel: some View {
        Text(log.isReviewed ? "Reviewed" : "To review")
            .font(TrainingType.caption())
            .fontWeight(log.isReviewed ? .regular : .semibold)
            .foregroundColor(
                log.isReviewed
                    ? Color.dynamicTextTertiary(theme: theme)
                    : Color.dynamicText(theme: theme)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var title: String {
        if showsName, let name = log.userName, !name.isEmpty {
            return "\(name.components(separatedBy: " ").first ?? name) · \(log.title)"
        }
        return log.title
    }

    private var metrics: String {
        var parts: [String] = []
        if let date = log.completedAt { parts.append(TrainingFormat.shortDate(date)) }
        parts.append("\(log.totalSets) set\(log.totalSets == 1 ? "" : "s")")
        parts.append(unit.volumeLabel(kilograms: log.totalVolumeKg))
        if log.isPartial { parts.append("partial") }
        return parts.joined(separator: " · ")
    }

    private var spoken: String {
        var text = "\(title). "
        if let date = log.completedAt { text += "\(TrainingFormat.shortDate(date)). " }
        text += "\(log.totalSets) sets, \(unit.volumeLabel(kilograms: log.totalVolumeKg)) of volume."
        if log.prCount > 0 {
            text += " \(log.prCount) personal record\(log.prCount == 1 ? "" : "s")."
        }
        if log.isPartial { text += " Partial session." }
        text += log.isReviewed ? " Reviewed." : " To review."
        return text
    }
}
