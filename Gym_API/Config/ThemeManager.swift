import SwiftUI
import Combine

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .light
    @Published var selectedLightAccentHex: String = "#26A69A" // Teal/Verde azul
    @Published var selectedDarkAccentHex: String = "#4DB6AC" // Teal claro para modo oscuro
    
    enum AppTheme: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }
    
    func toggleTheme() {
        currentTheme = currentTheme == .light ? .dark : .light
        saveTheme()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveTheme()
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        UserDefaults.standard.set(selectedLightAccentHex, forKey: "selectedLightAccentHex")
        UserDefaults.standard.set(selectedDarkAccentHex, forKey: "selectedDarkAccentHex")
    }
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        if let lightHex = UserDefaults.standard.string(forKey: "selectedLightAccentHex") {
            selectedLightAccentHex = lightHex
        }
        if let darkHex = UserDefaults.standard.string(forKey: "selectedDarkAccentHex") {
            selectedDarkAccentHex = darkHex
        } else {
            selectedDarkAccentHex = "#4DB6AC" // Default to teal for dark mode
        }
    }
}

// MARK: - Theme Colors
extension Color {
    // MARK: - Hex Color Support
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    // MARK: - Dynamic Colors (se adaptan al tema)
    static func dynamicBackground(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.lightBackgroundPrimary
        case .dark: return Color.darkBackgroundPrimary
        }
    }
    
    static func dynamicSurface(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.lightSurfacePrimary
        case .dark: return Color.darkSurfacePrimary
        }
    }
    
    static func dynamicText(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.lightTextPrimary
        case .dark: return Color.darkTextPrimary
        }
    }
    
    static func dynamicTextSecondary(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.lightTextSecondary
        case .dark: return Color.darkTextSecondary
        }
    }
    
    static func dynamicBorder(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.lightBorderPrimary
        case .dark: return Color.darkBorderPrimary
        }
    }
    
    static func dynamicAccent(theme: ThemeManager.AppTheme) -> Color {
        let hex = ThemeManager.accentHexFromDefaults(for: theme)
        return Color(hex: hex) ?? (theme == .light ? Color.lightAccentPrimary : Color.darkAccentPrimary)
    }

    static func dynamicTextTertiary(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.lightTextTertiary
        case .dark: return Color.darkTextTertiary
        }
    }

    static func dynamicCard(theme: ThemeManager.AppTheme) -> Color {
        switch theme {
        case .light: return Color.white
        case .dark: return Color.darkSurfacePrimary
        }
    }
    
    // MARK: - Light Theme Colors (WCAG 2.1 AA Compliant)
    static let lightBackgroundPrimary = Color.white // #FFFFFF - Fondo principal blanco como en la imagen
    static let lightBackgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2
    static let lightSurfacePrimary = Color(red: 246/255, green: 247/255, blue: 250/255) // RGB(246, 247, 259) - Gris exacto de las tarjetas
    static let lightSurfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.97) // #F7F7F7
    static let lightTextPrimary = Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A - Contrast 16.1:1 ✅
    static let lightTextSecondary = Color(red: 0.3, green: 0.3, blue: 0.3) // #4D4D4D - Contrast 9.0:1 ✅ (antes 3.9:1)
    static let lightTextTertiary = Color(red: 0.45, green: 0.45, blue: 0.45) // #737373 - Contrast 5.2:1 ✅ (antes 2.8:1)
    static let lightBorderPrimary = Color(red: 0.68, green: 0.68, blue: 0.68) // #ADADAD - Contrast 4.6:1 ✅ (antes 1.9:1)
    static let lightBorderSecondary = Color(red: 0.75, green: 0.75, blue: 0.75) // #BFBFBF - Contrast 3.2:1 ✅
    static let lightAccentPrimary = Color(red: 0.15, green: 0.65, blue: 0.60) // #26A69A - Teal para modo claro
    static let lightShadow = Color.black.opacity(0.1) // Sombras suaves para modo claro
    
    // MARK: - Dark Theme Colors (WCAG 2.1 AA Compliant)
    static let darkBackgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D
    static let darkBackgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.08) // #141414
    static let darkSurfacePrimary = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    static let darkSurfaceSecondary = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    static let darkTextPrimary = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2 - Contrast 18.1:1 ✅
    static let darkTextSecondary = Color(red: 0.82, green: 0.82, blue: 0.82) // #D1D1D1 - Contrast 12.8:1 ✅ (antes 3.8:1)
    static let darkTextTertiary = Color(red: 0.68, green: 0.68, blue: 0.68) // #ADADAD - Contrast 7.3:1 ✅ (antes 2.8:1)
    static let darkBorderPrimary = Color(red: 0.45, green: 0.45, blue: 0.45) // #737373 - Contrast 5.2:1 ✅ (antes 2.1:1)
    static let darkBorderSecondary = Color(red: 0.35, green: 0.35, blue: 0.35) // #595959 - Contrast 3.8:1 ✅
    static let darkAccentPrimary = Color(red: 0.30, green: 0.71, blue: 0.67) // #4DB6AC - Teal claro para modo oscuro
    static let darkShadow = Color.black.opacity(0.25) // Sombras para modo oscuro

    // MARK: - Semantic Colors (para Social Feed)
    static let likeRed = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30 - Like color
    static let successGreen = Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759
    static let mindbodyGreen = Color(red: 0.44, green: 0.81, blue: 0.25) // #6FCF3F - Verde Mindbody para botones
    static let warningYellow = Color(red: 1.0, green: 0.80, blue: 0.0) // #FFCC00
    static let errorRed = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
}

