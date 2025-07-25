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
    
    // MARK: - Light Theme Colors
    static let lightBackgroundPrimary = Color.white // #FFFFFF - Fondo principal blanco como en la imagen
    static let lightBackgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2
    static let lightSurfacePrimary = Color(red: 246/255, green: 247/255, blue: 250/255) // RGB(246, 247, 259) - Gris exacto de las tarjetas
    static let lightSurfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.97) // #F7F7F7
    static let lightTextPrimary = Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A
    static let lightTextSecondary = Color(red: 0.4, green: 0.4, blue: 0.4) // #666666
    static let lightTextTertiary = Color(red: 0.6, green: 0.6, blue: 0.6) // #999999
    static let lightBorderPrimary = Color(red: 0.85, green: 0.85, blue: 0.85) // #D9D9D9
    static let lightBorderSecondary = Color(red: 0.9, green: 0.9, blue: 0.9) // #E6E6E6
    static let lightAccentPrimary = Color(red: 0/255, green: 161/255, blue: 156/255) // #00A19C
    static let lightShadow = Color.black.opacity(0.1) // Sombras suaves para modo claro
    
    // MARK: - Dark Theme Colors (actuales)
    static let darkBackgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D
    static let darkBackgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.08) // #141414
    static let darkSurfacePrimary = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    static let darkSurfaceSecondary = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    static let darkTextPrimary = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2
    static let darkTextSecondary = Color(red: 0.75, green: 0.75, blue: 0.75) // #BFBFBF
    static let darkTextTertiary = Color(red: 0.55, green: 0.55, blue: 0.55) // #8C8C8C
    static let darkBorderPrimary = Color(red: 0.25, green: 0.25, blue: 0.25) // #404040
    static let darkBorderSecondary = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    static let darkAccentPrimary = Color(red: 0.85, green: 0.2, blue: 0.2) // #D93333 (rojo gym)
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