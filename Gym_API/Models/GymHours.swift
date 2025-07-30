//
//  GymHours.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import Foundation

// MARK: - Gym Hours Model
struct GymHours: Codable, Identifiable, Equatable {
    let dayOfWeek: Int
    let openTime: Date?
    let closeTime: Date?
    let isClosed: Bool
    let id: Int
    let gymId: Int
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case openTime = "open_time"
        case closeTime = "close_time"
        case isClosed = "is_closed"
        case id
        case gymId = "gym_id"
    }
    
    // MARK: - Computed Properties
    var dayName: String {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return dayNames[safe: dayOfWeek] ?? "Unknown"
    }
    
    var dayNameSpanish: String {
        let dayNames = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
        return dayNames[safe: dayOfWeek] ?? "Desconocido"
    }
    
    var isOpen: Bool {
        return !isClosed && openTime != nil && closeTime != nil
    }
    
    var hoursDisplay: String {
        if isClosed {
            return "Closed"
        }
        
        guard let openTime = openTime, let closeTime = closeTime else {
            return "Closed"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        return "\(formatter.string(from: openTime)) - \(formatter.string(from: closeTime))"
    }
    
    var hoursDisplaySpanish: String {
        if isClosed {
            return "Cerrado"
        }
        
        guard let openTime = openTime, let closeTime = closeTime else {
            return "Cerrado"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        return "\(formatter.string(from: openTime)) - \(formatter.string(from: closeTime))"
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}