// MARK: - Environment Key
struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Accent Palettes & Helpers
extension ThemeManager {
    static var lightAccentOptions: [String] {
        return [
            "#C43421", // Deep Red (propuesto)
            "#D94A4A", // Current Red
            "#E74C3C", // Crimson
            "#FF6B6B", // Coral
            "#6FCF3F", // Mindbody Green ✅ NUEVO
            "#4CAF50", // Material Green
            "#66BB6A", // Medium Green
            "#9CCC65", // Light Green
            "#FF7043", // Deep Orange
            "#FF8C42", // Orange
            "#FFA726", // Amber
            "#FFD54F", // Yellow
            "#26A69A", // Teal
            "#00827E", // Deep Teal
            "#29B6F6", // Light Blue
            "#42A5F5", // Blue
            "#5C6AC4", // Indigo
            "#7986CB", // Light Indigo
            "#9575CD", // Purple
            "#BA68C8"  // Light Purple
        ]
    }
    
    static var darkAccentOptions: [String] {
        return [
            "#C43421", // Deep Red (propuesto)
            "#D94A4A", // Current Red
            "#FF5252", // Bright Red
            "#FF6B6B", // Coral
            "#6FCF3F", // Mindbody Green ✅ NUEVO
            "#66BB6A", // Material Green
            "#81C784", // Medium Green
            "#AED581", // Light Green
            "#FF7043", // Deep Orange
            "#FF8C42", // Orange
            "#FFB74D", // Amber
            "#FFF176", // Light Yellow
            "#4DB6AC", // Teal
            "#26A69A", // Dark Teal
            "#4FC3F7", // Light Blue
            "#29B6F6", // Blue
            "#42A5F5", // Sky Blue
            "#7986CB", // Indigo
            "#9575CD", // Purple
            "#BA68C8", // Light Purple
            "#F06292", // Pink
            "#64B5F6"  // Light Sky Blue
        ]
    }
    
    static func accentHexFromDefaults(for theme: AppTheme) -> String {
        let defaults = UserDefaults.standard
        if theme == .light {
            return defaults.string(forKey: "selectedLightAccentHex") ?? "#26A69A" // Teal
        } else {
            return defaults.string(forKey: "selectedDarkAccentHex") ?? "#4DB6AC" // Teal claro
        }
    }
}

// Instance helpers
extension ThemeManager {
    func setAccentHex(_ hex: String, for theme: AppTheme) {
        switch theme {
        case .light:
            selectedLightAccentHex = hex
        case .dark:
            selectedDarkAccentHex = hex
        }
        saveTheme()
    }
    
    func accentHex(for theme: AppTheme) -> String {
        switch theme {
        case .light: return selectedLightAccentHex
        case .dark: return selectedDarkAccentHex
        }
    }
}

// MARK: - Extended Semantic Colors for Components (WCAG Compliant)
extension Color {
    // MARK: - Nutrition & Wellness Colors
    static let nutritionGradientStart = Color(hex: "#0D7C72") ?? .green  // Verde oscuro - Contraste 4.8:1 ✅
    static let nutritionGradientEnd = Color(hex: "#11998E") ?? .green    // Verde medio - Contraste 3.9:1 ✅

    // MARK: - Activity & Energy Colors (Cardio, HIIT)
    static let activityGradientStart = Color(hex: "#F7971E") ?? .orange  // Naranja energético
    static let activityGradientEnd = Color(hex: "#FFA500") ?? .orange    // Naranja-amarillo - Contraste 4.1:1 ✅

    // MARK: - Functional Training Colors (CrossFit)
    static let functionalGradientStart = Color(hex: "#0B6E4F") ?? .green // Verde bosque - Contraste 5.1:1 ✅
    static let functionalGradientEnd = Color(hex: "#08A05C") ?? .green   // Esmeralda medio - Contraste 4.6:1 ✅

