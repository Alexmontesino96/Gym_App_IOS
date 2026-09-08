//
//  LogReviewView.swift
//  Gym_API
//
//  S22 · Log review (UX §6).
//
//  Es la pantalla que justifica el push. Un entrenador abre un registro para responder a una
//  pregunta concreta —«¿dónde se salió de lo que le puse?»— y todo lo demás es contexto.
//
//  Tres decisiones que están en el código y conviene leer antes de tocarlo:
//
//  1. **Las desviaciones se calculan contra la prescripción que trae el propio registro**
//     (`GET /logs/{id}` devuelve `prescription`), no contra el programa de hoy. El programa pudo
//     cambiar desde entonces; comparar con el actual acusaría a la persona de no hacer algo que
//     nadie le pidió.
//  2. **`▲` nunca va solo.** Cada desviación lleva su palabra («above target», «below load») y su
//     etiqueta de VoiceOver con la cifra prescrita (checklist §10.5 y §10.18).
//  3. **`Congratulate` actúa en el momento**, como en el wireframe, y el comentario se envía
//     aparte. Son dos gestos distintos del entrenador y el contrato acepta los dos por separado;
//     unirlos en un solo envío obligaría a escribir un comentario para poder felicitar.
//

import SwiftUI
import TrainingCore

struct LogReviewView: View {

    let logId: Int
    /// Puede no conocerse: un deep link de push llega solo con el id del registro.
    let client: TrainingClientRef?
    /// Abre S15 en modo lectura sobre este cliente.
    var onOpenExerciseHistory: (String, String) -> Void = { _, _ in }

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var comment = ""
    @State private var isSending = false
    @State private var isCongratulating = false
    @State private var confirmation: String?
    @State private var showsParticles = false
    @State private var errorMessage: String?
    @FocusState private var isCommentFocused: Bool

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    private var log: TrainingWorkoutLog? {
        guard let log = trainingService.selectedLog, log.id == logId else { return nil }
        return log
    }

    /// El nombre con el que se habla en esta pantalla. Sin cliente conocido, el registro no dice
    /// «Sent to» a nadie en concreto.
    private var clientName: String { client?.firstName ?? "your client" }

