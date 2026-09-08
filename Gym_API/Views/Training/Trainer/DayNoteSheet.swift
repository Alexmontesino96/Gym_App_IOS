//
//  DayNoteSheet.swift
//  Gym_API
//
//  S23 · Day note (UX §6).
//
//  Una nota de 280 caracteres para un cliente y un día. El límite es intencional: la nota se lee
//  de un vistazo dentro de la pantalla de sesión (S11), y ahí no cabe un párrafo.
//
//  Dos detalles del wireframe que parecen adorno y no lo son:
//
//  - La línea «Shows on Dana's Thursday and inside the session log.» dice DÓNDE va a aparecer.
//    Sin ella, el entrenador no sabe si está mandando un mensaje de chat o escribiendo en el
//    plan, y escribe distinto.
//  - `RECENT` **rellena el campo, no envía**. Reutilizar una nota es un atajo de escritura, no
//    un botón de mandar: la segunda vez que alguien manda por accidente la nota de la semana
//    pasada deja de usar la sección.
//

import SwiftUI
import TrainingCore

struct DayNoteSheet: View {

    let client: TrainingClientRef
    let date: CalendarDate
    /// Se llama tras enviar, para que la pantalla de detrás refresque lo que enseña.
    var onSent: (TrainingClientDayNote) -> Void = { _ in }

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var text = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty && !isSending }

    /// «Thursday», el día de la semana en el que la nota va a salir.
    private var weekdayName: String {
        DateFormatter.localized(template: "EEEE").string(from: date.startOfDay(in: .current))
    }

    /// «Note for Dana · Sep 24». A partir de `xxxLarge` la barra no da para tanto y la fecha se
    /// baja al cuerpo en vez de dejar que iOS la corte con puntos suspensivos.
    private var navigationTitle: String {
        let name = "Note for \(client.firstName)"
        guard !dynamicTypeSize.stacksTrainerRows else { return name }
        return "\(name) · \(TrainingFormat.dayMonth(date.startOfDay(in: .current)))"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // A tamaños grandes el título de la barra pierde la fecha para no cortarse,
                    // así que la fecha baja aquí: sin ella no se sabe para qué día es la nota.
                    if dynamicTypeSize.stacksTrainerRows {
                        Text(TrainingFormat.longDate(date.startOfDay(in: .current)))
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    editor
                    counter
                    explanation

                    if let errorMessage {
                        TrainingRetryRow(
                            message: errorMessage,
                            retryTitle: "Retry",
                            onRetry: { Task { await send() } }
                        )
                        .trainingCard(theme: theme)
                    }

                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(navigationTitle)
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
                        .accessibilityHint("Sends the note to \(client.firstName).")
                }
            }
            .task { await load() }
            .trainingAnnouncement(errorMessage)
        }
    }

    // MARK: - Campo

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    TrainingSkeletonBar(width: 240, height: 14)
                    TrainingSkeletonBar(width: 180, height: 14)
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .accessibilityHidden(true)
            } else if trimmed.isEmpty {
                Text("What should \(client.firstName) know about this session?")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .padding(.horizontal, 13)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
                    // El editor de debajo ya dice su etiqueta y su valor; leer además el
                    // marcador de posición duplica la frase.
                    .accessibilityHidden(true)
            }

            TextEditor(text: $text)
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicText(theme: theme))
                .scrollContentBackground(.hidden)
                .accessibilityLabel("Note for \(client.firstName)")
                .accessibilityValue(trimmed.isEmpty ? "Empty" : trimmed)
                .focused($isFocused)
                .frame(minHeight: 132)
                .padding(8)
                .opacity(isLoading ? 0 : 1)
                .onChange(of: text) { _, newValue in
                    // El tope se aplica al escribir, no al enviar: un contador que llega a 281
                    // y luego recorta por detrás es una promesa rota.
                    if newValue.count > TrainingClientDayNote.maxLength {
                        text = String(newValue.prefix(TrainingClientDayNote.maxLength))
                    }
                }
        }
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
        // La etiqueta y el valor van en el `TextEditor`, no en el `ZStack`: envolver un control
        // editable en un elemento de accesibilidad puede dejarlo en solo lectura para VoiceOver.
    }

    private var counter: some View {
        Text("\(text.count) / \(TrainingClientDayNote.maxLength)")
            .font(TrainingType.monoS())
            .monospacedDigit()
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("\(text.count) of \(TrainingClientDayNote.maxLength) characters used")
    }

    private var explanation: some View {
        Text("Shows on \(client.firstName)'s \(weekdayName) and inside the session log.")
            .font(TrainingType.caption())
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - RECENT

    @ViewBuilder
    private var recentSection: some View {
        if !trainingService.recentDayNotes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                TrainingEyebrow(text: "Recent")

                ForEach(trainingService.recentDayNotes) { note in
                    Button {
                        HapticManager.shared.play(.selection)
                        text = String(note.text.prefix(TrainingClientDayNote.maxLength))
                        isFocused = true
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .font(TrainingType.body())
                                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                            Text("“\(note.text)”")
                                .font(TrainingType.body())
                                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(note.text)
                    .accessibilityHint("Fills the note. It is not sent yet.")
                }
            }
        }
    }

    // MARK: - Datos

    private func load() async {
        // Se pide en paralelo la nota que ya hubiera de ese día y las últimas del autor.
        async let existing = trainingService.fetchDayNote(userId: client.id, date: date)
        async let recent: Void = trainingService.fetchRecentDayNotes(userId: client.id)
        let note = await existing
        _ = await recent

        if let note, text.isEmpty {
            text = note.text
        }
        isLoading = false
    }

    private func send() async {
        guard canSend else { return }
        // Antes del primer await: si no, un segundo toque manda la nota dos veces.
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        guard let note = await trainingService.saveDayNote(userId: client.id, date: date, text: trimmed) else {
            errorMessage = trainingService.saveErrorMessage ?? "Couldn't send the note. Your text is still here."
            trainingService.saveErrorMessage = nil
            return
        }

        HapticManager.shared.play(.success)
        onSent(note)
        dismiss()
    }
}
