import Foundation

// MARK: - Simplified GymClass Model for UI Components
struct GymClass: Identifiable {
    let id: Int
    let name: String
    let description: String
    let instructor: String
    let startTime: Date
    let endTime: Date
    let maxParticipants: Int
    let currentParticipants: Int
    let difficulty: ClassDifficulty
    let status: ClassStatus
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }
}

enum ClassDifficulty: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

enum ClassStatus: String, CaseIterable {
    case available = "available"
    case completed = "completed"
    case cancelled = "cancelled"
}