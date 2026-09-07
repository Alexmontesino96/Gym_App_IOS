import SwiftUI

// MARK: - ClassCategoryHelper
/// Infers category and color from class name when no explicit category field exists
enum ClassCategory: String, CaseIterable {
    case yoga
    case cardio
    case hiit
    case strength
    case pilates
    case flexibility
    case functional
    case other

    var color: Color {
        switch self {
        case .yoga: return Color(hex: "#A78BFA")!
        case .cardio: return Color(hex: "#FF5A1F")!
        case .hiit: return Color(hex: "#D4FF3F")!
        case .strength: return Color(hex: "#3B82F6")!
        case .pilates: return Color(hex: "#F472B6")!
        case .flexibility: return Color(hex: "#4ADE80")!
        case .functional: return Color(hex: "#FFB347")!
        case .other: return Color(hex: "#8A8A86")!
        }
    }

    var label: String {
        switch self {
        case .yoga: return "YOGA"
        case .cardio: return "CARDIO"
        case .hiit: return "HIIT"
        case .strength: return "FUERZA"
        case .pilates: return "PILATES"
        case .flexibility: return "FLEX"
        case .functional: return "FUNCIONAL"
        case .other: return "CLASE"
        }
    }
}

// MARK: - Category Inference

struct ClassCategoryHelper {
    /// Infers category from class name using keyword matching
    static func category(for gymClass: GymClass) -> ClassCategory {
        let name = gymClass.name.lowercased()

        if name.contains("yoga") || name.contains("vinyasa") || name.contains("hatha") {
            return .yoga
        }
        if name.contains("hiit") || name.contains("tabata") || name.contains("interval") {
            return .hiit
        }
        if name.contains("spinning") || name.contains("cardio") || name.contains("cycling") || name.contains("bike") || name.contains("zumba") || name.contains("aerob") {
            return .cardio
        }
        if name.contains("fuerza") || name.contains("strength") || name.contains("pesas") || name.contains("weight") || name.contains("musculación") {
            return .strength
        }
        if name.contains("pilates") || name.contains("reformer") {
            return .pilates
        }
        if name.contains("stretch") || name.contains("flex") || name.contains("movilidad") || name.contains("mobility") {
            return .flexibility
        }
        if name.contains("funcional") || name.contains("functional") || name.contains("crossfit") || name.contains("cross") || name.contains("circuit") {
            return .functional
        }
        if name.contains("box") || name.contains("kickbox") || name.contains("combat") || name.contains("fight") {
            return .cardio
        }

        return .other
    }

    /// Get color for a class
    static func color(for gymClass: GymClass) -> Color {
        category(for: gymClass).color
    }

    /// Get label for a class
    static func label(for gymClass: GymClass) -> String {
        category(for: gymClass).label
    }
}
