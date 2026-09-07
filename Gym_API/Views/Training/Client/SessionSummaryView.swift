//
//  SessionSummaryView.swift
//  Gym_API
//
//  S18 · Session summary (UX §5).
//
//  Es la pantalla donde el módulo puede mentir más fácil, así que aquí está la regla que lo
//  impide: mientras el registro no haya llegado al servidor, la tarjeta dice «Best set so far».
//  Cuando `trainingLogSynced` avisa de que el servidor lo confirmó, y solo entonces, pasa a
//  «Personal record» con la celebración de nivel 2 — una sola vez (plan §4.5, UX §7).
//
//  Compartir es secundario y explícito: dos botones de contorno bajo el CTA, nunca preactivados,
//  y ocultos si el espacio no tiene los módulos de historias y publicaciones (UX §7.2).
//

import SwiftUI
import TrainingCore

struct SessionSummaryView: View {

    enum Source: Equatable {
        /// Recién terminada: los datos son los locales, sin confirmar.
        case finished(WorkoutSession)
        /// Modo lectura: se lee del servidor.
        case log(id: Int)
    }

    let source: Source
    let onClose: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var gymService: GymService

    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var log: TrainingWorkoutLog?
    @State private var feeling: Int?
    @State private var note: String = ""
    @State private var showsNoteEditor = false
    @State private var showsStoryShare = false
    @State private var showsFeedShare = false
    @State private var countProgress: Double = 0
    @State private var didAnnounce = false
    @AccessibilityFocusState private var titleFocused: Bool

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    // MARK: - Datos derivados

    private var session: WorkoutSession? {
        if case .finished(let session) = source { return session }
        return nil
    }

    private var title: String {
        log?.title ?? session?.title ?? "Session"
    }

    private var completedAt: Date? {
        log?.completedAt ?? session?.startedAt
    }

    private var durationSeconds: Int {
        if let log, let duration = log.durationSeconds { return duration }
        if let session { return session.durationSeconds(at: Date()) }
        return 0
    }

    private var totalSets: Int { log?.totalSets ?? session?.completedSetCount ?? 0 }
    private var totalVolumeKg: Double { log?.totalVolumeKg ?? session?.totalVolumeKg ?? 0 }
    private var averageRPE: Double? { log?.sessionRPE ?? session?.averageRPE }
    private var isPartial: Bool { log?.isPartial ?? session?.isPartial ?? false }

    /// El servidor ya confirmó este registro.
    private var isConfirmed: Bool { log != nil }

    private var celebration: PersonalRecordCelebration? {
        if let log, let record = log.topPersonalRecord {
            return Celebration.forConfirmedRecord(
                exerciseName: record.exerciseName,
                weightKg: record.weightKg,
                reps: record.reps,
                e1rmKg: record.e1rmKg,
                deltaKg: nil,
                isFirstRecord: record.prKind == .first,
                previousBestKg: nil,
                unit: unit.trainingUnit
            )
        }
        if let session, let best = session.bestSetsSoFar.max(by: { !$0.isBetter(than: $1) }) {
            let name = session.exercises.first { $0.exerciseKey == best.exerciseKey }?.exerciseName ?? best.exerciseKey
            return Celebration.forLocalBestSet(exerciseName: name, best: best, unit: unit.trainingUnit)
        }
        return nil
    }

    private var canShare: Bool { networkMonitor.isConnected }
    private var storiesEnabled: Bool { gymService.isModuleEnabled("stories") == true }
    private var postsEnabled: Bool { gymService.isModuleEnabled("posts") == true }
    private var showsShareSection: Bool { storiesEnabled || postsEnabled }

    private var isReadOnly: Bool {
        if case .log = source { return true }
        return false
    }

    // MARK: - Cuerpo

