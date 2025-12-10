//
//  Attendance.swift
//  Gym_API
//
//  Created by Claude Code on 12/1/25.
//

import Foundation

// MARK: - Request Models

/// Request body para check-in con código QR
struct AttendanceCheckInRequest: Codable {
    let qrCode: String
    let sessionId: Int?

    enum CodingKeys: String, CodingKey {
        case qrCode = "qr_code"
        case sessionId = "session_id"
    }
}

// MARK: - Response Models

/// Respuesta del endpoint de check-in
struct AttendanceCheckInResponse: Codable {
    let success: Bool
    let message: String
    let session: AttendanceSession?
}

/// Información de la sesión en la respuesta de check-in
struct AttendanceSession: Codable, Identifiable {
    let id: Int
    let startTime: Date?
    let endTime: Date?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case name
    }

    // MARK: - Computed Properties

    var formattedStartTime: String {
        guard let startTime = startTime else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }

    var formattedEndTime: String {
        guard let endTime = endTime else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endTime)
    }

    var timeRange: String {
        guard startTime != nil && endTime != nil else { return "N/A" }
        return "\(formattedStartTime) - \(formattedEndTime)"
    }
}

// MARK: - Error Models

/// Estructura de error del backend
struct AttendanceError: Codable {
    let detail: String
}

/// Errores específicos de check-in
enum AttendanceCheckInError: LocalizedError {
    case noClassesAvailable
    case sessionNotFound
    case outsideCheckInWindow
    case alreadyCheckedIn
    case invalidQRCode
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noClassesAvailable:
            return "No hay clases disponibles para check-in en este momento"
        case .sessionNotFound:
            return "Sesión no encontrada o no pertenece a este gimnasio"
        case .outsideCheckInWindow:
            return "La sesión está fuera del horario de check-in (±30 minutos)"
        case .alreadyCheckedIn:
            return "Este miembro ya hizo check-in en esta clase"
        case .invalidQRCode:
            return "Código QR inválido"
        case .unauthorized:
            return "No tienes permisos para realizar check-in"
        case .networkError(let message):
            return message
        }
    }

    var title: String {
        switch self {
        case .noClassesAvailable:
            return "Sin Clases Disponibles"
        case .sessionNotFound:
            return "Sesión No Encontrada"
        case .outsideCheckInWindow:
            return "Fuera de Horario"
        case .alreadyCheckedIn:
            return "Check-in Existente"
        case .invalidQRCode:
            return "QR Inválido"
        case .unauthorized:
            return "No Autorizado"
        case .networkError:
            return "Error de Conexión"
        }
    }

    var icon: String {
        switch self {
        case .noClassesAvailable:
            return "calendar.badge.exclamationmark"
        case .sessionNotFound:
            return "magnifyingglass.circle"
        case .outsideCheckInWindow:
            return "clock.badge.exclamationmark"
        case .alreadyCheckedIn:
            return "checkmark.circle.badge.xmark"
        case .invalidQRCode:
            return "qrcode.viewfinder"
        case .unauthorized:
            return "lock.shield"
        case .networkError:
            return "wifi.exclamationmark"
        }
    }
}
