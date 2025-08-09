import Foundation
import SwiftData

// MARK: - Event Status
enum EventStatus: String, CaseIterable, Codable {
    case scheduled = "SCHEDULED"
    case active = "ACTIVE"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Programado"
        case .active: return "Activo"
        case .completed: return "Completado"
        case .cancelled: return "Cancelado"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .active: return "green"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Event Model
struct Event: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let location: String
    let maxParticipants: Int
    let status: EventStatus
    let creatorId: Int
    let createdAt: Date
    let updatedAt: Date
    var participantsCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, location, status
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case participantsCount = "participants_count"
    }
    
    // Computed properties para formateo
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: startTime)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(startTime)
    }
    
    var dayTimeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        if isToday {
            formatter.dateFormat = "'Today', h:mm a"
        } else {
            formatter.dateFormat = "MMM dd, h:mm a"
        }
        return formatter.string(from: startTime)
    }
}

// MARK: - Event Detail Model (for detailed endpoint)
struct EventDetail: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let location: String
    let maxParticipants: Int
    let status: EventStatus
    let creatorId: Int
    let createdAt: Date
    let updatedAt: Date
    let participantsCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, location, status
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case participantsCount = "participants_count"
    }
    
    // Computed properties para formateo
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: startTime)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(startTime)
    }
    
    var dayTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        
        if isToday {
            formatter.dateFormat = "HH:mm"
            return "Hoy, \(formatter.string(from: startTime))"
        } else {
            // Usar formato consistente con participantes
            let components = Calendar.current.dateComponents([.day, .month, .year, .hour, .minute], from: startTime)
            if let day = components.day, let month = components.month, let hour = components.hour, let minute = components.minute {
                let monthNames = ["", "Ene", "Feb", "Mar", "Abr", "May", "Jun",
                                 "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
                let timeString = String(format: "%02d:%02d", hour, minute)
                return "\(day) \(monthNames[month]), \(timeString)"
            }
            
            // Fallback
            formatter.dateFormat = "dd MMM, HH:mm"
            formatter.timeZone = TimeZone.current // Usar zona horaria local
            return formatter.string(from: startTime)
        }
    }
    
    var availableSpots: Int {
        return maxParticipants - participantsCount
    }
    
    var isFullyBooked: Bool {
        return participantsCount >= maxParticipants
    }
}

// MARK: - Event Participation Model (API Real)
struct EventParticipation: Codable, Identifiable {
    let id: Int
    let eventId: Int
    let memberId: Int
    let status: String
    let attended: Bool
    let registeredAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, status, attended
        case eventId = "event_id"
        case memberId = "member_id"
        case registeredAt = "registered_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - User Profile Model (API Real)
struct UserProfile: Codable, Identifiable, Equatable {
    let id: Int
    let email: String
    let isActive: Bool
    let isSuperuser: Bool
    let firstName: String
    let lastName: String
    let role: String
    let phoneNumber: String?
    let birthDate: Date?
    let height: Double?
    let weight: Double?
    let bio: String?
    let goals: String?
    let healthConditions: String?
    let gymRole: String?
    let qrCode: String
    let createdAt: Date
    let updatedAt: Date
    let auth0Id: String
    let picture: String?
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, role, bio, goals, picture
        case isActive = "is_active"
        case isSuperuser = "is_superuser"
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case birthDate = "birth_date"
        case height, weight
        case healthConditions = "health_conditions"
        case gymRole = "gym_role"
        case qrCode = "qr_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case auth0Id = "auth0_id"
        case color
    }
    
    // MARK: - Computed Properties
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var displayRole: String {
        switch role {
        case "SUPER_ADMIN":
            return "Super Admin"
        case "MEMBER":
            return "Member"
        case "TRAINER":
            return "Trainer"
        case "OWNER":
            return "Owner"
        default:
            return role.capitalized
        }
    }
    
    var displayGymRole: String? {
        guard let gymRole = gymRole else { return nil }
        switch gymRole {
        case "OWNER":
            return "Gym Owner"
        case "MANAGER":
            return "Manager"
        case "TRAINER":
            return "Trainer"
        default:
            return gymRole.capitalized
        }
    }
    
    var memberSince: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: createdAt)
    }
    
    var formattedBirthDate: String? {
        guard let birthDate = birthDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: birthDate)
    }
    
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
    
    var heightDisplay: String? {
        guard let height = height else { return nil }
        return String(format: "%.1f cm", height)
    }
    
    var weightDisplay: String? {
        guard let weight = weight else { return nil }
        return String(format: "%.1f kg", weight)
    }
    
    var hasPhysicalInfo: Bool {
        return height != nil || weight != nil || birthDate != nil
    }
    
    var hasFitnessInfo: Bool {
        return bio != nil || goals != nil || healthConditions != nil
    }
} 

// MARK: - Event Participation With Event Model (API Real)
struct EventParticipationWithEvent: Codable, Identifiable {
    let id: Int
    let eventId: Int
    let memberId: Int
    let status: String
    let attended: Bool
    let registeredAt: Date
    let updatedAt: Date
    let event: EventInParticipation
    
    enum CodingKeys: String, CodingKey {
        case id, status, attended, event
        case eventId = "event_id"
        case memberId = "member_id"
        case registeredAt = "registered_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Event In Participation Model (sin id)
struct EventInParticipation: Codable {
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let location: String
    let maxParticipants: Int
    let status: EventStatus
    
    enum CodingKeys: String, CodingKey {
        case title, description, location, status
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
    }
    
    // Computed properties
    var isToday: Bool {
        Calendar.current.isDate(startTime, inSameDayAs: Date())
    }
    
    var isTomorrow: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return Calendar.current.isDate(startTime, inSameDayAs: tomorrow)
    }
    
    var isThisWeek: Bool {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        return startTime >= startOfWeek && startTime <= endOfWeek
    }
    
    var timeCategory: String {
        if isToday {
            return "Hoy"
        } else if isTomorrow {
            return "Mañana"
        } else if isThisWeek {
            return "Esta semana"
        } else {
            return "Más tarde"
        }
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: startTime)
    }
    
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: endTime)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: startTime)
    }
    
    var formattedDateWithDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd/MM/yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: startTime)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter.string(from: startTime)
    }
} 

// MARK: - Chat Models
struct StreamTokenResponse: Codable {
    let token: String
    let apiKey: String
    let internalUserId: Int
    
    enum CodingKeys: String, CodingKey {
        case token
        case apiKey = "api_key"
        case internalUserId = "internal_user_id"
    }
}

struct ChatRoomSchema: Codable {
    let name: String?
    let isDirect: Bool
    let eventId: Int
    let id: Int
    let streamChannelId: String
    let streamChannelType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case isDirect = "is_direct"
        case eventId = "event_id"
        case id
        case streamChannelId = "stream_channel_id"
        case streamChannelType = "stream_channel_type"
        case createdAt = "created_at"
    }
} 