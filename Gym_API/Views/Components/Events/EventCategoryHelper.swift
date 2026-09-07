import SwiftUI

// MARK: - EventCategory
/// Event category with associated color, label, and icon
enum EventCategory: String, CaseIterable {
    case outdoor
    case race
    case workshop
    case retreat
    case charity
    case social
    case other

    var color: Color {
        switch self {
        case .outdoor: return Color(hex: "#FF5A1F")!
        case .race: return Color(hex: "#3B82F6")!
        case .workshop: return Color(hex: "#A78BFA")!
        case .retreat: return Color(hex: "#4ADE80")!
        case .charity: return Color(hex: "#D4FF3F")!
        case .social: return Color(hex: "#F472B6")!
        case .other: return Color(hex: "#8A8A86")!
        }
    }

    var label: String {
        switch self {
        case .outdoor: return "OUTDOOR"
        case .race: return "CARRERA"
        case .workshop: return "WORKSHOP"
        case .retreat: return "RETIRO"
        case .charity: return "SOLIDARIO"
        case .social: return "SOCIAL"
        case .other: return "EVENTO"
        }
    }

    var icon: String {
        switch self {
        case .outdoor: return "leaf.fill"
        case .race: return "figure.run"
        case .workshop: return "sparkles"
        case .retreat: return "moon.stars.fill"
        case .charity: return "heart.fill"
        case .social: return "person.2.fill"
        case .other: return "star.fill"
        }
    }

    var filterLabel: String {
        switch self {
        case .outdoor: return "Outdoor"
        case .race: return "Carreras"
        case .workshop: return "Workshops"
        case .retreat: return "Retiros"
        case .charity: return "Solidarios"
        case .social: return "Social"
        case .other: return "Otros"
        }
    }
}

// MARK: - EventCategoryHelper

struct EventCategoryHelper {
    /// Infers event category from title and description
    static func category(for event: Event) -> EventCategory {
        let text = "\(event.title) \(event.description)".lowercased()

        if text.contains("run") || text.contains("carrera") || text.contains("maratón") || text.contains("maraton") || text.contains("10k") || text.contains("5k") || text.contains("hyrox") {
            return .race
        }
        if text.contains("workshop") || text.contains("taller") || text.contains("nutrición") || text.contains("nutricion") || text.contains("charla") {
            return .workshop
        }
        if text.contains("retiro") || text.contains("retreat") || text.contains("wellness") || text.contains("mindful") {
            return .retreat
        }
        if text.contains("outdoor") || text.contains("sunrise") || text.contains("hike") || text.contains("playa") || text.contains("montaña") || text.contains("ruta") {
            return .outdoor
        }
        if text.contains("solidar") || text.contains("charity") || text.contains("benéfic") || text.contains("benefic") || text.contains("donación") {
            return .charity
        }
        if text.contains("social") || text.contains("fiesta") || text.contains("meetup") || text.contains("encuentro") {
            return .social
        }

        return .other
    }

    static func color(for event: Event) -> Color {
        category(for: event).color
    }

    static func icon(for event: Event) -> String {
        category(for: event).icon
    }
}
