//
//  TrainerTrainingRoute.swift
//  Gym_API
//
//  Destinos de navegación del panel del ENTRENADOR (UX §2, tabla del entrenador).
//
//  Valores, no vistas, por lo mismo que en el lado del cliente: una fila del buzón, una fila de
//  la lista de clientes y un deep link de push llegan a la misma pantalla sin que ninguno de los
//  tres conozca a los otros dos.
//

import Foundation
import TrainingCore

/// Quién es el cliente que se está mirando.
///
/// Viaja entero por la ruta porque el nombre aparece en el microcopy de las cuatro pantallas
/// («Note for Dana», «Recently used with Dana», «Sent to Dana») y volver a pedirlo en cada una
/// pintaría un hueco durante la primera fracción de segundo.
struct TrainingClientRef: Hashable, Identifiable {

    let id: Int
    let name: String
    let pictureURL: String?

    init(id: Int, name: String, pictureURL: String? = nil) {
        self.id = id
        self.name = name
        self.pictureURL = pictureURL
    }

    init(client: ClientSummary) {
        self.init(id: client.id, name: client.displayName, pictureURL: client.pictureURL)
    }

    /// El nombre de pila, que es como habla la UX: «Dana has no program yet.»
    var firstName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "your client" }
        return trimmed.components(separatedBy: " ").first ?? trimmed
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let letters = parts.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}

enum TrainerTrainingRoute: Hashable {
    /// Ficha del cliente: cabecera, programas, registros recientes y check-ins.
    case clientDetail(TrainingClientRef)
    /// S20 · Client programs.
    case clientPrograms(TrainingClientRef)
    /// S22 · Log review. El cliente puede no conocerse todavía (deep link de push).
    case logReview(logId: Int, client: TrainingClientRef?)
    /// S15 en modo lectura sobre un cliente (UX §2: S22 → nombre de ejercicio).
    case clientExerciseHistory(client: TrainingClientRef, key: String, name: String)
}

/// Hojas del panel del entrenador. Todas llevan cierre textual (checklist §10.9).
enum TrainerTrainingSheet: Identifiable, Hashable {
    /// S21 · Day editor.
    case dayEditor(programId: Int, dayNumber: Int, client: TrainingClientRef)
    /// S23 · Day note.
    case dayNote(client: TrainingClientRef, date: CalendarDate)
    /// Asignar un programa a un cliente.
    case assignProgram(client: TrainingClientRef)

    var id: String {
        switch self {
        case .dayEditor(let programId, let dayNumber, let client):
            return "day-\(programId)-\(dayNumber)-\(client.id)"
        case .dayNote(let client, let date):
            return "note-\(client.id)-\(date.iso)"
        case .assignProgram(let client):
            return "assign-\(client.id)"
        }
    }
}
