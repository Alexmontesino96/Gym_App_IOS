import Foundation

struct StreamConfig {
    static let apiKey = "xptswctbxzsw"
    
    // NOTA: El API secret NO se incluye en el frontend por seguridad
    // El backend maneja toda la autenticación y generación de tokens
    
    // Configuración adicional para Stream.io
    static let chatDomain = "https://us-east-1.stream-io-api.com"
    static let maxMessageLength = 1000
    static let typingIndicatorTimeout = 10.0
    
    // Configuración del canal
    static let channelType = "messaging"
    static let channelCIDPrefix = "event_"
} 