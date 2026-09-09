//
//  CheckInReplySheet.swift
//  Gym_API
//
//  Respuesta del entrenador a un check-in semanal (plan §8.5).
//
//  Mismo patrón que `DayNoteSheet`: un campo, un límite visible, un botón que se deshabilita
//  mientras envía. Sobrescribir está permitido por el servidor, así que reabrir esta hoja sobre
//  un check-in que ya tiene respuesta la precarga en vez de empezar en blanco.
//

import SwiftUI

struct CheckInReplySheet: View {

    let client: ClientSummary
    let checkIn: WeeklyCheckIn
    /// Se llama con el check-in actualizado tras un envío correcto, para que la pantalla de
    /// detrás refresque su copia sin volver a pedir la lista entera.
    var onSent: (WeeklyCheckIn) -> Void = { _ in }

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var healthService: HealthService
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    init(client: ClientSummary, checkIn: WeeklyCheckIn, onSent: @escaping (WeeklyCheckIn) -> Void = { _ in }) {
        self.client = client
        self.checkIn = checkIn
        self.onSent = onSent
        _text = State(initialValue: checkIn.coachReply ?? "")
    }

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty && !isSending }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Week of \(TrainingFormat.dayMonth(checkIn.weekStart))")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                    editor
                    counter

                    if let errorMessage {
                        TrainingRetryRow(
                            message: errorMessage,
                            retryTitle: "Retry",
                            onRetry: { Task { await send() } }
                        )
                        .trainingCard(theme: theme)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Reply to \(client.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") { Task { await send() } }
                        .fontWeight(.semibold)
                        .foregroundColor(
                            canSend
                                ? Color.dynamicAccentText(theme: theme)
                                : Color.dynamicTextTertiary(theme: theme)
                        )
                        .disabled(!canSend)
                        .accessibilityHint("Sends the reply to \(client.displayName).")
                }
            }
            .onAppear { isFocused = true }
            .trainingAnnouncement(errorMessage)
        }
    }

    // MARK: - Campo

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if trimmed.isEmpty {
                Text("What should \(client.displayName) know?")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .padding(.horizontal, 13)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            TextEditor(text: $text)
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicText(theme: theme))
                .scrollContentBackground(.hidden)
                .accessibilityLabel("Reply to \(client.displayName)")
                .accessibilityValue(trimmed.isEmpty ? "Empty" : trimmed)
                .focused($isFocused)
                .frame(minHeight: 132)
                .padding(8)
                .onChange(of: text) { _, newValue in
                    if newValue.count > HealthService.maxReplyLength {
                        text = String(newValue.prefix(HealthService.maxReplyLength))
                    }
                }
        }
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    private var counter: some View {
        Text("\(text.count) / \(HealthService.maxReplyLength)")
            .font(TrainingType.monoS())
            .monospacedDigit()
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("\(text.count) of \(HealthService.maxReplyLength) characters used")
    }

    // MARK: - Envío

    private func send() async {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        guard let updated = await healthService.replyToCheckIn(
            userId: client.id, checkInId: checkIn.id, text: trimmed
        ) else {
            errorMessage = healthService.saveErrorMessage ?? "Couldn't send the reply. Your text is still here."
            healthService.saveErrorMessage = nil
            return
        }

        HapticManager.shared.play(.success)
        onSent(updated)
        dismiss()
    }
}