    var body: some View {
        ZStack {
            Color.dynamicBackground(theme: theme).ignoresSafeArea()

            VStack(spacing: 0) {
                closeBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        metrics

                        if let celebration {
                            RecordCelebrationCard(
                                celebration: celebration,
                                playsCelebration: !isReadOnly,
                                onShare: showsShareSection && canShare ? { showsStoryShare = true } : nil
                            )
                        }

                        if !isReadOnly {
                            feelingScale
                            noteButton
                        } else if let notes = log?.notes, !notes.isEmpty {
                            readOnlyNote(notes)
                        }

                        if showsShareSection {
                            shareSection
                        }

                        doneButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .task { await load() }
        .onAppear(perform: startCounting)
        .onReceive(NotificationCenter.default.publisher(for: .trainingLogSynced)) { notification in
            guard case .finished(let session) = source else { return }
            guard let id = notification.object as? Int else { return }
            Task {
                // El servidor acaba de confirmar un registro. Si es el nuestro, la pantalla pasa
                // de «Best set so far» a «Personal record» sin que nadie tenga que recargar.
                if let fetched = await trainingService.fetchLog(id),
                   fetched.clientUUID == session.clientUUID {
                    log = fetched
                }
            }
        }
        .sheet(isPresented: $showsNoteEditor) {
            SessionNoteSheet(text: $note) { text in
                note = text
                persistFeedbackIfNeeded()
            }
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showsStoryShare) {
            WorkoutStoryShareSheet(
                exerciseName: celebration?.headline,
                topRecord: log?.topPersonalRecord,
                session: session,
                log: log,
                unit: unit
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showsFeedShare) {
            CreatePostView(taggedWorkoutLogId: log?.id)
                .environmentObject(themeManager)
        }
    }

    // MARK: - Barra de cierre

    private var closeBar: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Text("Close")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Cabecera

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(TrainingType.display())
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($titleFocused)

            if let completedAt {
                Text("\(TrainingFormat.longDate(completedAt)) · \(TrainingFormat.duration(durationSeconds))")
                    .font(TrainingType.subhead())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }

            if isPartial {
                Text("Partial session saved")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .padding(.top, 2)
            }

            if !isConfirmed {
                TrainingSyncChip(compact: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Métricas

    private var metrics: some View {
        HStack(alignment: .top, spacing: 12) {
            TrainingMetricView(
                value: counted("\(totalSets)", value: Double(totalSets)),
                label: "sets",
                large: true,
                spoken: "\(totalSets) sets"
            )
            TrainingMetricView(
                value: unit.volumeLabel(kilograms: totalVolumeKg * countProgress),
                label: "volume",
                large: true,
                spoken: "\(unit.volumeLabel(kilograms: totalVolumeKg)) of volume"
            )
            TrainingMetricView(
                value: averageRPE.map { Celebration.number($0 * countProgress) } ?? NumberFormat.placeholder,
                label: "avg RPE",
                large: true,
                spoken: averageRPE.map { "Average RPE \(Celebration.number($0))" } ?? "Average RPE not recorded"
            )
        }
    }

    /// Conteo desde cero de UX §5. Con Reduce Motion `countProgress` arranca en 1 y no hay conteo.
    private func counted(_ text: String, value: Double) -> String {
        guard countProgress < 1 else { return text }
        return Celebration.number((value * countProgress).rounded())
    }

    private func startCounting() {
        guard countProgress == 0 else { return }
        if reduceMotion || isReadOnly {
            countProgress = 1
        } else {
            withAnimation(.easeOut(duration: 0.5)) { countProgress = 1 }
        }

        guard !didAnnounce else { return }
        didAnnounce = true
        HapticManager.shared.play(.success)
        titleFocused = true
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private var announcement: String {
        var text = "Session complete. \(totalSets) sets, \(unit.volumeLabel(kilograms: totalVolumeKg))"
        if let log, log.prCount > 0 {
            text += ", \(log.prCount) personal record\(log.prCount == 1 ? "" : "s")"
        }
        return text + "."
    }

    // MARK: - Sensación

    private var feelingScale: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How did that feel?")
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicText(theme: theme))

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button(action: {
                        HapticManager.shared.play(.selection)
                        feeling = value
                        persistFeedbackIfNeeded()
                    }) {
                        Text("\(value)")
                            .font(TrainingType.monoM())
                            .monospacedDigit()
                            .foregroundColor(
                                feeling == value
                                    ? Color.dynamicText(theme: theme)
                                    : Color.dynamicTextSecondary(theme: theme)
                            )
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14).fill(
                                    feeling == value ? Color.dynamicSurface2(theme: theme) : Color.clear
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(
                                    Color.dynamicBorder(theme: theme).opacity(feeling == value ? 0.5 : 0.2),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("How did that feel?")
            .accessibilityValue(feelingValueText)
            .accessibilityAdjustableAction { direction in
                let current = feeling ?? 3
                let updated = direction == .increment ? min(5, current + 1) : max(1, current - 1)
                feeling = updated
                persistFeedbackIfNeeded()
            }
        }
    }

    private var feelingValueText: String {
        guard let feeling else { return "Not set" }
        let words = [1: "very easy", 2: "easy", 3: "moderate", 4: "hard", 5: "very hard"]
        return "\(feeling) of 5, \(words[feeling] ?? "")"
    }

    // MARK: - Nota

    private var noteButton: some View {
        Button(action: { showsNoteEditor = true }) {
            HStack {
                Text(note.isEmpty ? noteTitle : note)
                    .font(TrainingType.body())
                    .foregroundColor(
                        note.isEmpty
                            ? Color.dynamicTextTertiary(theme: theme)
                            : Color.dynamicText(theme: theme)
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.dynamicBorder(theme: theme).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(noteTitle)
        .accessibilityValue(note.isEmpty ? "Empty" : note)
    }

    private var noteTitle: String {
        guard let coach = trainingService.coach?.name.components(separatedBy: " ").first else {
            return "Add a note for your coach"
        }
        return "Add a note for \(coach)"
    }

    private func readOnlyNote(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TrainingEyebrow(text: "Your note")
            Text("“\(text)”")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Compartir

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Share")

            HStack(spacing: 10) {
                if storiesEnabled {
                    shareButton(title: "To story") {
                        Analytics.track(Analytics.Event.shareStory, [
                            Analytics.Property.logId: log?.id ?? -1
                        ])
                        showsStoryShare = true
                    }
                }
                if postsEnabled {
                    shareButton(title: "To feed") {
                        Analytics.track(Analytics.Event.shareFeed, [
                            Analytics.Property.logId: log?.id ?? -1
                        ])
                        showsFeedShare = true
                    }
                }
                Spacer(minLength: 0)
            }

            if !canShare {
                Text("Sharing needs a connection.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
    }

    private func shareButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.play(.light)
            action()
        }) {
            Text(title)
                .font(TrainingType.caption())
                .fontWeight(.semibold)
                .foregroundColor(Color.dynamicText(theme: theme))
                .padding(.horizontal, 22)
                .frame(minHeight: 46)
                .overlay(
                    Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canShare)
        .opacity(canShare ? 1 : 0.5)
        .accessibilityLabel("Share \(title.lowercased())")
    }

    // MARK: - Done

    private var doneButton: some View {
        Button(action: {
            HapticManager.shared.play(.light)
            persistFeedbackIfNeeded()
            onClose()
        }) {
            Text("Done")
                .font(TrainingType.headline())
                .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
    }

    // MARK: - Carga y guardado

    private func load() async {
        await gymService.loadCurrentGymModulesIfNeeded()

        switch source {
        case .log(let id):
            log = await trainingService.fetchLog(id)
            feeling = log?.feeling
            note = log?.notes ?? ""
        case .finished(let session):
            feeling = session.feeling
            note = session.notes ?? ""
        }
    }

    /// La sensación y la nota se vuelven a encolar: un registro cerrado solo admite después
    /// cambios de `notes`, `feeling` y `session_rpe` (plan §6.4), y el upsert por `client_uuid`
    /// hace que reenviar sea seguro.
    private func persistFeedbackIfNeeded() {
        guard case .finished(var session) = source else { return }
        session.feeling = feeling
        session.notes = note.isEmpty ? nil : note
        Task {
            await syncCoordinator.enqueue(session, status: .completed)
        }
    }
}
