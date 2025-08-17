import SwiftUI
import Combine

// MARK: - Profile Background Color Options
enum ProfileBackgroundColor: String, CaseIterable {
    // Original 9 options
    case oceanBlue = "ocean_blue"
    case mysticPurple = "mystic_purple"
    case sunsetOrange = "sunset_orange"
    case emeraldGreen = "emerald_green"
    case passionRed = "passion_red"
    case elegantGold = "elegant_gold"
    case softPink = "soft_pink"
    case sophisticatedGray = "sophisticated_gray"
    case default_black = "default_black"
    
    // New 11 options based on accent colors
    case deepTeal = "deep_teal"
    case turquoise = "turquoise"
    case indigo = "indigo"
    case lightIndigo = "light_indigo"
    case lightPurple = "light_purple"
    case coral = "coral"
    case lightRed = "light_red"
    case amber = "amber"
    case lightGreen = "light_green"
    case lightBlue = "light_blue"
    case skyBlue = "sky_blue"
    
    var displayName: String {
        switch self {
        // Original options
        case .oceanBlue: return "Ocean Blue"
        case .mysticPurple: return "Mystic Purple"
        case .sunsetOrange: return "Sunset Orange"
        case .emeraldGreen: return "Emerald Green"
        case .passionRed: return "Passion Red"
        case .elegantGold: return "Elegant Gold"
        case .softPink: return "Soft Pink"
        case .sophisticatedGray: return "Sophisticated Gray"
        case .default_black: return "Classic Dark"
        
        // New options
        case .deepTeal: return "Deep Teal"
        case .turquoise: return "Turquoise"
        case .indigo: return "Indigo"
        case .lightIndigo: return "Light Indigo"
        case .lightPurple: return "Light Purple"
        case .coral: return "Coral"
        case .lightRed: return "Light Red"
        case .amber: return "Amber"
        case .lightGreen: return "Light Green"
        case .lightBlue: return "Light Blue"
        case .skyBlue: return "Sky Blue"
        }
    }
    
    var hexColor: String {
        switch self {
        // Original options
        case .oceanBlue: return "#1A66CC"
        case .mysticPurple: return "#9933CC"
        case .sunsetOrange: return "#FF8033"
        case .emeraldGreen: return "#33B366"
        case .passionRed: return "#E6334C"
        case .elegantGold: return "#E6B833"
        case .softPink: return "#E699B3"
        case .sophisticatedGray: return "#666680"
        case .default_black: return "#000000"
        
        // New options based on accent colors
        case .deepTeal: return "#00827E"
        case .turquoise: return "#3DBED0"
        case .indigo: return "#5C6AC4"
        case .lightIndigo: return "#7986CB"
        case .lightPurple: return "#BA68C8"
        case .coral: return "#FF6B6B"
        case .lightRed: return "#FF8A80"
        case .amber: return "#FFA726"
        case .lightGreen: return "#9CCC65"
        case .lightBlue: return "#29B6F6"
        case .skyBlue: return "#64B5F6"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        // Original options
        case .oceanBlue:
            return [Color(red: 0.1, green: 0.4, blue: 0.8), Color(red: 0.0, green: 0.2, blue: 0.6)]
        case .mysticPurple:
            return [Color(red: 0.6, green: 0.2, blue: 0.8), Color(red: 0.4, green: 0.1, blue: 0.6)]
        case .sunsetOrange:
            return [Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 0.8, green: 0.3, blue: 0.1)]
        case .emeraldGreen:
            return [Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.1, green: 0.5, blue: 0.3)]
        case .passionRed:
            return [Color(red: 0.9, green: 0.2, blue: 0.3), Color(red: 0.7, green: 0.1, blue: 0.2)]
        case .elegantGold:
            return [Color(red: 0.9, green: 0.7, blue: 0.2), Color(red: 0.7, green: 0.5, blue: 0.1)]
        case .softPink:
            return [Color(red: 0.9, green: 0.6, blue: 0.7), Color(red: 0.7, green: 0.4, blue: 0.5)]
        case .sophisticatedGray:
            return [Color(red: 0.4, green: 0.4, blue: 0.5), Color(red: 0.2, green: 0.2, blue: 0.3)]
        case .default_black:
            return [Color.black.opacity(0.9), Color.black.opacity(0.7)]
            
