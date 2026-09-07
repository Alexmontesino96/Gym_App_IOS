//
//  SessionLogViewModel.swift
//  Gym_API
//
//  Estado de S11 (UX §5).
//
//  Toda la lógica de la sesión vive en `TrainingCore.WorkoutSession`, que está probada sin
//  simulador. Esto es la capa que la conecta con lo que solo existe en la app: el outbox, la
//  notificación local del descanso, los hápticos, la analítica y el reloj de pantalla.
//
//  Dos decisiones que conviene no perder:
//
//  1. **Se encola en el outbox en cada marca**, no al final. Si la app muere a mitad de sesión,
//     lo marcado ya está en disco (plan §4.7).
//  2. **El cronómetro no tiene un contador que decrementa**: tiene una fecha de fin. El tic de un
//     segundo solo sirve para repintar; si la app pasa cinco minutos en segundo plano, al volver
//     la cifra es la correcta sin arreglar nada.
//

import Foundation
import Combine
import SwiftUI
import TrainingCore

@MainActor
final class SessionLogViewModel: ObservableObject {

    // MARK: - Publicado

    @Published private(set) var session: WorkoutSession
    @Published private(set) var restController = RestTimerController()
    /// Reloj de pantalla. Se actualiza cada segundo solo mientras hay algo que contar.
    @Published private(set) var now = Date()
    /// Coach marks de primera vez (UX §5, S11).
    @Published var showsCoachMarks = false
    /// Banner no bloqueante: «Saved on your phone…».
    @Published var banner: String?
    /// Última serie marcada, para la celebración de nivel 1.
    @Published private(set) var lastMark: MarkSetResult?

    // MARK: - Dependencias

    private let coordinator: TrainingSyncCoordinator
    private let notifier: RestTimerNotifier
    private var ticker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private static let coachMarksKey = "training.sessionCoachMarksSeen"

    // MARK: - Construcción

    init(
        session: WorkoutSession,
        coordinator: TrainingSyncCoordinator = .shared,
        notifier: RestTimerNotifier = .shared
    ) {
        self.session = session
        self.coordinator = coordinator
        self.notifier = notifier
        self.showsCoachMarks = !UserDefaults.standard.bool(forKey: Self.coachMarksKey)

        NotificationCenter.default.publisher(for: .trainingRestAddThirty)
            .sink { [weak self] _ in
                self?.addThirtySeconds(fromNotification: true)
            }
            .store(in: &cancellables)
    }

    /// Sesión desde un día del programa.
    static func forDay(_ day: TrainingDay, programId: Int?, scheduledDate: CalendarDate?) -> SessionLogViewModel {
        SessionLogViewModel(
            session: WorkoutSession(
                day: day,
                programId: programId,
                scheduledDate: scheduledDate,
                startedAt: Date()
            )
        )
    }

    /// Entreno libre.
    static func freeWorkout() -> SessionLogViewModel {
        SessionLogViewModel(session: .freeWorkout(startedAt: Date()))
    }

    // MARK: - Ciclo de vida

    func onAppear() {
        UIApplication.shared.isIdleTimerDisabled = true
        Analytics.track(Analytics.Event.sessionStarted, [
            Analytics.Property.dayId: session.dayId ?? -1,
            Analytics.Property.programId: session.programId ?? -1,
            Analytics.Property.isFreeWorkout: session.isFreeWorkout,
            Analytics.Property.plannedSetCount: session.prescribedSetCount
        ])
        Task { await notifier.refreshAuthorizationStatus() }
        startTicker()
    }

    func onDisappear() {
        UIApplication.shared.isIdleTimerDisabled = false
        stopTicker()
        notifier.cancel()
    }

    func dismissCoachMarks() {
        showsCoachMarks = false
        UserDefaults.standard.set(true, forKey: Self.coachMarksKey)
    }

