//
//  DayEditorView.swift
//  Gym_API
//
//  S21 · Day editor (UX §6).
//
//  Es la única pantalla del módulo donde el entrenador ESCRIBE el plan desde el móvil, y por eso
//  es la que más cuidado pide:
//
//  - `PUT /programs/{id}/days/{n}` es un **reemplazo completo**. Lo que no esté en la lista al
//    guardar deja de existir. Por eso el modelo (`DayEditorViewModel`) construye el cuerpo entero
//    y la vista no manda nada por su cuenta.
//  - **Reordenar tiene dos vías**: arrastrar por el asa `≡` y las acciones *Move up* / *Move down*
//    del rotor. Arrastrar no es una vía para quien usa VoiceOver o Control por conmutador.
//  - **Un error no cierra ni limpia.** El banner dice «Your changes are still here» porque es
//    verdad: el formulario sigue entero y se puede reintentar.
//

import SwiftUI
import TrainingCore

struct DayEditorView: View {

    @StateObject private var model: DayEditorViewModel
    /// Se llama al guardar bien, para que S20 refresque la semana.
    private let onSaved: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var showsPicker = false
    @State private var showsDiscardAlert = false
    @State private var showsDuplicate = false
    @State private var noteEditors: Set<UUID> = []
    /// Qué ejercicio se está arrastrando, solo para atenuarlo mientras viaja.
    @State private var draggingId: UUID?

    init(
        day: TrainingDay?,
        programId: Int,
        dayNumber: Int,
        client: TrainingClientRef,
        onSaved: @escaping () -> Void = {}
    ) {
        _model = StateObject(wrappedValue: DayEditorViewModel(
            day: day,
            programId: programId,
            dayNumber: dayNumber,
            client: client
        ))
        self.onSaved = onSaved
    }

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    dayHeader

                    if let message = model.errorMessage {
                        errorBanner(message)
                    }

                    if model.isRest {
                        restExplanation
                    } else {
                        exerciseList
                        addExerciseButton
                    }

                    duplicateButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { attemptClose() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                ToolbarItem(placement: .topBarTrailing) { saveButton }
            }
            .sheet(isPresented: $showsPicker) {
                ExercisePickerSheet(
                    mode: .add,
                    recentForClient: model.client,
                    onSelect: { model.add($0) }
                )
                .environmentObject(themeManager)
                .environmentObject(trainingService)
            }
            .sheet(isPresented: $showsDuplicate) {
                WeekTargetPickerSheet(
                    title: "Duplicate this day to…",
                    sourceLabel: model.title,
                    sourceWeek: model.weekNumber,
                    durationWeeks: durationWeeks,
                    keepLoadsTitle: nil,
                    onCopy: { weeks, _ in
                        await model.duplicate(toWeeks: weeks, using: trainingService) != nil
                    }
                )
                .environmentObject(themeManager)
            }
            .alert("Discard changes?", isPresented: $showsDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(model.hasChanges)
    }

    /// Semanas del programa: hace falta para saber a dónde se puede duplicar. Si el detalle no
    /// está cargado se usa la semana actual, que al menos no ofrece destinos inexistentes.
    private var durationWeeks: Int {
        trainingService.programDetail?.program.durationWeeks
            ?? trainingService.clientPrograms?.active?.program.durationWeeks
            ?? model.weekNumber
    }

