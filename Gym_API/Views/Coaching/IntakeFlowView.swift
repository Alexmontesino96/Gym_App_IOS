//
//  IntakeFlowView.swift
//  Gym_API
//
//  Intake del cliente (plan §8.4). Cuatro pasos, en este orden porque es el orden en que un
//  entrenador de verdad pregunta: primero para qué vienes, luego cuándo puedes, luego qué te
//  duele, y solo al final el papeleo médico y legal. Meter el PAR-Q primero convierte el alta
//  en un cuestionario de salud antes de que la persona haya dicho una palabra sobre su objetivo.
//
//  Nada de esto bloquea: un «sí» en el PAR-Q no impide enviar. Solo avisa de que el entrenador
//  lo va a revisar antes de la primera sesión, que es lo que de verdad pasa en el otro extremo.
//

import SwiftUI

struct IntakeFlowView: View {

    /// Se llama tras un envío correcto, para que quien presenta la hoja reaccione (por ejemplo,
    /// quitar la tarjeta «Tell your coach about you» sin esperar a la próxima carga).
    var onSubmitted: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var healthService: HealthService
    @Environment(\.dismiss) private var dismiss

    @State private var step: IntakeStep = .basics

    // Paso 1
    @State private var goals = ""
    @State private var experience: IntakeExperience = .beginner

    // Paso 2
    @State private var selectedDays: Set<String> = []

    // Paso 3
    @State private var injuries = ""
    @State private var medicalNotes = ""

    // Paso 4
    @State private var parq = ParqAnswers.allNo
    @State private var waiverAccepted = false

    @State private var isSending = false
    @State private var errorMessage: String?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var trimmedGoals: String { goals.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Solo el primer paso exige algo: sin un objetivo no hay nada que contarle al entrenador.
    /// El resto de campos son legítimamente opcionales — no todo el mundo tiene lesiones que
    /// declarar — salvo el interruptor del waiver, que bloquea el envío final.
    private var canAdvance: Bool {
        switch step {
        case .basics: return !trimmedGoals.isEmpty
        case .availability, .health: return true
        case .parqAndWaiver: return waiverAccepted && !isSending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressDots

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        stepContent

                        if let errorMessage {
                            TrainingRetryRow(
                                message: errorMessage,
                                retryTitle: "Retry",
                                onRetry: { Task { await submit() } }
                            )
                                .trainingCard(theme: theme)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                footer
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
            .trainingAnnouncement(errorMessage)
            .onChange(of: step) { _, newValue in
                // Cada paso anuncia su título: sin esto VoiceOver se queda leyendo el contenido
                // del paso anterior mientras el foco ya está en la nueva pantalla.
                UIAccessibility.post(notification: .screenChanged, argument: newValue.title)
            }
        }
    }

    // MARK: - Progreso

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(IntakeStep.allCases, id: \.self) { candidate in
                Capsule()
                    .fill(candidate.rawValue <= step.rawValue
                          ? Color.dynamicAccent(theme: theme)
                          : Color.dynamicBorder(theme: theme).opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .accessibilityHidden(true)
    }

    // MARK: - Contenido por paso

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basics: basicsStep
        case .availability: availabilityStep
        case .health: healthStep
        case .parqAndWaiver: parqAndWaiverStep
        }
    }

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are you training for?")
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicText(theme: theme))

