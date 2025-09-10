//
//  GymInfo.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import Foundation

// MARK: - Gym Info Model
struct GymInfo: Codable, Identifiable, Equatable {
    let name: String
    let subdomain: String
    let logoUrl: String?
    let addressValue: String
    let phone: String
    let email: String
    let description: String
    let timezone: String
    let id: Int
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let userEmail: String
    let userRoleInGym: String
    
    // Computed property for backward compatibility
    var address: String {
        return addressValue
    }
    
    enum CodingKeys: String, CodingKey {
        case name, subdomain, phone, email, description, timezone, id
        case addressValue = "address"
        case logoUrl = "logo_url"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userEmail = "user_email"
        case userRoleInGym = "user_role_in_gym"
    }
    
    // Custom decoder to handle both string and array for address and nullable fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        subdomain = try container.decode(String.self, forKey: .subdomain)
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        
        // Handle nullable fields with defaults
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "UTC"
        
        id = try container.decode(Int.self, forKey: .id)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        userEmail = try container.decode(String.self, forKey: .userEmail)
        userRoleInGym = try container.decode(String.self, forKey: .userRoleInGym)
        
        // Handle address that can be null, string or array
        if let addressString = try? container.decode(String.self, forKey: .addressValue) {
            addressValue = addressString
        } else if let addressArray = try? container.decode([String].self, forKey: .addressValue) {
            addressValue = addressArray.joined(separator: ", ")
        } else {
            addressValue = ""
        }
    }
    
    // MARK: - Computed Properties
    var roleDisplayName: String {
        switch userRoleInGym.uppercased() {
        case "OWNER":
            return "Owner"
        case "ADMIN":
            return "Administrator"
        case "TRAINER":
            return "Trainer"
        case "MEMBER":
            return "Member"
        default:
            return userRoleInGym
        }
    }
    
    var roleIcon: String {
        switch userRoleInGym.uppercased() {
        case "OWNER":
            return "crown.fill"
        case "ADMIN":
            return "person.badge.key.fill"
        case "TRAINER":
            return "figure.walk"
        case "MEMBER":
            return "person.fill"
        default:
            return "person.fill"
        }
    }
    
    var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Member since \(formatter.string(from: createdAt))"
    }
    
    var statusText: String {
        return isActive ? "Active" : "Inactive"
    }
    
    var statusColor: String {
        return isActive ? "green" : "red"
    }
}