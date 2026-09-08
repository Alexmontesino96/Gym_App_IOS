//
//  DayEditorViewModel.swift
//  Gym_API
//
//  El estado del editor de día (S21).
//
//  Vive fuera de la vista por tres razones concretas:
//
//  1. `PUT /programs/{id}/days/{n}` es un **reemplazo completo**. El cuerpo que se envía tiene
//     que ser exactamente lo que se ve; construirlo desde media docena de `@State` sueltos es la
//     manera de que un campo se quede atrás y borre una nota o una superserie.
//  2. «Discard changes?» necesita saber si de verdad hay cambios. Eso es comparar dos estructuras,
//     no adivinar por un booleano que alguien tiene que acordarse de poner a `true`.
//  3. Los ajustes por paso (series, reps, RPE, descanso, carga) son aritmética con límites del
//     contrato, y el cuerpo de una vista no es sitio para límites.
//

import Foundation
import SwiftUI
import TrainingCore

@MainActor
final class DayEditorViewModel: ObservableObject {

    // MARK: - Identidad

    let programId: Int
    let dayNumber: Int
    let client: TrainingClientRef

    /// El día ya existía en base. Un día nuevo se crea con el primer guardado.
    private(set) var existed: Bool

    // MARK: - Estado editable

    @Published var name: String
    @Published var isRest: Bool
    @Published var focus: String
    @Published var dayNotes: String
    @Published private(set) var exercises: [DayExerciseInput]

    /// El valor recordado de cada modo de carga, por ejercicio. Ver `LoadDraft`.
    @Published private(set) var loadDrafts: [UUID: LoadDraft] = [:]

    // MARK: - Estado de la pantalla

    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    /// Se enciende 300 ms al guardar bien: es el *morphing success* de la UX antes de cerrar.
    @Published private(set) var showsSuccess = false

    // MARK: - Instantánea para «Discard changes?»

    private var snapshot: Snapshot

    private struct Snapshot: Equatable {
        var name: String
        var isRest: Bool
        var focus: String
        var dayNotes: String
        var exercises: [DayExerciseInput]
    }

    // MARK: - Límites del contrato

    /// `check sets_count between 1 and 20` (plan §5).
    static let setsRange = 1...20
    /// El descanso se ajusta de 15 en 15 segundos, que es el escalón con el que se habla.
    static let restStep = 15
    static let restRange = 0...600
    /// RPE de 5 a 10 en pasos de 0,5. Por debajo de 5 nadie prescribe.
    static let rpeRange = 5.0...10.0
    static let rpeStep = 0.5
    /// El porcentaje de 1RM se mueve de 5 en 5.
    static let percentStep = 5.0
    static let repsRange = 1...50

    // MARK: - Init

    init(day: TrainingDay?, programId: Int, dayNumber: Int, client: TrainingClientRef) {
        self.programId = programId
        self.dayNumber = dayNumber
        self.client = client
        self.existed = day?.exists ?? false

        let inputs = (day?.exercisesInOrder ?? []).map(DayExerciseInput.init(from:))
        self.name = day?.name ?? ""
        self.isRest = day?.isRest ?? true
        self.focus = day?.focus ?? ""
        self.dayNotes = day?.notes ?? ""
        self.exercises = inputs
        self.snapshot = Snapshot(
            name: day?.name ?? "",
            isRest: day?.isRest ?? true,
            focus: day?.focus ?? "",
            dayNotes: day?.notes ?? "",
            exercises: inputs
        )
        self.loadDrafts = Dictionary(
            uniqueKeysWithValues: inputs.map { ($0.localId, LoadDraft(mode: $0.loadMode, value: $0.loadValue)) }
        )
    }

    // MARK: - Derivados

    var hasChanges: Bool { current != snapshot }

    /// Un día de descanso no lleva ejercicios; uno de entreno sin ninguno no tiene nada que
    /// guardar. En los dos casos el botón sigue activo: vaciar un día es una edición legítima.
    var canSave: Bool { !isSaving }

    var weekNumber: Int { WeekMath.weekNumber(forDayNumber: dayNumber) }

    /// «Thursday · Upper B»
    var title: String {
        let weekday = TrainingWeekday.name(forDayNumber: dayNumber)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? weekday : "\(weekday) · \(trimmed)"
    }

    private var current: Snapshot {
        Snapshot(name: name, isRest: isRest, focus: focus, dayNotes: dayNotes, exercises: exercises)
    }

