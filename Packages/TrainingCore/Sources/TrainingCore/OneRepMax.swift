//
//  OneRepMax.swift
//  TrainingCore
//
//  1RM estimado por Epley, elegibilidad de una serie y cifras redondas por unidad (plan §4.5).
//
//  Aviso que vale para todo el módulo: aquí NO se decide una marca personal. Las marcas las
//  calcula el servidor cuando el registro se sincroniza con `status = completed`. Lo que esto
//  produce es lo que el cliente puede afirmar sin mentir: un 1RM estimado y una «mejor serie
//  hasta ahora».
//

import Foundation

public enum OneRepMax {

    /// A partir de 13 repeticiones la fórmula de Epley se dispara y deja de significar nada,
    /// así que la serie no estima 1RM ni opta a marca.
    public static let maximumEligibleReps = 12

    // MARK: - Fórmula

    /// Epley: `peso × (1 + reps ÷ 30)`. Con una sola repetición, el 1RM es el peso levantado.
    ///
    /// Devuelve `nil` cuando la serie no es elegible: calentamiento, más de 12 repeticiones,
    /// cero repeticiones o ejercicio sin peso (el mérito entonces es en repeticiones, no en carga).
    public static func estimate(weightKg: Double?, reps: Int, isWarmup: Bool = false) -> Double? {
        guard isEligible(reps: reps, weightKg: weightKg, isWarmup: isWarmup) else { return nil }
        guard let weightKg else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    /// Una serie es elegible para 1RM y para marca si no es de calentamiento, tiene entre 1 y 12
    /// repeticiones y lleva un peso mayor que cero.
    public static func isEligible(reps: Int, weightKg: Double?, isWarmup: Bool = false) -> Bool {
        guard !isWarmup else { return false }
        guard reps >= 1, reps <= maximumEligibleReps else { return false }
        guard let weightKg, weightKg > 0 else { return false }
        return true
    }

    /// Peso que habría que mover a `reps` repeticiones para igualar un 1RM dado.
    /// Es la inversa de Epley y sirve para traducir `load_mode = percent_1rm` a una carga.
    public static func weight(forE1RM e1rmKg: Double, reps: Int) -> Double? {
        guard e1rmKg > 0, reps >= 1, reps <= maximumEligibleReps else { return nil }
        return e1rmKg / (1 + Double(reps) / 30)
    }

    /// Carga prescrita como porcentaje del 1RM, redondeada al paso de la unidad.
    public static func load(forPercent percent: Double, ofE1RM e1rmKg: Double, unit: TrainingWeightUnit) -> Double {
        let raw = e1rmKg * percent / 100
        return roundToStep(kilograms: raw, unit: unit)
    }

    // MARK: - Redondeo

    /// Redondea una carga en kilos al escalón real de la unidad que ve el cliente
    /// (5 lb o 2,5 kg), y devuelve el resultado en kilos.
    public static func roundToStep(kilograms: Double, unit: TrainingWeightUnit) -> Double {
        guard kilograms.isFinite, kilograms > 0 else { return 0 }
        let inUnit = unit.fromKilograms(kilograms)
        let step = unit.loadStep
        let snapped = (inUnit / step).rounded() * step
        return unit.toKilograms(snapped)
    }

    // MARK: - Cifras redondas (celebración de nivel 3, plan §4.5 y UX §7)

    /// Las cifras que la gente celebra en cada unidad. No son todas las redondas: son las que
    /// significan algo en un gimnasio (los discos que caben en la barra).
    public static func milestones(for unit: TrainingWeightUnit) -> [Double] {
        switch unit {
        case .pounds: return [135, 185, 225, 275, 315, 365, 405, 495]
        case .kilograms: return [60, 80, 100, 120, 140, 160, 180, 200]
        }
    }

    /// Cifra redonda que alcanza o supera esta carga por primera vez.
    ///
    /// `previousBestKg` es la mejor carga anterior del ejercicio: si ya estaba por encima del
    /// hito, no hay nada que celebrar. Devuelve el hito **en la unidad del cliente**, que es
    /// como se lee en pantalla ("315 lb"), no en kilos.
    public static func milestoneReached(
        weightKg: Double,
        previousBestKg: Double?,
        unit: TrainingWeightUnit
    ) -> Double? {
        guard weightKg.isFinite, weightKg > 0 else { return nil }
        let current = unit.fromKilograms(weightKg)
        let previous = previousBestKg.map { unit.fromKilograms($0) } ?? 0
        // Tolerancia de medio escalón: 224,7 lb convertidas desde kilos son 225 lb en la barra.
        let tolerance = unit.loadStep / 2
        return milestones(for: unit)
            .filter { current + tolerance >= $0 && previous + tolerance < $0 }
            .max()
    }
}

// MARK: - Mejor serie local

/// La mejor serie de un ejercicio dentro de lo que la app conoce **sin haber sincronizado**.
///
/// Se llama «best set so far» en pantalla, nunca «Personal record»: eso lo dice el servidor.
public struct BestSetSoFar: Hashable, Sendable {

    public let exerciseKey: String
    public let setNumber: Int
    public let reps: Int
    public let weightKg: Double?
    public let e1rmKg: Double?

    public init(exerciseKey: String, setNumber: Int, reps: Int, weightKg: Double?, e1rmKg: Double?) {
        self.exerciseKey = exerciseKey
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.e1rmKg = e1rmKg
    }

    /// Criterio de comparación, en el orden de prioridad del plan §4.5: e1RM, luego peso,
    /// luego repeticiones.
    public var rank: (Double, Double, Int) {
        (e1rmKg ?? 0, weightKg ?? 0, reps)
    }

    public func isBetter(than other: BestSetSoFar) -> Bool {
        rank > other.rank
    }
}
