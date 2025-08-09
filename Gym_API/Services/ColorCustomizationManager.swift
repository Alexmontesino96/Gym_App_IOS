import SwiftUI
import Combine

// MARK: - Profile Background Color Options
enum ProfileBackgroundColor: String, CaseIterable {
    case oceanBlue = "ocean_blue"
    case mysticPurple = "mystic_purple"
    case sunsetOrange = "sunset_orange"
    case emeraldGreen = "emerald_green"
    case passionRed = "passion_red"
    case elegantGold = "elegant_gold"
    case softPink = "soft_pink"
    case sophisticatedGray = "sophisticated_gray"
    case default_black = "default_black"
    
    var displayName: String {
        switch self {
        case .oceanBlue: return "Ocean Blue"
        case .mysticPurple: return "Mystic Purple"
        case .sunsetOrange: return "Sunset Orange"
        case .emeraldGreen: return "Emerald Green"
        case .passionRed: return "Passion Red"
        case .elegantGold: return "Elegant Gold"
        case .softPink: return "Soft Pink"
        case .sophisticatedGray: return "Sophisticated Gray"
        case .default_black: return "Classic Dark"
        }
    }
    
    var hexColor: String {
        switch self {
        case .oceanBlue: return "#1A66CC"
        case .mysticPurple: return "#9933CC"
        case .sunsetOrange: return "#FF8033"
        case .emeraldGreen: return "#33B366"
        case .passionRed: return "#E6334C"
        case .elegantGold: return "#E6B833"
        case .softPink: return "#E699B3"
        case .sophisticatedGray: return "#666680"
        case .default_black: return "#000000"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
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
        }
    }
    
    var accentColor: Color {
        switch self {
        case .oceanBlue: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .mysticPurple: return Color(red: 0.8, green: 0.4, blue: 1.0)
        case .sunsetOrange: return Color(red: 1.0, green: 0.6, blue: 0.3)
        case .emeraldGreen: return Color(red: 0.3, green: 0.8, blue: 0.5)
        case .passionRed: return Color(red: 1.0, green: 0.3, blue: 0.4)
        case .elegantGold: return Color(red: 1.0, green: 0.8, blue: 0.3)
        case .softPink: return Color(red: 1.0, green: 0.7, blue: 0.8)
        case .sophisticatedGray: return Color(red: 0.6, green: 0.6, blue: 0.7)
        case .default_black: return Color.white
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