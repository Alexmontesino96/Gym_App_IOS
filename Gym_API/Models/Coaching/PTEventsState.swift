import Foundation

/// The coach's preference is separate from the platform's module entitlement.
struct PTEventsState: Codable, Equatable {
    let gymId: Int
    let available: Bool
    let enabled: Bool
    let canManage: Bool
    let canSellTickets: Bool
    let currency: String

    enum CodingKeys: String, CodingKey {
        case available, enabled, currency
        case gymId = "gym_id"
        case canManage = "can_manage"
        case canSellTickets = "can_sell_tickets"
    }
}