        // New options
        case .deepTeal:
            return [Color(red: 0.0, green: 0.51, blue: 0.49), Color(red: 0.0, green: 0.35, blue: 0.33)]
        case .turquoise:
            return [Color(red: 0.24, green: 0.75, blue: 0.82), Color(red: 0.16, green: 0.55, blue: 0.62)]
        case .indigo:
            return [Color(red: 0.36, green: 0.42, blue: 0.77), Color(red: 0.25, green: 0.30, blue: 0.58)]
        case .lightIndigo:
            return [Color(red: 0.47, green: 0.53, blue: 0.80), Color(red: 0.35, green: 0.40, blue: 0.65)]
        case .lightPurple:
            return [Color(red: 0.73, green: 0.41, blue: 0.78), Color(red: 0.58, green: 0.30, blue: 0.63)]
        case .coral:
            return [Color(red: 1.0, green: 0.42, blue: 0.42), Color(red: 0.85, green: 0.30, blue: 0.30)]
        case .lightRed:
            return [Color(red: 1.0, green: 0.54, blue: 0.50), Color(red: 0.85, green: 0.40, blue: 0.36)]
        case .amber:
            return [Color(red: 1.0, green: 0.65, blue: 0.15), Color(red: 0.85, green: 0.50, blue: 0.10)]
        case .lightGreen:
            return [Color(red: 0.61, green: 0.80, blue: 0.40), Color(red: 0.45, green: 0.65, blue: 0.28)]
        case .lightBlue:
            return [Color(red: 0.16, green: 0.71, blue: 0.96), Color(red: 0.10, green: 0.55, blue: 0.80)]
        case .skyBlue:
            return [Color(red: 0.39, green: 0.71, blue: 0.96), Color(red: 0.28, green: 0.55, blue: 0.80)]
        }
    }
    
    var accentColor: Color {
        switch self {
        // Original options
        case .oceanBlue: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .mysticPurple: return Color(red: 0.8, green: 0.4, blue: 1.0)
        case .sunsetOrange: return Color(red: 1.0, green: 0.6, blue: 0.3)
        case .emeraldGreen: return Color(red: 0.3, green: 0.8, blue: 0.5)
        case .passionRed: return Color(red: 1.0, green: 0.3, blue: 0.4)
        case .elegantGold: return Color(red: 1.0, green: 0.8, blue: 0.3)
        case .softPink: return Color(red: 1.0, green: 0.7, blue: 0.8)
        case .sophisticatedGray: return Color(red: 0.6, green: 0.6, blue: 0.7)
        case .default_black: return Color.white
        
        // New options
        case .deepTeal: return Color(red: 0.1, green: 0.7, blue: 0.65)
        case .turquoise: return Color(red: 0.35, green: 0.85, blue: 0.92)
        case .indigo: return Color(red: 0.45, green: 0.52, blue: 0.87)
        case .lightIndigo: return Color(red: 0.57, green: 0.63, blue: 0.90)
        case .lightPurple: return Color(red: 0.83, green: 0.51, blue: 0.88)
        case .coral: return Color(red: 1.0, green: 0.52, blue: 0.52)
        case .lightRed: return Color(red: 1.0, green: 0.64, blue: 0.60)
        case .amber: return Color(red: 1.0, green: 0.75, blue: 0.25)
        case .lightGreen: return Color(red: 0.71, green: 0.90, blue: 0.50)
        case .lightBlue: return Color(red: 0.26, green: 0.81, blue: 1.0)
        case .skyBlue: return Color(red: 0.49, green: 0.81, blue: 1.0)
        }
    }
    
    // MARK: - Initialization from hex
    init?(hexColor: String) {
        let hex = hexColor.lowercased()
        for color in ProfileBackgroundColor.allCases {
            if color.hexColor.lowercased() == hex {
                self = color
                return
            }
        }
        return nil
    }
}

// MARK: - Color Customization Manager
@MainActor
class ColorCustomizationManager: ObservableObject {
    static let shared = ColorCustomizationManager()
    
