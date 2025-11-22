//
//  StripeConfig.swift
//  Gym_API
//
//  Configuración de Stripe para pagos de eventos
//

import Foundation

struct StripeConfig {
    // MARK: - Configuration
    // TODO: Mover a variables de entorno o archivo de configuración seguro

    #if DEBUG
    // Test keys for development
    static let publishableKey = "pk_test_51RdO0oPZfGCbdUwYca8o33ycTG6T7swLNMO1RuCymrih60Nze8Kvon0ljxlewatpVroFt9i0wSbGwhFJ29zUKDJZ00m8sMwl4n"
    static let merchantIdentifier = "merchant.gym" // Apple Pay Merchant ID configurado en Stripe
    private static let apiBaseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    #else
    // Production keys
    static let publishableKey = "pk_live_TU_CLAVE_DE_PRODUCCION_AQUI" // Reemplaza con tu clave de producción cuando vayas a producción
    static let merchantIdentifier = "merchant.gym" // Apple Pay Merchant ID
    #endif

    // API version
    static let apiVersion = "2023-10-16"

    // Payment configuration
    static let merchantDisplayName = "Gym App"
    static let companyName = "Gym Management"
    static let defaultCurrency = "EUR"

    // Supported payment methods
    static let supportedPaymentMethods = [
        "card",
        "apple_pay",
        "google_pay"
    ]

    // Return URL for web payments
    static let returnURL = "gym-app://stripe-redirect"

    // Webhook endpoint (for backend)
    static let webhookEndpoint = "\(apiBaseURL)/memberships/webhooks/stripe"

    // MARK: - Validation
    static func isConfigured() -> Bool {
        return !publishableKey.isEmpty &&
               !publishableKey.contains("TU_CLAVE") &&
               publishableKey.hasPrefix("pk_")
    }

    // MARK: - Currency Helpers
    static func formatCurrency(cents: Int, currencyCode: String? = nil) -> String {
        let amount = Double(cents) / 100.0
        let currency = currencyCode ?? defaultCurrency

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    static func centsFromAmount(_ amount: Double) -> Int {
        return Int(amount * 100)
    }
}