    func index(of id: UUID) -> Int? { exercises.firstIndex { $0.localId == id } }

    func loadDraft(for id: UUID) -> LoadDraft {
        loadDrafts[id] ?? LoadDraft(mode: .weight, value: nil)
    }

    /// Posición «1», «2», «3a», «3b» de cada ejercicio, con la misma regla de superseries que
    /// usa el cliente en S17 y S11.
    var positionLabels: [String] {
        TrainingPrescription.positionLabels(for: exercises.enumerated().map { index, input in
            input.previewExercise(id: index + 1)
        })
    }

    // MARK: - Lista

    func add(_ item: ExerciseCatalogItem) {
        var input = DayExerciseInput(
            exerciseKey: item.exerciseKey,
            exerciseName: item.name,
            exerciseId: item.id,
            orderIndex: exercises.count,
            setsCount: 3,
            reps: "5",
            loadMode: item.category == .strength ? .weight : .bodyweight,
            restSeconds: item.defaultRestSeconds
        )
        input.orderIndex = exercises.count
        exercises.append(input)
        loadDrafts[input.localId] = LoadDraft(mode: input.loadMode, value: nil)
        // Un día con ejercicios deja de ser descanso: si no, se guardaría un descanso con lista.
        if isRest { isRest = false }
    }

    func remove(id: UUID) {
        exercises.removeAll { $0.localId == id }
        loadDrafts[id] = nil
        renumber()
    }

    /// Acción de accesibilidad *Move up*: arrastrar no es una vía para quien usa VoiceOver o
    /// Control por conmutador (checklist §10.18).
    @discardableResult
    func moveUp(id: UUID) -> Bool {
        guard let index = index(of: id), index > 0 else { return false }
        exercises.swapAt(index, index - 1)
        renumber()
        return true
    }

    @discardableResult
    func moveDown(id: UUID) -> Bool {
        guard let index = index(of: id), index < exercises.count - 1 else { return false }
        exercises.swapAt(index, index + 1)
        renumber()
        return true
    }

    /// Suelta el ejercicio `id` en la posición del ejercicio `target`. Es lo que hace el
    /// arrastre: `onMove` no existe fuera de una `List`, así que el editor lo resuelve con
    /// `draggable`/`dropDestination` y esta operación.
    @discardableResult
    func move(id: UUID, toPositionOf target: UUID) -> Bool {
        guard id != target,
              let from = index(of: id),
              let to = index(of: target) else { return false }
        let item = exercises.remove(at: from)
        exercises.insert(item, at: to)
        renumber()
        return true
    }

    private func renumber() {
        for index in exercises.indices {
            exercises[index].orderIndex = index
        }
    }

    // MARK: - Edición de un ejercicio

    private func update(_ id: UUID, _ change: (inout DayExerciseInput) -> Void) {
        guard let index = index(of: id) else { return }
        change(&exercises[index])
    }

    func adjustSets(id: UUID, by delta: Int) {
        update(id) { exercise in
            let value = exercise.setsCount + delta
            exercise.setsCount = min(max(Self.setsRange.lowerBound, value), Self.setsRange.upperBound)
        }
    }

    /// Los steppers de repeticiones solo tienen sentido con un número; «AMRAP» o «8-10» se
    /// escriben a mano y los dejan apagados.
    func repsAreNumeric(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && Int(trimmed) != nil
    }

    func adjustReps(id: UUID, by delta: Int) {
        update(id) { exercise in
            guard let value = Int(exercise.reps.trimmingCharacters(in: .whitespaces)) else { return }
            let next = value + delta
            exercise.reps = String(min(max(Self.repsRange.lowerBound, next), Self.repsRange.upperBound))
        }
    }

    func setReps(id: UUID, text: String) {
        update(id) { $0.reps = String(text.prefix(16)) }
    }

    func adjustRPE(id: UUID, by steps: Int) {
        update(id) { exercise in
            guard steps != 0 else { return }
            // Sin RPE, el primer toque arriba lo pone en 8, que es donde vive casi toda
            // prescripción; el primer toque abajo lo deja sin objetivo otra vez.
            guard let current = exercise.rpeTarget else {
                exercise.rpeTarget = steps > 0 ? 8 : nil
                return
            }
            let next = current + Double(steps) * Self.rpeStep
            if next < Self.rpeRange.lowerBound {
                exercise.rpeTarget = nil
            } else {
                exercise.rpeTarget = min(next, Self.rpeRange.upperBound)
            }
        }
    }