    @Published var currentBackgroundColor: ProfileBackgroundColor = .default_black
    @Published var isLoading = false
    @Published var error: Error?
    
    private let userDefaults = UserDefaults.standard
    private let backgroundColorKey = "profile_background_color"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependency Injection
    weak var authService: AuthServiceDirect?
    weak var profileService: UserProfileService?
    
    private init() {
        loadSavedBackgroundColor()
    }
    
    // MARK: - Public Methods
    
    /// Cargar el color guardado localmente
    func loadSavedBackgroundColor() {
        if let savedColorString = userDefaults.string(forKey: backgroundColorKey),
           let savedColor = ProfileBackgroundColor(rawValue: savedColorString) {
            currentBackgroundColor = savedColor
        }
    }
    
    /// Cambiar el color de fondo con persistencia local y remota
    func changeBackgroundColor(to color: ProfileBackgroundColor) async {
        // Guardar inmediatamente en local para respuesta rápida
        saveBackgroundColorLocally(color)
        
        // Sincronizar con el servidor
        await syncBackgroundColorWithServer(color)
    }
    
    /// Obtener gradiente para el fondo del perfil
    func getProfileBackgroundGradient(for theme: ThemeManager.AppTheme) -> LinearGradient {
        let colors = currentBackgroundColor.gradientColors
        
        return LinearGradient(
            colors: [
                colors[0],
                colors[1],
                colors[1].opacity(0.5),
                Color.dynamicBackground(theme: theme).opacity(0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Obtener color de acento para elementos del perfil
    func getAccentColor() -> Color {
        return currentBackgroundColor.accentColor
    }
    
    /// Resetear al color por defecto
    func resetToDefault() async {
        await changeBackgroundColor(to: .default_black)
    }
    
    // MARK: - Private Methods
    
    private func saveBackgroundColorLocally(_ color: ProfileBackgroundColor) {
        currentBackgroundColor = color
        userDefaults.set(color.rawValue, forKey: backgroundColorKey)
        print("🎨 [ColorCustomizationManager] Saved background color locally: \(color.displayName)")
    }
    
    private func syncBackgroundColorWithServer(_ color: ProfileBackgroundColor) async {
        guard let authService = authService,
              let profileService = profileService else {
            print("❌ [ColorCustomizationManager] Missing required services")
            return
        }
        
        isLoading = true
        error = nil
        
        // Intentar actualizar el color en el servidor usando hex
        let success = await profileService.updateProfileBackgroundColor(color.hexColor)
        
        if success {
            print("🌐 [ColorCustomizationManager] Synced background color with server: \(color.displayName)")
        } else {
            print("❌ [ColorCustomizationManager] Failed to sync with server")
            
            // En caso de error, mantener el color local pero mostrar error al usuario
            // No revertir el cambio local para mejor UX
        }
        
        isLoading = false
    }
    
    /// Cargar color desde el perfil del usuario
    func loadColorFromProfile(_ profile: UserProfile) {
        if let hexColor = profile.color,
           let color = ProfileBackgroundColor(hexColor: hexColor) {
            
            // Solo actualizar si es diferente del actual
            if color != currentBackgroundColor {
                currentBackgroundColor = color
                saveBackgroundColorLocally(color)
                print("📥 [ColorCustomizationManager] Loaded color from profile hex: \(hexColor) -> \(color.displayName)")
            }
        } else if let hexColor = profile.color {
            print("⚠️ [ColorCustomizationManager] Unknown hex color from profile: \(hexColor), using default")
        }
    }
}

// MARK: - Extensions for Color Helpers
extension Color {
    /// Crear gradiente dinámico para fondo de perfil
    @MainActor
    static func profileBackgroundGradient(
        color: ProfileBackgroundColor,
        theme: ThemeManager.AppTheme
    ) -> LinearGradient {
        return ColorCustomizationManager.shared.getProfileBackgroundGradient(for: theme)
    }
    
    /// Obtener color de acento del perfil
    @MainActor
    static func profileAccent() -> Color {
        return ColorCustomizationManager.shared.getAccentColor()
    }
}