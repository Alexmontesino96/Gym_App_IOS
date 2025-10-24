import Foundation

struct StreamConfig {
    static let apiKey: String = {
        // Leer API Key desde Info.plist de forma segura
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "STREAM_CHAT_API_KEY") as? String,
           !apiKey.isEmpty {
            return apiKey
        } else {
            #if DEBUG
            print("⚠️ Stream Chat API Key no configurado en Info.plist")
            return "dev-stream-key-not-configured"
            #else
            fatalError("❌ Stream Chat API Key debe estar configurado en Info.plist para producción")
            #endif
        }
    }()

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