import Foundation

// MARK: - Gym with detailed information
struct GymDetail: Codable, Identifiable {
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
    let gymHours: [GymHourDetail]
    let membershipPlans: [MembershipPlan]
    let modules: [GymModule]
    
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
        case gymHours = "gym_hours"
        case membershipPlans = "membership_plans"
        case modules
    }
}

// MARK: - Gym Hours
struct GymHourDetail: Codable, Identifiable {
    let dayOfWeek: Int
    let openTime: String?
    let closeTime: String?
    let isClosed: Bool
    
    var id: Int { dayOfWeek }
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case openTime = "open_time"
        case closeTime = "close_time"
        case isClosed = "is_closed"
    }
    
    var dayName: String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[dayOfWeek]
    }
    
    var displayTime: String {
        if isClosed {
            return "Closed"
        }
        
        guard let openTime = openTime, let closeTime = closeTime else {
            return "Hours not available"
        }
        
        return "\(formatTime(openTime)) - \(formatTime(closeTime))"
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: time)
        }
        
        return timeString
    }
}

// MARK: - Membership Plan
struct MembershipPlan: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let priceCents: Int
    let currency: String
    let billingInterval: String
    let durationDays: Int
    let maxBillingCycles: Int?
    let features: String
    let maxBookingsPerMonth: Int
    let priceAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case priceCents = "price_cents"
        case currency
        case billingInterval = "billing_interval"
        case durationDays = "duration_days"
        case maxBillingCycles = "max_billing_cycles"
        case features
        case maxBookingsPerMonth = "max_bookings_per_month"
        case priceAmount = "price_amount"
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: priceAmount)) ?? "$\(priceAmount)"
    }
    
    var billingIntervalDisplay: String {
        switch billingInterval.lowercased() {
        case "month":
            return "per month"
        case "year":
            return "per year"
        case "week":
            return "per week"
        case "day":
            return "per day"
        default:
            return "per \(billingInterval)"
        }
    }
}

// MARK: - Gym Module
struct GymModule: Codable, Identifiable {
    let moduleName: String
    let isEnabled: Bool
    
    var id: String { moduleName }
    
    enum CodingKeys: String, CodingKey {
        case moduleName = "module_name"
        case isEnabled = "is_enabled"
    }
}