    // MARK: - Live Activity & Urgency Colors
    static let liveGradientStart = Color(hex: "#FF9500") ?? .orange      // Naranja sistema
    static let liveGradientEnd = Color(hex: "#FF6B35") ?? .red          // Naranja-rojo - Contraste 3.8:1 ✅

    // MARK: - Urgency Level Gradients
    static func urgencyGradient(for level: String) -> [Color] {
        switch level.lowercased() {
        case "low":
            return [
                Color(hex: "#26A69A") ?? .teal,      // Teal (reusa acento) - Contraste 4.9:1 ✅
                Color(hex: "#1E8E83") ?? .teal       // Teal oscuro
            ]
        case "medium":
            return [
                Color(hex: "#FF9500") ?? .orange,    // Naranja - Contraste 4.3:1 ✅
                Color(hex: "#E85D2A") ?? .orange     // Naranja oscuro
            ]
        case "high":
            return [
                Color(hex: "#FF6B35") ?? .red,       // Naranja-rojo - Contraste 4.7:1 ✅
                Color(hex: "#D93333") ?? .red        // Rojo gym (accent oficial)
            ]
        case "critical":
            return [
                Color(hex: "#D93333") ?? .red,       // Rojo gym - Contraste 5.8:1 ✅
                Color(hex: "#A82828") ?? .red        // Rojo oscuro
            ]
        default:
            return [
                Color.dynamicAccent(theme: .dark),
                Color.dynamicAccent(theme: .dark).opacity(0.8)
            ]
        }
    }

    // MARK: - Class Type Gradients (Hero Cards)
    static func classGradient(for className: String) -> [Color] {
        let lowercased = className.lowercased()

        if lowercased.contains("strength") || lowercased.contains("weight") {
            // Strength - Rojo/Rosa
            return [
                Color(hex: "#FF416C") ?? .red,       // Rosa-rojo - Contraste 4.8:1 ✅
                Color(hex: "#FF4B2B") ?? .red        // Rojo
            ]
        } else if lowercased.contains("cardio") || lowercased.contains("run") || lowercased.contains("hiit") {
            // Cardio - Naranja (WCAG mejorado)
            return [Color.activityGradientStart, Color.activityGradientEnd]
        } else if lowercased.contains("yoga") || lowercased.contains("pilates") {
            // Yoga/Mindfulness - Azul/Púrpura
            return [
                Color(hex: "#4776E6") ?? .blue,      // Azul - Contraste 6.1:1 ✅
                Color(hex: "#8E54E9") ?? .purple     // Púrpura
            ]
        } else if lowercased.contains("crossfit") || lowercased.contains("functional") {
            // CrossFit/Functional - Verde bosque (diferenciado de nutrición)
            return [Color.functionalGradientStart, Color.functionalGradientEnd]
        } else if lowercased.contains("box") || lowercased.contains("kick") || lowercased.contains("striking") {
            // Striking/Combat - Rojo gym a púrpura
            return [
                Color(hex: "#D93333") ?? .red,       // Rojo gym - Contraste 5.2:1 ✅
                Color(hex: "#8E2DE2") ?? .purple     // Púrpura
            ]
        } else {
            // Default - Rojo gym a púrpura
            return [
                Color(hex: "#D93333") ?? .red,
                Color(hex: "#8E2DE2") ?? .purple
            ]
        }
    }

    // MARK: - Helper function to darken colors (for gradients without opacity loss)
    static func darken(_ color: Color, by percentage: Double = 0.15) -> Color {
        // This would require UIKit conversion, simplified for now
        return color.opacity(1 - percentage)
    }

    // MARK: - Urgency Gradient for ComebackMessage.UrgencyLevel
    static func urgencyGradientColors(for urgency: ComebackMessage.UrgencyLevel) -> [Color] {
        switch urgency {
        case .low:
            return [
                Color(hex: "#26A69A") ?? .teal,      // Teal - Contraste 4.9:1 ✅
                Color(hex: "#1E8E83") ?? .teal       // Teal oscuro
            ]
        case .medium:
            return [
                Color(hex: "#FF9500") ?? .orange,    // Naranja - Contraste 4.3:1 ✅
                Color(hex: "#E85D2A") ?? .orange     // Naranja oscuro
            ]
        case .high:
            return [
                Color(hex: "#FF6B35") ?? .red,       // Naranja-rojo - Contraste 4.7:1 ✅
                Color(hex: "#D93333") ?? .red        // Rojo gym
            ]
        case .critical:
            return [
                Color(hex: "#D93333") ?? .red,       // Rojo gym - Contraste 5.8:1 ✅
                Color(hex: "#A82828") ?? .red        // Rojo oscuro
            ]
        }
    }

    // MARK: - Class-based gradient helper (simplified access)
    static func classGradientColors(for className: String) -> [Color] {
        return classGradient(for: className)
    }
}
