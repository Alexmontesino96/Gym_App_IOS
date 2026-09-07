//
//  TrainingPrescription.swift
//  Gym_API
//
//  Cómo se lee una prescripción en pantalla y en voz alta (UX §5, S17 y S11).
//
//  Está aquí y no en cada vista porque S17 y S11 tienen que decir exactamente lo mismo: si el
//  detalle del día promete «4 × 5 @ RPE 8» y la pantalla de registro dice otra cosa, la persona
//  deja de fiarse de las dos.
//

import Foundation
import TrainingCore

enum TrainingPrescription {

    /// «4 × 5 @ RPE 8 · rest 2:00» / «3 × 8-10 · 60% · rest 1:30».
    static func text(for exercise: TrainingDayExercise, unit: WeightUnit, includeRest: Bool = true) -> String {
        var parts = ["\(exercise.setsCount) × \(exercise.reps)"]

        switch exercise.loadMode {
        case .weight:
            if let load = exercise.loadValue {
                parts.append(unit.loadLabel(kilograms: load))
            }
        case .percent1RM:
            if let load = exercise.loadValue {
                parts.append("\(Celebration.number(load))%")
            }
        case .rpe:
            break
        case .bodyweight:
            parts.append("bodyweight")
        }

        var text = parts.joined(separator: " · ")
        if let rpe = exercise.rpeTarget {
            text += " @ RPE \(Celebration.number(rpe))"
        }
        if includeRest, exercise.restSeconds > 0 {
            text += " · rest \(clock(exercise.restSeconds))"
        }
        return text
    }

    /// «4 sets of 5 reps at RPE 8. Rest 2 minutes.»
    static func spoken(for exercise: TrainingDayExercise, unit: WeightUnit) -> String {
        var text = "\(exercise.setsCount) set\(exercise.setsCount == 1 ? "" : "s") of \(spokenReps(exercise.reps))"

        switch exercise.loadMode {
        case .weight:
            if let load = exercise.loadValue {
                let value = Celebration.number(unit.fromKilograms(load))
                text += " at \(value) \(unit == .pounds ? "pounds" : "kilograms")"
            }
        case .percent1RM:
            if let load = exercise.loadValue {
                text += " at \(Celebration.number(load)) percent of your one rep max"
            }
        case .bodyweight:
            text += " with bodyweight"
        case .rpe:
            break
        }

        if let rpe = exercise.rpeTarget {
            text += " at RPE \(Celebration.number(rpe))"
        }
        text += "."
        if exercise.restSeconds > 0 {
            text += " Rest \(spokenRest(exercise.restSeconds))."
        }
        return text
    }

    /// «2:00» / «45s»
    static func clock(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds)s" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func spokenRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = seconds / 60
        let rest = seconds % 60
        var text = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        if rest > 0 { text += " \(rest) seconds" }
        return text
    }

    private static func spokenReps(_ reps: String) -> String {
        let trimmed = reps.trimmingCharacters(in: .whitespaces)
        if trimmed.uppercased().contains("AMRAP") { return "as many reps as possible" }
        if trimmed.contains("-") {
            let parts = trimmed.components(separatedBy: "-")
            if parts.count == 2 { return "\(parts[0]) to \(parts[1]) reps" }
        }
        return "\(trimmed) reps"
    }

    // MARK: - Superseries

    /// Etiqueta de posición de cada ejercicio: «1», «2», «3a», «3b».
    ///
    /// Solo pone letra cuando el grupo tiene de verdad más de un ejercicio: un `superset_group`
    /// suelto no convierte un ejercicio normal en «1a».
    static func positionLabels(for exercises: [TrainingDayExercise]) -> [String] {
        var labels: [String] = []
        var position = 0
        var previousGroup: String?
        var letterIndex = 0

        let groupCounts = Dictionary(grouping: exercises.compactMap(\.supersetGroup), by: { $0 })
            .mapValues(\.count)

        for exercise in exercises {
            let group = exercise.supersetGroup
            let isRealSuperset = group.map { (groupCounts[$0] ?? 0) > 1 } ?? false

            if !isRealSuperset || group != previousGroup {
                position += 1
                letterIndex = 0
            } else {
                letterIndex += 1
            }
            previousGroup = group

            if isRealSuperset {
                let letter = String(UnicodeScalar(UInt8(97 + min(letterIndex, 25))))
                labels.append("\(position)\(letter)")
            } else {
                labels.append("\(position)")
            }
        }
        return labels
    }

    /// Nombre de los compañeros de superserie de un ejercicio, para el pie y para VoiceOver.
    static func supersetPartnerNames(of exercise: TrainingDayExercise, in exercises: [TrainingDayExercise]) -> [String] {
        guard let group = exercise.supersetGroup else { return [] }
        return exercises
            .filter { $0.supersetGroup == group && $0.id != exercise.id }
            .map(\.exerciseName)
    }
}