    // MARK: - Guardar

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            if model.showsSuccess {
                Image(systemName: "checkmark")
                    .font(TrainingType.icon(15, weight: .semibold))
                    .foregroundColor(Color.dynamicAccentText(theme: theme))
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else if model.isSaving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicAccentText(theme: theme))
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .disabled(!model.canSave)
        .accessibilityLabel(model.showsSuccess ? "Saved" : "Save")
    }

    private func save() async {
        guard await model.save(using: trainingService) else { return }
        onSaved()
        // El *morphing success* de la UX: 300 ms de check antes de cerrar. Con Reduce Motion el
        // check aparece sin escala, pero se enseña igual: es información, no adorno.
        try? await Task.sleep(nanoseconds: 300_000_000)
        dismiss()
    }

    private func attemptClose() {
        if model.hasChanges {
            showsDiscardAlert = true
        } else {
            dismiss()
        }
    }

    // MARK: - Cabecera del día

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainerTextField(
                label: "Day name",
                text: $model.name,
                placeholder: "Upper B",
                spokenValue: model.name.isEmpty ? "Empty" : model.name
            )

            Toggle(isOn: $model.isRest) {
                Text("Rest day")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
            }
            .tint(Color.dynamicAccent(theme: theme))
            .frame(minHeight: 44)
            .disabled(!model.exercises.isEmpty)
            .accessibilityHint(model.exercises.isEmpty ? "" : "Remove the exercises first.")
        }
        .trainingCard(theme: theme)
    }

    private var restExplanation: some View {
        Text("\(model.client.firstName) sees this day as rest. Adding an exercise turns it back into a session.")
            .font(TrainingType.body())
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            .fixedSize(horizontal: false, vertical: true)
            .trainingCard(theme: theme)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(TrainingType.icon(14))
                .foregroundColor(Color.warningYellow)
            Text(message)
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .trainingCard(theme: theme, padding: 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Lista de ejercicios

    @ViewBuilder
    private var exerciseList: some View {
        if model.exercises.isEmpty {
            Text("No exercises yet. Add the first one below.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
                .trainingCard(theme: theme)
        } else {
            VStack(spacing: 12) {
                ForEach(Array(model.exercises.enumerated()), id: \.element.localId) { index, exercise in
                    exerciseCard(exercise, position: position(at: index))
                }
            }
        }
    }

    private func position(at index: Int) -> String {
        let labels = model.positionLabels
        return labels.indices.contains(index) ? labels[index] : "\(index + 1)"
    }

    private func exerciseCard(_ exercise: DayExerciseInput, position: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow(exercise, position: position)

            TrainerFieldRow {
                TrainerStepperField(
                    label: "Sets",
                    value: "\(exercise.setsCount)",
                    spokenValue: "\(exercise.setsCount) sets",
                    onDecrement: { model.adjustSets(id: exercise.localId, by: -1) },
                    onIncrement: { model.adjustSets(id: exercise.localId, by: 1) }
                )

                TrainerTextField(
                    label: "Reps",
                    text: repsBinding(exercise),
                    placeholder: "5",
                    spokenValue: spokenReps(exercise.reps),
                    onDecrement: { model.adjustReps(id: exercise.localId, by: -1) },
                    onIncrement: { model.adjustReps(id: exercise.localId, by: 1) },
                    steppersEnabled: model.repsAreNumeric(exercise.reps)
                )
            }

            TrainerFieldRow {
                TrainerMenuField(label: "Load", value: LoadModeConversion.title(for: exercise.loadMode)) {
                    ForEach(LoadModeConversion.allModes, id: \.self) { mode in
                        Button {
                            model.setLoadMode(id: exercise.localId, mode: mode)
                        } label: {
                            if mode == exercise.loadMode {
                                Label(LoadModeConversion.title(for: mode), systemImage: "checkmark")
                            } else {
                                Text(LoadModeConversion.title(for: mode))
                            }
                        }
                    }
                }

                if model.loadDraft(for: exercise.localId).hasNumericField {
                    TrainerStepperField(
                        label: exercise.loadMode == .weight ? unit.symbol.uppercased() : "%",
                        value: loadText(exercise),
                        spokenValue: spokenLoad(exercise),
                        onDecrement: { model.adjustLoad(id: exercise.localId, by: -1, unit: unit) },
                        onIncrement: { model.adjustLoad(id: exercise.localId, by: 1, unit: unit) }
                    )
                }
            }

            TrainerFieldRow {
                TrainerStepperField(
                    label: "RPE",
                    value: exercise.rpeTarget.map { Celebration.number($0) } ?? NumberFormat.placeholder,
                    spokenValue: exercise.rpeTarget.map { "RPE \(Celebration.number($0))" } ?? "No target",
                    onDecrement: { model.adjustRPE(id: exercise.localId, by: -1) },
                    onIncrement: { model.adjustRPE(id: exercise.localId, by: 1) }
                )

                TrainerStepperField(
                    label: "Rest",
                    value: TrainingPrescription.clock(exercise.restSeconds),
                    spokenValue: TrainingPrescription.spokenRest(exercise.restSeconds),
                    onDecrement: { model.adjustRest(id: exercise.localId, by: -1) },
                    onIncrement: { model.adjustRest(id: exercise.localId, by: 1) }
                )

                TrainerMenuField(label: "Superset", value: exercise.supersetGroup ?? NumberFormat.placeholder) {
                    Button("None") { model.setSuperset(id: exercise.localId, group: nil) }
                    ForEach(["A", "B", "C", "D"], id: \.self) { group in
                        Button(group) { model.setSuperset(id: exercise.localId, group: group) }
                    }
                }
            }

            noteField(exercise)
        }
        .trainingCard(theme: theme, padding: 14)
        .opacity(draggingId == exercise.localId ? 0.4 : 1)
        // Arrastrar es la vía rápida; las acciones de accesibilidad de abajo son la otra, y
        // ninguna de las dos es la única (checklist §10.18).
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dragged = UUID(uuidString: raw) else { return false }
            let moved = model.move(id: dragged, toPositionOf: exercise.localId)
            if moved { HapticManager.shared.play(.selection) }
            draggingId = nil
            return moved
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(position). \(exercise.displayName)")
        .accessibilityActions {
            Button("Move up") {
                if model.moveUp(id: exercise.localId) { HapticManager.shared.play(.selection) }
            }
            Button("Move down") {
                if model.moveDown(id: exercise.localId) { HapticManager.shared.play(.selection) }
            }
            Button("Remove") { remove(exercise) }
        }
    }

    // MARK: - Fila del título

    private func titleRow(_ exercise: DayExerciseInput, position: String) -> some View {
        HStack(spacing: 10) {
            grip(exercise)

            Text(position)
                .font(TrainingType.monoS())
                .monospacedDigit()
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .frame(minWidth: 22, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(exercise.displayName)
                .font(TrainingType.headline())
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button { remove(exercise) } label: {
                Image(systemName: "xmark.circle")
                    .font(TrainingType.icon(16, weight: .regular))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(exercise.displayName)")
        }
    }

    /// El asa `≡` del wireframe. Arrastra el ejercicio; quien no puede arrastrar tiene las
    /// acciones *Move up* y *Move down* del rotor sobre la tarjeta entera.
    private func grip(_ exercise: DayExerciseInput) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(TrainingType.icon(13))
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .frame(width: 32, height: 44)
            .contentShape(Rectangle())
            .draggable(exercise.localId.uuidString) {
                Text(exercise.displayName)
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(8)
                    .background(Color.dynamicSurface2(theme: theme))
                    .onAppear { draggingId = exercise.localId }
            }
            .accessibilityHidden(true)
    }

    private func remove(_ exercise: DayExerciseInput) {
        HapticManager.shared.play(.light)
        noteEditors.remove(exercise.localId)
        model.remove(id: exercise.localId)
    }

    // MARK: - Nota del ejercicio

    @ViewBuilder
    private func noteField(_ exercise: DayExerciseInput) -> some View {
        let hasNote = !(exercise.notes ?? "").isEmpty
        if hasNote || noteEditors.contains(exercise.localId) {
            TrainerTextField(
                label: "Note",
                text: noteBinding(exercise),
                placeholder: "Strict press.",
                spokenValue: exercise.notes ?? "Empty"
            )
        } else {
            Button {
                noteEditors.insert(exercise.localId)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(TrainingType.icon(10, weight: .semibold))
                    Text("Note")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .overlay(
                    Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a note to \(exercise.displayName)")
        }
    }

    // MARK: - Acciones de la lista

    private var addExerciseButton: some View {
        Button {
            HapticManager.shared.play(.selection)
            showsPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(TrainingType.icon(13, weight: .semibold))
                Text("Add exercise")
                    .font(TrainingType.headline())
            }
            .foregroundColor(Color.dynamicText(theme: theme))
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(
                Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var duplicateButton: some View {
        Button {
            HapticManager.shared.play(.selection)
            showsDuplicate = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square")
                    .font(TrainingType.icon(13))
                Text("Duplicate this day to…")
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.existed)
        .accessibilityHint(model.existed ? "" : "Save this day first.")
    }

    // MARK: - Enlaces

    private func repsBinding(_ exercise: DayExerciseInput) -> Binding<String> {
        Binding(
            get: { model.index(of: exercise.localId).map { model.exercises[$0].reps } ?? exercise.reps },
            set: { model.setReps(id: exercise.localId, text: $0) }
        )
    }

    private func noteBinding(_ exercise: DayExerciseInput) -> Binding<String> {
        Binding(
            get: { model.index(of: exercise.localId).flatMap { model.exercises[$0].notes } ?? "" },
            set: { model.setNote(id: exercise.localId, text: $0) }
        )
    }

    // MARK: - Texto

    private func loadText(_ exercise: DayExerciseInput) -> String {
        guard let value = exercise.loadValue else { return NumberFormat.placeholder }
        switch exercise.loadMode {
        case .weight:
            return NumberFormat.trimmedDecimal(unit.loadValue(kilograms: value))
        case .percent1RM:
            return NumberFormat.trimmedDecimal(value)
        case .rpe, .bodyweight:
            return NumberFormat.placeholder
        }
    }

    private func spokenLoad(_ exercise: DayExerciseInput) -> String {
        guard let value = exercise.loadValue else { return "No load" }
        switch exercise.loadMode {
        case .weight:
            let converted = NumberFormat.trimmedDecimal(unit.loadValue(kilograms: value))
            return "\(converted) \(unit == .pounds ? "pounds" : "kilograms")"
        case .percent1RM:
            return "\(NumberFormat.trimmedDecimal(value)) percent of one rep max"
        case .rpe, .bodyweight:
            return "No load"
        }
    }

    private func spokenReps(_ reps: String) -> String {
        let trimmed = reps.trimmingCharacters(in: .whitespaces)
        if trimmed.uppercased().contains("AMRAP") { return "As many reps as possible" }
        if trimmed.isEmpty { return "Empty" }
        return "\(trimmed) reps"
    }
}
