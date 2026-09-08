//
//  SessionLogView.swift
//  Gym_API
//
//  S11 · Session log (UX §5). La pantalla que justifica el módulo entero.
//
//  Principio 1 de la especificación: aquí nada compite con marcar una serie. Por eso:
//
//  - Se ve **un ejercicio cada vez**; los demás están a un toque en la barra de chips. Además de
//    ser lo que pide el wireframe, evita tener treinta filas vivas a la vez cuando lo que
//    importa es que la siguiente serie responda al instante.
//  - El único relleno de acento de la pantalla es el círculo de la serie que toca ahora.
//    `Finish session` es de contorno: terminar es una decisión, marcar es el trabajo.
//  - La pantalla no se apaga mientras esta vista está viva, y sin red no cambia nada: se escribe
//    en el outbox en cada marca y el chip lo cuenta.
//

import SwiftUI
import TrainingCore

struct SessionLogView: View {

    @StateObject private var viewModel: SessionLogViewModel

    /// Nota del entrenador para el día, si la hay. Llega de `/me/days/{id}`.
    private let coachNote: String?
    /// Cierra la sesión: la vista de arriba abre S18 con lo que devuelve.
    private let onFinish: (WorkoutSession) -> Void
    /// Salir sin terminar.
    private let onClose: () -> Void
    /// Abre S15 del ejercicio.
    private let onOpenHistory: (String, String) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var showsLeaveConfirmation = false
    @State private var showsExercisePicker = false
    @State private var pickerMode: ExercisePickerSheet.Mode = .add
    @State private var swapTarget: UUID?
    @State private var showsRPEPicker = false
    @State private var rpeTarget: (exerciseId: UUID, setId: UUID, current: Double?)?
    @State private var showsRestSheet = false
    @State private var showsNoteEditor = false
    @State private var noteDraft = ""

    init(
        viewModel: SessionLogViewModel,
        coachNote: String? = nil,
        onFinish: @escaping (WorkoutSession) -> Void,
        onClose: @escaping () -> Void,
        onOpenHistory: @escaping (String, String) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.coachNote = coachNote
        self.onFinish = onFinish
        self.onClose = onClose
        self.onOpenHistory = onOpenHistory
    }

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var unit: WeightUnit { WeightUnitPreference.current }

    private var session: WorkoutSession { viewModel.session }

    private var activeExercise: SessionExercise? {
        guard session.exercises.indices.contains(session.activeExerciseIndex) else {
            return session.exercises.first
        }
        return session.exercises[session.activeExerciseIndex]
    }

    var body: some View {
        ZStack {
            Color.dynamicBackground(theme: theme).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))

                if !session.isFreeWorkout && session.exercises.count > 1 {
                    exerciseChips
                    Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                }

                // La nota del entrenador es del DÍA, no del ejercicio: se pinta una vez, arriba.
                // Repetirla bajo cada ejercicio la convertía en una instrucción de ese ejercicio.
                // Y un entreno libre no cuelga de ningún día: ahí la nota no viene a cuento.
                if let coachNote, !coachNote.isEmpty, !session.isFreeWorkout {
                    coachNoteBanner(coachNote)
                    Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                }

                body(for: activeExercise)

