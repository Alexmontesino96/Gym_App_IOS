//
//  TrainerModels.swift
//  Gym_API
//
//  Lo que el ENTRENADOR ve de sus clientes en el panel: quién viene hoy y qué le han contado
//  esta semana. Son composiciones de datos que ya existen; ninguna inventa nada.
//

import Foundation

/// Una sesión de hoy con la persona que viene a ella.
///
/// La sesión sale de `ClassService.sessions`, que ya está cargada al arrancar; el cliente se
/// resuelve con `GET /schedule/participation/participants/{session_id}` cruzado con la lista de
/// clientes del espacio, que es de donde salen la foto y el nombre.
struct SessionRosterEntry: Identifiable {
    let session: ClassSession
    let className: String
    /// Nil si la sesión no tiene a nadie inscrito o si el inscrito no está en la cartera.
    let client: ClientSummary?

    var id: Int { session.id }

    var gymTimeZone: TimeZone {
        TimeZone(identifier: session.timeInfo.gymTimezone) ?? .current
    }
}

/// El último check-in semanal de un cliente, con el cliente al lado para pintarlo.
struct ClientCheckIn: Identifiable, Equatable {
    let client: ClientSummary
    let checkIn: WeeklyCheckIn

    var id: Int { checkIn.id }

    /// Solo se enseña lo que la persona escribió. Sin nota y sin escalas no hay nada que contar.
    var hasSomethingToSay: Bool {
        let nota = checkIn.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !nota.isEmpty || checkIn.energy != nil || checkIn.sleep != nil || checkIn.soreness != nil
    }
}

/// Una fila de `GET /schedule/participation/participants/{session_id}`.
/// Solo se leen los tres campos que hacen falta; el resto del esquema se ignora.
struct SessionParticipantRow: Decodable {
    let sessionId: Int
    let memberId: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case memberId = "member_id"
        case status
    }

    /// Cuenta como «viene» si está inscrito o ya ha asistido. Cancelados y no-shows, no.
    var isActive: Bool {
        let s = status.uppercased()
        return s == "REGISTERED" || s == "ATTENDED"
    }
}