    // MARK: - Reloj

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.now = date
                self.checkRestCompletion()
            }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private var didAnnounceRestEnd = false

    private func checkRestCompletion() {
        guard let timer = restController.timer else { return }
        if timer.isFinished(at: now) {
            guard !didAnnounceRestEnd else { return }
            didAnnounceRestEnd = true
            // Fin del descanso: éxito más dos toques ligeros separados (UX §8).
            HapticManager.shared.playSequence([
                (.success, 0),
                (.light, 0.12),
                (.light, 0.12)
            ])
            UIAccessibility.post(notification: .announcement, argument: "Rest done.")
        } else {
            didAnnounceRestEnd = false
        }
    }

    // MARK: - Series

    /// Marca una serie: rellena el check, arranca el descanso y encola.
    func markSet(exerciseId: UUID, setId: UUID) {
        guard let result = session.markSet(exerciseId: exerciseId, setId: setId, at: Date()) else { return }
        lastMark = result
        HapticManager.shared.play(.rigid)
        UIAccessibility.post(notification: .announcement, argument: result.announcement)

        Analytics.track(Analytics.Event.setLogged, [
            Analytics.Property.exerciseKey: session.exercise(id: exerciseId)?.exerciseKey ?? "",
            Analytics.Property.setNumber: result.set.setNumber,
            Analytics.Property.dayId: session.dayId ?? -1
        ])

        startRest(after: result)
        enqueue()
    }

    /// Desmarca. Si el cronómetro estaba corriendo por esa serie, se cancela (UX §5).
    func undoSet(exerciseId: UUID, setId: UUID) {
        guard session.undoSet(exerciseId: exerciseId, setId: setId) else { return }
        HapticManager.shared.play(.selection)
        cancelRest()
        enqueue()
    }

    func updateSet(exerciseId: UUID, setId: UUID, reps: Int? = nil, weightKg: Double?? = nil, rpe: Double?? = nil) {
        guard session.updateSet(exerciseId: exerciseId, setId: setId, reps: reps, weightKg: weightKg, rpe: rpe) else { return }
        enqueue()
    }

    func addSet(to exerciseId: UUID) {
        guard session.addSet(toExerciseId: exerciseId) != nil else { return }
        HapticManager.shared.play(.light)
        enqueue()
    }

    func removeSet(exerciseId: UUID, setId: UUID) {
        guard session.removeSet(exerciseId: exerciseId, setId: setId) else { return }
        enqueue()
    }

    // MARK: - Ejercicios

    func selectExercise(at index: Int) {
        guard session.exercises.indices.contains(index) else { return }
        session.activeExerciseIndex = index
        HapticManager.shared.play(.selection)
    }

    /// Cambia un ejercicio por otro del catálogo. Las series ya hechas se quedan con el original
    /// (decisión de WP3): reescribirlas sería inventarse un histórico.
    func swapExercise(exerciseId: UUID, with item: ExerciseCatalogItem) {
        guard let newId = session.swapExercise(exerciseId: exerciseId, with: item) else {
            banner = "That exercise is already finished."
            return
        }
        if let index = session.exercises.firstIndex(where: { $0.id == newId }) {
            session.activeExerciseIndex = index
        }
        HapticManager.shared.play(.light)
        enqueue()
    }

    func addExercise(_ item: ExerciseCatalogItem) {
        let id = session.addExercise(item, initialSetCount: 1)
        if let index = session.exercises.firstIndex(where: { $0.id == id }) {
            session.activeExerciseIndex = index
        }
        HapticManager.shared.play(.light)
        enqueue()
    }

    func removeExercise(id: UUID) {
        guard session.removeExercise(id: id) else { return }
        enqueue()
    }

    func addNote(_ text: String) {
        session.notes = text.isEmpty ? nil : text
        enqueue()
    }

    // MARK: - Cronómetro

    private func startRest(after result: MarkSetResult) {
        guard result.restSeconds > 0 else { return }
        restController.start(
            exerciseName: result.exerciseName,
            setNumber: result.set.setNumber,
            totalSets: result.totalSetsInExercise,
            seconds: result.restSeconds,
            at: Date()
        )
        didAnnounceRestEnd = false
        if let timer = restController.timer {
            notifier.schedule(for: timer)
        }
    }

    func skipRest() {
        guard restController.skip(at: Date()) else { return }
        HapticManager.shared.play(.selection)
        notifier.cancel()
        Analytics.track(Analytics.Event.restTimerSkipped, [
            Analytics.Property.dayId: session.dayId ?? -1
        ])
    }

    private func cancelRest() {
        restController.cancel()
        notifier.cancel()
    }

    @discardableResult
    func addThirtySeconds(fromNotification: Bool = false) -> Bool {
        guard restController.addThirtySeconds() else { return false }
        if !fromNotification { HapticManager.shared.play(.light) }
        didAnnounceRestEnd = false
        if let timer = restController.timer {
            notifier.reschedule(for: timer)
        }
        return true
    }

    /// Cambia la duración del descanso en curso, desde la hoja del cronómetro.
    func restartRest(seconds: Int, applyToExercise: Bool) {
        guard let timer = restController.timer else { return }
        if applyToExercise, let exercise = session.activeExercise,
           let index = session.exercises.firstIndex(where: { $0.id == exercise.id }) {
            session.exercises[index].restSeconds = seconds
        }
        restController.start(
            exerciseName: timer.exerciseName,
            setNumber: timer.setNumber,
            totalSets: timer.totalSets,
            seconds: seconds,
            at: Date()
        )
        didAnnounceRestEnd = false
        if let updated = restController.timer {
            notifier.reschedule(for: updated)
        }
    }

    var restLabel: String? { restController.label(at: now) }
    var restProgress: Double { restController.timer?.progress(at: now) ?? 0 }
    var isRestRunning: Bool { restController.isRunning(at: now) }
    var isRestFinished: Bool { restController.timer?.isFinished(at: now) ?? false }
    var isInFinalCountdown: Bool { restController.timer?.isInFinalCountdown(at: now) ?? false }
    var restAccessibilityValue: String? { restController.timer?.accessibilityValue(at: now) }

    // MARK: - Progreso

    var elapsedLabel: String { TrainingFormat.duration(session.durationSeconds(at: now)) }
    var progressText: String { session.progressText }

    /// La mejor serie de la sesión, para la celebración de nivel 1. **Nunca** es «Personal
    /// record»: eso lo dice el servidor.
    func bestSetCelebration(for exerciseKey: String, exerciseName: String) -> PersonalRecordCelebration? {
        guard let best = session.bestSetSoFar(forExerciseKey: exerciseKey) else { return nil }
        return Celebration.forLocalBestSet(
            exerciseName: exerciseName,
            best: best,
            unit: WeightUnitPreference.current.trainingUnit
        )
    }

    // MARK: - Cierre

    /// Cierra la sesión y la encola como `completed`.
    func finish() async -> WorkoutSession {
        session.finish(at: Date())
        cancelRest()
        let ok = await coordinator.enqueue(session, status: .completed)
        if !ok {
            banner = "Saved on your phone. We'll sync when you're back online."
        }
        return session
    }

    /// Salir sin terminar: lo marcado ya está guardado y encolado.
    func leaveWithoutFinishing() {
        cancelRest()
        enqueue()
    }

    // MARK: - Outbox

    private func enqueue() {
        let snapshot = session
        Task { [coordinator] in
            let ok = await coordinator.enqueue(snapshot, status: .inProgress)
            if !ok {
                await MainActor.run {
                    self.banner = "Saved on your phone. We'll sync when you're back online."
                }
            }
        }
    }

    deinit {
        #if DEBUG
        print("🗑️ SessionLogViewModel deinitialized")
        #endif
    }
}
