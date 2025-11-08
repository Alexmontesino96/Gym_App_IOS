//
//  CreateEventRequest.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import Foundation

// MARK: - Create Event Request Model
struct CreateEventRequest: Codable {
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let location: String
    let maxParticipants: Int
    let status: String
    let firstMessageChat: String
    
    enum CodingKeys: String, CodingKey {
        case title, description, location, status
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case firstMessageChat = "first_message_chat"
    }
    
    init(
        title: String,
        description: String,
        startTime: Date,
        endTime: Date,
        location: String,
        maxParticipants: Int,
        firstMessageChat: String = ""
    ) {
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.maxParticipants = maxParticipants
        self.status = "SCHEDULED" // Always set to SCHEDULED for new events
        self.firstMessageChat = firstMessageChat.isEmpty ? "¡Bienvenidos al evento \(title)!" : firstMessageChat
    }
}

// MARK: - Create Event Response Model
struct CreateEventResponse: Codable {
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let location: String
    let maxParticipants: Int
    let status: String
    let id: Int
    let creatorId: Int
    let createdAt: Date
    let updatedAt: Date
    let participantsCount: Int

    // Monetization fields
    let isPaid: Bool?
    let priceCents: Int?
    let currency: String?
    let refundPolicy: RefundPolicyType?
    let refundDeadlineHours: Int?
    let partialRefundPercentage: Int?
    let stripeProductId: String?
    let stripePriceId: String?

    enum CodingKeys: String, CodingKey {
        case title, description, location, status, id
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case participantsCount = "participants_count"
        // Monetization keys
        case isPaid = "is_paid"
        case priceCents = "price_cents"
        case currency
        case refundPolicy = "refund_policy"
        case refundDeadlineHours = "refund_deadline_hours"
        case partialRefundPercentage = "partial_refund_percentage"
        case stripeProductId = "stripe_product_id"
        case stripePriceId = "stripe_price_id"
    }
}

// MARK: - Event Form Data (for UI state management)
struct EventFormData {
    var title: String = ""
    var description: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later by default
    var location: String = ""
    var maxParticipants: Int = 20
    var firstMessage: String = ""
    
    // Validation
    var isValid: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               endDate > startDate &&
               maxParticipants > 0 &&
               maxParticipants <= 200 // Reasonable upper limit
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("El título es requerido")
        }
        
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("La descripción es requerida")
        }
        
        if location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("La ubicación es requerida")
        }
        
        if endDate <= startDate {
            errors.append("La fecha de fin debe ser posterior a la fecha de inicio")
        }
        
        if startDate < Date().addingTimeInterval(-300) { // Allow 5 minutes in the past for clock differences
            errors.append("La fecha de inicio no puede ser en el pasado")
        }
        
        if maxParticipants <= 0 {
            errors.append("El número máximo de participantes debe ser mayor a 0")
        }
        
        if maxParticipants > 200 {
            errors.append("El número máximo de participantes no puede ser mayor a 200")
        }
        
        return errors
    }
    
    // Convert to API request
    func toCreateEventRequest() -> CreateEventRequest {
        return CreateEventRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startDate,
            endTime: endDate,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            maxParticipants: maxParticipants,
            firstMessageChat: firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    // Preset templates for common events
    static let fitnessClassTemplate = EventFormData(
        title: "Clase de Fitness",
        description: "Únete a nuestra clase de fitness para mejorar tu condición física",
        maxParticipants: 15
    )
    
    static let yogaClassTemplate = EventFormData(
        title: "Sesión de Yoga",
        description: "Relajación y estiramiento con posturas de yoga para todos los niveles",
        maxParticipants: 12
    )
    
    static let strengthTrainingTemplate = EventFormData(
        title: "Entrenamiento de Fuerza",
        description: "Desarrolla tu fuerza muscular con ejercicios dirigidos",
        maxParticipants: 10
    )
    
    static let cardioTemplate = EventFormData(
        title: "Cardio Intenso",
        description: "Sesión de cardio de alta intensidad para quemar calorías",
        maxParticipants: 20
    )
    
    static let specialEventTemplate = EventFormData(
        title: "Evento Especial",
        description: "Evento especial del gimnasio - ¡No te lo pierdas!",
        maxParticipants: 50
    )
}

// MARK: - Event Template Enum
enum EventTemplate: String, CaseIterable {
    case fitnessClass = "fitness_class"
    case yogaClass = "yoga_class" 
    case strengthTraining = "strength_training"
    case cardio = "cardio"
    case specialEvent = "special_event"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .fitnessClass:
            return "Clase de Fitness"
        case .yogaClass:
            return "Sesión de Yoga"
        case .strengthTraining:
            return "Entrenamiento de Fuerza"
        case .cardio:
            return "Cardio Intenso"
        case .specialEvent:
            return "Evento Especial"
        case .custom:
            return "Personalizado"
        }
    }
    
    var icon: String {
        switch self {
        case .fitnessClass:
            return "figure.walk"
        case .yogaClass:
            return "figure.yoga"
        case .strengthTraining:
            return "dumbbell.fill"
        case .cardio:
            return "heart.fill"
        case .specialEvent:
            return "star.fill"
        case .custom:
            return "plus.circle.fill"
        }
    }
    
    var formData: EventFormData {
        switch self {
        case .fitnessClass:
            return .fitnessClassTemplate
        case .yogaClass:
            return .yogaClassTemplate
        case .strengthTraining:
            return .strengthTrainingTemplate
        case .cardio:
            return .cardioTemplate
        case .specialEvent:
            return .specialEventTemplate
        case .custom:
            return EventFormData()
        }
    }
}

// MARK: - Update Event Request Model
struct UpdateEventRequest: Codable {
    let title: String?
    let description: String?
    let startTime: Date?
    let endTime: Date?
    let location: String?
    let maxParticipants: Int?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description, location, status
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
    }
    
    init(
        title: String? = nil,
        description: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        maxParticipants: Int? = nil,
        status: String? = nil
    ) {
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.maxParticipants = maxParticipants
        self.status = status
    }
    
    // Convert from EventFormData for updates
    static func fromEventFormData(_ formData: EventFormData) -> UpdateEventRequest {
        return UpdateEventRequest(
            title: formData.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: formData.description.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: formData.startDate,
            endTime: formData.endDate,
            location: formData.location.trimmingCharacters(in: .whitespacesAndNewlines),
            maxParticipants: formData.maxParticipants,
            status: "SCHEDULED"
        )
    }
}

// MARK: - Bulk Event Registration Models
struct BulkEventRegistrationRequest: Codable {
    let eventId: Int
    let userIds: [Int]
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userIds = "user_ids"
    }
    
    init(eventId: Int, userIds: [Int]) {
        self.eventId = eventId
        self.userIds = userIds
    }
}

struct BulkEventRegistrationResponse: Codable {
    let registrations: [EventParticipation]
    
    init(registrations: [EventParticipation]) {
        self.registrations = registrations
    }
}

// MARK: - User Selection Model (for UI)
struct SelectableUser: Identifiable, Equatable {
    let id: Int
    let name: String
    let email: String
    let role: String?
    let profilePicture: String?
    var isSelected: Bool = false
    var isAlreadyRegistered: Bool = false
    
    static func == (lhs: SelectableUser, rhs: SelectableUser) -> Bool {
        return lhs.id == rhs.id
    }
}