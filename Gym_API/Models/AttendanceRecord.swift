//
//  AttendanceRecord.swift
//  Gym_API
//
//  Created by Claude on 2026-01-31.
//

import Foundation

/// Modelo para representar un registro de asistencia del backend
struct AttendanceRecord: Codable {
    let id: Int
    let userId: Int
    let classId: Int
    let checkinTime: Date
    let checkoutTime: Date?
    let status: String?
    let classDetails: ClassDetails?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case classId = "class_id"
        case checkinTime = "checkin_time"
        case checkoutTime = "checkout_time"
        case status
        case classDetails = "class_details"
    }
}

/// Detalles de la clase asociada al registro de asistencia
struct ClassDetails: Codable {
    let id: Int
    let title: String
    let instructor: String
    let startTime: Date
    let endTime: Date
    let description: String?
    let maxCapacity: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case instructor
        case startTime = "start_time"
        case endTime = "end_time"
        case description
        case maxCapacity = "max_capacity"
    }
}