    func adjustRest(id: UUID, by steps: Int) {
        update(id) { exercise in
            let next = exercise.restSeconds + steps * Self.restStep
            exercise.restSeconds = min(max(Self.restRange.lowerBound, next), Self.restRange.upperBound)
        }
    }

    func setLoadMode(id: UUID, mode: TrainingLoadMode) {
        var draft = loadDraft(for: id)
        draft.select(mode)
        loadDrafts[id] = draft
        update(id) { exercise in
            exercise.loadMode = mode
            exercise.loadValue = draft.loadValue
        }
    }

    /// Ajusta la carga en el paso que corresponda al modo: el de la unidad del cliente en
    /// `weight` (5 lb / 2,5 kg, plan §2.2) y 5 puntos en `% of 1RM`.
    func adjustLoad(id: UUID, by steps: Int, unit: WeightUnit) {
        var draft = loadDraft(for: id)
        guard draft.hasNumericField else { return }

        let next: Double?
        switch draft.mode {
        case .weight:
            let step = unit.loadStep
            let displayed = draft.loadValue.map { unit.loadValue(kilograms: $0) } ?? 0
            let value = max(0, displayed + Double(steps) * step)
            next = value == 0 ? nil : unit.kilograms(fromLoad: value)
        case .percent1RM:
            let value = (draft.loadValue ?? 0) + Double(steps) * Self.percentStep
            let clamped = min(max(0, value), 100)
            next = clamped == 0 ? nil : clamped
        case .rpe, .bodyweight:
            next = nil
        }

        draft.setValue(next)
        loadDrafts[id] = draft
        update(id) { $0.loadValue = draft.loadValue }
    }

    func setSuperset(id: UUID, group: String?) {
        update(id) { $0.supersetGroup = group }
    }

    func setNote(id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        update(id) { $0.notes = trimmed.isEmpty ? nil : String(text.prefix(200)) }
    }

    // MARK: - Guardar

    /// El cuerpo exacto que viaja. `order_index` se renumera dentro de `DayUpsertRequest`.
    func request() -> DayUpsertRequest {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFocus = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = dayNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return DayUpsertRequest(
            name: trimmedName.isEmpty ? nil : trimmedName,
            isRest: isRest,
            focus: trimmedFocus.isEmpty ? nil : trimmedFocus,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            isPublished: true,
            exercises: isRest ? [] : exercises
        )
    }

    /// Guarda y devuelve `true` si el día quedó escrito.
    ///
    /// Un fallo **no cierra la pantalla ni limpia nada** (UX §6, S21): lo que se acaba de escribir
    /// sigue en el formulario y el mensaje lo dice con esas palabras.
    func save(using service: TrainingService) async -> Bool {
        guard !isSaving else { return false }
        // Antes de cualquier await: dos toques en «Save» serían dos reemplazos del mismo día.
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let body = request()
        guard let day = await service.saveDay(programId: programId, dayNumber: dayNumber, body) else {
            errorMessage = service.saveErrorMessage ?? "Couldn't save. Your changes are still here."
            service.saveErrorMessage = nil
            return false
        }

        existed = day.exists
        snapshot = current
        if !isRest {
            TrainingRecentExercises.remember(exercises.map(\.exerciseKey), forClient: client.id)
        }
        showsSuccess = true
        HapticManager.shared.play(.success)
        return true
    }

    /// Duplica este día a los mismos días de la semana indicados.
    func duplicate(toWeeks weeks: [Int], using service: TrainingService) async -> DuplicateResult? {
        let weekday = WeekMath.weekdayIndex(forDayNumber: dayNumber)
        let targets = weeks.map { ($0 - 1) * WeekMath.daysPerWeek + weekday }
        guard !targets.isEmpty else { return nil }

        errorMessage = nil
        let result = await service.duplicateDay(
            programId: programId,
            dayNumber: dayNumber,
            DuplicateDayRequest(targetDayNumbers: targets)
        )
        if result == nil {
            errorMessage = service.saveErrorMessage ?? "Couldn't copy this day."
            service.saveErrorMessage = nil
        } else {
            HapticManager.shared.play(.success)
        }
        return result
    }

    deinit {
        #if DEBUG
        print("🗑️ DayEditorViewModel deinitialized")
        #endif
    }
}