            TextField("e.g. lose fat, run a 10k, feel stronger day to day", text: $goals, axis: .vertical)
                .lineLimit(3...6)
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicText(theme: theme))
                .padding(14)
                .background(Color.dynamicSurface(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                )
                .accessibilityLabel("Your goals")

            Text("Training experience")
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicText(theme: theme))
                .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach(IntakeExperience.allCases, id: \.self) { level in
                    experienceRow(level)
                }
            }
        }
    }

    private func experienceRow(_ level: IntakeExperience) -> some View {
        let isSelected = experience == level
        return Button {
            HapticManager.shared.play(.selection)
            experience = level
        } label: {
            HStack {
                Text(level.label)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                }
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? Color.dynamicAccent(theme: theme)
                            : Color.dynamicBorder(theme: theme).opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(level.label)
    }

    private var availabilityStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which days can you usually train?")
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicText(theme: theme))

            Text("Pick as many as apply. Your coach uses this to plan your week — it's fine if it changes later.")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Array(IntakeFlowView.weekdayKeys.enumerated()), id: \.element) { index, key in
                    dayRow(key: key, index: index)
                }
            }
        }
    }

    private func dayRow(key: String, index: Int) -> some View {
        let isSelected = selectedDays.contains(key)
        let name = TrainingWeekday.name(index: index + 1)
        return Button {
            HapticManager.shared.play(.selection)
            if isSelected { selectedDays.remove(key) } else { selectedDays.insert(key) }
        } label: {
            HStack {
                Text(name)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(
                        isSelected ? Color.dynamicAccent(theme: theme) : Color.dynamicTextTertiary(theme: theme)
                    )
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? Color.dynamicAccent(theme: theme)
                            : Color.dynamicBorder(theme: theme).opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(name)
        .accessibilityHint(isSelected ? "Selected. Double tap to remove." : "Double tap to select.")
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Injuries")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text("Anything past or current your coach should know before programming.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Optional", text: $injuries, axis: .vertical)
                    .lineLimit(2...5)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(14)
                    .background(Color.dynamicSurface(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                    )
                    .accessibilityLabel("Injuries, optional")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Medical notes")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text("Conditions, medication, or anything that affects how you train.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Optional", text: $medicalNotes, axis: .vertical)
                    .lineLimit(2...5)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(14)
                    .background(Color.dynamicSurface(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                    )
                    .accessibilityLabel("Medical notes, optional")
            }
        }
    }

    private var parqAndWaiverStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("A few health questions")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text("The PAR-Q+, the standard pre-exercise screening.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }

            VStack(spacing: 10) {
                ForEach(IntakeFlowView.parqQuestions, id: \.key) { question in
                    parqRow(question)
                }
            }

            if parq.anyYes {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(TrainingType.icon(14, weight: .semibold))
                        .foregroundColor(Color.dynamicWarningText(theme: theme))
                    Text("Your coach will review this before your first session.")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicWarningText(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.dynamicWarningText(theme: theme).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }

            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.2))

            VStack(alignment: .leading, spacing: 10) {
                Text("Liability waiver")
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))

                ScrollView {
                    Text(IntakeFlowView.waiverText)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                }
                .frame(maxHeight: 140)
                .background(Color.dynamicSurface(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                )

                Toggle(isOn: $waiverAccepted) {
                    Text("I have read and accept this waiver")
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Color.dynamicAccent(theme: theme))
                .accessibilityLabel("I have read and accept this waiver, version \(IntakeFlowView.waiverVersion)")
            }
        }
    }

    private func parqRow(
        _ question: (key: String, keyPath: WritableKeyPath<ParqAnswers, Bool>, text: String)
    ) -> some View {
        Toggle(isOn: parqBinding(question.keyPath)) {
            Text(question.text)
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(Color.dynamicAccent(theme: theme))
        .padding(14)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
        .accessibilityLabel(question.text)
    }

    private func parqBinding(_ keyPath: WritableKeyPath<ParqAnswers, Bool>) -> Binding<Bool> {
        Binding(get: { parq[keyPath: keyPath] }, set: { parq[keyPath: keyPath] = $0 })
    }

    // MARK: - Navegación

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .basics {
                Button {
                    HapticManager.shared.play(.selection)
                    step = IntakeStep(rawValue: step.rawValue - 1) ?? .basics
                } label: {
                    Text("Back")
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button {
                if step == .parqAndWaiver {
                    Task { await submit() }
                } else {
                    HapticManager.shared.play(.selection)
                    step = IntakeStep(rawValue: step.rawValue + 1) ?? .parqAndWaiver
                }
            } label: {
                HStack(spacing: 8) {
                    if isSending { ProgressView().tint(ThemeManager.accentInkForCurrentAccent(theme: theme)) }
                    Text(step == .parqAndWaiver ? (isSending ? "Sending…" : "Submit") : "Next")
                        .font(TrainingType.headline())
                }
                .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                .opacity(canAdvance ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - Envío

    private func submit() async {
        guard canAdvance, !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let request = ClientIntakeRequest(
            goals: trimmedGoals,
            experience: experience,
            availableDays: IntakeFlowView.weekdayKeys.filter { selectedDays.contains($0) },
            injuries: injuries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : injuries.trimmingCharacters(in: .whitespacesAndNewlines),
            medicalNotes: medicalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : medicalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            parq: parq,
            waiverAccepted: waiverAccepted,
            waiverVersion: IntakeFlowView.waiverVersion
        )

        guard await healthService.submitIntake(request) else {
            errorMessage = healthService.saveErrorMessage ?? "Couldn't send your intake. Your answers are still here."
            healthService.saveErrorMessage = nil
            return
        }

        HapticManager.shared.play(.success)
        onSubmitted?()
        dismiss()
    }

    // MARK: - Constantes

    /// Orden canónico de `available_days`, el mismo en que se listan en el paso 2.
    static let weekdayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    static let waiverVersion = "2026-09-draft"

    /// Borrador: pendiente de que legal entregue el texto final. La versión en el cuerpo de la
    /// petición es lo que permite reemplazarlo sin migrar filas ya firmadas.
    static let waiverText = """
    I understand that participating in physical training involves inherent risks, including but \
    not limited to injury from exercise, use of equipment, and physical exertion. I confirm that \
    the health information I have provided is accurate to the best of my knowledge.

    I voluntarily assume all risks associated with my participation and release my trainer and \
    this gym from liability for any injury or loss arising from my participation, except where \
    caused by their gross negligence.

    I will inform my trainer immediately of any change in my health that could affect my ability \
    to train safely.
    """

    /// Las siete preguntas del PAR-Q+ (forma corta), en inglés y en el orden del contrato.
    static let parqQuestions: [(key: String, keyPath: WritableKeyPath<ParqAnswers, Bool>, text: String)] = [
        ("q1", \ParqAnswers.q1, "Has a doctor ever said you have a heart condition or high blood pressure?"),
        ("q2", \ParqAnswers.q2,
         "Do you feel pain in your chest at rest, during your daily activities, or during physical activity?"),
        ("q3", \ParqAnswers.q3,
         "Do you lose your balance because of dizziness, or have you lost consciousness in the last 12 months?"),
        ("q4", \ParqAnswers.q4,
         "Do you have a chronic medical condition other than heart disease or high blood pressure?"),
        ("q5", \ParqAnswers.q5, "Are you currently taking prescribed medication for a chronic medical condition?"),
        ("q6", \ParqAnswers.q6,
         "Do you have a bone, joint, or soft-tissue problem that could be made worse by physical activity?"),
        ("q7", \ParqAnswers.q7,
         "Has a doctor ever said you should only do physical activity recommended by a health professional?")
    ]
}

// MARK: - Pasos

enum IntakeStep: Int, CaseIterable, Hashable {
    case basics = 0
    case availability = 1
    case health = 2
    case parqAndWaiver = 3

    var title: String {
        switch self {
        case .basics: return "Goals & experience"
        case .availability: return "Your availability"
        case .health: return "Injuries & medical notes"
        case .parqAndWaiver: return "Health screening"
        }
    }
}
