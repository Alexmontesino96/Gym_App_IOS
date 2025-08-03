import Foundation

// MARK: - Simplified GymClass Model for UI Components
struct GymClass: Identifiable {
    let id: Int
    let name: String
    let description: String
    let instructor: String
    let trainerId: Int // Agregado para obtener la imagen del trainer
    let startTime: Date
    let endTime: Date
    let maxParticipants: Int
    let currentParticipants: Int
    let difficulty: ClassDifficulty
    let status: ClassStatus
    let gymTimezone: String? // Agregado para manejar zona horaria
    
    // Inicializador completo
    init(id: Int, name: String, description: String, instructor: String, trainerId: Int, startTime: Date, endTime: Date, maxParticipants: Int, currentParticipants: Int, difficulty: ClassDifficulty, status: ClassStatus, gymTimezone: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.instructor = instructor
        self.trainerId = trainerId
        self.startTime = startTime
        self.endTime = endTime
        self.maxParticipants = maxParticipants
        self.currentParticipants = currentParticipants
        self.difficulty = difficulty
        self.status = status
        self.gymTimezone = gymTimezone
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Obtener las zonas horarias
        let userTimezone = TimeZone.current
        let gymTimezoneString = gymTimezone ?? "America/New_York"
        let gymTimezone = TimeZone(identifier: gymTimezoneString) ?? TimeZone.current
        
        // Si las zonas horarias son iguales, no hacer conversión
        if userTimezone.identifier == gymTimezone.identifier {
            formatter.timeZone = TimeZone.current
            print("🕐 GymClass: Same timezone, no conversion needed")
        } else {
            // Si son diferentes, usar la zona horaria del gimnasio
            formatter.timeZone = gymTimezone
            print("🕐 GymClass: Different timezone, using gym timezone")
        }
        
        let result = formatter.string(from: startTime)
        print("🕐 GymClass: Formatted time: \(result)")
        return result
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