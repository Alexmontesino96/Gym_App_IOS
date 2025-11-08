//
//  UserProfile.swift
//  Gym_API
//
//  Model for user profile data from the API
//

import Foundation

// MARK: - User Profile Model
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
    let qrCode: String?
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