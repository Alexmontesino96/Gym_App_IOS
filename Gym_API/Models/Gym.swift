import Foundation

struct Gym: Codable, Identifiable {
    let id: Int
    let name: String
    let subdomain: String
    let logoUrl: String?
    let address: String?
    let phone: String?
    let email: String?
    let description: String?
    let timezone: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subdomain
        case logoUrl = "logo_url"
        case address
        case phone
        case email
        case description
        case timezone
        case isActive = "is_active"
    }
}