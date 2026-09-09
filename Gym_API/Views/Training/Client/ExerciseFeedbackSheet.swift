//
//  ExerciseFeedbackSheet.swift
//  Gym_API
//
//  «How did this feel?» de S11 (contrato §8.2).
//
//  Es la respuesta a la promesa P2: cada «me dolió» tiene que llegar al entrenador en contexto,
//  no perdido en un chat. Por eso son cuatro botones y una nota corta, y nada más:
//
//  - **Cuatro flags y solo cuatro.** Son los que el servidor acepta y los que un entrenador
//    puede leer de un vistazo en el registro. Un formulario largo se rellena una vez.
//  - **Elegir el flag que ya está puesto lo quita.** Es la única forma de deshacer sin
//    obligar a nadie a buscar un botón «Clear» que casi nunca se usa.
//  - **Se guarda en el outbox como el resto del registro**: esta hoja no llama a la red.
//

import SwiftUI
import TrainingCore

struct ExerciseFeedbackSheet: View {

    let exerciseName: String
    let currentFlag: TrainingFeedbackFlag?
    let currentNote: String?
    /// Flag nulo borra la respuesta entera.
    let onSave: (TrainingFeedbackFlag?, String?) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var flag: TrainingFeedbackFlag?
    @State private var note: String

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private let maxLength = TrainingExerciseFeedback.maxNoteLength

    init(
        exerciseName: String,
        currentFlag: TrainingFeedbackFlag?,
        currentNote: String?,
        onSave: @escaping (TrainingFeedbackFlag?, String?) -> Void
    ) {
        self.exerciseName = exerciseName
        self.currentFlag = currentFlag
        self.currentNote = currentNote
        self.onSave = onSave
        _flag = State(initialValue: currentFlag)
        _note = State(initialValue: currentNote ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(exerciseName)
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)

                    flagButtons

                    noteField

                    Text("Only your coach sees this.")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("How did this feel?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(flag, trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fontWeight(.semibold)
                }
            }
        }
        // Igual que `SessionNoteSheet`: 320 pt es el alto de apertura, no un techo. En talla de
        // accesibilidad los cuatro botones ya no caben y hace falta poder llegar al final.
        .presentationDetents([.height(320), .large])
    }

    // MARK: - Los cuatro flags

    /// Dos columnas, y una sola en tamaños de accesibilidad: «Too easy» partido por la mitad
    /// no se lee.
    private var flagButtons: some View {
        let columns = dynamicTypeSize.stacksTrainerRows
            ? [GridItem(.flexible())]
            : Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(TrainingFeedbackFlag.selectable, id: \.self) { option in
                Button(action: {
                    HapticManager.shared.play(.selection)
                    // Volver a tocar el que ya está puesto lo quita.
                    flag = (flag == option) ? nil : option
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: option.systemImage)
                            .font(TrainingType.icon(13, weight: .semibold))
                            .foregroundColor(
                                option.isAlarming
                                    ? Color.dynamicWarningText(theme: theme)
                                    : Color.dynamicTextSecondary(theme: theme)
                            )

                        Text(option.title)
                            .font(TrainingType.caption())
                            .fontWeight(.semibold)
                            .foregroundColor(Color.dynamicText(theme: theme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14).fill(
                            flag == option ? Color.dynamicSurface2(theme: theme) : Color.clear
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14).stroke(
                            Color.dynamicBorder(theme: theme).opacity(flag == option ? 0.5 : 0.2),
                            lineWidth: 1
                        )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(flag == option ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint(flag == option ? "Removes this answer." : "")
            }
        }
    }

    // MARK: - Nota

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Anything your coach should know?", text: $note, axis: .vertical)
                .lineLimit(2...5)
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicText(theme: theme))
                .padding(12)
                .background(Color.dynamicSurface(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dynamicBorder(theme: theme).opacity(0.2), lineWidth: 1)
                )
                .onChange(of: note) { _, newValue in
                    if newValue.count > maxLength {
                        note = String(newValue.prefix(maxLength))
                    }
                }
                .accessibilityLabel("Note for your coach")

            Text("\(note.count) / \(maxLength)")
                .font(TrainingType.caption())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Chip del feedback

/// «Pain · Right shoulder.» Lo pinta S11 bajo el ejercicio y S18 en su lista; el entrenador ve
/// el mismo chip en S22, así que las tres pantallas dicen lo mismo con las mismas palabras.
///
/// `pain` va en la tinta de aviso del tema, que es la única que cumple contraste sobre la
/// tarjeta clara; los demás en texto secundario. El color nunca va solo: al lado está la palabra.
struct ExerciseFeedbackChip: View {

    let flag: TrainingFeedbackFlag
    var note: String?

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        if flag != .unknown {
            HStack(spacing: 6) {
                Image(systemName: flag.systemImage)
                    .font(TrainingType.icon(10, weight: .semibold))
                    .accessibilityHidden(true)

                Text(note.map { "\(flag.title) · \($0)" } ?? flag.title)
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(
                flag.isAlarming
                    ? Color.dynamicWarningText(theme: theme)
                    : Color.dynamicTextSecondary(theme: theme)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.3), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(note.map { "\(flag.title). \($0)" } ?? flag.title)
        }
    }
}
