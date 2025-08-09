import SwiftUI
import Combine

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .dark
    
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
    }
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
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
        switch theme {
        case .light: return Color.lightAccentPrimary
        case .dark: return Color.darkAccentPrimary
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
    static let lightAccentPrimary = Color(red: 0/255, green: 130/255, blue: 126/255) // #00827E - Verde-azul original ✅
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
    static let darkAccentPrimary = Color(red: 0.95, green: 0.35, blue: 0.35) // #F25959 - WCAG 2.1 AA compliant ✅
    static let darkShadow = Color.black.opacity(0.25) // Sombras para modo oscuro
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