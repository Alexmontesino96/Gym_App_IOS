import Foundation

// MARK: - Gym Participant Model
struct GymParticipant: Codable, Identifiable {
    let id: Int
    let email: String?  // Hacer email opcional
    let isActive: Bool
    let firstName: String
    let lastName: String
    let role: String?
    let phoneNumber: String?
    let birthDate: Date?
    let height: Double?
    let weight: Double?
    let bio: String?
    let goals: String?
    let healthConditions: String?
    let gymRole: String?
    let qrCode: String?
    let createdAt: Date?
    let updatedAt: Date?
    let auth0Id: String?
    let picture: String?
    let color: String?
    let age: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isActive = "is_active"
        case firstName = "first_name"
        case lastName = "last_name"
        case role
        case phoneNumber = "phone_number"
        case birthDate = "birth_date"
        case height
        case weight
        case bio
        case goals
        case healthConditions = "health_conditions"
        case gymRole = "gym_role"
        case qrCode = "qr_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case auth0Id = "auth0_id"
        case picture
        case color
        case age
    }
    
    // MARK: - Computed Properties
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Convert to UserProfile for compatibility
    func toUserProfile() -> UserProfile? {
        // Usar email o crear uno por defecto si no existe
        let userEmail = email ?? "user\(id)@gym.local"
        
        return UserProfile(
            id: id,
            email: userEmail,
            isActive: isActive,
            isSuperuser: false, // Default value
            firstName: firstName,
            lastName: lastName,
            role: role ?? "member",
            phoneNumber: phoneNumber,
            birthDate: birthDate,
            height: height,
            weight: weight,
            bio: bio,
            goals: goals,
            healthConditions: healthConditions,
            gymRole: gymRole,
            qrCode: qrCode ?? "",
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            auth0Id: auth0Id ?? "",
            picture: picture,
            color: color
        )
    }
}