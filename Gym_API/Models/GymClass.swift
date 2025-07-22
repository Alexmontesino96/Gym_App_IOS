//
//  GymClass.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import Foundation

// MARK: - Session Models
struct ClassSession: Codable, Identifiable {
    let classId: Int
    let trainerId: Int
    let startTime: Date
    let endTime: Date
    let room: String?
    let isRecurring: Bool
    let recurrencePattern: String?
    let status: SessionStatus
    let overrideCapacity: Int?
    let notes: String?
    let id: Int
    let gymId: Int
    let currentParticipants: Int
    let createdAt: Date
    let updatedAt: Date?
    let createdBy: Int?
    
    enum CodingKeys: String, CodingKey {
        case classId = "class_id"
        case trainerId = "trainer_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case room
        case isRecurring = "is_recurring"
        case recurrencePattern = "recurrence_pattern"
        case status
        case overrideCapacity = "override_capacity"
        case notes
        case id
        case gymId = "gym_id"
        case currentParticipants = "current_participants"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }
}

enum SessionStatus: String, Codable {
    case scheduled = "scheduled"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
}

struct ClassInfo: Codable, Identifiable {
    let name: String
    let description: String
    let duration: Int
    let maxCapacity: Int
    let difficultyLevel: DifficultyLevel
    let categoryId: Int?
    let categoryEnum: String?
    let category: String?
    let isActive: Bool
    let gymId: Int
    let id: Int
    let createdAt: Date
    let updatedAt: Date?
    let createdBy: Int?
    let customCategory: CustomCategory?
    
    enum CodingKeys: String, CodingKey {
        case name, description, duration
        case maxCapacity = "max_capacity"
        case difficultyLevel = "difficulty_level"
        case categoryId = "category_id"
        case categoryEnum = "category_enum"
        case category
        case isActive = "is_active"
        case gymId = "gym_id"
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case customCategory = "custom_category"
    }
}

enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner: return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced: return "Avanzado"
        }
    }
    
    var color: String {
        switch self {
        case .beginner: return "#22c55e"
        case .intermediate: return "#f59e0b"
        case .advanced: return "#ef4444"
        }
    }
}

struct CustomCategory: Codable, Identifiable {
    let name: String
    let description: String
    let color: String
    let icon: String
    let isActive: Bool
    let id: Int
    let gymId: Int
    let createdAt: Date
    let updatedAt: Date?
    let createdBy: Int?
    
    enum CodingKeys: String, CodingKey {
        case name, description, color, icon
        case isActive = "is_active"
        case id
        case gymId = "gym_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }
}

struct SessionWithClass: Codable, Identifiable {
    let session: ClassSession
    let classInfo: ClassInfo
    
    var id: Int { session.id }
    
    enum CodingKeys: String, CodingKey {
        case session
        case classInfo = "class_info"
    }
}

// MARK: - Extensions for UI
extension SessionWithClass {
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: session.startTime)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: session.startTime)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(session.startTime)
    }
    
    var categoryColor: String {
        return classInfo.customCategory?.color ?? classInfo.difficultyLevel.color
    }
    
    var trainerName: String {
        // Obtener el nombre del trainer desde el ClassService
        if let classService = ClassService.shared {
            return classService.getTrainerName(trainerId: session.trainerId)
        }
        return "Coach \(session.trainerId)"
    }
    
    var availableSpots: Int {
        return classInfo.maxCapacity - session.currentParticipants
    }
    
    var isFullyBooked: Bool {
        return session.currentParticipants >= classInfo.maxCapacity
    }
} 