    private var exercises: [ReviewedExercise] {
        guard let log else { return [] }
        return CoachReview.group(sets: log.sets, prescription: log.prescription)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let log {
                    header(log)
                    if let record = log.topPersonalRecord {
                        recordCard(log: log, record: record)
                    }
                    exerciseList
                    if let note = log.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                        clientNote(note)
                    }
                    if log.isReviewed, let previous = log.coachComment, !previous.isEmpty {
                        previousComment(previous, at: log.reviewedAt)
                    }
                } else if trainingService.errorMessage != nil {
                    TrainingRetryRow(
                        message: "Couldn't load this session.",
                        retryTitle: "Retry",
                        onRetry: { Task { await load() } }
                    )
                    .trainingCard(theme: theme)
                } else {
                    loading
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 90)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if log != nil {
                commentBar
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var navigationTitle: String {
        guard let log else { return "Session" }
        if let client { return "\(client.firstName) · \(log.title)" }
        return log.title
    }

    // MARK: - Cabecera

    private func header(_ log: TrainingWorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = log.completedAt {
                Text(TrainingFormat.shortDate(date))
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }

            Text(metricsLine(log))
                .font(TrainingType.monoS())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            if log.isPartial {
                Text("Partial session")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenMetrics(log))
    }

    /// «52:10 · 18 sets · 12,480 lb · avg RPE 7.8»
    private func metricsLine(_ log: TrainingWorkoutLog) -> String {
        var parts: [String] = []
        if let seconds = log.durationSeconds { parts.append(TrainingFormat.duration(seconds)) }
        parts.append("\(log.totalSets) set\(log.totalSets == 1 ? "" : "s")")
        parts.append(unit.volumeLabel(kilograms: log.totalVolumeKg))
        if let rpe = averageRPE(log) { parts.append("avg RPE \(Celebration.number(rpe))") }
        return parts.joined(separator: " · ")
    }

    private func spokenMetrics(_ log: TrainingWorkoutLog) -> String {
        var parts: [String] = []
        if let date = log.completedAt { parts.append(TrainingFormat.shortDate(date)) }
        if let seconds = log.durationSeconds { parts.append(TrainingFormat.spokenDuration(seconds)) }
        parts.append("\(log.totalSets) sets")
        parts.append("\(unit.volumeLabel(kilograms: log.totalVolumeKg)) of volume")
        if let rpe = averageRPE(log) { parts.append("average RPE \(Celebration.number(rpe))") }
        if log.isPartial { parts.append("Partial session") }
        return parts.joined(separator: ", ") + "."
    }

    /// La media de esfuerzo de las series de trabajo. Si ninguna trae RPE se usa el de la sesión,
    /// que es lo que la persona declaró al cerrar; si tampoco, la línea no lo menciona.
    private func averageRPE(_ log: TrainingWorkoutLog) -> Double? {
        let values = log.sets.filter { !$0.isWarmup }.compactMap(\.rpe)
        guard !values.isEmpty else { return log.sessionRPE }
        let average = values.reduce(0, +) / Double(values.count)
        return (average * 10).rounded() / 10
    }

    // MARK: - Marca

    private func recordCard(log: TrainingWorkoutLog, record: TrainingSetLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                PRBadge(isConfirmed: true, showsText: false)
                Text("Personal record · \(record.exerciseName) \(setSummary(record))")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Personal record. \(record.exerciseName), \(spokenSet(record)).")

            if log.coachCongratulated {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(TrainingType.icon(11))
                        .foregroundColor(Color.dynamicAccentText(theme: theme))
                    Text("Congratulated")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Already congratulated.")
            } else {
                Button {
                    Task { await congratulate() }
                } label: {
                    Text("Congratulate")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .overlay(
                            Capsule().stroke(Color.dynamicAccentText(theme: theme).opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isCongratulating)
                .accessibilityHint("Tells \(clientName) you saw the record.")
            }
        }
        .trainingCard(theme: theme)
        .overlay(particles)
    }

    /// Partículas discretas y locales, dentro de la tarjeta: la celebración nunca cubre el CTA
    /// (checklist §10.13) y desaparece entera con Reduce Motion (§10.14).
    @ViewBuilder
    private var particles: some View {
        if showsParticles && !reduceMotion {
            ConfettiView(
                particleCount: 10,
                colors: [Color.dynamicAccent(theme: theme)],
                duration: 0.4,
                spreadRadius: 120
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Ejercicios

    private var exerciseList: some View {
        VStack(spacing: 12) {
            ForEach(exercises) { exercise in
                exerciseCard(exercise)
            }
        }
    }

    private func exerciseCard(_ exercise: ReviewedExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    onOpenExerciseHistory(exercise.exerciseKey, exercise.exerciseName)
                } label: {
                    Text(exercise.exerciseName)
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the history for this exercise.")

                Spacer(minLength: 8)

                if let prescription = exercise.prescription {
                    Text("prescribed \(TrainingPrescription.text(for: prescription, unit: unit, includeRest: false))")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel("Prescribed \(TrainingPrescription.spoken(for: prescription, unit: unit))")
                }
            }

            if exercise.isCompact {
                compactSets(exercise)
            } else {
                VStack(spacing: 6) {
                    ForEach(exercise.sets) { reviewed in
                        setRow(reviewed)
                    }
                }
            }
        }
        .trainingCard(theme: theme)
    }

    /// Los ejercicios sin desviación se compactan a una línea, como el wireframe: lo que hay que
    /// mirar son los que sí la tienen.
    private func compactSets(_ exercise: ReviewedExercise) -> some View {
        Text(exercise.sets.enumerated().map { index, reviewed in
            "\(index + 1)  \(setSummary(reviewed.setLog))"
        }.joined(separator: "  ·  "))
        .font(TrainingType.monoS())
        .monospacedDigit()
        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(
            exercise.sets.map { "Set \($0.setLog.setNumber). \(spokenSet($0.setLog))." }.joined(separator: " ")
        )
    }

    private func setRow(_ reviewed: ReviewedSet) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(reviewed.setLog.setNumber)")
                .font(TrainingType.monoS())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .frame(width: 18, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(setSummary(reviewed.setLog))
                .font(TrainingType.monoM())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let rpe = reviewed.setLog.rpe {
                Text("RPE \(Celebration.number(rpe))")
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 4)

            if let deviation = reviewed.deviation {
                HStack(spacing: 4) {
                    Image(systemName: "triangle.fill")
                        .font(TrainingType.icon(8, weight: .regular))
                    Text(deviation.text)
                        .font(TrainingType.caption())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(Color.warningYellow)
            }

            if reviewed.setLog.isPR {
                PRBadge(isConfirmed: true, showsText: false)
            }
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSetRow(reviewed))
    }

    // MARK: - Nota del cliente

    private func clientNote(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TrainingEyebrow(text: "Client note")
            Text("“\(note)”")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .trainingCard(theme: theme)
        .accessibilityElement(children: .combine)
    }

    private func previousComment(_ text: String, at date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TrainingEyebrow(
                text: "Your comment",
                trailing: date.map { TrainingFormat.relative($0) }
            )
            Text("“\(text)”")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .trainingCard(theme: theme)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Comentario

    private var commentBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let confirmation {
                Text(confirmation)
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .transition(.opacity)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                TextField("Write a comment", text: $comment, axis: .vertical)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1...4)
                    .focused($isCommentFocused)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(Color.dynamicSurface(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                    )
                    .onChange(of: comment) { _, _ in
                        confirmation = nil
                        errorMessage = nil
                    }

                Button {
                    Task { await sendComment() }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(TrainingType.icon(15, weight: .semibold))
                        .foregroundColor(
                            canSend
                                ? ThemeManager.accentInkForCurrentAccent(theme: theme)
                                : Color.dynamicTextTertiary(theme: theme)
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(
                                canSend
                                    ? Color.dynamicAccent(theme: theme)
                                    : Color.dynamicSurface2(theme: theme)
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send comment")
                .accessibilityHint("Sends your comment to \(clientName).")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.dynamicBackground(theme: theme).opacity(0.96))
    }

    private var canSend: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    // MARK: - Texto

    /// «185 × 5» / «5 reps» cuando no hubo peso.
    private func setSummary(_ set: TrainingSetLog) -> String {
        guard let weight = set.weightKg else { return "\(set.reps) reps" }
        return "\(NumberFormat.trimmedDecimal(unit.loadValue(kilograms: weight))) × \(set.reps)"
    }

    private func spokenSet(_ set: TrainingSetLog) -> String {
        var parts: [String] = []
        if let weight = set.weightKg {
            let value = NumberFormat.trimmedDecimal(unit.loadValue(kilograms: weight))
            parts.append("\(value) \(unit == .pounds ? "pounds" : "kilograms")")
        }
        parts.append("\(set.reps) rep\(set.reps == 1 ? "" : "s")")
        if let rpe = set.rpe { parts.append("RPE \(Celebration.number(rpe))") }
        return parts.joined(separator: ", ")
    }

    /// «Set 3. 185 pounds, 5 reps, RPE 9. Above the target RPE of 8.» (UX §6)
    private func spokenSetRow(_ reviewed: ReviewedSet) -> String {
        var text = "Set \(reviewed.setLog.setNumber). \(spokenSet(reviewed.setLog))."
        if let deviation = reviewed.deviation {
            text += " " + deviation.spoken(target: spokenTarget(reviewed))
        }
        if reviewed.setLog.isPR { text += " Personal record." }
        return text
    }

    private func spokenTarget(_ reviewed: ReviewedSet) -> String {
        guard let value = reviewed.targetValue else { return "" }
        switch reviewed.deviation {
        case .belowLoad:
            let converted = unit.loadValue(kilograms: value)
            return "\(NumberFormat.trimmedDecimal(converted)) \(unit == .pounds ? "pounds" : "kilograms")"
        default:
            return Celebration.number(value)
        }
    }

    // MARK: - Carga

    private var loading: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrainingSkeletonBar(width: 120, height: 12)
            TrainingSkeletonBar(width: 240, height: 16)
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    TrainingSkeletonBar(width: 160, height: 14)
                    TrainingSkeletonBar(width: 200, height: 12)
                    TrainingSkeletonBar(width: 180, height: 12)
                }
                .trainingCard(theme: theme)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading the session")
    }

    // MARK: - Acciones

    private func load() async {
        trainingService.errorMessage = nil
        await trainingService.fetchLog(logId)
    }

    private func congratulate() async {
        guard !isCongratulating else { return }
        // Antes de cualquier await, que si no el segundo toque manda una segunda felicitación.
        isCongratulating = true
        errorMessage = nil
        defer { isCongratulating = false }

        guard await trainingService.reviewLog(logId, comment: nil, congratulate: true) != nil else {
            errorMessage = trainingService.saveErrorMessage ?? "Couldn't send it. Try again."
            trainingService.saveErrorMessage = nil
            return
        }

        HapticManager.shared.play(.success)
        if !reduceMotion {
            showsParticles = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            showsParticles = false
        }
        confirmation = "Sent to \(clientName)"
    }

    private func sendComment() async {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        // La felicitación que ya estuviera puesta se conserva: el contrato reescribe el registro
        // entero en cada revisión y omitirla la borraría.
        let keepsCongratulation = log?.coachCongratulated ?? false

        guard await trainingService.reviewLog(logId, comment: text, congratulate: keepsCongratulation) != nil else {
            errorMessage = trainingService.saveErrorMessage ?? "Couldn't send it. Your comment is still here."
            trainingService.saveErrorMessage = nil
            return
        }

        HapticManager.shared.play(.success)
        comment = ""
        isCommentFocused = false
        confirmation = "Sent to \(clientName)"
    }
}
