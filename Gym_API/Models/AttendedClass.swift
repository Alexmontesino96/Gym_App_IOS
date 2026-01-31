//
//  AttendedClass.swift
//  Gym_API
//
//  Created by Claude on 2026-01-31.
//

import Foundation

/// Modelo que representa una clase a la que el usuario asistió
struct AttendedClass: Identifiable, Codable, Equatable {
    let id: Int
    let classId: Int
    let className: String
    let instructor: String
    let startTime: Date
    let endTime: Date
    let checkinTime: Date
    let checkoutTime: Date?

    // MARK: - Computed Properties

    /// Indica si la clase fue completada recientemente (menos de 2 horas)
    var isRecentlyCompleted: Bool {
        guard let checkout = checkoutTime else {
            // Si no hay checkout, verificar si han pasado menos de 2 horas desde el checkin
            return Date().timeIntervalSince(checkinTime) < 7200
        }
        return Date().timeIntervalSince(checkout) < 7200 // 2 horas en segundos
    }

    /// Texto que indica hace cuánto tiempo fue la clase
    var timeAgoText: String {
        let now = Date()
        let referenceTime = checkoutTime ?? checkinTime
        let interval = now.timeIntervalSince(referenceTime)

        if interval < 3600 { // Menos de 1 hora
            let minutes = Int(interval / 60)
            if minutes < 1 {
                return "Recién terminada"
            }
            return "Hace \(minutes) min"
        } else if interval < 86400 { // Menos de 1 día
            let hours = Int(interval / 3600)
            return "Hace \(hours) hora\(hours == 1 ? "" : "s")"
        } else { // Días
            let days = Int(interval / 86400)
            return "Hace \(days) día\(days == 1 ? "" : "s")"
        }
    }

    /// Fecha formateada para mostrar
    var displayDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(startTime) {
            return "Hoy"
        } else if calendar.isDateInYesterday(startTime) {
            return "Ayer"
        } else if let daysAgo = calendar.dateComponents([.day], from: startTime, to: Date()).day,
                  daysAgo < 7 {
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateFormat = "EEEE" // Día de la semana
            return formatter.string(from: startTime).capitalized
        } else {
            formatter.dateFormat = "d MMM"
            return formatter.string(from: startTime)
        }
    }

    /// Hora de la clase formateada
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    /// Duración de la asistencia del usuario
    var attendanceDuration: String {
        guard let checkout = checkoutTime else {
            return "En progreso"
        }

        let duration = checkout.timeIntervalSince(checkinTime)
        let minutes = Int(duration / 60)

        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hora\(hours == 1 ? "" : "s")"
            }
            return "\(hours)h \(remainingMinutes)min"
        }
    }

    /// Indica si la clase está dentro de la última semana
    var isWithinLastWeek: Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return checkinTime > oneWeekAgo
    }

    /// Badge de estado para mostrar en UI
    var statusBadge: (text: String, color: String)? {
        if isRecentlyCompleted {
            return ("Reciente", "green")
        } else if displayDate == "Hoy" {
            return ("Hoy", "blue")
        } else if displayDate == "Ayer" {
            return ("Ayer", "orange")
        }
        return nil
    }
}

// MARK: - Mock Data for Testing

#if DEBUG
extension AttendedClass {
    static let mockData: [AttendedClass] = [
        AttendedClass(
            id: 1,
            classId: 101,
            className: "CrossFit Intensivo",
            instructor: "Carlos López",
            startTime: Date().addingTimeInterval(-3600), // Hace 1 hora
            endTime: Date().addingTimeInterval(-600), // Terminó hace 10 min
            checkinTime: Date().addingTimeInterval(-3600),
            checkoutTime: Date().addingTimeInterval(-600)
        ),
        AttendedClass(
            id: 2,
            classId: 102,
            className: "Yoga Flow",
            instructor: "Ana Martínez",
            startTime: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            endTime: Calendar.current.date(byAdding: .hour, value: -23, to: Date())!,
            checkinTime: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            checkoutTime: Calendar.current.date(byAdding: .hour, value: -23, to: Date())!
        ),
        AttendedClass(
            id: 3,
            classId: 103,
            className: "HIIT Cardio",
            instructor: "Miguel Rodríguez",
            startTime: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            endTime: Calendar.current.date(byAdding: .hour, value: -71, to: Date())!,
            checkinTime: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            checkoutTime: Calendar.current.date(byAdding: .hour, value: -71, to: Date())!
        )
    ]
}
#endif