                bottomBar
            }

            if viewModel.showsCoachMarks {
                coachMarks
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $showsExercisePicker) {
            ExercisePickerSheet(mode: pickerMode) { item in
                if let target = swapTarget {
                    viewModel.swapExercise(exerciseId: target, with: item)
                    swapTarget = nil
                } else {
                    viewModel.addExercise(item)
                }
            }
            .environmentObject(themeManager)
            .environmentObject(trainingService)
        }
        .sheet(isPresented: $showsRPEPicker) {
            RPEPickerSheet(current: rpeTarget?.current) { value in
                if let target = rpeTarget {
                    viewModel.updateSet(
                        exerciseId: target.exerciseId,
                        setId: target.setId,
                        rpe: .some(value)
                    )
                }
            }
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showsRestSheet) {
            RestTimerSheet(
                currentSeconds: activeExercise?.restSeconds ?? RestTimer.defaultSeconds,
                permissionHint: RestTimerNotifier.shared.permissionHint
            ) { seconds, applyToExercise in
                viewModel.restartRest(seconds: seconds, applyToExercise: applyToExercise)
            }
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showsNoteEditor) {
            SessionNoteSheet(text: $noteDraft) { text in
                viewModel.addNote(text)
            }
            .environmentObject(themeManager)
        }
        .confirmationDialog(
            "Leave without finishing? Your sets are saved.",
            isPresented: $showsLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                viewModel.leaveWithoutFinishing()
                onClose()
            }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: - Barra superior

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if session.hasAnyCompletedSet {
                    showsLeaveConfirmation = true
                } else {
                    viewModel.leaveWithoutFinishing()
                    onClose()
                }
            }) {
                // Con la palabra, no solo el aspa: es un `fullScreenCover` y el checklist §10.9
                // pide un control textual de salida visible. Todas las demás pantallas del
                // módulo dicen «Close» o «Cancel»; esta era la excepción.
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Close")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.dynamicText(theme: theme))
                .padding(.horizontal, 8)
                .trainingTouchTarget(minWidth: 60)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close session")

            VStack(spacing: 2) {
                Text(session.title)
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(viewModel.elapsedLabel) · \(viewModel.progressText)")
                    .font(TrainingType.monoS())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(session.title). \(viewModel.progressText).")

            Menu {
                Button {
                    swapTarget = nil
                    pickerMode = .add
                    showsExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                Button {
                    noteDraft = session.notes ?? ""
                    showsNoteEditor = true
                } label: {
                    Label("Add note", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .trainingTouchTarget()
            }
            .accessibilityLabel("Session options")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Chips de ejercicio

    private var exerciseChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button(action: { viewModel.selectExercise(at: index) }) {
                            HStack(spacing: 5) {
                                Image(systemName: exercise.isComplete ? "circle.fill" : "circle")
                                    .font(.system(size: 8))
                                    .foregroundColor(
                                        exercise.isComplete
                                            ? Color.dynamicAccent(theme: theme)
                                            : Color.dynamicTextTertiary(theme: theme)
                                    )
                                Text(exercise.exerciseName)
                                    .font(TrainingType.caption())
                                    .fontWeight(index == session.activeExerciseIndex ? .semibold : .regular)
                                    .foregroundColor(
                                        index == session.activeExerciseIndex
                                            ? Color.dynamicText(theme: theme)
                                            : Color.dynamicTextSecondary(theme: theme)
                                    )
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(
                                Capsule().fill(
                                    index == session.activeExerciseIndex
                                        ? Color.dynamicSurface2(theme: theme)
                                        : Color.clear
                                )
                            )
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(exercise.id)
                        .accessibilityLabel(exercise.exerciseName)
                        .accessibilityValue(exercise.isComplete ? "Done" : "\(exercise.completedSetCount) of \(exercise.sets.count) sets")
                        .accessibilityAddTraits(index == session.activeExerciseIndex ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 52)
            .onChange(of: session.activeExerciseIndex) { _, _ in
                guard let id = activeExercise?.id else { return }
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    // MARK: - Cuerpo

    @ViewBuilder
    private func body(for exercise: SessionExercise?) -> some View {
        if let exercise {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    exerciseHeader(exercise)

                    SetTableHeader()

                    ForEach(exercise.sets) { set in
                        SetRowView(
                            exercise: exercise,
                            set: set,
                            state: exercise.rowState(forSetId: set.id),
                            unit: unit,
                            onToggle: {
                                if set.isDone {
                                    viewModel.undoSet(exerciseId: exercise.id, setId: set.id)
                                } else {
                                    viewModel.markSet(exerciseId: exercise.id, setId: set.id)
                                }
                            },
                            onChangeWeight: { value in
                                viewModel.updateSet(exerciseId: exercise.id, setId: set.id, weightKg: .some(value))
                            },
                            onChangeReps: { value in
                                viewModel.updateSet(exerciseId: exercise.id, setId: set.id, reps: value)
                            },
                            onEditRPE: {
                                rpeTarget = (exercise.id, set.id, set.rpe)
                                showsRPEPicker = true
                            },
                            onRemove: {
                                viewModel.removeSet(exerciseId: exercise.id, setId: set.id)
                            }
                        )
                        .id(set.id)

                        Divider()
                            .background(Color.dynamicBorder(theme: theme).opacity(0.1))
                            .padding(.leading, 16)
                    }

                    addSetButton(exercise)

                    if let celebration = viewModel.bestSetCelebration(
                        for: exercise.exerciseKey,
                        exerciseName: exercise.exerciseName
                    ), exercise.completedSetCount > 0 {
                        RecordCelebrationCard(celebration: celebration, playsCelebration: true)
                            .padding(.horizontal, 16)
                    }

                    supersetFooter(exercise)

                    if let banner = viewModel.banner {
                        Text(banner)
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .padding(.horizontal, 16)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 44)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        let delta = value.translation.width < 0 ? 1 : -1
                        let target = session.activeExerciseIndex + delta
                        if session.exercises.indices.contains(target) {
                            viewModel.selectExercise(at: target)
                        } else {
                            HapticManager.shared.boundaryReached()
                        }
                    }
            )
        } else {
            freeWorkoutEmpty
        }
    }

    private func exerciseHeader(_ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(exercise.exerciseName)
                    .font(TrainingType.title2())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Menu {
                    Button {
                        swapTarget = exercise.id
                        pickerMode = .swap(currentName: exercise.exerciseName)
                        showsExercisePicker = true
                    } label: {
                        Label("Swap exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        onOpenHistory(exercise.exerciseKey, exercise.exerciseName)
                    } label: {
                        Label("View history", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button {
                        noteDraft = session.notes ?? ""
                        showsNoteEditor = true
                    } label: {
                        Label("Add note", systemImage: "square.and.pencil")
                    }
                    Button(role: .destructive) {
                        viewModel.removeExercise(id: exercise.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .trainingTouchTarget()
                }
                .accessibilityLabel("Exercise options")
            }

            if let prescription = exercise.prescriptionText {
                Text(prescription)
                    .font(TrainingType.subhead())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notes = exercise.notes, !notes.isEmpty {
                noteLine(notes)
            }
        }
        .padding(.horizontal, 16)
    }

    private func coachNoteBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .accessibilityHidden(true)

            Text(text)
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamicSurface2(theme: theme).opacity(0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Note from your coach. \(text)")
    }

    private func noteLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.dynamicBorder(theme: theme).opacity(0.5))
                .frame(width: 2)
                .accessibilityHidden(true)

            Text("“\(text)”")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addSetButton(_ exercise: SessionExercise) -> some View {
        Button(action: { viewModel.addSet(to: exercise.id) }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Add set")
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add set")
    }

    @ViewBuilder
    private func supersetFooter(_ exercise: SessionExercise) -> some View {
        let partners = session.supersetPartners(of: exercise.id)
        if !partners.isEmpty {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.dynamicBorder(theme: theme).opacity(0.2))
                    .frame(height: 1)
                Text("superset with \(partners.map(\.exerciseName).joined(separator: ", "))")
                    .font(TrainingType.label())
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle()
                    .fill(Color.dynamicBorder(theme: theme).opacity(0.2))
                    .frame(height: 1)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Entreno libre vacío

    private var freeWorkoutEmpty: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add the first exercise to start logging.")
                .font(TrainingType.body())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                swapTarget = nil
                pickerMode = .add
                showsExercisePicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add exercise")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.dynamicText(theme: theme))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .overlay(
                    Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    // MARK: - Barra inferior

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if let label = viewModel.restLabel {
                RestTimerBar(
                    label: label,
                    progress: viewModel.restProgress,
                    isFinished: viewModel.isRestFinished,
                    isFinalCountdown: viewModel.isInFinalCountdown,
                    accessibilityValue: viewModel.restAccessibilityValue,
                    onSkip: { viewModel.skipRest() },
                    onAddThirty: { viewModel.addThirtySeconds() },
                    onOpenSettings: { showsRestSheet = true }
                )
            }

            HStack(spacing: 12) {
                TrainingSyncChip(compact: true)

                Spacer(minLength: 0)

                Button(action: finish) {
                    Text("Finish session")
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(.horizontal, 24)
                        .frame(minHeight: 50)
                        .overlay(
                            Capsule().stroke(Color.dynamicAccent(theme: theme), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Finish session")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.dynamicBackground(theme: theme))
        }
    }

    private func finish() {
        HapticManager.shared.play(.medium)
        Task {
            let finished = await viewModel.finish()
            onFinish(finished)
        }
    }

    // MARK: - Coach marks

    private var coachMarks: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Tap the circle when you finish a set. Rest starts on its own.")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: { viewModel.dismissCoachMarks() }) {
                    Text("Got it")
                        .font(TrainingType.headline())
                        .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                        .padding(.horizontal, 28)
                        .frame(minHeight: 48)
                        .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Nota de la sesión

/// «Add a note for Marcus» de S11 y S18. Una hoja pequeña con su cierre textual.
struct SessionNoteSheet: View {

    @Binding var text: String
    let onSave: (String) -> Void
    var title: String = "Note for your coach"

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private let maxLength = 280

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("What should your coach know?", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(12)
                    .background(Color.dynamicSurface(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.dynamicBorder(theme: theme).opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }

                Text("\(text.count) / \(maxLength)")
                    .font(TrainingType.caption())
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
