//
//  SupportConfig.swift
//  Gym_API
//
//  Dónde escribe quien necesita ayuda.
//
//  La guía 1.5 de la App Store exige una URL de soporte que funcione, y la 1.2 exige, en una
//  app con contenido de otras personas, "a published means for users to contact you". Hasta
//  ahora la fila de Ayuda del perfil tenía `action: {}`: no hacía nada.
//
//  ⚠️ ANTES DE PUBLICAR: sustituir estos dos valores por los reales y comprobar que la URL
//  abre. Una URL de soporte rota es motivo de rechazo por sí sola.
//

import Foundation

enum SupportConfig {

    /// Base del sitio público. Un solo sitio que cambiar si se mueve el dominio.
    private static let siteBase = "https://admin-gym-dashboard.vercel.app"

    /// Página de ayuda. Es la que se declara como Support URL en App Store Connect.
    static let supportURLString = "\(siteBase)/support"

    /// Condiciones de uso. Se enlazan en el alta, y la guía 1.2 exige que se acepten.
    static let termsURLString = "\(siteBase)/legal/terms"

    /// Política de privacidad. Se declara también en App Store Connect.
    static let privacyURLString = "\(siteBase)/legal/privacy"

    /// Versión de las condiciones que la app da por aceptada al continuar.
    /// Tiene que coincidir con `LEGAL.termsVersion` del panel y con lo que guarda el backend.
    static let termsVersion = "1.0"

    /// Dirección de correo de respaldo, por si la página no abre.
    static let supportEmail = "support@gymapi.app"

    static var supportURL: URL? { URL(string: supportURLString) }
    static var termsURL: URL? { URL(string: termsURLString) }
    static var privacyURL: URL? { URL(string: privacyURLString) }

    /// Correo prerrellenado con el asunto, para que llegue identificado.
    static func mailtoURL(subject: String = "App support") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}
